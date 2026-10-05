# Weekly releases

The `Weekly release` GitHub Actions workflow publishes development snapshots to
this repository's GitHub Releases, without a separate distribution repository.
It runs every Monday at 01:17 UTC (09:17 Asia/Shanghai) and can also be started
from **Actions → Weekly release → Run workflow** on the default branch. GitHub
scheduled jobs may be delayed; their timing is not an exact-time guarantee.
The workflow must be merged into the default branch before scheduling works.

## Supported artifacts

| Component | Operating system | Architectures | Format |
| --- | --- | --- | --- |
| Flutter client | Android | armv7, arm64, x64 | APK per ABI |
| Flutter client | Linux | x64 | tar.gz of the entire bundle |
| Flutter client | Windows | x64 | ZIP of the entire bundle |
| Flutter client | macOS | x64, arm64 | ZIP containing the app |
| Gin server | Linux | x64, arm64 | tar.gz |
| Gin server | Windows | x64, arm64 | ZIP |
| Gin server | macOS | x64, arm64 | tar.gz |

The desktop client matrix is deliberately not identical to the server matrix.
Flutter 3.44.8's official Linux and Windows SDK archives are x64 only. Native
ARM64 desktop builds on these platforms need an additional, verified SDK/toolchain
strategy; running an x64 SDK on an ARM64 runner does not produce an ARM64 bundle.
macOS uses separate native runners and explicit Xcode architecture settings,
then checks the executable's architecture before packaging. iOS is excluded
until Apple signing and provisioning are configured.

When extending this matrix, verify the official Flutter SDK manifests for
[Linux](https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)
and [Windows](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json),
and the current [GitHub-hosted runner labels](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

## Release contract

1. Capture the triggering default-branch commit and create a `weekly-N` tag name,
   where `N` is the workflow run number. Rerunning the same run retains its tag.
2. Reuse the existing Flutter and Go checks through `workflow_call`. Normal
   push/PR CI remains check-only; compilation happens in the release workflow.
3. Build all packages from that same commit. Client builds pin Flutter 3.44.8;
   server builds follow `server/go.mod` and use the pure-Go SQLite driver with
   `CGO_ENABLED=0`. Matrix failures do not cancel other builders, but prevent
   publication of the snapshot.
4. Download all 13 packages, add source/run metadata and SHA-256 checksums, and
   upload them to a draft prerelease. Only make the release public after all
   uploads succeed. A retry can repair a draft; an existing public snapshot is
   never overwritten.

Build jobs have read-only repository permissions. Only the publication job has
`contents: write`, using the automatic GitHub token. No personal access token,
separate repository, or signing secrets are required for these testing snapshots.
Tags are not semantic version numbers and weekly builds never replace GitHub's
stable **Latest** release. Concurrent runs are serialized, and build artifacts
are retained for 14 days; published release assets are not automatically deleted.

## Before installing a snapshot

Android currently uses the Gradle project's debug signing configuration. Each
runner can generate a different debug key, so upgrading an existing installation
may fail with a signature mismatch. Do not uninstall until you have saved your
server URL and recovery code, or have another authenticated device available.
A permanent release keystore should be added before stable Android distribution.
The pipeline does not weaken the application's network or security configuration.

macOS packages are not Developer ID signed/notarized. Linux bundles require GTK 3
and libsecret on a system compatible with the Ubuntu 24.04 build environment.
Windows bundles need the Visual C++ runtime. Keep all desktop bundle files together.

Server packages contain only the binary, README, and `.env.example`. Keep database
files outside extracted release directories and set `PAWMATE_DATABASE_PATH` to a
persistent location before replacing the server binary. Configuration is passed
through environment variables; copying `.env.example` alone does not load it.

To verify all downloaded assets on Linux:

```bash
sha256sum --check SHA256SUMS
```

Download every listed asset first, or verify only your chosen file's matching
checksum entry. Checksums detect corruption, not publisher identity. Read the
snapshot's installation warnings and `BUILD-INFO.txt` before using it.
