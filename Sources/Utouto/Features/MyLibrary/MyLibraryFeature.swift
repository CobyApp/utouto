import Foundation
import ComposableArchitecture

@Reducer
struct MyLibraryFeature {
    @ObservableState
    struct State: Equatable {
        var clips: [VideoClip] = []
        var isLoading = false
        var playingClipId: UUID?
        var clipEditor: ClipEditorFeature.State?
        var showDeleteAlert = false
        var clipToDelete: VideoClip?
        var uploadingClipId: UUID?
        var errorMessage: String?
    }

    enum Action {
        case onAppear
        case loadClips
        case clipsResponse([VideoClip])
        case playClip(VideoClip)
        case stopPlayback
        case showClipEditor
        case hideClipEditor
        case deleteClip(VideoClip)
        case confirmDelete(VideoClip)
        case hideDeleteAlert
        case uploadClip(VideoClip)
        case uploadResponse(Result<CommunityClip, Error>)
        case clipEditor(ClipEditorFeature.Action)

        @CasePathable
        enum Delegate { case selectClipForAlarm(VideoClip) }
        case delegate(Delegate)
    }

    @Dependency(\.videoClipClient) var videoClipClient
    @Dependency(\.supabaseClipClient) var supabaseClipClient
    @Dependency(\.audioClient) var audioClient
    @Dependency(\.haptic) var haptic

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                return .send(.loadClips)

            case .loadClips:
                state.isLoading = true
                return .run { send in
                    let clips = (try? await videoClipClient.loadClips()) ?? []
                    await send(.clipsResponse(clips))
                }

            case let .clipsResponse(clips):
                state.clips = clips.sorted { $0.createdAt > $1.createdAt }
                state.isLoading = false; return .none

            case let .playClip(clip):
                if state.playingClipId == clip.id {
                    state.playingClipId = nil
                    return .run { _ in await audioClient.stop() }
                }
                state.playingClipId = clip.id
                let url = videoClipClient.audioURL(clip)
                return .run { send in
                    await audioClient.play(url)
                    let dur = clip.durationSec
                    try? await Task.sleep(nanoseconds: UInt64(dur * 1_000_000_000))
                    await send(.stopPlayback)
                }

            case .stopPlayback:
                state.playingClipId = nil; return .none

            case .showClipEditor:
                state.clipEditor = ClipEditorFeature.State()
                return .none

            case .hideClipEditor:
                state.clipEditor = nil
                return .none

            case let .deleteClip(clip):
                state.showDeleteAlert = true; state.clipToDelete = clip; return .none

            case let .confirmDelete(clip):
                state.showDeleteAlert = false; state.clipToDelete = nil
                return .run { send in
                    try? await videoClipClient.deleteClip(clip.id)
                    await send(.loadClips)
                }

            case .hideDeleteAlert:
                state.showDeleteAlert = false; state.clipToDelete = nil; return .none

            case let .uploadClip(clip):
                state.uploadingClipId = clip.id
                let audioURL = videoClipClient.audioURL(clip)
                let thumbURL = videoClipClient.thumbnailURL(clip)
                return .run { send in
                    do {
                        let audio = try Data(contentsOf: audioURL)
                        let thumb = try? Data(contentsOf: thumbURL)
                        let result = try await supabaseClipClient.uploadClip(clip, audio, thumb)
                        await send(.uploadResponse(.success(result)))
                    } catch { await send(.uploadResponse(.failure(error))) }
                }

            case .uploadResponse(.success):
                state.uploadingClipId = nil
                haptic.notification(.success)
                return .send(.loadClips)

            case let .uploadResponse(.failure(err)):
                state.uploadingClipId = nil
                state.errorMessage = err.localizedDescription; return .none

            case .clipEditor(.delegate(.clipSaved(_))):
                state.clipEditor = nil
                return .send(.loadClips)

            case .clipEditor(.delegate(.dismiss)):
                state.clipEditor = nil
                return .none

            case .clipEditor:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.clipEditor, action: \.clipEditor) { ClipEditorFeature() }
    }
}
