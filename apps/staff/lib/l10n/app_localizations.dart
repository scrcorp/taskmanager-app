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

  /// App title shown on login screen and browser tab
  ///
  /// In en, this message translates to:
  /// **'Staff App'**
  String get appTitle;

  /// No description provided for @actionLogin.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get actionLogin;

  /// No description provided for @actionRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get actionRegister;

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

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

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

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @loginEmailOrUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get loginEmailOrUsernameHint;

  /// No description provided for @loginPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordHint;

  /// No description provided for @loginFindUsername.
  ///
  /// In en, this message translates to:
  /// **'Find ID'**
  String get loginFindUsername;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get loginForgotPassword;

  /// No description provided for @loginNoAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get loginNoAccountPrompt;

  /// No description provided for @loginRegisterAction.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get loginRegisterAction;

  /// No description provided for @loginFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Login Failed'**
  String get loginFailedTitle;

  /// No description provided for @loginFailedDefault.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailedDefault;

  /// No description provided for @loginAlreadyHaveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get loginAlreadyHaveAccountPrompt;

  /// No description provided for @companyCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Company Code'**
  String get companyCodeTitle;

  /// No description provided for @companyCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask your manager for the company code'**
  String get companyCodeSubtitle;

  /// No description provided for @companyCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Company Code'**
  String get companyCodeHint;

  /// No description provided for @commonHeadsUp.
  ///
  /// In en, this message translates to:
  /// **'Heads up'**
  String get commonHeadsUp;

  /// No description provided for @errorServerLater.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get errorServerLater;

  /// No description provided for @errorServerNotResponding.
  ///
  /// In en, this message translates to:
  /// **'Server not responding. Please try again.'**
  String get errorServerNotResponding;

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get errorNoInternet;

  /// No description provided for @actionLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get actionLogout;

  /// No description provided for @actionResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get actionResend;

  /// No description provided for @actionSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get actionSendCode;

  /// No description provided for @actionVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get actionVerify;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get fieldVerificationCode;

  /// No description provided for @hintEmailExample.
  ///
  /// In en, this message translates to:
  /// **'example@email.com'**
  String get hintEmailExample;

  /// No description provided for @hint6DigitCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get hint6DigitCode;

  /// No description provided for @emailVerifyHeader.
  ///
  /// In en, this message translates to:
  /// **'Email Verification'**
  String get emailVerifyHeader;

  /// No description provided for @emailVerifyHeading.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get emailVerifyHeading;

  /// No description provided for @emailVerifySubheading.
  ///
  /// In en, this message translates to:
  /// **'To continue using HTM,\nplease verify your email address.'**
  String get emailVerifySubheading;

  /// No description provided for @emailVerifyMissingEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get emailVerifyMissingEmail;

  /// No description provided for @emailVerifyCodeSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Code Sent'**
  String get emailVerifyCodeSentTitle;

  /// No description provided for @emailVerifyCodeSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent.'**
  String get emailVerifyCodeSentMessage;

  /// No description provided for @emailVerifyCodeSendErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send code'**
  String get emailVerifyCodeSendErrorTitle;

  /// No description provided for @emailVerifyCodeSendErrorDefault.
  ///
  /// In en, this message translates to:
  /// **'Failed to send code.'**
  String get emailVerifyCodeSendErrorDefault;

  /// No description provided for @emailVerifyMissing6Digit.
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit code.'**
  String get emailVerifyMissing6Digit;

  /// No description provided for @emailVerifyFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get emailVerifyFailedTitle;

  /// No description provided for @emailVerifyFailedDefault.
  ///
  /// In en, this message translates to:
  /// **'Verification failed.'**
  String get emailVerifyFailedDefault;

  /// No description provided for @emailVerifySuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Verified!'**
  String get emailVerifySuccessTitle;

  /// No description provided for @emailVerifySuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your email has been verified successfully.\nYou can now use all features.'**
  String get emailVerifySuccessMessage;

  /// No description provided for @emailVerifyGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get emailVerifyGoHome;

  /// No description provided for @emailVerifyChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change Email'**
  String get emailVerifyChangeEmail;

  /// No description provided for @emailVerifyChangeEmailHint.
  ///
  /// In en, this message translates to:
  /// **'You can change your email address if needed.'**
  String get emailVerifyChangeEmailHint;

  /// No description provided for @emailVerifyTimerRemaining.
  ///
  /// In en, this message translates to:
  /// **'⏱ {time} remaining'**
  String emailVerifyTimerRemaining(String time);

  /// No description provided for @actionResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get actionResendCode;

  /// No description provided for @actionGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get actionGoToLogin;

  /// No description provided for @actionResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get actionResetPassword;

  /// No description provided for @codeNotReceivedPrompt.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code?'**
  String get codeNotReceivedPrompt;

  /// No description provided for @findUsernameHeader.
  ///
  /// In en, this message translates to:
  /// **'Find ID'**
  String get findUsernameHeader;

  /// No description provided for @findUsernameHeading.
  ///
  /// In en, this message translates to:
  /// **'Find Your Username'**
  String get findUsernameHeading;

  /// No description provided for @findUsernameSubheading.
  ///
  /// In en, this message translates to:
  /// **'Enter the email address associated with your account.'**
  String get findUsernameSubheading;

  /// No description provided for @findUsernameHelp.
  ///
  /// In en, this message translates to:
  /// **'We\'ll look up your account and show a masked version of your username for verification.'**
  String get findUsernameHelp;

  /// No description provided for @findUsernameNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get findUsernameNotFoundTitle;

  /// No description provided for @findUsernameNotFoundDefault.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email.'**
  String get findUsernameNotFoundDefault;

  /// No description provided for @findUsernameStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Is this your account?'**
  String get findUsernameStep2Title;

  /// No description provided for @findUsernameStep2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'We found an account with the email you provided.'**
  String get findUsernameStep2Subtitle;

  /// No description provided for @findUsernameStep2Hint.
  ///
  /// In en, this message translates to:
  /// **'To see your full username, verify your email.'**
  String get findUsernameStep2Hint;

  /// No description provided for @findUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get findUsernameLabel;

  /// No description provided for @findUsernameTryDifferent.
  ///
  /// In en, this message translates to:
  /// **'Try Different Email'**
  String get findUsernameTryDifferent;

  /// No description provided for @findUsernameSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Username Found'**
  String get findUsernameSuccessTitle;

  /// No description provided for @findUsernameSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your username has been verified.'**
  String get findUsernameSuccessMessage;

  /// No description provided for @findUsernameYourUsername.
  ///
  /// In en, this message translates to:
  /// **'Your Username'**
  String get findUsernameYourUsername;

  /// No description provided for @findUsernameUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Use this username to log in to your account.'**
  String get findUsernameUsernameHint;

  /// No description provided for @actionSendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get actionSendVerificationCode;

  /// No description provided for @fieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fieldUsername;

  /// No description provided for @fieldNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get fieldNewPassword;

  /// No description provided for @fieldConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get fieldConfirmPassword;

  /// No description provided for @hintEnterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get hintEnterUsername;

  /// No description provided for @hintEnterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter new password'**
  String get hintEnterNewPassword;

  /// No description provided for @hintReenterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter new password'**
  String get hintReenterNewPassword;

  /// No description provided for @resetHeader.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetHeader;

  /// No description provided for @resetHeading.
  ///
  /// In en, this message translates to:
  /// **'Reset Your Password'**
  String get resetHeading;

  /// No description provided for @resetSubheading.
  ///
  /// In en, this message translates to:
  /// **'Enter your username and email to verify your identity.'**
  String get resetSubheading;

  /// No description provided for @resetMissingUsernameEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your username and email.'**
  String get resetMissingUsernameEmail;

  /// No description provided for @resetNoAccountDefault.
  ///
  /// In en, this message translates to:
  /// **'No account found.'**
  String get resetNoAccountDefault;

  /// No description provided for @resetCodeSentInfo.
  ///
  /// In en, this message translates to:
  /// **'A verification code will be sent to your email address.'**
  String get resetCodeSentInfo;

  /// No description provided for @resetCodeResentTitle.
  ///
  /// In en, this message translates to:
  /// **'Code Resent'**
  String get resetCodeResentTitle;

  /// No description provided for @resetCodeResentMessage.
  ///
  /// In en, this message translates to:
  /// **'Verification code resent.'**
  String get resetCodeResentMessage;

  /// No description provided for @resetCodeResendErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t resend code'**
  String get resetCodeResendErrorTitle;

  /// No description provided for @resetCodeResendErrorDefault.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend code.'**
  String get resetCodeResendErrorDefault;

  /// No description provided for @resetEnterCodeHeading.
  ///
  /// In en, this message translates to:
  /// **'Enter Verification Code'**
  String get resetEnterCodeHeading;

  /// No description provided for @resetCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}'**
  String resetCodeSentTo(String email);

  /// No description provided for @resetWrongEmail.
  ///
  /// In en, this message translates to:
  /// **'Wrong email? Go back'**
  String get resetWrongEmail;

  /// No description provided for @resetSetNewHeading.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get resetSetNewHeading;

  /// No description provided for @resetSetNewSubheading.
  ///
  /// In en, this message translates to:
  /// **'Create a new password for your account.'**
  String get resetSetNewSubheading;

  /// No description provided for @resetMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields.'**
  String get resetMissingFields;

  /// No description provided for @resetPasswordsMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get resetPasswordsMismatchTitle;

  /// No description provided for @resetPasswordsMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get resetPasswordsMismatchMessage;

  /// No description provided for @resetFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reset password'**
  String get resetFailedTitle;

  /// No description provided for @resetFailedDefault.
  ///
  /// In en, this message translates to:
  /// **'Failed to reset password.'**
  String get resetFailedDefault;

  /// No description provided for @resetSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Password Changed'**
  String get resetSuccessTitle;

  /// No description provided for @resetSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your password has been successfully reset.\nYou can now log in with your new password.'**
  String get resetSuccessMessage;

  /// No description provided for @resetSuccessDevicesNote.
  ///
  /// In en, this message translates to:
  /// **'All other devices have been logged out for security.'**
  String get resetSuccessDevicesNote;

  /// No description provided for @actionGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get actionGetStarted;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fieldFullName;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldPreferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred Language'**
  String get fieldPreferredLanguage;

  /// No description provided for @hintFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get hintFullName;

  /// No description provided for @hintChooseUsername.
  ///
  /// In en, this message translates to:
  /// **'Choose a username'**
  String get hintChooseUsername;

  /// No description provided for @hintEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get hintEnterPassword;

  /// No description provided for @hintReenterPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get hintReenterPassword;

  /// No description provided for @passwordsMismatchInline.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsMismatchInline;

  /// No description provided for @registerTermsHeading.
  ///
  /// In en, this message translates to:
  /// **'Review the Terms'**
  String get registerTermsHeading;

  /// No description provided for @registerTermsSubheading.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the terms to use the service.'**
  String get registerTermsSubheading;

  /// No description provided for @registerTermsBody.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service\n\nThese terms govern your use of the HTM service. Please read them carefully before using the service.\n\nArticle 1 (Purpose)\nThese terms define the rights, obligations, and responsibilities between the company and its members regarding the use of the service.\n\nArticle 2 (Definitions)\nThe definitions of terms used in these terms are as follows.'**
  String get registerTermsBody;

  /// No description provided for @registerAgreeAll.
  ///
  /// In en, this message translates to:
  /// **'Agree to all terms'**
  String get registerAgreeAll;

  /// No description provided for @registerAgreeTos.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service. (Required)'**
  String get registerAgreeTos;

  /// No description provided for @registerAgreePrivacy.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Privacy Policy. (Required)'**
  String get registerAgreePrivacy;

  /// No description provided for @registerAgreeMarketing.
  ///
  /// In en, this message translates to:
  /// **'I agree to receive marketing information. (Optional)'**
  String get registerAgreeMarketing;

  /// No description provided for @registerTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please agree to all required terms.'**
  String get registerTermsRequired;

  /// No description provided for @registerStoresHeading.
  ///
  /// In en, this message translates to:
  /// **'Select Your Stores'**
  String get registerStoresHeading;

  /// No description provided for @registerStoresSubheading.
  ///
  /// In en, this message translates to:
  /// **'Choose the stores you work at.\nYou can select multiple stores.'**
  String get registerStoresSubheading;

  /// No description provided for @registerStoresSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 store selected} other{{count} stores selected}}'**
  String registerStoresSelectedCount(int count);

  /// No description provided for @registerStoresSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search stores...'**
  String get registerStoresSearchHint;

  /// No description provided for @registerStoresNoSearchResult.
  ///
  /// In en, this message translates to:
  /// **'No stores found for \"{query}\".'**
  String registerStoresNoSearchResult(String query);

  /// No description provided for @registerStoresEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stores available.\nPlease contact your manager.'**
  String get registerStoresEmpty;

  /// No description provided for @registerStoresLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stores.'**
  String get registerStoresLoadFailed;

  /// No description provided for @registerSelectStoreRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one store.'**
  String get registerSelectStoreRequired;

  /// No description provided for @registerInfoHeading.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get registerInfoHeading;

  /// No description provided for @registerInfoSubheading.
  ///
  /// In en, this message translates to:
  /// **'Enter your basic information to get started.'**
  String get registerInfoSubheading;

  /// No description provided for @registerEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get registerEnterName;

  /// No description provided for @registerEnterUsername.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username.'**
  String get registerEnterUsername;

  /// No description provided for @registerEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password.'**
  String get registerEnterPassword;

  /// No description provided for @registerEmailSubheading.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a verification code to your email.'**
  String get registerEmailSubheading;

  /// No description provided for @registerEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get registerEnterValidEmail;

  /// No description provided for @registerCodeSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send code. Please try again.'**
  String get registerCodeSendFailed;

  /// No description provided for @registerEmailVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Email Verified'**
  String get registerEmailVerifiedTitle;

  /// No description provided for @registerEmailVerifiedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your email has been verified successfully.'**
  String get registerEmailVerifiedMessage;

  /// No description provided for @registerEmailVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'✓ Email verified'**
  String get registerEmailVerifiedBadge;

  /// No description provided for @registerCodeExpiresHint.
  ///
  /// In en, this message translates to:
  /// **'Code expires in 5 minutes after sending.'**
  String get registerCodeExpiresHint;

  /// No description provided for @registerVerifyEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email first.'**
  String get registerVerifyEmailFirst;

  /// No description provided for @registerFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration Failed'**
  String get registerFailedTitle;

  /// No description provided for @registerFailedDefault.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registerFailedDefault;

  /// No description provided for @registerWelcomeName.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String registerWelcomeName(String name);

  /// No description provided for @registerCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration Complete'**
  String get registerCompleteTitle;

  /// No description provided for @registerCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Start using the service right away.'**
  String get registerCompleteMessage;

  /// No description provided for @registerStepTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get registerStepTerms;

  /// No description provided for @registerStepStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get registerStepStore;

  /// No description provided for @registerStepInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get registerStepInfo;

  /// No description provided for @registerStepEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get registerStepEmail;

  /// No description provided for @registerStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get registerStepDone;

  /// No description provided for @scheduleViewWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get scheduleViewWeekly;

  /// No description provided for @scheduleViewMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get scheduleViewMonthly;

  /// No description provided for @scheduleToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get scheduleToday;

  /// No description provided for @scheduleThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get scheduleThisWeek;

  /// No description provided for @scheduleDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}} · {hours}h'**
  String scheduleDaysHours(int days, int hours);

  /// No description provided for @scheduleShiftsHours.
  ///
  /// In en, this message translates to:
  /// **'{shifts, plural, =1{1 shift} other{{shifts} shifts}} · {hours}h'**
  String scheduleShiftsHours(int shifts, int hours);

  /// No description provided for @scheduleNoShifts.
  ///
  /// In en, this message translates to:
  /// **'No shifts'**
  String get scheduleNoShifts;

  /// No description provided for @scheduleBadgePending.
  ///
  /// In en, this message translates to:
  /// **'Pending {count}'**
  String scheduleBadgePending(int count);

  /// No description provided for @scheduleBadgeConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed {count}'**
  String scheduleBadgeConfirmed(int count);

  /// No description provided for @scheduleBadgeRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected {count}'**
  String scheduleBadgeRejected(int count);

  /// No description provided for @scheduleStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get scheduleStatusConfirmed;

  /// No description provided for @scheduleStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get scheduleStatusRejected;

  /// No description provided for @scheduleStatusModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get scheduleStatusModified;

  /// No description provided for @scheduleStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get scheduleStatusSubmitted;

  /// No description provided for @scheduleStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get scheduleStatusPending;

  /// No description provided for @scheduleConfirmedSection.
  ///
  /// In en, this message translates to:
  /// **'Confirmed Schedule'**
  String get scheduleConfirmedSection;

  /// No description provided for @scheduleRequestSection.
  ///
  /// In en, this message translates to:
  /// **'{label} Schedule'**
  String scheduleRequestSection(String label);

  /// No description provided for @scheduleStoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get scheduleStoreLabel;

  /// No description provided for @scheduleWorkRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Work Role'**
  String get scheduleWorkRoleLabel;

  /// No description provided for @scheduleTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get scheduleTimeLabel;

  /// No description provided for @scheduleNetWork.
  ///
  /// In en, this message translates to:
  /// **'Net work: {duration}'**
  String scheduleNetWork(String duration);

  /// No description provided for @scheduleUpcomingChecklist.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Checklist'**
  String get scheduleUpcomingChecklist;

  /// No description provided for @scheduleViewChecklist.
  ///
  /// In en, this message translates to:
  /// **'View Checklist'**
  String get scheduleViewChecklist;

  /// No description provided for @scheduleChangedByManager.
  ///
  /// In en, this message translates to:
  /// **'Changed by manager'**
  String get scheduleChangedByManager;

  /// No description provided for @scheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No schedule'**
  String get scheduleEmpty;

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

  /// No description provided for @ojtTitle.
  ///
  /// In en, this message translates to:
  /// **'OJT Training'**
  String get ojtTitle;

  /// No description provided for @ojtSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On-the-job training modules will be available here.'**
  String get ojtSubtitle;

  /// No description provided for @noticesHeader.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get noticesHeader;

  /// No description provided for @noticesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notices'**
  String get noticesEmpty;

  /// No description provided for @tasksHeader.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksHeader;

  /// No description provided for @tasksFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter: '**
  String get tasksFilterLabel;

  /// No description provided for @tasksFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tasksFilterAll;

  /// No description provided for @tasksFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get tasksFilterPending;

  /// No description provided for @tasksFilterInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get tasksFilterInProgress;

  /// No description provided for @tasksFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tasksFilterCompleted;

  /// No description provided for @tasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get tasksEmpty;

  /// No description provided for @tasksDuePrefix.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String tasksDuePrefix(String date);

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

  /// No description provided for @settingsHeader.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsHeader;

  /// No description provided for @settingsAlertSettings.
  ///
  /// In en, this message translates to:
  /// **'Alert Settings'**
  String get settingsAlertSettings;

  /// No description provided for @settingsEditUsername.
  ///
  /// In en, this message translates to:
  /// **'Edit Username'**
  String get settingsEditUsername;

  /// No description provided for @settingsEnterNewUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter new username'**
  String get settingsEnterNewUsername;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get settingsChangePassword;

  /// No description provided for @settingsLanguageSaved.
  ///
  /// In en, this message translates to:
  /// **'Language preference saved.'**
  String get settingsLanguageSaved;

  /// No description provided for @settingsLanguageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update language'**
  String get settingsLanguageFailed;

  /// No description provided for @settingsUsernameSaved.
  ///
  /// In en, this message translates to:
  /// **'Username updated.'**
  String get settingsUsernameSaved;

  /// No description provided for @settingsUsernameFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update username'**
  String get settingsUsernameFailed;

  /// No description provided for @fieldCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get fieldCurrentPassword;

  /// No description provided for @fieldConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get fieldConfirmNewPassword;

  /// No description provided for @hintEnterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter current password'**
  String get hintEnterCurrentPassword;

  /// No description provided for @changePasswordHeader.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordHeader;

  /// No description provided for @changePasswordHeading.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordHeading;

  /// No description provided for @changePasswordSubheading.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password and set a new one.'**
  String get changePasswordSubheading;

  /// No description provided for @changePasswordDevicesNote.
  ///
  /// In en, this message translates to:
  /// **'After changing your password, all other devices will be logged out.'**
  String get changePasswordDevicesNote;

  /// No description provided for @changePasswordSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Password Changed'**
  String get changePasswordSuccessTitle;

  /// No description provided for @changePasswordSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get changePasswordSuccessMessage;

  /// No description provided for @changePasswordFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change password'**
  String get changePasswordFailedTitle;

  /// No description provided for @changePasswordFailedDefault.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password.'**
  String get changePasswordFailedDefault;

  /// No description provided for @alertsHeader.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsHeader;

  /// No description provided for @alertsUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread} other{{count} unread}}'**
  String alertsUnreadCount(int count);

  /// No description provided for @alertsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get alertsMarkAllRead;

  /// No description provided for @alertsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load alerts'**
  String get alertsLoadFailed;

  /// No description provided for @alertsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alerts yet'**
  String get alertsEmpty;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String timeMinAgo(int n);

  /// No description provided for @timeHourAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String timeHourAgo(int n);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get timeYesterday;

  /// No description provided for @timeDayAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String timeDayAgo(int n);

  /// No description provided for @timeWeekAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}w ago'**
  String timeWeekAgo(int n);

  /// No description provided for @dailyReportsHeader.
  ///
  /// In en, this message translates to:
  /// **'Daily Reports'**
  String get dailyReportsHeader;

  /// No description provided for @dailyReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports yet'**
  String get dailyReportsEmpty;

  /// No description provided for @dailyReportsFilterDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get dailyReportsFilterDraft;

  /// No description provided for @dailyReportsFilterSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get dailyReportsFilterSubmitted;

  /// No description provided for @dailyReportsFilterReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get dailyReportsFilterReviewed;

  /// No description provided for @inventoryHeader.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventoryHeader;

  /// No description provided for @inventoryStoresLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stores'**
  String get inventoryStoresLoadFailed;

  /// No description provided for @inventoryNoStoresTitle.
  ///
  /// In en, this message translates to:
  /// **'No stores assigned'**
  String get inventoryNoStoresTitle;

  /// No description provided for @inventoryNoStoresMessage.
  ///
  /// In en, this message translates to:
  /// **'You are not assigned to any stores yet.'**
  String get inventoryNoStoresMessage;

  /// No description provided for @inventoryStockItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String inventoryStockItems(int count);

  /// No description provided for @inventoryStockLow.
  ///
  /// In en, this message translates to:
  /// **'{count} low'**
  String inventoryStockLow(int count);

  /// No description provided for @inventoryStockOut.
  ///
  /// In en, this message translates to:
  /// **'{count} out'**
  String inventoryStockOut(int count);

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// No description provided for @commonConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get commonConnectionError;

  /// No description provided for @alertSettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'Alert Settings'**
  String get alertSettingsHeader;

  /// No description provided for @alertSettingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load alert settings.'**
  String get alertSettingsLoadFailed;

  /// No description provided for @alertSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Alert preferences updated.'**
  String get alertSettingsSaved;

  /// No description provided for @alertSettingsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to default?'**
  String get alertSettingsResetTitle;

  /// No description provided for @alertSettingsResetMessage.
  ///
  /// In en, this message translates to:
  /// **'All categories will be turned back on. You can adjust them again later.'**
  String get alertSettingsResetMessage;

  /// No description provided for @alertSettingsResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get alertSettingsResetButton;

  /// No description provided for @alertSettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose which categories you receive in the app and via email. A dash (—) means email isn\'t available for that category.'**
  String get alertSettingsIntro;

  /// No description provided for @alertSettingsHeaderInApp.
  ///
  /// In en, this message translates to:
  /// **'IN-APP'**
  String get alertSettingsHeaderInApp;

  /// No description provided for @alertSettingsHeaderEmail.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get alertSettingsHeaderEmail;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @commonStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get commonStaff;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeFirstNameSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get homeFirstNameSuffix;

  /// No description provided for @homePasswordBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Your password was recently reset. We recommend changing it to a new password.'**
  String get homePasswordBannerMessage;

  /// No description provided for @homeTodayOverview.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Overview'**
  String get homeTodayOverview;

  /// No description provided for @homeStatChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get homeStatChecklist;

  /// No description provided for @homeStatTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get homeStatTasks;

  /// No description provided for @homeStatDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due Today'**
  String get homeStatDueToday;

  /// No description provided for @homeQuickNotices.
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get homeQuickNotices;

  /// No description provided for @homeQuickOjt.
  ///
  /// In en, this message translates to:
  /// **'OJT'**
  String get homeQuickOjt;

  /// No description provided for @homeQuickDailyReports.
  ///
  /// In en, this message translates to:
  /// **'Daily Reports'**
  String get homeQuickDailyReports;

  /// No description provided for @homeQuickInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get homeQuickInventory;

  /// No description provided for @homeVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Share your voice!'**
  String get homeVoiceHint;

  /// No description provided for @homeVoiceSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get homeVoiceSubmittedTitle;

  /// No description provided for @homeVoiceSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Thanks for sharing!'**
  String get homeVoiceSubmittedMessage;

  /// No description provided for @homeVoiceFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit'**
  String get homeVoiceFailedTitle;

  /// No description provided for @homeVoiceFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit. Please try again.'**
  String get homeVoiceFailedMessage;

  /// No description provided for @homeVoiceCategoryIdea.
  ///
  /// In en, this message translates to:
  /// **'💡 Idea'**
  String get homeVoiceCategoryIdea;

  /// No description provided for @homeVoiceCategoryFacility.
  ///
  /// In en, this message translates to:
  /// **'🔧 Facility'**
  String get homeVoiceCategoryFacility;

  /// No description provided for @homeVoiceCategorySafety.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Safety'**
  String get homeVoiceCategorySafety;

  /// No description provided for @homeVoiceCategoryHr.
  ///
  /// In en, this message translates to:
  /// **'👤 HR'**
  String get homeVoiceCategoryHr;

  /// No description provided for @homeVoiceCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'📋 Other'**
  String get homeVoiceCategoryOther;

  /// No description provided for @homeImportantNotice.
  ///
  /// In en, this message translates to:
  /// **'IMPORTANT NOTICE'**
  String get homeImportantNotice;

  /// No description provided for @homeViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get homeViewDetails;

  /// No description provided for @homeScheduleHeader.
  ///
  /// In en, this message translates to:
  /// **'This Week\'s Schedule'**
  String get homeScheduleHeader;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all →'**
  String get homeViewAll;

  /// No description provided for @homeNextShift.
  ///
  /// In en, this message translates to:
  /// **'NEXT SHIFT'**
  String get homeNextShift;

  /// No description provided for @homeTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get homeTomorrow;

  /// No description provided for @homeStatChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get homeStatChanged;

  /// No description provided for @homeRejectedRequests.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 rejected request} other{{count} rejected requests}}'**
  String homeRejectedRequests(int count);

  /// No description provided for @homeResubmit.
  ///
  /// In en, this message translates to:
  /// **'Resubmit →'**
  String get homeResubmit;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get actionUpload;

  /// No description provided for @actionLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get actionLogoutConfirm;

  /// No description provided for @commonComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get commonComingSoonTitle;

  /// No description provided for @myPageHeader.
  ///
  /// In en, this message translates to:
  /// **'My Page'**
  String get myPageHeader;

  /// No description provided for @myTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get myTakePhoto;

  /// No description provided for @myChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get myChooseGallery;

  /// No description provided for @myRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get myRemovePhoto;

  /// No description provided for @myChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Profile Photo'**
  String get myChangePhoto;

  /// No description provided for @myUploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get myUploadDocument;

  /// No description provided for @myReplaceDocument.
  ///
  /// In en, this message translates to:
  /// **'Replace Document'**
  String get myReplaceDocument;

  /// No description provided for @myUploadedAt.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {date}'**
  String myUploadedAt(String date);

  /// No description provided for @myDocumentsHeader.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get myDocumentsHeader;

  /// No description provided for @myDocumentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload required documents for employment verification'**
  String get myDocumentsSubtitle;

  /// No description provided for @myDocumentsUnderDev.
  ///
  /// In en, this message translates to:
  /// **'This feature is under development'**
  String get myDocumentsUnderDev;

  /// No description provided for @myLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get myLogoutConfirmTitle;

  /// No description provided for @myLogoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get myLogoutConfirmMessage;

  /// No description provided for @myDocFoodHandlerTitle.
  ///
  /// In en, this message translates to:
  /// **'Food Handler Card'**
  String get myDocFoodHandlerTitle;

  /// No description provided for @myDocFoodHandlerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required food safety certification'**
  String get myDocFoodHandlerSubtitle;

  /// No description provided for @myDocSsnTitle.
  ///
  /// In en, this message translates to:
  /// **'SSN / Work Authorization'**
  String get myDocSsnTitle;

  /// No description provided for @myDocSsnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Social Security Number or Work Permit'**
  String get myDocSsnSubtitle;

  /// No description provided for @myDocIdTitle.
  ///
  /// In en, this message translates to:
  /// **'Government ID'**
  String get myDocIdTitle;

  /// No description provided for @myDocIdSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Driver License / State ID / Passport'**
  String get myDocIdSubtitle;

  /// No description provided for @myDocI9Title.
  ///
  /// In en, this message translates to:
  /// **'I-9 Form'**
  String get myDocI9Title;

  /// No description provided for @myDocI9Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Employment Eligibility Verification'**
  String get myDocI9Subtitle;

  /// No description provided for @myDocW4Title.
  ///
  /// In en, this message translates to:
  /// **'W-4 Form'**
  String get myDocW4Title;

  /// No description provided for @myDocW4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Employee\'s Withholding Certificate'**
  String get myDocW4Subtitle;

  /// No description provided for @noticeDetailHeader.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get noticeDetailHeader;

  /// No description provided for @noticeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Notice not found'**
  String get noticeNotFound;

  /// No description provided for @noticeAcknowledgedTitle.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get noticeAcknowledgedTitle;

  /// No description provided for @noticeAcknowledgedMessage.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get noticeAcknowledgedMessage;

  /// No description provided for @noticeCommentsCount.
  ///
  /// In en, this message translates to:
  /// **'Comments ({count})'**
  String noticeCommentsCount(int count);

  /// No description provided for @noticeNoComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noticeNoComments;

  /// No description provided for @noticeFirstComment.
  ///
  /// In en, this message translates to:
  /// **'Be the first to leave a comment'**
  String get noticeFirstComment;

  /// No description provided for @noticeCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment...'**
  String get noticeCommentHint;

  /// No description provided for @noticeMarkAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get noticeMarkAsRead;

  /// No description provided for @noticeAcknowledgedButton.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get noticeAcknowledgedButton;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @taskDetailHeader.
  ///
  /// In en, this message translates to:
  /// **'Task Detail'**
  String get taskDetailHeader;

  /// No description provided for @taskNotFound.
  ///
  /// In en, this message translates to:
  /// **'Task not found'**
  String get taskNotFound;

  /// No description provided for @taskMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Complete'**
  String get taskMarkComplete;

  /// No description provided for @taskCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskCompletedTitle;

  /// No description provided for @taskCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Task marked as complete'**
  String get taskCompletedMessage;

  /// No description provided for @taskCompletedByLine.
  ///
  /// In en, this message translates to:
  /// **'Completed by {name} · {time}'**
  String taskCompletedByLine(String name, String time);

  /// No description provided for @taskStartTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get taskStartTimeLabel;

  /// No description provided for @taskDueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get taskDueDateLabel;

  /// No description provided for @taskAssignedToLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get taskAssignedToLabel;

  /// No description provided for @taskCreatedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get taskCreatedByLabel;

  /// No description provided for @taskCreatedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Created at'**
  String get taskCreatedAtLabel;

  /// No description provided for @taskAssigneesCount.
  ///
  /// In en, this message translates to:
  /// **'Assignees ({count})'**
  String taskAssigneesCount(int count);

  /// No description provided for @taskDoneAt.
  ///
  /// In en, this message translates to:
  /// **'Done {time}'**
  String taskDoneAt(String time);

  /// No description provided for @drHeaderNew.
  ///
  /// In en, this message translates to:
  /// **'New Report'**
  String get drHeaderNew;

  /// No description provided for @drHeaderDetail.
  ///
  /// In en, this message translates to:
  /// **'Report Detail'**
  String get drHeaderDetail;

  /// No description provided for @drNotFound.
  ///
  /// In en, this message translates to:
  /// **'Report not found'**
  String get drNotFound;

  /// No description provided for @drSelectStorePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please select a store'**
  String get drSelectStorePrompt;

  /// No description provided for @drTemplateLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load template'**
  String get drTemplateLoadFailedTitle;

  /// No description provided for @drTemplateLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load template'**
  String get drTemplateLoadFailedMessage;

  /// No description provided for @drCreateFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create report'**
  String get drCreateFailedTitle;

  /// No description provided for @drCreateFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to create report'**
  String get drCreateFailedMessage;

  /// No description provided for @drDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get drDraftSaved;

  /// No description provided for @drSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get drSaveFailed;

  /// No description provided for @drSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get drSubmittedTitle;

  /// No description provided for @drSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Report submitted'**
  String get drSubmittedMessage;

  /// No description provided for @drSubmitFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit'**
  String get drSubmitFailedTitle;

  /// No description provided for @drSubmitFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit'**
  String get drSubmitFailedMessage;

  /// No description provided for @drDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Draft'**
  String get drDeleteTitle;

  /// No description provided for @drDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this draft?'**
  String get drDeleteMessage;

  /// No description provided for @drDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get drDeletedTitle;

  /// No description provided for @drDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Draft deleted'**
  String get drDeletedMessage;

  /// No description provided for @drDeleteFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete'**
  String get drDeleteFailedTitle;

  /// No description provided for @drDeleteFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get drDeleteFailedMessage;

  /// No description provided for @drExistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Exists'**
  String get drExistsTitle;

  /// No description provided for @drExistsMessage.
  ///
  /// In en, this message translates to:
  /// **'A report already exists for this store/date/period.\nWould you like to view the existing report?'**
  String get drExistsMessage;

  /// No description provided for @drExistsGo.
  ///
  /// In en, this message translates to:
  /// **'Go to Report'**
  String get drExistsGo;

  /// No description provided for @drSaveDraftButton.
  ///
  /// In en, this message translates to:
  /// **'Save Draft'**
  String get drSaveDraftButton;

  /// No description provided for @drStoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get drStoreLabel;

  /// No description provided for @drSelectStoreHint.
  ///
  /// In en, this message translates to:
  /// **'Select store'**
  String get drSelectStoreHint;

  /// No description provided for @drDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get drDateLabel;

  /// No description provided for @drPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get drPeriodLabel;

  /// No description provided for @drPeriodLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get drPeriodLunch;

  /// No description provided for @drPeriodDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get drPeriodDinner;

  /// No description provided for @drStartWriting.
  ///
  /// In en, this message translates to:
  /// **'Start Writing'**
  String get drStartWriting;

  /// No description provided for @drSubmittedAt.
  ///
  /// In en, this message translates to:
  /// **'Submitted {time}'**
  String drSubmittedAt(String time);

  /// No description provided for @drContentHeader.
  ///
  /// In en, this message translates to:
  /// **'Report Content'**
  String get drContentHeader;

  /// No description provided for @drEnterContent.
  ///
  /// In en, this message translates to:
  /// **'Enter content...'**
  String get drEnterContent;

  /// No description provided for @drOptional.
  ///
  /// In en, this message translates to:
  /// **'  (Optional)'**
  String get drOptional;

  /// No description provided for @drNoContent.
  ///
  /// In en, this message translates to:
  /// **'(No content)'**
  String get drNoContent;

  /// No description provided for @drFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get drFieldRequired;

  /// No description provided for @drDeadline.
  ///
  /// In en, this message translates to:
  /// **'Due {time}'**
  String drDeadline(String time);

  /// No description provided for @drOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get drOverdue;

  /// No description provided for @drLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get drLate;

  /// No description provided for @drReviewedBy.
  ///
  /// In en, this message translates to:
  /// **'Reviewed by {name}'**
  String drReviewedBy(String name);

  /// No description provided for @drReviewedByAt.
  ///
  /// In en, this message translates to:
  /// **'Reviewed by {name} · {time}'**
  String drReviewedByAt(String name, String time);

  /// No description provided for @drAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge'**
  String get drAcknowledge;

  /// No description provided for @drAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get drAcknowledged;

  /// No description provided for @drAcknowledgedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No acknowledgements} =1{1 acknowledgement} other{{count} acknowledgements}}'**
  String drAcknowledgedCount(int count);

  /// No description provided for @drAcknowledgedTitle.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get drAcknowledgedTitle;

  /// No description provided for @drAcknowledgedMessage.
  ///
  /// In en, this message translates to:
  /// **'You confirmed this report as read'**
  String get drAcknowledgedMessage;

  /// No description provided for @drAcknowledgeFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t acknowledge'**
  String get drAcknowledgeFailedTitle;

  /// No description provided for @drAcknowledgeFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to acknowledge the report'**
  String get drAcknowledgeFailedMessage;

  /// No description provided for @actionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get actionView;

  /// No description provided for @invChangeStore.
  ///
  /// In en, this message translates to:
  /// **'Change Store'**
  String get invChangeStore;

  /// No description provided for @invInStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get invInStock;

  /// No description provided for @invLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get invLowStock;

  /// No description provided for @invOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get invOutOfStock;

  /// No description provided for @invActionView.
  ///
  /// In en, this message translates to:
  /// **'View Inventory'**
  String get invActionView;

  /// No description provided for @invActionAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get invActionAudit;

  /// No description provided for @invActionStockIn.
  ///
  /// In en, this message translates to:
  /// **'Stock In'**
  String get invActionStockIn;

  /// No description provided for @invActionStockOut.
  ///
  /// In en, this message translates to:
  /// **'Stock Out'**
  String get invActionStockOut;

  /// No description provided for @invItemsNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item needs attention} other{{count} items need attention}}'**
  String invItemsNeedAttention(int count);

  /// No description provided for @actionAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get actionAdjust;

  /// No description provided for @invSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get invSearchHint;

  /// No description provided for @invFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get invFilterAll;

  /// No description provided for @invFilterLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get invFilterLowStock;

  /// No description provided for @invFilterFrequent.
  ///
  /// In en, this message translates to:
  /// **'Frequent Only'**
  String get invFilterFrequent;

  /// No description provided for @invEmpty.
  ///
  /// In en, this message translates to:
  /// **'No products in inventory'**
  String get invEmpty;

  /// No description provided for @invNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching products'**
  String get invNoMatch;

  /// No description provided for @invStockInRecorded.
  ///
  /// In en, this message translates to:
  /// **'Stock in recorded'**
  String get invStockInRecorded;

  /// No description provided for @invStockOutRecorded.
  ///
  /// In en, this message translates to:
  /// **'Stock out recorded'**
  String get invStockOutRecorded;

  /// No description provided for @invSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to record. Please try again.'**
  String get invSaveFailed;

  /// No description provided for @invAdjustedTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjusted'**
  String get invAdjustedTitle;

  /// No description provided for @invAdjustedMessage.
  ///
  /// In en, this message translates to:
  /// **'Quantity adjusted'**
  String get invAdjustedMessage;

  /// No description provided for @invAdjustFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to adjust. Please try again.'**
  String get invAdjustFailed;

  /// No description provided for @invStatusLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get invStatusLow;

  /// No description provided for @invStatusOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get invStatusOut;

  /// No description provided for @invStatusOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get invStatusOk;

  /// No description provided for @invNeverAudited.
  ///
  /// In en, this message translates to:
  /// **'Never audited'**
  String get invNeverAudited;

  /// No description provided for @invFrequent.
  ///
  /// In en, this message translates to:
  /// **'Frequent'**
  String get invFrequent;

  /// No description provided for @invLastAudited.
  ///
  /// In en, this message translates to:
  /// **'Last: {label}'**
  String invLastAudited(String label);

  /// No description provided for @invCurrentStock.
  ///
  /// In en, this message translates to:
  /// **'Current Stock'**
  String get invCurrentStock;

  /// No description provided for @invStatusOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get invStatusOutOfStock;

  /// No description provided for @invStatusInStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get invStatusInStock;

  /// No description provided for @invSvOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'Only SV and above can perform stock operations.'**
  String get invSvOnlyMessage;

  /// No description provided for @invNegativeStockWarning.
  ///
  /// In en, this message translates to:
  /// **'Will result in negative stock'**
  String get invNegativeStockWarning;

  /// No description provided for @invReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get invReasonOptional;

  /// No description provided for @invAdjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust Quantity'**
  String get invAdjustTitle;

  /// No description provided for @invAdjustHint.
  ///
  /// In en, this message translates to:
  /// **'Set new quantity (current: {qty} ea)'**
  String invAdjustHint(int qty);

  /// No description provided for @invNewQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'New quantity (ea)'**
  String get invNewQuantityLabel;

  /// No description provided for @invStockInTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock In'**
  String get invStockInTitle;

  /// No description provided for @invStockOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Out'**
  String get invStockOutTitle;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get actionExit;

  /// No description provided for @auditHeader.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get auditHeader;

  /// No description provided for @auditLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading inventory...'**
  String get auditLoading;

  /// No description provided for @auditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No inventory items'**
  String get auditEmpty;

  /// No description provided for @auditModifiedOnly.
  ///
  /// In en, this message translates to:
  /// **'Modified only'**
  String get auditModifiedOnly;

  /// No description provided for @auditSectionFrequent.
  ///
  /// In en, this message translates to:
  /// **'Frequent'**
  String get auditSectionFrequent;

  /// No description provided for @auditSectionAll.
  ///
  /// In en, this message translates to:
  /// **'All Items'**
  String get auditSectionAll;

  /// No description provided for @auditNoModified.
  ///
  /// In en, this message translates to:
  /// **'No modified items yet'**
  String get auditNoModified;

  /// No description provided for @auditNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items in audit'**
  String get auditNoItems;

  /// No description provided for @auditCompleteButton.
  ///
  /// In en, this message translates to:
  /// **'Complete Audit'**
  String get auditCompleteButton;

  /// No description provided for @auditCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Audit'**
  String get auditCompleteTitle;

  /// No description provided for @auditCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This will apply all quantity adjustments. Are you sure?'**
  String get auditCompleteMessage;

  /// No description provided for @auditCompleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get auditCompleteConfirm;

  /// No description provided for @auditCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get auditCompletedTitle;

  /// No description provided for @auditCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Audit completed'**
  String get auditCompletedMessage;

  /// No description provided for @auditFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit audit'**
  String get auditFailedMessage;

  /// No description provided for @auditExitTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit Audit'**
  String get auditExitTitle;

  /// No description provided for @auditExitMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? Progress will not be saved.'**
  String get auditExitMessage;

  /// No description provided for @auditAdjustmentsApplied.
  ///
  /// In en, this message translates to:
  /// **'Adjustments Applied'**
  String get auditAdjustmentsApplied;

  /// No description provided for @auditCompleteHeading.
  ///
  /// In en, this message translates to:
  /// **'Audit Complete'**
  String get auditCompleteHeading;

  /// No description provided for @auditNeverAudited.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get auditNeverAudited;

  /// No description provided for @auditSystemLastLine.
  ///
  /// In en, this message translates to:
  /// **'System: {system} · Last: {last}'**
  String auditSystemLastLine(String system, String last);

  /// No description provided for @auditActualLabel.
  ///
  /// In en, this message translates to:
  /// **'Actual:'**
  String get auditActualLabel;

  /// No description provided for @chatPhotoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo upload failed'**
  String get chatPhotoUploadFailed;

  /// No description provided for @chatPhotoRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo required'**
  String get chatPhotoRequiredTitle;

  /// No description provided for @chatPhotoRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Please attach a photo.'**
  String get chatPhotoRequiredMessage;

  /// No description provided for @chatSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit. Please try again.'**
  String get chatSubmitFailed;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get chatSendFailed;

  /// No description provided for @chatPhotoSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo send failed'**
  String get chatPhotoSendFailed;

  /// No description provided for @chatAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get chatAddPhoto;

  /// No description provided for @chatTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get chatTakePhoto;

  /// No description provided for @chatChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chatChooseGallery;

  /// No description provided for @chatSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get chatSubmitting;

  /// No description provided for @chatUploadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo...'**
  String get chatUploadingPhoto;

  /// No description provided for @chatStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected — Resubmission required'**
  String get chatStatusRejected;

  /// No description provided for @chatStatusReReview.
  ///
  /// In en, this message translates to:
  /// **'Pending re-review'**
  String get chatStatusReReview;

  /// No description provided for @chatStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get chatStatusApproved;

  /// No description provided for @chatStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed — Awaiting review'**
  String get chatStatusCompleted;

  /// No description provided for @chatStatusNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Not completed — Submit below'**
  String get chatStatusNotCompleted;

  /// No description provided for @chatPhotosLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos (required, min {min})'**
  String chatPhotosLabel(int min);

  /// No description provided for @chatTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Text (required)'**
  String get chatTextLabel;

  /// No description provided for @chatTakePhotoBtn.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get chatTakePhotoBtn;

  /// No description provided for @chatGalleryBtn.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get chatGalleryBtn;

  /// No description provided for @chatPhotosCount.
  ///
  /// In en, this message translates to:
  /// **'Photos: {current}/{min} required'**
  String chatPhotosCount(int current, int min);

  /// No description provided for @chatReasonForResubmission.
  ///
  /// In en, this message translates to:
  /// **'Reason for resubmission...'**
  String get chatReasonForResubmission;

  /// No description provided for @chatTextOptional.
  ///
  /// In en, this message translates to:
  /// **'Text (optional) — e.g. task completed'**
  String get chatTextOptional;

  /// No description provided for @chatResubmit.
  ///
  /// In en, this message translates to:
  /// **'Resubmit'**
  String get chatResubmit;

  /// No description provided for @chatSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get chatSubmit;

  /// No description provided for @chatBadgeSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get chatBadgeSubmitted;

  /// No description provided for @chatBadgeResubmitted.
  ///
  /// In en, this message translates to:
  /// **'Resubmitted'**
  String get chatBadgeResubmitted;

  /// No description provided for @chatBadgeRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get chatBadgeRejected;

  /// No description provided for @chatBadgeApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get chatBadgeApproved;

  /// No description provided for @chatBadgeReReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Re-review'**
  String get chatBadgeReReview;

  /// No description provided for @chatBadgePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get chatBadgePending;

  /// No description provided for @chatTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatTypeMessage;

  /// No description provided for @chatLabelRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get chatLabelRejected;

  /// No description provided for @chatLabelApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get chatLabelApproved;

  /// No description provided for @chatLabelReReview.
  ///
  /// In en, this message translates to:
  /// **'Re-review'**
  String get chatLabelReReview;

  /// No description provided for @chatLabelDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get chatLabelDone;

  /// No description provided for @chatLabelPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get chatLabelPending;

  /// No description provided for @stockItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get stockItemsLabel;

  /// No description provided for @stockTapToAddItems.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add items'**
  String get stockTapToAddItems;

  /// No description provided for @stockReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get stockReasonOptional;

  /// No description provided for @stockSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get stockSavedTitle;

  /// No description provided for @stockInSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Stock in recorded successfully'**
  String get stockInSavedMessage;

  /// No description provided for @stockOutSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Stock out recorded successfully'**
  String get stockOutSavedMessage;

  /// No description provided for @stockSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save. Please try again.'**
  String get stockSaveFailed;

  /// No description provided for @stockSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search inventory...'**
  String get stockSearchHint;

  /// No description provided for @stockNoProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get stockNoProductsFound;

  /// No description provided for @stockAddedBadge.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get stockAddedBadge;

  /// No description provided for @stockWillBeNegative.
  ///
  /// In en, this message translates to:
  /// **'Will be negative'**
  String get stockWillBeNegative;

  /// No description provided for @stockWillBeBelowMin.
  ///
  /// In en, this message translates to:
  /// **'Will be below minimum'**
  String get stockWillBeBelowMin;

  /// No description provided for @checklistAllDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'All Done'**
  String get checklistAllDoneTitle;

  /// No description provided for @checklistAllDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'All items completed! Great work.'**
  String get checklistAllDoneMessage;

  /// No description provided for @checklistResubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Resubmitted'**
  String get checklistResubmittedTitle;

  /// No description provided for @checklistResubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Resubmitted.'**
  String get checklistResubmittedMessage;

  /// No description provided for @checklistResubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t resubmit'**
  String get checklistResubmitFailed;

  /// No description provided for @checklistResubmitFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to resubmit. Please try again.'**
  String get checklistResubmitFailedMessage;

  /// No description provided for @checklistCompleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete'**
  String get checklistCompleteFailed;

  /// No description provided for @checklistCompleteFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete item. Please try again.'**
  String get checklistCompleteFailedMessage;

  /// No description provided for @checklistUndoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t undo'**
  String get checklistUndoFailed;

  /// No description provided for @checklistUndoFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to undo. Please try again.'**
  String get checklistUndoFailedMessage;

  /// No description provided for @checklistUndoCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo Complete'**
  String get checklistUndoCompleteTitle;

  /// No description provided for @checklistUndoCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to undo this item?'**
  String get checklistUndoCompleteMessage;

  /// No description provided for @checklistUndoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get checklistUndoAction;

  /// No description provided for @checklistCannotUncheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot Uncheck'**
  String get checklistCannotUncheckTitle;

  /// No description provided for @checklistCannotUncheckMessage.
  ///
  /// In en, this message translates to:
  /// **'Reviewed items cannot be unchecked.'**
  String get checklistCannotUncheckMessage;

  /// No description provided for @checklistSubmitReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get checklistSubmitReportTitle;

  /// No description provided for @checklistSubmitReportMessage.
  ///
  /// In en, this message translates to:
  /// **'Submit checklist completion report? Changes may be restricted after submission.'**
  String get checklistSubmitReportMessage;

  /// No description provided for @checklistSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get checklistSubmitAction;

  /// No description provided for @checklistSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get checklistSubmittedTitle;

  /// No description provided for @checklistSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Report submitted.'**
  String get checklistSubmittedMessage;

  /// No description provided for @checklistSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit report'**
  String get checklistSubmitFailed;

  /// No description provided for @checklistSubmitFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report. Please try again.'**
  String get checklistSubmitFailedMessage;

  /// No description provided for @checklistPhotoUploadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload'**
  String get checklistPhotoUploadFailedTitle;

  /// No description provided for @checklistPhotoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo upload failed'**
  String get checklistPhotoUploadFailed;

  /// No description provided for @checklistAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get checklistAddPhoto;

  /// No description provided for @checklistTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get checklistTakePhoto;

  /// No description provided for @checklistChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get checklistChooseGallery;

  /// No description provided for @checklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklistTitle;

  /// No description provided for @checklistFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load schedule'**
  String get checklistFailedToLoad;

  /// No description provided for @checklistNotFound.
  ///
  /// In en, this message translates to:
  /// **'Schedule not found.'**
  String get checklistNotFound;

  /// No description provided for @checklistUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo...'**
  String get checklistUploading;

  /// No description provided for @checklistEmptyPending.
  ///
  /// In en, this message translates to:
  /// **'No pending items.'**
  String get checklistEmptyPending;

  /// No description provided for @checklistEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed items.'**
  String get checklistEmptyCompleted;

  /// No description provided for @checklistEmptyRejected.
  ///
  /// In en, this message translates to:
  /// **'No rejected items.'**
  String get checklistEmptyRejected;

  /// No description provided for @checklistEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'No checklist items.'**
  String get checklistEmptyAll;

  /// No description provided for @checklistComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get checklistComplete;

  /// No description provided for @checklistInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get checklistInProgress;

  /// No description provided for @checklistItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} items'**
  String checklistItemsCount(int completed, int total);

  /// No description provided for @checklistTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get checklistTabAll;

  /// No description provided for @checklistTabTodo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get checklistTabTodo;

  /// No description provided for @checklistTabDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get checklistTabDone;

  /// No description provided for @checklistTabRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get checklistTabRejected;

  /// No description provided for @checklistResubmitRequired.
  ///
  /// In en, this message translates to:
  /// **'Resubmit Required'**
  String get checklistResubmitRequired;

  /// No description provided for @checklistApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get checklistApproved;

  /// No description provided for @checklistRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get checklistRejected;

  /// No description provided for @checklistReReviewPending.
  ///
  /// In en, this message translates to:
  /// **'Re-review Pending'**
  String get checklistReReviewPending;

  /// No description provided for @checklistTapToView.
  ///
  /// In en, this message translates to:
  /// **'Tap to view description'**
  String get checklistTapToView;

  /// No description provided for @checklistAllReviewed.
  ///
  /// In en, this message translates to:
  /// **'All Reviewed'**
  String get checklistAllReviewed;

  /// No description provided for @checklistReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report Submitted'**
  String get checklistReportSubmitted;

  /// No description provided for @checklistSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get checklistSubmitReport;

  /// No description provided for @checklistBadgeDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get checklistBadgeDaily;

  /// No description provided for @checklistBadgePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get checklistBadgePhoto;

  /// No description provided for @checklistBadgeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get checklistBadgeText;

  /// No description provided for @checklistMaxPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Limit reached'**
  String get checklistMaxPhotosTitle;

  /// No description provided for @checklistMaxPhotosMessage.
  ///
  /// In en, this message translates to:
  /// **'Maximum {max} photos allowed'**
  String checklistMaxPhotosMessage(int max);

  /// No description provided for @checklistMorePhotosAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only {count} more photo(s) allowed (max {max})'**
  String checklistMorePhotosAllowed(int count, int max);

  /// No description provided for @checklistResubmitItem.
  ///
  /// In en, this message translates to:
  /// **'Resubmit Item'**
  String get checklistResubmitItem;

  /// No description provided for @checklistCompleteItem.
  ///
  /// In en, this message translates to:
  /// **'Complete Item'**
  String get checklistCompleteItem;

  /// No description provided for @checklistPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get checklistPhoto;

  /// No description provided for @checklistPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'{current}/{min} min, {max} max'**
  String checklistPhotoCount(int current, int min, int max);

  /// No description provided for @checklistAddShort.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get checklistAddShort;

  /// No description provided for @checklistTapToAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to add photo'**
  String get checklistTapToAddPhoto;

  /// No description provided for @checklistNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get checklistNote;

  /// No description provided for @checklistRequired.
  ///
  /// In en, this message translates to:
  /// **'required'**
  String get checklistRequired;

  /// No description provided for @checklistOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get checklistOptional;

  /// No description provided for @checklistEnterNote.
  ///
  /// In en, this message translates to:
  /// **'Enter note...'**
  String get checklistEnterNote;

  /// No description provided for @checklistOptionalNote.
  ///
  /// In en, this message translates to:
  /// **'Optional note...'**
  String get checklistOptionalNote;

  /// No description provided for @checklistSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get checklistSubmitting;

  /// No description provided for @checklistResubmit.
  ///
  /// In en, this message translates to:
  /// **'Resubmit'**
  String get checklistResubmit;

  /// No description provided for @checklistCompleteAction.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get checklistCompleteAction;

  /// No description provided for @checklistNoAttachments.
  ///
  /// In en, this message translates to:
  /// **'No attachments'**
  String get checklistNoAttachments;

  /// No description provided for @workChecklistTab.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get workChecklistTab;

  /// No description provided for @workTaskTab.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get workTaskTab;

  /// No description provided for @workTabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get workTabToday;

  /// No description provided for @workTabPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get workTabPast;

  /// No description provided for @workEmptyChecklistsToday.
  ///
  /// In en, this message translates to:
  /// **'No checklists assigned today'**
  String get workEmptyChecklistsToday;

  /// No description provided for @workEmptyPastChecklists.
  ///
  /// In en, this message translates to:
  /// **'No past checklists'**
  String get workEmptyPastChecklists;

  /// No description provided for @workEmptyTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks assigned'**
  String get workEmptyTasks;

  /// No description provided for @workEmptyChecklistItems.
  ///
  /// In en, this message translates to:
  /// **'No checklist items'**
  String get workEmptyChecklistItems;

  /// No description provided for @workNoMatchingRecords.
  ///
  /// In en, this message translates to:
  /// **'No matching records'**
  String get workNoMatchingRecords;

  /// No description provided for @workNoTasksForDate.
  ///
  /// In en, this message translates to:
  /// **'No tasks for selected date'**
  String get workNoTasksForDate;

  /// No description provided for @workNoResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String workNoResultsFor(String query);

  /// No description provided for @workUnresolvedCount.
  ///
  /// In en, this message translates to:
  /// **'Unresolved {count}'**
  String workUnresolvedCount(int count);

  /// No description provided for @workPreviousUnresolvedCount.
  ///
  /// In en, this message translates to:
  /// **'Previous unresolved: {count}'**
  String workPreviousUnresolvedCount(int count);

  /// No description provided for @workUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get workUpcoming;

  /// No description provided for @workSearchTasksHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks or stores'**
  String get workSearchTasksHint;

  /// No description provided for @workDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get workDueLabel;

  /// No description provided for @workSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get workSortBy;

  /// No description provided for @workSortDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get workSortDueDate;

  /// No description provided for @workSortPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get workSortPriority;

  /// No description provided for @workSortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get workSortRecent;

  /// No description provided for @workSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get workSortName;

  /// No description provided for @workTasksDoneCount.
  ///
  /// In en, this message translates to:
  /// **'{count} done'**
  String workTasksDoneCount(int count);

  /// No description provided for @workTasksDoneLabel.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get workTasksDoneLabel;

  /// No description provided for @workTasksLeftLabel.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get workTasksLeftLabel;

  /// No description provided for @workFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get workFilterAll;

  /// No description provided for @workFilterDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get workFilterDate;

  /// No description provided for @workCardStatusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get workCardStatusNotStarted;

  /// No description provided for @workCardStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get workCardStatusInProgress;

  /// No description provided for @workCardStatusPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get workCardStatusPendingReview;

  /// No description provided for @workCardStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get workCardStatusDone;

  /// No description provided for @workStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get workStatusApproved;

  /// No description provided for @workStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get workStatusRejected;

  /// No description provided for @workStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get workStatusSubmitted;

  /// No description provided for @workStatusResubmitted.
  ///
  /// In en, this message translates to:
  /// **'Resubmitted'**
  String get workStatusResubmitted;

  /// No description provided for @workStatusPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Re-review'**
  String get workStatusPendingReview;

  /// No description provided for @workStatusRevisionRequested.
  ///
  /// In en, this message translates to:
  /// **'Revision Requested'**
  String get workStatusRevisionRequested;

  /// No description provided for @workStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get workStatusPending;

  /// No description provided for @workStatusNotSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Not Submitted'**
  String get workStatusNotSubmitted;

  /// No description provided for @workStatusActionRequired.
  ///
  /// In en, this message translates to:
  /// **'Action Required'**
  String get workStatusActionRequired;

  /// No description provided for @workCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed {time}'**
  String workCompletedAt(String time);

  /// No description provided for @workSelectWorkDate.
  ///
  /// In en, this message translates to:
  /// **'Select Work Date'**
  String get workSelectWorkDate;

  /// No description provided for @workLegendWorkDay.
  ///
  /// In en, this message translates to:
  /// **'Work day'**
  String get workLegendWorkDay;

  /// No description provided for @workLegendNoWork.
  ///
  /// In en, this message translates to:
  /// **'No work'**
  String get workLegendNoWork;

  /// No description provided for @workAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get workAddPhoto;

  /// No description provided for @workTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get workTakePhoto;

  /// No description provided for @workChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get workChooseFromGallery;

  /// No description provided for @workAddAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get workAddAPhoto;

  /// No description provided for @workCameraButton.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get workCameraButton;

  /// No description provided for @workGalleryButton.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get workGalleryButton;

  /// No description provided for @workPhotoSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get workPhotoSectionTitle;

  /// No description provided for @workPhotoSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please upload verification photo.'**
  String get workPhotoSectionSubtitle;

  /// No description provided for @workNoteSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get workNoteSectionTitle;

  /// No description provided for @workNoteSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please describe the work done.'**
  String get workNoteSectionSubtitle;

  /// No description provided for @workEnterNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your note...'**
  String get workEnterNoteHint;

  /// No description provided for @workVerificationHeader.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get workVerificationHeader;

  /// No description provided for @workAddNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get workAddNoteTitle;

  /// No description provided for @workVerificationNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Enter verification note...'**
  String get workVerificationNoteHint;

  /// No description provided for @workResponseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get workResponseDialogTitle;

  /// No description provided for @workResponseDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your response to the rejection...'**
  String get workResponseDialogHint;

  /// No description provided for @workPhotoUploadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload'**
  String get workPhotoUploadFailedTitle;

  /// No description provided for @workPhotoUploadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Photo upload failed'**
  String get workPhotoUploadFailedMessage;

  /// No description provided for @workAllCompleteCelebration.
  ///
  /// In en, this message translates to:
  /// **'All checklist items complete! Great job!'**
  String get workAllCompleteCelebration;

  /// No description provided for @workDoneButton.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get workDoneButton;

  /// No description provided for @workAwaitingResubmission.
  ///
  /// In en, this message translates to:
  /// **'Awaiting resubmission'**
  String get workAwaitingResubmission;

  /// No description provided for @workTimelineMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get workTimelineMessage;

  /// No description provided for @workTimelinePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get workTimelinePhoto;

  /// No description provided for @workFailedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get workFailedToLoadImage;

  /// No description provided for @workPriorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get workPriorityUrgent;

  /// No description provided for @workPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get workPriorityHigh;

  /// No description provided for @workPriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get workPriorityNormal;

  /// No description provided for @workPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get workPriorityLow;

  /// No description provided for @invAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get invAddTitle;

  /// No description provided for @invAddImageSection.
  ///
  /// In en, this message translates to:
  /// **'Product Image'**
  String get invAddImageSection;

  /// No description provided for @invAddTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get invAddTakePhoto;

  /// No description provided for @invAddChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get invAddChooseGallery;

  /// No description provided for @invAddRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get invAddRemovePhoto;

  /// No description provided for @invAddUploadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload'**
  String get invAddUploadFailedTitle;

  /// No description provided for @invAddUploadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get invAddUploadFailedMessage;

  /// No description provided for @invAddSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search products by name or code...'**
  String get invAddSearchHint;

  /// No description provided for @invAddCreateNewProduct.
  ///
  /// In en, this message translates to:
  /// **'Create New Product'**
  String get invAddCreateNewProduct;

  /// No description provided for @invAddAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already Added'**
  String get invAddAlreadyAdded;

  /// No description provided for @invAddMinQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Min Quantity'**
  String get invAddMinQtyLabel;

  /// No description provided for @invAddInitialQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Initial Quantity'**
  String get invAddInitialQtyLabel;

  /// No description provided for @invAddFrequentAudit.
  ///
  /// In en, this message translates to:
  /// **'Frequent audit'**
  String get invAddFrequentAudit;

  /// No description provided for @invAddAddToStore.
  ///
  /// In en, this message translates to:
  /// **'Add to Store'**
  String get invAddAddToStore;

  /// No description provided for @invAddTapToAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to add photo'**
  String get invAddTapToAddPhoto;

  /// No description provided for @invAddCameraOrGallery.
  ///
  /// In en, this message translates to:
  /// **'Camera or Gallery'**
  String get invAddCameraOrGallery;

  /// No description provided for @invAddNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Name *'**
  String get invAddNameLabel;

  /// No description provided for @invAddNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Whole Milk (1L)'**
  String get invAddNameHint;

  /// No description provided for @invAddNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Product name is required'**
  String get invAddNameRequired;

  /// No description provided for @invAddCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Product Code'**
  String get invAddCodeLabel;

  /// No description provided for @invAddCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-generated if empty'**
  String get invAddCodeHint;

  /// No description provided for @invAddCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get invAddCategoryLabel;

  /// No description provided for @invAddCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Category is required'**
  String get invAddCategoryRequired;

  /// No description provided for @invAddSubcategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get invAddSubcategoryLabel;

  /// No description provided for @invAddSubUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Sub Unit'**
  String get invAddSubUnitLabel;

  /// No description provided for @invAddSubUnitHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if counted only in ea'**
  String get invAddSubUnitHelp;

  /// No description provided for @invAddSubUnitRatioLabel.
  ///
  /// In en, this message translates to:
  /// **'Sub Unit Ratio *'**
  String get invAddSubUnitRatioLabel;

  /// No description provided for @invAddSubUnitRatioHint.
  ///
  /// In en, this message translates to:
  /// **'1 {unit} = ? ea (e.g. 24)'**
  String invAddSubUnitRatioHint(String unit);

  /// No description provided for @invAddRatioInvalid.
  ///
  /// In en, this message translates to:
  /// **'Ratio must be greater than 0'**
  String get invAddRatioInvalid;

  /// No description provided for @invAddDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get invAddDescriptionLabel;

  /// No description provided for @invAddDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Short product description'**
  String get invAddDescriptionHint;

  /// No description provided for @invAddStoreSettingsSection.
  ///
  /// In en, this message translates to:
  /// **'Store Settings'**
  String get invAddStoreSettingsSection;

  /// No description provided for @invAddCreateAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Create & Add to Store'**
  String get invAddCreateAndAdd;

  /// No description provided for @invAddCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get invAddCategoryHint;

  /// No description provided for @invAddAddNew.
  ///
  /// In en, this message translates to:
  /// **'+ Add New'**
  String get invAddAddNew;

  /// No description provided for @invAddNewCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Produce, Snacks...'**
  String get invAddNewCategoryHint;

  /// No description provided for @invAddAlreadyExistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Already exists'**
  String get invAddAlreadyExistsTitle;

  /// No description provided for @invAddAlreadyExistsMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" already exists'**
  String invAddAlreadyExistsMessage(String name);

  /// No description provided for @invAddCreateCategoryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create category'**
  String get invAddCreateCategoryFailedTitle;

  /// No description provided for @invAddCreateCategoryFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to create category'**
  String get invAddCreateCategoryFailedMessage;

  /// No description provided for @invAddSelectCategoryFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a category first'**
  String get invAddSelectCategoryFirst;

  /// No description provided for @invAddNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get invAddNone;

  /// No description provided for @invAddNewSubcategoryHint.
  ///
  /// In en, this message translates to:
  /// **'New subcategory name...'**
  String get invAddNewSubcategoryHint;

  /// No description provided for @invAddCreateSubcategoryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create subcategory'**
  String get invAddCreateSubcategoryFailedTitle;

  /// No description provided for @invAddCreateSubcategoryFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to create subcategory'**
  String get invAddCreateSubcategoryFailedMessage;

  /// No description provided for @invAddSubUnitNone.
  ///
  /// In en, this message translates to:
  /// **'None (ea only)'**
  String get invAddSubUnitNone;

  /// No description provided for @invAddNewSubUnitHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. crate, tray...'**
  String get invAddNewSubUnitHint;

  /// No description provided for @invAddCreateSubUnitFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create sub unit'**
  String get invAddCreateSubUnitFailedTitle;

  /// No description provided for @invAddCreateSubUnitFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to create sub unit'**
  String get invAddCreateSubUnitFailedMessage;

  /// No description provided for @invAddAddedTitle.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get invAddAddedTitle;

  /// No description provided for @invAddAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} added to store'**
  String invAddAddedMessage(String name);

  /// No description provided for @invAddAddFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add product'**
  String get invAddAddFailedTitle;

  /// No description provided for @invAddAddFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to add product'**
  String get invAddAddFailedMessage;

  /// No description provided for @invAddCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get invAddCreatedTitle;

  /// No description provided for @invAddCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} created and added to store'**
  String invAddCreatedMessage(String name);

  /// No description provided for @invAddCreateProductFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create product'**
  String get invAddCreateProductFailedTitle;

  /// No description provided for @invAddCreateProductFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to create product'**
  String get invAddCreateProductFailedMessage;

  /// No description provided for @myPinLabel.
  ///
  /// In en, this message translates to:
  /// **'Clock-in PIN'**
  String get myPinLabel;

  /// No description provided for @myPinEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit PIN'**
  String get myPinEdit;

  /// No description provided for @myPinNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get myPinNotAvailable;

  /// No description provided for @myPinSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save PIN'**
  String get myPinSaveFailed;

  /// No description provided for @warningsHeader.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get warningsHeader;

  /// No description provided for @warningsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get warningsCardTitle;

  /// No description provided for @warningsCardAllSigned.
  ///
  /// In en, this message translates to:
  /// **'All signed'**
  String get warningsCardAllSigned;

  /// No description provided for @warningsCardNeedSignature.
  ///
  /// In en, this message translates to:
  /// **'{count} need your signature'**
  String warningsCardNeedSignature(int count);

  /// No description provided for @warningsBannerNeedSignature.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 warning needs your signature.} other{{count} warnings need your signature.}}'**
  String warningsBannerNeedSignature(int count);

  /// No description provided for @warningsBannerAllSigned.
  ///
  /// In en, this message translates to:
  /// **'All warnings signed. Nothing needs your attention.'**
  String get warningsBannerAllSigned;

  /// No description provided for @warningsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No warnings.'**
  String get warningsEmpty;

  /// No description provided for @warningsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load warnings'**
  String get warningsLoadFailed;

  /// No description provided for @warningsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Warning not found.'**
  String get warningsNotFound;

  /// No description provided for @warningsNewBadge.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get warningsNewBadge;

  /// No description provided for @warningStatusSigned.
  ///
  /// In en, this message translates to:
  /// **'Signed'**
  String get warningStatusSigned;

  /// No description provided for @warningStatusUnsigned.
  ///
  /// In en, this message translates to:
  /// **'Signature required'**
  String get warningStatusUnsigned;

  /// No description provided for @warningOrdinalFirst.
  ///
  /// In en, this message translates to:
  /// **'First Warning'**
  String get warningOrdinalFirst;

  /// No description provided for @warningOrdinalSecond.
  ///
  /// In en, this message translates to:
  /// **'Second Warning'**
  String get warningOrdinalSecond;

  /// No description provided for @warningOrdinalFinal.
  ///
  /// In en, this message translates to:
  /// **'Final Warning'**
  String get warningOrdinalFinal;

  /// No description provided for @warningOrdinalN.
  ///
  /// In en, this message translates to:
  /// **'Warning #{n}'**
  String warningOrdinalN(int n);

  /// No description provided for @warningDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Warning {refNo}'**
  String warningDetailTitle(String refNo);

  /// No description provided for @warningIssuedBy.
  ///
  /// In en, this message translates to:
  /// **'Issued by {name}'**
  String warningIssuedBy(String name);

  /// No description provided for @warningReadOn.
  ///
  /// In en, this message translates to:
  /// **'Read on {date}'**
  String warningReadOn(String date);

  /// No description provided for @warningSectionReasons.
  ///
  /// In en, this message translates to:
  /// **'Reasons'**
  String get warningSectionReasons;

  /// No description provided for @warningSectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get warningSectionDetails;

  /// No description provided for @warningSectionCorrective.
  ///
  /// In en, this message translates to:
  /// **'Corrective action'**
  String get warningSectionCorrective;

  /// No description provided for @warningSectionFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get warningSectionFollowUp;

  /// No description provided for @warningDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get warningDeadline;

  /// No description provided for @warningSignedOn.
  ///
  /// In en, this message translates to:
  /// **'Signed on {date}'**
  String warningSignedOn(String date);

  /// No description provided for @warningManagerSignedOn.
  ///
  /// In en, this message translates to:
  /// **'Manager signed on {date}'**
  String warningManagerSignedOn(String date);

  /// No description provided for @warningManagerAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting manager signature'**
  String get warningManagerAwaiting;

  /// No description provided for @warningSignatureRequired.
  ///
  /// In en, this message translates to:
  /// **'Your signature is required'**
  String get warningSignatureRequired;

  /// No description provided for @warningEmployeeSignature.
  ///
  /// In en, this message translates to:
  /// **'Employee signature'**
  String get warningEmployeeSignature;

  /// No description provided for @warningActionSign.
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get warningActionSign;

  /// No description provided for @warningViewDocument.
  ///
  /// In en, this message translates to:
  /// **'View official document'**
  String get warningViewDocument;

  /// No description provided for @warningViewDocumentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Employee Warning Notice Form · PDF'**
  String get warningViewDocumentSubtitle;

  /// No description provided for @warningDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'Document · {refNo}'**
  String warningDocumentTitle(String refNo);

  /// No description provided for @warningSignSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign this warning'**
  String get warningSignSheetTitle;

  /// No description provided for @warningSignSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your signature confirms you have read and received this warning.'**
  String get warningSignSheetSubtitle;

  /// No description provided for @warningSignDrawNew.
  ///
  /// In en, this message translates to:
  /// **'Draw new'**
  String get warningSignDrawNew;

  /// No description provided for @warningSignUseSaved.
  ///
  /// In en, this message translates to:
  /// **'Use saved signature'**
  String get warningSignUseSaved;

  /// No description provided for @warningSignDrawHint.
  ///
  /// In en, this message translates to:
  /// **'Draw your signature here'**
  String get warningSignDrawHint;

  /// No description provided for @warningSignNoSaved.
  ///
  /// In en, this message translates to:
  /// **'No saved signature yet. Draw one below.'**
  String get warningSignNoSaved;

  /// No description provided for @warningSignSigningAs.
  ///
  /// In en, this message translates to:
  /// **'Signing as {name}'**
  String warningSignSigningAs(String name);

  /// No description provided for @warningSignSaveAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Save as my default signature'**
  String get warningSignSaveAsDefault;

  /// No description provided for @warningSignClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get warningSignClear;

  /// No description provided for @warningSignConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm signature'**
  String get warningSignConfirm;

  /// No description provided for @warningSignFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign. Please try again.'**
  String get warningSignFailed;

  /// No description provided for @warningStatusSignInPerson.
  ///
  /// In en, this message translates to:
  /// **'Sign in person'**
  String get warningStatusSignInPerson;

  /// No description provided for @warningViewSignedDocument.
  ///
  /// In en, this message translates to:
  /// **'View signed document'**
  String get warningViewSignedDocument;

  /// No description provided for @warningSignedDocOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the signed document. Please try again.'**
  String get warningSignedDocOpenFailed;

  /// No description provided for @warningWetSignInPersonTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign this warning in person'**
  String get warningWetSignInPersonTitle;

  /// No description provided for @warningWetSignInPersonBody.
  ///
  /// In en, this message translates to:
  /// **'This warning must be signed in person — see your manager. There\'s nothing to sign in the app.'**
  String get warningWetSignInPersonBody;

  /// No description provided for @warningWetDocOnFile.
  ///
  /// In en, this message translates to:
  /// **'Signed document on file'**
  String get warningWetDocOnFile;

  /// No description provided for @warningWetDocAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting signed document'**
  String get warningWetDocAwaiting;

  /// No description provided for @warningDocEmployeeName.
  ///
  /// In en, this message translates to:
  /// **'Employee Name'**
  String get warningDocEmployeeName;

  /// No description provided for @warningDocEmpId.
  ///
  /// In en, this message translates to:
  /// **'Emp ID'**
  String get warningDocEmpId;

  /// No description provided for @warningDocManagerName.
  ///
  /// In en, this message translates to:
  /// **'Manager Name'**
  String get warningDocManagerName;

  /// No description provided for @warningDocStoreBrand.
  ///
  /// In en, this message translates to:
  /// **'Store / Brand'**
  String get warningDocStoreBrand;

  /// No description provided for @warningDocDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get warningDocDate;

  /// No description provided for @warningDocWarningType.
  ///
  /// In en, this message translates to:
  /// **'Warning Type'**
  String get warningDocWarningType;

  /// No description provided for @warningDocReasonsTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Behavior / actions found unsatisfactory — reasons'**
  String get warningDocReasonsTitle;

  /// No description provided for @warningDocDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Details of unsatisfactory behavior / actions'**
  String get warningDocDetailsLabel;

  /// No description provided for @warningDocCorrectiveTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Corrective action required'**
  String get warningDocCorrectiveTitle;

  /// No description provided for @warningDocDeadline.
  ///
  /// In en, this message translates to:
  /// **'3. Deadline'**
  String get warningDocDeadline;

  /// No description provided for @warningDocFollowUpDate.
  ///
  /// In en, this message translates to:
  /// **'4. Follow-up date'**
  String get warningDocFollowUpDate;

  /// No description provided for @warningDocFollowUpTime.
  ///
  /// In en, this message translates to:
  /// **'Follow-up time'**
  String get warningDocFollowUpTime;

  /// No description provided for @warningDocEmployeeSignature.
  ///
  /// In en, this message translates to:
  /// **'Employee Signature'**
  String get warningDocEmployeeSignature;

  /// No description provided for @warningDocManagerSignature.
  ///
  /// In en, this message translates to:
  /// **'Manager Signature'**
  String get warningDocManagerSignature;

  /// No description provided for @warningDocCc.
  ///
  /// In en, this message translates to:
  /// **'cc'**
  String get warningDocCc;

  /// No description provided for @warningDocCcValue.
  ///
  /// In en, this message translates to:
  /// **'Employee / Manager / Human Resources / Personnel File'**
  String get warningDocCcValue;

  /// No description provided for @warningDocNone.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get warningDocNone;

  /// No description provided for @changelogTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get changelogTitle;

  /// No description provided for @changelogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No updates yet'**
  String get changelogEmpty;

  /// No description provided for @changelogLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load updates'**
  String get changelogLoadError;

  /// No description provided for @changelogRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get changelogRetry;
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
