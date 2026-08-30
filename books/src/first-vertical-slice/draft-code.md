# Draft implementation code

This page contains the first code to copy into the feature branch. It is a
starting point, not a completed security implementation. Review the database,
password hashing, token signing, and error policy before adapting it.

## Flutter dependencies

Add these packages from the Flutter project root:

```bash
flutter pub add http flutter_secure_storage
```

`http` performs discovery requests. `flutter_secure_storage` keeps login tokens
out of ordinary preferences. The instance URL itself is not a secret and may be
stored separately later.

## Flutter: discover an instance

Create `lib/features/onboarding/instance_api.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

class InstanceInfo {
  const InstanceInfo({
    required this.apiVersion,
    required this.id,
    required this.name,
    required this.features,
  });

  factory InstanceInfo.fromJson(Map<String, dynamic> json) {
    return InstanceInfo(
      apiVersion: json['api_version'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      features: List<String>.from(json['features'] as List<dynamic>),
    );
  }

  final String apiVersion;
  final List<String> features;
  final String id;
  final String name;
}

class InstanceApi {
  InstanceApi(this._client);

  final http.Client _client;

  void close() => _client.close();

  Future<InstanceInfo> discover(String rawURL) async {
    final baseURL = Uri.parse(rawURL.trim());
    if (!baseURL.hasScheme || !baseURL.hasAuthority) {
      throw const FormatException('Enter a complete server URL.');
    }

    final response = await _client
        .get(baseURL.resolve('/api/v1/instance'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError('The server could not be verified.');
    }

    final instance = InstanceInfo.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (instance.apiVersion != 'v1') {
      throw StateError('This Pawmate server is not compatible with this app.');
    }
    return instance;
  }
}
```

The Android emulator reaches a server on the development machine through
`http://10.0.2.2:8080`, not `http://localhost:8080`.

## Flutter: initial URL form

Create `lib/features/onboarding/instance_setup_page.dart`. This deliberately
keeps routing out of the widget; the successful callback can later save the
configuration and move to authentication.

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'instance_api.dart';

class InstanceSetupPage extends StatefulWidget {
  const InstanceSetupPage({super.key, required this.onConnected});

  final ValueChanged<InstanceInfo> onConnected;

  @override
  State<InstanceSetupPage> createState() => _InstanceSetupPageState();
}

class _InstanceSetupPageState extends State<InstanceSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _api = InstanceApi(http.Client());
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });
    try {
      final instance = await _api.discover(_urlController.text);
      if (!mounted) return;
      widget.onConnected(instance);
    } on FormatException catch (error) {
      setState(() => _errorMessage = error.message);
    } on Object {
      setState(() => _errorMessage = 'Could not connect to that Pawmate server.');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Connect your little home',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  const Text('Enter the URL of your private Pawmate server.'),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _urlController,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Server URL is required.'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://pawmate.example.com',
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isConnecting ? null : _connect,
                    child: Text(_isConnecting ? 'Connecting…' : 'Connect'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Replace `Scaffold`, `TextFormField`, and `FilledButton` with the shared
hand-drawn widgets once those components exist; the networking code should not
change.

## Gin: request and response types

Add `server/internal/httpapi/auth.go`. The handler depends on an interface so
the HTTP contract can be tested before the final SQLite implementation exists.

```go
package httpapi

import (
    "context"
    "errors"
    "net/http"

    "github.com/gin-gonic/gin"
)

var ErrCapacityReached = errors.New("instance capacity reached")

type RegisterInput struct {
    DisplayName string `json:"display_name" binding:"required,min=1,max=40"`
    Password    string `json:"password" binding:"required,min=12,max=128"`
}

type Session struct {
    AccessToken  string `json:"access_token"`
    RefreshToken string `json:"refresh_token"`
}

type AuthService interface {
    Register(context.Context, RegisterInput) (Session, error)
}

func registerHandler(service AuthService) gin.HandlerFunc {
    return func(c *gin.Context) {
        var input RegisterInput
        if err := c.ShouldBindJSON(&input); err != nil {
            c.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
            return
        }

        session, err := service.Register(c.Request.Context(), input)
        switch {
        case errors.Is(err, ErrCapacityReached):
            c.JSON(http.StatusConflict, gin.H{"error": "registration_closed"})
        case err != nil:
            c.Error(err)
            c.JSON(http.StatusInternalServerError, gin.H{"error": "internal_error"})
        default:
            c.JSON(http.StatusCreated, session)
        }
    }
}
```

Before committing, run `gofmt -w internal/httpapi/auth.go`; the book displays
spaces for readability, but Go source must be formatted with `gofmt`.

## Gin: add the route

Update `NewRouter` only after an `AuthService` implementation is available.
Pass dependencies explicitly instead of creating database connections inside a
handler:

```go
type Dependencies struct {
    Auth AuthService
}

func NewRouter(cfg config.Config, logger *slog.Logger, deps Dependencies) *gin.Engine {
    // Existing middleware and public routes stay unchanged.
    // ...
    api := router.Group("/api/v1")
    api.GET("/instance", instanceHandler(cfg))
    api.POST("/auth/register", registerHandler(deps.Auth))
    return router
}
```

Update all existing router tests to supply a fake `AuthService`. This makes
capacity and error behavior deterministic without requiring a database for every
HTTP test.

## Gin: pairing transaction shape

The repository method must perform pairing atomically. The following is the
essential shape for a SQLite-backed implementation; adapt table and driver
details after approving the persistence choice.

```go
func (store *Store) RedeemInvite(ctx context.Context, userID, code string) error {
    return store.withTransaction(ctx, func(tx *sql.Tx) error {
        invite, err := store.findActiveInviteForUpdate(ctx, tx, hashCode(code))
        if err != nil {
            return err
        }
        if invite.CreatorUserID == userID {
            return ErrCannotRedeemOwnInvite
        }
        if err := store.assertUnpaired(ctx, tx, userID); err != nil {
            return err
        }
        if err := store.assertUnpaired(ctx, tx, invite.CreatorUserID); err != nil {
            return err
        }
        if err := store.createCouple(ctx, tx, invite.CreatorUserID, userID); err != nil {
            return err
        }
        return store.markInviteRedeemed(ctx, tx, invite.ID)
    })
}
```

`findActiveInviteForUpdate` must reject expired and previously redeemed codes.
For SQLite, write transactions serialize writers; still test two concurrent
redemption attempts and ensure only one succeeds.

## Current inviter implementation

The repository now has a process-local implementation in
`server/internal/pairing/service.go` and HTTP adapters in
`server/internal/httpapi/pairing.go`:

```text
POST /api/v1/pairing/invites
  {"server_url":"https://home.example.com"}
  -> {"invite_url":"pawmate://pair?...", "inviter_token":"...", "expires_at":"..."}

GET /api/v1/pairing/invites/status
  Authorization: Bearer <inviter_token>

POST /api/v1/pairing/invites/redeem
  {"code":"..."}
```

The Flutter inviter screen is
`lib/features/pairing/inviter_setup_page.dart`, backed by
`lib/features/pairing/pairing_api.dart`. It validates the configured URL,
creates the invite, displays the link, copies it to the clipboard, and checks
pairing status.

This is intentionally a development baseline: pairing state is protected by a
mutex but lives only in the Gin process. A restart invalidates the invitation
and pairing state. Before production, replace the service storage with the
SQLite schema and authenticated accounts described earlier in this chapter.
