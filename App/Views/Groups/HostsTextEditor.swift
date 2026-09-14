import AppKit
import HostsCore
import SwiftUI

/// A code-style editor for hosts text: monospaced, line numbers, syntax colours, and invalid lines flagged in the gutter.
struct HostsTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.font = HostsHighlighter.font
        textView.typingAttributes = [.font: HostsHighlighter.font, .foregroundColor: NSColor.labelColor]
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.ruler = ruler
        context.coordinator.highlight()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView, textView.string != text else { return }
        let selection = textView.selectedRange()
        textView.string = text
        textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        context.coordinator.highlight()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        weak var textView: NSTextView?
        weak var ruler: LineNumberRulerView?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text = textView.string
            highlight()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            ruler?.needsDisplay = true
        }

        func highlight() {
            guard let textView, let storage = textView.textStorage else { return }
            let invalid = HostsHighlighter.apply(to: storage)
            ruler?.invalidLines = invalid
            ruler?.needsDisplay = true
        }
    }
}

@MainActor
enum HostsHighlighter {
    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    /// Recolours the whole document in place and returns the 1-based numbers of invalid lines.
    static func apply(to storage: NSTextStorage) -> Set<Int> {
        let text = storage.string as NSString
        var invalid: Set<Int> = []
        storage.beginEditing()
        storage.setAttributes([.font: font, .foregroundColor: NSColor.labelColor], range: NSRange(location: 0, length: text.length))
        var lineNumber = 0
        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: [.byLines, .substringNotRequired]) { _, range, _, _ in
            lineNumber += 1
            let line = text.substring(with: range)
            switch HostsSyntax.parseLine(line) {
            case .blank:
                break
            case .comment:
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
            case .entry:
                colourEntry(line, at: range.location, in: storage)
            case .invalid:
                invalid.insert(lineNumber)
                storage.addAttribute(.foregroundColor, value: NSColor.systemRed, range: range)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                storage.addAttribute(.underlineColor, value: NSColor.systemRed.withAlphaComponent(0.6), range: range)
            }
        }
        storage.endEditing()
        return invalid
    }

    private static func colourEntry(_ line: String, at start: Int, in storage: NSTextStorage) {
        let nsLine = line as NSString
        let commentStart = nsLine.range(of: "#").location
        let body = commentStart == NSNotFound ? nsLine : nsLine.substring(to: commentStart) as NSString
        if commentStart != NSNotFound {
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: start + commentStart, length: nsLine.length - commentStart))
        }
        let addressRange = body.rangeOfCharacter(from: .whitespaces.inverted)
        guard addressRange.location != NSNotFound else { return }
        let addressEnd = body.rangeOfCharacter(from: .whitespaces, range: NSRange(location: addressRange.location, length: body.length - addressRange.location))
        let addressLength = (addressEnd.location == NSNotFound ? body.length : addressEnd.location) - addressRange.location
        storage.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: NSRange(location: start + addressRange.location, length: addressLength))
    }
}

/// Draws line numbers beside the text and a red marker next to lines the hosts parser rejects.
final class LineNumberRulerView: NSRulerView {
    var invalidLines: Set<Int> = []

    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
        NotificationCenter.default.addObserver(self, selector: #selector(redraw), name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(redraw), name: NSView.boundsDidChangeNotification, object: textView.enclosingScrollView?.contentView)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func redraw() {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer
        else { return }

        NSColor.textBackgroundColor.withAlphaComponent(0.4).setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        let text = textView.string as NSString
        let visibleRect = scrollView?.contentView.bounds ?? .zero
        let inset = textView.textContainerInset.height
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let visibleCharacters = layoutManager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
        let selectedLine = lineNumber(at: textView.selectedRange().location, in: text)

        var lineNumber = lineNumber(at: visibleCharacters.location, in: text)
        var glyphIndex = visibleGlyphs.location
        var characterIndex = visibleCharacters.location
        while characterIndex <= text.length {
            var lineRange = NSRange(location: 0, length: 0)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange, withoutAdditionalLayout: true)
            let lineCharacters = layoutManager.characterRange(forGlyphRange: lineRange, actualGlyphRange: nil)
            let isLineStart = lineCharacters.location == 0 || text.character(at: lineCharacters.location - 1) == 10
            if isLineStart {
                draw(lineNumber, at: fragment.minY + inset - visibleRect.minY, height: fragment.height, isCurrent: lineNumber == selectedLine)
            }
            characterIndex = NSMaxRange(lineCharacters)
            glyphIndex = NSMaxRange(lineRange)
            if characterIndex >= text.length || fragment.maxY > visibleRect.maxY { break }
            if text.character(at: characterIndex - 1) == 10 { lineNumber += 1 }
        }
        if text.length == 0 || text.character(at: text.length - 1) == 10 {
            let extra = layoutManager.extraLineFragmentRect
            let number = text.length == 0 ? 1 : lineNumber + 1
            draw(number, at: extra.minY + inset - visibleRect.minY, height: max(extra.height, numberFont.pointSize + 6), isCurrent: number == selectedLine)
        }
    }

    private func draw(_ number: Int, at y: CGFloat, height: CGFloat, isCurrent: Bool) {
        let isInvalid = invalidLines.contains(number)
        let colour: NSColor = isInvalid ? .systemRed : (isCurrent ? .labelColor : .tertiaryLabelColor)
        let label = NSAttributedString(string: "\(number)", attributes: [.font: numberFont, .foregroundColor: colour])
        let size = label.size()
        label.draw(at: NSPoint(x: ruleThickness - size.width - 12, y: y + (height - size.height) / 2))
        if isInvalid {
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: NSRect(x: ruleThickness - 8, y: y + height / 2 - 2.5, width: 5, height: 5)).fill()
        }
    }

    private func lineNumber(at location: Int, in text: NSString) -> Int {
        var count = 1
        var index = 0
        let limit = min(location, text.length)
        while index < limit {
            if text.character(at: index) == 10 { count += 1 }
            index += 1
        }
        return count
    }
}
