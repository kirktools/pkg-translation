import Foundation
import NaturalLanguage

public struct TranslationSentencePairs {
    public let original: [NSRange]
    public let translation: [NSRange]
    public let originalSentenceCount: Int
    public let translatedSentenceCount: Int
    public let isApproximate: Bool

    public var canHighlight: Bool { !original.isEmpty && original.count == translation.count }

    public init(original source: String, translation target: String) {
        let sourceSentences = Self.sentences(in: source)
        let targetSentences = Self.sentences(in: target)
        originalSentenceCount = sourceSentences.count
        translatedSentenceCount = targetSentences.count
        isApproximate = !sourceSentences.isEmpty && !targetSentences.isEmpty && sourceSentences.count != targetSentences.count
        if isApproximate && sourceSentences.count > targetSentences.count {
            original = Self.group(sourceSentences, against: targetSentences)
            translation = targetSentences
        } else if isApproximate {
            original = sourceSentences
            translation = Self.group(targetSentences, against: sourceSentences)
        } else {
            original = sourceSentences
            translation = targetSentences
        }
    }

    public init(original: [NSRange], translation: [NSRange]) {
        self.original = original
        self.translation = translation
        originalSentenceCount = original.count
        translatedSentenceCount = translation.count
        isApproximate = false
    }

    /// 在句数较多的一侧按相对文本长度选择边界，每组至少保留一句，并保持两边的顺序。
    private static func group(_ sentences: [NSRange], against reference: [NSRange]) -> [NSRange] {
        let total = Double(sentences.reduce(0) { $0 + $1.length })
        let referenceTotal = Double(reference.reduce(0) { $0 + $1.length })
        var groups: [NSRange] = []
        var start = 0
        var cumulative = 0
        var referenceLength = 0
        for (index, segment) in reference.dropLast().enumerated() {
            referenceLength += segment.length
            let boundary = Double(referenceLength) / referenceTotal * total
            let limit = sentences.count - (reference.count - index - 1)
            var end = start + 1
            cumulative += sentences[start].length
            while end < limit {
                let next = cumulative + sentences[end].length
                guard abs(Double(next) - boundary) < abs(Double(cumulative) - boundary) else { break }
                cumulative = next
                end += 1
            }
            groups.append(NSUnionRange(sentences[start], sentences[end - 1]))
            start = end
        }
        groups.append(NSUnionRange(sentences[start], sentences[sentences.count - 1]))
        return groups
    }

    fileprivate static func sentences(in text: String) -> [NSRange] {
        guard !text.isEmpty else { return [] }
        let tokenizer = NLTokenizer(unit: .sentence)
        // OCR 经常把视觉换行当成分句。替换单个硬换行时保持 UTF-16 偏移，供原文高亮使用。
        var normalized = Array(text.utf16)
        for index in normalized.indices where normalized[index] == 10 {
            guard index > 0, index + 1 < normalized.count,
                  normalized[index - 1] != 10, normalized[index + 1] != 10 else { continue }
            normalized[index] = 32
        }
        let content = String(decoding: normalized, as: UTF16.self)
        tokenizer.string = content
        return tokenizer.tokens(for: content.startIndex..<content.endIndex).compactMap { range in
            // NLTokenizer 可能把段落换行包含在前一句范围内。保留原始偏移，但把空白留给句间分隔。
            guard let first = content[range].firstIndex(where: { !$0.isWhitespace }),
                  let last = content[range].lastIndex(where: { !$0.isWhitespace }) else { return nil }
            return NSRange(first..<content.index(after: last), in: content)
        }
    }
}

/// 在同一个翻译请求中保留段落对应关系，显示及复制时剥离分隔符。
public struct SegmentedTranslation {
    private static let separator = "[[SEG]]"
    public let source: String
    public let marker: String?
    private let ranges: [NSRange]
    private let joins: [String]

    public init(source: String, target: String) {
        ranges = TranslationSentencePairs.sentences(in: source)
        let original = source as NSString
        let join = ["zh", "ja"].contains(String(target.prefix(2))) ? "" : " "
        var annotated = ""
        var previous = 0
        var joins: [String] = []
        for range in ranges.dropFirst() {
            annotated += original.substring(with: NSRange(location: previous, length: range.location - previous))
            annotated += Self.separator
            previous = range.location
        }
        annotated += original.substring(from: previous)
        for (left, right) in zip(ranges, ranges.dropFirst()) {
            let gap = original.substring(with: NSRange(location: NSMaxRange(left),
                                                      length: right.location - NSMaxRange(left)))
            joins.append(gap.contains("\n\n") ? "\n\n" : join)
        }
        self.joins = joins
        if ranges.count > 1, !source.contains(Self.separator), annotated.utf8.count <= 12_000 {
            self.source = annotated
            marker = Self.separator
        } else {
            self.source = source
            marker = nil
        }
    }

    public func render(_ output: String, streaming: Bool = false) -> (text: String, pairs: TranslationSentencePairs?) {
        guard let marker else { return (output, nil) }
        var value = output
        if streaming {
            for length in (1..<marker.count).reversed() where value.hasSuffix(marker.prefix(length)) {
                value.removeLast(length)
                break
            }
        }
        let parts = value.components(separatedBy: marker).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var text = ""
        var translated: [NSRange] = []
        for (index, part) in parts.enumerated() {
            if index > 0 { text += joins.indices.contains(index - 1) ? joins[index - 1] : " " }
            let range = NSRange(location: text.utf16.count, length: part.utf16.count)
            text += part
            translated.append(range)
        }
        guard !streaming, translated.count == ranges.count, translated.allSatisfy({ $0.length > 0 }) else {
            return (text, nil)
        }
        return (text, TranslationSentencePairs(original: ranges, translation: translated))
    }
}

