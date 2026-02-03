import XCTest
import AppKit
@testable import Skwad

final class ClipboardTests: XCTestCase {

    func testCopiesAndReadsString() {
        Clipboard.copy("test string")
        let result = Clipboard.readString()
        XCTAssertEqual(result, "test string")
    }

    func testCopiesLinesWithDefaultSeparator() {
        Clipboard.copy(lines: ["line1", "line2", "line3"])
        let result = Clipboard.readString()
        XCTAssertEqual(result, "line1\nline2\nline3")
    }

    func testCopiesLinesWithCustomSeparator() {
        Clipboard.copy(lines: ["a", "b", "c"], separator: ", ")
        let result = Clipboard.readString()
        XCTAssertEqual(result, "a, b, c")
    }
}
