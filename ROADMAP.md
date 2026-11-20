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
- v1.1 Temporary assignment / Move team (TEAM_MOVE_PLAN.md, approved) and the configurable app are planned around these; exact order with Eddy.

## Configurable app (backlog, Eddy 19-11-2026; after the consent build)

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

## Backup (note, Eddy 19-11-2026; no action now)

Backup = the existing GitHub repo + the local clone + tags/releases (v1.0.0, v1.0.1, ...). Optional later: a second git remote inside the GEA environment.

## Parked

- **WP Document Generator prototype** (browser, pdf-lib): fills Acrobat templates, photos into image fields / photo pages, attachments appended. Not published. Resume when phase 3 (workpackages) starts.

## Documenten (later)

- Werkpakketdocumenten (WR4, DECISIONS.md): aparte versie per taal (NL voor de supervisor + taal van uitvoerende fitters/team), sjablonen per taal; taalbron waarschijnlijk team/uitvoerders, dus "taal per team" heroverwegen bij de start van de WP-module. Alleen documentatie, niets gebouwd. Week Report/export: WEEKREPORT_PLAN.md.
