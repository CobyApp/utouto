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
            .navigationTitle(store.alarm.label.isEmpty ? L10n.alarmDefaultLabel : store.alarm.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { store.send(.delegate(.dismiss)) }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.delegate(.edit(store.alarm)))
                    } label: {
                        Text(L10n.edit).fontWeight(.semibold)
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

            Text(store.alarm.enabled ? L10n.alarmEnabled : L10n.alarmDisabled)
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
                infoRow(icon: "tag", title: L10n.alarmLabel, value: store.alarm.label)
                Divider().padding(.leading, 52)
            }

            infoRow(
                icon: "repeat",
                title: L10n.alarmRepeat,
                value: L10n.repeatDaysString(repeatDays: store.alarm.repeatDays, isEmpty: store.alarm.repeatDays.isEmpty, isFullWeek: store.alarm.repeatDays.count == 7)
            )

            if store.alarm.oneTimeDate != nil {
                Divider().padding(.leading, 52)
                infoRow(
                    icon: "calendar",
                    title: L10n.alarmDate,
                    value: store.alarm.oneTimeDate.map { formatDate($0) } ?? ""
                )
            }

            Divider().padding(.leading, 52)

            if let clipTitle = store.clipTitle {
                infoRow(icon: "music.note", title: L10n.alarmSound, value: clipTitle)
            } else if store.alarm.clipId != nil {
                infoRow(icon: "music.note", title: L10n.alarmSound, value: L10n.alarmSoundLoading)
            } else {
                infoRow(icon: "speaker.slash", title: L10n.alarmSound, value: L10n.alarmSoundNone)
            }

            Divider().padding(.leading, 52)

            if store.alarm.snoozeEnabled {
                infoRow(
                    icon: "clock.arrow.circlepath",
                    title: L10n.snooze,
                    value: String(format: L10n.minutesFormat, store.alarm.snoozeIntervalMin) + " / " + snoozeMaxText
                )
            } else {
                infoRow(icon: "clock.arrow.circlepath", title: L10n.snooze, value: L10n.snoozeOff)
            }

            Divider().padding(.leading, 52)

            infoRow(
                icon: "hand.tap",
                title: L10n.dismissMethod,
                value: store.alarm.dismissMode == .slide ? L10n.dismissSlide : L10n.dismissLongPress
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
                    Text(L10n.alarmEditButton)
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
                    Text(L10n.alarmDeleteButton)
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
        case .unlimited: return L10n.snoozeUnlimited
        case let .limited(n): return String(format: L10n.timesFormat, n)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: L10n.appLanguageCode ?? Locale.current.language.languageCode?.identifier ?? "en")
        return f.string(from: date)
    }
}
