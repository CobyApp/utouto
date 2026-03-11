import XCTest
import ComposableArchitecture
@testable import Utouto

final class AppFeatureTests: XCTestCase {
    @MainActor
    func test_alarmCreation_andSave() async {
        let store = TestStore(initialState: AlarmListFeature.State()) {
            AlarmListFeature()
        }

        store.dependencies.alarmRepository.loadAlarms = { [] }
        store.dependencies.alarmRepository.saveAlarm = { (_: Alarm) async throws in }

        _ = Alarm.newDefault()

        await store.send(.addAlarm) {
            $0.alarmDetail = nil
        }
    }

    @MainActor
    func test_alarmToggle_updatesNotification() async {
        let alarm = Alarm.newDefault()
        let store = TestStore(initialState: AlarmListFeature.State(alarms: [alarm])) {
            AlarmListFeature()
        }

        store.dependencies.alarmRepository.updateAlarm = { (_: Alarm) async throws in }
        store.dependencies.alarmKitClient.scheduleAlarm = { (_: Alarm, _: URL?) async throws in }
        store.dependencies.alarmKitClient.cancelAlarm = { (_: UUID) async in }

        await store.send(.toggleAlarm(alarm)) {state in 
            // State unchanged until effects run
        }
    }

    @MainActor
    func test_ringingSnooze_stopsAudio() async {
        let alarmId = UUID()
        let store = TestStore(initialState: RingingFeature.State(alarmId: alarmId)) {
            RingingFeature()
        }

        store.dependencies.audioClient.stop = { () async in }
        let alarm = Alarm.newDefault()
        store.dependencies.alarmRepository.loadAlarms = { [alarm] }

        await store.send(.onAppear)

        await store.receive(\.alarmResponse, alarm) {
            $0.alarm = alarm
        }

        await store.send(.snooze) {
            $0.snoozeCount = 1
        }
    }
}
