import Foundation
import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State {
        enum Tab: Hashable { case alarms, myLibrary, community, settings }
        var tab: Tab = .alarms
        var isCheckingAuth: Bool = true  // 起動時の権限確認中フラグ
        var needsOnboarding = false

        var onboarding = OnboardingFeature.State()
        var alarmList = AlarmListFeature.State()
        var myLibrary = MyLibraryFeature.State()
        var community = CommunityFeature.State()
        var settings = SettingsFeature.State()

        var alarmEdit: AlarmEditFeature.State?
        var ringing: RingingFeature.State?
    }

    enum Action {
        case onAppear
        case checkNotificationAuthorization
        case setNeedsOnboarding(Bool)
        case handleDeepLink(URL)
        case setTab(State.Tab)
        case dismissAlarmEdit
        case dismissRinging
        case onboarding(OnboardingFeature.Action)
        case alarmList(AlarmListFeature.Action)
        case myLibrary(MyLibraryFeature.Action)
        case community(CommunityFeature.Action)
        case settings(SettingsFeature.Action)
        case alarmEdit(AlarmEditFeature.Action)
        case ringing(RingingFeature.Action)
    }

    @Dependency(\.alarmKitClient) var alarmKitClient
    @Dependency(\.clipImportClient) var clipImportClient
    @Dependency(\.appRouter) var appRouter

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                return .run { send in await send(.checkNotificationAuthorization) }

            case .checkNotificationAuthorization:
                return .run { send in
                    let ok = await alarmKitClient.isAuthorized()
                    await send(.setNeedsOnboarding(!ok))
                }

            case let .setNeedsOnboarding(v):
                state.needsOnboarding = v
                state.isCheckingAuth = false  // 確認完了
                return .none

            case let .handleDeepLink(url):
                guard let deepLink = appRouter.parseDeepLink(url) else { return .none }
                switch deepLink {
                case .ringing(let alarmId):
                    state.ringing = RingingFeature.State(alarmId: alarmId)
                }
                return .none

            case let .setTab(t):
                state.tab = t; return .none

            case .alarmList(.delegate(.showAlarmEdit(let alarm))):
                state.alarmEdit = AlarmEditFeature.State(alarm: alarm)
                return .none

            case .alarmList: return .none

            case .alarmEdit(.delegate(.dismiss)):
                state.alarmEdit = nil; return .none

            case .alarmEdit(.delegate(.saveAlarm)):
                state.alarmEdit = nil
                return .send(.alarmList(.loadAlarms))

            case .alarmEdit: return .none

            case .myLibrary(.delegate(.selectClipForAlarm(let clip))):
                var editState = AlarmEditFeature.State(alarm: nil)
                editState.selectedClipId = clip.id
                state.alarmEdit = editState
                state.tab = .alarms
                return .none

            case .myLibrary: return .none

            case .community(.delegate(.useClipAsAlarm(let url, let communityClip))):
                var editState = AlarmEditFeature.State(alarm: nil)
                editState.selectedClipId = communityClip.id
                state.alarmEdit = editState
                state.tab = .alarms
                return .run { send in
                    try? await clipImportClient.importCommunityClip(communityClip, url)
                    await send(.myLibrary(.loadClips))
                }

            case .community: return .none

            case .ringing(.delegate(.dismiss)):
                state.ringing = nil; return .none
            case .ringing: return .none

            case .settings: return .none

            case .onboarding(.delegate(.authorizationGranted)):
                return .send(.setNeedsOnboarding(false))
            case .onboarding: return .none

            case .dismissAlarmEdit:
                state.alarmEdit = nil; return .none
            case .dismissRinging:
                state.ringing = nil; return .none
            }
        }
        .ifLet(\.alarmEdit, action: \.alarmEdit) { AlarmEditFeature() }
        .ifLet(\.ringing, action: \.ringing) { RingingFeature() }

        Scope(state: \.onboarding, action: \.onboarding) { OnboardingFeature() }
        Scope(state: \.alarmList, action: \.alarmList) { AlarmListFeature() }
        Scope(state: \.myLibrary, action: \.myLibrary) { MyLibraryFeature() }
        Scope(state: \.community, action: \.community) { CommunityFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }
    }
}
