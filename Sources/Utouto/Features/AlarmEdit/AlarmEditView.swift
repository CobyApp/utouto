import SwiftUI
import ComposableArchitecture

struct AlarmEditFeatureView: View {
    let store: StoreOf<AlarmEditFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section("時間") {
                    Picker("時", selection: Binding(
                        get: { store.selectedHour },
                        set: { store.send(.updateHour($0)) }
                    )) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    Picker("分", selection: Binding(
                        get: { store.selectedMinute },
                        set: { store.send(.updateMinute($0)) }
                    )) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                }

                Section("ラベル") {
                    TextField("ラベル (オプション)", text: Binding(
                        get: { store.label },
                        set: { store.send(.updateLabel($0)) }
                    ))
                }

                Section("繰り返し") {
                    Toggle("一度だけ", isOn: Binding(
                        get: { store.isOneTime },
                        set: { _ in store.send(.toggleOneTime) }
                    ))
                    if store.isOneTime {
                        DatePicker("日付", selection: Binding(
                            get: { store.oneTimeDate },
                            set: { store.send(.updateOneTimeDate($0)) }
                        ), displayedComponents: [.date])
                    } else {
                        VStack {
                            let days = ["日", "月", "火", "水", "木", "金", "土"]
                            ForEach(0..<7, id: \.self) { i in
                                Toggle(days[i], isOn: Binding(
                                    get: { store.repeatDays.contains(i) },
                                    set: { if $0 { store.send(.toggleRepeatDay(i)) } else { store.send(.toggleRepeatDay(i)) } }
                                ))
                            }
                        }
                    }
                }

                Section("クリップ") {
                    Picker("使用するクリップ", selection: Binding(
                        get: { store.selectedClipId },
                        set: { store.send(.selectClip($0)) }
                    )) {
                        Text("なし").tag(UUID?.none)
                        ForEach(store.availableClips) { clip in
                            Text(clip.title).tag(Optional(clip.id))
                        }
                    }
                }

                Section("スヌーズ") {
                    Toggle("有効", isOn: Binding(
                        get: { store.snoozeEnabled },
                        set: { _ in store.send(.toggleSnoozeEnabled) }
                    ))
                    if store.snoozeEnabled {
                        Picker("間隔（分）", selection: Binding(
                            get: { store.snoozeIntervalMin },
                            set: { store.send(.updateSnoozeInterval($0)) }
                        )) {
                            ForEach([1, 5, 10, 15, 30], id: \.self) { i in
                                Text("\(i)分").tag(i)
                            }
                        }
                        Picker("最大回数", selection: Binding(
                            get: { store.snoozeMaxCount },
                            set: { store.send(.updateSnoozeMaxCount($0)) }
                        )) {
                            Text("3回").tag(Alarm.SnoozeMaxCount.limited(3))
                            Text("5回").tag(Alarm.SnoozeMaxCount.limited(5))
                            Text("無制限").tag(Alarm.SnoozeMaxCount.unlimited)
                        }
                    }
                }

                Section("解除方法") {
                    Picker("方法", selection: Binding(
                        get: { store.dismissMode },
                        set: { store.send(.updateDismissMode($0)) }
                    )) {
                        Text("スライド").tag(Alarm.DismissMode.slide)
                        Text("長押し").tag(Alarm.DismissMode.longPress)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(store.isNew ? "新しいアラーム" : "アラームを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { store.send(.cancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { store.send(.saveAlarm) }
                        .disabled(!store.canSave || store.isSaving)
                }
            }
            .task { await store.send(.loadClips).finish() }
        }
    }
}
