# Privacy Policy

**blood_donation** is a standalone, offline Android app. This policy describes how the app handles information.

## Data collection

The app does **not** collect, transmit, or share personal data. There are no analytics, crash reporters, advertising SDKs, or backend APIs.

## Data storage

All data stays on your device:

- Donation dates, optional arm tags (L / R / Both), and history
- Optional donor number / donor ID (if you choose to save one)
- Settings (reminder preferences, statistics UI prefs; older backups may still include unused countdown-interval keys)
- Optional app PIN (stored only as a salted hash — never in plaintext)
- Exported backup files (only when you choose to save them)

**On-device encryption:** User data (donation lists, donor number, reminder settings, and related prefs) is encrypted at rest. The encryption key is kept in Android Keystore-backed secure storage (`flutter_secure_storage`). A one-time migration moves any older plaintext SharedPreferences values into the encrypted store and clears them. Backups may still include unused `countdown_days*` keys from older app versions; those values are not used for eligibility.

**Optional PIN lock:** You may enable a 4–6 digit PIN in Settings → Security. When enabled, the app asks for the PIN on open and after the configured **Auto-lock** delay (immediately on background, or after 30 seconds / 1 minute / 5 minutes). Failed attempts are briefly throttled; the app does **not** wipe your data.

**Exports:** JSON backups can be saved as **plaintext** (readable JSON, schema v1–v6) or **PIN-protected** (`format: enc_export_v1`: PBKDF2 + AES-CBC). PIN-protected files require the export PIN/passphrase to import; a wrong PIN shows an error and does not change on-device data. Treat plaintext exports like other personal documents. On-device encryption does not protect a plaintext backup you save elsewhere.

There is no cloud sync. Backup export/import uses the system file picker; the app does not upload files anywhere.

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
