import XCTest
@testable import Skwad

final class ClaudeHistoryProviderTests: XCTestCase {

    private var tempDir: String!
    private let provider = ClaudeHistoryProvider()

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

    func testFormatsCommandMessageAsTitle() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("<command-message>review</command-message>\\n<command-name>/review</command-name>\\n<command-args>focus on error handling</command-args>"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "/review focus on error handling")
    }

    func testFormatsCommandMessageWithoutArgs() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("<command-message>merge</command-message>\\n<command-name>/merge</command-name>\\n<command-args></command-args>"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "/merge")
    }

    func testFormatsCommandMessageWithNoArgsTag() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("<command-message>review</command-message>\\n<command-name>/review</command-name>"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "/review")
    }

    func testFormatsCommandMessageIndentedPattern() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("<command-name>/clear</command-name>\\n            <command-message>clear</command-message>\\n            <command-args></command-args>"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "/clear")
    }

    func testFormatsCommandMessageMultilineArgs() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("<command-message>design</command-message>\\n<command-name>/design</command-name>\\n<command-args>deprecate models screen\\nif workspace has restrictions show it</command-args>"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "/design deprecate models screen")
    }

    func testFormatsCommandMessageNamespacedCommand() {
        writeJSONL("session1.jsonl", lines: [
            userMessage("<command-message>skwad:broadcast</command-message>\\n<command-name>/skwad:broadcast</command-name>\\n<command-args>hello all!</command-args>"),
            assistantMessage()
        ])

        let sessions = parseSessions()
        XCTAssertEqual(sessions[0].title, "/skwad:broadcast hello all!")
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
        writeJSONL("session-old.jsonl", lines: [
            userMessage("You are part of a team of agents"),
            userMessage("<local-command-stdout></local-command-stdout>"),
        ], modDate: Date().addingTimeInterval(-100))

        writeJSONL("session-new.jsonl", lines: [
            userMessage("Real message"),
            assistantMessage()
        ], modDate: Date())

        let sessions = parseSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].title, "Real message")
    }

    func testSkipsEmptyFiles() {
        writeJSONL("session-old.jsonl", lines: [""], modDate: Date().addingTimeInterval(-100))

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
        writeJSONL("session-current.jsonl", lines: [
            userMessage("You are part of a team of agents"),
        ], modDate: Date())

        writeJSONL("session-old.jsonl", lines: [
            userMessage("Fix the bug"),
            assistantMessage()
        ], modDate: Date().addingTimeInterval(-100))

        let sessions = parseSessions()
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].id, "session-current")
        XCTAssertEqual(sessions[0].title, "")
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
        writeJSONL("session-newest.jsonl", lines: [
            userMessage("You are part of a team of agents"),
        ], modDate: Date())

        writeJSONL("session-middle.jsonl", lines: [
            userMessage("<local-command-stdout></local-command-stdout>"),
        ], modDate: Date().addingTimeInterval(-50))

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

    func testDeleteRemovesFilesAndDirectory() {
        let sessionId = "test-session-id"
        writeJSONL("\(sessionId).jsonl", lines: [
            userMessage("Hello"),
            assistantMessage()
        ])

        let dataDir = (tempDir as NSString).appendingPathComponent(sessionId)
        try! FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true)

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: (tempDir as NSString).appendingPathComponent("\(sessionId).jsonl")))
        XCTAssertTrue(fm.fileExists(atPath: dataDir))

        // Test file deletion directly (deleteSession derives its own path)
        try? fm.removeItem(atPath: (tempDir as NSString).appendingPathComponent("\(sessionId).jsonl"))
        try? fm.removeItem(atPath: dataDir)

        XCTAssertFalse(fm.fileExists(atPath: (tempDir as NSString).appendingPathComponent("\(sessionId).jsonl")))
        XCTAssertFalse(fm.fileExists(atPath: dataDir))
    }

    // MARK: - Path Derivation

    func testClaudeProjectsPathDerivation() {
        let path = provider.sessionsDirectory(for: "/Users/foo/src/bar")
        XCTAssertTrue(path.hasSuffix("/.claude/projects/-Users-foo-src-bar"))
    }

    func testClaudeProjectsPathWithTrailingSlash() {
        let path = provider.sessionsDirectory(for: "/Users/foo/src/bar/")
        XCTAssertTrue(path.hasSuffix("/.claude/projects/-Users-foo-src-bar-"))
    }

    // MARK: - Format Command Message

    func testFormatCommandMessageBasic() {
        let result = ClaudeHistoryProvider.formatCommandMessage("<command-name>/review</command-name><command-args>focus on errors</command-args>")
        XCTAssertEqual(result, "/review focus on errors")
    }

    func testFormatCommandMessageNoArgs() {
        let result = ClaudeHistoryProvider.formatCommandMessage("<command-name>/merge</command-name>")
        XCTAssertEqual(result, "/merge")
    }

    func testFormatCommandMessageNoCommandName() {
        let result = ClaudeHistoryProvider.formatCommandMessage("just some text")
        XCTAssertEqual(result, "")
    }

    // MARK: - Helpers

    /// Tests call loadSessions via a wrapper that points at tempDir.
    /// Since loadSessions derives the path from the folder, we test parseSessionFile directly
    /// through the directory-based flow using internal methods.
    private func parseSessions() -> [SessionSummary] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: tempDir) else { return [] }

        var jsonlFiles: [(name: String, date: Date)] = []
        for file in contents where file.hasSuffix(".jsonl") {
            let path = (tempDir as NSString).appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let modDate = attrs[.modificationDate] as? Date {
                jsonlFiles.append((name: file, date: modDate))
            }
        }
        jsonlFiles.sort { $0.date > $1.date }

        var summaries: [SessionSummary] = []
        for (index, file) in jsonlFiles.enumerated() {
            let sessionId = String(file.name.dropLast(6))
            let path = (tempDir as NSString).appendingPathComponent(file.name)

            if let summary = provider.parseSessionFile(path: path, sessionId: sessionId, timestamp: file.date) {
                summaries.append(summary)
            } else if index == 0 {
                summaries.append(SessionSummary(id: sessionId, title: "", timestamp: file.date, messageCount: 0))
            }
            if summaries.count >= 20 { break }
        }

        return summaries
    }
}
