import Foundation
import ComposableArchitecture

@Reducer
struct AlarmDetailFeature {
    @ObservableState
    struct State: Equatable {
        var alarm: Alarm
        var clipTitle: String?
        var isLoadingClip = false
    }

    enum Action {
        case onAppear
        case clipTitleLoaded(String?)
        case toggleEnabled
        case toggleEnabledResponse(Alarm)

        @CasePathable
        enum Delegate {
            case edit(Alarm)
            case delete(Alarm)
            case dismiss
            case alarmUpdated(Alarm)
        }
        case delegate(Delegate)
    }

    @Dependency(\.videoClipClient) var videoClipClient
    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.alarmKitClient) var alarmKitClient
    @Dependency(\.clock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                guard let clipId = state.alarm.clipId else { return .none }
                state.isLoadingClip = true
                return .run { send in
                    let clips = (try? await videoClipClient.loadClips()) ?? []
                    let title = clips.first { $0.id == clipId }?.title
                    await send(.clipTitleLoaded(title))
                }

            case let .clipTitleLoaded(title):
                state.isLoadingClip = false
                state.clipTitle = title
                return .none

            case .toggleEnabled:
                var updated = state.alarm
                updated.enabled.toggle()
                updated.updatedAt = clock.now()
                state.alarm = updated
                let isEnabled = updated.enabled
                let alarmId = updated.id
                let audioURL: URL? = nil
                return .run { [updated] send in
                    try? await alarmRepository.updateAlarm(updated)
                    if isEnabled {
                        try? await alarmKitClient.scheduleAlarm(updated, audioURL)
                    } else {
                        await alarmKitClient.cancelAlarm(alarmId)
                    }
                    await send(.toggleEnabledResponse(updated))
                }

            case let .toggleEnabledResponse(alarm):
                state.alarm = alarm
                return .send(.delegate(.alarmUpdated(alarm)))

            case .delegate:
                return .none
            }
        }
    }
}
