import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ComposableArchitecture

// PhotosPickerItem から動画ファイルを直接コピーして URL を得る Transferable 型。
// Data として読み込む方式だとメモリ超過・フォーマット不一致で
// AVAssetExportSession が失敗するため FileRepresentation を使う。
private struct VideoFileTransferable: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let dest = try FileStorageClient.copyToTemporaryDirectory(source: received.file)
            return Self(url: dest)
        }
    }
}

struct ClipEditorView: View {
    let store: StoreOf<ClipEditorFeature>
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            Group {
                switch store.step {
                case .pickVideo:    pickVideoView
                case .editTimeline: timelineEditorView
                case .saving:       savingView
                case .done:         doneView
                }
            }
            .navigationTitle(L10n.clipCreateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if store.step != .saving && store.step != .done {
                        Button(L10n.cancel) { store.send(.dismiss) }
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Pick Video (Gallery or File — no download; extract audio + segment later)

    private var pickVideoView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 72))
                .foregroundStyle(.blue.opacity(0.85))
            VStack(spacing: 8) {
                Text(L10n.clipPickVideoTitle).font(.title2.bold())
                Text(L10n.clipPickVideoSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            VStack(spacing: 12) {
                PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text(L10n.clipOpenPhotoLibrary)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .onChange(of: selectedVideoItem) { _, item in
                    Task {
                        guard let video = try? await item?.loadTransferable(type: VideoFileTransferable.self) else { return }
                        await store.send(.videoSelected(video.url)).finish()
                    }
                }

                Button {
                    showFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text(L10n.clipOpenFiles)
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        Task {
                            guard url.startAccessingSecurityScopedResource() else {
                                await store.send(.videoSelected(nil)).finish()
                                return
                            }
                            defer { url.stopAccessingSecurityScopedResource() }
                            if let dest = try? FileStorageClient.copyToTemporaryDirectory(source: url) {
                                await store.send(.videoSelected(dest)).finish()
                            } else {
                                await store.send(.videoSelected(nil)).finish()
                            }
                        }
                    case .failure:
                        break
                    }
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 32)
        }
        .padding()
    }

    // MARK: - Step 2: Edit Timeline

    private var timelineEditorView: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Preview frame
                if let url = store.selectedVideoURL {
                    VideoFirstFrameView(url: url, atSec: store.startSec)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            if store.isPreviewing {
                                Label(L10n.clipPreviewing, systemImage: "speaker.wave.2.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.black.opacity(0.6))
                                    .clipShape(Capsule())
                                    .padding(10)
                            }
                        }
                        .padding(.horizontal)
                }

                // Trimmer card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(L10n.clipTrimRange, systemImage: "scissors")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(formatTime(store.startSec)) ~ \(formatTime(store.endSec))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    if let url = store.selectedVideoURL, store.videoDuration > 0 {
                        VideoTrimmerView(
                            url: url,
                            duration: store.videoDuration,
                            startSec: Binding(
                                get: { store.startSec },
                                set: { store.send(.updateStart($0)) }
                            ),
                            endSec: Binding(
                                get: { store.endSec },
                                set: { store.send(.updateEnd($0)) }
                            )
                        )
                        .padding(.horizontal)
                    }

                    // Duration badge
                    durationBadge
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Title input
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.clipNameLabel, systemImage: "textformat")
                        .font(.subheadline.weight(.semibold))
                    TextField(L10n.clipNamePlaceholder, text: Binding(
                        get: { store.videoTitle },
                        set: { store.send(.updateTitle($0)) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                // Action buttons
                HStack(spacing: 12) {
                    Button { store.send(.togglePreview) } label: {
                        HStack {
                            Image(systemName: store.isPreviewing ? "stop.fill" : "play.fill")
                            Text(store.isPreviewing ? L10n.stop : L10n.play)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(store.isPreviewing
                            ? Color.red.opacity(0.12)
                            : Color.blue.opacity(0.1))
                        .foregroundStyle(store.isPreviewing ? .red : .blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button { store.send(.saveClip) } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text(L10n.save)
                        }
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(store.canSave ? Color.green : Color.gray.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!store.canSave || store.isSaving)
                }
                .padding(.horizontal)

                // エラーメッセージ表示
                if let msg = store.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(msg)
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                Spacer().frame(height: 32)
            }
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private var durationBadge: some View {
        let dur = store.trimDuration
        let color: Color = dur < 1 ? .red : dur > 30 ? .orange : .green
        VStack(spacing: 4) {
            Label(String(format: L10n.secondsFormat, dur), systemImage: "clock")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
            if dur < 1 {
                Text(L10n.clipDurationMin)
                    .font(.caption).foregroundStyle(.red)
            } else if dur > 30 {
                Text(L10n.clipDurationMax)
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Step 3: Saving

    private var savingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().controlSize(.large)
            Text(L10n.clipSaving)
                .font(.headline).foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Step 4: Done

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72)).foregroundStyle(.green)
            Text(L10n.clipSaveSuccess).font(.title.bold())
            Text(L10n.clipSaveSuccessSubtitle)
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button { store.send(.dismiss) } label: {
                Text(L10n.clipBackToLibrary)
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24).padding(.bottom, 32)
        }
        .padding()
    }

    // MARK: - Helpers

    private func formatTime(_ secs: Double) -> String {
        let s = Int(secs)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
