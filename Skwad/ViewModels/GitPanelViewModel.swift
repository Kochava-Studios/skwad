import Foundation
import Observation

@Observable
@MainActor
final class GitPanelViewModel {

    // MARK: - Published State

    private(set) var status: RepositoryStatus?
    private(set) var selectedFile: FileStatus?
    private(set) var selectedDiff: FileDiff?
    private(set) var showStagedDiff = false
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let folder: String
    private let repository: GitRepository
    private let onStatsRefresh: () -> Void

    private var fileWatcher: GitFileWatcher?

    // MARK: - Initialization

    init(folder: String, onStatsRefresh: @escaping () -> Void) {
        self.folder = folder
        self.repository = GitRepository(path: folder)
        self.onStatsRefresh = onStatsRefresh
    }

    // MARK: - Lifecycle

    func onAppear() {
        refresh()
        startWatching()
    }

    func onDisappear() {
        stopWatching()
    }

    // MARK: - File Watching

    private func startWatching() {
        fileWatcher = GitFileWatcher(path: folder) { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        fileWatcher?.start()
    }

    private func stopWatching() {
        fileWatcher?.stop()
        fileWatcher = nil
    }

    // MARK: - Refresh

    func refresh() {
        fileWatcher?.pause()

        if status == nil {
            isLoading = true
        }
        errorMessage = nil

        // Capture repository for use in detached task
        let repo = repository

        Task.detached(priority: .userInitiated) {
            let newStatus = repo.status()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.status = newStatus
                self.isLoading = false
                self.onStatsRefresh()

                if let selected = self.selectedFile,
                   !newStatus.files.contains(where: { $0.path == selected.path }) {
                    self.selectedFile = nil
                    self.selectedDiff = nil
                }

                AsyncDelay.dispatch(after: TimingConstants.gitFileWatcherResume) { [weak self] in
                    self?.fileWatcher?.resume()
                }
            }
        }
    }

    // MARK: - Selection

    func selectFile(_ file: FileStatus, staged: Bool) {
        selectedFile = file
        showStagedDiff = staged

        // Capture repository for use in detached task
        let repo = repository

        Task.detached(priority: .userInitiated) {
            let diffs = repo.diff(for: file.path, staged: staged)

            await MainActor.run { [weak self] in
                self?.selectedDiff = diffs.first
            }
        }
    }

    // MARK: - Git Operations

    func stage(_ paths: [String]) {
        performGitOperation {
            try self.repository.stage(paths)
        }
    }

    func unstage(_ paths: [String]) {
        performGitOperation {
            try self.repository.unstage(paths)
        }
    }

    func stageAll() {
        performGitOperation {
            try self.repository.stageAll()
        }
    }

    func unstageAll() {
        performGitOperation {
            try self.repository.unstageAll()
        }
    }

    func discard(_ paths: [String]) {
        performGitOperation {
            try self.repository.discardChanges(paths)
        }
    }

    // MARK: - Private Helpers

    private func performGitOperation(_ operation: () throws -> Void) {
        do {
            try operation()
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
