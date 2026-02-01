import SwiftUI

struct CommitSheet: View {
    let folder: String
    let onCommit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var commitMessage = ""
    @State private var isCommitting = false
    @State private var errorMessage: String?

    private var repo: GitRepository {
        GitRepository(path: folder)
    }

    private var canCommit: Bool {
        !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCommitting
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Commit Changes")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Enter a commit message for your staged changes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Message input
            VStack(alignment: .leading, spacing: 8) {
                Text("Commit message")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $commitMessage)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                Text("Tip: First line is the subject, leave a blank line before the body")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Error message
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Spacer()
        }
        .frame(width: 450, height: 280)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Commit") {
                    commit()
                }
                .disabled(!canCommit)
            }
        }
    }

    private func commit() {
        isCommitting = true
        errorMessage = nil

        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try repo.commit(message: message)

                DispatchQueue.main.async {
                    onCommit()
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isCommitting = false
                }
            }
        }
    }
}

#Preview {
    CommitSheet(folder: "/Users/nbonamy/src/skwad") {}
}
