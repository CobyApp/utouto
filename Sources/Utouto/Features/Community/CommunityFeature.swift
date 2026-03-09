import Foundation
import ComposableArchitecture

@Reducer
struct CommunityFeature {
    @ObservableState
    struct State: Equatable {
        var clips: [CommunityClip] = []
        var isLoading = false
        var isLoadingMore = false
        var currentPage = 0
        var hasMore = true
        var searchQuery = ""
        var isSearching = false
        var playingClipId: UUID?
        var downloadingClipId: UUID?
        var errorMessage: String?
    }

    enum Action {
        case onAppear
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
                guard state.clips.isEmpty else { return .none }
                return .send(.loadFirstPage)

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
                        await send(.downloadResponse(.success((clip, url))))
                    } catch { await send(.downloadResponse(.failure(error))) }
                }

            case let .downloadResponse(.success((clip, url))):
                state.downloadingClipId = nil
                haptic.notification(.success)
                return .send(.delegate(.useClipAsAlarm(url, clip)))

            case let .downloadResponse(.failure(err)):
                state.downloadingClipId = nil
                state.errorMessage = err.localizedDescription; return .none

            case let .likeClip(clip):
                haptic.impact(.light)
                return .run { _ in try? await supabaseClient.likeClip(clip.id) }

            case .delegate: return .none
            }
        }
    }
}
