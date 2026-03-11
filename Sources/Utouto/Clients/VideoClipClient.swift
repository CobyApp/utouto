import Foundation
import AVFoundation
import UIKit
import ComposableArchitecture

struct VideoClipClient {
    var loadClips: @Sendable () async throws -> [VideoClip]
    var saveClip: @Sendable (VideoClip) async throws -> Void
    var deleteClip: @Sendable (UUID) async throws -> Void
    var trimAudio: @Sendable (_ sourceURL: URL, _ start: Double, _ end: Double, _ outputId: UUID) async throws -> URL
    var trimVideo: @Sendable (_ sourceURL: URL, _ start: Double, _ end: Double, _ outputId: UUID) async -> URL?
    var generateThumbnail: @Sendable (_ videoURL: URL, _ atTime: Double) async throws -> URL
    var audioURL: @Sendable (VideoClip) -> URL
    var thumbnailURL: @Sendable (VideoClip) -> URL
    var videoURL: @Sendable (VideoClip) -> URL
    var hasVideoFile: @Sendable (VideoClip) -> Bool
}

extension VideoClipClient: DependencyKey {
    static let liveValue: VideoClipClient = {
        let impl = VideoClipClientLive()
        return VideoClipClient(
            loadClips: { try await impl.loadClips() },
            saveClip: { try await impl.saveClip($0) },
            deleteClip: { try await impl.deleteClip($0) },
            trimAudio: { src, s, e, id in try await impl.trimAudio(sourceURL: src, start: s, end: e, outputId: id) },
            trimVideo: { src, s, e, id in await impl.trimVideo(sourceURL: src, start: s, end: e, outputId: id) },
            generateThumbnail: { url, t in try await impl.generateThumbnail(videoURL: url, atTime: t) },
            audioURL: { impl.audioURL(for: $0) },
            thumbnailURL: { impl.thumbnailURL(for: $0) },
            videoURL: { impl.videoURL(for: $0) },
            hasVideoFile: { impl.hasVideoFile(for: $0) }
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
    private var videosDir: URL { docs.appendingPathComponent("videos", isDirectory: true) }
    private var clipsJSON: URL { docs.appendingPathComponent("videoclips.json") }

    private func ensureDirs() throws {
        try fm.createDirectory(at: clipsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: thumbsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: videosDir, withIntermediateDirectories: true)
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
            try? fm.removeItem(at: videoURL(for: clip))
        }
        list.removeAll { $0.id == id }
        try enc.encode(list).write(to: clipsJSON)
    }

    func trimAudio(sourceURL: URL, start: Double, end: Double, outputId: UUID) async throws -> URL {
        try ensureDirs()
        let outURL = clipsDir.appendingPathComponent("\(outputId.uuidString).m4a")

        // 既存ファイルがあれば削除（上書き不可のため）
        try? fm.removeItem(at: outURL)

        let asset = AVURLAsset(url: sourceURL)

        // 音声トラックがあるか確認
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw NSError(domain: "VideoClip", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "動画に音声トラックが含まれていません。音声付きの動画を選んでください。"])
        }

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "VideoClip", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "ExportSession の作成に失敗しました"])
        }
        exporter.outputURL = outURL
        exporter.outputFileType = .m4a

        // 動画の実際の長さに収まるようにクランプ
        let duration = try await asset.load(.duration)
        let clampedEnd = min(end, duration.seconds)
        exporter.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: clampedEnd, preferredTimescale: 600)
        )

        // exportAsynchronously + continuation で確実に完了を待つ
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    cont.resume()
                case .failed, .cancelled:
                    cont.resume(throwing: exporter.error ?? NSError(
                        domain: "VideoClip", code: exporter.status.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: "Export 失敗 (status=\(exporter.status.rawValue))"]
                    ))
                default:
                    cont.resume(throwing: NSError(
                        domain: "VideoClip", code: -99,
                        userInfo: [NSLocalizedDescriptionKey: "Export が予期しない状態で終了 (status=\(exporter.status.rawValue))"]
                    ))
                }
            }
        }

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

    func trimVideo(sourceURL: URL, start: Double, end: Double, outputId: UUID) async -> URL? {
        try? ensureDirs()
        let outURL = videosDir.appendingPathComponent("\(outputId.uuidString).mp4")
        try? fm.removeItem(at: outURL)
        let asset = AVURLAsset(url: sourceURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            return nil
        }
        exporter.outputURL = outURL
        exporter.outputFileType = .mp4
        do {
            let duration = try await asset.load(.duration)
            let clampedEnd = min(end, duration.seconds)
            exporter.timeRange = CMTimeRange(
                start: CMTime(seconds: start, preferredTimescale: 600),
                end: CMTime(seconds: clampedEnd, preferredTimescale: 600)
            )
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                exporter.exportAsynchronously {
                    switch exporter.status {
                    case .completed: cont.resume()
                    default:
                        cont.resume(throwing: exporter.error ?? NSError(
                            domain: "VideoClip", code: exporter.status.rawValue, userInfo: nil
                        ))
                    }
                }
            }
            return outURL
        } catch {
            return nil
        }
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

    nonisolated func videoURL(for clip: VideoClip) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("videos", isDirectory: true)
                   .appendingPathComponent(clip.videoFilename)
    }

    nonisolated func hasVideoFile(for clip: VideoClip) -> Bool {
        FileManager.default.fileExists(atPath: videoURL(for: clip).path)
    }
}
