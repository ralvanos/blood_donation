# blood_donation 2.0.0

Major update from 1.0.0: multi-type donation tracking, on-device encrypted storage, optional PIN lock, and export schema v5.

## Highlights

- **Four donation types** — Whole Blood, Plasma, Platelets, and Double Red, each with its own history, countdown, and volume totals
- **On-device encryption** — Donation history, donor number, and settings encrypted at rest (AES-CBC); DEK in Android Keystore via `flutter_secure_storage`; one-time migration from plaintext SharedPreferences
- **Optional PIN lock** — 4–6 digit PIN; lock on open; auto-lock Immediate / 30s / 1m / 5m
- **PIN-protected backups** — Export as plaintext JSON (schema v5) or `enc_export_v1` (PBKDF2 + AES-CBC); import accepts v1–v5 and encrypted wrappers
- **Eligibility overview** — Next eligible date for every type on one screen
- **Combined history** — Timeline with All + per-type filters
- **Statistics** — This type vs All types (multi-line chart, legend toggles, cross-type totals)
- **Smarter reminders** — Soonest eligibility across types; notification text names the type
- **Donor extras** — Optional donor number, Learn content, soft journey labels / Double Red tip

## Upgrade notes

- Existing 1.x installs migrate donation data and settings into encrypted storage on first launch after upgrade
- Older plaintext backup JSON (schema v1–v4) still imports; wrong PIN on encrypted import does not wipe on-device data
- Release APKs are signed with the project keystore (not in git) — attach `app-release.apk` to the GitHub Release, do not commit it

## Build

```bash
flutter pub get
flutter test
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`
