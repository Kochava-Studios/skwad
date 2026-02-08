import SwiftUI

struct NewWorktreeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let repo: RepoInfo
    let onComplete: (WorktreeInfo?) -> Void

    @State private var branchName: String = ""
    @State private var destinationPath: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private var suggestedPath: String {
        GitWorktreeManager.shared.suggestedWorktreePath(
            repoPath: repo.path,
            branchName: branchName
        )
    }

    private var canCreate: Bool {
        !branchName.isEmpty && !destinationPath.isEmpty && !isLoading
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
                    LabeledContent("Branch") {
                        TextField("", text: $branchName, prompt: Text("feature/my-feature"))
                            .textFieldStyle(.plain)
                            .onChange(of: branchName) { _, _ in
                                updateDestinationPath()
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
        .frame(width: 450, height: 260)
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
    }

    // MARK: - Actions

    private func updateDestinationPath() {
        if !branchName.isEmpty {
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
                branchName: branchName,
                destinationPath: destinationPath
            )

            let folderName = (destinationPath as NSString).lastPathComponent
            let worktree = WorktreeInfo(
                name: folderName,
                path: destinationPath
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
    NewWorktreeSheet(repo: RepoInfo(name: "skwad", worktrees: [WorktreeInfo(name: "main", path: "/Users/nbonamy/src/skwad")])) { _ in }
}
