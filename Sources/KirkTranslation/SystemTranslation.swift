import Foundation
import Translation

/// 从 Apple 提供的会话翻译文本，宿主负责驱动会话的生命周期。
@available(macOS 15.0, *)
public enum SystemTranslationEngine {
    public enum Phase {
        case needsLanguageDownload
        case translating
    }

    @MainActor public static func translate(
        _ text: String, target: Locale.Language, using session: TranslationSession,
        progress: @MainActor (Phase) -> Void = { _ in }
    ) async throws -> String {
        let status = try? await LanguageAvailability().status(for: text, to: target)
        try Task.checkCancellation()
        progress(status == .supported ? .needsLanguageDownload : .translating)
        let response = try await session.translate(text)
        try Task.checkCancellation()
        return response.targetText
    }
}
