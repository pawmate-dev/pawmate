import 'chat_store.dart';
import 'chat_store_unavailable.dart'
    if (dart.library.io) 'native_chat_store.dart'
    as platform;

/// Opens the platform cache without putting native FFI into browser builds.
Future<ChatStore> openChatStore(ChatScope scope) =>
    platform.openChatStore(scope);
