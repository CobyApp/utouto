import SwiftUI
import ComposableArchitecture

struct AppFeatureView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Group {
            if store.isCheckingAuth {
                // 権限確認中は何も表示しない（ランチスクリーンから自然に遷移）
                Color(.systemBackground)
            } else if store.needsOnboarding {
                OnboardingFeatureView(
                    store: store.scope(state: \.onboarding, action: \.onboarding)
                )
            } else {
                mainTabView
            }
        }
        // .task を最上位に置くことで、権限確認を起動直後に必ず実行
        .task { await store.send(.onAppear).finish() }
    }

    private var mainTabView: some View {
        TabView(selection: Binding(
            get: { store.tab },
            set: { store.send(.setTab($0)) }
        )) {
            AlarmListFeatureView(
                store: store.scope(state: \.alarmList, action: \.alarmList)
            )
            .tabItem { Label(L10n.tabAlarms, systemImage: "alarm") }
            .tag(AppFeature.State.Tab.alarms)

            MyLibraryView(
                store: store.scope(state: \.myLibrary, action: \.myLibrary)
            )
            .tabItem { Label(L10n.tabMyLibrary, systemImage: "music.note.list") }
            .tag(AppFeature.State.Tab.myLibrary)

            CommunityView(
                store: store.scope(state: \.community, action: \.community)
            )
            .tabItem { Label(L10n.tabCommunity, systemImage: "person.3") }
            .tag(AppFeature.State.Tab.community)

            SettingsFeatureView(
                store: store.scope(state: \.settings, action: \.settings)
            )
            .tabItem { Label(L10n.tabSettings, systemImage: "gear") }
            .tag(AppFeature.State.Tab.settings)
        }
        .sheet(isPresented: Binding(
            get: { store.alarmEdit != nil },
            set: { _ in }
        ), onDismiss: {
            store.send(.dismissAlarmEdit)
        }) {
            if let alarmEditStore = store.scope(state: \.alarmEdit, action: \.alarmEdit) {
                AlarmEditFeatureView(store: alarmEditStore)
                    .presentationDetents([.large])
            }
        }
        .sheet(isPresented: Binding(
            get: { store.ringing != nil },
            set: { _ in }
        ), onDismiss: {
            store.send(.dismissRinging)
        }) {
            if let ringingStore = store.scope(state: \.ringing, action: \.ringing) {
                RingingFeatureView(store: ringingStore)
                    .presentationDetents([.large])
                    .interactiveDismissDisabled()
            }
        }
        .onOpenURL { store.send(.handleDeepLink($0)) }
    }
}
