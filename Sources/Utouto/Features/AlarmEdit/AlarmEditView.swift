import SwiftUI
import ComposableArchitecture

struct AlarmEditFeatureView: View {
    let store: StoreOf<AlarmEditFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.sectionTime) {
                    Picker(L10n.hour, selection: Binding(
                        get: { store.selectedHour },
                        set: { store.send(.updateHour($0)) }
                    )) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    Picker(L10n.minute, selection: Binding(
                        get: { store.selectedMinute },
                        set: { store.send(.updateMinute($0)) }
                    )) {
                        ForEach(0..<60, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                }

                Section(L10n.sectionLabel) {
                    TextField(L10n.labelPlaceholder, text: Binding(
                        get: { store.label },
                        set: { store.send(.updateLabel($0)) }
                    ))
                }

                Section(L10n.sectionRepeat) {
                    Toggle(L10n.repeatOnceOnly, isOn: Binding(
                        get: { store.isOneTime },
                        set: { _ in store.send(.toggleOneTime) }
                    ))
                    if store.isOneTime {
                        DatePicker(L10n.alarmDate, selection: Binding(
                            get: { store.oneTimeDate },
                            set: { store.send(.updateOneTimeDate($0)) }
                        ), displayedComponents: [.date])
                    } else {
                        VStack {
                            let days = [L10n.weekdaySun, L10n.weekdayMon, L10n.weekdayTue, L10n.weekdayWed, L10n.weekdayThu, L10n.weekdayFri, L10n.weekdaySat]
                            ForEach(0..<7, id: \.self) { i in
                                Toggle(days[i], isOn: Binding(
                                    get: { store.repeatDays.contains(i) },
                                    set: { _ in store.send(.toggleRepeatDay(i)) }
                                ))
                            }
                        }
                    }
                }

                Section(L10n.sectionClip) {
                    Picker(L10n.clipPickerTitle, selection: Binding(
                        get: { store.selectedClipId },
                        set: { store.send(.selectClip($0)) }
                    )) {
                        Text(L10n.alarmSoundNone).tag(UUID?.none)
                        ForEach(store.availableClips) { clip in
                            Text(clip.title).tag(Optional(clip.id))
                        }
                    }
                }

                Section(L10n.sectionSnooze) {
                    Toggle(L10n.snoozeEnabled, isOn: Binding(
                        get: { store.snoozeEnabled },
                        set: { _ in store.send(.toggleSnoozeEnabled) }
                    ))
                    if store.snoozeEnabled {
                        Picker(L10n.snoozeInterval, selection: Binding(
                            get: { store.snoozeIntervalMin },
                            set: { store.send(.updateSnoozeInterval($0)) }
                        )) {
                            ForEach([1, 5, 10, 15, 30], id: \.self) { i in
                                Text(String(format: L10n.minutesFormat, i)).tag(i)
                            }
                        }
                        Picker(L10n.snoozeMaxCount, selection: Binding(
                            get: { store.snoozeMaxCount },
                            set: { store.send(.updateSnoozeMaxCount($0)) }
                        )) {
                            Text(String(format: L10n.timesFormat, 3)).tag(Alarm.SnoozeMaxCount.limited(3))
                            Text(String(format: L10n.timesFormat, 5)).tag(Alarm.SnoozeMaxCount.limited(5))
                            Text(L10n.snoozeUnlimited).tag(Alarm.SnoozeMaxCount.unlimited)
                        }
                    }
                }

                Section(L10n.sectionDismiss) {
                    Picker(L10n.dismissMethodPicker, selection: Binding(
                        get: { store.dismissMode },
                        set: { store.send(.updateDismissMode($0)) }
                    )) {
                        Text(L10n.dismissSlide).tag(Alarm.DismissMode.slide)
                        Text(L10n.dismissLongPress).tag(Alarm.DismissMode.longPress)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(store.isNew ? L10n.alarmEditTitleNew : L10n.alarmEditTitleEdit)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { store.send(.cancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) { store.send(.saveAlarm) }
                        .disabled(!store.canSave || store.isSaving)
                }
            }
            .task { await store.send(.loadClips).finish() }
        }
    }
}
