import Foundation
import AVFoundation
import ComposableArchitecture

struct AudioClient {
    var play: @Sendable (URL) async -> Void
    var stop: @Sendable () async -> Void
    var previewClip: @Sendable (URL, Double, Double) async -> Void
}

extension AudioClient: DependencyKey {
    static let liveValue: AudioClient = {
        let impl = AudioClientLive()
        return AudioClient(
            play: { await impl.play($0) },
            stop: { await impl.stop() },
            previewClip: { url, s, e in await impl.previewClip(url: url, start: s, end: e) }
        )
    }()
}

extension DependencyValues {
    var audioClient: AudioClient {
        get { self[AudioClient.self] }
        set { self[AudioClient.self] = newValue }
    }
}

private actor AudioClientLive: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?     // アラーム再生用（.m4a）
    private var previewPlayer: AVPlayer?   // クリップ試聴用（動画ファイル対応）
    private var stopTask: Task<Void, Never>?

    func play(_ url: URL) async {
        await configureSession()
        previewPlayer?.pause(); previewPlayer = nil
        player?.stop()
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.prepareToPlay(); p.play()
        player = p
    }
    func stop() async {
        stopTask?.cancel(); stopTask = nil
        player?.stop(); player = nil
        previewPlayer?.pause(); previewPlayer = nil
    }
    func previewClip(url: URL, start: Double, end: Double) async {
        await configureSession()
        player?.stop(); player = nil
        previewPlayer?.pause()

        // AVPlayer を使うことで .mov / .mp4 などの動画ファイルも再生可能
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        previewPlayer = avPlayer

        let startTime = CMTime(seconds: start, preferredTimescale: 600)
        await avPlayer.seek(to: startTime)
        avPlayer.play()

        stopTask?.cancel()
        let dur = end - start
        stopTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(dur * 1_000_000_000))
            if !Task.isCancelled { avPlayer.pause() }
        }
    }
    private func configureSession() async {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }
}
