# blood_donation 2.1.0

Arm tags for needle access (L / R / Both) and export schema v6. Builds on 2.0.0 (multi-type tracking, encrypted storage, PIN lock).

## Highlights

- **Arm tags** — When you add a donation, optionally mark **L**, **R**, or **Both** (typical for dual-needle platelets). Skip with **Not sure**.
- **Backfill** — Tap any History row to tag or change older donations you remember.
- **Alternation hint** — After a tagged single-needle donation, Home and the picker suggest the other arm next.
- **Arm sequence** — Filter History by type to see a newest-first L / R line (untagged days show as —).
- **Eligibility matrix** — Next dates for every type from your last donation (plus any older visit that still blocks a product). After whole blood: 56 / 56 / 7 / 56 days; after plasma: 28 / 28 / 7 / 28; after platelets: 7 across; after double red: 112 across. Rolling yearly caps: 6 / 13 / 24 / 3. Wait days are locked to this table (the Settings interval stepper is gone).
- **Calendar** — Month view on Eligibility overview: donation dots, first-eligible outlines, tap a day to see what you could donate.

## Upgrade notes

- Existing donations stay date-only until you tag them
- Older plaintext backups (schema v1–v5) still import; wrong PIN on encrypted import does not wipe on-device data
- Android `versionCode` is **4** (`2.1.0+4`) so sideload upgrades from earlier 2.1.0 test APKs (`+3`) install cleanly
- Release APKs are signed with the project keystore (not in git) — attach `app-release.apk` to the GitHub Release, do not commit it

## Build

```bash
flutter pub get
flutter test
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`
