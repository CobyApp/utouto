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
            // スワイプ削除のアラート
            .alert("削除しますか？", isPresented: Binding(
                get: { store.showDeleteAlert },
                set: { _ in store.send(.hideDeleteAlert) }
            ), presenting: store.clipToDelete) { clip in
                Button("削除", role: .destructive) { store.send(.confirmDelete(clip)) }
                Button("キャンセル", role: .cancel) {}
            } message: { _ in
                Text("このクリップを削除します。")
            }
            // クリップ編集シート
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
            // クリップ詳細シート
            .sheet(isPresented: Binding(
                get: { store.clipDetail != nil },
                set: { _ in }
            ), onDismiss: {
                store.send(.hideClipDetail)
            }) {
                if let detailStore = store.scope(state: \.clipDetail, action: \.clipDetail) {
                    ClipDetailView(store: detailStore)
                        .presentationDetents([.large])
                }
            }
            .task { await store.send(.onAppear).finish() }
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60)).foregroundStyle(.secondary)
            Text("クリップがありません")
                .font(.headline).foregroundStyle(.secondary)
            Text("＋ボタンで動画からクリップを作ろう")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { store.send(.showClipEditor) } label: {
                Text("クリップを作成")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.blue).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - List

    private var clipList: some View {
        List {
            ForEach(store.clips) { clip in
                ClipRowView(clip: clip)
                    .contentShape(Rectangle())
                    .onTapGesture { store.send(.showClipDetail(clip)) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.send(.deleteClip(clip))
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Clip Row

struct ClipRowView: View {
    let clip: VideoClip

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(clip.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(clip.durationString)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if clip.isUploaded {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}
