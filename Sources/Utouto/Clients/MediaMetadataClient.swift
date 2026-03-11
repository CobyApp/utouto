import Foundation
import AVFoundation
import ComposableArchitecture

/// Single responsibility: load metadata from media URLs (e.g. duration).
/// Keeps AVFoundation usage out of reducers (SRP / DIP).
struct MediaMetadataClient {
    var loadVideoDuration: @Sendable (URL) async throws -> Double
}

extension MediaMetadataClient: DependencyKey {
    static let liveValue: MediaMetadataClient = {
        let impl = MediaMetadataClientLive()
        return MediaMetadataClient(
            loadVideoDuration: { try await impl.loadVideoDuration($0) }
        )
    }()
}

extension DependencyValues {
    var mediaMetadataClient: MediaMetadataClient {
        get { self[MediaMetadataClient.self] }
        set { self[MediaMetadataClient.self] = newValue }
    }
}

private final class MediaMetadataClientLive: @unchecked Sendable {
    func loadVideoDuration(_ url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }
}

