import Foundation
import UIKit
import ComposableArchitecture

struct HapticClient {
    var impact: @Sendable (UIImpactFeedbackGenerator.FeedbackStyle) -> Void
    var notification: @Sendable (UINotificationFeedbackGenerator.FeedbackType) -> Void
    var selection: @Sendable () -> Void
}

extension HapticClient: DependencyKey {
    static let liveValue = HapticClient(
        impact: { style in Task { @MainActor in UIImpactFeedbackGenerator(style: style).impactOccurred() } },
        notification: { type in Task { @MainActor in UINotificationFeedbackGenerator().notificationOccurred(type) } },
        selection: { Task { @MainActor in UISelectionFeedbackGenerator().selectionChanged() } }
    )
}

extension DependencyValues {
    var haptic: HapticClient {
        get { self[HapticClient.self] }
        set { self[HapticClient.self] = newValue }
    }
}
