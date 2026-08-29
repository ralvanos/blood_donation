/// Current plaintext JSON export format version. Bump when breaking export shape.
///
/// v1: single `donations` list + `countdown_days` + reminder fields (whole blood).
/// v2: three parallel series (`donations`, `donations_plasma`, `donations_double_red`),
///     per-type countdown keys, and `active_donation_type`.
/// v3: adds `donations_platelet` + `countdown_days_platelet` (four series total).
/// v4: adds optional `donor_number` (donor ID string; may be empty/absent).
/// v5: same data fields as v4; documents on-device encryption era. Plaintext exports
///     may include optional `export_note`. Older v1–v4 backups still import.
/// v6: donation lists may mix ISO date strings (untagged) with objects
///     `{ "date": "...", "arm": "L"|"R"|"both" }` for needle-access tags.
///
/// **PIN-protected exports** use a separate wrapper (`format: enc_export_v1`)
/// with PBKDF2 + AES-CBC. The decrypted payload is still a v1–v6 plaintext map.
const int kExportSchemaVersion = 6;

/// Wrapper format id for passphrase-protected backup files (not a schema_version).
const String kEncryptedExportFormat = 'enc_export_v1';
