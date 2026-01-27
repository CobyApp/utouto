import SwiftUI
import ComposableArchitecture

@Reducer
struct AlarmListFeature {
@ObservableState
struct State {
    var alarms: [Alarm] = []
    var isLoading = false
    var showDeleteAlert = false
    var alarmToDelete: Alarm?
}

    enum Action {
        case loadAlarms
        case alarmsResponse([Alarm])
        case toggleAlarm(Alarm)
        case toggleAlarmResponse
        case addAlarm
        case editAlarm(Alarm)
        case deleteAlarm(Alarm)
        case deleteAlarmResponse
        case confirmDelete(Alarm)
        case showDeleteAlert(Alarm)
        case hideDeleteAlert

        @CasePathable
        enum Delegate {
            case showAlarmEdit(Alarm?)
            case showCharacterSelect
        }

        case delegate(Delegate)
    }

    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.clock) var clock
    @Dependency(\.logger) var logger

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadAlarms:
                state.isLoading = true
                return .run { send in
                    do {
                        let alarms = try await alarmRepository.loadAlarms()
                        await send(.alarmsResponse(alarms))
                    } catch {
                        logger.error("Failed to load alarms: \(error)")
                        await send(.alarmsResponse([]))
                    }
                }

            case let .alarmsResponse(alarms):
                state.alarms = alarms.sorted { $0.timeString < $1.timeString }
                state.isLoading = false
                return .none

            case let .toggleAlarm(alarm):
                let isEnabled = !alarm.enabled
                let alarmId = alarm.id

                return .run { send in
                    do {
                        var updatedAlarm = alarm
                        updatedAlarm.enabled = isEnabled
                        updatedAlarm.updatedAt = clock.now()

                        try await alarmRepository.updateAlarm(updatedAlarm)
                        if isEnabled {
                            try await notificationClient.scheduleAlarm(updatedAlarm)
                        } else {
                            await notificationClient.cancelAlarm(alarmId)
                        }
                        await send(.toggleAlarmResponse)
                        await send(.loadAlarms)
                    } catch {
                        logger.error("Failed to toggle alarm: \(error)")
                    }
                }

            case .toggleAlarmResponse:
                return .none

            case .addAlarm:
                return .send(.delegate(.showAlarmEdit(nil)))

            case let .editAlarm(alarm):
                return .send(.delegate(.showAlarmEdit(alarm)))

            case let .deleteAlarm(alarm):
                state.showDeleteAlert = true
                state.alarmToDelete = alarm
                return .none

            case .deleteAlarmResponse:
                return .send(.loadAlarms)

            case let .confirmDelete(alarm):
                return .run { send in
                    do {
                        await notificationClient.cancelAlarm(alarm.id)
                        try await alarmRepository.deleteAlarm(alarm.id)
                        await send(.deleteAlarmResponse)
                        await send(.hideDeleteAlert)
                    } catch {
                        logger.error("Failed to delete alarm: \(error)")
                        await send(.hideDeleteAlert)
                    }
                }

            case .showDeleteAlert:
                return .none

            case .hideDeleteAlert:
                state.showDeleteAlert = false
                state.alarmToDelete = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

struct AlarmListFeatureView: View {
    let store: StoreOf<AlarmListFeature>

    var body: some View {
        NavigationStack {
            ZStack {
                if store.alarms.isEmpty && !store.isLoading {
                    emptyStateView
                } else {
                    alarmListView
                }

                if store.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("アラーム")
            .toolbar {
                Button {
                    store.send(.addAlarm)
                } label: {
                    Image(systemName: "plus")
                }
            }
            .alert("アラームを削除", isPresented: Binding(
                get: { store.showDeleteAlert },
                set: { _ in store.send(.hideDeleteAlert) }
            ), presenting: store.alarmToDelete) { alarm in
                Button("削除", role: .destructive) {
                    store.send(.confirmDelete(alarm))
                }
            } message: { alarm in
                Text("このアラームを削除しますか？")
            }
            .task {
                await store.send(.loadAlarms).finish()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "alarm")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("アラームがありません")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("最初のアラームを作成しましょう")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                store.send(.addAlarm)
            } label: {
                Text("アラームを追加")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var alarmListView: some View {
        List {
            ForEach(store.alarms) { alarm in
                AlarmRowView(alarm: alarm) {
                    store.send(.toggleAlarm(alarm))
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.send(.deleteAlarm(alarm))
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
                .onTapGesture {
                    store.send(.editAlarm(alarm))
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct AlarmRowView: View {
    let alarm: Alarm
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.label.isEmpty ? "アラーム" : alarm.label)
                    .font(.headline)

                HStack(spacing: 12) {
                    Text(alarm.timeString)
                        .font(.title2)
                        .fontWeight(.bold)

                    if !alarm.repeatDays.isEmpty {
                        Text(alarm.repeatDaysString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { alarm.enabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 8)
        .opacity(alarm.enabled ? 1.0 : 0.6)
    }
}
