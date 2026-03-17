import SwiftUI
import AVFoundation
import ComposableArchitecture

// MARK: - LoopingVideoPlayerView

/// AVQueuePlayer + AVPlayerLooper でシームレスループ再生するUIViewRepresentable
struct LoopingVideoPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black

        let player = AVQueuePlayer()
        let item = AVPlayerItem(url: url)
        let looper = AVPlayerLooper(player: player, templateItem: item)

        context.coordinator.player = player
        context.coordinator.looper = looper

        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill

        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?

        deinit {
            player?.pause()
            looper?.disableLooping()
        }
    }
}

/// AVPlayerLayer を持ち、bounds 変化時に自動リサイズするカスタム UIView
final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

// MARK: - RingingFeatureView

struct RingingFeatureView: View {
    let store: StoreOf<RingingFeature>

    var body: some View {
        ZStack {
            // --- 背景 ---
            if let videoURL = store.videoFileURL {
                LoopingVideoPlayerView(url: videoURL)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            // グラデーションオーバーレイ（テキスト可読性のため）
            LinearGradient(
                colors: [.black.opacity(0.25), .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // --- コンテンツ ---
            VStack(spacing: 32) {
                Spacer()

                Text(timeString(from: store.currentTime))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

                Text(store.wakeText)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                Spacer()

                actionButtons

                Spacer()
            }
            .padding()
        }
        .task { await store.send(.onAppear).finish() }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 24) {
            if let alarm = store.alarm, alarm.snoozeEnabled {
                Button { store.send(.snooze) } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "alarm").font(.title2)
                        Text(L10n.snooze).font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 100, height: 80)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            let mode = store.alarm?.dismissMode ?? .slide
            if mode == .slide {
                SlideToWakeView { store.send(.dismiss) }
            } else {
                LongPressWakeView(
                    progress: store.longPressProgress,
                    onProgressChanged: { store.send(.longPressProgressUpdated($0)) },
                    onPressChanged: { store.send(.longPressChanged($0)) }
                )
            }
        }
    }

    private func timeString(from date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

// MARK: - SlideToWakeView

struct SlideToWakeView: View {
    let onDismiss: () -> Void
    @State private var offset: CGFloat = 0
    private let trackWidth: CGFloat = 260
    private let thumbSize: CGFloat = 60

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.ultraThinMaterial)
                .frame(width: trackWidth, height: 64)
                .overlay(
                    Text(L10n.slideToWake)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.leading, thumbSize + 8)
                )
            Circle()
                .fill(Color.green)
                .frame(width: thumbSize, height: thumbSize)
                .overlay(Image(systemName: "chevron.right.2").foregroundStyle(.white).font(.title3))
                .offset(x: 2 + offset)
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            offset = min(max(0, v.translation.width), trackWidth - thumbSize - 4)
                        }
                        .onEnded { _ in
                            let maxOffset = trackWidth - thumbSize - 4
                            if offset > maxOffset * 0.85 { onDismiss() }
                            else { withAnimation(.spring()) { offset = 0 } }
                        }
                )
        }
    }
}

// MARK: - LongPressWakeView

struct LongPressWakeView: View {
    let progress: Double
    let onProgressChanged: (Double) -> Void
    let onPressChanged: (Bool) -> Void
    @State private var timer: Timer?
    private let holdDuration: Double = 2.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 6)
                .frame(width: 120, height: 120)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: progress)
            VStack(spacing: 4) {
                Image(systemName: progress > 0 ? "hand.point.up.fill" : "hand.point.up")
                    .font(.title).foregroundStyle(.white)
                Text(L10n.longPressToWake)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if timer == nil { onPressChanged(true); startTimer() } }
                .onEnded { _ in stopTimer(); onPressChanged(false); onProgressChanged(0) }
        )
    }

    private func startTimer() {
        let step = 0.05; var elapsed = 0.0
        timer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { t in
            elapsed += step
            let p = min(elapsed / holdDuration, 1.0)
            onProgressChanged(p)
            if p >= 1.0 { t.invalidate(); timer = nil }
        }
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }
}
