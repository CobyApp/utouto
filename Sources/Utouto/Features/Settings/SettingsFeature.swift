import ComposableArchitecture

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var settings: Settings = .default
        var isNotificationAuthorized = false
    }

    enum Action {
        case onAppear
        case loadSettings
        case settingsResponse(Settings)
        case checkNotificationAuthorization
        case authorizationResponse(Bool)
        case updateSnoozeInterval(Int)
        case updateSnoozeMaxCount(Alarm.SnoozeMaxCount)
        case updateDismissMode(Alarm.DismissMode)
        case toggleVibration
        case openSettingsApp
    }

    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.alarmKitClient) var alarmKitClient
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
                return .none

            case .checkNotificationAuthorization:
                return .run { send in
                    let isAuthorized = await alarmKitClient.isAuthorized()
                    await send(.authorizationResponse(isAuthorized))
                }

            case let .authorizationResponse(authorized):
                state.isNotificationAuthorized = authorized
                return .none

            case let .updateSnoozeInterval(interval):
                state.settings.defaultSnoozeIntervalMin = interval
                return .run { [settings = state.settings] _ in
                    do { try await alarmRepository.saveSettings(settings) } catch { }
                }

            case let .updateSnoozeMaxCount(maxCount):
                state.settings.defaultSnoozeMaxCount = maxCount
                return .run { [settings = state.settings] _ in
                    do { try await alarmRepository.saveSettings(settings) } catch { }
                }

            case let .updateDismissMode(mode):
                state.settings.defaultDismissMode = mode
                return .run { [settings = state.settings] _ in
                    do { try await alarmRepository.saveSettings(settings) } catch { }
                }

            case .toggleVibration:
                state.settings.vibrationEnabled.toggle()
                return .run { [settings = state.settings] _ in
                    do { try await alarmRepository.saveSettings(settings) } catch { }
                }

            case .openSettingsApp:
                return .run { _ in await appRouter.openSettings() }
            }
        }
    }
}
