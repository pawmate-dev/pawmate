Weekly development snapshot, not a stable release. All CI checks and build jobs
must succeed before this prerelease is published.

Choose `client` for the Flutter application or `server` for the Gin backend.
Asset names include the operating system and CPU architecture; `x64` means
x86-64/AMD64. Extract entire desktop bundles, including libraries and data.
Server archives include configuration examples, never databases or credentials.

## Installation caveats

- Android APKs currently use the project's debug signing configuration. These
  are testing builds, not Play Store releases. A new CI runner may use a different
  key, so Android may require uninstalling a previous build before installation.
  Uninstalling removes local app data: keep your server URL and recovery code,
  or use an existing device to generate a new device login code.
- macOS applications are not Developer ID signed or notarized. Only run snapshots
  you trust; Gatekeeper may require explicitly approving the application.
- Linux desktop bundles require compatible system GTK 3 and libsecret libraries
  and are built on Ubuntu 24.04. They are not fully static executables.
- Windows desktop bundles require the Microsoft Visual C++ runtime.
- iOS installable packages require Apple signing/provisioning and are not included.

See `BUILD-INFO.txt` for the source commit and build run. Verify downloads with
`SHA256SUMS` (for example, `sha256sum --check SHA256SUMS` after downloading all
listed files). Checksums detect damaged downloads; they are not signatures.
