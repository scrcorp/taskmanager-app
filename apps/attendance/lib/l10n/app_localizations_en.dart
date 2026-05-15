// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HTM Attendance';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionSave => 'Save';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionClose => 'Close';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionDone => 'Done';

  @override
  String get commonHeadsUp => 'Heads up';

  @override
  String get commonSavedTitle => 'Saved';

  @override
  String get commonSaveFailedTitle => 'Couldn\'t save';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonStore => 'Store';

  @override
  String get commonDevice => 'Device';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonUntitled => 'Untitled';

  @override
  String get attAccessCodeRegisterTitle => 'Register This Device';

  @override
  String get attAccessCodeRegisterDescription =>
      'Enter the 6-character access code provided by your manager.';

  @override
  String get attAccessCodeRegisterButton => 'Register Device';

  @override
  String get attAccessCodeChangeStoreTitle => 'Change Store';

  @override
  String get attAccessCodeChangeStoreDescription =>
      'Enter a new 6-character access code to switch this device to a different store.';

  @override
  String get attAccessCodeInvalid => 'Invalid access code';

  @override
  String get attAccessCodeRegisterFailedTitle => 'Couldn\'t register device';

  @override
  String get attStoreSelectTitle => 'Select Store';

  @override
  String attStoreSelectDeviceNeedsAssignment(String deviceName) {
    return 'This device ($deviceName) needs to be assigned to a store.';
  }

  @override
  String get attStoreSelectGenericNeedsAssignment =>
      'This device needs to be assigned to a store.';

  @override
  String get attStoreSelectLoadFailed =>
      'Failed to load stores from server. Showing preset/manual fallback.';

  @override
  String get attStoreSelectEmpty =>
      'No stores available. Contact an administrator.';

  @override
  String get attStoreSelectManualLabel => 'Manual Store ID';

  @override
  String get attStoreSelectManualHint => 'Paste store UUID (fallback)';

  @override
  String get attStoreSelectAssignButton => 'Assign Store';

  @override
  String get attStoreSelectAssignFailed => 'Failed to assign store';

  @override
  String get attStoreSelectAssignFailedTitle => 'Couldn\'t assign store';

  @override
  String get attSettingsTitle => 'Device Settings';

  @override
  String get attSettingsDeviceLabel => 'Device';

  @override
  String get attSettingsStoreLabel => 'Store';

  @override
  String get attSettingsStoreNotAssigned => 'Not assigned';

  @override
  String get attSettingsDeviceIdLabel => 'Device ID';

  @override
  String get attSettingsLanguageLabel => 'Language';

  @override
  String get attSettingsLanguageEnglish => 'English';

  @override
  String get attSettingsLanguageSpanish => 'Español';

  @override
  String get attSettingsChangeStore => 'Change Store';

  @override
  String get attSettingsChangeStoreConfirm =>
      'To switch this device to a different store, you will need a new access code. The current device registration will be revoked.';

  @override
  String get attSettingsKioskLockTitle => 'Kiosk Lock';

  @override
  String get attSettingsKioskLockOn =>
      'App is locked. Disable to use device freely.';

  @override
  String get attSettingsKioskLockOff =>
      'App is unlocked. Enable to restrict device.';

  @override
  String get attSettingsKioskEnableTitle => 'Enable Kiosk Lock';

  @override
  String get attSettingsKioskEnableMessage =>
      'Android will show a system dialog asking to pin this app. You MUST tap \"Got it\" / \"OK\" to enable kiosk mode. Tapping \"No thanks\" will leave the device unlocked.';

  @override
  String get attSettingsKioskNotActiveTitle => 'Lock Not Active';

  @override
  String get attSettingsKioskNotActiveMessage =>
      'You declined the pinning prompt. Kiosk mode is required for this device. Tap Retry and confirm the system dialog.';

  @override
  String get attSettingsKioskDisableTitle => 'Disable Kiosk Lock';

  @override
  String get attSettingsKioskDisableConfirm => 'Unlock';

  @override
  String get attSettingsKioskDisabledTitle => 'Kiosk Disabled';

  @override
  String get attSettingsKioskDisabledMessage =>
      'Kiosk lock will re-enable automatically in 5 minutes. Toggle it back on at any time to re-lock immediately.';

  @override
  String get attSettingsUnregister => 'Unregister This Device';

  @override
  String get attSettingsUnregisterConfirmTitle => 'Unregister Device';

  @override
  String get attSettingsUnregisterConfirmMessage =>
      'This device will be removed from the organization. You will need a new access code to register again.';

  @override
  String get attSettingsUnregisterVerifyTitle => 'Confirm Unregister';

  @override
  String get attSettingsUnregisterVerifyConfirm => 'Unregister';

  @override
  String get attSettingsAccessCodePromptTitle => 'Cannot Continue';

  @override
  String get attSettingsAccessCodePromptMessage =>
      'No access code on file. Re-register this device to enable this action.';

  @override
  String get attSettingsAccessCodeEnter => 'Enter the device access code.';

  @override
  String get attSettingsAccessCodeIncorrectTitle => 'Incorrect Code';

  @override
  String get attSettingsAccessCodeIncorrectMessage =>
      'The access code did not match.';

  @override
  String get attSettingsAccessCodeHint => 'ABC123';

  @override
  String get attSettingsKioskUnlockedTitle => 'Kiosk Unlocked';

  @override
  String get attSettingsKioskUnlockedMessage =>
      'You may now navigate away from the app. Re-register or reinstall to re-enable kiosk mode.';

  @override
  String attPinHi(String name) {
    return 'Hi, $name';
  }

  @override
  String get attPinTitle => 'Enter Your PIN';

  @override
  String attPinSubtitle(int length) {
    return 'Please use your $length-digit number to proceed';
  }

  @override
  String get attPinCancelReturn => 'Cancel & Return';

  @override
  String get attPinVerify => 'Verify Identity';

  @override
  String get attPinPadClear => 'CLEAR';

  @override
  String get attPinSecureAccessTitle => 'Secure Access';

  @override
  String get attPinSecureAccessDescription =>
      'Verification ensures the safety and accountability of all staff members.';

  @override
  String get attPinShiftRecognitionTitle => 'Shift Recognition';

  @override
  String get attPinShiftRecognitionDescription =>
      'Clocking in registers your presence for the current cycle.';

  @override
  String get attPinVerificationFailedTitle => 'Verification Failed';

  @override
  String get attPinVerificationFailedMessage =>
      'Invalid PIN. Please try again.';

  @override
  String get attSuccessClockIn => 'Clock In Successful';

  @override
  String get attSuccessClockOut => 'Clock Out Successful';

  @override
  String get attSuccessShortBreak => '10min Break Started';

  @override
  String get attSuccessLongBreak => 'Meal Break Started';

  @override
  String get attSuccessBreakEnded => 'Break Ended';

  @override
  String get attSuccessWelcomeBack => 'Welcome back';

  @override
  String attSuccessWelcomeBackName(String name) {
    return ', $name!';
  }

  @override
  String get attSuccessGoToDashboard => 'Go to Dashboard';

  @override
  String attSuccessRedirecting(int seconds) {
    return 'REDIRECTING IN $seconds SECONDS';
  }

  @override
  String attSuccessWorkedTime(int hours, int minutes) {
    return 'You worked ${hours}h ${minutes}m today';
  }

  @override
  String get attSuccessGreatJob => 'Great job — get some rest!';

  @override
  String get attMainWorkDateLabel => 'WORK DATE';

  @override
  String get attMainKioskUnlockedTitle => 'Kiosk Unlocked';

  @override
  String get attMainKioskUnlockedMessage =>
      'Kiosk lock temporarily disabled. It will re-lock automatically in 5 minutes.';

  @override
  String get attMainAttendanceLabel => 'ATTENDANCE';

  @override
  String get attMainSelectNameFirst => 'Select your name first';

  @override
  String get attMainShiftCompleted => 'Shift already completed';

  @override
  String get attMainTapToChooseAction => 'Tap to choose action';

  @override
  String get attMainSelected => 'SELECTED';

  @override
  String get attMainClearSelection => 'Clear selection';

  @override
  String get attMainChooseAction => 'CHOOSE ACTION';

  @override
  String get attMainActionClockIn => 'CLOCK IN';

  @override
  String get attMainActionClockInSubtitle => 'Start Workday';

  @override
  String get attMainActionClockOut => 'CLOCK OUT';

  @override
  String get attMainActionClockOutSubtitle => 'End Schedule';

  @override
  String get attMainActionShortBreak => '10MIN BREAK';

  @override
  String get attMainActionShortBreakSubtitle => 'Paid';

  @override
  String get attMainActionLongBreak => 'MEAL BREAK';

  @override
  String get attMainActionLongBreakSubtitle => 'Unpaid';

  @override
  String get attMainActionEndBreak => 'END BREAK';

  @override
  String get attMainActionEndBreakSubtitle => 'Resume Work';

  @override
  String get attMainClockedIn => 'Clocked In';

  @override
  String attMainActiveBadge(int count) {
    return '$count ACTIVE';
  }

  @override
  String get attMainNoOneOnShift => 'No one is currently on shift';

  @override
  String get attMainNotClockedIn => 'Not Clocked In';

  @override
  String get attMainNoUpcoming => 'No upcoming shifts';

  @override
  String attMainBadgeUpcoming(int count) {
    return '$count UPCOMING';
  }

  @override
  String attMainBadgeSoon(int count) {
    return '$count SOON';
  }

  @override
  String attMainBadgeLate(int count) {
    return '$count LATE';
  }

  @override
  String attMainBadgeNoShow(int count) {
    return '$count NO SHOW';
  }

  @override
  String get attMainBadgeSoonShort => 'SOON';

  @override
  String get attMainBadgeLateShort => 'LATE';

  @override
  String get attMainBadgeNoShowShort => 'NO SHOW';

  @override
  String get attMainClockedOut => 'Clocked Out';

  @override
  String attMainDoneBadge(int count) {
    return '$count DONE';
  }

  @override
  String get attMainNoCompletedShifts => 'No completed shifts yet';

  @override
  String get attMainCurrentTimeLabel => 'CURRENT TIME';

  @override
  String get attMainNoticeBoard => 'Notice Board';

  @override
  String get attMainNoNotices => 'No notices';

  @override
  String get attMainNoSchedule => 'No schedule';

  @override
  String attMainClockedInAt(String time) {
    return 'Clocked in at $time';
  }

  @override
  String get attMainBreakLong => 'Meal Unpaid';

  @override
  String get attMainBreakShort => '10min Paid';

  @override
  String get attMainBreakOnBreak => 'On Break';

  @override
  String attMainOnBreakWith(String label) {
    return 'On Break · $label';
  }

  @override
  String get attMainLateBadge => 'Late';

  @override
  String get attMainEarlyClockOutTitle => 'Clocking out early';

  @override
  String attMainEarlyClockOutMessage(String remaining) {
    return 'Your shift still has $remaining remaining. Are you sure you want to clock out now?';
  }

  @override
  String get attMainEarlyClockOutReasonLabel =>
      'Please enter a reason — required for early clock-out.';

  @override
  String get attMainEarlyClockOutReasonHint =>
      'e.g. Family emergency, feeling unwell';

  @override
  String get attMainTimeAgoJustNow => 'Just now';

  @override
  String attMainTimeAgoMinutes(int count) {
    return '$count min ago';
  }

  @override
  String attMainTimeAgoHours(int count) {
    return '${count}h ago';
  }

  @override
  String attMainTimeAgoDays(int count) {
    return '${count}d ago';
  }

  @override
  String attMainDurationHM(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String attMainDurationM(int minutes) {
    return '${minutes}m';
  }

  @override
  String get attUpdateRequiredTitle => 'App Update Required';

  @override
  String attUpdateRequiredMessage(String current, String required) {
    return 'This device is running $current but $required or higher is required to continue.';
  }

  @override
  String attUpdateDownloadButton(String version) {
    return 'Download Update (v$version)';
  }

  @override
  String get attUpdateUnavailableTitle => 'Update Unavailable';

  @override
  String get attUpdateUnavailableMessage =>
      'No download URL configured. Contact your administrator.';

  @override
  String get attUpdateCannotOpenTitle => 'Cannot Open Download';

  @override
  String get attUpdateCannotOpenMessage => 'Failed to launch the download URL.';

  @override
  String attUpdateAvailableBanner(String latest, String current) {
    return 'Update available: v$latest (current v$current)';
  }

  @override
  String get attUpdateButton => 'Update';

  @override
  String get attUpdateDownloading => 'Downloading';

  @override
  String get attUpdateLaunchingInstaller => 'Launching installer…';
}
