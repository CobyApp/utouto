import SwiftUI
import ComposableArchitecture

struct ClipDetailView: View {
    let store: StoreOf<ClipDetailFeature>

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: L10n.appLanguageCode ?? Locale.current.language.languageCode?.identifier ?? "en")
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.bottom, 32)

                    playSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)

                    Divider()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    actionsSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    Divider()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                    deleteSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                }
            }
            .navigationTitle(store.clip.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { store.send(.dismiss) }
                }
            }
            .alert(L10n.clipDeleteConfirmTitle, isPresented: Binding(
                get: { store.showDeleteAlert },
                set: { if !$0 { store.send(.cancelDelete) } }
            )) {
                Button(L10n.delete, role: .destructive) { store.send(.confirmDelete) }
                Button(L10n.cancel, role: .cancel) { store.send(.cancelDelete) }
            } message: {
                Text(L10n.clipDeleteConfirmMessage(title: store.clip.title))
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 148, height: 148)

                Image(systemName: store.isPlaying ? "waveform" : "music.note")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                    )
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: store.isPlaying)
            }
            .padding(.top, 28)

            VStack(spacing: 6) {
                Text(store.clip.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack(spacing: 8) {
                    Label(store.clip.durationString, systemImage: "clock")
                    Text("·")
                    Text(store.clip.createdAt, formatter: dateFormatter)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
    }

    // MARK: - Play

    private var playSection: some View {
        Button { store.send(.togglePlay) } label: {
            HStack(spacing: 12) {
                Image(systemName: store.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 26))
                Text(store.isPlaying ? L10n.stop : L10n.play)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(store.isPlaying ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
            .foregroundStyle(store.isPlaying ? .red : .blue)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {

            // アラームに使う
            menuButton(title: L10n.useAsAlarm, icon: "alarm.fill", color: .orange) {
                store.send(.useAsAlarm)
            }

            // 共有（ShareLink）
            ShareLink(
                item: store.audioFileURL,
                subject: Text(store.clip.title),
                preview: SharePreview(
                    store.clip.title,
                    icon: Image(systemName: "music.note")
                )
            ) {
                menuRow(title: L10n.share, icon: "square.and.arrow.up", color: .blue)
            }

            // コミュニティに投稿
            if store.clip.isUploaded {
                menuRow(title: L10n.uploadedToCommunity, icon: "checkmark.icloud.fill", color: .green, showChevron: false)
                    .opacity(0.6)
            } else {
                Button {
                    store.send(.uploadToCommunity)
                } label: {
                    HStack(spacing: 14) {
                        Group {
                            if store.isUploading {
                                ProgressView().scaleEffect(0.85)
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .frame(width: 28)
                        .foregroundStyle(.teal)

                        Text(store.isUploading ? L10n.uploading : L10n.uploadToCommunity)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        if !store.isUploading {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 54)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(store.isUploading)
            }

            // エラー表示
            if let msg = store.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(msg).font(.caption)
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button { store.send(.requestDelete) } label: {
            HStack(spacing: 14) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 28)
                Text(L10n.delete)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 54)
            .background(Color.red.opacity(0.08))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func menuButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            menuRow(title: title, icon: icon, color: color)
        }
    }

    private func menuRow(title: String, icon: String, color: Color, showChevron: Bool = true) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 28)
                .foregroundStyle(color)
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 54)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
