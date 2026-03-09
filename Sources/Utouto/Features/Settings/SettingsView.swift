import SwiftUI
import ComposableArchitecture

struct SettingsFeatureView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            Form {
                permissionsSection
                defaultSnoozeSection
                defaultDismissSection
                otherSettingsSection
            }
            .navigationTitle("設定")
            .task {
                await store.send(.onAppear).finish()
            }
        }
    }

    private var permissionsSection: some View {
        Section("権限") {
            HStack {
                Text("通知")
                Spacer()
                Text(store.isNotificationAuthorized ? "許可済み" : "未許可")
                    .foregroundStyle(store.isNotificationAuthorized ? .green : .red)
            }
            Button("設定アプリを開く") {
                store.send(.openSettingsApp)
            }
        }
    }

    private var defaultSnoozeSection: some View {
        Section("デフォルトスヌーズ") {
            Picker("間隔", selection: Binding(
                get: { store.settings.defaultSnoozeIntervalMin },
                set: { store.send(.updateSnoozeInterval($0)) }
            )) {
                ForEach([1, 5, 10, 15, 30], id: \.self) { interval in
                    Text("\(interval)分").tag(interval)
                }
            }
            Picker("最大回数", selection: Binding(
                get: { store.settings.defaultSnoozeMaxCount },
                set: { store.send(.updateSnoozeMaxCount($0)) }
            )) {
                Text("3回").tag(Alarm.SnoozeMaxCount.limited(3))
                Text("5回").tag(Alarm.SnoozeMaxCount.limited(5))
                Text("無制限").tag(Alarm.SnoozeMaxCount.unlimited)
            }
        }
    }

    private var defaultDismissSection: some View {
        Section("デフォルト解除方法") {
            Picker("解除方法", selection: Binding(
                get: { store.settings.defaultDismissMode },
                set: { store.send(.updateDismissMode($0)) }
            )) {
                Text("スライド").tag(Alarm.DismissMode.slide)
                Text("長押し").tag(Alarm.DismissMode.longPress)
            }
            .pickerStyle(.segmented)
        }
    }

    private var otherSettingsSection: some View {
        Section("その他") {
            Toggle("振動", isOn: Binding(
                get: { store.settings.vibrationEnabled },
                set: { _ in store.send(.toggleVibration) }
            ))
        }
    }
}
