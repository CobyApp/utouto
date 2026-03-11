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
            .navigationTitle("クリップを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if store.step != .saving && store.step != .done {
                        Button("キャンセル") { store.send(.dismiss) }
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Pick Video

    private var pickVideoView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 72))
                .foregroundStyle(.blue.opacity(0.85))
            VStack(spacing: 8) {
                Text("動画を選択").font(.title2.bold())
                Text("フォトライブラリから動画を選んで\nアラームクリップを作成しましょう")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("フォトライブラリを開く")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24).padding(.bottom, 32)
            .onChange(of: selectedVideoItem) { _, item in
                Task {
                    // VideoFileTransferable でファイルを直接コピーして URL を取得。
                    // Data 経由だとメモリ超過・AVAssetExportSession エラーの原因になる。
                    guard let video = try? await item?.loadTransferable(type: VideoFileTransferable.self) else { return }
                    await store.send(.videoSelected(video.url)).finish()
                }
            }
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
                                Label("試聴中", systemImage: "speaker.wave.2.fill")
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
                        Label("トリミング範囲", systemImage: "scissors")
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
                    Label("クリップ名", systemImage: "textformat")
                        .font(.subheadline.weight(.semibold))
                    TextField("例：好きな曲のサビ", text: Binding(
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
                            Text(store.isPreviewing ? "停止" : "試聴")
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
                            Text("保存")
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
            Label(String(format: "%.1f 秒", dur), systemImage: "clock")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
            if dur < 1 {
                Text("最低1秒以上にしてください")
                    .font(.caption).foregroundStyle(.red)
            } else if dur > 30 {
                Text("⚠️ 30秒以内にしてください")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Step 3: Saving

    private var savingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("クリップを保存中...")
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
            Text("保存完了！").font(.title.bold())
            Text("クリップがライブラリに追加されました")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button { store.send(.dismiss) } label: {
                Text("ライブラリへ戻る")
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
