import SwiftUI
import ComposableArchitecture

struct AlarmDetailView: View {
    let store: StoreOf<AlarmDetailFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    timeHeader
                    infoCards
                    actionButtons
                }
                .padding()
            }
            .navigationTitle(store.alarm.label.isEmpty ? "アラーム" : store.alarm.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { store.send(.delegate(.dismiss)) }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.delegate(.edit(store.alarm)))
                    } label: {
                        Text("編集").fontWeight(.semibold)
                    }
                }
            }
            .task { await store.send(.onAppear).finish() }
        }
    }

    // MARK: - Time Header

    private var timeHeader: some View {
        VStack(spacing: 8) {
            Text(store.alarm.timeString)
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .monospacedDigit()

            Toggle(isOn: Binding(
                get: { store.alarm.enabled },
                set: { _ in store.send(.toggleEnabled) }
            )) {
                EmptyView()
            }
            .labelsHidden()
            .scaleEffect(1.2)

            Text(store.alarm.enabled ? "有効" : "無効")
                .font(.subheadline)
                .foregroundStyle(store.alarm.enabled ? .green : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Info Cards

    private var infoCards: some View {
        VStack(spacing: 1) {
            if !store.alarm.label.isEmpty {
                infoRow(icon: "tag", title: "ラベル", value: store.alarm.label)
                Divider().padding(.leading, 52)
            }

            infoRow(
                icon: "repeat",
                title: "繰り返し",
                value: store.alarm.repeatDaysString
            )

            if store.alarm.oneTimeDate != nil {
                Divider().padding(.leading, 52)
                infoRow(
                    icon: "calendar",
                    title: "日付",
                    value: store.alarm.oneTimeDate.map { formatDate($0) } ?? ""
                )
            }

            Divider().padding(.leading, 52)

            if let clipTitle = store.clipTitle {
                infoRow(icon: "music.note", title: "アラーム音", value: clipTitle)
            } else if store.alarm.clipId != nil {
                infoRow(icon: "music.note", title: "アラーム音", value: "読み込み中...")
            } else {
                infoRow(icon: "speaker.slash", title: "アラーム音", value: "なし")
            }

            Divider().padding(.leading, 52)

            if store.alarm.snoozeEnabled {
                infoRow(
                    icon: "clock.arrow.circlepath",
                    title: "スヌーズ",
                    value: "\(store.alarm.snoozeIntervalMin)分 / \(snoozeMaxText)"
                )
            } else {
                infoRow(icon: "clock.arrow.circlepath", title: "スヌーズ", value: "オフ")
            }

            Divider().padding(.leading, 52)

            infoRow(
                icon: "hand.tap",
                title: "解除方法",
                value: store.alarm.dismissMode == .slide ? "スライド" : "長押し"
            )
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                store.send(.delegate(.edit(store.alarm)))
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("アラームを編集")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button(role: .destructive) {
                store.send(.delegate(.delete(store.alarm)))
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("削除")
                }
                .font(.headline)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Helpers

    private var snoozeMaxText: String {
        switch store.alarm.snoozeMaxCount {
        case .unlimited: return "無制限"
        case let .limited(n): return "\(n)回"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: date)
    }
}
