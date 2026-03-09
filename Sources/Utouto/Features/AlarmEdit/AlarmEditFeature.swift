import Foundation
import SwiftUI
import ComposableArchitecture

@Reducer
struct AlarmEditFeature {
    @ObservableState
    struct State: Equatable {
        var alarm: Alarm
        var isNew: Bool
        var isSaving = false
        var selectedHour: Int
        var selectedMinute: Int
        var label: String
        var repeatDays: Set<Int>
        var isOneTime = false
        var oneTimeDate: Date
        var snoozeEnabled: Bool
        var snoozeIntervalMin: Int
        var snoozeMaxCount: Alarm.SnoozeMaxCount
        var dismissMode: Alarm.DismissMode
        var selectedClipId: UUID?
        var availableClips: [VideoClip] = []

        var canSave: Bool { true }
        var selectedClip: VideoClip? { availableClips.first { $0.id == selectedClipId } }

        init(alarm: Alarm? = nil) {
            let now = Date()
            if let alarm = alarm {
                self.alarm = alarm; self.isNew = false
                self.selectedHour = alarm.hour; self.selectedMinute = alarm.minute
                self.label = alarm.label; self.repeatDays = Set(alarm.repeatDays)
                self.isOneTime = alarm.oneTimeDate != nil; self.oneTimeDate = alarm.oneTimeDate ?? now
                self.snoozeEnabled = alarm.snoozeEnabled; self.snoozeIntervalMin = alarm.snoozeIntervalMin
                self.snoozeMaxCount = alarm.snoozeMaxCount; self.dismissMode = alarm.dismissMode
                self.selectedClipId = alarm.clipId
            } else {
                let d = Alarm.newDefault()
                self.alarm = d; self.isNew = true
                self.selectedHour = d.hour; self.selectedMinute = d.minute
                self.label = d.label; self.repeatDays = Set(d.repeatDays)
                self.isOneTime = false; self.oneTimeDate = now
                self.snoozeEnabled = true; self.snoozeIntervalMin = 5
                self.snoozeMaxCount = .limited(3); self.dismissMode = .slide
                self.selectedClipId = nil
            }
        }
    }

    enum Action {
        case loadClips; case clipsResponse([VideoClip])
        case updateHour(Int); case updateMinute(Int); case updateLabel(String)
        case toggleRepeatDay(Int); case toggleOneTime; case updateOneTimeDate(Date)
        case selectClip(UUID?); case toggleSnoozeEnabled
        case updateSnoozeInterval(Int); case updateSnoozeMaxCount(Alarm.SnoozeMaxCount)
        case updateDismissMode(Alarm.DismissMode)
        case saveAlarm; case saveResponse; case cancel; case none

        @CasePathable
        enum Delegate { case dismiss; case saveAlarm(Alarm) }
        case delegate(Delegate)
    }

    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.videoClipClient) var videoClipClient
    @Dependency(\.clock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .none: return .none
            case .loadClips:
                return .run { send in
                    let clips = (try? await videoClipClient.loadClips()) ?? []
                    await send(.clipsResponse(clips))
                }
            case let .clipsResponse(clips): state.availableClips = clips; return .none
            case let .updateHour(h): state.selectedHour = h; return .none
            case let .updateMinute(m): state.selectedMinute = m; return .none
            case let .updateLabel(l): state.label = l; return .none
            case let .toggleRepeatDay(d):
                if state.repeatDays.contains(d) { state.repeatDays.remove(d) }
                else { state.repeatDays.insert(d) }
                return .none
            case .toggleOneTime: state.isOneTime.toggle(); return .none
            case let .updateOneTimeDate(d): state.oneTimeDate = d; return .none
            case let .selectClip(id): state.selectedClipId = id; return .none
            case .toggleSnoozeEnabled: state.snoozeEnabled.toggle(); return .none
            case let .updateSnoozeInterval(i): state.snoozeIntervalMin = i; return .none
            case let .updateSnoozeMaxCount(c): state.snoozeMaxCount = c; return .none
            case let .updateDismissMode(m): state.dismissMode = m; return .none
            case .saveAlarm:
                guard state.canSave else { return .none }
                state.isSaving = true
                var a = state.alarm
                a.time = DateComponents(hour: state.selectedHour, minute: state.selectedMinute)
                a.enabled = true; a.repeatDays = Array(state.repeatDays).sorted()
                a.oneTimeDate = state.isOneTime ? state.oneTimeDate : nil
                a.label = state.label; a.clipId = state.selectedClipId
                a.snoozeEnabled = state.snoozeEnabled; a.snoozeIntervalMin = state.snoozeIntervalMin
                a.snoozeMaxCount = state.snoozeMaxCount; a.dismissMode = state.dismissMode
                a.updatedAt = clock.now()
                let isNew = state.isNew
                let audioURL: URL? = state.selectedClip.map { videoClipClient.audioURL($0) }
                return .run { [a, isNew, audioURL] send in
                    do {
                        if isNew { try await alarmRepository.saveAlarm(a) }
                        else { try await alarmRepository.updateAlarm(a) }
                        try await notificationClient.scheduleAlarm(a, audioURL)
                        await send(.saveResponse)
                        await send(.delegate(.saveAlarm(a)))
                    } catch { print("Save error: \(error)") }
                }
            case .saveResponse: state.isSaving = false; return .none
            case .cancel: return .send(.delegate(.dismiss))
            case .delegate: return .none
            }
        }
    }
}
