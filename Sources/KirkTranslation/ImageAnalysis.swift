import Foundation

/// 宿主提供已选定的 PNG、问题和指令。两种客户端分别编码各自的图片请求。
public struct ImageAnalysis {
    public static let maximumPNGBytes = 8 * 1024 * 1024
    public static let maximumQuestionLength = 1_200

    let imageURL: String
    let question: String
    let instructions: String

    public init(png: Data, question: String, instructions: String) throws {
        guard !png.isEmpty, png.count <= Self.maximumPNGBytes,
              question.count <= Self.maximumQuestionLength else { throw CloudTranslation.Failure.inputTooLong }
        self.imageURL = "data:image/png;base64," + png.base64EncodedString()
        self.question = question
        self.instructions = instructions
    }
}
