import XCTest
@testable import Skwad

final class RepoDiscoveryServiceTests: XCTestCase {

    private var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "skwad-test-\(UUID().uuidString)"
        try! FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Create a fake clone (folder with .git directory and HEAD file)
    private func createClone(_ name: String, branch: String = "main") {
        let repoPath = (tempDir as NSString).appendingPathComponent(name)
        let gitPath = (repoPath as NSString).appendingPathComponent(".git")
        try! FileManager.default.createDirectory(atPath: gitPath, withIntermediateDirectories: true)
        let headContent = "ref: refs/heads/\(branch)\n"
        try! headContent.write(toFile: (gitPath as NSString).appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
    }

    /// Create a fake worktree (folder with .git file pointing to parent)
    private func createWorktree(_ name: String, parentRepo: String) {
        let wtPath = (tempDir as NSString).appendingPathComponent(name)
        try! FileManager.default.createDirectory(atPath: wtPath, withIntermediateDirectories: true)
        let parentRepoPath = (tempDir as NSString).appendingPathComponent(parentRepo)
        let gitContent = "gitdir: \(parentRepoPath)/.git/worktrees/\(name)\n"
        try! gitContent.write(toFile: (wtPath as NSString).appendingPathComponent(".git"), atomically: true, encoding: .utf8)
    }

    /// Create a plain folder (no .git)
    private func createFolder(_ name: String) {
        let path = (tempDir as NSString).appendingPathComponent(name)
        try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    // MARK: - Empty / Invalid

    func testEmptyFolderReturnsNoRepos() {
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertTrue(repos.isEmpty)
    }

    func testInvalidPathReturnsNoRepos() {
        let repos = RepoDiscoveryService.scanRepos(in: "/this/path/does/not/exist")
        XCTAssertTrue(repos.isEmpty)
    }

    func testPlainFoldersAreIgnored() {
        createFolder("not-a-repo")
        createFolder("also-not-a-repo")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertTrue(repos.isEmpty)
    }

    // MARK: - Clone Detection

    func testFindsClone() {
        createClone("my-repo")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos.count, 1)
        XCTAssertEqual(repos[0].name, "my-repo")
    }

    func testCloneHasOneWorktree() {
        createClone("my-repo", branch: "main")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos[0].worktrees.count, 1)
        XCTAssertEqual(repos[0].worktrees[0].name, "main")
        XCTAssertTrue(repos[0].worktrees[0].path.hasSuffix("/my-repo"))
    }

    func testCloneBranchNameFromHead() {
        createClone("my-repo", branch: "develop")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos[0].worktrees[0].name, "develop")
    }

    func testCloneNestedBranchName() {
        createClone("my-repo", branch: "feature/deep/branch")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos[0].worktrees[0].name, "feature/deep/branch")
    }

    func testCloneFallsBackToFolderNameWhenHeadMissing() {
        let repoPath = (tempDir as NSString).appendingPathComponent("my-repo")
        let gitPath = (repoPath as NSString).appendingPathComponent(".git")
        try! FileManager.default.createDirectory(atPath: gitPath, withIntermediateDirectories: true)
        // No HEAD file
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos[0].worktrees[0].name, "my-repo")
    }

    func testCloneDetachedHeadFallsBackToFolderName() {
        let repoPath = (tempDir as NSString).appendingPathComponent("my-repo")
        let gitPath = (repoPath as NSString).appendingPathComponent(".git")
        try! FileManager.default.createDirectory(atPath: gitPath, withIntermediateDirectories: true)
        // Detached HEAD (SHA, not ref)
        try! "abc123def456\n".write(toFile: (gitPath as NSString).appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos[0].worktrees[0].name, "my-repo")
    }

    // MARK: - Worktree Detection

    func testFindsWorktreeLinkedToClone() {
        createClone("witsy", branch: "main")
        createWorktree("witsy-feature", parentRepo: "witsy")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos.count, 1)
        XCTAssertEqual(repos[0].name, "witsy")
        XCTAssertEqual(repos[0].worktrees.count, 2)
    }

    func testWorktreeNameStripsRepoPrefix() {
        createClone("witsy", branch: "main")
        createWorktree("witsy-streaming-block", parentRepo: "witsy")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        let worktreeNames = repos[0].worktrees.map { $0.name }
        XCTAssertTrue(worktreeNames.contains("main"))
        XCTAssertTrue(worktreeNames.contains("streaming-block"))
    }

    func testWorktreeWithoutRepoPrefixKeepsFullName() {
        createClone("witsy", branch: "main")
        createWorktree("unrelated-name", parentRepo: "witsy")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        let worktreeNames = repos[0].worktrees.map { $0.name }
        XCTAssertTrue(worktreeNames.contains("unrelated-name"))
    }

    func testCloneWorktreeIsFirst() {
        createClone("witsy", branch: "main")
        createWorktree("witsy-feature", parentRepo: "witsy")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos[0].worktrees[0].name, "main")
        XCTAssertTrue(repos[0].worktrees[0].path.hasSuffix("/witsy"))
    }

    func testMultipleWorktrees() {
        createClone("witsy", branch: "main")
        createWorktree("witsy-feature-a", parentRepo: "witsy")
        createWorktree("witsy-feature-b", parentRepo: "witsy")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos[0].worktrees.count, 3)
    }

    // MARK: - Worktree Without Parent Clone In Base Folder

    func testWorktreeWithoutParentCloneIsIgnored() {
        // Worktree pointing to a repo that's NOT in the base folder
        let wtPath = (tempDir as NSString).appendingPathComponent("orphan-wt")
        try! FileManager.default.createDirectory(atPath: wtPath, withIntermediateDirectories: true)
        let gitContent = "gitdir: /some/other/path/.git/worktrees/orphan-wt\n"
        try! gitContent.write(toFile: (wtPath as NSString).appendingPathComponent(".git"), atomically: true, encoding: .utf8)
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertTrue(repos.isEmpty)
    }

    // MARK: - Multiple Repos

    func testMultipleReposSortedAlphabetically() {
        createClone("zeta")
        createClone("alpha")
        createClone("middle")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos.count, 3)
        XCTAssertEqual(repos[0].name, "alpha")
        XCTAssertEqual(repos[1].name, "middle")
        XCTAssertEqual(repos[2].name, "zeta")
    }

    func testMixOfReposAndPlainFolders() {
        createClone("repo-a")
        createFolder("not-a-repo")
        createClone("repo-b")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertEqual(repos.count, 2)
    }

    // MARK: - RepoInfo.path

    func testRepoPathIsFirstWorktreePath() {
        createClone("my-repo", branch: "main")
        createWorktree("my-repo-feature", parentRepo: "my-repo")
        let repos = RepoDiscoveryService.scanRepos(in: tempDir)
        XCTAssertTrue(repos[0].path.hasSuffix("/my-repo"))
    }

    // MARK: - Tilde Expansion

    func testTildeExpansion() {
        // scanRepos expands ~ in paths — just verify it doesn't crash
        let repos = RepoDiscoveryService.scanRepos(in: "~/nonexistent-skwad-test-dir")
        XCTAssertTrue(repos.isEmpty)
    }
}
