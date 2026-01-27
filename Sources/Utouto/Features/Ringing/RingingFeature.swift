import SwiftUI
import ComposableArchitecture

@Reducer
struct RingingFeature {
    @ObservableState
    struct State: Equatable {
        let alarmId: UUID
        var alarm: Alarm?
        var character: Character?
        var currentTime = Date()
        var wakeText: String = ""
        var isPlaying = false
        var snoozeCount = 0

        init(alarmId: UUID) {
            self.alarmId = alarmId
            self.wakeText = Self.randomWakeText()
        }

        static func randomWakeText() -> String {
            [
                "おはよう…起きようか",
                "時間だよ！",
                "もう起きる時間だよ〜",
                "早く起きなさい！",
                "素敵な朝だね"
            ].randomElement()!
        }
    }

    enum Action {
        case onAppear
        case loadAlarm
        case alarmResponse(Alarm?)
        case updateTime
        case playWakeSound
        case snooze
        case dismiss
        case stopAudio

        @CasePathable
        enum Delegate {
            case dismiss
        }

        case delegate(Delegate)
    }

    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.audioClient) var audioClient
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
                        // Update time every second
                        while true {
                            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
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
                    } catch {
                        logger.error("Failed to load alarm: \(error)")
                        await send(.alarmResponse(nil))
                    }
                }

            case let .alarmResponse(alarm):
                state.alarm = alarm
                if let characterId = alarm?.characterId {
                    // Load character - Note: In a real implementation, you'd send an action to update character
                    return .run { [characterId] send in
                        do {
                            let characters = try await alarmRepository.loadCharacters()
                            let character = characters.first { $0.id == characterId }
                            // Here you would send an action to update the character in state
                            logger.log("Loaded character: \(character?.name ?? "none")")
                        } catch {
                            logger.error("Failed to load character: \(error)")
                        }
                    }
                }
                return .none

            case .updateTime:
                state.currentTime = clock.now()
                return .none

            case .playWakeSound:
                state.isPlaying = true
                return .run { [character = state.character] send in
                    await audioClient.playWakeClip(character, nil)
                    // In a real implementation, you'd handle looping or stopping
                }

            case .snooze:
                guard let alarm = state.alarm else { return .none }

                state.snoozeCount += 1

                // Schedule snooze - calculate snooze alarm outside closure
                let snoozeTime = clock.now().addingTimeInterval(TimeInterval(alarm.snoozeIntervalMin * 60))
                var snoozeAlarm = alarm
                snoozeAlarm.time = Calendar.current.dateComponents([.hour, .minute], from: snoozeTime)
                snoozeAlarm.oneTimeDate = snoozeTime
                snoozeAlarm.repeatDays = []

                return .merge(
                    .run { send in
                        await audioClient.stopPlayback()
                        await send(.stopAudio)
                    },
                    .run { [snoozeAlarm] send in
                        do {
                            try await alarmRepository.saveAlarm(snoozeAlarm)
                            // In a real app, you'd schedule this snooze alarm
                            await send(.delegate(.dismiss))
                        } catch {
                            logger.error("Failed to schedule snooze: \(error)")
                        }
                    }
                )

            case .dismiss:
                return .merge(
                    .run { send in
                        await audioClient.stopPlayback()
                        await send(.stopAudio)
                    },
                    .run { [alarm = state.alarm, firedAt = clock.now(), snoozeCount = state.snoozeCount] send in
                        // Log the dismissal
                        if let alarm = alarm {
                            let log = AlarmLog(
                                id: UUID(),
                                alarmId: alarm.id,
                                firedAt: firedAt,
                                dismissedAt: firedAt,
                                snoozeCount: snoozeCount,
                                result: .dismissed
                            )
                            do {
                                try await alarmRepository.saveAlarmLog(log)
                            } catch {
                                logger.error("Failed to save alarm log: \(error)")
                            }
                        }
                        await send(.delegate(.dismiss))
                    }
                )

            case .stopAudio:
                state.isPlaying = false
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

struct RingingFeatureView: View {
    let store: StoreOf<RingingFeature>

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Character Image
                if let character = store.character {
                    // TODO: Replace with actual character image asset
                    Image(systemName: characterImageName(for: character))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .foregroundStyle(characterColor(for: character))
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .foregroundStyle(.white)
                }

                // Current Time
                Text(timeString(from: store.currentTime))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                // Wake Text
                Text(store.wakeText)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                // Action Buttons
                HStack(spacing: 24) {
                    if let alarm = store.alarm, alarm.snoozeEnabled {
                        Button {
                            store.send(.snooze)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "alarm")
                                    .font(.title2)
                                Text("スヌーズ")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(width: 100, height: 80)
                            .background(Color.blue.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    // Dismiss Button (Slide for MVP)
                    Button {
                        store.send(.dismiss)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.draw")
                                .font(.title2)
                            Text("スライドして起きる")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 80)
                        .background(Color.green.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }

                Spacer()
            }
            .padding()
        }
        .task {
            await store.send(.onAppear).finish()
        }
    }

    private func timeString(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func characterImageName(for character: Character) -> String {
        // TODO: Replace with actual asset names
        switch character.personalityType {
        case "gentle": return "person.circle.fill"
        case "tsundere": return "person.circle.fill"
        case "cool": return "person.circle.fill"
        default: return "person.circle"
        }
    }

    private func characterColor(for character: Character) -> Color {
        switch character.personalityType {
        case "gentle": return .green
        case "tsundere": return .pink
        case "cool": return .blue
        default: return .white
        }
    }
}
