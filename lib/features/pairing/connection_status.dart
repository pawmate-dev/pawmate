import '../../l10n/generated/app_localizations.dart';

/// Separates an unreachable instance from a reachable instance rejecting access.
enum ConnectionStatus { checking, online, offline, unauthorized }

/// Localizes status at render time so changing language updates existing notices.
String connectionLabel(AppLocalizations l10n, ConnectionStatus status) =>
    switch (status) {
      ConnectionStatus.checking => l10n.checkingConnection,
      ConnectionStatus.online => l10n.connectionOnline,
      ConnectionStatus.offline => l10n.connectionOffline,
      ConnectionStatus.unauthorized => l10n.connectionUnauthorized,
    };
