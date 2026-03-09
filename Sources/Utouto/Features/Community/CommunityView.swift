import SwiftUI
import ComposableArchitecture

struct CommunityView: View {
    let store: StoreOf<CommunityFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("クリップを検索...", text: Binding(
                        get: { store.searchQuery },
                        set: { store.send(.updateSearch($0)) }
                    ))
                    .onSubmit { store.send(.submitSearch) }
                    if !store.searchQuery.isEmpty {
                        Button { store.send(.clearSearch) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                if store.isLoading {
                    Spacer(); ProgressView(); Spacer()
                } else if store.clips.isEmpty {
                    emptyView
                } else {
                    clipScrollView
                }
            }
            .navigationTitle("コミュニティ")
            .task { await store.send(.onAppear).finish() }
            .refreshable { store.send(.loadFirstPage) }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "music.note.tv").font(.system(size: 60)).foregroundStyle(.secondary)
            Text(store.isSearching ? "検索結果がありません" : "クリップがありません")
                .font(.headline).foregroundStyle(.secondary)
            if store.isSearching {
                Button { store.send(.clearSearch) } label: {
                    Text("すべて表示").foregroundStyle(.blue)
                }
            }
            Spacer()
        }
    }

    private var clipScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let err = store.errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red).padding()
                }
                ForEach(store.clips) { clip in
                    CommunityClipCardView(
                        clip: clip,
                        isPlaying: store.playingClipId == clip.id,
                        isDownloading: store.downloadingClipId == clip.id
                    ) {
                        store.send(.playClip(clip))
                    } onLike: {
                        store.send(.likeClip(clip))
                    } onDownload: {
                        store.send(.downloadClip(clip))
                    }
                }
                if store.hasMore && !store.isLoadingMore {
                    Button { store.send(.loadMore) } label: {
                        Text("もっと見る").font(.subheadline).foregroundStyle(.blue)
                    }.padding()
                }
                if store.isLoadingMore { ProgressView().padding() }
            }
            .padding()
        }
    }
}

struct CommunityClipCardView: View {
    let clip: CommunityClip
    let isPlaying: Bool
    let isDownloading: Bool
    let onPlay: () -> Void
    let onLike: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onPlay) {
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.12)).frame(width: 52, height: 52)
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.title3).foregroundStyle(.blue)
                    }
                }.buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.title).font(.headline).lineLimit(1)
                    HStack(spacing: 8) {
                        Text(String(format: "%.1f秒", clip.durationSec))
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        Text("·")
                        Text(clip.createdAt, style: .relative)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if !clip.description.isEmpty {
                Text(clip.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }

            Divider()

            HStack(spacing: 20) {
                Button(action: onLike) {
                    Label("\(clip.likeCount)", systemImage: "heart")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Label("\(clip.downloadCount)", systemImage: "arrow.down.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if isDownloading {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button(action: onDownload) {
                        Label("アラームに使う", systemImage: "alarm.fill")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}
