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
        var alarmDetail: AlarmDetailFeature.State?
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
        case showAlarmDetail(Alarm)
        case hideAlarmDetail
        case alarmDetail(AlarmDetailFeature.Action)

        @CasePathable
        enum Delegate {
            case showAlarmEdit(Alarm?)
        }

        case delegate(Delegate)
    }

    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.clock) var clock
    @Dependency(\.logger) var logger

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action { // swiftlint:disable:this cyclomatic_complexity
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
                            try await notificationClient.scheduleAlarm(updatedAlarm, nil)
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

            case let .showAlarmDetail(alarm):
                state.alarmDetail = AlarmDetailFeature.State(alarm: alarm)
                return .none

            case .hideAlarmDetail:
                state.alarmDetail = nil
                return .none

            case .alarmDetail(.delegate(.edit(let alarm))):
                state.alarmDetail = nil
                return .send(.delegate(.showAlarmEdit(alarm)))

            case .alarmDetail(.delegate(.delete(let alarm))):
                state.alarmDetail = nil
                return .send(.deleteAlarm(alarm))

            case .alarmDetail(.delegate(.dismiss)):
                state.alarmDetail = nil
                return .none

            case .alarmDetail(.delegate(.alarmUpdated(let updated))):
                if let idx = state.alarms.firstIndex(where: { $0.id == updated.id }) {
                    state.alarms[idx] = updated
                }
                return .none

            case .alarmDetail:
                return .none

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
        .ifLet(\.alarmDetail, action: \.alarmDetail) { AlarmDetailFeature() }
    }
}
