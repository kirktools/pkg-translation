import Foundation
import KirkTranslation
import XCTest

final class SentencePairsTests: XCTestCase {
    func testSegmentedResponseUsesUTF16RangesAndPreservesParagraphBreak() {
        let original = "Hello 🌍.\n\nGoodbye."
        let request = SegmentedTranslation(source: original, target: "zh-Hans")
        guard let marker = request.marker else { return XCTFail("预期多段请求") }
        let response = request.render("你好 🌍。" + marker + "再见。")
        XCTAssertEqual(response.text, "你好 🌍。\n\n再见。")
        XCTAssertEqual(response.pairs?.original.map { (original as NSString).substring(with: $0).trimmingCharacters(in: .whitespacesAndNewlines) },
                       ["Hello 🌍.", "Goodbye."])
        XCTAssertEqual(response.pairs?.translation.map { (response.text as NSString).substring(with: $0) },
                       ["你好 🌍。", "再见。"])
        let streaming = request.render("你好" + marker.dropLast(), streaming: true)
        XCTAssertEqual(streaming.text, "你好")
        XCTAssertNil(streaming.pairs)
    }
}
