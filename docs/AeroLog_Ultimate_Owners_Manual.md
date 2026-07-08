# AeroLog Ultimate — Owner's Manual
**Version 1.1.0**

AeroLog Ultimate is your logbook. You bought it once, the data lives on your device, and it works with no internet connection and no subscription. This manual explains how the app works and — just as important — exactly what the app does and does not decide for you.

---

## 1. The one rule that governs everything

**You, the pilot in command, are responsible for determining your own currency and compliance (14 CFR 91.3, 61.57).** AeroLog computes currency from the flights *you enter*. If an entry is wrong or missing, the dashboard is wrong. The app is a recordkeeping aid, not an authority. When it matters, verify against the regulations or with your instructor.

Electronic logbooks are legal: 14 CFR 61.51 does not require a paper format, and FAA Advisory Circular 120-78B recognizes electronic records and signatures. You must be able to present your records for inspection on reasonable request (61.51(i)) — the app's PDF export satisfies this. Student pilots must carry required endorsements on solo cross-country flights; a PDF export of your signed endorsements meets that requirement.

---

## 2. Getting started

1. **Set up your pilot profile** (Settings → Pilot Profile): name, certificate number, and — important — check off your **ratings** (ASEL, AMEL, instrument, etc.). Your ratings control how the currency dashboard is organized.
2. **Set your recency dates** (Settings → Pilot Recency): last flight review, last IPC if instrument-rated, and your medical (see §5).
3. **Add your aircraft**, or just start logging — aircraft are created automatically during CSV import.
4. **Import your old logbook** if you have one (§7).

---

## 3. Logging flights

Every flight records date, aircraft, route, your role, time breakdowns, landings, and conditions. Two things trip people up:

**Role matters for hours, not landings.** Log your role honestly (PIC, solo, dual received, dual given, SIC). Landings you enter on your own flight are treated as landings *you performed* and count toward landing currency regardless of role — that's the actual FAA test (sole manipulator of the controls), so your landings during dual instruction count.

**Two kinds of "night."** You may log *night time* starting at the end of evening civil twilight. But landings only count toward **night passenger currency (61.57(b))** if made between **1 hour after sunset and 1 hour before sunrise**, and they must be **full stop**. The app's "full-stop night landings" field means the 1-hour kind. A touch-and-go at night counts for nothing under 61.57(b) — the app enforces that; the 1-hour timing is on you.

**Drafts vs. finalized.** Only finalized flights count toward currency and reports. Finalized entries keep an edit-history trail if you later change them.

**Simulators.** Sessions in devices with a simulator level count approaches and holds toward instrument currency (61.57(c) permits this), but never count landings toward passenger-carrying currency.

---

## 4. The currency dashboard — how to read it

Currency is grouped **by aircraft category and class**, because that's how the regulation works: being current in a single-engine airplane does *not* make you current to carry passengers in a twin, a seaplane, or a helicopter. Each class you fly gets its own rows.

| Row | Rule | What it means |
|---|---|---|
| Passenger Carrying (Day) — per class | 61.57(a) | 3 takeoffs and landings in that class within the preceding 90 days. Night landings count toward day currency. Touch-and-goes count. |
| Passenger Carrying (Night) — per class | 61.57(b) | 3 **full-stop** landings in that class, 1 hr after sunset–1 hr before sunrise, within 90 days. |
| Tailwheel | 61.57(a)(1)(ii) | 3 **full-stop** landings in a tailwheel airplane within 90 days (day or night). |
| Instrument — per category | 61.57(c) | 6 approaches + holding within the preceding **6 calendar months**, in that category (airplane approaches don't maintain helicopter instrument currency). |
| IPC | 61.57(d) | Required once instrument currency has lapsed beyond the grace structure — shows only when relevant. |
| Flight Review | 61.56 | Valid through the **last day** of the 24th calendar month after the review. |
| Medical / BasicMed | 61.23 | See §5. |

**"Calendar months" means end of the month.** A flight review on July 5, 2024 is valid through July **31**, 2026 — not July 5. The app computes it that way.

**"Training toward" groups.** If you're logging dual received in a class you don't yet hold a rating for (say, working on your multi add-on), that class appears under *Training toward* — your landings and approaches accrue, but the label reminds you the rating isn't held yet.

**Expiration dates are live.** "Expires in 12 days" means the oldest landing/approach that currently keeps you legal is about to age out of the window.

**Flight review and IPC equivalents.** A passed checkride counts as a flight review; a completed FAA WINGS phase counts too; a passed instrument checkride counts as an IPC. Enter the date in Pilot Recency and pick the source so your record documents why the date is valid.

---

## 5. Medical: class medical or BasicMed

Pick your mode in the pilot profile:

- **Class medical (1/2/3):** enter the expiration date from your certificate. The app reminds you before it lapses.
- **BasicMed:** two separate clocks, tracked as two rows — your **physician exam (CMEC)** is valid **48 months**, and your **online medical education course** is valid **24 calendar months**. Both must be current. Enter each date; the app tracks both.

The app never computes medical duration from your age or class — you enter the dates from your paperwork.

---

## 6. Endorsements and the "second CFI" question

AeroLog is a **single-owner logbook**. Instructors who sign things for you are not "users" of your app — they're recorded the way they'd appear in a paper logbook: name, certificate number, and signature.

- **Receiving an endorsement** (flight review, solo, rating training, IPC): create it from a template, then have your instructor sign **on your device** with Apple Pencil or finger, or send a **remote signing package** for them to sign elsewhere and return.
- **An endorsement cannot be marked Signed without the signer's name and certificate number.** That's deliberate — it's what makes the record defensible.
- **CFIs using AeroLog:** you sign your students' endorsements in the app and export them; your students' records live in *their* logbooks. For **your own training** — no one may instruct or endorse themselves. Your flight review, IPC, or new-rating training must come from another appropriately rated instructor (multi-engine instruction requires an MEI). Record them exactly as any pilot would: their name and certificate number on the flight and the endorsement. Select **yourself** as the recipient when logging endorsements you receive.

---

## 7. Importing your old logbook

**CSV import** accepts LogTen, ForeFlight, MyFlightbook, and generic spreadsheet exports. The preview screen shows what was recognized and warns about duplicates and inferred values.

**Read the import warnings.** If your CSV has no full-stop landing columns, the app cannot compute night, tailwheel, or landing currency from those flights — it will tell you so rather than silently showing "not current." Fix: check your recent flights and edit full-stop counts on the ones inside your currency windows, or just note your recency dates manually.

**Duplicates:** rows with an ID from the source app are skipped if already imported. Re-importing the same generic CSV twice will duplicate flights — use merge carefully.

---

## 8. Backup and restore

**Back up regularly** (Settings → Data Management). A backup contains everything: flights, aircraft, endorsements with signatures, fuel, weight & balance, expenses, maintenance, hobbs/tach, lesson notes, and edit history. Store a copy off the device (Files/iCloud Drive/AirDrop to a computer).

- **Merge** adds anything missing without touching existing records.
- **Replace All** erases your logbook first. It means it. Back up before using it.
- Restoring onto a new device brings your pilot profile with it — the app reconciles it with the fresh install automatically.

There is no cloud account and no server. If you lose the device and have no backup, the data is gone. That's the ownership trade: your data, your responsibility.

---

## 9. Reports

- **FAA 8710 totals** for certificate applications.
- **Totals and analytics** by aircraft, airport, class, and time period.
- **PDF/CSV/JSON export** of your full logbook — this is also your "present for inspection" answer and your exit ramp: your data is never locked in.

---

## 10. What the app does NOT cover (and how to handle it)

- **Part 121/135 currency alternatives (61.57(e))**, **NVG currency (61.57(f))**, **glider towing (61.69)**, **SIC qualification (61.55)**: not built in. Most can be approximated with a **custom currency requirement** (Settings → Currency → Add Custom) — set your own window, landings, approaches, or hours, scoped to a class if needed.
- **Automatic night/day determination:** the app does not compute sunset times. You log what you flew.
- **Legal advice:** none. When in doubt: FAR/AIM, your CFI, or your FSDO.

---

## 11. Quick answers

**Why does a class show "not current" when I just flew?** Check the flight is *finalized*, on *your* pilot profile, in the *right class*, and that landings are entered (full-stop fields for night/tailwheel).

**I logged ground instruction — where is it?** Ground lessons count as soon as you save them. If you have older unfinalized ground entries from a previous version, the app will prompt you once to review and finalize them.

**I'm a CFI working on my own next rating — can I be my own student?** Not in the syllabus system (no one instructs themselves, and student profiles are separate from your logbook). Just log those flights normally as dual received with your instructor's name and certificate number — they flow into your totals, reports, and the "Training toward" currency group for that class. Structured syllabus tracking for your own training is planned for a future update.

**Why did my currency date shift to end-of-month?** That's correct — calendar-month rules run through the last day of the month.

**Can my instructor sign from their own phone?** Yes — send a remote signing package; they return it signed and you import it.

**Does my sim session help?** Approaches and holds, yes. Landings, no.

**I fly under BasicMed and the app shows two medical rows.** Correct — exam and course are separate legal requirements with different clocks.

---

*AeroLog Ultimate stores your data locally on your device. No accounts, no telemetry, no subscription. Regulatory references (14 CFR 61.23, 61.51, 61.56, 61.57, 91.3; AC 120-78B) are current as of mid-2026; regulations change — the pilot in command is responsible for compliance.*
