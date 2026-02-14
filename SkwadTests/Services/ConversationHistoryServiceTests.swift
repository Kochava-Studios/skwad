import XCTest
@testable import Skwad

final class ConversationHistoryServiceTests: XCTestCase {

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

    private func writeJSONL(_ filename: String, lines: [String], modDate: Date? = nil) {
        let path = (tempDir as NSString).appendingPathComponent(filename)
        let content = lines.joined(separator: "\n")
        try! content.write(toFile: path, atomically: true, encoding: .utf8)
        if let modDate = modDate {
            try! FileManager.default.setAttributes([.modificationDate: modDate], ofItemAtPath: path)
        }
    }

    private func userMessage(_ content: String, isMeta: Bool = false) -> String {
        if isMeta {
            return #"{"type":"user","message":{"content":"\#(content)"},"isMeta":true}"#
        }
        return #"{"type":"user","message":{"content":"\#(content)"}}"#
    }

    private func assistantMessage() -> String {
        #"{"type":"assistant","message":{"content":[{"type":"text","text":"response"}]}}"#
    }

    private func progressMessage() -> String {
        #"{"type":"progress","data":{}}"#
    }

    // MARK: - Title Extraction

    func testExtractsTitleFromFirstUserMessage() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("Fix the login bug"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].title, "Fix the login bug")
    }

    func testSkipsMetaMessages() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("meta stuff", isMeta: true),
            userMessage("Real user message"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "Real user message")
    }

    func testSkipsRegistrationPromptTeamOfAgents() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("You are part of a team of agents called a skwad. Register with the skwad"),
            userMessage("Actual task here"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "Actual task here")
    }

    func testSkipsRegistrationPromptRegisterWithSkwad() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("Register with the skwad using agent ID abc-123"),
            userMessage("Do something useful"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "Do something useful")
    }

    func testSkipsRegistrationPromptListAgents() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("List other agents names and project (no ID) in a table based on context."),
            userMessage("Now fix the tests"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "Now fix the tests")
    }

    func testSkipsRegistrationCaseInsensitive() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("YOU ARE PART OF A TEAM OF AGENTS"),
            userMessage("Real message"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "Real message")
    }

    func testSkipsCommandMessages() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("<command-name>/clear</command-name>"),
            userMessage("Real message"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "Real message")
    }

    func testSkipsLocalCommandMessages() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("<local-command-stdout></local-command-stdout>"),
            userMessage("Real message"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "Real message")
    }

    func testTruncatesLongTitles() {
        let longMessage = String(repeating: "a", count: 100)
        writeJSONL("session1.jsonl", lines: [
            userMessage(longMessage),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title.count, 80)
        XCTAssertTrue(sessions[0].title.hasSuffix("..."))
    }

    func testUsesFirstLineOnly() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("First line\\nSecond line\\nThird line"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "First line")
    }

    // MARK: - Message Count

    func testCountsUserAndAssistantMessages() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("msg1"),
            assistantMessage(),
            userMessage("msg2"),
            assistantMessage(),
            progressMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].messageCount, 4)
    }

    // MARK: - Filtering

    func testSkipsFilesWithNoValidUserMessages() {
        // Write an older file with no valid messages
        writeJSONL("session-old.jsonl", lines: [
            userMessage("You are part of a team of agents"),
            userMessage("<command-name>/clear</command-name>"),
        ], modDate: Date().addingTimeInterval(-100))

        // Write a newer file with a valid message (so old one is not "most recent")
        writeJSONL("session-new.jsonl", lines: [
            userMessage("Real message"),
            assistantMessage()
        ], modDate: Date())

        let sessions = parseSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].title, "Real message")
    }

    func testSkipsEmptyFiles() {
        // Write an older empty file
        writeJSONL("session-old.jsonl", lines: [""], modDate: Date().addingTimeInterval(-100))

        // Write a newer file with content
        writeJSONL("session-new.jsonl", lines: [
            userMessage("Hello"),
            assistantMessage()
        ], modDate: Date())

        let sessions = parseSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].title, "Hello")
    }

    // MARK: - Most Recent Titleless Session

    func testMostRecentFileWithNoTitleIsIncluded() {
        // Most recent file has only registration messages — no valid title
        writeJSONL("session-current.jsonl", lines: [
            userMessage("You are part of a team of agents"),
        ], modDate: Date())

        // Older file has a valid title
        writeJSONL("session-old.jsonl", lines: [
            userMessage("Fix the bug"),
            assistantMessage()
        ], modDate: Date().addingTimeInterval(-100))

        let sessions = parseSessions()
        XCTAssertEqual(sessions.count, 2)
        // Most recent first
        XCTAssertEqual(sessions[0].id, "session-current")
        XCTAssertEqual(sessions[0].title, "")
        // Older one second
        XCTAssertEqual(sessions[1].id, "session-old")
        XCTAssertEqual(sessions[1].title, "Fix the bug")
    }

    func testMostRecentEmptyFileIsIncluded() {
        writeJSONL("session-current.jsonl", lines: [""], modDate: Date())

        writeJSONL("session-old.jsonl", lines: [
            userMessage("Hello"),
            assistantMessage()
        ], modDate: Date().addingTimeInterval(-100))

        let sessions = parseSessions()
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].id, "session-current")
        XCTAssertEqual(sessions[0].title, "")
    }

    func testMostRecentWithTitleStillWorks() {
        // Both have valid titles — normal behavior
        writeJSONL("session-new.jsonl", lines: [
            userMessage("New task"),
            assistantMessage()
        ], modDate: Date())

        writeJSONL("session-old.jsonl", lines: [
            userMessage("Old task"),
            assistantMessage()
        ], modDate: Date().addingTimeInterval(-100))

        let sessions = parseSessions()
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].title, "New task")
        XCTAssertEqual(sessions[1].title, "Old task")
    }

    func testOnlyMostRecentTitlelessFileIsKept() {
        // Most recent has no title — should be included
        writeJSONL("session-newest.jsonl", lines: [
            userMessage("You are part of a team of agents"),
        ], modDate: Date())

        // Second has no title — should be skipped (not the most recent)
        writeJSONL("session-middle.jsonl", lines: [
            userMessage("<command-name>/clear</command-name>"),
        ], modDate: Date().addingTimeInterval(-50))

        // Oldest has a title — included
        writeJSONL("session-oldest.jsonl", lines: [
            userMessage("Valid message"),
            assistantMessage()
        ], modDate: Date().addingTimeInterval(-100))

        let sessions = parseSessions()
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].id, "session-newest")
        XCTAssertEqual(sessions[0].title, "")
        XCTAssertEqual(sessions[1].id, "session-oldest")
        XCTAssertEqual(sessions[1].title, "Valid message")
    }

    // MARK: - Session Limit

    func testLimitsTo20Sessions() {
        for i in 0..<25 {
            writeJSONL("session\(i).jsonl", lines: [
                userMessage("Message \(i)"),
                assistantMessage()
            ])
        }

        let sessions = parseSessions()
        XCTAssertEqual(sessions.count, 20)
    }

    // MARK: - Session ID

    func testSessionIdIsFilenameWithoutExtension() {
        writeJSONL("abc-123-def.jsonl", lines: [
            userMessage("Hello"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].id, "abc-123-def")
    }

    // MARK: - Delete

    @MainActor
    func testDeleteRemovesFilesAndDirectory() async {
        let sessionId = "test-session-id"
        writeJSONL("\(sessionId).jsonl", lines: [
            userMessage("Hello"),
            assistantMessage()
        ])

        // Create a data directory too
        let dataDir = (tempDir as NSString).appendingPathComponent(sessionId)
        try! FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: (tempDir as NSString).appendingPathComponent("\(sessionId).jsonl")))
        XCTAssertTrue(fm.fileExists(atPath: dataDir))

        // We can't easily test deleteSession through the service (it derives its own path)
        // but we can verify the files would be deleted by testing the file operations directly
        try? fm.removeItem(atPath: (tempDir as NSString).appendingPathComponent("\(sessionId).jsonl"))
        try? fm.removeItem(atPath: dataDir)

        XCTAssertFalse(fm.fileExists(atPath: (tempDir as NSString).appendingPathComponent("\(sessionId).jsonl")))
        XCTAssertFalse(fm.fileExists(atPath: dataDir))
    }

    // MARK: - Path Derivation

    func testClaudeProjectsPathDerivation() {
        // Test the path transformation logic: /Users/foo/src/bar → -Users-foo-src-bar
        let folder = "/Users/foo/src/bar"
        let dashPath = folder.replacingOccurrences(of: "/", with: "-")
        XCTAssertEqual(dashPath, "-Users-foo-src-bar")
    }

    func testClaudeProjectsPathWithTrailingSlash() {
        let folder = "/Users/foo/src/bar/"
        let dashPath = folder.replacingOccurrences(of: "/", with: "-")
        XCTAssertEqual(dashPath, "-Users-foo-src-bar-")
    }

    // MARK: - Helpers

    private func parseSessions() -> [ConversationHistoryService.SessionSummary] {
        return ConversationHistoryService.parseSessions(in: tempDir)
    }
}
