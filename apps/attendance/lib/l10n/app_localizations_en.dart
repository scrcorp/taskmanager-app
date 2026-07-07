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
  String get attSettingsAppLabel => 'App';

  @override
  String get attSettingsVersionLabel => 'Version';

  @override
  String get attSettingsCompanyLabel => 'Company';

  @override
  String get attSettingsCompanyName => 'Tigers Plus';

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
  String get scheduleSectionWorking => 'Working';

  @override
  String get scheduleSectionWorkingEmpty => 'Nobody is working.';

  @override
  String get scheduleSectionUpcoming => 'Upcoming';

  @override
  String get scheduleSectionUpcomingEmpty => 'Everyone has clocked in.';

  @override
  String get scheduleSectionDone => 'Done';

  @override
  String get scheduleSectionDoneEmpty => 'Nobody has clocked out yet.';

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

  @override
  String get attUpdateReadyTitle => 'Update Downloaded';

  @override
  String get attUpdateReadyMessage =>
      'The update is ready to install. The screen will unlock briefly so the installer can run, then re-lock automatically.';

  @override
  String get attUpdateInstallNow => 'Install Now';

  @override
  String get attSettingsCheckUpdate => 'Check for updates';

  @override
  String get attSettingsUpToDate => 'You\'re on the latest version.';

  @override
  String attSettingsUpdateAvailable(String latest) {
    return 'Update available: v$latest';
  }

  @override
  String get attSettingsUpdateButton => 'Update';

  @override
  String get attSettingsUpdateCheckFailed =>
      'Couldn\'t check for updates. Check your connection and try again.';

  @override
  String get pfStoreFallback => 'Store';

  @override
  String get pfHeaderSchedule => 'Schedule';

  @override
  String get pfHeaderSettings => 'Settings';

  @override
  String get pfHeaderRefreshTooltip => 'Refresh';

  @override
  String get pfHeaderRefreshed => 'Updated';

  @override
  String pfPinHint(int min, int max) {
    return 'Enter $min~$max digits, then tap Verify';
  }

  @override
  String get pfPinShow => 'Show PIN';

  @override
  String get pfPinHide => 'Hide PIN';

  @override
  String get pfPinClear => 'CLEAR';

  @override
  String get pfPinVerify => 'Verify Identity';

  @override
  String get pfKioskUnlockedToast => 'Kiosk lock released for 5 minutes';

  @override
  String get pfMainWorkingHeader => 'WORKING';

  @override
  String get pfMainWorkingEmpty => 'Nobody is currently working.';

  @override
  String pfMainWorkingDuration(String duration) {
    return 'Working $duration';
  }

  @override
  String pfMainBreakDuration(String duration, String type) {
    return 'Break $duration · $type';
  }

  @override
  String get pfMainBreakTypeShort => '10m';

  @override
  String get pfMainBreakTypeMeal => 'meal';

  @override
  String get pfKioskUnlockedTitle => 'Kiosk Unlocked';

  @override
  String get pfKioskUnlockedBody =>
      'You have 5 minutes to use the device freely.\nThe kiosk will re-lock automatically.';

  @override
  String get pfIdHeader => 'IS THIS YOU?';

  @override
  String get pfIdYes => 'Yes, it\'s me';

  @override
  String get pfIdClose => 'Close';

  @override
  String get pfIdNoShiftTitle => 'NO SHIFT TODAY';

  @override
  String get pfIdNoShiftBody =>
      'You don\'t have a schedule today. Clock actions disabled.';

  @override
  String get pfIdWalkInTitle => 'WALK-IN';

  @override
  String get pfIdWalkInBody =>
      'No scheduled shift. Walk-in clock-in is enabled.';

  @override
  String get pfIdWalkInAgainBody =>
      'Previous shift completed. You can clock in again.';

  @override
  String pfStaleWarnTitle(int count) {
    return '$count unfinished record(s)';
  }

  @override
  String get pfStaleWarnBody =>
      'You didn\'t clock out on these days. Please ask your manager.';

  @override
  String pfStaleMore(int count) {
    return '+$count more';
  }

  @override
  String get pfStatusWorking => 'Currently working';

  @override
  String get pfStatusOnBreak => 'On break';

  @override
  String get pfStatusUpcoming => 'Shift upcoming';

  @override
  String get pfStatusSoon => 'Shift starting soon';

  @override
  String get pfStatusLate => 'Running late';

  @override
  String get pfStatusNoShow => 'No-show';

  @override
  String get pfStatusClockedOut => 'Shift completed';

  @override
  String pfBreakOnBreakTitle(String breakLabel) {
    return 'ON BREAK · $breakLabel';
  }

  @override
  String pfBreakElapsed(int minutes) {
    return '${minutes}m elapsed';
  }

  @override
  String get pfBreakLabelPaid10Min => '10-min Break (paid)';

  @override
  String get pfBreakLabelMealUnpaid => 'Meal Break (unpaid)';

  @override
  String get pfBreakLabelOnBreak => 'On Break';

  @override
  String pfBreakHintPaidTooShort(int minutes) {
    return 'End Break available after ${minutes}m more (10m minimum).';
  }

  @override
  String get pfBreakHintPaidWithin => 'Paid up to 10m. You can end break now.';

  @override
  String pfBreakHintPaidOver(int minutes) {
    return 'Excess ${minutes}m will be unpaid.';
  }

  @override
  String pfBreakHintMealTooShort(int minutes) {
    return 'End Break available after ${minutes}m more (30m minimum).';
  }

  @override
  String get pfBreakHintMealWithin =>
      'Within allowance (30~35m). You can end break now.';

  @override
  String get pfBreakHintMealRequiresReason =>
      'Over 35m — reason required to end break.';

  @override
  String get pfActionHeader => 'CHOOSE ACTION';

  @override
  String get pfActionHint =>
      'Only actions valid for your current status are enabled.';

  @override
  String get pfActionClockIn => 'Clock In';

  @override
  String get pfActionClockInSub => 'Start your shift';

  @override
  String get pfActionClockOut => 'Clock Out';

  @override
  String get pfActionClockOutSub => 'End your shift';

  @override
  String get pfActionBreakShort => '10-min Break';

  @override
  String get pfActionBreakShortSub => 'Paid short break';

  @override
  String get pfActionBreakLong => 'Meal Break';

  @override
  String get pfActionBreakLongSub => 'Unpaid meal';

  @override
  String get pfActionBreakEnd => 'End Break';

  @override
  String get pfActionBreakEndSub => 'Return to work';

  @override
  String pfActionWaitMore(int minutes) {
    return 'Wait ${minutes}m more';
  }

  @override
  String get pfEarlyHeader => 'EARLY CLOCK OUT';

  @override
  String pfEarlyRemainingLine(String remaining, String end) {
    return '$remaining remaining until scheduled end ($end)';
  }

  @override
  String pfEarlyTitle(String name) {
    return '$name, why are you leaving early?';
  }

  @override
  String get pfEarlyBody =>
      'A reason is required for early clock-out. Your manager will see this.';

  @override
  String get pfEarlyReasonUnwell => 'Feeling unwell';

  @override
  String get pfEarlyReasonFamily => 'Family emergency';

  @override
  String get pfEarlyReasonManager => 'Manager approved';

  @override
  String get pfEarlyReasonPersonal => 'Personal reason';

  @override
  String get pfEarlyReasonOther => 'Other (please specify)';

  @override
  String get pfEarlyDetailHint => 'Please describe...';

  @override
  String get pfEarlyCancel => 'Cancel';

  @override
  String get pfEarlySubmit => 'Submit & Clock Out';

  @override
  String get pfTipHeader => 'TIP ENTRY';

  @override
  String pfTipTitle(String name) {
    return '$name\'s tips today';
  }

  @override
  String get pfTipBody =>
      'Record your tips and distribute to teammates who worked with you.';

  @override
  String get pfTipCardLabel => 'Card Tips';

  @override
  String get pfTipCardSub => 'Total from POS';

  @override
  String get pfTipCashLabel => 'Cash Tips Kept';

  @override
  String get pfTipCashSub => 'Cash you took home';

  @override
  String get pfTipDistributeHeader => 'DISTRIBUTE CARD TIPS';

  @override
  String get pfTipDistributeSub =>
      'Pick teammates and split — total can\'t exceed card tips';

  @override
  String get pfTipSplitEvenly => 'Split evenly';

  @override
  String get pfTipNoTeammates => 'No teammates worked with you today.';

  @override
  String pfTipWorked(String hours) {
    return '${hours}h worked';
  }

  @override
  String pfTipDistributedLine(String dist, String card) {
    return 'Distributed: \$$dist / \$$card';
  }

  @override
  String pfTipOverBy(String amount) {
    return 'Over by \$$amount';
  }

  @override
  String get pfTipAddTeammateButton => 'Add teammate (not in list)';

  @override
  String get pfTipAddTeammateHeader => 'ADD TEAMMATE';

  @override
  String get pfTipAddSearchHint => 'Search by name…';

  @override
  String get pfTipAddNoMatch => 'No match.';

  @override
  String get pfTipSkip => 'Skip — enter later';

  @override
  String get pfTipSubmit => 'Submit Tips';

  @override
  String get pfSuccessClockedIn => 'CLOCKED IN';

  @override
  String pfSuccessClockedInMsg(String name) {
    return 'Have a great shift, $name!';
  }

  @override
  String get pfSuccessClockedOut => 'CLOCKED OUT';

  @override
  String pfSuccessClockedOutMsg(String name) {
    return 'Great work today, $name!';
  }

  @override
  String get pfSuccessOn10MinBreak => 'ON 10-MIN BREAK';

  @override
  String pfSuccessOn10MinBreakMsg(String name) {
    return 'See you in 10, $name!';
  }

  @override
  String get pfSuccessMealBreak => 'MEAL BREAK';

  @override
  String pfSuccessMealBreakMsg(String name) {
    return 'Enjoy your meal, $name!';
  }

  @override
  String get pfSuccessBackToWork => 'BACK TO WORK';

  @override
  String pfSuccessBackToWorkMsg(String name) {
    return 'Welcome back, $name!';
  }

  @override
  String get pfSuccessOk => 'OK';

  @override
  String get pfSuccessAutoClose => 'Closes automatically in 5 seconds';

  @override
  String get pfErrorFallback => 'Something went wrong';

  @override
  String get pfErrorOk => 'OK';
}
