import Foundation
import SwiftUI

/// Centralized localization. Uses device language by default; override in Settings (UserDefaults "app_language": "ko" | "ja" | "en" | nil).
enum L10n {
    private static let appLanguageKey = "app_language"

    /// Current app language override. nil or empty = follow system.
    static var appLanguageCode: String? {
        get {
            let v = UserDefaults.standard.string(forKey: appLanguageKey)
            return (v == nil || v?.isEmpty == true) ? nil : v
        }
        set { UserDefaults.standard.set(newValue?.isEmpty == true ? nil : newValue, forKey: appLanguageKey) }
    }

    /// Bundle for the current language (override or system, fallback to en).
    static var bundle: Bundle {
        let code = appLanguageCode ?? Locale.current.language.languageCode?.identifier
        if let code = code, let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.main
    }

    /// Localized string for key.
    static func tr(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    /// Supported languages for Settings picker. tag = "" for system, else "ko"/"ja"/"en".
    static func supportedLanguageTags() -> [(tag: String, name: String)] {
        [
            ("", tr("language.system")),
            ("ko", tr("language.korean")),
            ("ja", tr("language.japanese")),
            ("en", tr("language.english")),
        ]
    }
}

// MARK: - String keys (single place for all UI text)

extension L10n {
    // Tab
    static var tabAlarms: String { tr("tab.alarms") }
    static var tabMyLibrary: String { tr("tab.my_library") }
    static var tabCommunity: String { tr("tab.community") }
    static var tabSettings: String { tr("tab.settings") }

    // Alarm list
    static var alarmListTitle: String { tr("alarm.list.title") }
    static var alarmEmptyTitle: String { tr("alarm.list.empty_title") }
    static var alarmEmptySubtitle: String { tr("alarm.list.empty_subtitle") }
    static var alarmAdd: String { tr("alarm.list.add") }
    static var alarmDeleteConfirmTitle: String { tr("alarm.list.delete_confirm_title") }
    static var alarmDeleteConfirmMessage: String { tr("alarm.list.delete_confirm_message") }
    static var delete: String { tr("common.delete") }
    static var cancel: String { tr("common.cancel") }
    static var close: String { tr("common.close") }
    static var save: String { tr("common.save") }
    static var edit: String { tr("common.edit") }
    static var commonOk: String { tr("common.ok") }

    // Alarm detail
    static var alarmDefaultLabel: String { tr("alarm.detail.default_label") }
    static var alarmEnabled: String { tr("alarm.detail.enabled") }
    static var alarmDisabled: String { tr("alarm.detail.disabled") }
    static var alarmLabel: String { tr("alarm.detail.label") }
    static var alarmRepeat: String { tr("alarm.detail.repeat") }
    static var alarmDate: String { tr("alarm.detail.date") }
    static var alarmSound: String { tr("alarm.detail.sound") }
    static var alarmSoundLoading: String { tr("alarm.detail.sound_loading") }
    static var alarmSoundNone: String { tr("alarm.detail.sound_none") }
    static var snooze: String { tr("alarm.detail.snooze") }
    static var snoozeOff: String { tr("alarm.detail.snooze_off") }
    static var dismissMethod: String { tr("alarm.detail.dismiss_method") }
    static var dismissSlide: String { tr("alarm.detail.dismiss_slide") }
    static var dismissLongPress: String { tr("alarm.detail.dismiss_long_press") }
    static var alarmEditButton: String { tr("alarm.detail.edit_button") }
    static var alarmDeleteButton: String { tr("alarm.detail.delete_button") }
    static var snoozeUnlimited: String { tr("alarm.detail.snooze_unlimited") }

    // Alarm edit
    static var alarmEditTitleNew: String { tr("alarm.edit.title_new") }
    static var alarmEditTitleEdit: String { tr("alarm.edit.title_edit") }
    static var sectionTime: String { tr("alarm.edit.section_time") }
    static var sectionLabel: String { tr("alarm.edit.section_label") }
    static var sectionRepeat: String { tr("alarm.edit.section_repeat") }
    static var sectionClip: String { tr("alarm.edit.section_clip") }
    static var sectionSnooze: String { tr("alarm.edit.section_snooze") }
    static var sectionDismiss: String { tr("alarm.edit.section_dismiss") }
    static var hour: String { tr("alarm.edit.hour") }
    static var minute: String { tr("alarm.edit.minute") }
    static var labelPlaceholder: String { tr("alarm.edit.label_placeholder") }
    static var repeatOnce: String { tr("alarm.edit.repeat_once") }
    static var clipPickerTitle: String { tr("alarm.edit.clip_picker_title") }
    static var snoozeEnabled: String { tr("alarm.edit.snooze_enabled") }
    static var snoozeInterval: String { tr("alarm.edit.snooze_interval") }
    static var snoozeMaxCount: String { tr("alarm.edit.snooze_max_count") }
    static var dismissMethodPicker: String { tr("alarm.edit.dismiss_method_picker") }
    static var minutesFormat: String { tr("alarm.edit.minutes_format") }
    static var timesFormat: String { tr("alarm.edit.times_format") }
    static var alarmScheduleFailedTitle: String { tr("alarm.edit.schedule_failed_title") }
    static var alarmScheduleFailedHint: String { tr("alarm.edit.schedule_failed_hint") }

    // Ringing
    static var slideToWake: String { tr("ringing.slide_to_wake") }
    static var longPressToWake: String { tr("ringing.long_press_to_wake") }

    // My Library
    static var myLibraryTitle: String { tr("library.title") }
    static var libraryEmptyTitle: String { tr("library.empty_title") }
    static var libraryEmptySubtitle: String { tr("library.empty_subtitle") }
    static var libraryCreateClip: String { tr("library.create_clip") }
    static var libraryDeleteConfirmTitle: String { tr("library.delete_confirm_title") }
    static var libraryDeleteConfirmMessage: String { tr("library.delete_confirm_message") }
    static var useAsAlarm: String { tr("library.use_as_alarm") }
    static var share: String { tr("library.share") }
    static var uploadedToCommunity: String { tr("library.uploaded_to_community") }
    static var uploadToCommunity: String { tr("library.upload_to_community") }
    static var uploading: String { tr("library.uploading") }
    static var play: String { tr("library.play") }
    static var stop: String { tr("library.stop") }
    static var clipDeleteConfirmTitle: String { tr("library.clip_delete_confirm_title") }
    static func clipDeleteConfirmMessage(title: String) -> String {
        String(format: tr("library.clip_delete_confirm_message"), title)
    }

    // Clip editor
    static var clipCreateTitle: String { tr("clip_editor.title") }
    static var clipPickVideoTitle: String { tr("clip_editor.pick_video_title") }
    static var clipPickVideoSubtitle: String { tr("clip_editor.pick_video_subtitle") }
    static var clipOpenPhotoLibrary: String { tr("clip_editor.open_photo_library") }
    static var clipOpenFiles: String { tr("clip_editor.open_files") }
    static var clipTrimRange: String { tr("clip_editor.trim_range") }
    static var clipNameLabel: String { tr("clip_editor.clip_name_label") }
    static var clipNamePlaceholder: String { tr("clip_editor.clip_name_placeholder") }
    static var clipPreviewing: String { tr("clip_editor.previewing") }
    static var clipSaving: String { tr("clip_editor.saving") }
    static var clipSaveSuccess: String { tr("clip_editor.save_success") }
    static var clipSaveSuccessSubtitle: String { tr("clip_editor.save_success_subtitle") }
    static var clipBackToLibrary: String { tr("clip_editor.back_to_library") }
    static var clipDurationMin: String { tr("clip_editor.duration_min") }
    static var clipDurationMax: String { tr("clip_editor.duration_max") }
    static var secondsFormat: String { tr("clip_editor.seconds_format") }

    // Community
    static var communityTitle: String { tr("community.title") }
    static var communitySearchPlaceholder: String { tr("community.search_placeholder") }
    static var communityEmptySearch: String { tr("community.empty_search") }
    static var communityEmptyDefault: String { tr("community.empty_default") }
    static var communityShowAll: String { tr("community.show_all") }
    static var communityLoadMore: String { tr("community.load_more") }

    // Settings
    static var settingsTitle: String { tr("settings.title") }
    static var settingsPermissions: String { tr("settings.permissions") }
    static var settingsNotification: String { tr("settings.notification") }
    static var settingsNotificationAllowed: String { tr("settings.notification_allowed") }
    static var settingsNotificationDenied: String { tr("settings.notification_denied") }
    static var settingsOpenSystemSettings: String { tr("settings.open_system_settings") }
    static var settingsDefaultSnooze: String { tr("settings.default_snooze") }
    static var settingsDefaultDismiss: String { tr("settings.default_dismiss") }
    static var settingsOther: String { tr("settings.other") }
    static var settingsVibration: String { tr("settings.vibration") }
    static var settingsLanguage: String { tr("settings.language") }
    static var settingsLanguageSection: String { tr("settings.language_section") }

    // Onboarding
    static var onboardingPermissionTitle: String { tr("onboarding.permission_title") }
    static var onboardingPermissionMessage: String { tr("onboarding.permission_message") }
    static var onboardingAllowButton: String { tr("onboarding.allow_button") }
    static var onboardingOpenSettings: String { tr("onboarding.open_settings") }

    // AlarmKit (system alert, countdown, paused)
    static var alarmKitDefaultTitle: String { tr("alarm_kit.default_title") }
    static var alarmKitSnoozeButton: String { tr("alarm_kit.snooze_button") }
    static var alarmKitCountdownTitle: String { tr("alarm_kit.countdown_title") }
    static var alarmKitPauseButton: String { tr("alarm_kit.pause_button") }
    static var alarmKitResumeButton: String { tr("alarm_kit.resume_button") }
    static var alarmKitPausedTitle: String { tr("alarm_kit.paused_title") }

    // Repeat / weekdays
    static var repeatOnceOnly: String { tr("alarm.repeat_once") }
    static var repeatDaily: String { tr("alarm.repeat_daily") }
    static var weekdaySun: String { tr("alarm.weekday_sun") }
    static var weekdayMon: String { tr("alarm.weekday_mon") }
    static var weekdayTue: String { tr("alarm.weekday_tue") }
    static var weekdayWed: String { tr("alarm.weekday_wed") }
    static var weekdayThu: String { tr("alarm.weekday_thu") }
    static var weekdayFri: String { tr("alarm.weekday_fri") }
    static var weekdaySat: String { tr("alarm.weekday_sat") }

    static func repeatDaysString(repeatDays: [Int], isEmpty: Bool, isFullWeek: Bool) -> String {
        if isEmpty { return repeatOnceOnly }
        if isFullWeek { return repeatDaily }
        let names = [weekdaySun, weekdayMon, weekdayTue, weekdayWed, weekdayThu, weekdayFri, weekdaySat]
        return repeatDays.sorted().map { names[$0] }.joined(separator: " ")
    }

    // Wake texts (random)
    static var wakeTexts: [String] { [tr("wake.1"), tr("wake.2"), tr("wake.3"), tr("wake.4"), tr("wake.5")] }
}
