import Foundation
import ComposableArchitecture

@Reducer
struct CommunityFeature {
    @ObservableState
    struct State: Equatable {
        var clips: [CommunityClip] = []
        var currentUserId: String = ""
        var isLoading = false
        var isLoadingMore = false
        var currentPage = 0
        var hasMore = true
        var searchQuery = ""
        var isSearching = false
        var playingClipId: UUID?
        var downloadingClipId: UUID?
        var deletingClipId: UUID?
        var errorMessage: String?

        func canDelete(_ clip: CommunityClip) -> Bool {
            !currentUserId.isEmpty && clip.userId == currentUserId
        }
    }

    enum Action {
        case onAppear
        case setCurrentUserId(String)
        case loadFirstPage
        case loadMore
        case clipsResponse(Result<[CommunityClip], Error>, isFirstPage: Bool)
        case updateSearch(String)
        case submitSearch
        case clearSearch
        case playClip(CommunityClip)
        case stopPlayback
        case downloadClip(CommunityClip)
        case downloadResponse(Result<(CommunityClip, URL), Error>)
        case likeClip(CommunityClip)
        case deleteClip(CommunityClip)
        case deleteResponse(Result<Void, Error>)

        @CasePathable
        enum Delegate { case useClipAsAlarm(URL, CommunityClip) }
        case delegate(Delegate)
    }

    @Dependency(\.supabaseClipClient) var supabaseClient
    @Dependency(\.videoClipClient) var videoClipClient
    @Dependency(\.audioClient) var audioClient
    @Dependency(\.haptic) var haptic

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                let isEmpty = state.clips.isEmpty
                return .merge(
                    .run { send in
                        let id = await supabaseClient.getCurrentUserId()
                        await send(.setCurrentUserId(id))
                    },
                    isEmpty ? .send(.loadFirstPage) : .none
                )

            case let .setCurrentUserId(id):
                state.currentUserId = id
                return .none

            case .loadFirstPage:
                state.isLoading = true; state.currentPage = 0; state.hasMore = true
                return .run { send in
                    do {
                        let clips = try await supabaseClient.fetchClips(0)
                        await send(.clipsResponse(.success(clips), isFirstPage: true))
                    } catch { await send(.clipsResponse(.failure(error), isFirstPage: true)) }
                }

            case .loadMore:
                guard !state.isLoadingMore && state.hasMore else { return .none }
                state.isLoadingMore = true
                let nextPage = state.currentPage + 1
                return .run { send in
                    do {
                        let clips = try await supabaseClient.fetchClips(nextPage)
                        await send(.clipsResponse(.success(clips), isFirstPage: false))
                    } catch { await send(.clipsResponse(.failure(error), isFirstPage: false)) }
                }

            case let .clipsResponse(.success(clips), isFirstPage):
                if isFirstPage { state.clips = clips; state.isLoading = false }
                else { state.clips.append(contentsOf: clips); state.isLoadingMore = false; state.currentPage += 1 }
                state.hasMore = clips.count == 20; return .none

            case let .clipsResponse(.failure(err), _):
                state.isLoading = false; state.isLoadingMore = false
                state.errorMessage = err.localizedDescription; return .none

            case let .updateSearch(q):
                state.searchQuery = q; return .none

            case .submitSearch:
                guard !state.searchQuery.isEmpty else { return .send(.clearSearch) }
                state.isSearching = true; state.isLoading = true
                let q = state.searchQuery
                return .run { send in
                    do {
                        let clips = try await supabaseClient.searchClips(q)
                        await send(.clipsResponse(.success(clips), isFirstPage: true))
                    } catch { await send(.clipsResponse(.failure(error), isFirstPage: true)) }
                }

            case .clearSearch:
                state.searchQuery = ""; state.isSearching = false
                return .send(.loadFirstPage)

            case let .playClip(clip):
                if state.playingClipId == clip.id {
                    state.playingClipId = nil
                    return .run { _ in await audioClient.stop() }
                }
                state.playingClipId = clip.id
                return .run { send in
                    do {
                        let url = try await supabaseClient.downloadAudio(clip)
                        await audioClient.play(url)
                        let dur = clip.durationSec
                        try? await Task.sleep(nanoseconds: UInt64(dur * 1_000_000_000))
                        await send(.stopPlayback)
                    } catch { await send(.stopPlayback) }
                }

            case .stopPlayback:
                state.playingClipId = nil; return .none

            case let .downloadClip(clip):
                state.downloadingClipId = clip.id
                return .run { send in
                    do {
                        let url = try await supabaseClient.downloadAudio(clip)
                        try? await supabaseClient.incrementDownloadCount(clip.id)
                        await send(.downloadResponse(.success((clip, url))))
                    } catch { await send(.downloadResponse(.failure(error))) }
                }

            case let .downloadResponse(.success((clip, url))):
                state.downloadingClipId = nil
                if let idx = state.clips.firstIndex(where: { $0.id == clip.id }) {
                    state.clips[idx].downloadCount += 1
                }
                haptic.notification(.success)
                return .send(.delegate(.useClipAsAlarm(url, clip)))

            case let .downloadResponse(.failure(err)):
                state.downloadingClipId = nil
                state.errorMessage = err.localizedDescription; return .none

            case let .likeClip(clip):
                haptic.impact(.light)
                return .run { _ in try? await supabaseClient.likeClip(clip.id) }

            case let .deleteClip(clip):
                guard state.canDelete(clip) else { return .none }
                state.deletingClipId = clip.id
                return .run { send in
                    do {
                        try await supabaseClient.deleteClip(clip.id)
                        await send(.deleteResponse(.success(())))
                    } catch { await send(.deleteResponse(.failure(error))) }
                }

            case let .deleteResponse(.success):
                state.deletingClipId = nil
                haptic.notification(.success)
                return .send(.loadFirstPage)

            case let .deleteResponse(.failure(err)):
                state.deletingClipId = nil
                state.errorMessage = err.localizedDescription
                return .none

            case .delegate: return .none
            }
        }
    }
}
