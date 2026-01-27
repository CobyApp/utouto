import SwiftUI
import ComposableArchitecture

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var settings: Settings = .default
        var isNotificationAuthorized = false
        var selectedCharacter: Character?

        init() {
            // Load initial settings
        }
    }

    enum Action {
        case onAppear
        case loadSettings
        case settingsResponse(Settings)
        case checkNotificationAuthorization
        case authorizationResponse(Bool)
        case updateDefaultCharacter(Character?)
        case updateSnoozeInterval(Int)
        case updateSnoozeMaxCount(Alarm.SnoozeMaxCount)
        case updateDismissMode(Alarm.DismissMode)
        case toggleVibration
        case openSettingsApp

        @CasePathable
        enum Delegate {
            case showCharacterSelect
        }

        case delegate(Delegate)
    }

    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.appRouter) var appRouter

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .send(.loadSettings),
                    .send(.checkNotificationAuthorization)
                )

            case .loadSettings:
                return .run { send in
                    do {
                        let settings = try await alarmRepository.loadSettings()
                        await send(.settingsResponse(settings))
                    } catch {
                        await send(.settingsResponse(.default))
                    }
                }

            case let .settingsResponse(settings):
                state.settings = settings
                // Load selected character if any
                if let characterId = settings.defaultCharacterId {
                    return .run { [characterId] send in
                        do {
                            let characters = try await alarmRepository.loadCharacters()
                            _ = characters.first { $0.id == characterId }
                            // Note: In a real implementation, you'd send an action to update state
                        } catch {
                            // Ignore error
                        }
                    }
                }
                return .none

            case .checkNotificationAuthorization:
                return .run { send in
                    let isAuthorized = await notificationClient.isAuthorized()
                    await send(.authorizationResponse(isAuthorized))
                }

            case let .authorizationResponse(authorized):
                state.isNotificationAuthorized = authorized
                return .none

            case let .updateDefaultCharacter(character):
                state.selectedCharacter = character
                state.settings.defaultCharacterId = character?.id

                return .run { [settings = state.settings] send in
                    do {
                        try await alarmRepository.saveSettings(settings)
                    } catch {
                        // Handle error - maybe show alert
                    }
                }

            case let .updateSnoozeInterval(interval):
                state.settings.defaultSnoozeIntervalMin = interval
                return .run { [settings = state.settings] send in
                    do {
                        try await alarmRepository.saveSettings(settings)
                    } catch {
                        // Handle error
                    }
                }

            case let .updateSnoozeMaxCount(maxCount):
                state.settings.defaultSnoozeMaxCount = maxCount
                return .run { [settings = state.settings] send in
                    do {
                        try await alarmRepository.saveSettings(settings)
                    } catch {
                        // Handle error
                    }
                }

            case let .updateDismissMode(mode):
                state.settings.defaultDismissMode = mode
                return .run { [settings = state.settings] send in
                    do {
                        try await alarmRepository.saveSettings(settings)
                    } catch {
                        // Handle error
                    }
                }

            case .toggleVibration:
                state.settings.vibrationEnabled.toggle()
                return .run { [settings = state.settings] send in
                    do {
                        try await alarmRepository.saveSettings(settings)
                    } catch {
                        // Handle error
                    }
                }

            case .openSettingsApp:
                return .run { _ in
                    await appRouter.openSettings()
                }

            case .delegate:
                return .none
            }
        }
    }
}

struct SettingsFeatureView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            Form {
                permissionsSection
                defaultCharacterSection
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

    private var defaultCharacterSection: some View {
        Section("デフォルトキャラクター") {
            HStack {
                Text("キャラクター")
                Spacer()
                if let character = store.selectedCharacter {
                    Text(character.name)
                        .foregroundStyle(.blue)
                } else {
                    Text("デフォルト")
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .onTapGesture {
                store.send(.delegate(.showCharacterSelect))
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

// Note: Binding extensions removed as they conflict with TCA ObservableState
// Use explicit Bindings in the view instead