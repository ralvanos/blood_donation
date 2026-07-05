# 🩸 blood_donation

An **Android-only**, **offline**, standalone app to track your blood donations, view your total count, and get a configurable countdown to your next eligible donation (default **56 days**). No accounts, no APIs, no analytics — all data stays on your device.

## 🚀 The Path Forward
Due to the evolving complexities of Google Play's policies, I have decided to take a different path for **blood_donation**. Instead of a traditional closed-source Play Store release, I am opening the project to the developer community. My goal is to foster collaboration, allowing developers to contribute their expertise to create a better, more robust app that anyone can easily build and install on their Android devices.

---

## ✅ Features

* **Log donations** – Pick the date of each donation using a date picker
* **Total donations** – See how many times you've donated at a glance
* **Countdown** – View days remaining until you're eligible again
* **Next eligible date** – Clear display of when you can donate next
* **Configurable interval** – Set days between donations (default: 56 days)
* **Donation reminders** – Scheduled Android notifications when you're eligible (and optional advance reminder); catch-up notification or in-app banner if you open the app after a missed date
* **Donation history** – View and remove past donation entries
* **Statistics** – Charts and donation gap insights
* **Backup & restore** – Export and import your data as JSON
* **Dark theme** – Clean red-on-dark UI for a modern look

---

## 🛠️ Installation & Contribution

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

### Release signing (required for release APK)

Release builds use a project-specific keystore that is **not** committed to git:

1. Place (or generate) the keystore at `android/app/blood-donation.jks` (gitignored via `**/*.jks`)
2. Copy or edit `android/key.properties` (gitignored) and set `storePassword` and `keyPassword` to match your keystore before building

See Flutter's [Android deployment docs](https://docs.flutter.dev/deployment/android#signing-the-app) for generating a keystore.

```bash
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## 📂 Project Structure

* `lib/main.dart` – App entry point
* `lib/app.dart` – Material app and theme
* `lib/screens/` – Home, settings, statistics, donation history
* `lib/services/donation_storage.dart` – Storage, notifications, export/import
* `lib/widgets/` – Reusable UI components
* `android/` – Android configuration and build files
* Local data stored using `shared_preferences`

### For Developers
I welcome any constructive feedback, bug reports, or feature ideas. If you're interested in collaborating, sharing ideas, or brainstorming future improvements, I'd love to connect!
1. Clone the repository: `git clone https://github.com/ralvanos/blood_donation.git`
2. Open the project in **Android Studio (Ladybug or newer)**
3. `cd blood_donation`
4. Configure release signing (see above) or build a debug APK with `flutter build apk --debug`
5. `flutter build apk --release`
6. APK is under `build/app/outputs/flutter-apk/app-release.apk`

## 📱 How It Works

1. Add your blood donation date
2. The app calculates your next eligible date
3. A countdown shows remaining days
4. Optional reminders notify you when you're eligible again (including catch-up if you open the app after a missed date)
5. Track your history and total donations over time

---

## 🔒 Privacy

* **Local-only** — donation history and settings are stored on your device via `SharedPreferences`
* **No network** — the app does not call remote APIs or sync data to a server
* **No analytics** — no tracking, crash reporting SDKs, or advertising
* **Optional export** — JSON backup files are written only when you choose export

See [PRIVACY.md](PRIVACY.md) for a short policy suitable for Play Store prep.

---

## ✅ Manual testing checklist

Before releasing or sharing a build, spot-check:

- [ ] Add, view, and delete donations; countdown updates correctly
- [ ] Change countdown interval in settings; next eligible date recalculates
- [ ] Enable reminders; grant notification permission; eligible/advance notifications fire (or catch-up on app open)
- [ ] Deny notification permission; app still works; permission hint appears when reminders are on
- [ ] Reboot device; scheduled reminders still reschedule (boot receiver)
- [ ] Export JSON backup and import on a fresh install; data restores correctly
- [ ] Import invalid JSON; clear error message, no crash
- [ ] Release APK builds with `flutter build apk --release`

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
