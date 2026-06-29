// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Staff App';

  @override
  String get actionLogin => 'Log In';

  @override
  String get actionRegister => 'Register';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionNext => 'Next';

  @override
  String get actionBack => 'Back';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionClose => 'Close';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionContinue => 'Continue';

  @override
  String get loginEmailOrUsernameHint => 'ID';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginFindUsername => 'Find ID';

  @override
  String get loginForgotPassword => 'Forgot Password?';

  @override
  String get loginNoAccountPrompt => 'Don\'t have an account? ';

  @override
  String get loginRegisterAction => 'Register';

  @override
  String get loginFailedTitle => 'Login Failed';

  @override
  String get loginFailedDefault => 'Login failed';

  @override
  String get loginAlreadyHaveAccountPrompt => 'Already have an account? ';

  @override
  String get companyCodeTitle => 'Enter Company Code';

  @override
  String get companyCodeSubtitle => 'Ask your manager for the company code';

  @override
  String get companyCodeHint => 'Company Code';

  @override
  String get commonHeadsUp => 'Heads up';

  @override
  String get errorServerLater => 'Server error. Please try again later.';

  @override
  String get errorServerNotResponding =>
      'Server not responding. Please try again.';

  @override
  String get errorNoInternet => 'No internet connection.';

  @override
  String get actionLogout => 'Log out';

  @override
  String get actionResend => 'Resend';

  @override
  String get actionSendCode => 'Send Code';

  @override
  String get actionVerify => 'Verify';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldVerificationCode => 'Verification Code';

  @override
  String get hintEmailExample => 'example@email.com';

  @override
  String get hint6DigitCode => '6-digit code';

  @override
  String get emailVerifyHeader => 'Email Verification';

  @override
  String get emailVerifyHeading => 'Verify Your Email';

  @override
  String get emailVerifySubheading =>
      'To continue using HTM,\nplease verify your email address.';

  @override
  String get emailVerifyMissingEmail => 'Please enter your email.';

  @override
  String get emailVerifyCodeSentTitle => 'Code Sent';

  @override
  String get emailVerifyCodeSentMessage => 'Verification code sent.';

  @override
  String get emailVerifyCodeSendErrorTitle => 'Couldn\'t send code';

  @override
  String get emailVerifyCodeSendErrorDefault => 'Failed to send code.';

  @override
  String get emailVerifyMissing6Digit => 'Please enter the 6-digit code.';

  @override
  String get emailVerifyFailedTitle => 'Verification Failed';

  @override
  String get emailVerifyFailedDefault => 'Verification failed.';

  @override
  String get emailVerifySuccessTitle => 'Email Verified!';

  @override
  String get emailVerifySuccessMessage =>
      'Your email has been verified successfully.\nYou can now use all features.';

  @override
  String get emailVerifyGoHome => 'Go to Home';

  @override
  String get emailVerifyChangeEmail => 'Change Email';

  @override
  String get emailVerifyChangeEmailHint =>
      'You can change your email address if needed.';

  @override
  String emailVerifyTimerRemaining(String time) {
    return '⏱ $time remaining';
  }

  @override
  String get actionResendCode => 'Resend Code';

  @override
  String get actionGoToLogin => 'Go to Login';

  @override
  String get actionResetPassword => 'Reset Password';

  @override
  String get codeNotReceivedPrompt => 'Didn\'t receive the code?';

  @override
  String get findUsernameHeader => 'Find ID';

  @override
  String get findUsernameHeading => 'Find Your Username';

  @override
  String get findUsernameSubheading =>
      'Enter the email address associated with your account.';

  @override
  String get findUsernameHelp =>
      'We\'ll look up your account and show a masked version of your username for verification.';

  @override
  String get findUsernameNotFoundTitle => 'Account not found';

  @override
  String get findUsernameNotFoundDefault => 'No account found with this email.';

  @override
  String get findUsernameStep2Title => 'Is this your account?';

  @override
  String get findUsernameStep2Subtitle =>
      'We found an account with the email you provided.';

  @override
  String get findUsernameStep2Hint =>
      'To see your full username, verify your email.';

  @override
  String get findUsernameLabel => 'Username';

  @override
  String get findUsernameTryDifferent => 'Try Different Email';

  @override
  String get findUsernameSuccessTitle => 'Username Found';

  @override
  String get findUsernameSuccessMessage => 'Your username has been verified.';

  @override
  String get findUsernameYourUsername => 'Your Username';

  @override
  String get findUsernameUsernameHint =>
      'Use this username to log in to your account.';

  @override
  String get actionSendVerificationCode => 'Send Verification Code';

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldNewPassword => 'New Password';

  @override
  String get fieldConfirmPassword => 'Confirm Password';

  @override
  String get hintEnterUsername => 'Enter your username';

  @override
  String get hintEnterNewPassword => 'Enter new password';

  @override
  String get hintReenterNewPassword => 'Re-enter new password';

  @override
  String get resetHeader => 'Reset Password';

  @override
  String get resetHeading => 'Reset Your Password';

  @override
  String get resetSubheading =>
      'Enter your username and email to verify your identity.';

  @override
  String get resetMissingUsernameEmail =>
      'Please enter your username and email.';

  @override
  String get resetNoAccountDefault => 'No account found.';

  @override
  String get resetCodeSentInfo =>
      'A verification code will be sent to your email address.';

  @override
  String get resetCodeResentTitle => 'Code Resent';

  @override
  String get resetCodeResentMessage => 'Verification code resent.';

  @override
  String get resetCodeResendErrorTitle => 'Couldn\'t resend code';

  @override
  String get resetCodeResendErrorDefault => 'Failed to resend code.';

  @override
  String get resetEnterCodeHeading => 'Enter Verification Code';

  @override
  String resetCodeSentTo(String email) {
    return 'We sent a 6-digit code to $email';
  }

  @override
  String get resetWrongEmail => 'Wrong email? Go back';

  @override
  String get resetSetNewHeading => 'Set New Password';

  @override
  String get resetSetNewSubheading => 'Create a new password for your account.';

  @override
  String get resetMissingFields => 'Please fill in all fields.';

  @override
  String get resetPasswordsMismatchTitle => 'Passwords do not match';

  @override
  String get resetPasswordsMismatchMessage => 'Passwords do not match.';

  @override
  String get resetFailedTitle => 'Couldn\'t reset password';

  @override
  String get resetFailedDefault => 'Failed to reset password.';

  @override
  String get resetSuccessTitle => 'Password Changed';

  @override
  String get resetSuccessMessage =>
      'Your password has been successfully reset.\nYou can now log in with your new password.';

  @override
  String get resetSuccessDevicesNote =>
      'All other devices have been logged out for security.';

  @override
  String get actionGetStarted => 'Get Started';

  @override
  String get fieldFullName => 'Full Name';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldPreferredLanguage => 'Preferred Language';

  @override
  String get hintFullName => 'Enter your full name';

  @override
  String get hintChooseUsername => 'Choose a username';

  @override
  String get hintEnterPassword => 'Enter password';

  @override
  String get hintReenterPassword => 'Re-enter your password';

  @override
  String get passwordsMismatchInline => 'Passwords do not match';

  @override
  String get registerTermsHeading => 'Review the Terms';

  @override
  String get registerTermsSubheading =>
      'Please agree to the terms to use the service.';

  @override
  String get registerTermsBody =>
      'Terms of Service\n\nThese terms govern your use of the HTM service. Please read them carefully before using the service.\n\nArticle 1 (Purpose)\nThese terms define the rights, obligations, and responsibilities between the company and its members regarding the use of the service.\n\nArticle 2 (Definitions)\nThe definitions of terms used in these terms are as follows.';

  @override
  String get registerAgreeAll => 'Agree to all terms';

  @override
  String get registerAgreeTos => 'I agree to the Terms of Service. (Required)';

  @override
  String get registerAgreePrivacy =>
      'I agree to the Privacy Policy. (Required)';

  @override
  String get registerAgreeMarketing =>
      'I agree to receive marketing information. (Optional)';

  @override
  String get registerTermsRequired => 'Please agree to all required terms.';

  @override
  String get registerStoresHeading => 'Select Your Stores';

  @override
  String get registerStoresSubheading =>
      'Choose the stores you work at.\nYou can select multiple stores.';

  @override
  String registerStoresSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stores selected',
      one: '1 store selected',
    );
    return '$_temp0';
  }

  @override
  String get registerStoresSearchHint => 'Search stores...';

  @override
  String registerStoresNoSearchResult(String query) {
    return 'No stores found for \"$query\".';
  }

  @override
  String get registerStoresEmpty =>
      'No stores available.\nPlease contact your manager.';

  @override
  String get registerStoresLoadFailed => 'Failed to load stores.';

  @override
  String get registerSelectStoreRequired => 'Please select at least one store.';

  @override
  String get registerInfoHeading => 'Tell us about yourself';

  @override
  String get registerInfoSubheading =>
      'Enter your basic information to get started.';

  @override
  String get registerEnterName => 'Please enter your name.';

  @override
  String get registerEnterUsername => 'Please enter a username.';

  @override
  String get registerEnterPassword => 'Please enter a password.';

  @override
  String get registerEmailSubheading =>
      'We\'ll send a verification code to your email.';

  @override
  String get registerEnterValidEmail => 'Please enter a valid email address.';

  @override
  String get registerCodeSendFailed => 'Failed to send code. Please try again.';

  @override
  String get registerEmailVerifiedTitle => 'Email Verified';

  @override
  String get registerEmailVerifiedMessage =>
      'Your email has been verified successfully.';

  @override
  String get registerEmailVerifiedBadge => '✓ Email verified';

  @override
  String get registerCodeExpiresHint =>
      'Code expires in 5 minutes after sending.';

  @override
  String get registerVerifyEmailFirst => 'Please verify your email first.';

  @override
  String get registerFailedTitle => 'Registration Failed';

  @override
  String get registerFailedDefault => 'Registration failed';

  @override
  String registerWelcomeName(String name) {
    return 'Welcome, $name!';
  }

  @override
  String get registerCompleteTitle => 'Registration Complete';

  @override
  String get registerCompleteMessage => 'Start using the service right away.';

  @override
  String get registerStepTerms => 'Terms';

  @override
  String get registerStepStore => 'Store';

  @override
  String get registerStepInfo => 'Info';

  @override
  String get registerStepEmail => 'Email';

  @override
  String get registerStepDone => 'Done';

  @override
  String get scheduleViewWeekly => 'Weekly';

  @override
  String get scheduleViewMonthly => 'Monthly';

  @override
  String get scheduleToday => 'Today';

  @override
  String get scheduleThisWeek => 'This week';

  @override
  String scheduleDaysHours(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0 · ${hours}h';
  }

  @override
  String scheduleShiftsHours(int shifts, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      shifts,
      locale: localeName,
      other: '$shifts shifts',
      one: '1 shift',
    );
    return '$_temp0 · ${hours}h';
  }

  @override
  String get scheduleNoShifts => 'No shifts';

  @override
  String scheduleBadgePending(int count) {
    return 'Pending $count';
  }

  @override
  String scheduleBadgeConfirmed(int count) {
    return 'Confirmed $count';
  }

  @override
  String scheduleBadgeRejected(int count) {
    return 'Rejected $count';
  }

  @override
  String get scheduleStatusConfirmed => 'Confirmed';

  @override
  String get scheduleStatusRejected => 'Rejected';

  @override
  String get scheduleStatusModified => 'Modified';

  @override
  String get scheduleStatusSubmitted => 'Submitted';

  @override
  String get scheduleStatusPending => 'Pending';

  @override
  String get scheduleConfirmedSection => 'Confirmed Schedule';

  @override
  String scheduleRequestSection(String label) {
    return '$label Schedule';
  }

  @override
  String get scheduleStoreLabel => 'Store';

  @override
  String get scheduleWorkRoleLabel => 'Work Role';

  @override
  String get scheduleTimeLabel => 'Time';

  @override
  String scheduleNetWork(String duration) {
    return 'Net work: $duration';
  }

  @override
  String get scheduleUpcomingChecklist => 'Upcoming Checklist';

  @override
  String get scheduleViewChecklist => 'View Checklist';

  @override
  String get scheduleChangedByManager => 'Changed by manager';

  @override
  String get scheduleEmpty => 'No schedule';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get ojtTitle => 'OJT Training';

  @override
  String get ojtSubtitle =>
      'On-the-job training modules will be available here.';

  @override
  String get noticesHeader => 'Notices';

  @override
  String get noticesEmpty => 'No notices';

  @override
  String get tasksHeader => 'Tasks';

  @override
  String get tasksFilterLabel => 'Filter: ';

  @override
  String get tasksFilterAll => 'All';

  @override
  String get tasksFilterPending => 'Pending';

  @override
  String get tasksFilterInProgress => 'In Progress';

  @override
  String get tasksFilterCompleted => 'Completed';

  @override
  String get tasksEmpty => 'No tasks';

  @override
  String tasksDuePrefix(String date) {
    return 'Due: $date';
  }

  @override
  String get commonSavedTitle => 'Saved';

  @override
  String get commonSaveFailedTitle => 'Couldn\'t save';

  @override
  String get settingsHeader => 'Settings';

  @override
  String get settingsAlertSettings => 'Alert Settings';

  @override
  String get settingsEditUsername => 'Edit Username';

  @override
  String get settingsEnterNewUsername => 'Enter new username';

  @override
  String get settingsChangePassword => 'Change Password';

  @override
  String get settingsLanguageSaved => 'Language preference saved.';

  @override
  String get settingsLanguageFailed => 'Failed to update language';

  @override
  String get settingsUsernameSaved => 'Username updated.';

  @override
  String get settingsUsernameFailed => 'Failed to update username';

  @override
  String get fieldCurrentPassword => 'Current Password';

  @override
  String get fieldConfirmNewPassword => 'Confirm New Password';

  @override
  String get hintEnterCurrentPassword => 'Enter current password';

  @override
  String get changePasswordHeader => 'Change Password';

  @override
  String get changePasswordHeading => 'Change Password';

  @override
  String get changePasswordSubheading =>
      'Enter your current password and set a new one.';

  @override
  String get changePasswordDevicesNote =>
      'After changing your password, all other devices will be logged out.';

  @override
  String get changePasswordSuccessTitle => 'Password Changed';

  @override
  String get changePasswordSuccessMessage => 'Password changed successfully.';

  @override
  String get changePasswordFailedTitle => 'Couldn\'t change password';

  @override
  String get changePasswordFailedDefault => 'Failed to change password.';

  @override
  String get alertsHeader => 'Alerts';

  @override
  String alertsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
    );
    return '$_temp0';
  }

  @override
  String get alertsMarkAllRead => 'Mark all read';

  @override
  String get alertsLoadFailed => 'Failed to load alerts';

  @override
  String get alertsEmpty => 'No alerts yet';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinAgo(int n) {
    return '${n}m ago';
  }

  @override
  String timeHourAgo(int n) {
    return '${n}h ago';
  }

  @override
  String get timeYesterday => 'yesterday';

  @override
  String timeDayAgo(int n) {
    return '${n}d ago';
  }

  @override
  String timeWeekAgo(int n) {
    return '${n}w ago';
  }

  @override
  String get dailyReportsHeader => 'Daily Reports';

  @override
  String get dailyReportsEmpty => 'No reports yet';

  @override
  String get dailyReportsFilterDraft => 'Draft';

  @override
  String get dailyReportsFilterSubmitted => 'Submitted';

  @override
  String get dailyReportsFilterReviewed => 'Reviewed';

  @override
  String get inventoryHeader => 'Inventory';

  @override
  String get inventoryStoresLoadFailed => 'Failed to load stores';

  @override
  String get inventoryNoStoresTitle => 'No stores assigned';

  @override
  String get inventoryNoStoresMessage =>
      'You are not assigned to any stores yet.';

  @override
  String inventoryStockItems(int count) {
    return '$count items';
  }

  @override
  String inventoryStockLow(int count) {
    return '$count low';
  }

  @override
  String inventoryStockOut(int count) {
    return '$count out';
  }

  @override
  String get actionReset => 'Reset';

  @override
  String get commonConnectionError =>
      'Please check your connection and try again.';

  @override
  String get alertSettingsHeader => 'Alert Settings';

  @override
  String get alertSettingsLoadFailed => 'Couldn\'t load alert settings.';

  @override
  String get alertSettingsSaved => 'Alert preferences updated.';

  @override
  String get alertSettingsResetTitle => 'Reset to default?';

  @override
  String get alertSettingsResetMessage =>
      'All categories will be turned back on. You can adjust them again later.';

  @override
  String get alertSettingsResetButton => 'Reset to default';

  @override
  String get alertSettingsIntro =>
      'Choose which categories you receive in the app and via email. A dash (—) means email isn\'t available for that category.';

  @override
  String get alertSettingsHeaderInApp => 'IN-APP';

  @override
  String get alertSettingsHeaderEmail => 'EMAIL';

  @override
  String get actionChange => 'Change';

  @override
  String get commonStaff => 'Staff';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeFirstNameSuffix => '.';

  @override
  String get homePasswordBannerMessage =>
      'Your password was recently reset. We recommend changing it to a new password.';

  @override
  String get homeTodayOverview => 'Today\'s Overview';

  @override
  String get homeStatChecklist => 'Checklist';

  @override
  String get homeStatTasks => 'Tasks';

  @override
  String get homeStatDueToday => 'Due Today';

  @override
  String get homeQuickNotices => 'Notices';

  @override
  String get homeQuickOjt => 'OJT';

  @override
  String get homeQuickDailyReports => 'Daily Reports';

  @override
  String get homeQuickInventory => 'Inventory';

  @override
  String get homeVoiceHint => 'Share your voice!';

  @override
  String get homeVoiceSubmittedTitle => 'Submitted';

  @override
  String get homeVoiceSubmittedMessage => 'Thanks for sharing!';

  @override
  String get homeVoiceFailedTitle => 'Couldn\'t submit';

  @override
  String get homeVoiceFailedMessage => 'Failed to submit. Please try again.';

  @override
  String get homeVoiceCategoryIdea => '💡 Idea';

  @override
  String get homeVoiceCategoryFacility => '🔧 Facility';

  @override
  String get homeVoiceCategorySafety => '⚠️ Safety';

  @override
  String get homeVoiceCategoryHr => '👤 HR';

  @override
  String get homeVoiceCategoryOther => '📋 Other';

  @override
  String get homeImportantNotice => 'IMPORTANT NOTICE';

  @override
  String get homeViewDetails => 'View details';

  @override
  String get homeScheduleHeader => 'This Week\'s Schedule';

  @override
  String get homeViewAll => 'View all →';

  @override
  String get homeNextShift => 'NEXT SHIFT';

  @override
  String get homeTomorrow => 'Tomorrow';

  @override
  String get homeStatChanged => 'Changed';

  @override
  String homeRejectedRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rejected requests',
      one: '1 rejected request',
    );
    return '$_temp0';
  }

  @override
  String get homeResubmit => 'Resubmit →';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionUpload => 'Upload';

  @override
  String get actionLogoutConfirm => 'Logout';

  @override
  String get commonComingSoonTitle => 'Coming Soon';

  @override
  String get myPageHeader => 'My Page';

  @override
  String get myTakePhoto => 'Take Photo';

  @override
  String get myChooseGallery => 'Choose from Gallery';

  @override
  String get myRemovePhoto => 'Remove Photo';

  @override
  String get myChangePhoto => 'Change Profile Photo';

  @override
  String get myUploadDocument => 'Upload Document';

  @override
  String get myReplaceDocument => 'Replace Document';

  @override
  String myUploadedAt(String date) {
    return 'Uploaded $date';
  }

  @override
  String get myDocumentsHeader => 'Documents';

  @override
  String get myDocumentsSubtitle =>
      'Upload required documents for employment verification';

  @override
  String get myDocumentsUnderDev => 'This feature is under development';

  @override
  String get myLogoutConfirmTitle => 'Logout';

  @override
  String get myLogoutConfirmMessage => 'Are you sure you want to log out?';

  @override
  String get myDocFoodHandlerTitle => 'Food Handler Card';

  @override
  String get myDocFoodHandlerSubtitle => 'Required food safety certification';

  @override
  String get myDocSsnTitle => 'SSN / Work Authorization';

  @override
  String get myDocSsnSubtitle => 'Social Security Number or Work Permit';

  @override
  String get myDocIdTitle => 'Government ID';

  @override
  String get myDocIdSubtitle => 'Driver License / State ID / Passport';

  @override
  String get myDocI9Title => 'I-9 Form';

  @override
  String get myDocI9Subtitle => 'Employment Eligibility Verification';

  @override
  String get myDocW4Title => 'W-4 Form';

  @override
  String get myDocW4Subtitle => 'Employee\'s Withholding Certificate';

  @override
  String get noticeDetailHeader => 'Notice';

  @override
  String get noticeNotFound => 'Notice not found';

  @override
  String get noticeAcknowledgedTitle => 'Acknowledged';

  @override
  String get noticeAcknowledgedMessage => 'Acknowledged';

  @override
  String noticeCommentsCount(int count) {
    return 'Comments ($count)';
  }

  @override
  String get noticeNoComments => 'No comments yet';

  @override
  String get noticeFirstComment => 'Be the first to leave a comment';

  @override
  String get noticeCommentHint => 'Write a comment...';

  @override
  String get noticeMarkAsRead => 'Mark as read';

  @override
  String get noticeAcknowledgedButton => 'Acknowledged';

  @override
  String get fieldDescription => 'Description';

  @override
  String get taskDetailHeader => 'Task Detail';

  @override
  String get taskNotFound => 'Task not found';

  @override
  String get taskMarkComplete => 'Mark Complete';

  @override
  String get taskCompletedTitle => 'Completed';

  @override
  String get taskCompletedMessage => 'Task marked as complete';

  @override
  String taskCompletedByLine(String name, String time) {
    return 'Completed by $name · $time';
  }

  @override
  String get taskStartTimeLabel => 'Start time';

  @override
  String get taskDueDateLabel => 'Due date';

  @override
  String get taskAssignedToLabel => 'Assigned to';

  @override
  String get taskCreatedByLabel => 'Created by';

  @override
  String get taskCreatedAtLabel => 'Created at';

  @override
  String taskAssigneesCount(int count) {
    return 'Assignees ($count)';
  }

  @override
  String taskDoneAt(String time) {
    return 'Done $time';
  }

  @override
  String get drHeaderNew => 'New Report';

  @override
  String get drHeaderDetail => 'Report Detail';

  @override
  String get drNotFound => 'Report not found';

  @override
  String get drSelectStorePrompt => 'Please select a store';

  @override
  String get drTemplateLoadFailedTitle => 'Couldn\'t load template';

  @override
  String get drTemplateLoadFailedMessage => 'Failed to load template';

  @override
  String get drCreateFailedTitle => 'Couldn\'t create report';

  @override
  String get drCreateFailedMessage => 'Failed to create report';

  @override
  String get drDraftSaved => 'Draft saved';

  @override
  String get drSaveFailed => 'Failed to save';

  @override
  String get drSubmittedTitle => 'Submitted';

  @override
  String get drSubmittedMessage => 'Report submitted';

  @override
  String get drSubmitFailedTitle => 'Couldn\'t submit';

  @override
  String get drSubmitFailedMessage => 'Failed to submit';

  @override
  String get drDeleteTitle => 'Delete Draft';

  @override
  String get drDeleteMessage => 'Are you sure you want to delete this draft?';

  @override
  String get drDeletedTitle => 'Deleted';

  @override
  String get drDeletedMessage => 'Draft deleted';

  @override
  String get drDeleteFailedTitle => 'Couldn\'t delete';

  @override
  String get drDeleteFailedMessage => 'Failed to delete';

  @override
  String get drExistsTitle => 'Report Exists';

  @override
  String get drExistsMessage =>
      'A report already exists for this store/date/period.\nWould you like to view the existing report?';

  @override
  String get drExistsGo => 'Go to Report';

  @override
  String get drSaveDraftButton => 'Save Draft';

  @override
  String get drStoreLabel => 'Store';

  @override
  String get drSelectStoreHint => 'Select store';

  @override
  String get drDateLabel => 'Date';

  @override
  String get drPeriodLabel => 'Period';

  @override
  String get drPeriodLunch => 'Lunch';

  @override
  String get drPeriodDinner => 'Dinner';

  @override
  String get drStartWriting => 'Start Writing';

  @override
  String drSubmittedAt(String time) {
    return 'Submitted $time';
  }

  @override
  String get drContentHeader => 'Report Content';

  @override
  String get drEnterContent => 'Enter content...';

  @override
  String get drOptional => '  (Optional)';

  @override
  String get drNoContent => '(No content)';

  @override
  String get drFieldRequired => 'This field is required';

  @override
  String drDeadline(String time) {
    return 'Due $time';
  }

  @override
  String get drOverdue => 'Overdue';

  @override
  String get drLate => 'Late';

  @override
  String drReviewedBy(String name) {
    return 'Reviewed by $name';
  }

  @override
  String drReviewedByAt(String name, String time) {
    return 'Reviewed by $name · $time';
  }

  @override
  String get drAcknowledge => 'Acknowledge';

  @override
  String get drAcknowledged => 'Acknowledged';

  @override
  String drAcknowledgedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count acknowledgements',
      one: '1 acknowledgement',
      zero: 'No acknowledgements',
    );
    return '$_temp0';
  }

  @override
  String get drAcknowledgedTitle => 'Acknowledged';

  @override
  String get drAcknowledgedMessage => 'You confirmed this report as read';

  @override
  String get drAcknowledgeFailedTitle => 'Couldn\'t acknowledge';

  @override
  String get drAcknowledgeFailedMessage => 'Failed to acknowledge the report';

  @override
  String get actionView => 'View';

  @override
  String get invChangeStore => 'Change Store';

  @override
  String get invInStock => 'In Stock';

  @override
  String get invLowStock => 'Low Stock';

  @override
  String get invOutOfStock => 'Out';

  @override
  String get invActionView => 'View Inventory';

  @override
  String get invActionAudit => 'Audit';

  @override
  String get invActionStockIn => 'Stock In';

  @override
  String get invActionStockOut => 'Stock Out';

  @override
  String invItemsNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items need attention',
      one: '1 item needs attention',
    );
    return '$_temp0';
  }

  @override
  String get actionAdjust => 'Adjust';

  @override
  String get invSearchHint => 'Search products...';

  @override
  String get invFilterAll => 'All';

  @override
  String get invFilterLowStock => 'Low Stock';

  @override
  String get invFilterFrequent => 'Frequent Only';

  @override
  String get invEmpty => 'No products in inventory';

  @override
  String get invNoMatch => 'No matching products';

  @override
  String get invStockInRecorded => 'Stock in recorded';

  @override
  String get invStockOutRecorded => 'Stock out recorded';

  @override
  String get invSaveFailed => 'Failed to record. Please try again.';

  @override
  String get invAdjustedTitle => 'Adjusted';

  @override
  String get invAdjustedMessage => 'Quantity adjusted';

  @override
  String get invAdjustFailed => 'Failed to adjust. Please try again.';

  @override
  String get invStatusLow => 'Low';

  @override
  String get invStatusOut => 'Out';

  @override
  String get invStatusOk => 'OK';

  @override
  String get invNeverAudited => 'Never audited';

  @override
  String get invFrequent => 'Frequent';

  @override
  String invLastAudited(String label) {
    return 'Last: $label';
  }

  @override
  String get invCurrentStock => 'Current Stock';

  @override
  String get invStatusOutOfStock => 'Out of Stock';

  @override
  String get invStatusInStock => 'In Stock';

  @override
  String get invSvOnlyMessage =>
      'Only SV and above can perform stock operations.';

  @override
  String get invNegativeStockWarning => 'Will result in negative stock';

  @override
  String get invReasonOptional => 'Reason (optional)';

  @override
  String get invAdjustTitle => 'Adjust Quantity';

  @override
  String invAdjustHint(int qty) {
    return 'Set new quantity (current: $qty ea)';
  }

  @override
  String get invNewQuantityLabel => 'New quantity (ea)';

  @override
  String get invStockInTitle => 'Stock In';

  @override
  String get invStockOutTitle => 'Stock Out';

  @override
  String get actionDone => 'Done';

  @override
  String get actionExit => 'Exit';

  @override
  String get auditHeader => 'Audit';

  @override
  String get auditLoading => 'Loading inventory...';

  @override
  String get auditEmpty => 'No inventory items';

  @override
  String get auditModifiedOnly => 'Modified only';

  @override
  String get auditSectionFrequent => 'Frequent';

  @override
  String get auditSectionAll => 'All Items';

  @override
  String get auditNoModified => 'No modified items yet';

  @override
  String get auditNoItems => 'No items in audit';

  @override
  String get auditCompleteButton => 'Complete Audit';

  @override
  String get auditCompleteTitle => 'Complete Audit';

  @override
  String get auditCompleteMessage =>
      'This will apply all quantity adjustments. Are you sure?';

  @override
  String get auditCompleteConfirm => 'Complete';

  @override
  String get auditCompletedTitle => 'Completed';

  @override
  String get auditCompletedMessage => 'Audit completed';

  @override
  String get auditFailedMessage => 'Failed to submit audit';

  @override
  String get auditExitTitle => 'Exit Audit';

  @override
  String get auditExitMessage => 'Are you sure? Progress will not be saved.';

  @override
  String get auditAdjustmentsApplied => 'Adjustments Applied';

  @override
  String get auditCompleteHeading => 'Audit Complete';

  @override
  String get auditNeverAudited => 'Never';

  @override
  String auditSystemLastLine(String system, String last) {
    return 'System: $system · Last: $last';
  }

  @override
  String get auditActualLabel => 'Actual:';

  @override
  String get chatPhotoUploadFailed => 'Photo upload failed';

  @override
  String get chatPhotoRequiredTitle => 'Photo required';

  @override
  String get chatPhotoRequiredMessage => 'Please attach a photo.';

  @override
  String get chatSubmitFailed => 'Failed to submit. Please try again.';

  @override
  String get chatSendFailed => 'Send failed';

  @override
  String get chatPhotoSendFailed => 'Photo send failed';

  @override
  String get chatAddPhoto => 'Add Photo';

  @override
  String get chatTakePhoto => 'Take Photo';

  @override
  String get chatChooseGallery => 'Choose from Gallery';

  @override
  String get chatSubmitting => 'Submitting...';

  @override
  String get chatUploadingPhoto => 'Uploading photo...';

  @override
  String get chatStatusRejected => 'Rejected — Resubmission required';

  @override
  String get chatStatusReReview => 'Pending re-review';

  @override
  String get chatStatusApproved => 'Approved';

  @override
  String get chatStatusCompleted => 'Completed — Awaiting review';

  @override
  String get chatStatusNotCompleted => 'Not completed — Submit below';

  @override
  String chatPhotosLabel(int min) {
    return 'Photos (required, min $min)';
  }

  @override
  String get chatTextLabel => 'Text (required)';

  @override
  String get chatTakePhotoBtn => 'Take Photo';

  @override
  String get chatGalleryBtn => 'Gallery';

  @override
  String chatPhotosCount(int current, int min) {
    return 'Photos: $current/$min required';
  }

  @override
  String get chatReasonForResubmission => 'Reason for resubmission...';

  @override
  String get chatTextOptional => 'Text (optional) — e.g. task completed';

  @override
  String get chatResubmit => 'Resubmit';

  @override
  String get chatSubmit => 'Submit';

  @override
  String get chatBadgeSubmitted => 'Submitted';

  @override
  String get chatBadgeResubmitted => 'Resubmitted';

  @override
  String get chatBadgeRejected => 'Rejected';

  @override
  String get chatBadgeApproved => 'Approved';

  @override
  String get chatBadgeReReview => 'Pending Re-review';

  @override
  String get chatBadgePending => 'Pending';

  @override
  String get chatTypeMessage => 'Type a message...';

  @override
  String get chatLabelRejected => 'Rejected';

  @override
  String get chatLabelApproved => 'Approved';

  @override
  String get chatLabelReReview => 'Re-review';

  @override
  String get chatLabelDone => 'Done';

  @override
  String get chatLabelPending => 'Pending';

  @override
  String get stockItemsLabel => 'Items';

  @override
  String get stockTapToAddItems => 'Tap + to add items';

  @override
  String get stockReasonOptional => 'Reason (optional)';

  @override
  String get stockSavedTitle => 'Saved';

  @override
  String get stockInSavedMessage => 'Stock in recorded successfully';

  @override
  String get stockOutSavedMessage => 'Stock out recorded successfully';

  @override
  String get stockSaveFailed => 'Failed to save. Please try again.';

  @override
  String get stockSearchHint => 'Search inventory...';

  @override
  String get stockNoProductsFound => 'No products found';

  @override
  String get stockAddedBadge => 'Added';

  @override
  String get stockWillBeNegative => 'Will be negative';

  @override
  String get stockWillBeBelowMin => 'Will be below minimum';

  @override
  String get checklistAllDoneTitle => 'All Done';

  @override
  String get checklistAllDoneMessage => 'All items completed! Great work.';

  @override
  String get checklistResubmittedTitle => 'Resubmitted';

  @override
  String get checklistResubmittedMessage => 'Resubmitted.';

  @override
  String get checklistResubmitFailed => 'Couldn\'t resubmit';

  @override
  String get checklistResubmitFailedMessage =>
      'Failed to resubmit. Please try again.';

  @override
  String get checklistCompleteFailed => 'Couldn\'t complete';

  @override
  String get checklistCompleteFailedMessage =>
      'Failed to complete item. Please try again.';

  @override
  String get checklistUndoFailed => 'Couldn\'t undo';

  @override
  String get checklistUndoFailedMessage => 'Failed to undo. Please try again.';

  @override
  String get checklistUndoCompleteTitle => 'Undo Complete';

  @override
  String get checklistUndoCompleteMessage =>
      'Are you sure you want to undo this item?';

  @override
  String get checklistUndoAction => 'Undo';

  @override
  String get checklistCannotUncheckTitle => 'Cannot Uncheck';

  @override
  String get checklistCannotUncheckMessage =>
      'Reviewed items cannot be unchecked.';

  @override
  String get checklistSubmitReportTitle => 'Submit Report';

  @override
  String get checklistSubmitReportMessage =>
      'Submit checklist completion report? Changes may be restricted after submission.';

  @override
  String get checklistSubmitAction => 'Submit';

  @override
  String get checklistSubmittedTitle => 'Submitted';

  @override
  String get checklistSubmittedMessage => 'Report submitted.';

  @override
  String get checklistSubmitFailed => 'Couldn\'t submit report';

  @override
  String get checklistSubmitFailedMessage =>
      'Failed to submit report. Please try again.';

  @override
  String get checklistPhotoUploadFailedTitle => 'Couldn\'t upload';

  @override
  String get checklistPhotoUploadFailed => 'Photo upload failed';

  @override
  String get checklistAddPhoto => 'Add Photo';

  @override
  String get checklistTakePhoto => 'Take Photo';

  @override
  String get checklistChooseGallery => 'Choose from Gallery';

  @override
  String get checklistTitle => 'Checklist';

  @override
  String get checklistFailedToLoad => 'Failed to load schedule';

  @override
  String get checklistNotFound => 'Schedule not found.';

  @override
  String get checklistUploading => 'Uploading photo...';

  @override
  String get checklistEmptyPending => 'No pending items.';

  @override
  String get checklistEmptyCompleted => 'No completed items.';

  @override
  String get checklistEmptyRejected => 'No rejected items.';

  @override
  String get checklistEmptyAll => 'No checklist items.';

  @override
  String get checklistComplete => 'Complete';

  @override
  String get checklistInProgress => 'In Progress';

  @override
  String checklistItemsCount(int completed, int total) {
    return '$completed/$total items';
  }

  @override
  String get checklistTabAll => 'All';

  @override
  String get checklistTabTodo => 'Todo';

  @override
  String get checklistTabDone => 'Done';

  @override
  String get checklistTabRejected => 'Rejected';

  @override
  String get checklistResubmitRequired => 'Resubmit Required';

  @override
  String get checklistApproved => 'Approved';

  @override
  String get checklistRejected => 'Rejected';

  @override
  String get checklistReReviewPending => 'Re-review Pending';

  @override
  String get checklistTapToView => 'Tap to view description';

  @override
  String get checklistAllReviewed => 'All Reviewed';

  @override
  String get checklistReportSubmitted => 'Report Submitted';

  @override
  String get checklistSubmitReport => 'Submit Report';

  @override
  String get checklistBadgeDaily => 'Daily';

  @override
  String get checklistBadgePhoto => 'Photo';

  @override
  String get checklistBadgeText => 'Text';

  @override
  String get checklistMaxPhotosTitle => 'Limit reached';

  @override
  String checklistMaxPhotosMessage(int max) {
    return 'Maximum $max photos allowed';
  }

  @override
  String checklistMorePhotosAllowed(int count, int max) {
    return 'Only $count more photo(s) allowed (max $max)';
  }

  @override
  String get checklistResubmitItem => 'Resubmit Item';

  @override
  String get checklistCompleteItem => 'Complete Item';

  @override
  String get checklistPhoto => 'Photo';

  @override
  String checklistPhotoCount(int current, int min, int max) {
    return '$current/$min min, $max max';
  }

  @override
  String get checklistAddShort => 'Add';

  @override
  String get checklistTapToAddPhoto => 'Tap to add photo';

  @override
  String get checklistNote => 'Note';

  @override
  String get checklistRequired => 'required';

  @override
  String get checklistOptional => 'optional';

  @override
  String get checklistEnterNote => 'Enter note...';

  @override
  String get checklistOptionalNote => 'Optional note...';

  @override
  String get checklistSubmitting => 'Submitting...';

  @override
  String get checklistResubmit => 'Resubmit';

  @override
  String get checklistCompleteAction => 'Complete';

  @override
  String get checklistNoAttachments => 'No attachments';

  @override
  String get workChecklistTab => 'Checklist';

  @override
  String get workTaskTab => 'Task';

  @override
  String get workTabToday => 'Today';

  @override
  String get workTabPast => 'Past';

  @override
  String get workEmptyChecklistsToday => 'No checklists assigned today';

  @override
  String get workEmptyPastChecklists => 'No past checklists';

  @override
  String get workEmptyTasks => 'No tasks assigned';

  @override
  String get workEmptyChecklistItems => 'No checklist items';

  @override
  String get workNoMatchingRecords => 'No matching records';

  @override
  String get workNoTasksForDate => 'No tasks for selected date';

  @override
  String workNoResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String workUnresolvedCount(int count) {
    return 'Unresolved $count';
  }

  @override
  String workPreviousUnresolvedCount(int count) {
    return 'Previous unresolved: $count';
  }

  @override
  String get workUpcoming => 'Upcoming';

  @override
  String get workSearchTasksHint => 'Search tasks or stores';

  @override
  String get workDueLabel => 'Due';

  @override
  String get workSortBy => 'Sort by';

  @override
  String get workSortDueDate => 'Due date';

  @override
  String get workSortPriority => 'Priority';

  @override
  String get workSortRecent => 'Recent';

  @override
  String get workSortName => 'Name';

  @override
  String workTasksDoneCount(int count) {
    return '$count done';
  }

  @override
  String get workTasksDoneLabel => 'done';

  @override
  String get workTasksLeftLabel => 'left';

  @override
  String get workFilterAll => 'All';

  @override
  String get workFilterDate => 'Date';

  @override
  String get workCardStatusNotStarted => 'Not Started';

  @override
  String get workCardStatusInProgress => 'In Progress';

  @override
  String get workCardStatusPendingReview => 'Pending Review';

  @override
  String get workCardStatusDone => 'Done';

  @override
  String get workStatusApproved => 'Approved';

  @override
  String get workStatusRejected => 'Rejected';

  @override
  String get workStatusSubmitted => 'Submitted';

  @override
  String get workStatusResubmitted => 'Resubmitted';

  @override
  String get workStatusPendingReview => 'Pending Re-review';

  @override
  String get workStatusRevisionRequested => 'Revision Requested';

  @override
  String get workStatusPending => 'Pending';

  @override
  String get workStatusNotSubmitted => 'Not Submitted';

  @override
  String get workStatusActionRequired => 'Action Required';

  @override
  String workCompletedAt(String time) {
    return 'Completed $time';
  }

  @override
  String get workSelectWorkDate => 'Select Work Date';

  @override
  String get workLegendWorkDay => 'Work day';

  @override
  String get workLegendNoWork => 'No work';

  @override
  String get workAddPhoto => 'Add Photo';

  @override
  String get workTakePhoto => 'Take Photo';

  @override
  String get workChooseFromGallery => 'Choose from Gallery';

  @override
  String get workAddAPhoto => 'Add a photo';

  @override
  String get workCameraButton => 'Camera';

  @override
  String get workGalleryButton => 'Gallery';

  @override
  String get workPhotoSectionTitle => 'Photo';

  @override
  String get workPhotoSectionSubtitle => 'Please upload verification photo.';

  @override
  String get workNoteSectionTitle => 'Note';

  @override
  String get workNoteSectionSubtitle => 'Please describe the work done.';

  @override
  String get workEnterNoteHint => 'Enter your note...';

  @override
  String get workVerificationHeader => 'Verification';

  @override
  String get workAddNoteTitle => 'Add Note';

  @override
  String get workVerificationNoteHint => 'Enter verification note...';

  @override
  String get workResponseDialogTitle => 'Response';

  @override
  String get workResponseDialogHint =>
      'Enter your response to the rejection...';

  @override
  String get workPhotoUploadFailedTitle => 'Couldn\'t upload';

  @override
  String get workPhotoUploadFailedMessage => 'Photo upload failed';

  @override
  String get workAllCompleteCelebration =>
      'All checklist items complete! Great job!';

  @override
  String get workDoneButton => 'DONE';

  @override
  String get workAwaitingResubmission => 'Awaiting resubmission';

  @override
  String get workTimelineMessage => 'Message';

  @override
  String get workTimelinePhoto => 'Photo';

  @override
  String get workFailedToLoadImage => 'Failed to load image';

  @override
  String get workPriorityUrgent => 'Urgent';

  @override
  String get workPriorityHigh => 'High';

  @override
  String get workPriorityNormal => 'Normal';

  @override
  String get workPriorityLow => 'Low';

  @override
  String get invAddTitle => 'Add Product';

  @override
  String get invAddImageSection => 'Product Image';

  @override
  String get invAddTakePhoto => 'Take Photo';

  @override
  String get invAddChooseGallery => 'Choose from Gallery';

  @override
  String get invAddRemovePhoto => 'Remove Photo';

  @override
  String get invAddUploadFailedTitle => 'Couldn\'t upload';

  @override
  String get invAddUploadFailedMessage => 'Image upload failed';

  @override
  String get invAddSearchHint => 'Search products by name or code...';

  @override
  String get invAddCreateNewProduct => 'Create New Product';

  @override
  String get invAddAlreadyAdded => 'Already Added';

  @override
  String get invAddMinQtyLabel => 'Min Quantity';

  @override
  String get invAddInitialQtyLabel => 'Initial Quantity';

  @override
  String get invAddFrequentAudit => 'Frequent audit';

  @override
  String get invAddAddToStore => 'Add to Store';

  @override
  String get invAddTapToAddPhoto => 'Tap to add photo';

  @override
  String get invAddCameraOrGallery => 'Camera or Gallery';

  @override
  String get invAddNameLabel => 'Product Name *';

  @override
  String get invAddNameHint => 'e.g. Whole Milk (1L)';

  @override
  String get invAddNameRequired => 'Product name is required';

  @override
  String get invAddCodeLabel => 'Product Code';

  @override
  String get invAddCodeHint => 'Auto-generated if empty';

  @override
  String get invAddCategoryLabel => 'Category *';

  @override
  String get invAddCategoryRequired => 'Category is required';

  @override
  String get invAddSubcategoryLabel => 'Subcategory';

  @override
  String get invAddSubUnitLabel => 'Sub Unit';

  @override
  String get invAddSubUnitHelp => 'Leave empty if counted only in ea';

  @override
  String get invAddSubUnitRatioLabel => 'Sub Unit Ratio *';

  @override
  String invAddSubUnitRatioHint(String unit) {
    return '1 $unit = ? ea (e.g. 24)';
  }

  @override
  String get invAddRatioInvalid => 'Ratio must be greater than 0';

  @override
  String get invAddDescriptionLabel => 'Description';

  @override
  String get invAddDescriptionHint => 'Short product description';

  @override
  String get invAddStoreSettingsSection => 'Store Settings';

  @override
  String get invAddCreateAndAdd => 'Create & Add to Store';

  @override
  String get invAddCategoryHint => 'Select category';

  @override
  String get invAddAddNew => '+ Add New';

  @override
  String get invAddNewCategoryHint => 'e.g. Produce, Snacks...';

  @override
  String get invAddAlreadyExistsTitle => 'Already exists';

  @override
  String invAddAlreadyExistsMessage(String name) {
    return '\"$name\" already exists';
  }

  @override
  String get invAddCreateCategoryFailedTitle => 'Couldn\'t create category';

  @override
  String get invAddCreateCategoryFailedMessage => 'Failed to create category';

  @override
  String get invAddSelectCategoryFirst => 'Select a category first';

  @override
  String get invAddNone => 'None';

  @override
  String get invAddNewSubcategoryHint => 'New subcategory name...';

  @override
  String get invAddCreateSubcategoryFailedTitle =>
      'Couldn\'t create subcategory';

  @override
  String get invAddCreateSubcategoryFailedMessage =>
      'Failed to create subcategory';

  @override
  String get invAddSubUnitNone => 'None (ea only)';

  @override
  String get invAddNewSubUnitHint => 'e.g. crate, tray...';

  @override
  String get invAddCreateSubUnitFailedTitle => 'Couldn\'t create sub unit';

  @override
  String get invAddCreateSubUnitFailedMessage => 'Failed to create sub unit';

  @override
  String get invAddAddedTitle => 'Added';

  @override
  String invAddAddedMessage(String name) {
    return '$name added to store';
  }

  @override
  String get invAddAddFailedTitle => 'Couldn\'t add product';

  @override
  String get invAddAddFailedMessage => 'Failed to add product';

  @override
  String get invAddCreatedTitle => 'Created';

  @override
  String invAddCreatedMessage(String name) {
    return '$name created and added to store';
  }

  @override
  String get invAddCreateProductFailedTitle => 'Couldn\'t create product';

  @override
  String get invAddCreateProductFailedMessage => 'Failed to create product';

  @override
  String get myPinLabel => 'Clock-in PIN';

  @override
  String get myPinEdit => 'Edit PIN';

  @override
  String get myPinNotAvailable => 'Not available';

  @override
  String get myPinSaveFailed => 'Could not save PIN';

  @override
  String get warningsHeader => 'Warnings';

  @override
  String get warningsCardTitle => 'Warnings';

  @override
  String get warningsCardAllSigned => 'All signed';

  @override
  String warningsCardNeedSignature(int count) {
    return '$count need your signature';
  }

  @override
  String warningsBannerNeedSignature(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count warnings need your signature.',
      one: '1 warning needs your signature.',
    );
    return '$_temp0';
  }

  @override
  String get warningsBannerAllSigned =>
      'All warnings signed. Nothing needs your attention.';

  @override
  String get warningsEmpty => 'No warnings.';

  @override
  String get warningsLoadFailed => 'Couldn\'t load warnings';

  @override
  String get warningsNotFound => 'Warning not found.';

  @override
  String get warningsNewBadge => 'New';

  @override
  String get warningStatusSigned => 'Signed';

  @override
  String get warningStatusUnsigned => 'Signature required';

  @override
  String get warningOrdinalFirst => 'First Warning';

  @override
  String get warningOrdinalSecond => 'Second Warning';

  @override
  String get warningOrdinalFinal => 'Final Warning';

  @override
  String warningOrdinalN(int n) {
    return 'Warning #$n';
  }

  @override
  String warningDetailTitle(String refNo) {
    return 'Warning $refNo';
  }

  @override
  String warningIssuedBy(String name) {
    return 'Issued by $name';
  }

  @override
  String warningReadOn(String date) {
    return 'Read on $date';
  }

  @override
  String get warningSectionReasons => 'Reasons';

  @override
  String get warningSectionDetails => 'Details';

  @override
  String get warningSectionCorrective => 'Corrective action';

  @override
  String get warningSectionFollowUp => 'Follow-up';

  @override
  String get warningDeadline => 'Deadline';

  @override
  String warningSignedOn(String date) {
    return 'Signed on $date';
  }

  @override
  String warningManagerSignedOn(String date) {
    return 'Manager signed on $date';
  }

  @override
  String get warningManagerAwaiting => 'Awaiting manager signature';

  @override
  String get warningSignatureRequired => 'Your signature is required';

  @override
  String get warningEmployeeSignature => 'Employee signature';

  @override
  String get warningActionSign => 'Sign';

  @override
  String get warningViewDocument => 'View official document';

  @override
  String get warningViewDocumentSubtitle =>
      'Employee Warning Notice Form · PDF';

  @override
  String warningDocumentTitle(String refNo) {
    return 'Document · $refNo';
  }

  @override
  String get warningSignSheetTitle => 'Sign this warning';

  @override
  String get warningSignSheetSubtitle =>
      'Your signature confirms you have read and received this warning.';

  @override
  String get warningSignDrawNew => 'Draw new';

  @override
  String get warningSignUseSaved => 'Use saved signature';

  @override
  String get warningSignDrawHint => 'Draw your signature here';

  @override
  String get warningSignNoSaved => 'No saved signature yet. Draw one below.';

  @override
  String warningSignSigningAs(String name) {
    return 'Signing as $name';
  }

  @override
  String get warningSignSaveAsDefault => 'Save as my default signature';

  @override
  String get warningSignClear => 'Clear';

  @override
  String get warningSignConfirm => 'Confirm signature';

  @override
  String get warningSignFailed => 'Couldn\'t sign. Please try again.';

  @override
  String get warningStatusSignInPerson => 'Sign in person';

  @override
  String get warningViewSignedDocument => 'View signed document';

  @override
  String get warningSignedDocOpenFailed =>
      'Couldn\'t open the signed document. Please try again.';

  @override
  String get warningWetSignInPersonTitle => 'Sign this warning in person';

  @override
  String get warningWetSignInPersonBody =>
      'This warning must be signed in person — see your manager. There\'s nothing to sign in the app.';

  @override
  String get warningWetDocOnFile => 'Signed document on file';

  @override
  String get warningWetDocAwaiting => 'Awaiting signed document';

  @override
  String get warningDocEmployeeName => 'Employee Name';

  @override
  String get warningDocEmpId => 'Emp ID';

  @override
  String get warningDocManagerName => 'Manager Name';

  @override
  String get warningDocStoreBrand => 'Store / Brand';

  @override
  String get warningDocDate => 'Date';

  @override
  String get warningDocWarningType => 'Warning Type';

  @override
  String get warningDocReasonsTitle =>
      '1. Behavior / actions found unsatisfactory — reasons';

  @override
  String get warningDocDetailsLabel =>
      'Details of unsatisfactory behavior / actions';

  @override
  String get warningDocCorrectiveTitle => '2. Corrective action required';

  @override
  String get warningDocDeadline => '3. Deadline';

  @override
  String get warningDocFollowUpDate => '4. Follow-up date';

  @override
  String get warningDocFollowUpTime => 'Follow-up time';

  @override
  String get warningDocEmployeeSignature => 'Employee Signature';

  @override
  String get warningDocManagerSignature => 'Manager Signature';

  @override
  String get warningDocCc => 'cc';

  @override
  String get warningDocCcValue =>
      'Employee / Manager / Human Resources / Personnel File';

  @override
  String get warningDocNone => '—';

  @override
  String get changelogTitle => 'What\'s New';

  @override
  String get changelogEmpty => 'No updates yet';

  @override
  String get changelogLoadError => 'Failed to load updates';

  @override
  String get changelogRetry => 'Retry';
}
