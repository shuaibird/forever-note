import AppKit

extension NSAttributedString.Key {
    /// Marks code drawn with a rounded background by NoteLayoutManager.
    static let noteCode = NSAttributedString.Key("noteCode")
    /// Marks block quotes drawn with a leading accent bar by NoteLayoutManager.
    static let noteQuote = NSAttributedString.Key("noteQuote")
}

enum CodeKind: Int { case inline, block }

// Live Markdown styling: the text stays plain Markdown, only attributes change.
// The whole note is restyled on every edit, which is cheap at note-sized lengths.
final class MarkdownStyler: NSObject, NSTextStorageDelegate {
    static let fontSize: CGFloat = 14
    static let bodyFont = NSFont.systemFont(ofSize: fontSize)
    static let codeFont = NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
    static let headingSizes: [CGFloat] = [23, 19, 16, 14, 14, 14]
    static let quoteIndent: CGFloat = 12
    static let inlineCodeColor = NSColor.systemPink
    static let markerColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1, alpha: 0.32) : NSColor(white: 0, alpha: 0.24)
    }

    static let paragraph: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.lineHeightMultiple = 1.2
        p.paragraphSpacing = 2
        return p
    }()

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }

    private let fence = regex("^```[^\\n]*\\n[\\s\\S]*?(?:^```[ \\t]*$|\\z)")
    private let inlineCode = regex("(`+)([^`\\n]+?)\\1")
    private let heading = regex("^(#{1,6})[ \\t]+(.*)$")
    private let bold = regex("(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1")
    private let italic = regex("(?<![\\*\\w])([\\*_])(?![\\*_\\s])(.+?)(?<![\\*_\\s])\\1(?![\\*\\w])")
    private let strike = regex("(~~)(?=\\S)(.+?)(?<=\\S)~~")
    private let link = regex("\\[([^\\]\\n]+)\\]\\(([^)\\s]+)\\)")
    private let bareURL = regex("(?<![\\(\\w])https?://[^\\s<>()]+")
    private let quote = regex("^>[ \\t]?.*$")
    private let listMarker = regex("^[ \\t]*(?:[-*+]|\\d+[.)])[ \\t]+")
    private let doneTask = regex("^[ \\t]*[-*+][ \\t]+\\[[xX]\\][ \\t]+.*$")
    private let task = regex("^[ \\t]*[-*+][ \\t]+(\\[[ xX]\\])")
    private let rule = regex("^[ \\t]*([-*_])(?:[ \\t]*\\1){2,}[ \\t]*$")

    func textStorage(_ storage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        style(storage)
    }

    func style(_ s: NSTextStorage) {
        let text = s.string
        let all = NSRange(location: 0, length: s.length)
        let para = Self.paragraph

        s.setAttributes([.font: Self.bodyFont, .foregroundColor: NSColor.labelColor, .paragraphStyle: para], range: all)

        // Code ranges are claimed first so nothing else formats inside them.
        var code: [NSRange] = []
        for m in fence.matches(in: text, range: all) { code.append(m.range) }
        for m in inlineCode.matches(in: text, range: all) where !overlaps(m.range, code) { code.append(m.range) }
        func each(_ re: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
            for m in re.matches(in: text, range: all) where !overlaps(m.range, code) { body(m) }
        }

        each(heading) { m in
            let level = m.range(at: 1).length
            let p = Self.paragraph.mutableCopy() as! NSMutableParagraphStyle
            p.paragraphSpacingBefore = level <= 2 ? 6 : 2
            s.addAttributes([.font: NSFont.systemFont(ofSize: Self.headingSizes[level - 1], weight: .bold),
                             .paragraphStyle: p], range: m.range)
            dim(s, NSRange(location: m.range(at: 1).location, length: m.range(at: 1).length + 1))
        }
        each(quote) { m in
            let p = Self.paragraph.mutableCopy() as! NSMutableParagraphStyle
            p.firstLineHeadIndent = Self.quoteIndent
            p.headIndent = Self.quoteIndent
            s.addAttributes([.foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: p,
                             .noteQuote: true], range: m.range)
            dim(s, NSRange(location: m.range.location, length: 1))
        }
        each(listMarker) { m in
            s.addAttributes([.foregroundColor: NSColor.controlAccentColor,
                             .font: NSFont.systemFont(ofSize: Self.fontSize, weight: .bold)], range: m.range)
        }
        each(task) { m in
            s.addAttributes([.foregroundColor: NSColor.controlAccentColor, .font: Self.codeFont], range: m.range(at: 1))
        }
        each(doneTask) { m in
            s.addAttributes([.foregroundColor: NSColor.tertiaryLabelColor,
                             .strikethroughStyle: NSUnderlineStyle.single.rawValue], range: m.range)
        }
        each(rule) { m in dim(s, m.range) }
        each(bold) { m in
            addTrait(s, .boldFontMask, m.range)
            dimMarkers(s, m, markerLength: 2)
        }
        each(italic) { m in
            addTrait(s, .italicFontMask, m.range)
            dimMarkers(s, m, markerLength: 1)
        }
        each(strike) { m in
            s.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: m.range(at: 2))
            dimMarkers(s, m, markerLength: 2)
        }
        each(link) { m in
            let urlString = (text as NSString).substring(with: m.range(at: 2))
            dim(s, m.range)
            if let url = URL(string: urlString) {
                s.addAttribute(.link, value: url, range: m.range(at: 1))
            }
        }
        each(bareURL) { m in
            if let url = URL(string: (text as NSString).substring(with: m.range)) {
                s.addAttribute(.link, value: url, range: m.range)
            }
        }

        let fences = fence.matches(in: text, range: all)
        for r in code {
            let kind: CodeKind = fences.contains { $0.range == r } ? .block : .inline
            s.setAttributes([.font: Self.codeFont, .foregroundColor: kind == .inline ? Self.inlineCodeColor : NSColor.labelColor,
                             .noteCode: kind.rawValue, .paragraphStyle: para], range: r)
        }
        for m in inlineCode.matches(in: text, range: all) where code.contains(m.range) {
            dim(s, m.range(at: 1))
            dim(s, NSRange(location: NSMaxRange(m.range) - m.range(at: 1).length, length: m.range(at: 1).length))
        }
        for m in fences {
            // Dim the ``` lines themselves.
            let block = (text as NSString).substring(with: m.range) as NSString
            let open = block.range(of: "\n")
            dim(s, NSRange(location: m.range.location, length: open.location))
            let close = block.range(of: "\n```", options: .backwards)
            if close.location != NSNotFound, close.location > open.location {
                dim(s, NSRange(location: m.range.location + close.location + 1, length: m.range.length - close.location - 1))
            }
        }
    }

    private func overlaps(_ r: NSRange, _ ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange($0, r).length > 0 }
    }

    private func dim(_ s: NSTextStorage, _ r: NSRange) {
        s.addAttribute(.foregroundColor, value: Self.markerColor, range: r)
    }

    private func dimMarkers(_ s: NSTextStorage, _ m: NSTextCheckingResult, markerLength: Int) {
        dim(s, NSRange(location: m.range.location, length: markerLength))
        dim(s, NSRange(location: NSMaxRange(m.range) - markerLength, length: markerLength))
    }

    private func addTrait(_ s: NSTextStorage, _ trait: NSFontTraitMask, _ r: NSRange) {
        s.enumerateAttribute(.font, in: r) { value, sub, _ in
            let font = (value as? NSFont) ?? Self.bodyFont
            s.addAttribute(.font, value: NSFontManager.shared.convert(font, toHaveTrait: trait), range: sub)
        }
    }
}

// Draws the rounded code backgrounds and quote bars that plain attributes can't express.
final class NoteLayoutManager: NSLayoutManager {
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage, let container = textContainers.first else { return }
        let chars = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let full = NSRange(location: 0, length: storage.length)
        let padding = container.lineFragmentPadding

        var seen = Set<Int>()
        storage.enumerateAttribute(.noteCode, in: chars) { value, range, _ in
            guard let raw = value as? Int, let kind = CodeKind(rawValue: raw) else { return }
            // Use the whole run so a partial redraw doesn't draw corners mid-block.
            var whole = NSRange()
            _ = storage.attribute(.noteCode, at: range.location, longestEffectiveRange: &whole, in: full)
            guard seen.insert(whole.location).inserted else { return }
            let glyphs = glyphRange(forCharacterRange: whole, actualCharacterRange: nil)

            switch kind {
            case .block:
                NSColor.labelColor.withAlphaComponent(0.07).setFill()
                var rect = NSRect.null
                enumerateLineFragments(forGlyphRange: glyphs) { r, _, _, _, _ in rect = rect.union(r) }
                rect = NSRect(x: rect.minX + padding - 6, y: rect.minY - 2,
                              width: container.size.width - padding * 2 + 12, height: rect.height + 4)
                    .offsetBy(dx: origin.x, dy: origin.y)
                NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            case .inline:
                MarkdownStyler.inlineCodeColor.withAlphaComponent(0.12).setFill()
                enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                        in: container) { r, _ in
                    let rect = r.insetBy(dx: -2, dy: 1).offsetBy(dx: origin.x, dy: origin.y)
                    NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
                }
            }
        }

        NSColor.controlAccentColor.withAlphaComponent(0.8).setFill()
        storage.enumerateAttribute(.noteQuote, in: chars) { value, range, _ in
            guard value != nil else { return }
            // One continuous bar per quote paragraph, including its wrapped lines.
            let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = NSRect.null
            enumerateLineFragments(forGlyphRange: glyphs) { _, used, _, _, _ in rect = rect.union(used) }
            let bar = NSRect(x: padding, y: rect.minY + 2, width: 3, height: rect.height - 4)
            NSBezierPath(roundedRect: bar.offsetBy(dx: origin.x, dy: origin.y), xRadius: 1.5, yRadius: 1.5).fill()
        }
    }
}
