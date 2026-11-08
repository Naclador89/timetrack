# Development setup

How the toolchain was set up on the maintainer's machine (Fedora 44, GNOME/Wayland), so it can be
rebuilt from scratch. Other environments (CI, Copilot coding agent) use
`.github/workflows/ci.yml` and `copilot-setup-steps.yml` instead.

Pinned versions: **Flutter 3.47.9** (Dart 3.13.7), **Temurin JDK 21**, Android **platform 36**,
build-tools 36.0.0, NDK 28.2.13676358. If you change the Flutter version, also update
`environment.flutter` in `app/pubspec.yaml`; CI reads it from there.

## 1. Toolbox container

The host has no build tools, and `sudo` doesn't work non-interactively, so everything lives in a
Fedora toolbox. Packages are installed as container root through `podman exec`, which needs no password.

```bash
toolbox create -y -c flutter
podman start flutter
podman exec -u root flutter dnf -y install clang cmake ninja-build pkgconf-pkg-config gtk3-devel \
  xz-devel libstdc++-devel libsecret-devel jsoncpp-devel sqlite-devel git unzip zip which curl file \
  mesa-libGL-devel
```

## 2. SDKs in `~/dev/sdk/`

The home folder is shared between host and toolbox, so the SDKs are just folders:

| Folder | Content | Source |
|---|---|---|
| `~/dev/sdk/flutter` | Flutter SDK | release tarball from `storage.googleapis.com/flutter_infra_release/releases/releases_linux.json` (check the sha256) |
| `~/dev/sdk/jdk-21` | Temurin JDK 21 | `api.adoptium.net/v3/assets/latest/21/hotspot?os=linux&architecture=x64&image_type=jdk` (check the sha256). Fedora 44 ships only JDK 25 and later, which the Android tooling handles less reliably. |
| `~/dev/sdk/android` | Android SDK | `cmdline-tools` from `dl.google.com/android/repository/repository2-3.xml` (check the sha1), unpacked to `cmdline-tools/latest` |
| `~/dev/sdk/env.sh` | `JAVA_HOME`, `ANDROID_HOME`, `PATH` | written by hand (see below) |

```bash
# ~/dev/sdk/env.sh
export JAVA_HOME="$HOME/dev/sdk/jdk-21"
export ANDROID_HOME="$HOME/dev/sdk/android"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$HOME/dev/sdk/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
```

Then, inside the toolbox (`tool/dev.sh bash`):

```bash
flutter --disable-analytics && dart --disable-analytics
flutter config --no-cli-animations --jdk-dir "$JAVA_HOME" --android-sdk "$ANDROID_HOME"
yes | sdkmanager --licenses
sdkmanager --install "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358" "cmake;3.22.1"
flutter doctor     # Flutter, Android toolchain and Linux toolchain should be ✓ (Chrome isn't needed)
```

`tool/dev.sh <cmd>` runs any command in the toolbox with `env.sh` loaded.

## 3. Phone (wireless debugging)

USB inside the toolbox would need udev rules on the host, so use wireless debugging (Android 11+):

1. Phone: Settings → Developer options → **Wireless debugging** → *Pair device with pairing code*.
2. `tool/dev.sh adb pair <ip>:<pair-port>` and enter the code.
3. `tool/dev.sh adb connect <ip>:<port>` (the port shown on the Wireless debugging screen, not the pairing port).
4. `tool/dev.sh flutter devices`, then `cd app && ../tool/dev.sh flutter run -d <id>`.

## 4. Builds

```bash
cd app
../tool/dev.sh flutter build linux --release   # → build/linux/x64/release/bundle/
../tool/dev.sh flutter build apk --release     # → build/app/outputs/flutter-apk/app-release.apk
```

**Windows**: only on GitHub Actions (tag `v*` or *Run workflow*). The artifact is a portable ZIP;
unzip it and run `timetrack.exe`. SmartScreen warns once, because the build is unsigned.

**Install on Linux** (no root):
```bash
mkdir -p ~/.local/opt && rm -rf ~/.local/opt/timetrack && cp -r app/build/linux/x64/release/bundle ~/.local/opt/timetrack
# plus a launcher in ~/.local/share/applications/timetrack.desktop (Exec=$HOME/.local/opt/timetrack/timetrack)
```

**Releasing** (the apps update themselves from it, `docs/specs/updates.md`):
1. Bump `version:` in `app/pubspec.yaml` (e.g. `0.4.1+5`; the build number must grow for Android).
2. Commit, push, wait for CI to be green.
3. Tag and push: `git tag -a v0.4.1 -m "…" && tool/dev.sh git push origin v0.4.1`. CI refuses a tag
   that doesn't match the pubspec version, builds all three platforms and publishes the release with
   `SHA256SUMS` and generated notes.
4. Within a day every installed app shows the update banner (or at once: Einstellungen → App →
   Nach Updates suchen).

## 5. Android release signing

Without a keystore, release APKs are signed with the debug key. That is fine for testing, but every
machine has a different debug key, so an APK from CI can't update one built locally. For a stable key:

```bash
tool/dev.sh keytool -genkey -v -keystore app/android/app/release.jks -keyalg RSA -keysize 4096 \
  -validity 10000 -alias timetrack
cat > app/android/key.properties <<'EOF'
storeFile=release.jks
storePassword=…
keyAlias=timetrack
keyPassword=…
EOF
```

Both files are git-ignored; **back them up**, because losing the key means reinstalling the app.

**Set up on 2026-11-08** (RSA 4096, PKCS12, alias `timetrack`, random password in `key.properties`;
certificate `CN=TimeTrack, O=Naclador89`, SHA-256
`23:D0:B2:19:7F:93:57:8B:DF:92:4F:54:EA:93:34:93:B8:2E:F5:0D:48:4A:21:08:F6:2D:DA:CB:3B:75:A4:E8`).
Both files exist on the maintainer machine; the user keeps a backup. The two CI secrets are set.
Builds before that date were signed with debug keys, so switching needed one reinstall on the phone.
Since the move to the public repo (ADR 0008) the secrets are set on `Naclador89/timetrack`; the old
private repo `Naclador89/timetrack-private` still has its own copies.
For CI, add the repo secrets `ANDROID_KEYSTORE_BASE64` (`base64 -w0 app/android/app/release.jks`)
and `ANDROID_KEY_PROPERTIES` (the content of `key.properties`).

## 6. Local Nextcloud for integration tests

A throwaway Nextcloud in podman (SQLite, admin login, only on 127.0.0.1). Tests never touch the
user's real Nextcloud.

```bash
podman run -d --name tt-nextcloud -p 127.0.0.1:8089:80 \
  -e SQLITE_DATABASE=nextcloud -e NEXTCLOUD_ADMIN_USER=admin -e NEXTCLOUD_ADMIN_PASSWORD=tt-test-admin-pw \
  -e NEXTCLOUD_TRUSTED_DOMAINS="localhost 127.0.0.1" docker.io/library/nextcloud:stable
# wait until `curl -u admin:tt-test-admin-pw -X PROPFIND http://127.0.0.1:8089/remote.php/dav/files/admin/` answers 207
cd packages/core
NEXTCLOUD_URL=http://127.0.0.1:8089 NEXTCLOUD_USER=admin NEXTCLOUD_PASSWORD=tt-test-admin-pw \
  ../../tool/dev.sh dart test test/integration
podman stop tt-nextcloud    # podman start tt-nextcloud to reuse it
```

Without these variables the integration tests are skipped (also in CI).
