import Testing
@testable import Skwad

@Suite("MarkdownToHTML")
struct MarkdownToHTMLTests {

    // MARK: - Headings

    @Test("converts h1 heading")
    func convertsH1() {
        let result = MarkdownToHTML.convert("# Hello")
        #expect(result.contains("<h1>Hello</h1>"))
    }

    @Test("converts h2 heading")
    func convertsH2() {
        let result = MarkdownToHTML.convert("## World")
        #expect(result.contains("<h2>World</h2>"))
    }

    @Test("converts h3 heading")
    func convertsH3() {
        let result = MarkdownToHTML.convert("### Sub")
        #expect(result.contains("<h3>Sub</h3>"))
    }

    @Test("converts h6 heading")
    func convertsH6() {
        let result = MarkdownToHTML.convert("###### Deep")
        #expect(result.contains("<h6>Deep</h6>"))
    }

    // MARK: - Paragraphs

    @Test("converts paragraph")
    func convertsParagraph() {
        let result = MarkdownToHTML.convert("Hello world")
        #expect(result.contains("<p>Hello world</p>"))
    }

    @Test("merges consecutive lines into one paragraph")
    func mergesConsecutiveLines() {
        let result = MarkdownToHTML.convert("line one\nline two")
        #expect(result.contains("<p>line one line two</p>"))
    }

    // MARK: - Inline formatting

    @Test("converts bold with asterisks")
    func convertsBoldAsterisks() {
        let result = MarkdownToHTML.convert("**bold**")
        #expect(result.contains("<strong>bold</strong>"))
    }

    @Test("converts bold with underscores")
    func convertsBoldUnderscores() {
        let result = MarkdownToHTML.convert("__bold__")
        #expect(result.contains("<strong>bold</strong>"))
    }

    @Test("converts italic with asterisks")
    func convertsItalicAsterisks() {
        let result = MarkdownToHTML.convert("*italic*")
        #expect(result.contains("<em>italic</em>"))
    }

    @Test("converts bold+italic")
    func convertsBoldItalic() {
        let result = MarkdownToHTML.convert("***both***")
        #expect(result.contains("<strong><em>both</em></strong>"))
    }

    @Test("converts strikethrough")
    func convertsStrikethrough() {
        let result = MarkdownToHTML.convert("~~deleted~~")
        #expect(result.contains("<del>deleted</del>"))
    }

    @Test("converts inline code")
    func convertsInlineCode() {
        let result = MarkdownToHTML.convert("`code`")
        #expect(result.contains("<code>code</code>"))
    }

    // MARK: - Links and images

    @Test("converts link")
    func convertsLink() {
        let result = MarkdownToHTML.convert("[text](https://example.com)")
        #expect(result.contains("<a href=\"https://example.com\">text</a>"))
    }

    @Test("converts image")
    func convertsImage() {
        let result = MarkdownToHTML.convert("![alt](image.png)")
        #expect(result.contains("<img src=\"image.png\" alt=\"alt\">"))
    }

    // MARK: - Code blocks

    @Test("converts fenced code block")
    func convertsFencedCodeBlock() {
        let md = "```\nlet x = 1\n```"
        let result = MarkdownToHTML.convert(md)
        #expect(result.contains("<pre><code>let x = 1</code></pre>"))
    }

    @Test("converts fenced code block with language")
    func convertsFencedCodeBlockWithLang() {
        let md = "```swift\nlet x = 1\n```"
        let result = MarkdownToHTML.convert(md)
        #expect(result.contains("class=\"language-swift\""))
        #expect(result.contains("let x = 1"))
    }

    @Test("escapes html in code blocks")
    func escapesHTMLInCodeBlocks() {
        let md = "```\n<div>test</div>\n```"
        let result = MarkdownToHTML.convert(md)
        #expect(result.contains("&lt;div&gt;test&lt;/div&gt;"))
    }

    // MARK: - Lists

    @Test("converts unordered list")
    func convertsUnorderedList() {
        let md = "- item one\n- item two"
        let result = MarkdownToHTML.convert(md)
        #expect(result.contains("<ul>"))
        #expect(result.contains("<li>item one</li>"))
        #expect(result.contains("<li>item two</li>"))
        #expect(result.contains("</ul>"))
    }

    @Test("converts ordered list")
    func convertsOrderedList() {
        let md = "1. first\n2. second"
        let result = MarkdownToHTML.convert(md)
        #expect(result.contains("<ol>"))
        #expect(result.contains("<li>first</li>"))
        #expect(result.contains("<li>second</li>"))
        #expect(result.contains("</ol>"))
    }

    @Test("converts task list unchecked")
    func convertsTaskListUnchecked() {
        let md = "- [ ] todo"
        let result = MarkdownToHTML.convert(md)
        #expect(result.contains("<input type=\"checkbox\" disabled>"))
        #expect(result.contains("todo"))
    }

    @Test("converts task list checked")
    func convertsTaskListChecked() {
        let md = "- [x] done"
        let result = MarkdownToHTML.convert(md)
        #expect(result.contains("<input type=\"checkbox\" checked disabled>"))
        #expect(result.contains("done"))
    }

    // MARK: - Blockquotes

    @Test("converts blockquote")
    func convertsBlockquote() {
        let result = MarkdownToHTML.convert("> quoted text")
        #expect(result.contains("<blockquote>"))
        #expect(result.contains("quoted text"))
        #expect(result.contains("</blockquote>"))
    }

    // MARK: - Horizontal rule

    @Test("converts horizontal rule with dashes")
    func convertsHorizontalRuleDashes() {
        let result = MarkdownToHTML.convert("---")
        #expect(result.contains("<hr>"))
    }

    @Test("converts horizontal rule with asterisks")
    func convertsHorizontalRuleAsterisks() {
        let result = MarkdownToHTML.convert("***")
        #expect(result.contains("<hr>"))
    }

    // MARK: - Tables

    @Test("converts table")
    func convertsTable() {
        let md = "| Col1 | Col2 |\n| --- | --- |\n| a | b |"
        let result = MarkdownToHTML.convert(md)
        #expect(result.contains("<table>"))
        #expect(result.contains("<th>Col1</th>"))
        #expect(result.contains("<th>Col2</th>"))
        #expect(result.contains("<td>a</td>"))
        #expect(result.contains("<td>b</td>"))
        #expect(result.contains("</table>"))
    }

    // MARK: - HTML escaping

    @Test("escapes html in paragraphs")
    func escapesHTMLInParagraphs() {
        let result = MarkdownToHTML.convert("<script>alert('xss')</script>")
        #expect(result.contains("&lt;script&gt;"))
        #expect(!result.contains("<script>"))
    }

    // MARK: - Empty input

    @Test("handles empty string")
    func handlesEmptyString() {
        let result = MarkdownToHTML.convert("")
        #expect(result.isEmpty)
    }

    // MARK: - Mixed content

    @Test("handles heading followed by paragraph")
    func headingThenParagraph() {
        let md = "# Title\n\nSome text here"
        let result = MarkdownToHTML.convert(md)
        #expect(result.contains("<h1>Title</h1>"))
        #expect(result.contains("<p>Some text here</p>"))
    }

    @Test("handles inline formatting in headings")
    func inlineFormattingInHeadings() {
        let result = MarkdownToHTML.convert("## **bold** heading")
        #expect(result.contains("<h2><strong>bold</strong> heading</h2>"))
    }
}
