import Foundation

struct VideoClip: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var sourceVideoFilename: String   // Documents/videos/ に保存
    var audioFilename: String         // Documents/clips/ にトリム済みm4a
    var thumbnailFilename: String     // Documents/thumbs/
    var startSec: Double
    var endSec: Double
    var durationSec: Double           // endSec - startSec
    var createdAt: Date
    var isUploaded: Bool              // Supabaseにアップロード済みか

    var durationString: String {
        let d = Int(durationSec)
        return String(format: "%d:%02d", d / 60, d % 60)
    }
}
