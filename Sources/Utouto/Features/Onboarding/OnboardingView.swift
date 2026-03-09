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

            Text("通知許可")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("うとうと が適切に動作するためには\n通知の許可が必要です。")
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
                        Text("通知を許可")
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
                    Text("設定へ")
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
