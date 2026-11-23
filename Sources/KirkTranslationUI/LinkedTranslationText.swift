import AppKit
import SwiftUI

public struct LinkedTranslationText: NSViewRepresentable {
    let text: String
    let sentences: [NSRange]
    let highlighted: Int?
    let highlightColor: NSColor
    let revealHighlight: Bool
    let onHover: (Int?) -> Void
    let onEdit: ((String) -> Void)?

    public init(text: String, sentences: [NSRange] = [], highlighted: Int? = nil,
                highlightColor: NSColor = .selectedTextBackgroundColor,
                revealHighlight: Bool = false, onEdit: ((String) -> Void)? = nil,
                onHover: @escaping (Int?) -> Void = { _ in }) {
        self.text = text
        self.sentences = sentences
        self.highlighted = highlighted
        self.highlightColor = highlightColor
        self.revealHighlight = revealHighlight
        self.onEdit = onEdit
        self.onHover = onHover
    }

    public func makeNSView(context: Context) -> NSScrollView { Self.makeScrollView() }

    static func makeScrollView() -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let document = SentenceHoverTextView(frame: .zero)
        document.isRichText = false
        document.isEditable = false
        document.isSelectable = true
        document.drawsBackground = false
        document.font = .systemFont(ofSize: NSFont.systemFontSize)
        document.textColor = .labelColor
        document.textContainerInset = NSSize(width: 3, height: 8)
        document.isHorizontallyResizable = false
        document.isVerticallyResizable = true
        document.autoresizingMask = [.width]
        document.textContainer?.containerSize = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        document.textContainer?.widthTracksTextView = true
        document.frame.size = scroll.contentSize
        scroll.documentView = document
        return scroll
    }

    public func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let document = scroll.documentView as? SentenceHoverTextView else { return }
        document.onHover = onHover
        document.onEdit = onEdit
        document.isEditable = onEdit != nil
        if document.string != text {
            document.updateHighlight(nil, color: highlightColor, reveal: false)
            document.string = text
        }
        let length = document.string.utf16.count
        document.sentences = sentences.map { range in
            guard range.location >= 0, range.location <= length,
                  range.length > 0, range.length <= length - range.location else { return NSRange(location: 0, length: 0) }
            return range
        }
        let range = highlighted.flatMap { document.sentences.indices.contains($0) ? document.sentences[$0] : nil }
            .flatMap { $0.length > 0 ? $0 : nil }
        document.updateHighlight(range, color: highlightColor, reveal: revealHighlight)
    }
}

final class SentenceHoverTextView: NSTextView {
    var sentences: [NSRange] = []
    var onHover: ((Int?) -> Void)?
    var onEdit: ((String) -> Void)?

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        let allowed = super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
        if allowed {
            updateHighlight(nil, color: .clear, reveal: false)
            sentences = []
        }
        return allowed
    }

    override func didChangeText() {
        super.didChangeText()
        onEdit?(string)
    }
    private var tracking: NSTrackingArea?
    private var lastHighlight: NSRange?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .enabledDuringMouseDrag, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
                                  owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }

    override func mouseMoved(with event: NSEvent) {
        guard !sentences.isEmpty, let layoutManager, let textContainer else { onHover?(nil); return }
        let cursor = convert(event.locationInWindow, from: nil)
        let point = CGPoint(x: cursor.x - textContainerOrigin.x, y: cursor.y - textContainerOrigin.y)
        let glyph = layoutManager.glyphIndex(for: point, in: textContainer)
        guard glyph < layoutManager.numberOfGlyphs,
              layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
                .contains(point) else { onHover?(nil); return }
        let character = layoutManager.characterIndexForGlyph(at: glyph)
        onHover?(sentences.firstIndex { NSLocationInRange(character, $0) })
    }

    override func mouseExited(with event: NSEvent) { onHover?(nil) }

    func updateHighlight(_ range: NSRange?, color: NSColor, reveal: Bool) {
        guard range != lastHighlight, let layoutManager else { return }
        if let lastHighlight {
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: lastHighlight)
        }
        lastHighlight = range
        if let range {
            layoutManager.addTemporaryAttribute(.backgroundColor,
                                                value: color,
                                                forCharacterRange: range)
            if reveal {
                layoutManager.ensureLayout(forCharacterRange: range)
                scrollRangeToVisible(range)
            }
        }
    }
}
