import SwiftUI
import ComposableArchitecture

struct MyLibraryView: View {
    let store: StoreOf<MyLibraryFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView()
                } else if store.clips.isEmpty {
                    emptyView
                } else {
                    clipList
                }
            }
            .navigationTitle("マイライブラリ")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { store.send(.showClipEditor) } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("削除しますか？", isPresented: Binding(
                get: { store.showDeleteAlert },
                set: { _ in store.send(.hideDeleteAlert) }
            ), presenting: store.clipToDelete) { clip in
                Button("削除", role: .destructive) { store.send(.confirmDelete(clip)) }
            } message: { _ in Text("このクリップを削除します。") }
            .sheet(isPresented: Binding(
                get: { store.clipEditor != nil },
                set: { _ in }
            ), onDismiss: {
                store.send(.hideClipEditor)
            }) {
                if let editorStore = store.scope(state: \.clipEditor, action: \.clipEditor) {
                    ClipEditorView(store: editorStore)
                }
            }
            .task { await store.send(.onAppear).finish() }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60)).foregroundStyle(.secondary)
            Text("クリップがありません").font(.headline).foregroundStyle(.secondary)
            Text("＋ボタンで動画からクリップを作ろう").font(.subheadline).foregroundStyle(.secondary)
            Button { store.send(.showClipEditor) } label: {
                Text("クリップを作成")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.blue).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var clipList: some View {
        List {
            ForEach(store.clips) { clip in
                ClipRowView(
                    clip: clip,
                    isPlaying: store.playingClipId == clip.id,
                    isUploading: store.uploadingClipId == clip.id
                ) {
                    store.send(.playClip(clip))
                } onUpload: {
                    store.send(.uploadClip(clip))
                } onUseAsAlarm: {
                    store.send(.delegate(.selectClipForAlarm(clip)))
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { store.send(.deleteClip(clip)) } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct ClipRowView: View {
    let clip: VideoClip
    let isPlaying: Bool
    let isUploading: Bool
    let onPlay: () -> Void
    let onUpload: () -> Void
    let onUseAsAlarm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 56, height: 56)
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(isPlaying ? .red : .blue)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(clip.title).font(.headline).lineLimit(1)
                Text(clip.durationString)
                    .font(.caption).foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onUseAsAlarm) {
                    Image(systemName: "alarm").foregroundStyle(.orange)
                }
                if isUploading {
                    ProgressView().scaleEffect(0.8)
                } else if !clip.isUploaded {
                    Button(action: onUpload) {
                        Image(systemName: "arrow.up.circle").foregroundStyle(.blue)
                    }
                } else {
                    Image(systemName: "checkmark.icloud.fill").foregroundStyle(.green)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
