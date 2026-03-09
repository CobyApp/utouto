import Foundation
import AVFoundation
import UIKit
import ComposableArchitecture

struct VideoClipClient {
    var loadClips: @Sendable () async throws -> [VideoClip]
    var saveClip: @Sendable (VideoClip) async throws -> Void
    var deleteClip: @Sendable (UUID) async throws -> Void
    var trimAudio: @Sendable (_ sourceURL: URL, _ start: Double, _ end: Double, _ outputId: UUID) async throws -> URL
    var generateThumbnail: @Sendable (_ videoURL: URL, _ atTime: Double) async throws -> URL
    var audioURL: @Sendable (VideoClip) -> URL
    var thumbnailURL: @Sendable (VideoClip) -> URL
}

extension VideoClipClient: DependencyKey {
    static let liveValue: VideoClipClient = {
        let impl = VideoClipClientLive()
        return VideoClipClient(
            loadClips: { try await impl.loadClips() },
            saveClip: { try await impl.saveClip($0) },
            deleteClip: { try await impl.deleteClip($0) },
            trimAudio: { src, s, e, id in try await impl.trimAudio(sourceURL: src, start: s, end: e, outputId: id) },
            generateThumbnail: { url, t in try await impl.generateThumbnail(videoURL: url, atTime: t) },
            audioURL: { impl.audioURL(for: $0) },
            thumbnailURL: { impl.thumbnailURL(for: $0) }
        )
    }()
}

extension DependencyValues {
    var videoClipClient: VideoClipClient {
        get { self[VideoClipClient.self] }
        set { self[VideoClipClient.self] = newValue }
    }
}

private actor VideoClipClientLive {
    private let fm = FileManager.default
    private let enc = JSONEncoder()
    private let dec = JSONDecoder()

    private var docs: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private var clipsDir: URL { docs.appendingPathComponent("clips", isDirectory: true) }
    private var thumbsDir: URL { docs.appendingPathComponent("thumbs", isDirectory: true) }
    private var clipsJSON: URL { docs.appendingPathComponent("videoclips.json") }

    private func ensureDirs() throws {
        try fm.createDirectory(at: clipsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: thumbsDir, withIntermediateDirectories: true)
    }

    func loadClips() async throws -> [VideoClip] {
        guard let data = try? Data(contentsOf: clipsJSON) else { return [] }
        return try dec.decode([VideoClip].self, from: data)
    }

    func saveClip(_ clip: VideoClip) async throws {
        var list = try await loadClips()
        if let i = list.firstIndex(where: { $0.id == clip.id }) { list[i] = clip }
        else { list.append(clip) }
        try enc.encode(list).write(to: clipsJSON)
    }

    func deleteClip(_ id: UUID) async throws {
        var list = try await loadClips()
        if let clip = list.first(where: { $0.id == id }) {
            try? fm.removeItem(at: audioURL(for: clip))
            try? fm.removeItem(at: thumbnailURL(for: clip))
        }
        list.removeAll { $0.id == id }
        try enc.encode(list).write(to: clipsJSON)
    }

    func trimAudio(sourceURL: URL, start: Double, end: Double, outputId: UUID) async throws -> URL {
        try ensureDirs()
        let outURL = clipsDir.appendingPathComponent("\(outputId.uuidString).m4a")
        let asset = AVURLAsset(url: sourceURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "VideoClip", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export session failed"])
        }
        exporter.outputURL = outURL
        exporter.outputFileType = .m4a
        let startTime = CMTime(seconds: start, preferredTimescale: 600)
        let endTime = CMTime(seconds: end, preferredTimescale: 600)
        exporter.timeRange = CMTimeRange(start: startTime, end: endTime)
        await exporter.export()
        if let err = exporter.error { throw err }
        return outURL
    }

    func generateThumbnail(videoURL: URL, atTime: Double) async throws -> URL {
        try ensureDirs()
        let asset = AVURLAsset(url: videoURL)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: atTime, preferredTimescale: 600)
        let cgImage = try await gen.image(at: time).image
        let uiImage = UIImage(cgImage: cgImage)
        let outURL = thumbsDir.appendingPathComponent("\(UUID().uuidString).jpg")
        if let data = uiImage.jpegData(compressionQuality: 0.7) {
            try data.write(to: outURL)
        }
        return outURL
    }

    nonisolated func audioURL(for clip: VideoClip) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("clips", isDirectory: true)
                   .appendingPathComponent(clip.audioFilename)
    }

    nonisolated func thumbnailURL(for clip: VideoClip) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("thumbs", isDirectory: true)
                   .appendingPathComponent(clip.thumbnailFilename)
    }
}
