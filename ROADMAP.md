# Roadmap

Plan and open decisions. Not read by Claude Code unless a task says so. Status of built items: **PROJECT_STATUS.md**; why things were decided: **DECISIONS.md**; commands still to run: **NEXT_COMMANDS.md**.

The full phased plan is still to be added (NEXT_COMMANDS.md, "Roadmap into repo"). Phase numbers below refer to that plan.

## Open decisions

| Decision | Needed for |
|---|---|
| Hosting pidtracker + 3D viewer: local or central | 3D viewer (phase 6) |
| Who draws the skid layout: supervisor or lead fitter | Configurator (phase 7) |
| Plant 3D / Navisworks export or STEP set for the first test skid | 3D viewer (phase 6) |
| Source of STEP files (GEA Inventor library / supplier / Plant 3D catalog) | Component library |
| GEA Sans allowed in generated PDFs | Workpackage documents (phase 3) |
| Employer Code = own column EmployerCode1 (unique, not required, filled by MS-019); confirm it is the CSV EmployerCode source once MS-019 is confirmed | Export CSV (EmployerCode) |

## Order after v1.0.2 (Eddy 20-11-2026)

1. Consent build (CONSENT_PLAN.md, after MS-047).
2. **Weld sticker register** directly after consent (WELDSTICKERS_PLAN.md): start/end registration by the site manager, one row per series, search sticker -> welder/employer/period. Business case: about 40 printed pages saved per series; stickers traceable for years.
3. **Certificates register** (CERTIFICATES_PLAN.md, H49): no copies or scans, only registration + authenticity check; welding certificate verified with the issuing body before it is valid.
4. Then: certificate check at weld sticker issue (WELDSTICKERS_PLAN.md par. 10).
5. **Archive option A** (H50), **configurable app** (H51), **multi business unit** (H52) and the **installation package** (H53): design only, after consent + weld stickers; sections below.
- v1.1 Temporary assignment / Move team (TEAM_MOVE_PLAN.md, approved) and the configurable app are planned around these; exact order with Eddy.

## Configurable app (backlog, Eddy 19-11-2026; scope confirmed 20-11-2026, H51; after consent + weld stickers)

Goal: one app that other GEA branches can use without code changes (good design, no behaviour change for the current site). Status: idea only; **design first, Eddy approves before any build**.

- **What moves out of the code:**
  - **AppSettings:** company name, SharePoint site URL, list names, library names (Exports, Templates, Imports), form numbers/versions (for example FOR-010.040 in the consent footer).
  - **Theme tokens:** brand colours, a named set in App.Formulas fed from settings, replacing the hex literals.
  - **Logo:** asset reference.
  - **Translations:** document titles.
  - **Templates library:** templates per branch.
- **Who reads the settings:** the app, the HTML templates and the flows (Export file, Mail draft, Import rows).
- **Fail-closed:** a missing or duplicate setting means nothing is exported or saved, with a red message, like report.primaryLanguage now.
- **Design questions** (for the design document):
  - Which settings may differ per branch, and which stay fixed (data model, keys)?
  - Can the data source connection (site and list IDs) be switched at all without Studio? Probably not: connections stay per environment or app copy.
  - How do the flows get the settings: their own AppSettings read, or app inputs?
  - Theme: Power Fx named formulas, and what the colour tests check (Test-GeaColors).
  - Migration without behaviour change: the same values as now as defaults in AppSettings.
- **Order:** after the consent build; first a design document (CONFIGURABLE_PLAN.md), then Eddy's approval, then the build in small steps with the full test set.

## Archive (Eddy 20-11-2026, H50; design only, after consent + weld stickers)

- **Option A (approved):** data stays in the same lists; nothing is moved or deleted.
  - Project close action: Status Closed + ClosedDate (written by the app on an explicit close, fail-closed like other saves).
  - Year/Archived marker (indexed column) so active screens can filter delegably.
  - Active screens filter on open projects / the current period (indexed, delegable filters; no 500-row truncation shown as complete).
  - New read-only screen **Archive**: search by project, worker, week, weld sticker and year(s). No Patch, no export changes.
  - The Exports library is the document archive (week reports, consent).
- **Option B (only if ever needed):** yearly copy to archive lists + verified removal from the active lists. Not planned.
- Design questions: which columns get the marker (Projects only, or also Hours/Assignment Periods via ProjectKey/Year), index plan per list, who may close a project, reopen allowed?

## Multi business unit (Eddy 20-11-2026, H52; design only, depends on the configurable app)

- Each BU gets its **own installation**: own SharePoint site, lists, flows and app copy. Data fully separated (no shared lists, no cross-BU reads).
- Same source code for all BUs; BU differences only through the settings of the configurable app (H51).

## Installation package (Eddy 20-11-2026, H53; design only, after H51/H52)

Goal: a new BU or site **live in one afternoon**. Deliverable: **INSTALL.md** with exact click paths plus the files below.

- **Lists:** one .xlsx per list (New > List > From Excel) + a checklist for column settings (types, choices, required, unique) and indexes.
- **Flows:** import packages for Export file, Import rows, Mail draft and Translate (Import Package > Create as new) + connections.
- **App:** .msapp with the site settings (AppSettings drive the BU specifics).
- **Templates:** HTML templates uploaded to the Templates library.
- **Data:** Translations, countries and AppSettings via the Import rows flow (CSV).
- **Studio steps:** add data sources and flows, Save, Publish.
- **Permissions:** MS-021 pattern (run-only users for flows, list permissions per role).
- **Smoke test checklist** (load, save on a TEST project, export, mail draft).

## Scale (Eddy 20-11-2026, H54)

About 6 supervisors, typical small projects of about 4 people, at most about 20 people per week. SharePoint + standard connectors are sufficient; Azure only later if real limits are hit.

## Backup (note, Eddy 19-11-2026; no action now)

Backup = the existing GitHub repo + the local clone + tags/releases (v1.0.0, v1.0.1, ...). Optional later: a second git remote inside the GEA environment.

## Parked

- **WP Document Generator prototype** (browser, pdf-lib): fills Acrobat templates, photos into image fields / photo pages, attachments appended. Not published. Resume when phase 3 (workpackages) starts.

## Documenten (later)

- Werkpakketdocumenten (WR4, DECISIONS.md): aparte versie per taal (NL voor de supervisor + taal van uitvoerende fitters/team), sjablonen per taal; taalbron waarschijnlijk team/uitvoerders, dus "taal per team" heroverwegen bij de start van de WP-module. Alleen documentatie, niets gebouwd. Week Report/export: WEEKREPORT_PLAN.md.
