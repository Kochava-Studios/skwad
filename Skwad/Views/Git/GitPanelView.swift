import SwiftUI

/// Sliding panel showing git status and diffs for the current agent's folder
struct GitPanelView: View {
    let folder: String
    let onClose: () -> Void

    @Environment(AgentManager.self) var agentManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var viewModel: GitPanelViewModel?
    @State private var panelWidth: CGFloat = 500
    @State private var showCommitSheet = false

    private var backgroundColor: Color {
        settings.effectiveBackgroundColor
    }

    var body: some View {
        HStack(spacing: 0) {
            resizeHandle

            VStack(spacing: 0) {
                header

                Divider()
                    .background(Color.primary.opacity(0.2))

                if let vm = viewModel {
                    contentView(vm)
                }
            }
            .frame(width: panelWidth)
        }
        .background(backgroundColor)
        .onAppear {
            let vm = GitPanelViewModel(folder: folder) { [weak agentManager] in
                agentManager?.refreshGitStats(forFolder: folder)
            }
            viewModel = vm
            vm.onAppear()
        }
        .onDisappear {
            viewModel?.onDisappear()
        }
        .sheet(isPresented: $showCommitSheet) {
            CommitSheet(folder: folder) {
                viewModel?.refresh()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func contentView(_ vm: GitPanelViewModel) -> some View {
        if vm.isLoading {
            loadingView
        } else if let error = vm.errorMessage {
            errorView(error)
        } else if let status = vm.status {
            if status.isClean {
                cleanView
            } else {
                VSplitView {
                    fileListView(status: status, viewModel: vm)
                        .frame(minHeight: 150, idealHeight: 200)

                    diffDetailView(viewModel: vm)
                        .frame(minHeight: 200)
                }
            }
        }
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

            if let status = viewModel?.status, status.hasStaged {
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
                viewModel?.refresh()
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

    private func fileListView(status: RepositoryStatus, viewModel: GitPanelViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let branch = status.branch {
                    branchInfoView(branch: branch, status: status)
                }

                if !status.stagedFiles.isEmpty {
                    fileSection(
                        title: "Staged Changes",
                        files: status.stagedFiles,
                        isStaged: true,
                        color: .green,
                        viewModel: viewModel
                    )
                }

                if !status.modifiedFiles.isEmpty {
                    fileSection(
                        title: "Changes",
                        files: status.modifiedFiles,
                        isStaged: false,
                        color: .orange,
                        viewModel: viewModel
                    )
                }

                if !status.untrackedFiles.isEmpty {
                    fileSection(
                        title: "Untracked",
                        files: status.untrackedFiles,
                        isStaged: false,
                        color: .gray,
                        viewModel: viewModel
                    )
                }

                if !status.conflictedFiles.isEmpty {
                    fileSection(
                        title: "Conflicts",
                        files: status.conflictedFiles,
                        isStaged: false,
                        color: .red,
                        viewModel: viewModel
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

    private func fileSection(
        title: String,
        files: [FileStatus],
        isStaged: Bool,
        color: Color,
        viewModel: GitPanelViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text("(\(files.count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                if isStaged {
                    Button("Unstage All") {
                        viewModel.unstageAll()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                } else if title == "Changes" {
                    Button("Stage All") {
                        viewModel.stageAll()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ForEach(files) { file in
                FileRowView(
                    file: file,
                    isSelected: viewModel.selectedFile?.path == file.path && viewModel.showStagedDiff == isStaged,
                    color: color,
                    onSelect: {
                        viewModel.selectFile(file, staged: isStaged)
                    },
                    onStage: isStaged ? nil : {
                        viewModel.stage([file.path])
                    },
                    onUnstage: isStaged ? {
                        viewModel.unstage([file.path])
                    } : nil,
                    onDiscard: !isStaged && !file.isUntracked ? {
                        viewModel.discard([file.path])
                    } : nil
                )
            }
        }
    }

    // MARK: - Diff Detail

    private func diffDetailView(viewModel: GitPanelViewModel) -> some View {
        Group {
            if let diff = viewModel.selectedDiff {
                VStack(spacing: 0) {
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
            Text(statusSymbol)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 16)

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

#Preview("FileRow") {
    let staged = FileStatus(path: "Skwad/Views/ContentView.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
    let unstaged = FileStatus(path: "Skwad/Models/Agent.swift", originalPath: nil, stagedStatus: nil, unstagedStatus: .modified)
    let untracked = FileStatus(path: "Skwad/Views/NewView.swift", originalPath: nil, stagedStatus: .untracked, unstagedStatus: .untracked)
    let deleted = FileStatus(path: "Skwad/Old/Removed.swift", originalPath: nil, stagedStatus: .deleted, unstagedStatus: nil)

    VStack(spacing: 0) {
        FileRowView(file: staged, isSelected: true, color: .green, onSelect: {}, onStage: nil, onUnstage: {}, onDiscard: nil)
        FileRowView(file: unstaged, isSelected: false, color: .orange, onSelect: {}, onStage: {}, onUnstage: nil, onDiscard: {})
        FileRowView(file: untracked, isSelected: false, color: .gray, onSelect: {}, onStage: {}, onUnstage: nil, onDiscard: nil)
        FileRowView(file: deleted, isSelected: false, color: .green, onSelect: {}, onStage: nil, onUnstage: {}, onDiscard: nil)
    }
    .frame(width: 400)
}
