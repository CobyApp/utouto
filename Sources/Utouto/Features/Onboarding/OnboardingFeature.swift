import ComposableArchitecture

@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        var isAuthorized = false
        var isRequesting = false
    }

    enum Action {
        case requestAuthorization
        case authorizationResponse(Bool)
        case openSettings

        @CasePathable
        enum Delegate {
            case authorizationGranted
        }

        case delegate(Delegate)
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.appRouter) var appRouter
    @Dependency(\.logger) var logger

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .requestAuthorization:
                state.isRequesting = true
                logger.log("[Onboarding] Requesting authorization...")
                return .run { send in
                    do {
                        let granted = try await notificationClient.requestAuthorization()
                        logger.log("[Onboarding] Authorization response: \(granted)")
                        await send(.authorizationResponse(granted))
                    } catch {
                        logger.error("[Onboarding] Authorization error: \(error)")
                        await send(.authorizationResponse(false))
                    }
                }

            case let .authorizationResponse(granted):
                logger.log("[Onboarding] authorizationResponse received: \(granted)")
                state.isAuthorized = granted
                state.isRequesting = false
                if granted {
                    logger.log("[Onboarding] Sending delegate authorizationGranted")
                    return .send(.delegate(.authorizationGranted))
                } else {
                    logger.log("[Onboarding] Authorization not granted, staying on onboarding")
                }
                return .none

            case .openSettings:
                return .run { _ in
                    await appRouter.openSettings()
                }

            case .delegate:
                return .none
            }
        }
    }
}
