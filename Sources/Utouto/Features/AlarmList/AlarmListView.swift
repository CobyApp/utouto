import SwiftUI
import ComposableArchitecture

struct AlarmListFeatureView: View {
    let store: StoreOf<AlarmListFeature>
    var body: some View {
        NavigationStack {
            ZStack {
                if store.alarms.isEmpty && !store.isLoading { emptyStateView }
                else { alarmListView }
                if store.isLoading { ProgressView() }
            }
            .navigationTitle(L10n.alarmListTitle)
            .toolbar {
                Button { store.send(.addAlarm) } label: { Image(systemName: "plus") }
            }
            .alert(L10n.alarmDeleteConfirmTitle, isPresented: Binding(
                get: { store.showDeleteAlert },
                set: { _ in store.send(.hideDeleteAlert) }
            ), presenting: store.alarmToDelete) { alarm in
                Button(L10n.delete, role: .destructive) { store.send(.confirmDelete(alarm)) }
            } message: { _ in Text(L10n.alarmDeleteConfirmMessage) }
            .sheet(isPresented: Binding(
                get: { store.alarmDetail != nil },
                set: { _ in }
            ), onDismiss: {
                store.send(.hideAlarmDetail)
            }) {
                if let detailStore = store.scope(state: \.alarmDetail, action: \.alarmDetail) {
                    AlarmDetailView(store: detailStore)
                        .presentationDetents([.large])
                }
            }
            .task { await store.send(.loadAlarms).finish() }
        }
    }
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "alarm").font(.system(size: 60)).foregroundStyle(.secondary)
            Text(L10n.alarmEmptyTitle).font(.headline).foregroundStyle(.secondary)
            Text(L10n.alarmEmptySubtitle).font(.subheadline).foregroundStyle(.secondary)
            Button { store.send(.addAlarm) } label: {
                Text(L10n.alarmAdd).font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.blue).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    private var alarmListView: some View {
        List {
            ForEach(store.alarms) { alarm in
                AlarmRowView(alarm: alarm) { store.send(.toggleAlarm(alarm)) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { store.send(.deleteAlarm(alarm)) } label: {
                            Label(L10n.delete, systemImage: "trash")
                        }
                    }
                    .onTapGesture { store.send(.showAlarmDetail(alarm)) }
            }
        }.listStyle(.insetGrouped)
    }
}

struct AlarmRowView: View {
    let alarm: Alarm
    let onToggle: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.label.isEmpty ? L10n.alarmDefaultLabel : alarm.label).font(.headline)
                HStack(spacing: 12) {
                    Text(alarm.timeString).font(.title2).fontWeight(.bold)
                    if !alarm.repeatDays.isEmpty {
                        Text(alarm.repeatDaysString).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { alarm.enabled }, set: { _ in onToggle() })).labelsHidden()
        }
        .padding(.vertical, 8).opacity(alarm.enabled ? 1.0 : 0.6)
    }
}
