import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('zh'),
  ];

  /// No description provided for @chatAttachments.
  ///
  /// In en, this message translates to:
  /// **'More chat features'**
  String get chatAttachments;

  /// No description provided for @sendFile.
  ///
  /// In en, this message translates to:
  /// **'Send file'**
  String get sendFile;

  /// No description provided for @sendPhoto.
  ///
  /// In en, this message translates to:
  /// **'Send image'**
  String get sendPhoto;

  /// No description provided for @chatStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get chatStickers;

  /// No description provided for @saveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Save attachment'**
  String get saveAttachment;

  /// No description provided for @openImagePreview.
  ///
  /// In en, this message translates to:
  /// **'Open image preview'**
  String get openImagePreview;

  /// No description provided for @closeImagePreview.
  ///
  /// In en, this message translates to:
  /// **'Close image preview'**
  String get closeImagePreview;

  /// No description provided for @imagePreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch or scroll to zoom, then drag to move the image'**
  String get imagePreviewHint;

  /// No description provided for @attachmentSaved.
  ///
  /// In en, this message translates to:
  /// **'Attachment saved'**
  String get attachmentSaved;

  /// No description provided for @attachmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attachment unavailable. Check your connection and retry'**
  String get attachmentUnavailable;

  /// No description provided for @attachmentPickError.
  ///
  /// In en, this message translates to:
  /// **'Choose a non-empty file up to 20 MiB. Pictures must be valid PNG, JPEG or GIF images up to 25 megapixels'**
  String get attachmentPickError;

  /// No description provided for @chatStickersPlanned.
  ///
  /// In en, this message translates to:
  /// **'Your shared sticker collection is coming later.'**
  String get chatStickersPlanned;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get chooseLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get chinese;

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your little home, together'**
  String get homeHeadline;

  /// No description provided for @homeIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose how you’d like to come in.'**
  String get homeIntro;

  /// No description provided for @createInvitation.
  ///
  /// In en, this message translates to:
  /// **'Create invitation'**
  String get createInvitation;

  /// No description provided for @createInvitationDescription.
  ///
  /// In en, this message translates to:
  /// **'Start a home on your private server.'**
  String get createInvitationDescription;

  /// No description provided for @acceptInvitation.
  ///
  /// In en, this message translates to:
  /// **'Accept invitation'**
  String get acceptInvitation;

  /// No description provided for @acceptInvitationDescription.
  ///
  /// In en, this message translates to:
  /// **'Join your partner using their link.'**
  String get acceptInvitationDescription;

  /// No description provided for @restoreData.
  ///
  /// In en, this message translates to:
  /// **'Restore data'**
  String get restoreData;

  /// No description provided for @restoreDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Lost access? Use your recovery code.'**
  String get restoreDataDescription;

  /// No description provided for @addDevice.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get addDevice;

  /// No description provided for @addDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep your other devices signed in.'**
  String get addDeviceDescription;

  /// No description provided for @alreadyPaired.
  ///
  /// In en, this message translates to:
  /// **'Already paired? Add a device instead of creating a new invitation. Your home’s data stays on your server.'**
  String get alreadyPaired;

  /// No description provided for @invitePartner.
  ///
  /// In en, this message translates to:
  /// **'Invite your partner'**
  String get invitePartner;

  /// No description provided for @chooseHomeAddress.
  ///
  /// In en, this message translates to:
  /// **'Choose your home address'**
  String get chooseHomeAddress;

  /// No description provided for @trustedServerHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the URL or domain of the private server you trust.'**
  String get trustedServerHelp;

  /// No description provided for @serverUrlDomain.
  ///
  /// In en, this message translates to:
  /// **'Server URL or domain'**
  String get serverUrlDomain;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @serverUrlExisting.
  ///
  /// In en, this message translates to:
  /// **'Existing server URL'**
  String get serverUrlExisting;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://pawmate.example.com'**
  String get serverUrlHint;

  /// No description provided for @enterServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter your server URL.'**
  String get enterServerUrl;

  /// No description provided for @makingRoom.
  ///
  /// In en, this message translates to:
  /// **'Making a little room…'**
  String get makingRoom;

  /// No description provided for @createInvitationAction.
  ///
  /// In en, this message translates to:
  /// **'Create invitation'**
  String get createInvitationAction;

  /// No description provided for @invitationCreatedStorageWarning.
  ///
  /// In en, this message translates to:
  /// **'Invitation created. Save the recovery code below; this device could not store it securely.'**
  String get invitationCreatedStorageWarning;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the Pawmate server.'**
  String get serverUnreachable;

  /// No description provided for @serverUnreachableShort.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server.'**
  String get serverUnreachableShort;

  /// No description provided for @invitationCopied.
  ///
  /// In en, this message translates to:
  /// **'Invitation link copied'**
  String get invitationCopied;

  /// No description provided for @invitationReady.
  ///
  /// In en, this message translates to:
  /// **'Your invitation is ready'**
  String get invitationReady;

  /// No description provided for @homeConnected.
  ///
  /// In en, this message translates to:
  /// **'Your home is connected!'**
  String get homeConnected;

  /// No description provided for @shareInvitation.
  ///
  /// In en, this message translates to:
  /// **'Share this one-time link with your partner.'**
  String get shareInvitation;

  /// No description provided for @connectedMemories.
  ///
  /// In en, this message translates to:
  /// **'You and your partner can start making memories together.'**
  String get connectedMemories;

  /// No description provided for @copyInvitation.
  ///
  /// In en, this message translates to:
  /// **'Copy invitation'**
  String get copyInvitation;

  /// No description provided for @expiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String expiresAt(String date);

  /// No description provided for @pairingComplete.
  ///
  /// In en, this message translates to:
  /// **'Pairing complete'**
  String get pairingComplete;

  /// No description provided for @checkPairingStatus.
  ///
  /// In en, this message translates to:
  /// **'Check pairing status'**
  String get checkPairingStatus;

  /// No description provided for @waitingForPartner.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your partner to accept…'**
  String get waitingForPartner;

  /// No description provided for @recoveryCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your recovery code'**
  String get recoveryCodeTitle;

  /// No description provided for @recoveryCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep this code somewhere safe. It can restore your home after losing a device.'**
  String get recoveryCodeHelp;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @recoveryCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Recovery code copied'**
  String get recoveryCodeCopied;

  /// No description provided for @anInvitationForTwo.
  ///
  /// In en, this message translates to:
  /// **'An invitation for two'**
  String get anInvitationForTwo;

  /// No description provided for @invitationPasteHelp.
  ///
  /// In en, this message translates to:
  /// **'Paste the complete link your partner sent. You’ll review the server address before joining.'**
  String get invitationPasteHelp;

  /// No description provided for @invitationLink.
  ///
  /// In en, this message translates to:
  /// **'Invitation link'**
  String get invitationLink;

  /// No description provided for @pasteInvitationLinkFirst.
  ///
  /// In en, this message translates to:
  /// **'Copy your partner’s invitation link first.'**
  String get pasteInvitationLinkFirst;

  /// No description provided for @clipboardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Clipboard unavailable. Paste or type the link into the field.'**
  String get clipboardUnavailable;

  /// No description provided for @pasteLink.
  ///
  /// In en, this message translates to:
  /// **'Paste link'**
  String get pasteLink;

  /// No description provided for @reviewInvitation.
  ///
  /// In en, this message translates to:
  /// **'Review invitation'**
  String get reviewInvitation;

  /// No description provided for @invalidInvitationLink.
  ///
  /// In en, this message translates to:
  /// **'This invitation link is not valid.'**
  String get invalidInvitationLink;

  /// No description provided for @incompleteInvitation.
  ///
  /// In en, this message translates to:
  /// **'This invitation link is incomplete.'**
  String get incompleteInvitation;

  /// No description provided for @joinHome.
  ///
  /// In en, this message translates to:
  /// **'Join your little home'**
  String get joinHome;

  /// No description provided for @invited.
  ///
  /// In en, this message translates to:
  /// **'You have been invited'**
  String get invited;

  /// No description provided for @acceptOneTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Accepting this one-time invitation will pair your device with your partner.'**
  String get acceptOneTimeHelp;

  /// No description provided for @privateServer.
  ///
  /// In en, this message translates to:
  /// **'Private server'**
  String get privateServer;

  /// No description provided for @joining.
  ///
  /// In en, this message translates to:
  /// **'Joining…'**
  String get joining;

  /// No description provided for @couldNotAccept.
  ///
  /// In en, this message translates to:
  /// **'Could not accept this invitation.'**
  String get couldNotAccept;

  /// No description provided for @incompleteCredentials.
  ///
  /// In en, this message translates to:
  /// **'The server did not return complete pairing credentials.'**
  String get incompleteCredentials;

  /// No description provided for @restoreHome.
  ///
  /// In en, this message translates to:
  /// **'Restore your home'**
  String get restoreHome;

  /// No description provided for @reconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Let’s reconnect you'**
  String get reconnectTitle;

  /// No description provided for @reconnectHelp.
  ///
  /// In en, this message translates to:
  /// **'This device needs a new login. If another device is still signed in, use its device login code. Recovery is for lost access and signs out all your other devices.'**
  String get reconnectHelp;

  /// No description provided for @deviceCodeSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a device login code'**
  String get deviceCodeSignIn;

  /// No description provided for @restoreExistingHome.
  ///
  /// In en, this message translates to:
  /// **'Restoring an existing home?'**
  String get restoreExistingHome;

  /// No description provided for @recoveryHelp.
  ///
  /// In en, this message translates to:
  /// **'Use your recovery code if you have lost access. Recovery signs out all your devices and replaces the recovery code; your partner stays signed in. To add a device, use a device login code instead.'**
  String get recoveryHelp;

  /// No description provided for @recoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get recoveryCode;

  /// No description provided for @restoringAccess.
  ///
  /// In en, this message translates to:
  /// **'Restoring access…'**
  String get restoringAccess;

  /// No description provided for @restoreAccess.
  ///
  /// In en, this message translates to:
  /// **'Restore access with a recovery code'**
  String get restoreAccess;

  /// No description provided for @invalidRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'That recovery code is not valid anymore.'**
  String get invalidRecoveryCode;

  /// No description provided for @notPaired.
  ///
  /// In en, this message translates to:
  /// **'This server does not have a completed couple pairing.'**
  String get notPaired;

  /// No description provided for @couldNotRestore.
  ///
  /// In en, this message translates to:
  /// **'Could not restore this home. Try again.'**
  String get couldNotRestore;

  /// No description provided for @bringHome.
  ///
  /// In en, this message translates to:
  /// **'Bring your home along'**
  String get bringHome;

  /// No description provided for @signInAnotherDevice.
  ///
  /// In en, this message translates to:
  /// **'Sign in on another device'**
  String get signInAnotherDevice;

  /// No description provided for @deviceSignInHelp.
  ///
  /// In en, this message translates to:
  /// **'On your signed-in phone, tablet or computer, open My devices and choose Add a device. Enter its server address and login code here. Your other devices will stay signed in.'**
  String get deviceSignInHelp;

  /// No description provided for @deviceLoginCode.
  ///
  /// In en, this message translates to:
  /// **'Device login code'**
  String get deviceLoginCode;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceName;

  /// No description provided for @enterServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your server address.'**
  String get enterServerAddress;

  /// No description provided for @enterLoginCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the login code.'**
  String get enterLoginCode;

  /// No description provided for @deviceNameLength.
  ///
  /// In en, this message translates to:
  /// **'Use a name between 1 and 80 characters.'**
  String get deviceNameLength;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @invalidDeviceCode.
  ///
  /// In en, this message translates to:
  /// **'This login code expired or was already used. Generate a new one on your signed-in device.'**
  String get invalidDeviceCode;

  /// No description provided for @couldNotSignIn.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Check your connection and try again.'**
  String get couldNotSignIn;

  /// No description provided for @openingHome.
  ///
  /// In en, this message translates to:
  /// **'Opening your home'**
  String get openingHome;

  /// No description provided for @checkingSavedAccess.
  ///
  /// In en, this message translates to:
  /// **'Checking your saved access…'**
  String get checkingSavedAccess;

  /// No description provided for @findingHome.
  ///
  /// In en, this message translates to:
  /// **'Finding your home'**
  String get findingHome;

  /// No description provided for @chooseSignInMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose a sign-in method'**
  String get chooseSignInMethod;

  /// No description provided for @ourConversation.
  ///
  /// In en, this message translates to:
  /// **'Our conversation'**
  String get ourConversation;

  /// No description provided for @playCorner.
  ///
  /// In en, this message translates to:
  /// **'Play corner'**
  String get playCorner;

  /// No description provided for @ourLittleHome.
  ///
  /// In en, this message translates to:
  /// **'Our little home'**
  String get ourLittleHome;

  /// No description provided for @chatUnread.
  ///
  /// In en, this message translates to:
  /// **'Chat, {count} unread messages'**
  String chatUnread(int count);

  /// No description provided for @viewHome.
  ///
  /// In en, this message translates to:
  /// **'View Home'**
  String get viewHome;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @unreadGoLatest.
  ///
  /// In en, this message translates to:
  /// **'{count} unread · Go to latest'**
  String unreadGoLatest(int count);

  /// No description provided for @messagePartner.
  ///
  /// In en, this message translates to:
  /// **'Message your partner'**
  String get messagePartner;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @retryMessage.
  ///
  /// In en, this message translates to:
  /// **'Retry message'**
  String get retryMessage;

  /// No description provided for @myDevices.
  ///
  /// In en, this message translates to:
  /// **'My devices'**
  String get myDevices;

  /// No description provided for @signOutDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out {name}?'**
  String signOutDeviceTitle(String name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @signOutDevice.
  ///
  /// In en, this message translates to:
  /// **'Sign out device'**
  String get signOutDevice;

  /// No description provided for @refreshDevices.
  ///
  /// In en, this message translates to:
  /// **'Refresh devices'**
  String get refreshDevices;

  /// No description provided for @deviceCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Device login code copied'**
  String get deviceCodeCopied;

  /// No description provided for @copyLoginCode.
  ///
  /// In en, this message translates to:
  /// **'Copy login code'**
  String get copyLoginCode;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get changeLanguage;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @onlineGames.
  ///
  /// In en, this message translates to:
  /// **'Games together'**
  String get onlineGames;

  /// No description provided for @life.
  ///
  /// In en, this message translates to:
  /// **'Life'**
  String get life;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @checkingConnection.
  ///
  /// In en, this message translates to:
  /// **'Checking the server connection'**
  String get checkingConnection;

  /// No description provided for @connectionOnline.
  ///
  /// In en, this message translates to:
  /// **'Connected to your private server'**
  String get connectionOnline;

  /// No description provided for @connectionOffline.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to your server. Local conversations remain available'**
  String get connectionOffline;

  /// No description provided for @connectionUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'This device\'s access has expired. Restore access in Settings'**
  String get connectionUnauthorized;

  /// No description provided for @localChatStorageError.
  ///
  /// In en, this message translates to:
  /// **'Local chat storage is unavailable. New messages may not survive a restart'**
  String get localChatStorageError;

  /// No description provided for @serverConnection.
  ///
  /// In en, this message translates to:
  /// **'Server connection'**
  String get serverConnection;

  /// No description provided for @revalidateConnection.
  ///
  /// In en, this message translates to:
  /// **'Check connection and access again'**
  String get revalidateConnection;

  /// No description provided for @accessAndRecovery.
  ///
  /// In en, this message translates to:
  /// **'Access and recovery'**
  String get accessAndRecovery;

  /// No description provided for @recoverySettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Recovery signs out your other devices and replaces your recovery code. To add a device, use a device login code instead'**
  String get recoverySettingsHelp;

  /// No description provided for @languageSaveError.
  ///
  /// In en, this message translates to:
  /// **'The language changed, but could not be saved for the next launch'**
  String get languageSaveError;

  /// No description provided for @languageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Language preferences are unavailable in this preview'**
  String get languageUnavailable;

  /// No description provided for @coupleDetails.
  ///
  /// In en, this message translates to:
  /// **'Couple details'**
  String get coupleDetails;

  /// No description provided for @openCoupleDetails.
  ///
  /// In en, this message translates to:
  /// **'Open couple details'**
  String get openCoupleDetails;

  /// No description provided for @saveRecoveryCodeDetails.
  ///
  /// In en, this message translates to:
  /// **'Open couple details to save your recovery code before leaving.'**
  String get saveRecoveryCodeDetails;

  /// No description provided for @lifeSpace.
  ///
  /// In en, this message translates to:
  /// **'Our everyday life'**
  String get lifeSpace;

  /// No description provided for @viewLife.
  ///
  /// In en, this message translates to:
  /// **'View Life'**
  String get viewLife;

  /// No description provided for @saveRecoveryCodeLife.
  ///
  /// In en, this message translates to:
  /// **'Save your recovery code in Life before leaving.'**
  String get saveRecoveryCodeLife;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @unreadFromPartner.
  ///
  /// In en, this message translates to:
  /// **'{count} unread messages from your partner'**
  String unreadFromPartner(int count);

  /// No description provided for @openChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get openChat;

  /// No description provided for @loginNotSaved.
  ///
  /// In en, this message translates to:
  /// **'This device could not save its login. Open Home for reconnect instructions.'**
  String get loginNotSaved;

  /// No description provided for @saveRecoveryCodeHome.
  ///
  /// In en, this message translates to:
  /// **'Save your recovery code in Home before leaving.'**
  String get saveRecoveryCodeHome;

  /// No description provided for @gamesComing.
  ///
  /// In en, this message translates to:
  /// **'A little corner for playing together.\nGames will arrive here later.'**
  String get gamesComing;

  /// No description provided for @youAreHome.
  ///
  /// In en, this message translates to:
  /// **'You are home together'**
  String get youAreHome;

  /// No description provided for @connectedAsRole.
  ///
  /// In en, this message translates to:
  /// **'This device is connected as the {role}.'**
  String connectedAsRole(String role);

  /// No description provided for @homeId.
  ///
  /// In en, this message translates to:
  /// **'Home ID: {id}'**
  String homeId(String id);

  /// No description provided for @storageWarningRecovery.
  ///
  /// In en, this message translates to:
  /// **'This device could not securely save its login. Keep the recovery code below in case the app closes.'**
  String get storageWarningRecovery;

  /// No description provided for @storageWarningDevice.
  ///
  /// In en, this message translates to:
  /// **'This device could not securely save its login. If the app closes, generate a new login code on another signed-in device to reconnect.'**
  String get storageWarningDevice;

  /// No description provided for @couldNotReachRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not reach your server. Try again.'**
  String get couldNotReachRetry;

  /// No description provided for @signOutDeviceHelp.
  ///
  /// In en, this message translates to:
  /// **'This device will need a new login code to reconnect. Your other devices will stay signed in.'**
  String get signOutDeviceHelp;

  /// No description provided for @devicesHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep your phone, tablet and computer connected to the same home. Only your own devices appear here.'**
  String get devicesHelp;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @addedDate.
  ///
  /// In en, this message translates to:
  /// **'Added {date}'**
  String addedDate(String date);

  /// No description provided for @addDeviceAction.
  ///
  /// In en, this message translates to:
  /// **'Add a device'**
  String get addDeviceAction;

  /// No description provided for @newDeviceCodeHelp.
  ///
  /// In en, this message translates to:
  /// **'On your new device, choose Sign in on another device. Use the server address above and this code. Keep it private: it grants access as you.'**
  String get newDeviceCodeHelp;

  /// No description provided for @singleUseExpires.
  ///
  /// In en, this message translates to:
  /// **'Single use · Expires {date}'**
  String singleUseExpires(String date);

  /// No description provided for @chatError.
  ///
  /// In en, this message translates to:
  /// **'Chat could not be loaded. Check your connection and try again.'**
  String get chatError;

  /// No description provided for @firstWords.
  ///
  /// In en, this message translates to:
  /// **'Your first words together\nSend a little hello to start your shared journal.'**
  String get firstWords;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @notSent.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get notSent;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @loadEarlier.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get loadEarlier;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @messageTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use up to 4000 characters.'**
  String get messageTooLong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @savedAccessError.
  ///
  /// In en, this message translates to:
  /// **'Could not read or validate saved access on this device.'**
  String get savedAccessError;

  /// No description provided for @serverAccessError.
  ///
  /// In en, this message translates to:
  /// **'Could not reach your Pawmate server. Check your connection and retry.'**
  String get serverAccessError;

  /// No description provided for @sessionRestoreError.
  ///
  /// In en, this message translates to:
  /// **'Could not restore this session.'**
  String get sessionRestoreError;

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'The server could not complete this request. Try again.'**
  String get requestFailed;

  /// No description provided for @invalidServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP or HTTPS server address.'**
  String get invalidServerAddress;

  /// No description provided for @invitationLinkHint.
  ///
  /// In en, this message translates to:
  /// **'pawmate://pair?server=…&code=…'**
  String get invitationLinkHint;

  /// No description provided for @myDeviceName.
  ///
  /// In en, this message translates to:
  /// **'My device'**
  String get myDeviceName;

  /// No description provided for @uploadAvatar.
  ///
  /// In en, this message translates to:
  /// **'Upload avatar'**
  String get uploadAvatar;

  /// No description provided for @changeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change avatar'**
  String get changeAvatar;

  /// No description provided for @avatarImages.
  ///
  /// In en, this message translates to:
  /// **'Avatar images'**
  String get avatarImages;

  /// No description provided for @avatarRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose an avatar before continuing.'**
  String get avatarRequired;

  /// No description provided for @avatarUploadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read this image. Choose a PNG or JPEG under 10 MB.'**
  String get avatarUploadError;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'What should your partner call you?'**
  String get nicknameHint;

  /// No description provided for @nicknameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a nickname between 1 and 32 characters, without control characters.'**
  String get nicknameInvalid;

  /// No description provided for @profileRejected.
  ///
  /// In en, this message translates to:
  /// **'The server could not save your profile. Check your nickname and avatar.'**
  String get profileRejected;

  /// No description provided for @yourProfile.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get yourProfile;

  /// No description provided for @partnerProfile.
  ///
  /// In en, this message translates to:
  /// **'Your partner'**
  String get partnerProfile;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
