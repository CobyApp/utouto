import Foundation
import ComposableArchitecture

struct SupabaseClipClient {
    var getCurrentUserId: @Sendable () async -> String
    var fetchClips: @Sendable (_ page: Int) async throws -> [CommunityClip]
    var uploadClip: @Sendable (_ clip: VideoClip, _ audioData: Data, _ thumbData: Data?) async throws -> CommunityClip
    var likeClip: @Sendable (UUID) async throws -> Void
    var downloadAudio: @Sendable (CommunityClip) async throws -> URL
    var incrementDownloadCount: @Sendable (UUID) async throws -> Void
    var searchClips: @Sendable (String) async throws -> [CommunityClip]
    var deleteClip: @Sendable (UUID) async throws -> Void

    /// Build client with injectable backend (DIP: tests can pass a mock).
    static func live(backend: SupabaseClipBackend) -> SupabaseClipClient {
        SupabaseClipClient(
            getCurrentUserId: { await backend.getCurrentUserId() },
            fetchClips: { page in try await backend.fetchClips(page: page) },
            uploadClip: { clip, audio, thumb in try await backend.uploadClip(clip, audioData: audio, thumbData: thumb) },
            likeClip: { id in try await backend.likeClip(id: id) },
            downloadAudio: { clip in try await backend.downloadAudio(clip) },
            incrementDownloadCount: { id in try await backend.incrementDownloadCount(clipId: id) },
            searchClips: { q in try await backend.searchClips(query: q) },
            deleteClip: { id in try await backend.deleteClip(id: id) }
        )
    }
}

extension SupabaseClipClient: DependencyKey {
    static let liveValue = SupabaseClipClient.live(backend: SupabaseService.shared)
}

extension DependencyValues {
    var supabaseClipClient: SupabaseClipClient {
        get { self[SupabaseClipClient.self] }
        set { self[SupabaseClipClient.self] = newValue }
    }
}
