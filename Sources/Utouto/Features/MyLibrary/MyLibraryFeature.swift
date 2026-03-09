import Foundation
import ComposableArchitecture

@Reducer
struct MyLibraryFeature {
    @ObservableState
    struct State: Equatable {
        var clips: [VideoClip] = []
        var isLoading = false
        var clipEditor: ClipEditorFeature.State?
        var clipDetail: ClipDetailFeature.State?
        var showDeleteAlert = false
        var clipToDelete: VideoClip?
        var errorMessage: String?
    }

    enum Action {
        case onAppear
        case loadClips
        case clipsResponse([VideoClip])
        case showClipDetail(VideoClip)
        case hideClipDetail
        case showClipEditor
        case hideClipEditor
        case deleteClip(VideoClip)
        case confirmDelete(VideoClip)
        case hideDeleteAlert
        case clipEditor(ClipEditorFeature.Action)
        case clipDetail(ClipDetailFeature.Action)

        @CasePathable
        enum Delegate { case selectClipForAlarm(VideoClip) }
        case delegate(Delegate)
    }

    @Dependency(\.videoClipClient) var videoClipClient
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
                state.isLoading = false
                return .none

            // MARK: - Clip Detail

            case let .showClipDetail(clip):
                state.clipDetail = ClipDetailFeature.State(clip: clip)
                return .none

            case .hideClipDetail:
                state.clipDetail = nil
                return .none

            case .clipDetail(.delegate(.dismiss)):
                state.clipDetail = nil
                return .none

            case .clipDetail(.delegate(.deleted)):
                state.clipDetail = nil
                return .send(.loadClips)

            case .clipDetail(.delegate(.useAsAlarm(let clip))):
                state.clipDetail = nil
                return .send(.delegate(.selectClipForAlarm(clip)))

            case .clipDetail(.delegate(.clipUpdated)):
                return .send(.loadClips)

            case .clipDetail:
                return .none

            // MARK: - Clip Editor

            case .showClipEditor:
                state.clipEditor = ClipEditorFeature.State()
                return .none

            case .hideClipEditor:
                state.clipEditor = nil
                return .none

            case .clipEditor(.delegate(.clipSaved)):
                state.clipEditor = nil
                return .send(.loadClips)

            case .clipEditor(.delegate(.dismiss)):
                state.clipEditor = nil
                return .none

            case .clipEditor:
                return .none

            // MARK: - Delete (swipe action)

            case let .deleteClip(clip):
                state.showDeleteAlert = true
                state.clipToDelete = clip
                return .none

            case let .confirmDelete(clip):
                state.showDeleteAlert = false
                state.clipToDelete = nil
                return .run { send in
                    try? await videoClipClient.deleteClip(clip.id)
                    await send(.loadClips)
                }

            case .hideDeleteAlert:
                state.showDeleteAlert = false
                state.clipToDelete = nil
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.clipEditor, action: \.clipEditor) { ClipEditorFeature() }
        .ifLet(\.clipDetail, action: \.clipDetail) { ClipDetailFeature() }
    }
}
