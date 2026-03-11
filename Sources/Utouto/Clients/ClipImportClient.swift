import Foundation
import ComposableArchitecture

/// Single responsibility: import a community clip (after download) into local library as VideoClip.
/// Keeps conversion and persistence logic out of AppFeature (SRP).
struct ClipImportClient {
    var importCommunityClip: @Sendable (_ clip: CommunityClip, _ audioURL: URL) async throws -> Void

    /// For tests: inject VideoClipClient so import uses the overridden client.
    static func live(videoClipClient: VideoClipClient) -> ClipImportClient {
        ClipImportClient(
            importCommunityClip: { communityClip, url in
                let clip = VideoClip(
                    id: communityClip.id,
                    title: communityClip.title,
                    sourceVideoFilename: "",
                    audioFilename: url.lastPathComponent,
                    thumbnailFilename: "",
                    startSec: 0,
                    endSec: communityClip.durationSec,
                    durationSec: communityClip.durationSec,
                    createdAt: Date(),
                    isUploaded: true
                )
                try await videoClipClient.saveClip(clip)
            }
        )
    }
}

extension ClipImportClient: DependencyKey {
    static let liveValue = ClipImportClient.live(videoClipClient: .liveValue)
}

extension DependencyValues {
    var clipImportClient: ClipImportClient {
        get { self[ClipImportClient.self] }
        set { self[ClipImportClient.self] = newValue }
    }
}
