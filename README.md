# JalStock 💧 Stock management for water bottle and jar suppliers

A Flutter Android app built for a shop owner who doesn't read or write much: big picture buttons, very few words, three languages (English / ગુજરાતી / हिंदी), and a green tick after every save.

## What it does

| Feature | Details |
|---|---|
| **Upload Excel → app learns** | Reads `.xlsx` / `.csv`. Finds the header row on its own, understands column names in English, Gujarati, Hindi and Hinglish (`Item`, `Maal`, `Jaththo`, `Khali Jar`, `Rate`, `Kharid Bhav`, `Grahak`, `Udhar`, `Tarikh`, `Nang`, `Jama`…), and works out whether each sheet is a **stock list**, a **customer list** or a **daily register**. Shows what it understood before saving anything. |
| **Water-business stock rules** | Full jars, empty jars in godown, and jars with customers are tracked separately. Sales can take empties back. Empties can be filled at the plant. |
| **Automatic minimum stock** | `min = average daily sale × days to get stock × (1 + safety %)`, learned from history. A minimum typed by hand or given in the Excel always wins. |
| **Hard rules** | You can't sell or write off more than you have, and you can't fill more jars than there are empties. |
| **Alerts** | Item finished or low (with how many to order), empties waiting to be filled, a customer keeping jars too long, money pending. |
| **Customers** | Jars held, money due, history, one-tap call, and a WhatsApp reminder already written for you. |
| **Reports** | Today / 7 / 30 days: sold, sales ₹, cash ₹, approx. profit, by item, shopping list. **Download as Excel**; the file can be uploaded back as a backup. |
| **Safe undo** | Long-press any entry to delete it. Stock is always recalculated from the opening balance plus all entries, so it can never drift. |
| **Offline** | All data stays on the phone in one JSON file. No login, no internet needed. |

## Get the APK (easiest way, no setup)

1. Create an empty GitHub repo and push this folder to it.
2. Open **Actions** → **Build Android APK**. It runs on every push, or you can start it with *Run workflow*.
3. When it finishes (about 6–8 minutes), download **JalStock-apk** from the run page and install `app-release.apk` on the phone.

The workflow creates the `android/` folder, runs the Excel-learning tests and builds the release APK.

## Build on your own computer

```bash
cd jal_stock
flutter create --org com.wolftech --project-name jal_stock --platforms android .
rm test/widget_test.dart            # default test created by flutter
flutter pub get
flutter test                        # Excel learning + rules tests
flutter run                         # phone connected by USB
flutter build apk --release         # build/app/outputs/flutter-apk/app-release.apk
```

You need Flutter 3.27 or newer (stable).

Before putting it on the Play Store, add your own signing key (`android/app/build.gradle`) and an app icon (for example with `flutter_launcher_icons`).

## Try the Excel learning

`sample/Sample_Water_Shop.xlsx` is a messy real-shop style file with three sheets:

- **Maal Stock**: a title row, Hinglish headers and a Total row
- **Grahak**: customers with jars pending and udhar (credit)
- **Hisab**: a 35-day register with Aavak / Vechan / Leak entries and dd/mm/yyyy dates

Upload it from **Upload Excel** and the app will set up 4 items, 6 customers, the full history and the learned minimum stock levels. Suppliers on "Aavak" rows are not added as customers.

## Code map

```
lib/
  main.dart                 app start, theme, first-run gate
  models.dart               Product, Customer, Entry, Settings, StockInfo
  store.dart                single data store, JSON save, stock/jar/due maths
  rules.dart                ALL stock rules + alerts (edit here to change rules)
  l10n.dart                 English / Gujarati / Hindi text
  excel/xlsx_io.dart        pure-Dart .xlsx/.csv reader + .xlsx writer
  excel/excel_learner.dart  column detection, sheet type detection, learning, import
  excel/export.dart         Excel report + blank template
  screens/                  onboarding, home, entry, stock, customers, import, reports, settings
test/learner_test.dart      tests on the sample Excel
```
