import 'chat_store.dart';

/// Fails explicitly rather than pretending browser history has persisted.
Future<ChatStore> openChatStore(ChatScope scope) async =>
    throw UnsupportedError(
      'Persistent chat storage requires a native platform',
    );
