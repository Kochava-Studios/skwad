import SwiftUI

struct NewWorktreeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let repo: RepoInfo
    let onComplete: (WorktreeInfo?) -> Void

    @State private var branchName: String = ""
    @State private var createNewBranch: Bool = true
    @State private var selectedExistingBranch: String = ""
    @State private var destinationPath: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    @State private var localBranches: [String] = []
    @State private var remoteBranches: [String] = []

    private var effectiveBranchName: String {
        createNewBranch ? branchName : selectedExistingBranch
    }

    private var suggestedPath: String {
        GitWorktreeManager.shared.suggestedWorktreePath(
            repoPath: repo.path,
            branchName: effectiveBranchName
        )
    }

    private var canCreate: Bool {
        !effectiveBranchName.isEmpty && !destinationPath.isEmpty && !isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("New Worktree")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Create a worktree for \(repo.name)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            Form {
                Section {
                    // Branch mode toggle
                    Picker("Branch", selection: $createNewBranch) {
                        Text("New branch").tag(true)
                        Text("Existing branch").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: createNewBranch) { _, _ in
                        updateDestinationPath()
                    }

                    if createNewBranch {
                        // New branch name
                        LabeledContent("Name") {
                            TextField("", text: $branchName, prompt: Text("feature/my-feature"))
                                .textFieldStyle(.plain)
                                .onChange(of: branchName) { _, _ in
                                    updateDestinationPath()
                                }
                        }
                    } else {
                        // Existing branch picker
                        LabeledContent("Branch") {
                            Menu {
                                if !localBranches.isEmpty {
                                    Section("Local") {
                                        ForEach(localBranches, id: \.self) { branch in
                                            Button(branch) {
                                                selectedExistingBranch = branch
                                                updateDestinationPath()
                                            }
                                        }
                                    }
                                }

                                if !remoteBranches.isEmpty {
                                    Section("Remote") {
                                        ForEach(remoteBranches, id: \.self) { branch in
                                            Button(branch) {
                                                selectedExistingBranch = branch
                                                updateDestinationPath()
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedExistingBranch.isEmpty ? "Select branch" : selectedExistingBranch)
                                        .foregroundColor(selectedExistingBranch.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }

                    // Destination path
                    LabeledContent("Folder") {
                        HStack {
                            TextField("", text: $destinationPath)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))

                            Button {
                                browseDestination()
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Error message
                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 320)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onComplete(nil)
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    createWorktree()
                }
                .disabled(!canCreate)
            }
        }
        .onAppear {
            loadBranches()
            updateDestinationPath()
        }
    }

    // MARK: - Actions

    private func loadBranches() {
        localBranches = GitWorktreeManager.shared.listLocalBranches(for: repo.path)
        remoteBranches = GitWorktreeManager.shared.listRemoteBranches(for: repo.path)

        // Filter out branches that already have worktrees
        let existingWorktrees = GitWorktreeManager.shared.listWorktrees(for: repo.path)
        let existingBranches = Set(existingWorktrees.map { $0.branch })

        localBranches = localBranches.filter { !existingBranches.contains($0) }
        remoteBranches = remoteBranches.filter { !existingBranches.contains($0) }
    }

    private func updateDestinationPath() {
        if !effectiveBranchName.isEmpty {
            destinationPath = suggestedPath
        }
    }

    private func browseDestination() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.message = "Choose location for the worktree"
        panel.prompt = "Select"
        panel.nameFieldStringValue = URL(fileURLWithPath: suggestedPath).lastPathComponent

        // Start in parent directory of repo
        let parentDir = (repo.path as NSString).deletingLastPathComponent
        panel.directoryURL = URL(fileURLWithPath: parentDir)

        if panel.runModal() == .OK, let url = panel.url {
            destinationPath = url.path
        }
    }

    private func createWorktree() {
        isLoading = true
        errorMessage = nil

        do {
            try GitWorktreeManager.shared.createWorktree(
                repoPath: repo.path,
                branchName: effectiveBranchName,
                destinationPath: destinationPath,
                createBranch: createNewBranch
            )

            // Return the newly created worktree info
            let worktree = WorktreeInfo(
                path: destinationPath,
                branch: effectiveBranchName,
                isMain: false
            )

            onComplete(worktree)
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    NewWorktreeSheet(repo: RepoInfo(name: "skwad", path: "/Users/nbonamy/src/skwad", worktreeCount: 2)) { _ in }
}
