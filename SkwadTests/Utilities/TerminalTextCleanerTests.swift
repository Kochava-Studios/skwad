import XCTest
@testable import Skwad

final class TerminalTextCleanerTests: XCTestCase {

    // MARK: - ANSI Code Stripping

    func testStripsColorCodes() {
        let input = "\u{1b}[31mRed text\u{1b}[0m"
        let result = TerminalTextCleaner.stripAnsiCodes(input)
        XCTAssertEqual(result, "Red text")
    }

    func testStripsBoldCodes() {
        let input = "\u{1b}[1mBold\u{1b}[0m"
        let result = TerminalTextCleaner.stripAnsiCodes(input)
        XCTAssertEqual(result, "Bold")
    }

    func testStripsMultipleColorCodes() {
        let input = "\u{1b}[32mGreen\u{1b}[0m and \u{1b}[34mBlue\u{1b}[0m"
        let result = TerminalTextCleaner.stripAnsiCodes(input)
        XCTAssertEqual(result, "Green and Blue")
    }

    func testStripsCursorMovementCodes() {
        let input = "\u{1b}[2Atext\u{1b}[3B"
        let result = TerminalTextCleaner.stripAnsiCodes(input)
        XCTAssertEqual(result, "text")
    }

    func testPreservesTextWithoutAnsiCodes() {
        let input = "Plain text without codes"
        let result = TerminalTextCleaner.stripAnsiCodes(input)
        XCTAssertEqual(result, input)
    }

    func testStripsOscSequences() {
        let input = "\u{1b}]0;Window Title\u{07}content"
        let result = TerminalTextCleaner.stripAnsiCodes(input)
        XCTAssertEqual(result, "content")
    }

    // MARK: - Trailing Whitespace

    func testTrimsTrailingSpacesFromSingleLine() {
        let input = "text   "
        let result = TerminalTextCleaner.trimTrailingWhitespace(input)
        XCTAssertEqual(result, "text")
    }

    func testTrimsTrailingTabs() {
        let input = "text\t\t"
        let result = TerminalTextCleaner.trimTrailingWhitespace(input)
        XCTAssertEqual(result, "text")
    }

    func testTrimsFromMultipleLines() {
        let input = "line1   \nline2  \nline3\t"
        let result = TerminalTextCleaner.trimTrailingWhitespace(input)
        XCTAssertEqual(result, "line1\nline2\nline3")
    }

    func testPreservesLeadingWhitespace() {
        let input = "   text   "
        let result = TerminalTextCleaner.trimTrailingWhitespace(input)
        XCTAssertEqual(result, "   text")
    }

    func testHandlesEmptyLines() {
        let input = "text\n\nmore"
        let result = TerminalTextCleaner.trimTrailingWhitespace(input)
        XCTAssertEqual(result, "text\n\nmore")
    }

    // MARK: - Blank Lines

    func testCollapsesTripleNewlinesToDouble() {
        let input = "text\n\n\nmore"
        let result = TerminalTextCleaner.collapseBlankLines(input)
        XCTAssertEqual(result, "text\n\nmore")
    }

    func testCollapsesManyNewlinesToDouble() {
        let input = "text\n\n\n\n\n\nmore"
        let result = TerminalTextCleaner.collapseBlankLines(input)
        XCTAssertEqual(result, "text\n\nmore")
    }

    func testPreservesSingleNewlines() {
        let input = "line1\nline2\nline3"
        let result = TerminalTextCleaner.collapseBlankLines(input)
        XCTAssertEqual(result, input)
    }

    func testPreservesDoubleNewlines() {
        let input = "paragraph1\n\nparagraph2"
        let result = TerminalTextCleaner.collapseBlankLines(input)
        XCTAssertEqual(result, input)
    }

    // MARK: - Shell Prompts

    func testStripsDollarPrompt() {
        let input = "$ ls -la"
        let result = TerminalTextCleaner.stripPromptPrefixes(input)
        XCTAssertEqual(result, "ls -la")
    }

    func testStripsHashPrompt() {
        let input = "# sudo apt update"
        let result = TerminalTextCleaner.stripPromptPrefixes(input)
        XCTAssertEqual(result, "sudo apt update")
    }

    func testPreservesIndentation() {
        let input = "  $ git status"
        let result = TerminalTextCleaner.stripPromptPrefixes(input)
        XCTAssertEqual(result, "  git status")
    }

    func testReturnsNilForNonCommandText() {
        let input = "This is just text."
        let result = TerminalTextCleaner.stripPromptPrefixes(input)
        XCTAssertNil(result)
    }

    func testReturnsNilForEmptyInput() {
        let input = "   \n  \n  "
        let result = TerminalTextCleaner.stripPromptPrefixes(input)
        XCTAssertNil(result)
    }

    // MARK: - Command Flattening

    func testFlattensBackslashContinuations() {
        let input = "echo hello \\\nworld"
        let result = TerminalTextCleaner.flattenMultilineCommand(input)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("hello") == true)
        XCTAssertTrue(result?.contains("world") == true)
        XCTAssertFalse(result?.contains("\n") == true)
    }

    func testReturnsNilForSingleLine() {
        let input = "echo hello"
        let result = TerminalTextCleaner.flattenMultilineCommand(input)
        XCTAssertNil(result)
    }

    func testReturnsNilForTooManyLines() {
        let input = (0..<15).map { "line\($0)" }.joined(separator: "\n")
        let result = TerminalTextCleaner.flattenMultilineCommand(input)
        XCTAssertNil(result)
    }

    func testFlattensPipeContinuations() {
        let input = "cat file.txt |\ngrep pattern"
        let result = TerminalTextCleaner.flattenMultilineCommand(input)
        XCTAssertNotNil(result)
    }

    // MARK: - Box Drawing

    func testStripsBoxCharacters() {
        let input = "│ text │"
        let result = TerminalTextCleaner.stripBoxDrawingCharacters(in: input)
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.contains("│") == true)
    }

    func testReturnsNilWhenNoBoxCharacters() {
        let input = "plain text"
        let result = TerminalTextCleaner.stripBoxDrawingCharacters(in: input)
        XCTAssertNil(result)
    }

    func testHandlesMultipleBoxCharacters() {
        let input = "│ line1 │\n│ line2 │"
        let result = TerminalTextCleaner.stripBoxDrawingCharacters(in: input)
        XCTAssertNotNil(result)
    }

    // MARK: - Full Clean

    func testAppliesAllEnabledSettings() {
        var settings = TerminalCopySettings()
        settings.stripAnsiCodes = true
        settings.trimTrailingWhitespace = true

        let input = "\u{1b}[31mRed\u{1b}[0m   "
        let result = TerminalTextCleaner.cleanText(input, settings: settings)
        XCTAssertEqual(result, "Red")
    }

    func testRespectsDisabledSettings() {
        var settings = TerminalCopySettings()
        settings.stripAnsiCodes = false
        settings.trimTrailingWhitespace = false

        let input = "\u{1b}[31mRed\u{1b}[0m   "
        let result = TerminalTextCleaner.cleanText(input, settings: settings)
        XCTAssertEqual(result, input)
    }

    func testAppliesSettingsInCorrectOrder() {
        var settings = TerminalCopySettings()
        settings.stripAnsiCodes = true
        settings.collapseBlankLines = true
        settings.trimTrailingWhitespace = true

        let input = "\u{1b}[32mtext\u{1b}[0m   \n\n\n\nmore   "
        let result = TerminalTextCleaner.cleanText(input, settings: settings)
        XCTAssertEqual(result, "text\n\nmore")
    }

    // MARK: - Settings Defaults

    func testDefaultSettings() {
        let settings = TerminalCopySettings()
        XCTAssertTrue(settings.trimTrailingWhitespace)
        XCTAssertFalse(settings.collapseBlankLines)
        XCTAssertFalse(settings.stripShellPrompts)
        XCTAssertFalse(settings.flattenCommands)
        XCTAssertFalse(settings.removeBoxDrawing)
        XCTAssertTrue(settings.stripAnsiCodes)
    }
}
