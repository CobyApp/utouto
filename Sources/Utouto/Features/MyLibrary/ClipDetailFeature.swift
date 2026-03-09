import Foundation
import ComposableArchitecture

@Reducer
struct ClipDetailFeature {
    @ObservableState
    struct State: Equatable {
        var clip: VideoClip
        var audioFileURL: URL      // ShareLink / play 用に保持
        var isPlaying: Bool = false
        var isUploading: Bool = false
        var showDeleteAlert: Bool = false
        var errorMessage: String?

        init(clip: VideoClip) {
            self.clip = clip
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.audioFileURL = docs
                .appendingPathComponent("clips", isDirectory: true)
                .appendingPathComponent(clip.audioFilename)
        }
    }

    enum Action {
        case togglePlay
        case stopPlayback
        case useAsAlarm
        case uploadToCommunity
        case uploadResponse(Result<VideoClip, Error>)
        case requestDelete
        case confirmDelete
        case cancelDelete
        case dismiss

        @CasePathable
        enum Delegate {
            case dismiss
            case deleted(VideoClip)
            case useAsAlarm(VideoClip)
            case clipUpdated(VideoClip)
        }
        case delegate(Delegate)
    }

    @Dependency(\.audioClient) var audioClient
    @Dependency(\.videoClipClient) var videoClipClient
    @Dependency(\.supabaseClipClient) var supabaseClipClient
    @Dependency(\.haptic) var haptic

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .togglePlay:
                if state.isPlaying {
                    state.isPlaying = false
                    return .run { _ in await audioClient.stop() }
                }
                state.isPlaying = true
                let url = state.audioFileURL
                let dur = state.clip.durationSec
                return .run { send in
                    await audioClient.play(url)
                    try? await Task.sleep(nanoseconds: UInt64(dur * 1_000_000_000))
                    await send(.stopPlayback)
                }

            case .stopPlayback:
                state.isPlaying = false
                return .none

            case .useAsAlarm:
                return .send(.delegate(.useAsAlarm(state.clip)))

            case .uploadToCommunity:
                guard !state.clip.isUploaded else { return .none }
                state.isUploading = true
                state.errorMessage = nil
                let clip = state.clip
                let audioURL = state.audioFileURL
                let thumbURL = videoClipClient.thumbnailURL(clip)
                return .run { send in
                    do {
                        let audio = try Data(contentsOf: audioURL)
                        let thumb = try? Data(contentsOf: thumbURL)
                        let _ = try await supabaseClipClient.uploadClip(clip, audio, thumb)
                        var updated = clip
                        updated.isUploaded = true
                        try? await videoClipClient.saveClip(updated)
                        await send(.uploadResponse(.success(updated)))
                    } catch {
                        await send(.uploadResponse(.failure(error)))
                    }
                }

            case let .uploadResponse(.success(updated)):
                state.isUploading = false
                state.clip = updated
                haptic.notification(.success)
                return .send(.delegate(.clipUpdated(updated)))

            case let .uploadResponse(.failure(err)):
                state.isUploading = false
                state.errorMessage = err.localizedDescription
                haptic.notification(.error)
                return .none

            case .requestDelete:
                state.showDeleteAlert = true
                return .none

            case .confirmDelete:
                state.showDeleteAlert = false
                let clip = state.clip
                return .run { send in
                    try? await videoClipClient.deleteClip(clip.id)
                    await send(.delegate(.deleted(clip)))
                }

            case .cancelDelete:
                state.showDeleteAlert = false
                return .none

            case .dismiss:
                if state.isPlaying {
                    return .run { send in
                        await audioClient.stop()
                        await send(.delegate(.dismiss))
                    }
                }
                return .send(.delegate(.dismiss))

            case .delegate:
                return .none
            }
        }
    }
}
