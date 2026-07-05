# Privacy Policy

**blood_donation** is a standalone, offline Android app. This policy describes how the app handles information.

## Data collection

The app does **not** collect, transmit, or share personal data. There are no analytics, crash reporters, advertising SDKs, or backend APIs.

## Data storage

All data stays on your device:

- Donation dates and history
- Settings (countdown interval, reminder preferences)
- Exported backup files (only when you choose to save them)

Data is stored locally using Android `SharedPreferences`. Backup export/import uses the system file picker; the app does not upload files anywhere.

## Network access

The app does not require network access for core functionality. It does not make HTTP requests or connect to remote servers.

Optional actions may open external apps (for example, your email client for feedback). Those interactions are handled by the system and are outside this app.

## Notifications

If you enable reminders, the app schedules local notifications on your device only. No notification data is sent to third parties.

## Permissions

- **Notifications** — optional, for donation reminders
- **Boot completed** — reschedule local reminders after device restart
- **Storage / file picker** — only when you export or import a backup

## Contact

Questions about privacy: [ralvanos@protonmail.com](mailto:ralvanos@protonmail.com)

## Changes

This policy may be updated as the app evolves. The current version applies to the open-source release in this repository.
