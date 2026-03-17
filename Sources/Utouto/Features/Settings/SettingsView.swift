import SwiftUI
import ComposableArchitecture

struct SettingsFeatureView: View {
    let store: StoreOf<SettingsFeature>
    @AppStorage("app_language") private var appLanguageRaw: String = ""

    var body: some View {
        NavigationStack {
            Form {
                languageSection
                permissionsSection
                defaultSnoozeSection
                defaultDismissSection
                otherSettingsSection
            }
            .navigationTitle(L10n.settingsTitle)
            .task {
                await store.send(.onAppear).finish()
            }
        }
    }

    private var languageSection: some View {
        Section(L10n.settingsLanguageSection) {
            Picker(L10n.settingsLanguage, selection: Binding(
                get: { appLanguageRaw },
                set: { appLanguageRaw = $0; L10n.appLanguageCode = $0.isEmpty ? nil : $0 }
            )) {
                ForEach(L10n.supportedLanguageTags(), id: \.tag) { item in
                    Text(item.name).tag(item.tag)
                }
            }
        }
    }

    private var permissionsSection: some View {
        Section(L10n.settingsPermissions) {
            HStack {
                Text(L10n.settingsNotification)
                Spacer()
                Text(store.isNotificationAuthorized ? L10n.settingsNotificationAllowed : L10n.settingsNotificationDenied)
                    .foregroundStyle(store.isNotificationAuthorized ? .green : .red)
            }
            Button(L10n.settingsOpenSystemSettings) {
                store.send(.openSettingsApp)
            }
        }
    }

    private var defaultSnoozeSection: some View {
        Section(L10n.settingsDefaultSnooze) {
            Picker(L10n.snoozeInterval, selection: Binding(
                get: { store.settings.defaultSnoozeIntervalMin },
                set: { store.send(.updateSnoozeInterval($0)) }
            )) {
                ForEach([1, 5, 10, 15, 30], id: \.self) { interval in
                    Text(String(format: L10n.minutesFormat, interval)).tag(interval)
                }
            }
            Picker(L10n.snoozeMaxCount, selection: Binding(
                get: { store.settings.defaultSnoozeMaxCount },
                set: { store.send(.updateSnoozeMaxCount($0)) }
            )) {
                Text(String(format: L10n.timesFormat, 3)).tag(Alarm.SnoozeMaxCount.limited(3))
                Text(String(format: L10n.timesFormat, 5)).tag(Alarm.SnoozeMaxCount.limited(5))
                Text(L10n.snoozeUnlimited).tag(Alarm.SnoozeMaxCount.unlimited)
            }
        }
    }

    private var defaultDismissSection: some View {
        Section(L10n.settingsDefaultDismiss) {
            Picker(L10n.dismissMethodPicker, selection: Binding(
                get: { store.settings.defaultDismissMode },
                set: { store.send(.updateDismissMode($0)) }
            )) {
                Text(L10n.dismissSlide).tag(Alarm.DismissMode.slide)
                Text(L10n.dismissLongPress).tag(Alarm.DismissMode.longPress)
            }
            .pickerStyle(.segmented)
        }
    }

    private var otherSettingsSection: some View {
        Section(L10n.settingsOther) {
            Toggle(L10n.settingsVibration, isOn: Binding(
                get: { store.settings.vibrationEnabled },
                set: { _ in store.send(.toggleVibration) }
            ))
        }
    }
}
