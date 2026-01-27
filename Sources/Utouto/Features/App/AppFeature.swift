import SwiftUI
import ComposableArchitecture

// MARK: - AppFeature

@Reducer
struct AppFeature {
@ObservableState
struct State {
        enum Tab: Hashable {
            case alarms
            case settings
        }

        enum Route: Equatable {
            case ringing(alarmId: UUID)
            case alarmEdit(alarm: Alarm?)
            case characterSelect
        }

        var tab: Tab = .alarms
        var needsOnboarding = true
        var route: Route?

        // Child states
        var onboarding = OnboardingFeature.State()
        var alarmList = AlarmListFeature.State()
        var settings = SettingsFeature.State()
        var ringing: RingingFeature.State?
        var alarmEdit: AlarmEditFeature.State?
        var characterSelect: CharacterSelectFeature.State?
    }

    enum Action {
        case onAppear
        case checkNotificationAuthorization
        case setNeedsOnboarding(Bool)
        case handleDeepLink(URL)
        case setTab(State.Tab)
        case dismissRoute
        case dismissRinging
        case dismissAlarmEdit
        case dismissCharacterSelect
        case onboarding(OnboardingFeature.Action)
        case alarmList(AlarmListFeature.Action)
        case settings(SettingsFeature.Action)
        case ringing(RingingFeature.Action)
        case alarmEdit(AlarmEditFeature.Action)
        case characterSelect(CharacterSelectFeature.Action)
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.logger) var logger

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                logger.log("[App] onAppear - checking notification authorization")
                return .run { send in
                    await send(.checkNotificationAuthorization)
                }

            case .checkNotificationAuthorization:
                return .run { send in
                    let isAuthorized = await notificationClient.isAuthorized()
                    logger.log("[App] checkNotificationAuthorization: isAuthorized=\(isAuthorized), needsOnboarding=\(!isAuthorized)")
                    await send(.setNeedsOnboarding(!isAuthorized))
                }

            case let .setNeedsOnboarding(value):
                logger.log("[App] setNeedsOnboarding: \(value) (current: \(state.needsOnboarding))")
                state.needsOnboarding = value
                logger.log("[App] setNeedsOnboarding: after update: \(state.needsOnboarding)")
                return .none

            case let .handleDeepLink(url):
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      components.host == "ringing",
                      let alarmIdStr = components.queryItems?.first(where: { $0.name == "alarmId" })?.value,
                      let alarmId = UUID(uuidString: alarmIdStr) else {
                    return .none
                }
                state.route = .ringing(alarmId: alarmId)
                return .none

            case let .setTab(tab):
                state.tab = tab
                return .none

            case .dismissRoute:
                state.route = nil
                state.ringing = nil
                state.alarmEdit = nil
                state.characterSelect = nil
                return .none

            case .alarmList(.delegate(.showAlarmEdit(let alarm))):
                state.route = .alarmEdit(alarm: alarm)
                state.alarmEdit = AlarmEditFeature.State(alarm: alarm)
                return .none

            case .alarmList(.delegate(.showCharacterSelect)):
                state.route = .characterSelect
                state.characterSelect = CharacterSelectFeature.State()
                return .none

            case .alarmList:
                return .none // Handled by child reducer

            case .settings(.delegate(.showCharacterSelect)):
                state.route = .characterSelect
                state.characterSelect = CharacterSelectFeature.State()
                return .none

            case .settings:
                return .none // Handled by child reducer

            case .ringing(.delegate(.dismiss)):
                return .send(.dismissRoute)

            case .ringing:
                return .none // Handled by child reducer

            case .alarmEdit(.delegate(.dismiss)):
                return .send(.dismissRoute)

            case .alarmEdit(.delegate(.saveAlarm(_))):
                return .merge(
                    .send(.dismissRoute),
                    .send(.alarmList(.loadAlarms))
                )

            case .alarmEdit:
                return .none // Handled by child reducer

            case .characterSelect(.delegate(.dismiss)):
                return .send(.dismissRoute)

            case .characterSelect(.delegate(.selectCharacter(let character))):
                return .merge(
                    .send(.dismissRoute),
                    .send(.alarmEdit(.updateCharacter(character))),
                    .send(.settings(.updateDefaultCharacter(character)))
                )

            case .characterSelect:
                return .none // Handled by child reducer

            case .dismissRinging:
                state.ringing = nil
                return .none

            case .dismissAlarmEdit:
                state.alarmEdit = nil
                return .none

            case .dismissCharacterSelect:
                state.characterSelect = nil
                return .none

            case .onboarding(.delegate(.authorizationGranted)):
                logger.log("[App] Received onboarding delegate: authorizationGranted")
                return .send(.setNeedsOnboarding(false))

            case .onboarding:
                return .none // Handled by child reducer
            }
        }
        .ifLet(\.ringing, action: \.ringing) {
            RingingFeature()
        }
        .ifLet(\.alarmEdit, action: \.alarmEdit) {
            AlarmEditFeature()
        }
        .ifLet(\.characterSelect, action: \.characterSelect) {
            CharacterSelectFeature()
        }

        Scope(state: \.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }

        Scope(state: \.alarmList, action: \.alarmList) {
            AlarmListFeature()
        }

        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
    }
}

struct AppFeatureView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        let _ = print("[AppView] body rendered - needsOnboarding: \(store.needsOnboarding)")
        return NavigationStack {
            if store.needsOnboarding {
                OnboardingFeatureView(
                    store: store.scope(state: \.onboarding, action: \.onboarding)
                )
                .onChange(of: store.needsOnboarding) { oldValue, newValue in
                    print("[AppView] needsOnboarding changed: \(oldValue) -> \(newValue)")
                }
            } else {
                TabView(selection: Binding(
                    get: { store.tab },
                    set: { store.send(.setTab($0)) }
                )) {
                    AlarmListFeatureView(
                        store: store.scope(state: \.alarmList, action: \.alarmList)
                    )
                    .tabItem { Label("アラーム", systemImage: "alarm") }
                    .tag(AppFeature.State.Tab.alarms)

                    SettingsFeatureView(
                        store: store.scope(state: \.settings, action: \.settings)
                    )
                    .tabItem { Label("設定", systemImage: "gear") }
                    .tag(AppFeature.State.Tab.settings)
                }
            }
        }
        .sheet(isPresented: Binding(
                get: { store.ringing != nil },
                set: { if !$0 { store.send(.dismissRinging) } }
            )) {
                if let ringingState = store.ringing {
                    RingingFeatureView(store: Store(
                        initialState: ringingState,
                        reducer: { RingingFeature() }
                    ))
                    .presentationDetents([.large])
                }
            }
        .sheet(isPresented: Binding(
                get: { store.alarmEdit != nil },
                set: { if !$0 { store.send(.dismissAlarmEdit) } }
            )) {
                if let alarmEditState = store.alarmEdit {
                    AlarmEditFeatureView(store: Store(
                        initialState: alarmEditState,
                        reducer: { AlarmEditFeature() }
                    ))
                    .presentationDetents([.large])
                }
            }
        .sheet(isPresented: Binding(
                get: { store.characterSelect != nil },
                set: { if !$0 { store.send(.dismissCharacterSelect) } }
            )) {
                if let characterSelectState = store.characterSelect {
                    CharacterSelectFeatureView(store: Store(
                        initialState: characterSelectState,
                        reducer: { CharacterSelectFeature() }
                    ))
                    .presentationDetents([.medium, .large])
                }
            }
        .onOpenURL { url in
            store.send(.handleDeepLink(url))
        }
        .task {
            await store.send(.onAppear).finish()
        }
    }
}

extension StoreOf<AppFeature> {
    // Route binding removed - use actions to modify route instead
}

// MARK: - Route Bindings

extension Binding {
    func `case`<Enum, Case>(_ casePath: AnyCasePath<Enum, Case>) -> Binding<Case?> where Value == Enum? {
        Binding<Case?>(
            get: {
                guard let enumValue = self.wrappedValue,
                      let caseValue = casePath.extract(from: enumValue) else {
                    return nil
                }
                return caseValue
            },
            set: { newValue in
                if let newValue = newValue {
                    self.wrappedValue = casePath.embed(newValue)
                } else {
                    self.wrappedValue = nil
                }
            }
        )
    }
}
