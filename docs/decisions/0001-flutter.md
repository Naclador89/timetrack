# 0001: Flutter (Dart) for all platforms

- Status: accepted (2026-11-07)

## Context
The app must run on Linux (Fedora/GNOME), Windows and Android, ideally from one codebase, with good
offline storage and access to platform features (notifications, Android tile and widget, watch bridge).

## Decision
Use **Flutter** with Dart, SQLite through **drift**, and state management with **Riverpod**.

## Consequences
- One codebase with native builds; desktop support is mature.
- Windows builds need Windows (Flutter can't cross-compile), so they run on GitHub Actions (ADR 0005).
- Platform features without a Dart plugin (Quick Settings tile, Connect IQ SDK) need small Kotlin bridges.
- Alternatives considered: Kotlin Multiplatform (the JVM desktop app feels less native on Linux),
  Tauri 2 (Android support less mature).
