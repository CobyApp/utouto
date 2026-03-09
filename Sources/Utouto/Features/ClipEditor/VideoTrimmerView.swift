import SwiftUI
import AVFoundation

// MARK: - VideoTrimmerView

struct VideoTrimmerView: View {
    let url: URL
    let duration: Double
    @Binding var startSec: Double
    @Binding var endSec: Double

    @State private var thumbnails: [UIImage] = []

    private let height: CGFloat = 64
    private let handleW: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let trackW = W - handleW * 2
            let sx = handleW + CGFloat(startSec / max(duration, 0.001)) * trackW
            let ex = handleW + CGFloat(endSec   / max(duration, 0.001)) * trackW

            ZStack(alignment: .leading) {
                thumbnailStrip(width: W, trackW: trackW)
                leftDim(sx: sx)
                rightDim(ex: ex, totalW: W)
                selectionBorder(sx: sx, ex: ex)
                leftHandle(sx: sx, trackW: trackW)
                rightHandle(ex: ex, trackW: trackW)
            }
            .coordinateSpace(name: "trimZone")
            .frame(width: W, height: height)
        }
        .frame(height: height)
        .task(id: url.path) { await loadThumbnails() }
    }

    // MARK: Sub-views

    @ViewBuilder
    private func thumbnailStrip(width: CGFloat, trackW: CGFloat) -> some View {
        HStack(spacing: 0) {
            if thumbnails.isEmpty {
                ForEach(0..<10, id: \.self) { _ in
                    Color(.systemGray4)
                        .frame(width: trackW / 10, height: height)
                }
            } else {
                ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, img in
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: trackW / CGFloat(thumbnails.count), height: height)
                        .clipped()
                }
            }
        }
        .frame(width: trackW, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .offset(x: handleW)
    }

    @ViewBuilder
    private func leftDim(sx: CGFloat) -> some View {
        if sx > handleW {
            Color.black.opacity(0.55)
                .frame(width: sx - handleW, height: height)
                .offset(x: handleW)
        }
    }

    @ViewBuilder
    private func rightDim(ex: CGFloat, totalW: CGFloat) -> some View {
        let w = totalW - ex - handleW
        if w > 0 {
            Color.black.opacity(0.55)
                .frame(width: w, height: height)
                .offset(x: ex)
        }
    }

    @ViewBuilder
    private func selectionBorder(sx: CGFloat, ex: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.yellow.frame(height: 3)
            Spacer()
            Color.yellow.frame(height: 3)
        }
        .frame(width: max(0, ex - sx), height: height)
        .offset(x: sx)
        .allowsHitTesting(false)
    }

    private func leftHandle(sx: CGFloat, trackW: CGFloat) -> some View {
        handleShape(isLeft: true)
            .offset(x: sx - handleW)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("trimZone"))
                    .onChanged { v in
                        let sec = Double(v.location.x - handleW) / Double(trackW) * duration
                        startSec = max(0, min(endSec - 1, sec))
                    }
            )
    }

    private func rightHandle(ex: CGFloat, trackW: CGFloat) -> some View {
        handleShape(isLeft: false)
            .offset(x: ex)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("trimZone"))
                    .onChanged { v in
                        let sec = Double(v.location.x - handleW) / Double(trackW) * duration
                        endSec = max(startSec + 1, min(duration, sec))
                    }
            )
    }

    @ViewBuilder
    private func handleShape(isLeft: Bool) -> some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: isLeft ? 6 : 0,
                bottomLeadingRadius: isLeft ? 6 : 0,
                bottomTrailingRadius: isLeft ? 0 : 6,
                topTrailingRadius: isLeft ? 0 : 6
            )
            .fill(Color.yellow)
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 3, height: 10)
                }
            }
        }
        .frame(width: handleW, height: height)
    }

    // MARK: Thumbnail generation

    private func loadThumbnails() async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        guard let dur = try? await asset.load(.duration), dur.seconds > 0 else { return }

        let total = dur.seconds
        let count = 12
        var imgs: [UIImage] = []

        for i in 0..<count {
            let t = i == 0 ? 0.0 : total * Double(i) / Double(count - 1)
            let cmTime = CMTime(seconds: t, preferredTimescale: 600)
            if let result = try? await generator.image(at: cmTime) {
                imgs.append(UIImage(cgImage: result.image))
            }
        }
        await MainActor.run { thumbnails = imgs }
    }
}

// MARK: - VideoFirstFrameView

struct VideoFirstFrameView: View {
    let url: URL
    let atSec: Double
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            Color.black
            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: Int(atSec * 5)) {
            await loadFrame()
        }
    }

    private func loadFrame() async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: atSec, preferredTimescale: 600)
        if let result = try? await generator.image(at: time) {
            await MainActor.run { thumbnail = UIImage(cgImage: result.image) }
        }
    }
}
