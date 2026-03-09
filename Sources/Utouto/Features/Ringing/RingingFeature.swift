import Foundation
import SwiftUI
import ComposableArchitecture

@Reducer
struct RingingFeature {
    @ObservableState
    struct State: Equatable {
        let alarmId: UUID
        var alarm: Alarm?
        var clip: VideoClip?
        var currentTime = Date()
        var wakeText: String = ""
        var isPlaying = false
        var snoozeCount = 0
        var longPressProgress: Double = 0
        var isLongPressing = false

        init(alarmId: UUID) {
            self.alarmId = alarmId
            self.wakeText = Self.randomWakeText()
        }

        static func randomWakeText() -> String {
            ["おはよう…起きようか", "時間だよ！", "もう起きる時間だよ〜",
             "早く起きなさい！", "素敵な朝だね"].randomElement()!
        }
    }

    enum Action {
        case onAppear
        case loadAlarm
        case alarmResponse(Alarm?)
        case clipResponse(VideoClip?)
        case updateTime
        case playWakeSound
        case snooze
        case dismiss
        case stopAudio
        case longPressChanged(Bool)
        case longPressProgressUpdated(Double)

        @CasePathable
        enum Delegate { case dismiss }
        case delegate(Delegate)
    }

    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.videoClipClient) var videoClipClient
    @Dependency(\.audioClient) var audioClient
    @Dependency(\.haptic) var haptic
    @Dependency(\.clock) var clock
    @Dependency(\.logger) var logger

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .send(.loadAlarm),
                    .send(.playWakeSound),
                    .run { send in
                        while true {
                            try await Task.sleep(nanoseconds: 1_000_000_000)
                            await send(.updateTime)
                        }
                    }
                )
            case .loadAlarm:
                return .run { [alarmId = state.alarmId] send in
                    do {
                        let alarms = try await alarmRepository.loadAlarms()
                        let alarm = alarms.first { $0.id == alarmId }
                        await send(.alarmResponse(alarm))
                        if let clipId = alarm?.clipId,
                           let clips = try? await videoClipClient.loadClips(),
                           let clip = clips.first(where: { $0.id == clipId }) {
                            await send(.clipResponse(clip))
                        }
                    } catch {
                        logger.error("Failed to load alarm: \(error)")
                        await send(.alarmResponse(nil))
                    }
                }
            case let .alarmResponse(alarm):
                state.alarm = alarm
                return .none
            case let .clipResponse(clip):
                state.clip = clip
                return .none
            case .updateTime:
                state.currentTime = clock.now()
                return .none
            case .playWakeSound:
                state.isPlaying = true
                haptic.notification(.warning)
                return .run { [clip = state.clip] _ in
                    if let clip = clip {
                        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let url = docs.appendingPathComponent("clips").appendingPathComponent(clip.audioFilename)
                        await audioClient.play(url)
                    }
                }
            case .snooze:
                guard let alarm = state.alarm else { return .none }
                state.snoozeCount += 1
                let snoozeTime = clock.now().addingTimeInterval(TimeInterval(alarm.snoozeIntervalMin * 60))
                var snoozeAlarm = alarm
                snoozeAlarm.id = UUID()
                snoozeAlarm.time = Calendar.current.dateComponents([.hour, .minute], from: snoozeTime)
                snoozeAlarm.oneTimeDate = snoozeTime
                snoozeAlarm.repeatDays = []
                haptic.impact(.medium)
                return .merge(
                    .run { send in await audioClient.stop(); await send(.stopAudio) },
                    .run { [snoozeAlarm, alarm, firedAt = clock.now(), sc = state.snoozeCount] _ in
                        do {
                            try await alarmRepository.saveAlarm(snoozeAlarm)
                            let log = AlarmLog(id: UUID(), alarmId: alarm.id, firedAt: firedAt,
                                              dismissedAt: nil, snoozeCount: sc, result: .snoozed)
                            try await alarmRepository.saveAlarmLog(log)
                        } catch { logger.error("Snooze error: \(error)") }
                    },
                    .send(.delegate(.dismiss))
                )
            case .dismiss:
                haptic.notification(.success)
                return .merge(
                    .run { send in await audioClient.stop(); await send(.stopAudio) },
                    .run { [alarm = state.alarm, now = clock.now(), sc = state.snoozeCount] _ in
                        if let alarm = alarm {
                            let log = AlarmLog(id: UUID(), alarmId: alarm.id, firedAt: now,
                                              dismissedAt: now, snoozeCount: sc, result: .dismissed)
                            try? await alarmRepository.saveAlarmLog(log)
                        }
                    },
                    .send(.delegate(.dismiss))
                )
            case .stopAudio:
                state.isPlaying = false; return .none
            case let .longPressChanged(isPressing):
                state.isLongPressing = isPressing
                if !isPressing { state.longPressProgress = 0 }
                return .none
            case let .longPressProgressUpdated(progress):
                state.longPressProgress = progress
                if progress >= 1.0 { return .send(.dismiss) }
                return .none
            case .delegate: return .none
            }
        }
    }
}
