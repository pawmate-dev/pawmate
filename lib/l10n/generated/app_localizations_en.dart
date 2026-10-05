// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get chooseLanguage => 'Language';

  @override
  String get english => 'English';

  @override
  String get chinese => '简体中文';

  @override
  String get homeHeadline => 'Your little home, together';

  @override
  String get homeIntro => 'Choose how you’d like to come in.';

  @override
  String get createInvitation => 'Create invitation';

  @override
  String get createInvitationDescription =>
      'Start a home on your private server.';

  @override
  String get acceptInvitation => 'Accept invitation';

  @override
  String get acceptInvitationDescription =>
      'Join your partner using their link.';

  @override
  String get restoreData => 'Restore data';

  @override
  String get restoreDataDescription => 'Lost access? Use your recovery code.';

  @override
  String get addDevice => 'Add device';

  @override
  String get addDeviceDescription => 'Keep your other devices signed in.';

  @override
  String get alreadyPaired =>
      'Already paired? Add a device instead of creating a new invitation. Your home’s data stays on your server.';

  @override
  String get invitePartner => 'Invite your partner';

  @override
  String get chooseHomeAddress => 'Choose your home address';

  @override
  String get trustedServerHelp =>
      'Use the URL or domain of the private server you trust.';

  @override
  String get serverUrlDomain => 'Server URL or domain';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlExisting => 'Existing server URL';

  @override
  String get serverUrlHint => 'https://pawmate.example.com';

  @override
  String get enterServerUrl => 'Enter your server URL.';

  @override
  String get makingRoom => 'Making a little room…';

  @override
  String get createInvitationAction => 'Create invitation';

  @override
  String get invitationCreatedStorageWarning =>
      'Invitation created. Save the recovery code below; this device could not store it securely.';

  @override
  String get serverUnreachable => 'Could not reach the Pawmate server.';

  @override
  String get serverUnreachableShort => 'Could not reach the server.';

  @override
  String get invitationCopied => 'Invitation link copied';

  @override
  String get invitationReady => 'Your invitation is ready';

  @override
  String get homeConnected => 'Your home is connected!';

  @override
  String get shareInvitation => 'Share this one-time link with your partner.';

  @override
  String get connectedMemories =>
      'You and your partner can start making memories together.';

  @override
  String get copyInvitation => 'Copy invitation';

  @override
  String expiresAt(String date) {
    return 'Expires $date';
  }

  @override
  String get pairingComplete => 'Pairing complete';

  @override
  String get checkPairingStatus => 'Check pairing status';

  @override
  String get waitingForPartner => 'Waiting for your partner to accept…';

  @override
  String get recoveryCodeTitle => 'Your recovery code';

  @override
  String get recoveryCodeHelp =>
      'Keep this code somewhere safe. It can restore your home after losing a device.';

  @override
  String get copyCode => 'Copy code';

  @override
  String get recoveryCodeCopied => 'Recovery code copied';

  @override
  String get anInvitationForTwo => 'An invitation for two';

  @override
  String get invitationPasteHelp =>
      'Paste the complete link your partner sent. You’ll review the server address before joining.';

  @override
  String get invitationLink => 'Invitation link';

  @override
  String get pasteInvitationLinkFirst =>
      'Copy your partner’s invitation link first.';

  @override
  String get clipboardUnavailable =>
      'Clipboard unavailable. Paste or type the link into the field.';

  @override
  String get pasteLink => 'Paste link';

  @override
  String get reviewInvitation => 'Review invitation';

  @override
  String get invalidInvitationLink => 'This invitation link is not valid.';

  @override
  String get incompleteInvitation => 'This invitation link is incomplete.';

  @override
  String get joinHome => 'Join your little home';

  @override
  String get invited => 'You have been invited';

  @override
  String get acceptOneTimeHelp =>
      'Accepting this one-time invitation will pair your device with your partner.';

  @override
  String get privateServer => 'Private server';

  @override
  String get joining => 'Joining…';

  @override
  String get couldNotAccept => 'Could not accept this invitation.';

  @override
  String get incompleteCredentials =>
      'The server did not return complete pairing credentials.';

  @override
  String get restoreHome => 'Restore your home';

  @override
  String get reconnectTitle => 'Let’s reconnect you';

  @override
  String get reconnectHelp =>
      'This device needs a new login. If another device is still signed in, use its device login code. Recovery is for lost access and signs out all your other devices.';

  @override
  String get deviceCodeSignIn => 'Sign in with a device login code';

  @override
  String get restoreExistingHome => 'Restoring an existing home?';

  @override
  String get recoveryHelp =>
      'Use your recovery code if you have lost access. Recovery signs out all your devices and replaces the recovery code; your partner stays signed in. To add a device, use a device login code instead.';

  @override
  String get recoveryCode => 'Recovery code';

  @override
  String get restoringAccess => 'Restoring access…';

  @override
  String get restoreAccess => 'Restore access with a recovery code';

  @override
  String get invalidRecoveryCode => 'That recovery code is not valid anymore.';

  @override
  String get notPaired =>
      'This server does not have a completed couple pairing.';

  @override
  String get couldNotRestore => 'Could not restore this home. Try again.';

  @override
  String get bringHome => 'Bring your home along';

  @override
  String get signInAnotherDevice => 'Sign in on another device';

  @override
  String get deviceSignInHelp =>
      'On your signed-in phone, tablet or computer, open My devices and choose Add a device. Enter its server address and login code here. Your other devices will stay signed in.';

  @override
  String get deviceLoginCode => 'Device login code';

  @override
  String get deviceName => 'Device name';

  @override
  String get enterServerAddress => 'Enter your server address.';

  @override
  String get enterLoginCode => 'Enter the login code.';

  @override
  String get deviceNameLength => 'Use a name between 1 and 80 characters.';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get signIn => 'Sign in';

  @override
  String get back => 'Back';

  @override
  String get invalidDeviceCode =>
      'This login code expired or was already used. Generate a new one on your signed-in device.';

  @override
  String get couldNotSignIn =>
      'Could not sign in. Check your connection and try again.';

  @override
  String get openingHome => 'Opening your home';

  @override
  String get checkingSavedAccess => 'Checking your saved access…';

  @override
  String get findingHome => 'Finding your home';

  @override
  String get chooseSignInMethod => 'Choose a sign-in method';

  @override
  String get ourConversation => 'Our conversation';

  @override
  String get playCorner => 'Play corner';

  @override
  String get ourLittleHome => 'Our little home';

  @override
  String chatUnread(int count) {
    return 'Chat, $count unread messages';
  }

  @override
  String get viewHome => 'View Home';

  @override
  String get retry => 'Retry';

  @override
  String unreadGoLatest(int count) {
    return '$count unread · Go to latest';
  }

  @override
  String get messagePartner => 'Message your partner';

  @override
  String get sendMessage => 'Send message';

  @override
  String get retryMessage => 'Retry message';

  @override
  String get myDevices => 'My devices';

  @override
  String signOutDeviceTitle(String name) {
    return 'Sign out $name?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get signOutDevice => 'Sign out device';

  @override
  String get refreshDevices => 'Refresh devices';

  @override
  String get deviceCodeCopied => 'Device login code copied';

  @override
  String get copyLoginCode => 'Copy login code';

  @override
  String get changeLanguage => 'Change language';

  @override
  String get chat => 'Chat';

  @override
  String get onlineGames => 'Games together';

  @override
  String get life => 'Life';

  @override
  String get settings => 'Settings';

  @override
  String get checkingConnection => 'Checking the server connection';

  @override
  String get connectionOnline => 'Connected to your private server';

  @override
  String get connectionOffline =>
      'Cannot connect to your server. Local conversations remain available';

  @override
  String get connectionUnauthorized =>
      'This device\'s access has expired. Restore access in Settings';

  @override
  String get localChatStorageError =>
      'Local chat storage is unavailable. New messages may not survive a restart';

  @override
  String get serverConnection => 'Server connection';

  @override
  String get revalidateConnection => 'Check connection and access again';

  @override
  String get accessAndRecovery => 'Access and recovery';

  @override
  String get recoverySettingsHelp =>
      'Recovery signs out your other devices and replaces your recovery code. To add a device, use a device login code instead';

  @override
  String get languageSaveError =>
      'The language changed, but could not be saved for the next launch';

  @override
  String get languageUnavailable =>
      'Language preferences are unavailable in this preview';

  @override
  String get coupleDetails => 'Couple details';

  @override
  String get openCoupleDetails => 'Open couple details';

  @override
  String get saveRecoveryCodeDetails =>
      'Open couple details to save your recovery code before leaving.';

  @override
  String get lifeSpace => 'Our everyday life';

  @override
  String get viewLife => 'View Life';

  @override
  String get saveRecoveryCodeLife =>
      'Save your recovery code in Life before leaving.';

  @override
  String get play => 'Play';

  @override
  String get home => 'Home';

  @override
  String unreadFromPartner(int count) {
    return '$count unread messages from your partner';
  }

  @override
  String get openChat => 'Open chat';

  @override
  String get loginNotSaved =>
      'This device could not save its login. Open Home for reconnect instructions.';

  @override
  String get saveRecoveryCodeHome =>
      'Save your recovery code in Home before leaving.';

  @override
  String get gamesComing =>
      'A little corner for playing together.\nGames will arrive here later.';

  @override
  String get youAreHome => 'You are home together';

  @override
  String connectedAsRole(String role) {
    return 'This device is connected as the $role.';
  }

  @override
  String homeId(String id) {
    return 'Home ID: $id';
  }

  @override
  String get storageWarningRecovery =>
      'This device could not securely save its login. Keep the recovery code below in case the app closes.';

  @override
  String get storageWarningDevice =>
      'This device could not securely save its login. If the app closes, generate a new login code on another signed-in device to reconnect.';

  @override
  String get couldNotReachRetry => 'Could not reach your server. Try again.';

  @override
  String get signOutDeviceHelp =>
      'This device will need a new login code to reconnect. Your other devices will stay signed in.';

  @override
  String get devicesHelp =>
      'Keep your phone, tablet and computer connected to the same home. Only your own devices appear here.';

  @override
  String get thisDevice => 'This device';

  @override
  String addedDate(String date) {
    return 'Added $date';
  }

  @override
  String get addDeviceAction => 'Add a device';

  @override
  String get newDeviceCodeHelp =>
      'On your new device, choose Sign in on another device. Use the server address above and this code. Keep it private: it grants access as you.';

  @override
  String singleUseExpires(String date) {
    return 'Single use · Expires $date';
  }

  @override
  String get chatError =>
      'Chat could not be loaded. Check your connection and try again.';

  @override
  String get firstWords =>
      'Your first words together\nSend a little hello to start your shared journal.';

  @override
  String get sending => 'Sending…';

  @override
  String get notSent => 'Not sent';

  @override
  String get loading => 'Loading…';

  @override
  String get loadEarlier => 'Load earlier messages';

  @override
  String get read => 'Read';

  @override
  String get unread => 'Unread';

  @override
  String get messageTooLong => 'Use up to 4000 characters.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get savedAccessError =>
      'Could not read or validate saved access on this device.';

  @override
  String get serverAccessError =>
      'Could not reach your Pawmate server. Check your connection and retry.';

  @override
  String get sessionRestoreError => 'Could not restore this session.';

  @override
  String get requestFailed =>
      'The server could not complete this request. Try again.';

  @override
  String get invalidServerAddress =>
      'Enter a valid HTTP or HTTPS server address.';

  @override
  String get invitationLinkHint => 'pawmate://pair?server=…&code=…';

  @override
  String get myDeviceName => 'My device';

  @override
  String get uploadAvatar => 'Upload avatar';

  @override
  String get changeAvatar => 'Change avatar';

  @override
  String get avatarImages => 'Avatar images';

  @override
  String get avatarRequired => 'Choose an avatar before continuing.';

  @override
  String get avatarUploadError =>
      'Could not read this image. Choose a PNG or JPEG under 10 MB.';

  @override
  String get nickname => 'Nickname';

  @override
  String get nicknameHint => 'What should your partner call you?';

  @override
  String get nicknameInvalid =>
      'Use a nickname between 1 and 32 characters, without control characters.';

  @override
  String get profileRejected =>
      'The server could not save your profile. Check your nickname and avatar.';

  @override
  String get yourProfile => 'You';

  @override
  String get partnerProfile => 'Your partner';
}
