// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get chooseLanguage => '选择语言';

  @override
  String get english => 'English';

  @override
  String get chinese => '简体中文';

  @override
  String get homeHeadline => '两个人的小家';

  @override
  String get homeIntro => '选择一种方式进入';

  @override
  String get createInvitation => '创建邀请';

  @override
  String get createInvitationDescription => '在你的私人服务器上创建小家';

  @override
  String get acceptInvitation => '接受邀请';

  @override
  String get acceptInvitationDescription => '通过伴侣发送的链接加入';

  @override
  String get restoreData => '恢复数据';

  @override
  String get restoreDataDescription => '无法登录时使用恢复码';

  @override
  String get addDevice => '添加设备';

  @override
  String get addDeviceDescription => '让其他设备也保持登录';

  @override
  String get alreadyPaired => '如果已经配对，可直接添加设备，无需重新创建邀请，小家的数据仍保存在你的服务器上';

  @override
  String get invitePartner => '邀请伴侣';

  @override
  String get chooseHomeAddress => '设置小家的地址';

  @override
  String get trustedServerHelp => '填写你信任的私人服务器网址或域名';

  @override
  String get serverUrlDomain => '服务器网址或域名';

  @override
  String get serverUrl => '服务器网址';

  @override
  String get serverUrlExisting => '已有服务器网址';

  @override
  String get serverUrlHint => 'https://pawmate.example.com';

  @override
  String get enterServerUrl => '请输入服务器网址';

  @override
  String get makingRoom => '正在准备小家…';

  @override
  String get createInvitationAction => '创建邀请';

  @override
  String get invitationCreatedStorageWarning => '邀请已创建，请保存下方恢复码，此设备未能安全保存它';

  @override
  String get serverUnreachable => '无法连接到 Pawmate 服务器';

  @override
  String get serverUnreachableShort => '无法连接到服务器';

  @override
  String get invitationCopied => '邀请链接已复制';

  @override
  String get invitationReady => '邀请已准备好';

  @override
  String get homeConnected => '小家已连接';

  @override
  String get shareInvitation => '把这个一次性链接分享给伴侣';

  @override
  String get connectedMemories => '现在可以和伴侣一起留下回忆了';

  @override
  String get copyInvitation => '复制邀请';

  @override
  String expiresAt(String date) {
    return '有效期至 $date';
  }

  @override
  String get pairingComplete => '配对完成';

  @override
  String get checkPairingStatus => '检查配对状态';

  @override
  String get waitingForPartner => '等待伴侣接受邀请…';

  @override
  String get recoveryCodeTitle => '你的小家恢复码';

  @override
  String get recoveryCodeHelp => '请妥善保存此恢复码，设备丢失后可用它恢复小家';

  @override
  String get copyCode => '复制代码';

  @override
  String get recoveryCodeCopied => '恢复码已复制';

  @override
  String get anInvitationForTwo => '一份双人邀请';

  @override
  String get invitationPasteHelp => '粘贴伴侣发来的完整链接，加入前可以先核对服务器地址';

  @override
  String get invitationLink => '邀请链接';

  @override
  String get pasteInvitationLinkFirst => '请先复制伴侣发来的邀请链接';

  @override
  String get clipboardUnavailable => '剪贴板不可用，请在下方粘贴或输入链接';

  @override
  String get pasteLink => '粘贴链接';

  @override
  String get reviewInvitation => '查看邀请';

  @override
  String get invalidInvitationLink => '邀请链接无效';

  @override
  String get incompleteInvitation => '邀请链接不完整';

  @override
  String get joinHome => '加入小家';

  @override
  String get invited => '你收到了一份邀请';

  @override
  String get acceptOneTimeHelp => '接受这份一次性邀请后，你的设备将与伴侣完成配对';

  @override
  String get privateServer => '私人服务器';

  @override
  String get joining => '正在加入…';

  @override
  String get couldNotAccept => '无法接受这份邀请';

  @override
  String get incompleteCredentials => '服务器返回的配对凭证不完整';

  @override
  String get restoreHome => '恢复小家';

  @override
  String get reconnectTitle => '重新连接小家';

  @override
  String get reconnectHelp =>
      '此设备需要重新登录，如果其他设备仍处于登录状态，请使用设备登录码，恢复码适用于无法访问其他设备的情况，并会让其他设备退出登录';

  @override
  String get deviceCodeSignIn => '使用设备登录码登录';

  @override
  String get restoreExistingHome => '需要恢复已有的小家吗';

  @override
  String get recoveryHelp =>
      '无法登录时使用恢复码，恢复后所有设备都会退出登录，恢复码也会更新，伴侣仍保持登录，添加设备请使用设备登录码';

  @override
  String get recoveryCode => '恢复码';

  @override
  String get restoringAccess => '正在恢复访问…';

  @override
  String get restoreAccess => '恢复访问';

  @override
  String get invalidRecoveryCode => '恢复码已失效';

  @override
  String get notPaired => '此服务器上还没有完成配对的小家';

  @override
  String get couldNotRestore => '无法恢复小家，请重试';

  @override
  String get bringHome => '在新设备上登录';

  @override
  String get signInAnotherDevice => '登录另一台设备';

  @override
  String get deviceSignInHelp =>
      '在已登录的手机、平板或电脑上打开“我的设备”并选择“添加设备”，然后在这里输入服务器地址和登录码，其他设备会保持登录';

  @override
  String get deviceLoginCode => '设备登录码';

  @override
  String get deviceName => '设备名称';

  @override
  String get enterServerAddress => '请输入服务器地址';

  @override
  String get enterLoginCode => '请输入登录码';

  @override
  String get deviceNameLength => '设备名称长度需为 1 到 80 个字符';

  @override
  String get signingIn => '正在登录…';

  @override
  String get signIn => '登录';

  @override
  String get back => '返回';

  @override
  String get invalidDeviceCode => '登录码已过期或已使用，请在已登录设备上重新生成';

  @override
  String get couldNotSignIn => '无法登录，请检查网络后重试';

  @override
  String get openingHome => '正在打开小家';

  @override
  String get checkingSavedAccess => '正在检查已保存的登录信息…';

  @override
  String get findingHome => '正在寻找小家';

  @override
  String get chooseSignInMethod => '选择登录方式';

  @override
  String get ourConversation => '我们的聊天';

  @override
  String get playCorner => '游戏角';

  @override
  String get ourLittleHome => '我们的小家';

  @override
  String chatUnread(int count) {
    return '聊天，有 $count 条未读消息';
  }

  @override
  String get viewHome => '查看小家';

  @override
  String get retry => '重试';

  @override
  String unreadGoLatest(int count) {
    return '有 $count 条未读 · 查看最新消息';
  }

  @override
  String get messagePartner => '给伴侣发消息';

  @override
  String get sendMessage => '发送消息';

  @override
  String get retryMessage => '重试发送';

  @override
  String get myDevices => '我的设备';

  @override
  String signOutDeviceTitle(String name) {
    return '让 $name 退出登录';
  }

  @override
  String get cancel => '取消';

  @override
  String get signOutDevice => '退出此设备';

  @override
  String get refreshDevices => '刷新设备';

  @override
  String get deviceCodeCopied => '设备登录码已复制';

  @override
  String get copyLoginCode => '复制登录码';

  @override
  String get changeLanguage => '切换语言';

  @override
  String get chat => '聊天';

  @override
  String get onlineGames => '联机小游戏';

  @override
  String get life => '生活';

  @override
  String get coupleDetails => '双人信息';

  @override
  String get openCoupleDetails => '查看双人信息';

  @override
  String get saveRecoveryCodeDetails => '离开前请打开双人信息保存恢复码';

  @override
  String get lifeSpace => '我们的生活';

  @override
  String get viewLife => '查看生活';

  @override
  String get saveRecoveryCodeLife => '离开前请在生活中保存恢复码';

  @override
  String get play => '游戏';

  @override
  String get home => '小家';

  @override
  String unreadFromPartner(int count) {
    return '有 $count 条伴侣发来的未读消息';
  }

  @override
  String get openChat => '打开聊天';

  @override
  String get loginNotSaved => '此设备未能保存登录信息，请打开小家查看重新连接说明';

  @override
  String get saveRecoveryCodeHome => '离开前请在小家中保存恢复码';

  @override
  String get gamesComing => '一起玩耍的小角落\n游戏功能即将到来';

  @override
  String get youAreHome => '你们已经回到小家';

  @override
  String connectedAsRole(String role) {
    return '此设备以$role身份连接';
  }

  @override
  String homeId(String id) {
    return '小家编号：$id';
  }

  @override
  String get storageWarningRecovery => '此设备未能安全保存登录信息，请保存下方恢复码，以免应用关闭后无法登录';

  @override
  String get storageWarningDevice =>
      '此设备未能安全保存登录信息，若应用关闭，请在其他已登录设备上生成新的登录码以重新连接';

  @override
  String get couldNotReachRetry => '无法连接服务器，请重试';

  @override
  String get signOutDeviceHelp => '此设备需要新的登录码才能重新连接，其他设备会保持登录';

  @override
  String get devicesHelp => '让手机、平板和电脑连接到同一个小家，这里只会显示你自己的设备';

  @override
  String get thisDevice => '当前设备';

  @override
  String addedDate(String date) {
    return '添加于 $date';
  }

  @override
  String get addDeviceAction => '添加设备';

  @override
  String get newDeviceCodeHelp =>
      '在新设备上选择“登录另一台设备”，使用上方服务器地址和此登录码，请妥善保管，它可以访问你的账户';

  @override
  String singleUseExpires(String date) {
    return '单次使用 · 有效期至 $date';
  }

  @override
  String get chatError => '聊天暂时无法加载，请检查网络后重试';

  @override
  String get firstWords => '你们的第一句话\n发送一声问候，开启两个人的聊天日记';

  @override
  String get sending => '正在发送…';

  @override
  String get notSent => '发送失败';

  @override
  String get loading => '正在加载…';

  @override
  String get loadEarlier => '加载更早的消息';

  @override
  String get read => '已读';

  @override
  String get unread => '未读';

  @override
  String get messageTooLong => '消息最多可输入 4000 个字符';

  @override
  String get tryAgain => '重试';

  @override
  String get savedAccessError => '无法读取或验证此设备上保存的登录信息';

  @override
  String get serverAccessError => '无法连接到 Pawmate 服务器，请检查网络后重试';

  @override
  String get sessionRestoreError => '无法恢复此登录状态';

  @override
  String get requestFailed => '服务器暂时无法完成请求，请重试';

  @override
  String get invalidServerAddress => '请输入有效的 HTTP 或 HTTPS 服务器地址';

  @override
  String get invitationLinkHint => 'pawmate://pair?server=…&code=…';

  @override
  String get myDeviceName => '我的设备';

  @override
  String get uploadAvatar => '上传头像';

  @override
  String get changeAvatar => '更换头像';

  @override
  String get avatarImages => '头像图片';

  @override
  String get avatarRequired => '请先选择头像';

  @override
  String get avatarUploadError => '无法读取这张图片，请选择小于 10 MB 的 PNG 或 JPEG 图片';

  @override
  String get nickname => '昵称';

  @override
  String get nicknameHint => '想让伴侣怎么称呼你';

  @override
  String get nicknameInvalid => '请输入 1 到 32 个字符的昵称，不要包含控制字符';

  @override
  String get profileRejected => '服务器未能保存个人资料，请检查昵称和头像';

  @override
  String get yourProfile => '你';

  @override
  String get partnerProfile => '你的伴侣';
}
