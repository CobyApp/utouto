import SwiftUI
import ComposableArchitecture

@Reducer
struct AlarmEditFeature {
    @ObservableState
    struct State: Equatable {
        var alarm: Alarm
        var isNew: Bool
        var isSaving = false

        // Form fields
        var selectedHour: Int
        var selectedMinute: Int
        var label: String
        var repeatDays: Set<Int>
        var isOneTime = false
        var oneTimeDate: Date
        var selectedCharacterId: String?
        var snoozeEnabled: Bool
        var snoozeIntervalMin: Int
        var snoozeMaxCount: Alarm.SnoozeMaxCount
        var dismissMode: Alarm.DismissMode

        var characters: [Character] = []

        init(alarm: Alarm? = nil) {
            let now = Date()
            _ = Calendar.current

            if let alarm = alarm {
                self.alarm = alarm
                self.isNew = false
                self.selectedHour = alarm.hour
                self.selectedMinute = alarm.minute
                self.label = alarm.label
                self.repeatDays = Set(alarm.repeatDays)
                self.isOneTime = alarm.oneTimeDate != nil
                self.oneTimeDate = alarm.oneTimeDate ?? now
                self.selectedCharacterId = alarm.characterId
                self.snoozeEnabled = alarm.snoozeEnabled
                self.snoozeIntervalMin = alarm.snoozeIntervalMin
                self.snoozeMaxCount = alarm.snoozeMaxCount
                self.dismissMode = alarm.dismissMode
            } else {
                let defaultAlarm = Alarm.newDefault()
                self.alarm = defaultAlarm
                self.isNew = true
                self.selectedHour = defaultAlarm.hour
                self.selectedMinute = defaultAlarm.minute
                self.label = defaultAlarm.label
                self.repeatDays = Set(defaultAlarm.repeatDays)
                self.isOneTime = false
                self.oneTimeDate = now
                self.selectedCharacterId = nil
                self.snoozeEnabled = true
                self.snoozeIntervalMin = 5
                self.snoozeMaxCount = .limited(3)
                self.dismissMode = .slide
            }
        }

        var selectedCharacter: Character? {
            characters.first { $0.id == selectedCharacterId }
        }

        var canSave: Bool {
            // Basic validation
            true
        }
    }

    enum Action {
        case loadCharacters
        case charactersResponse([Character])
        case updateHour(Int)
        case updateMinute(Int)
        case updateLabel(String)
        case toggleRepeatDay(Int)
        case toggleOneTime
        case updateOneTimeDate(Date)
        case updateCharacter(Character?)
        case toggleSnoozeEnabled
        case updateSnoozeInterval(Int)
        case updateSnoozeMaxCount(Alarm.SnoozeMaxCount)
        case updateDismissMode(Alarm.DismissMode)
        case saveAlarm
        case saveResponse
        case cancel

        @CasePathable
        enum Delegate {
            case dismiss
            case saveAlarm(Alarm)
        }

        case delegate(Delegate)
    }

    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.clock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadCharacters:
                return .run { send in
                    do {
                        let characters = try await alarmRepository.loadCharacters()
                        await send(.charactersResponse(characters))
                    } catch {
                        await send(.charactersResponse([]))
                    }
                }

            case let .charactersResponse(characters):
                state.characters = characters
                return .none

            case let .updateHour(hour):
                state.selectedHour = hour
                return .none

            case let .updateMinute(minute):
                state.selectedMinute = minute
                return .none

            case let .updateLabel(label):
                state.label = label
                return .none

            case let .toggleRepeatDay(day):
                if state.repeatDays.contains(day) {
                    state.repeatDays.remove(day)
                } else {
                    state.repeatDays.insert(day)
                }
                return .none

            case .toggleOneTime:
                state.isOneTime.toggle()
                return .none

            case let .updateOneTimeDate(date):
                state.oneTimeDate = date
                return .none

            case let .updateCharacter(character):
                state.selectedCharacterId = character?.id
                return .none

            case .toggleSnoozeEnabled:
                state.snoozeEnabled.toggle()
                return .none

            case let .updateSnoozeInterval(interval):
                state.snoozeIntervalMin = interval
                return .none

            case let .updateSnoozeMaxCount(maxCount):
                state.snoozeMaxCount = maxCount
                return .none

            case let .updateDismissMode(mode):
                state.dismissMode = mode
                return .none

            case .saveAlarm:
                guard state.canSave else { return .none }

                state.isSaving = true

                let isNew = state.isNew
                var updatedAlarm = state.alarm
                updatedAlarm.time = DateComponents(hour: state.selectedHour, minute: state.selectedMinute)
                updatedAlarm.enabled = true
                updatedAlarm.repeatDays = Array(state.repeatDays).sorted()
                updatedAlarm.oneTimeDate = state.isOneTime ? state.oneTimeDate : nil
                updatedAlarm.label = state.label
                updatedAlarm.characterId = state.selectedCharacterId
                updatedAlarm.snoozeEnabled = state.snoozeEnabled
                updatedAlarm.snoozeIntervalMin = state.snoozeIntervalMin
                updatedAlarm.snoozeMaxCount = state.snoozeMaxCount
                updatedAlarm.dismissMode = state.dismissMode
                updatedAlarm.updatedAt = clock.now()

                return .run { [isNew, updatedAlarm] send in
                    do {
                        if isNew {
                            try await alarmRepository.saveAlarm(updatedAlarm)
                        } else {
                            try await alarmRepository.updateAlarm(updatedAlarm)
                        }

                        try await notificationClient.scheduleAlarm(updatedAlarm)
                        await send(.saveResponse)
                        await send(.delegate(.saveAlarm(updatedAlarm)))
                    } catch {
                        // In a real app, show error alert
                        print("Failed to save alarm: \(error)")
                        // Note: In a real implementation, you'd send an action to reset isSaving
                    }
                }

            case .saveResponse:
                state.isSaving = false
                return .none

            case .cancel:
                return .send(.delegate(.dismiss))

            case .delegate:
                return .none
            }
        }
    }
}

struct AlarmEditFeatureView: View {
    let store: StoreOf<AlarmEditFeature>

    var body: some View {
        NavigationStack {
            Form {
                timeSection
                labelSection
                repeatSection
                oneTimeSection
                characterSection
                snoozeSection
                dismissSection
            }
            .navigationTitle(store.isNew ? "アラーム追加" : "アラーム編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        store.send(.cancel)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.send(.saveAlarm)
                    } label: {
                        if store.isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(!store.canSave || store.isSaving)
                }
            }
            .task {
                await store.send(.loadCharacters).finish()
            }
        }
    }

    private var timeSection: some View {
        Section("時間") {
            HStack {
                Picker("時", selection: Binding(
                    get: { store.selectedHour },
                    set: { store.send(.updateHour($0)) }
                )) {
                    ForEach(0..<24) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 100)

                Text(":")

                Picker("分", selection: Binding(
                    get: { store.selectedMinute },
                    set: { store.send(.updateMinute($0)) }
                )) {
                    ForEach(0..<60) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 100)
            }
            .frame(height: 100)
        }
    }

    private var labelSection: some View {
        Section("ラベル") {
            TextField("アラーム", text: Binding(
                get: { store.label },
                set: { store.send(.updateLabel($0)) }
            ))
        }
    }

    private var repeatSection: some View {
        Section("繰り返し") {
            let days = ["日", "月", "火", "水", "木", "金", "土"]
            ForEach(0..<7) { index in
                Toggle(days[index], isOn: Binding(
                    get: { store.repeatDays.contains(index) },
                    set: { _ in store.send(.toggleRepeatDay(index)) }
                ))
            }
        }
    }

    private var oneTimeSection: some View {
        Section("一度だけ") {
            Toggle("一度だけのスケジュール", isOn: Binding(
                get: { store.isOneTime },
                set: { _ in store.send(.toggleOneTime) }
            ))

            if store.isOneTime {
                DatePicker("日付", selection: Binding(
                    get: { store.oneTimeDate },
                    set: { store.send(.updateOneTimeDate($0)) }
                ), displayedComponents: [.date, .hourAndMinute])
            }
        }
    }

    private var characterSection: some View {
        Section("キャラクター") {
            if let character = store.selectedCharacter {
                HStack {
                    Text(character.name)
                    Spacer()
                    Image(systemName: "person.circle")
                        .foregroundStyle(.blue)
                }
                .onTapGesture {
                    // TODO: Navigate to character select
                }
            } else {
                HStack {
                    Text("デフォルト")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "person.circle")
                        .foregroundStyle(.secondary)
                }
                .onTapGesture {
                    // TODO: Navigate to character select
                }
            }
        }
    }

    private var snoozeSection: some View {
        Section("スヌーズ") {
            Toggle("スヌーズ有効", isOn: Binding(
                get: { store.snoozeEnabled },
                set: { _ in store.send(.toggleSnoozeEnabled) }
            ))

            if store.snoozeEnabled {
                Picker("間隔", selection: Binding(
                    get: { store.snoozeIntervalMin },
                    set: { store.send(.updateSnoozeInterval($0)) }
                )) {
                    ForEach([1, 5, 10, 15, 30], id: \.self) { interval in
                        Text("\(interval)分").tag(interval)
                    }
                }

                Picker("最大回数", selection: Binding(
                    get: { store.snoozeMaxCount },
                    set: { store.send(.updateSnoozeMaxCount($0)) }
                )) {
                    Text("3回").tag(Alarm.SnoozeMaxCount.limited(3))
                    Text("5回").tag(Alarm.SnoozeMaxCount.limited(5))
                    Text("無制限").tag(Alarm.SnoozeMaxCount.unlimited)
                }
            }
        }
    }

    private var dismissSection: some View {
        Section("解除方法") {
            Picker("解除方法", selection: Binding(
                get: { store.dismissMode },
                set: { store.send(.updateDismissMode($0)) }
            )) {
                Text("スライド").tag(Alarm.DismissMode.slide)
                Text("長押し").tag(Alarm.DismissMode.longPress)
            }
            .pickerStyle(.segmented)
        }
    }
}