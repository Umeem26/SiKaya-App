# SiKaya

**Bookkeeping for small livestock farmers and growers, in plain Indonesian, fully offline.**

SiKaya is a Flutter app built under *Program Mahasiswa Berdampak* (a student community-impact program in Indonesia). It helps small farmers record what happens in their business (selling, buying feed, a sick animal, a loan payment) in everyday language, and turns those records into financial statements that follow the structure of **SAK EMKM**, the Indonesian accounting standard for micro, small and medium entities.

The primary users are older farmers using low-end Android phones outdoors, so the UI follows the phone's font size, uses large touch targets and avoids accounting jargon outside the formal reports.

| Home | "What happened?" | Recording a sale | Records |
| :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/beranda.png" width="200" /> | <img src="docs/screenshots/apa-yang-terjadi.png" width="200" /> | <img src="docs/screenshots/form-jual.png" width="200" /> | <img src="docs/screenshots/catatan.png" width="200" /> |

| Plain-language summary | Statement of financial position | Notes (CaLK) | Settings & backup |
| :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/laporan-ringkasan.png" width="200" /> | <img src="docs/screenshots/laporan-posisi-keuangan.png" width="200" /> | <img src="docs/screenshots/calk.png" width="200" /> | <img src="docs/screenshots/lainnya.png" width="200" /> |

| Assets & stock | Fixed asset with depreciation history | Splash | Home at the largest system font (200%) |
| :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/aset.png" width="200" /> | <img src="docs/screenshots/detail-aset.png" width="200" /> | <img src="docs/screenshots/splash.png" width="200" /> | <img src="docs/screenshots/beranda-huruf-besar.png" width="200" /> |

Screenshots and the short screen recording ([docs/demo-flow.mp4](docs/demo-flow.mp4): record a sale, Home updates) were captured automatically on an Android emulator by the integration test. **All data shown is fictional demo data** ("Peternakan Contoh Sukamaju"); it exists only in `integration_test/`, not in the app build.

## Features

- **Record events, not journal entries.** A "What happened?" screen groups 14 transaction types a farmer records (sell for cash or on credit, collect a receivable, buy feed/medicine/chicks for cash or on credit, use stock, livestock deaths, operating expenses, fixed assets, owner capital and drawings, loans, principal and interest payments) plus partial returns/reversals; depreciation and closing entries are generated automatically. Each form is rendered from a single spec table that also holds the validation rules.
- **Home** shows money in, money out, profit or loss for the month and cash on hand, with warnings for records that need checking and for an unbalanced report.
- **Records** history grouped by month, with labelled Edit and Delete buttons.
- **Assets** tab: fixed assets with photo, cost, book value, remaining useful life and the monthly depreciation history from the engine; feed/medicine/livestock stock with quantity, value and a low-stock warning. Home shows the same asset summary. The visual review (before/after, three review rounds) is in [docs/UI-REVIEW.md](docs/UI-REVIEW.md).
- **Two-layer reports.** A plain-language summary (money in/out, profit, stock value, fixed assets, payables, receivables), then formal statements: Statement of Financial Position, Income Statement, Statement of Changes in Equity and auto-generated Notes to the Financial Statements (CaLK). One combined PDF export.
- **Period closing** is non-destructive: the database is backed up, the period's profit is posted to retained earnings, and records up to the closing date are locked (corrections go through dated reversals).
- **Backup and restore** of the whole database file (with a weekly reminder), CSV export for Excel, a separate non-financial inventory list.
- **Offline only.** Data is stored in SQLite on the phone; the release manifest requests no internet permission.

## Accounting basis and limitations

- The statements and recognition rules are designed with reference to **SAK EMKM** (IAI): accrual basis, historical cost, inventory at cost with weighted-average costing, straight-line depreciation without residual value, land not depreciated, loan principal and owner capital/drawings kept out of profit.
- The rules were drafted from the SAK EMKM exposure draft; a paragraph-by-paragraph check against the final text has not been done yet.
- **Biological assets are a management policy of this app, not a rule from SAK EMKM**, which does not cover them. Chicks/seedlings are carried as livestock inventory at cost and expensed when sold or harvested; feed and medicine are expensed when used; abnormal deaths are a separate loss. The policy is disclosed in the generated notes.
- **No review by an accountant has been done yet.** Treat the reports as a bookkeeping aid, not as audited statements.

## Architecture

```
lib/accounting/   pure Dart, no Flutter imports
  engine.dart       builds the report from transactions + fixed assets
                    (balances, depreciation, weighted-average cost, review flags)
  calk.dart         generated notes to the financial statements
  tx_form_spec.dart form fields + validation per transaction type
  repository.dart   AccountingRepository: loads data, runs the engine,
                    period locking, closing, review flags
lib/database/     SQLite schema with migrations, backup/restore
lib/*.dart, lib/ui/  Flutter UI (Material 3); screens call the repository only
```

The engine is a set of pure functions over in-memory data, so the accounting rules are unit-tested without a device or database. The repository injects its database opener and backup function, so tests run on an in-memory SQLite database. The summary screen, formal statements and PDF are all rendered from the same loaded report object, so their numbers cannot drift apart.

## Tests

| Suite | Count | What it covers |
| --- | ---: | --- |
| `test/accounting/` | 100 | The worked scenarios from the spec with hand-calculated answers, report invariants (assets = liabilities + equity, the same net profit in the income statement and in equity changes, report cash = cash book), depreciation, land, closing, backup/restore, edge cases, form validation |
| `test/ui/` | 69 | Widget tests at 360dp width with font scale 1.0 and 2.0: no clipped text, tap targets of at least 48dp (Android guideline), colour contrast ratios, and record/edit/delete flows checked against engine numbers |
| `integration_test/` | 1 | One simulated day on an Android emulator, end to end (below) |

The integration test runs the real app on an emulator with fictional data: onboarding, 19 records through the UI across every transaction group (some dated in the previous month through the date picker), Home and both report layers compared with the engine's numbers and with hand-calculated cash, payables, receivables and stock, closing the previous month, checking that editing or deleting a locked record is refused, exporting the PDF (the file is checked; the OS share sheet is not opened), and "Delete all data" returning to onboarding.

Current results (Flutter 3.47.5, Dart 3.13.4): `flutter analyze` reports no issues, all 169 unit and widget tests pass, and the integration test passes on an Android 15 (API 35) emulator.

## Build and test

The Flutter project lives in `ternak_cibeusi_app/`.

```bash
cd ternak_cibeusi_app
flutter pub get
flutter analyze
flutter test                                   # unit + widget tests (also run in CI)
flutter test integration_test -d <emulator-id>  # needs a running Android emulator
flutter build apk --debug
```

`bash tool/tangkap_layar.sh <emulator-id>` re-runs the integration test in screenshot mode and regenerates `docs/screenshots/` and `docs/demo-flow.mp4`.

**Release builds** need a signing key. Create `ternak_cibeusi_app/android/key.properties` (ignored by git) with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`; without it, `flutter build apk --release` stops with an explanatory error. Release builds use R8 (code and resource shrinking). Application ID: `io.github.umeem26.sikaya`.

CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs `pub get`, `analyze` and `test` on every push and pull request to `main`. The emulator test is run locally.

## License

[MIT](LICENSE)
