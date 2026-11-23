import AppKit
import KirkTranslation
import SwiftUI

/// Screenshot 的原文与译文联动交互。宿主传入标题、文案、配对及可选的原文写入方式。
public struct TranslationTextColumns: View {
    private enum Side { case original, translation }
    @State private var hoveredSide: Side?
    @State private var hoveredIndex: Int?
    private let original: String
    private let translation: String
    private let originalTitle: String
    private let translationTitle: String
    private let copyTitle: String
    private let pairs: TranslationSentencePairs?
    private let approximateAlignmentNote: String?
    private let originalHeight: CGFloat
    private let translationCanCopy: Bool
    private let onOriginalEdit: ((String) -> Void)?

    public init(original: String, translation: String, originalTitle: String,
                translationTitle: String, copyTitle: String, pairs: TranslationSentencePairs?,
                approximateAlignmentNote: String? = nil, originalHeight: CGFloat = 112,
                translationCanCopy: Bool = true, onOriginalEdit: ((String) -> Void)? = nil) {
        self.original = original
        self.translation = translation
        self.originalTitle = originalTitle
        self.translationTitle = translationTitle
        self.copyTitle = copyTitle
        self.pairs = pairs
        self.approximateAlignmentNote = approximateAlignmentNote
        self.originalHeight = originalHeight
        self.translationCanCopy = translationCanCopy
        self.onOriginalEdit = onOriginalEdit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if pairs?.isApproximate == true, let approximateAlignmentNote {
                Text(approximateAlignmentNote).font(.caption).foregroundStyle(.secondary)
            }
            column(originalTitle, text: original, side: .original, ranges: pairs?.original ?? [],
                   canCopy: true, onEdit: onOriginalEdit)
                .frame(height: originalHeight)
            column(translationTitle, text: translation, side: .translation, ranges: pairs?.translation ?? [],
                   canCopy: translationCanCopy)
                .frame(maxHeight: .infinity)
        }
        .onChange(of: original) { clearHover() }
        .onChange(of: translation) { clearHover() }
    }

    private func clearHover() {
        hoveredSide = nil
        hoveredIndex = nil
    }

    private func column(_ title: String, text: String, side: Side, ranges: [NSRange], canCopy: Bool,
                        onEdit: ((String) -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button(copyTitle) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .accessibilityLabel(copyTitle + " " + title)
                .disabled(text.isEmpty || !canCopy)
            }
            LinkedTranslationText(
                text: text, sentences: pairs?.canHighlight == true ? ranges : [],
                highlighted: hoveredIndex,
                highlightColor: (side == .original ? NSColor.systemBlue : NSColor.systemOrange).withAlphaComponent(0.28),
                revealHighlight: hoveredSide.map { $0 != side } ?? false, onEdit: onEdit
            ) { index in
                if let index {
                    hoveredSide = side
                    hoveredIndex = index
                } else if hoveredSide == side {
                    clearHover()
                }
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity)
    }
}
