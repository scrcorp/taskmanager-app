import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'HTM Attendance'**
  String get appTitle;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @commonHeadsUp.
  ///
  /// In en, this message translates to:
  /// **'Heads up'**
  String get commonHeadsUp;

  /// No description provided for @commonSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get commonSavedTitle;

  /// No description provided for @commonSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save'**
  String get commonSaveFailedTitle;

  /// No description provided for @commonComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get commonComingSoon;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get commonStore;

  /// No description provided for @commonDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get commonDevice;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get commonUntitled;

  /// No description provided for @attAccessCodeRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register This Device'**
  String get attAccessCodeRegisterTitle;

  /// No description provided for @attAccessCodeRegisterDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-character access code provided by your manager.'**
  String get attAccessCodeRegisterDescription;

  /// No description provided for @attAccessCodeRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Register Device'**
  String get attAccessCodeRegisterButton;

  /// No description provided for @attAccessCodeChangeStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Store'**
  String get attAccessCodeChangeStoreTitle;

  /// No description provided for @attAccessCodeChangeStoreDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a new 6-character access code to switch this device to a different store.'**
  String get attAccessCodeChangeStoreDescription;

  /// No description provided for @attAccessCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid access code'**
  String get attAccessCodeInvalid;

  /// No description provided for @attAccessCodeRegisterFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t register device'**
  String get attAccessCodeRegisterFailedTitle;

  /// No description provided for @attStoreSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Store'**
  String get attStoreSelectTitle;

  /// No description provided for @attStoreSelectDeviceNeedsAssignment.
  ///
  /// In en, this message translates to:
  /// **'This device ({deviceName}) needs to be assigned to a store.'**
  String attStoreSelectDeviceNeedsAssignment(String deviceName);

  /// No description provided for @attStoreSelectGenericNeedsAssignment.
  ///
  /// In en, this message translates to:
  /// **'This device needs to be assigned to a store.'**
  String get attStoreSelectGenericNeedsAssignment;

  /// No description provided for @attStoreSelectLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stores from server. Showing preset/manual fallback.'**
  String get attStoreSelectLoadFailed;

  /// No description provided for @attStoreSelectEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stores available. Contact an administrator.'**
  String get attStoreSelectEmpty;

  /// No description provided for @attStoreSelectManualLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual Store ID'**
  String get attStoreSelectManualLabel;

  /// No description provided for @attStoreSelectManualHint.
  ///
  /// In en, this message translates to:
  /// **'Paste store UUID (fallback)'**
  String get attStoreSelectManualHint;

  /// No description provided for @attStoreSelectAssignButton.
  ///
  /// In en, this message translates to:
  /// **'Assign Store'**
  String get attStoreSelectAssignButton;

  /// No description provided for @attStoreSelectAssignFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to assign store'**
  String get attStoreSelectAssignFailed;

  /// No description provided for @attStoreSelectAssignFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t assign store'**
  String get attStoreSelectAssignFailedTitle;

  /// No description provided for @attSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Settings'**
  String get attSettingsTitle;

  /// No description provided for @attSettingsDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get attSettingsDeviceLabel;

  /// No description provided for @attSettingsStoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get attSettingsStoreLabel;

  /// No description provided for @attSettingsStoreNotAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get attSettingsStoreNotAssigned;

  /// No description provided for @attSettingsDeviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get attSettingsDeviceIdLabel;

  /// No description provided for @attSettingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get attSettingsLanguageLabel;

  /// No description provided for @attSettingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get attSettingsLanguageEnglish;

  /// No description provided for @attSettingsLanguageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get attSettingsLanguageSpanish;

  /// No description provided for @attSettingsChangeStore.
  ///
  /// In en, this message translates to:
  /// **'Change Store'**
  String get attSettingsChangeStore;

  /// No description provided for @attSettingsChangeStoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'To switch this device to a different store, you will need a new access code. The current device registration will be revoked.'**
  String get attSettingsChangeStoreConfirm;

  /// No description provided for @attSettingsKioskLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Lock'**
  String get attSettingsKioskLockTitle;

  /// No description provided for @attSettingsKioskLockOn.
  ///
  /// In en, this message translates to:
  /// **'App is locked. Disable to use device freely.'**
  String get attSettingsKioskLockOn;

  /// No description provided for @attSettingsKioskLockOff.
  ///
  /// In en, this message translates to:
  /// **'App is unlocked. Enable to restrict device.'**
  String get attSettingsKioskLockOff;

  /// No description provided for @attSettingsKioskEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Kiosk Lock'**
  String get attSettingsKioskEnableTitle;

  /// No description provided for @attSettingsKioskEnableMessage.
  ///
  /// In en, this message translates to:
  /// **'Android will show a system dialog asking to pin this app. You MUST tap \"Got it\" / \"OK\" to enable kiosk mode. Tapping \"No thanks\" will leave the device unlocked.'**
  String get attSettingsKioskEnableMessage;

  /// No description provided for @attSettingsKioskNotActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock Not Active'**
  String get attSettingsKioskNotActiveTitle;

  /// No description provided for @attSettingsKioskNotActiveMessage.
  ///
  /// In en, this message translates to:
  /// **'You declined the pinning prompt. Kiosk mode is required for this device. Tap Retry and confirm the system dialog.'**
  String get attSettingsKioskNotActiveMessage;

  /// No description provided for @attSettingsKioskDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable Kiosk Lock'**
  String get attSettingsKioskDisableTitle;

  /// No description provided for @attSettingsKioskDisableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get attSettingsKioskDisableConfirm;

  /// No description provided for @attSettingsKioskDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Disabled'**
  String get attSettingsKioskDisabledTitle;

  /// No description provided for @attSettingsKioskDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Kiosk lock will re-enable automatically in 5 minutes. Toggle it back on at any time to re-lock immediately.'**
  String get attSettingsKioskDisabledMessage;

  /// No description provided for @attSettingsUnregister.
  ///
  /// In en, this message translates to:
  /// **'Unregister This Device'**
  String get attSettingsUnregister;

  /// No description provided for @attSettingsUnregisterConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Unregister Device'**
  String get attSettingsUnregisterConfirmTitle;

  /// No description provided for @attSettingsUnregisterConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This device will be removed from the organization. You will need a new access code to register again.'**
  String get attSettingsUnregisterConfirmMessage;

  /// No description provided for @attSettingsUnregisterVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Unregister'**
  String get attSettingsUnregisterVerifyTitle;

  /// No description provided for @attSettingsUnregisterVerifyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Unregister'**
  String get attSettingsUnregisterVerifyConfirm;

  /// No description provided for @attSettingsAccessCodePromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot Continue'**
  String get attSettingsAccessCodePromptTitle;

  /// No description provided for @attSettingsAccessCodePromptMessage.
  ///
  /// In en, this message translates to:
  /// **'No access code on file. Re-register this device to enable this action.'**
  String get attSettingsAccessCodePromptMessage;

  /// No description provided for @attSettingsAccessCodeEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter the device access code.'**
  String get attSettingsAccessCodeEnter;

  /// No description provided for @attSettingsAccessCodeIncorrectTitle.
  ///
  /// In en, this message translates to:
  /// **'Incorrect Code'**
  String get attSettingsAccessCodeIncorrectTitle;

  /// No description provided for @attSettingsAccessCodeIncorrectMessage.
  ///
  /// In en, this message translates to:
  /// **'The access code did not match.'**
  String get attSettingsAccessCodeIncorrectMessage;

  /// No description provided for @attSettingsAccessCodeHint.
  ///
  /// In en, this message translates to:
  /// **'ABC123'**
  String get attSettingsAccessCodeHint;

  /// No description provided for @attSettingsKioskUnlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Unlocked'**
  String get attSettingsKioskUnlockedTitle;

  /// No description provided for @attSettingsKioskUnlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'You may now navigate away from the app. Re-register or reinstall to re-enable kiosk mode.'**
  String get attSettingsKioskUnlockedMessage;

  /// No description provided for @attPinHi.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String attPinHi(String name);

  /// No description provided for @attPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Your PIN'**
  String get attPinTitle;

  /// No description provided for @attPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please use your {length}-digit number to proceed'**
  String attPinSubtitle(int length);

  /// No description provided for @attPinCancelReturn.
  ///
  /// In en, this message translates to:
  /// **'Cancel & Return'**
  String get attPinCancelReturn;

  /// No description provided for @attPinVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify Identity'**
  String get attPinVerify;

  /// No description provided for @attPinPadClear.
  ///
  /// In en, this message translates to:
  /// **'CLEAR'**
  String get attPinPadClear;

  /// No description provided for @attPinSecureAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure Access'**
  String get attPinSecureAccessTitle;

  /// No description provided for @attPinSecureAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'Verification ensures the safety and accountability of all staff members.'**
  String get attPinSecureAccessDescription;

  /// No description provided for @attPinShiftRecognitionTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift Recognition'**
  String get attPinShiftRecognitionTitle;

  /// No description provided for @attPinShiftRecognitionDescription.
  ///
  /// In en, this message translates to:
  /// **'Clocking in registers your presence for the current cycle.'**
  String get attPinShiftRecognitionDescription;

  /// No description provided for @attPinVerificationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get attPinVerificationFailedTitle;

  /// No description provided for @attPinVerificationFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Invalid PIN. Please try again.'**
  String get attPinVerificationFailedMessage;

  /// No description provided for @attSuccessClockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock In Successful'**
  String get attSuccessClockIn;

  /// No description provided for @attSuccessClockOut.
  ///
  /// In en, this message translates to:
  /// **'Clock Out Successful'**
  String get attSuccessClockOut;

  /// No description provided for @attSuccessShortBreak.
  ///
  /// In en, this message translates to:
  /// **'10min Break Started'**
  String get attSuccessShortBreak;

  /// No description provided for @attSuccessLongBreak.
  ///
  /// In en, this message translates to:
  /// **'Meal Break Started'**
  String get attSuccessLongBreak;

  /// No description provided for @attSuccessBreakEnded.
  ///
  /// In en, this message translates to:
  /// **'Break Ended'**
  String get attSuccessBreakEnded;

  /// No description provided for @attSuccessWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get attSuccessWelcomeBack;

  /// No description provided for @attSuccessWelcomeBackName.
  ///
  /// In en, this message translates to:
  /// **', {name}!'**
  String attSuccessWelcomeBackName(String name);

  /// No description provided for @attSuccessGoToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to Dashboard'**
  String get attSuccessGoToDashboard;

  /// No description provided for @attSuccessRedirecting.
  ///
  /// In en, this message translates to:
  /// **'REDIRECTING IN {seconds} SECONDS'**
  String attSuccessRedirecting(int seconds);

  /// No description provided for @attSuccessWorkedTime.
  ///
  /// In en, this message translates to:
  /// **'You worked {hours}h {minutes}m today'**
  String attSuccessWorkedTime(int hours, int minutes);

  /// No description provided for @attSuccessGreatJob.
  ///
  /// In en, this message translates to:
  /// **'Great job — get some rest!'**
  String get attSuccessGreatJob;

  /// No description provided for @attMainWorkDateLabel.
  ///
  /// In en, this message translates to:
  /// **'WORK DATE'**
  String get attMainWorkDateLabel;

  /// No description provided for @attMainKioskUnlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Unlocked'**
  String get attMainKioskUnlockedTitle;

  /// No description provided for @attMainKioskUnlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Kiosk lock temporarily disabled. It will re-lock automatically in 5 minutes.'**
  String get attMainKioskUnlockedMessage;

  /// No description provided for @attMainAttendanceLabel.
  ///
  /// In en, this message translates to:
  /// **'ATTENDANCE'**
  String get attMainAttendanceLabel;

  /// No description provided for @attMainSelectNameFirst.
  ///
  /// In en, this message translates to:
  /// **'Select your name first'**
  String get attMainSelectNameFirst;

  /// No description provided for @attMainShiftCompleted.
  ///
  /// In en, this message translates to:
  /// **'Shift already completed'**
  String get attMainShiftCompleted;

  /// No description provided for @attMainTapToChooseAction.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose action'**
  String get attMainTapToChooseAction;

  /// No description provided for @attMainSelected.
  ///
  /// In en, this message translates to:
  /// **'SELECTED'**
  String get attMainSelected;

  /// No description provided for @attMainClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get attMainClearSelection;

  /// No description provided for @attMainChooseAction.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE ACTION'**
  String get attMainChooseAction;

  /// No description provided for @attMainActionClockIn.
  ///
  /// In en, this message translates to:
  /// **'CLOCK IN'**
  String get attMainActionClockIn;

  /// No description provided for @attMainActionClockInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start Workday'**
  String get attMainActionClockInSubtitle;

  /// No description provided for @attMainActionClockOut.
  ///
  /// In en, this message translates to:
  /// **'CLOCK OUT'**
  String get attMainActionClockOut;

  /// No description provided for @attMainActionClockOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'End Schedule'**
  String get attMainActionClockOutSubtitle;

  /// No description provided for @attMainActionShortBreak.
  ///
  /// In en, this message translates to:
  /// **'10MIN BREAK'**
  String get attMainActionShortBreak;

  /// No description provided for @attMainActionShortBreakSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get attMainActionShortBreakSubtitle;

  /// No description provided for @attMainActionLongBreak.
  ///
  /// In en, this message translates to:
  /// **'MEAL BREAK'**
  String get attMainActionLongBreak;

  /// No description provided for @attMainActionLongBreakSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get attMainActionLongBreakSubtitle;

  /// No description provided for @attMainActionEndBreak.
  ///
  /// In en, this message translates to:
  /// **'END BREAK'**
  String get attMainActionEndBreak;

  /// No description provided for @attMainActionEndBreakSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Resume Work'**
  String get attMainActionEndBreakSubtitle;

  /// No description provided for @attMainClockedIn.
  ///
  /// In en, this message translates to:
  /// **'Clocked In'**
  String get attMainClockedIn;

  /// No description provided for @attMainActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} ACTIVE'**
  String attMainActiveBadge(int count);

  /// No description provided for @attMainNoOneOnShift.
  ///
  /// In en, this message translates to:
  /// **'No one is currently on shift'**
  String get attMainNoOneOnShift;

  /// No description provided for @attMainNotClockedIn.
  ///
  /// In en, this message translates to:
  /// **'Not Clocked In'**
  String get attMainNotClockedIn;

  /// No description provided for @attMainNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming shifts'**
  String get attMainNoUpcoming;

  /// No description provided for @attMainBadgeUpcoming.
  ///
  /// In en, this message translates to:
  /// **'{count} UPCOMING'**
  String attMainBadgeUpcoming(int count);

  /// No description provided for @attMainBadgeSoon.
  ///
  /// In en, this message translates to:
  /// **'{count} SOON'**
  String attMainBadgeSoon(int count);

  /// No description provided for @attMainBadgeLate.
  ///
  /// In en, this message translates to:
  /// **'{count} LATE'**
  String attMainBadgeLate(int count);

  /// No description provided for @attMainBadgeNoShow.
  ///
  /// In en, this message translates to:
  /// **'{count} NO SHOW'**
  String attMainBadgeNoShow(int count);

  /// No description provided for @attMainBadgeSoonShort.
  ///
  /// In en, this message translates to:
  /// **'SOON'**
  String get attMainBadgeSoonShort;

  /// No description provided for @attMainBadgeLateShort.
  ///
  /// In en, this message translates to:
  /// **'LATE'**
  String get attMainBadgeLateShort;

  /// No description provided for @attMainBadgeNoShowShort.
  ///
  /// In en, this message translates to:
  /// **'NO SHOW'**
  String get attMainBadgeNoShowShort;

  /// No description provided for @attMainClockedOut.
  ///
  /// In en, this message translates to:
  /// **'Clocked Out'**
  String get attMainClockedOut;

  /// No description provided for @attMainDoneBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} DONE'**
  String attMainDoneBadge(int count);

  /// No description provided for @attMainNoCompletedShifts.
  ///
  /// In en, this message translates to:
  /// **'No completed shifts yet'**
  String get attMainNoCompletedShifts;

  /// No description provided for @attMainCurrentTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'CURRENT TIME'**
  String get attMainCurrentTimeLabel;

  /// No description provided for @attMainNoSchedule.
  ///
  /// In en, this message translates to:
  /// **'No schedule'**
  String get attMainNoSchedule;

  /// No description provided for @attMainClockedInAt.
  ///
  /// In en, this message translates to:
  /// **'Clocked in at {time}'**
  String attMainClockedInAt(String time);

  /// No description provided for @attMainBreakLong.
  ///
  /// In en, this message translates to:
  /// **'Meal Unpaid'**
  String get attMainBreakLong;

  /// No description provided for @attMainBreakShort.
  ///
  /// In en, this message translates to:
  /// **'10min Paid'**
  String get attMainBreakShort;

  /// No description provided for @attMainBreakOnBreak.
  ///
  /// In en, this message translates to:
  /// **'On Break'**
  String get attMainBreakOnBreak;

  /// No description provided for @attMainOnBreakWith.
  ///
  /// In en, this message translates to:
  /// **'On Break · {label}'**
  String attMainOnBreakWith(String label);

  /// No description provided for @attMainLateBadge.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get attMainLateBadge;

  /// No description provided for @attMainEarlyClockOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Clocking out early'**
  String get attMainEarlyClockOutTitle;

  /// No description provided for @attMainEarlyClockOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Your shift still has {remaining} remaining. Are you sure you want to clock out now?'**
  String attMainEarlyClockOutMessage(String remaining);

  /// No description provided for @attMainEarlyClockOutReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Please enter a reason — required for early clock-out.'**
  String get attMainEarlyClockOutReasonLabel;

  /// No description provided for @attMainEarlyClockOutReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Family emergency, feeling unwell'**
  String get attMainEarlyClockOutReasonHint;

  /// No description provided for @attMainTimeAgoJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get attMainTimeAgoJustNow;

  /// No description provided for @attMainTimeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String attMainTimeAgoMinutes(int count);

  /// No description provided for @attMainTimeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String attMainTimeAgoHours(int count);

  /// No description provided for @attMainTimeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String attMainTimeAgoDays(int count);

  /// No description provided for @attMainDurationHM.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String attMainDurationHM(int hours, int minutes);

  /// No description provided for @attMainDurationM.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String attMainDurationM(int minutes);

  /// No description provided for @attUpdateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'App Update Required'**
  String get attUpdateRequiredTitle;

  /// No description provided for @attUpdateRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This device is running {current} but {required} or higher is required to continue.'**
  String attUpdateRequiredMessage(String current, String required);

  /// No description provided for @attUpdateDownloadButton.
  ///
  /// In en, this message translates to:
  /// **'Download Update (v{version})'**
  String attUpdateDownloadButton(String version);

  /// No description provided for @attUpdateUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Unavailable'**
  String get attUpdateUnavailableTitle;

  /// No description provided for @attUpdateUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'No download URL configured. Contact your administrator.'**
  String get attUpdateUnavailableMessage;

  /// No description provided for @attUpdateCannotOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot Open Download'**
  String get attUpdateCannotOpenTitle;

  /// No description provided for @attUpdateCannotOpenMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to launch the download URL.'**
  String get attUpdateCannotOpenMessage;

  /// No description provided for @attUpdateAvailableBanner.
  ///
  /// In en, this message translates to:
  /// **'Update available: v{latest} (current v{current})'**
  String attUpdateAvailableBanner(String latest, String current);

  /// No description provided for @attUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get attUpdateButton;

  /// No description provided for @attUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get attUpdateDownloading;

  /// No description provided for @attUpdateLaunchingInstaller.
  ///
  /// In en, this message translates to:
  /// **'Launching installer…'**
  String get attUpdateLaunchingInstaller;

  /// No description provided for @pfStoreFallback.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get pfStoreFallback;

  /// No description provided for @pfHeaderSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get pfHeaderSchedule;

  /// No description provided for @pfHeaderSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get pfHeaderSettings;

  /// No description provided for @pfPinHint.
  ///
  /// In en, this message translates to:
  /// **'Enter {min}~{max} digits, then tap Verify'**
  String pfPinHint(int min, int max);

  /// No description provided for @pfPinShow.
  ///
  /// In en, this message translates to:
  /// **'Show PIN'**
  String get pfPinShow;

  /// No description provided for @pfPinHide.
  ///
  /// In en, this message translates to:
  /// **'Hide PIN'**
  String get pfPinHide;

  /// No description provided for @pfPinClear.
  ///
  /// In en, this message translates to:
  /// **'CLEAR'**
  String get pfPinClear;

  /// No description provided for @pfPinVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify Identity'**
  String get pfPinVerify;

  /// No description provided for @pfKioskUnlockedToast.
  ///
  /// In en, this message translates to:
  /// **'Kiosk lock released for 5 minutes'**
  String get pfKioskUnlockedToast;

  /// No description provided for @pfMainWorkingHeader.
  ///
  /// In en, this message translates to:
  /// **'WORKING'**
  String get pfMainWorkingHeader;

  /// No description provided for @pfMainWorkingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody is currently working.'**
  String get pfMainWorkingEmpty;

  /// No description provided for @pfMainWorkingDuration.
  ///
  /// In en, this message translates to:
  /// **'Working {duration}'**
  String pfMainWorkingDuration(String duration);

  /// No description provided for @pfMainBreakDuration.
  ///
  /// In en, this message translates to:
  /// **'Break {duration} · {type}'**
  String pfMainBreakDuration(String duration, String type);

  /// No description provided for @pfMainBreakTypeShort.
  ///
  /// In en, this message translates to:
  /// **'10m'**
  String get pfMainBreakTypeShort;

  /// No description provided for @pfMainBreakTypeMeal.
  ///
  /// In en, this message translates to:
  /// **'meal'**
  String get pfMainBreakTypeMeal;

  /// No description provided for @pfKioskUnlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Unlocked'**
  String get pfKioskUnlockedTitle;

  /// No description provided for @pfKioskUnlockedBody.
  ///
  /// In en, this message translates to:
  /// **'You have 5 minutes to use the device freely.\nThe kiosk will re-lock automatically.'**
  String get pfKioskUnlockedBody;

  /// No description provided for @pfIdHeader.
  ///
  /// In en, this message translates to:
  /// **'IS THIS YOU?'**
  String get pfIdHeader;

  /// No description provided for @pfIdYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, it\'s me'**
  String get pfIdYes;

  /// No description provided for @pfIdClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get pfIdClose;

  /// No description provided for @pfIdNoShiftTitle.
  ///
  /// In en, this message translates to:
  /// **'NO SHIFT TODAY'**
  String get pfIdNoShiftTitle;

  /// No description provided for @pfIdNoShiftBody.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have a schedule today. Clock actions disabled.'**
  String get pfIdNoShiftBody;

  /// No description provided for @pfStatusWorking.
  ///
  /// In en, this message translates to:
  /// **'Currently working'**
  String get pfStatusWorking;

  /// No description provided for @pfStatusOnBreak.
  ///
  /// In en, this message translates to:
  /// **'On break'**
  String get pfStatusOnBreak;

  /// No description provided for @pfStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Shift upcoming'**
  String get pfStatusUpcoming;

  /// No description provided for @pfStatusSoon.
  ///
  /// In en, this message translates to:
  /// **'Shift starting soon'**
  String get pfStatusSoon;

  /// No description provided for @pfStatusLate.
  ///
  /// In en, this message translates to:
  /// **'Running late'**
  String get pfStatusLate;

  /// No description provided for @pfStatusNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get pfStatusNoShow;

  /// No description provided for @pfStatusClockedOut.
  ///
  /// In en, this message translates to:
  /// **'Shift completed'**
  String get pfStatusClockedOut;

  /// No description provided for @pfBreakOnBreakTitle.
  ///
  /// In en, this message translates to:
  /// **'ON BREAK · {breakLabel}'**
  String pfBreakOnBreakTitle(String breakLabel);

  /// No description provided for @pfBreakElapsed.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m elapsed'**
  String pfBreakElapsed(int minutes);

  /// No description provided for @pfBreakLabelPaid10Min.
  ///
  /// In en, this message translates to:
  /// **'10-min Break (paid)'**
  String get pfBreakLabelPaid10Min;

  /// No description provided for @pfBreakLabelMealUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Meal Break (unpaid)'**
  String get pfBreakLabelMealUnpaid;

  /// No description provided for @pfBreakLabelOnBreak.
  ///
  /// In en, this message translates to:
  /// **'On Break'**
  String get pfBreakLabelOnBreak;

  /// No description provided for @pfBreakHintPaidTooShort.
  ///
  /// In en, this message translates to:
  /// **'End Break available after {minutes}m more (10m minimum).'**
  String pfBreakHintPaidTooShort(int minutes);

  /// No description provided for @pfBreakHintPaidWithin.
  ///
  /// In en, this message translates to:
  /// **'Paid up to 10m. You can end break now.'**
  String get pfBreakHintPaidWithin;

  /// No description provided for @pfBreakHintPaidOver.
  ///
  /// In en, this message translates to:
  /// **'Excess {minutes}m will be unpaid.'**
  String pfBreakHintPaidOver(int minutes);

  /// No description provided for @pfBreakHintMealTooShort.
  ///
  /// In en, this message translates to:
  /// **'End Break available after {minutes}m more (30m minimum).'**
  String pfBreakHintMealTooShort(int minutes);

  /// No description provided for @pfBreakHintMealWithin.
  ///
  /// In en, this message translates to:
  /// **'Within allowance (30~35m). You can end break now.'**
  String get pfBreakHintMealWithin;

  /// No description provided for @pfBreakHintMealRequiresReason.
  ///
  /// In en, this message translates to:
  /// **'Over 35m — reason required to end break.'**
  String get pfBreakHintMealRequiresReason;

  /// No description provided for @pfActionHeader.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE ACTION'**
  String get pfActionHeader;

  /// No description provided for @pfActionHint.
  ///
  /// In en, this message translates to:
  /// **'Only actions valid for your current status are enabled.'**
  String get pfActionHint;

  /// No description provided for @pfActionClockIn.
  ///
  /// In en, this message translates to:
  /// **'Clock In'**
  String get pfActionClockIn;

  /// No description provided for @pfActionClockInSub.
  ///
  /// In en, this message translates to:
  /// **'Start your shift'**
  String get pfActionClockInSub;

  /// No description provided for @pfActionClockOut.
  ///
  /// In en, this message translates to:
  /// **'Clock Out'**
  String get pfActionClockOut;

  /// No description provided for @pfActionClockOutSub.
  ///
  /// In en, this message translates to:
  /// **'End your shift'**
  String get pfActionClockOutSub;

  /// No description provided for @pfActionBreakShort.
  ///
  /// In en, this message translates to:
  /// **'10-min Break'**
  String get pfActionBreakShort;

  /// No description provided for @pfActionBreakShortSub.
  ///
  /// In en, this message translates to:
  /// **'Paid short break'**
  String get pfActionBreakShortSub;

  /// No description provided for @pfActionBreakLong.
  ///
  /// In en, this message translates to:
  /// **'Meal Break'**
  String get pfActionBreakLong;

  /// No description provided for @pfActionBreakLongSub.
  ///
  /// In en, this message translates to:
  /// **'Unpaid meal'**
  String get pfActionBreakLongSub;

  /// No description provided for @pfActionBreakEnd.
  ///
  /// In en, this message translates to:
  /// **'End Break'**
  String get pfActionBreakEnd;

  /// No description provided for @pfActionBreakEndSub.
  ///
  /// In en, this message translates to:
  /// **'Return to work'**
  String get pfActionBreakEndSub;

  /// No description provided for @pfActionWaitMore.
  ///
  /// In en, this message translates to:
  /// **'Wait {minutes}m more'**
  String pfActionWaitMore(int minutes);

  /// No description provided for @pfEarlyHeader.
  ///
  /// In en, this message translates to:
  /// **'EARLY CLOCK OUT'**
  String get pfEarlyHeader;

  /// No description provided for @pfEarlyRemainingLine.
  ///
  /// In en, this message translates to:
  /// **'{remaining} remaining until scheduled end ({end})'**
  String pfEarlyRemainingLine(String remaining, String end);

  /// No description provided for @pfEarlyTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}, why are you leaving early?'**
  String pfEarlyTitle(String name);

  /// No description provided for @pfEarlyBody.
  ///
  /// In en, this message translates to:
  /// **'A reason is required for early clock-out. Your manager will see this.'**
  String get pfEarlyBody;

  /// No description provided for @pfEarlyReasonUnwell.
  ///
  /// In en, this message translates to:
  /// **'Feeling unwell'**
  String get pfEarlyReasonUnwell;

  /// No description provided for @pfEarlyReasonFamily.
  ///
  /// In en, this message translates to:
  /// **'Family emergency'**
  String get pfEarlyReasonFamily;

  /// No description provided for @pfEarlyReasonManager.
  ///
  /// In en, this message translates to:
  /// **'Manager approved'**
  String get pfEarlyReasonManager;

  /// No description provided for @pfEarlyReasonPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal reason'**
  String get pfEarlyReasonPersonal;

  /// No description provided for @pfEarlyReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other (please specify)'**
  String get pfEarlyReasonOther;

  /// No description provided for @pfEarlyDetailHint.
  ///
  /// In en, this message translates to:
  /// **'Please describe...'**
  String get pfEarlyDetailHint;

  /// No description provided for @pfEarlyCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get pfEarlyCancel;

  /// No description provided for @pfEarlySubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit & Clock Out'**
  String get pfEarlySubmit;

  /// No description provided for @pfTipHeader.
  ///
  /// In en, this message translates to:
  /// **'TIP ENTRY'**
  String get pfTipHeader;

  /// No description provided for @pfTipTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s tips today'**
  String pfTipTitle(String name);

  /// No description provided for @pfTipBody.
  ///
  /// In en, this message translates to:
  /// **'Record your tips and distribute to teammates who worked with you.'**
  String get pfTipBody;

  /// No description provided for @pfTipCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Card Tips'**
  String get pfTipCardLabel;

  /// No description provided for @pfTipCardSub.
  ///
  /// In en, this message translates to:
  /// **'Total from POS'**
  String get pfTipCardSub;

  /// No description provided for @pfTipCashLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash Tips Kept'**
  String get pfTipCashLabel;

  /// No description provided for @pfTipCashSub.
  ///
  /// In en, this message translates to:
  /// **'Cash you took home'**
  String get pfTipCashSub;

  /// No description provided for @pfTipDistributeHeader.
  ///
  /// In en, this message translates to:
  /// **'DISTRIBUTE CARD TIPS'**
  String get pfTipDistributeHeader;

  /// No description provided for @pfTipDistributeSub.
  ///
  /// In en, this message translates to:
  /// **'Pick teammates and split — total can\'t exceed card tips'**
  String get pfTipDistributeSub;

  /// No description provided for @pfTipSplitEvenly.
  ///
  /// In en, this message translates to:
  /// **'Split evenly'**
  String get pfTipSplitEvenly;

  /// No description provided for @pfTipNoTeammates.
  ///
  /// In en, this message translates to:
  /// **'No teammates worked with you today.'**
  String get pfTipNoTeammates;

  /// No description provided for @pfTipWorked.
  ///
  /// In en, this message translates to:
  /// **'{hours}h worked'**
  String pfTipWorked(String hours);

  /// No description provided for @pfTipDistributedLine.
  ///
  /// In en, this message translates to:
  /// **'Distributed: \${dist} / \${card}'**
  String pfTipDistributedLine(String dist, String card);

  /// No description provided for @pfTipOverBy.
  ///
  /// In en, this message translates to:
  /// **'Over by \${amount}'**
  String pfTipOverBy(String amount);

  /// No description provided for @pfTipAddTeammateButton.
  ///
  /// In en, this message translates to:
  /// **'Add teammate (not in list)'**
  String get pfTipAddTeammateButton;

  /// No description provided for @pfTipAddTeammateHeader.
  ///
  /// In en, this message translates to:
  /// **'ADD TEAMMATE'**
  String get pfTipAddTeammateHeader;

  /// No description provided for @pfTipAddSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name…'**
  String get pfTipAddSearchHint;

  /// No description provided for @pfTipAddNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No match.'**
  String get pfTipAddNoMatch;

  /// No description provided for @pfTipSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip — enter later'**
  String get pfTipSkip;

  /// No description provided for @pfTipSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Tips'**
  String get pfTipSubmit;

  /// No description provided for @pfSuccessClockedIn.
  ///
  /// In en, this message translates to:
  /// **'CLOCKED IN'**
  String get pfSuccessClockedIn;

  /// No description provided for @pfSuccessClockedInMsg.
  ///
  /// In en, this message translates to:
  /// **'Have a great shift, {name}!'**
  String pfSuccessClockedInMsg(String name);

  /// No description provided for @pfSuccessClockedOut.
  ///
  /// In en, this message translates to:
  /// **'CLOCKED OUT'**
  String get pfSuccessClockedOut;

  /// No description provided for @pfSuccessClockedOutMsg.
  ///
  /// In en, this message translates to:
  /// **'Great work today, {name}!'**
  String pfSuccessClockedOutMsg(String name);

  /// No description provided for @pfSuccessOn10MinBreak.
  ///
  /// In en, this message translates to:
  /// **'ON 10-MIN BREAK'**
  String get pfSuccessOn10MinBreak;

  /// No description provided for @pfSuccessOn10MinBreakMsg.
  ///
  /// In en, this message translates to:
  /// **'See you in 10, {name}!'**
  String pfSuccessOn10MinBreakMsg(String name);

  /// No description provided for @pfSuccessMealBreak.
  ///
  /// In en, this message translates to:
  /// **'MEAL BREAK'**
  String get pfSuccessMealBreak;

  /// No description provided for @pfSuccessMealBreakMsg.
  ///
  /// In en, this message translates to:
  /// **'Enjoy your meal, {name}!'**
  String pfSuccessMealBreakMsg(String name);

  /// No description provided for @pfSuccessBackToWork.
  ///
  /// In en, this message translates to:
  /// **'BACK TO WORK'**
  String get pfSuccessBackToWork;

  /// No description provided for @pfSuccessBackToWorkMsg.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}!'**
  String pfSuccessBackToWorkMsg(String name);

  /// No description provided for @pfSuccessOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get pfSuccessOk;

  /// No description provided for @pfSuccessAutoClose.
  ///
  /// In en, this message translates to:
  /// **'Closes automatically in 5 seconds'**
  String get pfSuccessAutoClose;

  /// No description provided for @pfErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get pfErrorFallback;

  /// No description provided for @pfErrorOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get pfErrorOk;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'es':
      return AppL10nEs();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
