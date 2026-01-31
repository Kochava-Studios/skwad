import Foundation

/// Low-level git command runner
class GitCLI {
    static let shared = GitCLI()

    /// Default timeout for git commands (30 seconds)
    private let defaultTimeout: TimeInterval = 30.0

    private init() {}

    /// Result of a git command execution
    struct CommandResult {
        let output: String
        let error: String
        let exitCode: Int32

        var isSuccess: Bool { exitCode == 0 }
    }

    /// Run a git command synchronously
    /// - Parameters:
    ///   - arguments: Git command arguments (without "git" prefix)
    ///   - directory: Working directory for the command
    /// - Returns: Result with output string or GitError
    func run(_ arguments: [String], in directory: String) -> Result<String, GitError> {
        let result = execute(arguments, in: directory)
        if result.isSuccess {
            return .success(result.output)
        } else {
            return .failure(GitError.commandFailed(
                command: "git \(arguments.joined(separator: " "))",
                message: result.error.isEmpty ? result.output : result.error,
                exitCode: result.exitCode
            ))
        }
    }

    /// Run a git command asynchronously
    /// - Parameters:
    ///   - arguments: Git command arguments (without "git" prefix)
    ///   - directory: Working directory for the command
    /// - Returns: Result with output string or GitError
    func runAsync(_ arguments: [String], in directory: String) async -> Result<String, GitError> {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.run(arguments, in: directory)
                continuation.resume(returning: result)
            }
        }
    }

    /// Run a git command and return raw result (for cases where non-zero exit is expected)
    func runRaw(_ arguments: [String], in directory: String) -> CommandResult {
        execute(arguments, in: directory)
    }

    // MARK: - Private

    private func execute(_ arguments: [String], in directory: String) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()

            // Wait with timeout to prevent hanging
            let deadline = Date().addingTimeInterval(defaultTimeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: TimingConstants.gitProcessPollInterval)
            }

            // If still running after timeout, terminate
            if process.isRunning {
                process.terminate()
                return CommandResult(
                    output: "",
                    error: "Command timed out after \(Int(defaultTimeout)) seconds",
                    exitCode: -2
                )
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            return CommandResult(
                output: String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                error: String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                exitCode: process.terminationStatus
            )
        } catch {
            return CommandResult(
                output: "",
                error: error.localizedDescription,
                exitCode: -1
            )
        }
    }
}

// MARK: - Git Errors

enum GitError: LocalizedError {
    case commandFailed(command: String, message: String, exitCode: Int32)
    case timeout(command: String)
    case notARepository
    case invalidPath(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let message, _):
            return "Git command failed: \(command)\n\(message)"
        case .timeout(let command):
            return "Git command timed out: \(command)"
        case .notARepository:
            return "Not a git repository"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        }
    }
}
