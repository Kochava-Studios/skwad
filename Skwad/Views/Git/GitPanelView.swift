import SwiftUI

/// Sliding panel showing git status and diffs for the current agent's folder
struct GitPanelView: View {
    let folder: String
    let onClose: () -> Void

    @EnvironmentObject var agentManager: AgentManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var status: RepositoryStatus?
    @State private var selectedFile: FileStatus?
    @State private var selectedDiff: FileDiff?
    @State private var showStagedDiff = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var fileWatcher: GitFileWatcher?
    @State private var panelWidth: CGFloat = 500
    @State private var showCommitSheet = false

    private var repo: GitRepository {
        GitRepository(path: folder)
    }

    private var backgroundColor: Color {
        settings.effectiveBackgroundColor
    }

    var body: some View {
        HStack(spacing: 0) {
            // Resize handle
            resizeHandle

            VStack(spacing: 0) {
                // Header
                header

                Divider()
                    .background(Color.primary.opacity(0.2))

                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let status = status {
                    if status.isClean {
                        cleanView
                    } else {
                        VSplitView {
                            // File list at top
                            fileListView(status: status)
                                .frame(minHeight: 150, idealHeight: 200)

                            // Diff view at bottom
                            diffDetailView
                                .frame(minHeight: 200)
                        }
                    }
                }
            }
            .frame(width: panelWidth)
        }
        .background(backgroundColor)
        .onAppear {
            refresh()
            startWatching()
        }
        .onDisappear {
            stopWatching()
        }
        .sheet(isPresented: $showCommitSheet) {
            CommitSheet(folder: folder) {
                refresh()
            }
        }
    }

    // MARK: - File Watching

    private func startWatching() {
        fileWatcher = GitFileWatcher(path: folder) {
            DispatchQueue.main.async { [weak fileWatcher] in
                // Double-check we're not paused before refreshing
                guard fileWatcher != nil else { return }
                self.refresh()
            }
        }
        fileWatcher?.start()
    }

    private func stopWatching() {
        fileWatcher?.stop()
        fileWatcher = nil
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newWidth = panelWidth - value.translation.width
                        panelWidth = max(350, min(800, newWidth))
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Git Status")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            // Commit button (only when staged changes exist)
            if let status = status, status.hasStaged {
                Button {
                    showCommitSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                        Text("Commit")
                    }
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Commit staged changes")
            }

            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.05))
    }

    // MARK: - States

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cleanView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundColor(.green)
            Text("Working tree clean")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - File List

    private func fileListView(status: RepositoryStatus) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Branch info
                if let branch = status.branch {
                    branchInfoView(branch: branch, status: status)
                }

                // Staged files
                if !status.stagedFiles.isEmpty {
                    fileSection(
                        title: "Staged Changes",
                        files: status.stagedFiles,
                        isStaged: true,
                        color: .green
                    )
                }

                // Modified files
                if !status.modifiedFiles.isEmpty {
                    fileSection(
                        title: "Changes",
                        files: status.modifiedFiles,
                        isStaged: false,
                        color: .orange
                    )
                }

                // Untracked files
                if !status.untrackedFiles.isEmpty {
                    fileSection(
                        title: "Untracked",
                        files: status.untrackedFiles,
                        isStaged: false,
                        color: .gray
                    )
                }

                // Conflicts
                if !status.conflictedFiles.isEmpty {
                    fileSection(
                        title: "Conflicts",
                        files: status.conflictedFiles,
                        isStaged: false,
                        color: .red
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func branchInfoView(branch: String, status: RepositoryStatus) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundColor(.secondary)

            Text(branch)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            if status.ahead > 0 {
                Text("↑\(status.ahead)")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            if status.behind > 0 {
                Text("↓\(status.behind)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
    }

    private func fileSection(title: String, files: [FileStatus], isStaged: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text("(\(files.count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                // Stage/unstage all
                if isStaged {
                    Button("Unstage All") {
                        unstageAll()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                } else if title == "Changes" {
                    Button("Stage All") {
                        stageAll()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // Files
            ForEach(files) { file in
                FileRowView(
                    file: file,
                    isSelected: selectedFile?.path == file.path && showStagedDiff == isStaged,
                    color: color,
                    onSelect: {
                        selectFile(file, staged: isStaged)
                    },
                    onStage: isStaged ? nil : {
                        stage([file.path])
                    },
                    onUnstage: isStaged ? {
                        unstage([file.path])
                    } : nil,
                    onDiscard: !isStaged && !file.isUntracked ? {
                        discard([file.path])
                    } : nil
                )
            }
        }
    }

    // MARK: - Diff Detail

    private var diffDetailView: some View {
        Group {
            if let diff = selectedDiff {
                VStack(spacing: 0) {
                    // File header
                    HStack {
                        Text(diff.path)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        if diff.additions > 0 {
                            Text("+\(diff.additions)")
                                .foregroundColor(.green)
                                .font(.caption.monospaced())
                        }
                        if diff.deletions > 0 {
                            Text("-\(diff.deletions)")
                                .foregroundColor(.red)
                                .font(.caption.monospaced())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.05))

                    DiffView(diff: diff)
                }
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Select a file to view diff")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Actions

    private func refresh() {
        // Pause watcher during refresh to avoid feedback loop
        fileWatcher?.pause()

        // Only show loading on first load
        if status == nil {
            isLoading = true
        }
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let newStatus = repo.status()

            DispatchQueue.main.async {
                self.status = newStatus
                self.isLoading = false
                self.refreshGitStats()

                // Clear selection if file no longer exists
                if let selected = selectedFile,
                   !newStatus.files.contains(where: { $0.path == selected.path }) {
                    selectedFile = nil
                    selectedDiff = nil
                }

                // Resume watching after a short delay
                AsyncDelay.dispatch(after: TimingConstants.gitFileWatcherResume) {
                    self.fileWatcher?.resume()
                }
            }
        }
    }

    private func refreshGitStats() {
        agentManager.refreshGitStats(forFolder: folder)
    }

    private func selectFile(_ file: FileStatus, staged: Bool) {
        selectedFile = file
        showStagedDiff = staged

        DispatchQueue.global(qos: .userInitiated).async {
            let diffs = repo.diff(for: file.path, staged: staged)

            DispatchQueue.main.async {
                self.selectedDiff = diffs.first
            }
        }
    }

    private func stage(_ paths: [String]) {
        do {
            try repo.stage(paths)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unstage(_ paths: [String]) {
        do {
            try repo.unstage(paths)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stageAll() {
        do {
            try repo.stageAll()
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unstageAll() {
        do {
            try repo.unstageAll()
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func discard(_ paths: [String]) {
        do {
            try repo.discardChanges(paths)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - File Row

struct FileRowView: View {
    let file: FileStatus
    let isSelected: Bool
    let color: Color
    let onSelect: () -> Void
    let onStage: (() -> Void)?
    let onUnstage: (() -> Void)?
    let onDiscard: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Text(statusSymbol)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 16)

            // Filename
            VStack(alignment: .leading, spacing: 1) {
                Text(file.fileName)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !file.directory.isEmpty {
                    Text(file.directory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Action buttons (on hover)
            if isHovering {
                HStack(spacing: 4) {
                    if let onStage = onStage {
                        Button {
                            onStage()
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Stage")
                    }

                    if let onUnstage = onUnstage {
                        Button {
                            onUnstage()
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Unstage")
                    }

                    if let onDiscard = onDiscard {
                        Button {
                            onDiscard()
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Discard changes")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.3) : (isHovering ? Color.primary.opacity(0.1) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var statusSymbol: String {
        if let staged = file.stagedStatus, staged != .untracked {
            return staged.symbol
        }
        if let unstaged = file.unstagedStatus {
            return unstaged.symbol
        }
        return "?"
    }
}
