# 🩸 blood_donation

**Version:** 2.1.0+4 — see [RELEASE_NOTES.md](RELEASE_NOTES.md) for the changelog.

An **Android-only**, **offline**, standalone app to track your blood donations (whole blood, plasma, platelets, and double red), view your totals, and get a countdown to your next eligible donation. No accounts, no APIs, no analytics — all data stays on your device.

> **Personal tracker only.** Eligibility uses a cross-type wait matrix based on your last donation (and any older visit that still blocks a product). Donation centers set the final rules. Always confirm with your center; this app does not enforce medical policy.

## 🚀 The Path Forward
Due to the evolving complexities of Google Play's policies, I have decided to take a different path for **blood_donation**. Instead of a traditional closed-source Play Store release, I am opening the project to the developer community. My goal is to foster collaboration, allowing developers to contribute their expertise to create a better, more robust app that anyone can easily build and install on their Android devices.

---

## ✅ Features

* **Four donation types** – Whole Blood (deep red), Plasma (saffron/gold), Platelets (peach), Double Red / Power Red (maroon); switch with a scrollable segmented control on Home (order: WB → Plasma → Platelets → Double Red)
* **Log donations** – Pick the date of each donation for the active type, then optionally tag the needle-access arm (**L** / **R**, or **Both** for dual-needle platelets)
* **Arm tags** – Optional on every record; tap a History row to tag older donations you remember; type-filtered History shows a newest-first L/R sequence so you can see if you’ve been alternating
* **Total donations** – See how many times you've donated at a glance (per type), with approximate volume totals
* **Countdown** – View days remaining until you're eligible again (wait table: 56 / 28 / 7 / 112 same-type days; cross-type waits on Eligibility overview)
* **Next eligible date** – Clear display of when you can donate next
* **Eligibility overview** – Next eligible date for every type from a last-donation wait matrix (after whole blood: 56 / 56 / 7 / 56; after double red: 112 across); 4×4 wait table; month calendar
* **Combined history** – Timeline of all donations with **All** + per-type filters; each row tagged by type and optional arm
* **Donation reminders** – Scheduled Android notifications from the **soonest** eligibility across types; text names the type (e.g. “Platelets: you’re eligible again”); catch-up if you open the app after a missed date
* **Soft journey labels** – Guidance-only labels on types (e.g. “Start here / New donor”, “Frequent / Maximize impact”, “Advanced / High impact”); nothing is locked
* **Soft journey guidance** – After 1–2 whole blood donations, an optional Home hint about Double Red (advisory only)
* **Optional donor number** – Save a donor ID in Settings → Donor info; discreet Home badge to view/copy at check-in
* **Learn** – Info sheet per type, center-specific rule notes, donor journey sheet, and Settings → PFAS / toxins article
* **Statistics** – Dual mode: **This type** (single cumulative trend for the active Home type) or **All types** (multi-line chart with legend toggles, cross-type totals / volume / types used); type accent colors; last mode + legend remembered in prefs
* **Backup & restore** – Export/import JSON (`schema_version` **6**; v1–v5 imports still work). Choose **Normal** (plaintext) or **PIN-protected** (`enc_export_v1` encrypted wrapper)
* **On-device encryption** – Donation history, donor number, and settings encrypted at rest (AES-CBC blob; DEK in Android Keystore via `flutter_secure_storage`); one-time migration from older plaintext SharedPreferences
* **Optional PIN lock** – Settings → Security: 4–6 digit PIN; locks on open; configurable auto-lock (**Immediate** / **30s** / **1m** / **5m**)
* **Dark theme** – Type-tinted accents on a dark scaffold

### What’s new (brief)

Optional **L / R / Both** arm tags, a last-donation **eligibility matrix** and **calendar**, and wait days locked to that table (the Settings days stepper is gone). Export schema **v6**. Prior 2.0 work: PIN-protected export, auto-lock, on-device encrypted storage, combined history, type-named reminders, optional donor number, soft Double Red journey tip / labels, and Statistics dual mode.

### Export schema versions

| Version | Contents |
| --- | --- |
| **v1** | Whole blood only (`donations`, `countdown_days`, reminder fields) |
| **v2** | Adds plasma + double red series and `active_donation_type` |
| **v3** | Adds platelets (four series) |
| **v4** | Adds optional `donor_number` |
| **v5** | Same fields as v4; on-device encryption era. May include optional `export_note` |
| **v6** | Donation lists may mix ISO date strings with `{ "date", "arm": "L"|"R"|"both" }` |

PIN-protected files wrap a v1–v6 payload in `format: enc_export_v1` (PBKDF2-SHA256 + AES-CBC). Import accepts older plaintext v1–v6 backups and encrypted wrappers (correct PIN required; wrong PIN does not wipe on-device data).

---

## 🛠️ Installation & Contribution

Clone the repo, run the tests, and build a debug or signed release APK. Pull requests run `flutter analyze` and `flutter test` on GitHub Actions.

## 🧰 Requirements

* Flutter SDK (stable channel)
* Android SDK (via Android Studio or CLI tools)
* Android device or emulator (API 21+)

> **Note:** This project targets **Android only**. It is fully offline with no backend. Web, iOS, and desktop platform folders are not maintained.

---

## ⚙️ Setup

1. Install Flutter:
   [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)

2. Configure paths (if needed):

   * `android/local.properties` is usually auto-generated
   * If build issues occur, set:

     * `flutter.sdk`
     * `sdk.dir`

3. Install dependencies:

   ```bash
   flutter pub get
   ```

4. Run on a device/emulator (debug):

   ```bash
   flutter run
   ```

5. Unit tests:

   ```bash
   flutter test
   ```

### Release signing (required for release APK)

Release builds use a project-specific keystore that is **not** committed to git:

1. Place (or generate) the keystore at `android/app/blood-donation.jks` (gitignored via `**/*.jks`)
2. Copy or edit `android/key.properties` (gitignored) and set `storePassword` and `keyPassword` to match your keystore before building

See Flutter's [Android deployment docs](https://docs.flutter.dev/deployment/android#signing-the-app) for generating a keystore.

```bash
flutter build apk --release
```

Debug APK (no release keystore needed):

```bash
flutter build apk --debug
```

APK output: `build/app/outputs/flutter-apk/app-release.apk` (or `app-debug.apk`)

## 📂 Project Structure

* `lib/main.dart` – App entry point
* `lib/app.dart` – Material app, theme, and PIN auto-lock wiring
* `lib/models/` – Donation type, arm tags, eligibility matrix, typed donation / eligibility helpers, statistics math, export schema version
* `lib/content/` – Educational copy (Learn / PFAS / center notes / journey)
* `lib/screens/` – Home, statistics, donation history (combined + filters), eligibility overview, PIN lock
* `lib/services/donation_storage.dart` – Encrypted storage, notifications, export/import
* `lib/services/encrypted_store.dart` – AES-CBC encrypted user-data blob + plaintext→encrypted migration
* `lib/services/key_vault.dart` – Keystore-backed DEK storage (`flutter_secure_storage`)
* `lib/services/export_crypto.dart` – PIN-protected backup encrypt/decrypt (`enc_export_v1`)
* `lib/services/auto_lock_policy.dart` – Auto-lock timeout helpers
* `lib/services/pin_service.dart` – Optional PIN (salted hash in secure storage)
* `lib/widgets/` – Reusable UI components
* `test/` – Storage, eligibility matrix, statistics, encryption, and export/PIN unit tests
* `android/` – Android configuration and build files
* User data encrypted at rest; DEK in `flutter_secure_storage` (not plaintext SharedPreferences-only)

### For Developers
I welcome any constructive feedback, bug reports, or feature ideas. If you're interested in collaborating, sharing ideas, or brainstorming future improvements, I'd love to connect!
1. Clone the repository: `git clone https://github.com/ralvanos/blood_donation.git`
2. Open the project in **Android Studio (Ladybug or newer)**
3. `cd blood_donation`
4. `flutter pub get`
5. Configure release signing (see above) or build a debug APK with `flutter build apk --debug`
6. `flutter test` (optional but recommended before sharing a build)
7. `flutter build apk --release`
8. APK is under `build/app/outputs/flutter-apk/app-release.apk`

## 📱 How It Works

1. Choose Whole Blood, Plasma, Platelets, or Double Red on the Home segment control
2. Add a donation date for that type (optionally tag **L** / **R** / **Both**)
3. The app calculates your next eligible date from a fixed wait matrix (and yearly caps) — the same table shown on Eligibility overview
4. A countdown shows remaining days (accents follow the active type)
5. Optional reminders notify you using the soonest eligibility across types (titles name the type)
6. Open **History** for a combined timeline (**All**) or filter by type; tap a row to tag or change the arm; open **Eligibility overview** for the matrix, calendar, and every type’s next date
7. Optionally save a donor number in Settings; export JSON backups include all four series + donor number + arm tags (`schema_version: 6`, or `enc_export_v1` when PIN-protected)

---

## 🔒 Privacy

* **Local-only** — donation history, optional donor number, and settings stay on your device
* **Encrypted at rest** — AES-CBC user-data blob; DEK in Android Keystore-backed secure storage (migrates older plaintext prefs once)
* **Optional PIN** — Settings → Security; 4–6 digits; auto-lock Immediate / 30s / 1m / 5m; hash only (not plaintext PIN)
* **No network** — the app does not call remote APIs or sync data to a server
* **No analytics** — no tracking, crash reporting SDKs, or advertising
* **Optional export** — plaintext JSON or PIN-protected (`enc_export_v1`); protect plaintext files yourself

See [PRIVACY.md](PRIVACY.md) for a short policy suitable for Play Store prep.

---

## ✅ Manual testing checklist

Before releasing or sharing a build, spot-check:

- [ ] Switch Whole Blood / Plasma / Platelets / Double Red; countdown, volume, history, and chart follow the active type
- [ ] Statistics → **This type** shows active-type totals + single trend; **All types** shows cross-type stats, legend chips, and multi-line cumulative chart (not Whole-Blood-only numbers over an all-types chart)
- [ ] Add, view, and delete donations; countdown updates correctly (same calendar day allowed across types)
- [ ] Add a donation; choose L / R / Both or Not sure; History shows the tag; Home last-arm hint appears after a single-needle tag
- [ ] Open History → tap an older untagged row and set L or R; type filter shows newest-first arm sequence
- [ ] Open History → **All** combined timeline with type tags; filter by type; delete still works
- [ ] Open Eligibility overview; last donation is highlighted; each type shows a date from the matrix; calendar outlines first-eligible days; tap a day to see which types you could donate
- [ ] Eligibility dates match the wait table (not a Settings days control); older donations that still block a product are respected
- [ ] Enable reminders; grant notification permission; eligible/advance notifications name the type (soonest across types) or catch-up on app open
- [ ] Deny notification permission; app still works; permission hint appears when reminders are on
- [ ] Reboot device; scheduled reminders still reschedule (boot receiver)
- [ ] Save / clear optional donor number in Settings; discreet Home badge opens copy sheet
- [ ] Enable PIN in Settings → Security; app locks on cold start; Auto-lock Immediate / 30s / 1m / 5m behave as expected; change/remove PIN works
- [ ] Export JSON: Normal (plaintext, schema **6**) and PIN-protected (`enc_export_v1`); import encrypted with correct PIN; wrong PIN shows error and does not wipe data
- [ ] Upgrade from pre-encryption install: existing donations/settings migrate; plaintext prefs cleared
- [ ] Import a v1 JSON backup; whole blood restores, other series empty
- [ ] Import a v2 JSON backup; WB + plasma + double red restore, platelets empty
- [ ] Import a v3 JSON backup; four series restore without donor number
- [ ] Import a v4 JSON backup with donor_number; restores correctly under schema v6 app
- [ ] Import a v5 JSON backup; donations restore; untagged arms stay empty
- [ ] Export JSON after tagging arms; re-import preserves L / R / Both
- [ ] Import invalid JSON; clear error message, no crash
- [ ] Open Learn (info icon), journey guidance / soft labels, center-rule notes, and Settings → PFAS article
- [ ] Soft Double Red hint appears after 1–2 whole blood donations and can be dismissed
- [ ] `flutter test` passes; release APK builds with `flutter build apk --release`

---

## 📬 Feedback & Support
Questions, ideas, or bug reports are always welcome.

- **Email**: [ralvanos@protonmail.com](mailto:ralvanos@protonmail.com)

### Support the App
**blood_donation** is designed to be fully free and ad-free for everyone. Donations are completely voluntary and always appreciated. If you choose to contribute and would like recognition, I will gladly feature your name within the app.

> *"Doubt kills more dreams than failure ever will"* - Suzy Kassem

#### 💰 Voluntary Donations
- **Bitcoin**: `bc1qm0pwaxjyd809v7d606duklmcujn9sygnkgyunx`
- **Monero**: `82sVJnuXRSRGv8RnZGPhpQYssmSAQXT8aXu81CB9iifMB73HKmuMcGNWxmV5s8ELUoaHtJeY13akB7m5f6DMjCDW1mFjtKV`

---

## 📄 License
This project is open-source. Please refer to the LICENSE file for more details. (Default: MIT)
