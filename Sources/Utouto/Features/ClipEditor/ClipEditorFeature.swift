import Foundation
import SwiftUI
import AVFoundation
import PhotosUI
import ComposableArchitecture

@Reducer
struct ClipEditorFeature {
    @ObservableState
    struct State: Equatable {
        enum Step: Equatable { case pickVideo, editTimeline, saving, done }
        var step: Step = .pickVideo
        var selectedVideoURL: URL?
        var videoDuration: Double = 0
        var videoTitle: String = ""
        var startSec: Double = 0
        var endSec: Double = 30
        var isPreviewing: Bool = false
        var savedClip: VideoClip?
        var isSaving: Bool = false
        var errorMessage: String?

        var trimDuration: Double { max(0, endSec - startSec) }
        var canSave: Bool { trimDuration >= 1 && trimDuration <= 30 && !videoTitle.isEmpty }
    }

    enum Action {
        case videoSelected(URL?)
        case videoMetadataLoaded(duration: Double)
        case updateTitle(String)
        case updateStart(Double)
        case updateEnd(Double)
        case togglePreview
        case stopPreview
        case saveClip
        case saveResponse(Result<VideoClip, Error>)
        case dismiss

        @CasePathable
        enum Delegate { case dismiss; case clipSaved(VideoClip) }
        case delegate(Delegate)
    }

    @Dependency(\.videoClipClient) var videoClipClient
    @Dependency(\.audioClient) var audioClient
    @Dependency(\.haptic) var haptic

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .videoSelected(url):
                guard let url = url else { return .none }
                state.selectedVideoURL = url
                state.step = .editTimeline
                return .run { send in
                    let asset = AVURLAsset(url: url)
                    let duration = try await asset.load(.duration)
                    await send(.videoMetadataLoaded(duration: duration.seconds))
                }
            case let .videoMetadataLoaded(duration):
                state.videoDuration = duration
                state.startSec = 0
                state.endSec = min(30, duration)
                return .none
            case let .updateTitle(t): state.videoTitle = t; return .none
            case let .updateStart(s):
                state.startSec = max(0, min(s, state.endSec - 1)); return .none
            case let .updateEnd(e):
                state.endSec = min(state.videoDuration, max(e, state.startSec + 1)); return .none
            case .togglePreview:
                guard let url = state.selectedVideoURL else { return .none }
                if state.isPreviewing {
                    state.isPreviewing = false
                    return .run { _ in await audioClient.stop() }
                }
                state.isPreviewing = true
                let s = state.startSec, e = state.endSec
                return .run { send in
                    await audioClient.previewClip(url, s, e)
                    try? await Task.sleep(nanoseconds: UInt64((e - s) * 1_000_000_000))
                    await send(.stopPreview)
                }
            case .stopPreview:
                state.isPreviewing = false; return .none
            case .saveClip:
                guard let url = state.selectedVideoURL, state.canSave else { return .none }
                state.isSaving = true; state.step = .saving
                let s = state.startSec, e = state.endSec, title = state.videoTitle
                return .run { send in
                    do {
                        let clipId = UUID()
                        let audioURL = try await videoClipClient.trimAudio(url, s, e, clipId)
                        let thumbURL = try await videoClipClient.generateThumbnail(url, s)
                        let clip = VideoClip(
                            id: clipId, title: title,
                            sourceVideoFilename: url.lastPathComponent,
                            audioFilename: audioURL.lastPathComponent,
                            thumbnailFilename: thumbURL.lastPathComponent,
                            startSec: s, endSec: e, durationSec: e - s,
                            createdAt: Date(), isUploaded: false
                        )
                        try await videoClipClient.saveClip(clip)
                        await send(.saveResponse(.success(clip)))
                    } catch { await send(.saveResponse(.failure(error))) }
                }
            case let .saveResponse(.success(clip)):
                state.isSaving = false; state.step = .done; state.savedClip = clip
                haptic.notification(.success)
                return .send(.delegate(.clipSaved(clip)))
            case let .saveResponse(.failure(err)):
                state.isSaving = false; state.step = .editTimeline
                state.errorMessage = err.localizedDescription
                return .none
            case .dismiss:
                return .send(.delegate(.dismiss))
            case .delegate:
                return .none
            }
        }
    }
}
