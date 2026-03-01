import SwiftUI
import WebKit

/// A WKWebView-based markdown renderer with native text selection.
/// On mouseup with selected text, calls `onSelection` with the selected text.
struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    var fontSize: Int = 14
    let backgroundColor: Color
    let isDarkMode: Bool
    var onSelection: (String, CGFloat) -> Void = { _, _ in }  // (text, yPosition)

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "selectionHandler")
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        loadHTML(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onSelection = onSelection
        let markdownChanged = context.coordinator.lastMarkdown != markdown
        let darkModeChanged = context.coordinator.lastDarkMode != isDarkMode
        let fontSizeChanged = context.coordinator.lastFontSize != fontSize

        guard markdownChanged || darkModeChanged || fontSizeChanged else { return }

        context.coordinator.lastMarkdown = markdown
        context.coordinator.lastDarkMode = isDarkMode
        context.coordinator.lastFontSize = fontSize

        if darkModeChanged {
            // Theme changed — full reload needed (CSS is different)
            loadHTML(in: webView)
        } else if fontSizeChanged {
            // Font size changed — update via JS to preserve scroll position
            webView.evaluateJavaScript("document.body.style.fontSize = '\(fontSize)px'") { _, _ in }
        } else {
            // Content changed — update body via JS to preserve scroll position
            let htmlBody = MarkdownToHTML.convert(markdown)
            let escaped = htmlBody
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("document.getElementById('content').innerHTML = `\(escaped)`") { _, _ in }
        }
    }

    private func loadHTML(in webView: WKWebView) {
        let html = buildHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func buildHTML() -> String {
        let htmlBody = MarkdownToHTML.convert(markdown)

        let bgNSColor = NSColor(backgroundColor)
        let bgHex = bgNSColor.hexString

        let textColor = isDarkMode ? "#e0e0e0" : "#1a1a1a"
        let secondaryColor = isDarkMode ? "#a0a0a0" : "#666666"
        let codeBackground = isDarkMode ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.05)"
        let borderColor = isDarkMode ? "rgba(255,255,255,0.15)" : "rgba(0,0,0,0.12)"
        let linkColor = isDarkMode ? "#6bb3f0" : "#0366d6"
        let highlightBg = isDarkMode ? "rgba(100,150,255,0.3)" : "rgba(0,100,255,0.2)"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;
                font-size: \(fontSize)px;
                line-height: 1.6;
                color: \(textColor);
                background-color: \(bgHex);
                padding: 16px;
                -webkit-font-smoothing: antialiased;
            }
            ::selection { background: \(highlightBg); }
            h1, h2, h3, h4, h5, h6 {
                margin-top: 1.2em; margin-bottom: 0.4em;
                font-weight: 600; line-height: 1.3;
            }
            h1 { font-size: 1.6em; }
            h2 { font-size: 1.35em; }
            h3 { font-size: 1.15em; }
            h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
            p { margin-bottom: 0.8em; }
            a { color: \(linkColor); text-decoration: none; }
            a:hover { text-decoration: underline; }
            code {
                font-family: 'SF Mono', Menlo, Monaco, monospace;
                font-size: 0.9em;
                background: \(codeBackground);
                padding: 2px 5px; border-radius: 4px;
            }
            pre {
                background: \(codeBackground);
                border: 1px solid \(borderColor);
                border-radius: 6px;
                padding: 12px; margin: 0.8em 0; overflow-x: auto;
            }
            pre code { background: none; padding: 0; font-size: 0.85em; line-height: 1.5; }
            blockquote {
                border-left: 3px solid \(borderColor);
                padding-left: 12px; color: \(secondaryColor); margin: 0.8em 0;
            }
            ul, ol { margin: 0.5em 0 0.8em 1.5em; }
            li { margin-bottom: 0.3em; }
            li > ul, li > ol { margin-top: 0.2em; margin-bottom: 0.2em; }
            table { border-collapse: collapse; margin: 0.8em 0; width: 100%; }
            th, td { border: 1px solid \(borderColor); padding: 6px 12px; text-align: left; }
            th { font-weight: 600; background: \(codeBackground); }
            hr { border: none; border-top: 1px solid \(borderColor); margin: 1em 0; }
            img { max-width: 100%; }
            input[type="checkbox"] { margin-right: 6px; }
        </style>
        </head>
        <body>
        <div id="content">\(htmlBody)</div>
        <script>
        document.addEventListener('mouseup', function() {
            setTimeout(function() {
                var sel = window.getSelection();
                var text = sel.toString().trim();
                if (text.length > 0) {
                    var range = sel.getRangeAt(0);
                    var rect = range.getBoundingClientRect();
                    window.webkit.messageHandlers.selectionHandler.postMessage({
                        text: text,
                        y: rect.bottom
                    });
                }
            }, 10);
        });
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onSelection: (String, CGFloat) -> Void
        weak var webView: WKWebView?
        var lastMarkdown: String?
        var lastFontSize: Int?
        var lastDarkMode: Bool?

        init(onSelection: @escaping (String, CGFloat) -> Void) {
            self.onSelection = onSelection
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "selectionHandler", let dict = message.body as? [String: Any],
               let text = dict["text"] as? String,
               let y = dict["y"] as? CGFloat {
                DispatchQueue.main.async {
                    self.onSelection(text, y)
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - Markdown to HTML converter

enum MarkdownToHTML {

    static func convert(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        var html = ""
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Fenced code block
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(escapeHTML(lines[i]))
                    i += 1
                }
                let langAttr = lang.isEmpty ? "" : " class=\"language-\(lang)\""
                html += "<pre><code\(langAttr)>\(codeLines.joined(separator: "\n"))</code></pre>\n"
                i += 1
                continue
            }

            // Heading
            if let match = line.prefixMatch(of: /^(#{1,6})\s+(.+)/) {
                let level = match.1.count
                let text = inlineMarkdown(String(match.2))
                html += "<h\(level)>\(text)</h\(level)>\n"
                i += 1
                continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces).range(of: #"^[-*_]{3,}$"#, options: .regularExpression) != nil {
                html += "<hr>\n"
                i += 1
                continue
            }

            // Blockquote
            if line.hasPrefix("> ") || line == ">" {
                var quoteLines: [String] = []
                while i < lines.count && (lines[i].hasPrefix("> ") || lines[i] == ">") {
                    let content = lines[i].hasPrefix("> ") ? String(lines[i].dropFirst(2)) : ""
                    quoteLines.append(content)
                    i += 1
                }
                let inner = convert(quoteLines.joined(separator: "\n"))
                html += "<blockquote>\(inner)</blockquote>\n"
                continue
            }

            // Unordered list
            if line.range(of: #"^\s*[-*+]\s+"#, options: .regularExpression) != nil {
                html += parseList(lines: &lines, index: &i, ordered: false)
                continue
            }

            // Ordered list
            if line.range(of: #"^\s*\d+\.\s+"#, options: .regularExpression) != nil {
                html += parseList(lines: &lines, index: &i, ordered: true)
                continue
            }

            // Table
            if i + 1 < lines.count && lines[i + 1].range(of: #"^\s*\|?\s*[-:]+[-:|  ]+\s*$"#, options: .regularExpression) != nil {
                html += parseTable(lines: &lines, index: &i)
                continue
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }

            // Paragraph
            var paraLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                if l.trimmingCharacters(in: .whitespaces).isEmpty
                    || l.hasPrefix("#") || l.hasPrefix("```")
                    || l.hasPrefix("> ")
                    || l.range(of: #"^\s*[-*+]\s+"#, options: .regularExpression) != nil
                    || l.range(of: #"^\s*\d+\.\s+"#, options: .regularExpression) != nil {
                    break
                }
                paraLines.append(l)
                i += 1
            }
            html += "<p>\(inlineMarkdown(paraLines.joined(separator: "\n")))</p>\n"
        }

        return html
    }

    // MARK: - List parsing

    private static func parseList(lines: inout [String], index: inout Int, ordered: Bool) -> String {
        let tag = ordered ? "ol" : "ul"
        let itemPattern = ordered ? #"^\s*\d+\.\s+"# : #"^\s*[-*+]\s+"#
        var html = "<\(tag)>\n"

        while index < lines.count {
            let line = lines[index]
            guard line.range(of: itemPattern, options: .regularExpression) != nil else { break }

            // Check for task list items
            let content: String
            if let match = line.range(of: itemPattern, options: .regularExpression) {
                content = String(line[match.upperBound...])
            } else {
                content = line
            }

            if content.hasPrefix("[ ] ") {
                html += "<li><input type=\"checkbox\" disabled> \(inlineMarkdown(String(content.dropFirst(4))))</li>\n"
            } else if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
                html += "<li><input type=\"checkbox\" checked disabled> \(inlineMarkdown(String(content.dropFirst(4))))</li>\n"
            } else {
                html += "<li>\(inlineMarkdown(content))</li>\n"
            }
            index += 1
        }

        html += "</\(tag)>\n"
        return html
    }

    // MARK: - Table parsing

    private static func parseTable(lines: inout [String], index: inout Int) -> String {
        var html = "<table>\n"

        // Header row
        let headerCells = parsePipeLine(lines[index])
        html += "<thead><tr>\(headerCells.map { "<th>\(inlineMarkdown($0))</th>" }.joined())</tr></thead>\n"
        index += 1

        // Separator row (skip)
        index += 1

        // Body rows
        html += "<tbody>\n"
        while index < lines.count && lines[index].contains("|") {
            let cells = parsePipeLine(lines[index])
            html += "<tr>\(cells.map { "<td>\(inlineMarkdown($0))</td>" }.joined())</tr>\n"
            index += 1
        }
        html += "</tbody>\n</table>\n"
        return html
    }

    private static func parsePipeLine(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Inline markdown

    private static func inlineMarkdown(_ text: String) -> String {
        var result = escapeHTML(text)

        // Images: ![alt](url)
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^)]+)\)"#,
            with: "<img src=\"$2\" alt=\"$1\">",
            options: .regularExpression
        )

        // Links: [text](url)
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )

        // Bold+italic: ***text*** or ___text___
        result = result.replacingOccurrences(
            of: #"\*\*\*(.+?)\*\*\*"#,
            with: "<strong><em>$1</em></strong>",
            options: .regularExpression
        )

        // Bold: **text** or __text__
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"__(.+?)__"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )

        // Italic: *text* or _text_
        result = result.replacingOccurrences(
            of: #"\*(.+?)\*"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\b_(.+?)_\b"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )

        // Strikethrough: ~~text~~
        result = result.replacingOccurrences(
            of: #"~~(.+?)~~"#,
            with: "<del>$1</del>",
            options: .regularExpression
        )

        // Inline code: `code`
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "<code>$1</code>",
            options: .regularExpression
        )

        // Line breaks
        result = result.replacingOccurrences(of: "  \n", with: "<br>")
        result = result.replacingOccurrences(of: "\n", with: " ")

        return result
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - NSColor hex helper

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
