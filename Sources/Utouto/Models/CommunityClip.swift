import Foundation

struct CommunityClip: Identifiable, Codable, Equatable {
    var id: UUID
    var userId: String
    var title: String
    var description: String
    var audioUrl: String
    var thumbnailUrl: String?
    var durationSec: Double
    var likeCount: Int
    var downloadCount: Int
    var createdAt: Date

    // ローカルにダウンロード済みか（UIで使用、DBには保存しない）
    var isDownloaded: Bool = false
    var localClipId: UUID? = nil

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", title, description
        case audioUrl = "audio_url", thumbnailUrl = "thumbnail_url"
        case durationSec = "duration_sec", likeCount = "like_count"
        case downloadCount = "download_count", createdAt = "created_at"
    }
}
