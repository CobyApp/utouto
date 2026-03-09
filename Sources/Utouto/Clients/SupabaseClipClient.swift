import Foundation
import ComposableArchitecture

struct SupabaseClipClient {
    var fetchClips: @Sendable (_ page: Int) async throws -> [CommunityClip]
    var uploadClip: @Sendable (_ clip: VideoClip, _ audioData: Data, _ thumbData: Data?) async throws -> CommunityClip
    var likeClip: @Sendable (UUID) async throws -> Void
    var downloadAudio: @Sendable (CommunityClip) async throws -> URL
    var searchClips: @Sendable (String) async throws -> [CommunityClip]
    var deleteClip: @Sendable (UUID) async throws -> Void
}

extension SupabaseClipClient: DependencyKey {
    static let liveValue = SupabaseClipClient(
        fetchClips: { page in try await SupabaseService.shared.fetchClips(page: page) },
        uploadClip: { clip, audio, thumb in try await SupabaseService.shared.uploadClip(clip, audioData: audio, thumbData: thumb) },
        likeClip: { id in try await SupabaseService.shared.likeClip(id: id) },
        downloadAudio: { clip in try await SupabaseService.shared.downloadAudio(clip) },
        searchClips: { q in try await SupabaseService.shared.searchClips(query: q) },
        deleteClip: { id in try await SupabaseService.shared.deleteClip(id: id) }
    )
}

extension DependencyValues {
    var supabaseClipClient: SupabaseClipClient {
        get { self[SupabaseClipClient.self] }
        set { self[SupabaseClipClient.self] = newValue }
    }
}
