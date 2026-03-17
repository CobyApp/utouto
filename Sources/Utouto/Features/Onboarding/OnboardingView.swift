import SwiftUI
import ComposableArchitecture

struct OnboardingFeatureView: View {
    let store: StoreOf<OnboardingFeature>

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            Text(L10n.onboardingPermissionTitle)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(L10n.onboardingPermissionMessage)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 16) {
                Button {
                    print("[OnboardingView] '通知を許可' button tapped")
                    store.send(.requestAuthorization)
                } label: {
                    if store.isRequesting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(L10n.onboardingAllowButton)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(store.isRequesting ? Color.gray : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(store.isRequesting)

                Button {
                    store.send(.openSettings)
                } label: {
                    Text(L10n.onboardingOpenSettings)
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
        }
        .padding()
    }
}
