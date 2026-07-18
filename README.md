# Prem Kirana Ledger — Flutter

A full Flutter port of `prem-kirana-ledger-fixed.html` — a udhar/jama (credit
book) ledger app for a kirana store. Same features, same dark/light "marigold"
theme, native Flutter widgets and state management instead of vanilla JS + DOM.

## Getting started

```bash
# 1. Scaffold platform folders (android/ios/etc. are not included in this archive)
flutter create --project-name prem_kirana_ledger .

# 2. Install dependencies
flutter pub get

# 3. Run
flutter run
```

Requires Flutter 3.19+ (Dart 3.3+). Step 1 only needs to be run once — it
generates the `android/`, `ios/` (and optionally `web/`, `macos/`, etc.)
platform folders around the existing `lib/` and `pubspec.yaml` without
touching them.

## Project structure

```
lib/
  main.dart                     # App entry point, theme + provider wiring
  models/
    customer.dart                # Customer entity + computed balance/totals
    transaction.dart             # LedgerTransaction entity, TxnType, PaymentMode
  theme/
    app_theme.dart                # AppColors ThemeExtension (mirrors :root CSS vars)
  state/
    ledger_provider.dart          # ChangeNotifier: CRUD, filters, search, persistence
  utils/
    formatters.dart               # ₹ formatting (en-IN) + fuzzy name search (Levenshtein)
    pdf_export.dart                # jsPDF/autotable-equivalent ledger statement PDF
  screens/
    home_dashboard.dart           # Dashboard: totals, filters, search, customer list
    customer_timeline.dart        # Per-customer ledger timeline + actions
  widgets/
    customer_card.dart
    transaction_tile.dart          # Timeline tile + transaction details sheet
    add_customer_sheet.dart
    txn_form_sheet.dart            # Single UDHAR/JAMA entry sheet
    bulk_txn_sheet.dart            # Staged multi-transaction queue entry
    settings_sheet.dart
    whatsapp_preference_sheet.dart
    share_receipt_sheet.dart       # Ticket-style receipt preview
    common.dart                    # Shared sheet grabber/field-decoration helpers
```

## HTML → Flutter feature mapping

| HTML app                                   | Flutter equivalent                                   |
|---------------------------------------------|-------------------------------------------------------|
| CSS custom properties (`--brand-primary`…)  | `AppColors` `ThemeExtension`, dark/light `ThemeData`   |
| `localStorage` persistence                  | `shared_preferences` (JSON-encoded customer list)      |
| Vanilla JS DOM state / `renderHomeDashboard`| `LedgerProvider` (`ChangeNotifier`) + `Consumer`/`watch`|
| `#homeViewWrapper` / `#timelineViewWrapper` | `HomeDashboard` / `CustomerTimelineScreen` (pushed route)|
| `addCustomerModal`, `txnFormModal`, etc.    | `showModalBottomSheet` widgets in `widgets/`            |
| Webcam capture (`getUserMedia`)             | `image_picker` camera capture                           |
| jsPDF + jsPDF-autotable export              | `pdf` + `printing` packages (`utils/pdf_export.dart`)   |
| Fuzzy customer search (Levenshtein)         | Ported 1:1 in `utils/formatters.dart`                   |
| WhatsApp redirect links                     | `whatsapp_preference_sheet.dart` (per-customer toggle)  |

## Notes / follow-ups

- The original HTML mocked a phone frame purely for the design preview; this
  Flutter app is a normal full-screen app meant to run on a real device/emulator.
- Camera capture uses the device camera via `image_picker` rather than a raw
  `<video>` element — functionally equivalent, more reliable on mobile.
- WhatsApp deep-linking (`wa.me`) can be wired up with `url_launcher` if you
  want the "Send Receipt" action to actually open WhatsApp; the toggle/state
  is already in place in `LedgerProvider.updateWhatsappPreference`.
- Run `flutter pub get` before first run — dependencies are declared in
  `pubspec.yaml` but not vendored in this archive.
