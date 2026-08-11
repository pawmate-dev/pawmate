# Implementation plan

## 1. Create the feature branch

Run this yourself after approving the decisions in this chapter:

```bash
git switch -c feat/instance-onboarding
```

## 2. Build the Gin persistence and domain layer

1. Choose and configure the approved database.
2. Add migrations for users, couples, pairing invites, and refresh tokens.
3. Add a domain service that enforces the two-user limit in one transaction.
4. Keep HTTP handlers thin: parse input, call the domain service, return a
   documented response.
5. Add authenticated middleware before adding protected endpoints.

The pairing redemption transaction must verify all of the following together:

- the caller is not already paired;
- the invitation exists and is not expired or redeemed;
- the caller did not create the invitation;
- neither side would make the instance exceed two users;
- the invitation is marked redeemed and the couple is created atomically.

## 3. Add Flutter infrastructure

1. Create an `InstanceConfig` model containing the normalized base URL and
   instance metadata.
2. Store the configured URL locally; store access and refresh tokens only in
   platform secure storage.
3. Add an API client that attaches the access token only to protected requests.
4. Give all network states clear UI: loading, unreachable server, incompatible
   version, invalid credentials, expired invitation, and successful pairing.
5. Keep the first-launch route separate from the later home route.

Do not log authorization headers, tokens, or server URLs in release builds.

## 4. Implement the first screens

1. Server URL entry and connection test.
2. Register/sign-in screen.
3. Pairing choice: create invite or redeem invite.
4. Minimal paired home screen showing both display names.

Use the shared hand-drawn design components rather than introducing a one-off
visual style for onboarding.

## 5. Integrate in small commits

Suggested order:

```text
docs: approve the onboarding contract
server: add persistence and authentication
server: add pairing invitations
flutter: add instance configuration
flutter: add authentication and pairing flow
test: cover the complete onboarding journey
```
