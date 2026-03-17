import Foundation
import Supabase

// MARK: - SupabaseClipBackend (DIP: depend on abstraction for testability)
protocol SupabaseClipBackend: AnyObject, Sendable {
    func getCurrentUserId() async -> String
    func fetchClips(page: Int) async throws -> [CommunityClip]
    func uploadClip(_ clip: VideoClip, audioData: Data, thumbData: Data?) async throws -> CommunityClip
    func likeClip(id: UUID) async throws
    func downloadAudio(_ clip: CommunityClip) async throws -> URL
    func incrementDownloadCount(clipId: UUID) async throws
    func searchClips(query: String) async throws -> [CommunityClip]
    func deleteClip(id: UUID) async throws
}

// MARK: - SupabaseService
// Info.plist or環境変数からURL/Keyを取得する想定
// 開発中はここにベタ書き、本番はSecrets管理に移行すること

actor SupabaseService: SupabaseClipBackend {
    static let shared = SupabaseService()

    private let client: SupabaseClient
    private let fm = FileManager.default

    private var docs: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private var downloadsDir: URL { docs.appendingPathComponent("downloads", isDirectory: true) }

    /// Device-scoped user id for "uploaded by me" / delete-only-by-uploader. Stored in UserDefaults.
    private static let deviceUserIdKey = "utouto_device_user_id"

    private init() {
        // Use SUPABASE_URL and SUPABASE_ANON_KEY from Info.plist. Anon key from Supabase Dashboard → Settings → API.
        let supabaseURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "https://your-project.supabase.co")!
        let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? "your-anon-key"
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }

    func getCurrentUserId() async -> String {
        if let existing = UserDefaults.standard.string(forKey: Self.deviceUserIdKey), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: Self.deviceUserIdKey)
        return newId
    }

    // MARK: - Fetch

    func fetchClips(page: Int) async throws -> [CommunityClip] {
        let pageSize = 20
        let from = page * pageSize
        let to = from + pageSize - 1
        let clips: [CommunityClip] = try await client
            .from("community_clips")
            .select()
            .order("created_at", ascending: false)
            .range(from: from, to: to)
            .execute()
            .value
        return clips
    }

    func searchClips(query: String) async throws -> [CommunityClip] {
        let clips: [CommunityClip] = try await client
            .from("community_clips")
            .select()
            .ilike("title", pattern: "%\(query)%")
            .order("like_count", ascending: false)
            .limit(50)
            .execute()
            .value
        return clips
    }

    // MARK: - Upload

    func uploadClip(_ clip: VideoClip, audioData: Data, thumbData: Data?) async throws -> CommunityClip {
        let audioPath = "audio/\(clip.id.uuidString).m4a"
        let thumbPath = "thumbs/\(clip.id.uuidString).jpg"

        // Upload audio
        try await client.storage
            .from("clips")
            .upload(audioPath, data: audioData, options: FileOptions(contentType: "audio/m4a"))

        // Upload thumbnail
        var thumbURL: String? = nil
        if let thumbData = thumbData {
            try await client.storage
                .from("clips")
                .upload(thumbPath, data: thumbData, options: FileOptions(contentType: "image/jpeg"))
            thumbURL = try client.storage.from("clips").getPublicURL(path: thumbPath).absoluteString
        }

        let audioPublicURL = try client.storage.from("clips").getPublicURL(path: audioPath).absoluteString

        // Insert DB row
        struct InsertPayload: Encodable {
            let id: UUID
            let userId: String
            let title: String
            let description: String
            let audioUrl: String
            let thumbnailUrl: String?
            let durationSec: Double
            enum CodingKeys: String, CodingKey {
                case id, userId = "user_id", title, description
                case audioUrl = "audio_url", thumbnailUrl = "thumbnail_url"
                case durationSec = "duration_sec"
            }
        }
        let userId = await getCurrentUserId()
        let payload = InsertPayload(id: clip.id, userId: userId,
                                    title: clip.title, description: "",
                                    audioUrl: audioPublicURL, thumbnailUrl: thumbURL,
                                    durationSec: clip.durationSec)
        let result: CommunityClip = try await client
            .from("community_clips")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return result
    }

    // MARK: - Like

    func likeClip(id: UUID) async throws {
        try await client.rpc("increment_like", params: ["clip_id": id.uuidString]).execute()
    }

    // MARK: - Download

    func downloadAudio(_ clip: CommunityClip) async throws -> URL {
        try fm.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destURL = downloadsDir.appendingPathComponent("\(clip.id.uuidString).m4a")
        if fm.fileExists(atPath: destURL.path) { return destURL }

        guard let url = URL(string: clip.audioUrl) else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        try data.write(to: destURL)
        return destURL
    }

    func incrementDownloadCount(clipId: UUID) async throws {
        try await client.rpc("increment_download_count", params: ["clip_id": clipId.uuidString]).execute()
    }

    // MARK: - Delete

    func deleteClip(id: UUID) async throws {
        try await client.from("community_clips").delete().eq("id", value: id.uuidString).execute()
        _ = try? await client.storage.from("clips").remove(paths: ["audio/\(id.uuidString).m4a"])
        _ = try? await client.storage.from("clips").remove(paths: ["thumbs/\(id.uuidString).jpg"])
    }
}
