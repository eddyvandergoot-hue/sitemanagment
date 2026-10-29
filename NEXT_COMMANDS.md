# Next commands (queue)

Run top to bottom in Claude Code, started in `C:\Users\vandergoot.ed\Dev\Sitemanagment`.
After a command is done and its build is approved: remove its section here (history goes to NEXT_COMMANDS_ARCHIVE.md only if not already in PROJECT_STATUS_ARCHIVE.md) and commit.
Rules live in AGENTS.md (auto-loaded by Claude Code, no need to tell it to read), status in PROJECT_STATUS.md, plan in ROADMAP.md.
Agents: subagents in .claude/agents/ are picked automatically by task; commands below also name them explicitly.
Model tip: default opus (medium). Mixed builds: `/model opusplan`. Save/load logic: `/effort high`. Pure layout/docs: `/model sonnet`.


## 1. Admin screens (plan decided 27-10-2026: ADMIN_PLAN.md; Contractors built, Studio test open)

Next: Eddy's Studio retest of the current Contractors build 20261029_221757 (v4: all messages via the notification bar, red field borders, read-only txtEmpCode; DECISIONS.md H17) with the new checks I-O (TESTPLAN.md TP-CONTRACTORS-01; build: PROJECT_STATUS.md). Build 174723 passed steps 8-11, 12a, 12b and the wide-layout alignment (29-10-2026). Eddy decides the open message points (PROJECT_STATUS.md, Contractors v4 open). MS-020 is done (28-10-2026). After approval: Projects build (powerfx-logic, reviewer, powerfx-ui, verifier; messages per H17), then Workers (incl. Weekly Hours stale-cache fix). Open points: ADMIN_PLAN.md par. 8 and 9.

Proposal (Eddy to approve, analysis 29-10-2026, PROJECT_STATUS.md Open items): Save week must not give NEW Hours rows an outdated Employer/Trade/Team snapshot. In Save week, before the first write: Refresh(Workers) + re-read colWorkersCache (<=500, staging) and Refresh('Project Workers') + Filter on ProjectKey; compare Employer.Id/Trade/Team/Active of the involved workers with the loaded values; difference = zero writes + message "Worker or team changed in SharePoint; Refresh on Project / team". Alternative: btnReadTeam and btnLoadReport always Refresh Workers/Projects (H16 app-wide). Save team and Confirm migration need no fix.

## 2b. ModernDatePicker 1.0.2

Src en de Check-WeeklySource-allow-list uitlijnen op ModernDatePicker@1.0.2 (Studio schreef 1.0.0 om naar 1.0.2); een Studio-import bevestigt de combinatie. Optioneel erbij: App checker-toegankelijkheidsmeldingen doorlopen (PROJECT_STATUS.md, Studio-bewijs). Bij punt 5 ook het logo op scrWeekReport.

## 4. Assignment periods (built 26-10-2026, waiting for Studio test; design: DECISIONS.md H9)

Built (not imported, not functionally tested, not approved): build and known limits in PROJECT_STATUS.md; rules in AGENTS.md. Waiting for the Studio tests TESTPLAN.md TP-PERIOD-01 and TP-MIGR-01 on TEST-000 (MS-005). After approval: remove this section.

Still to do:
- Check online the indexes on the new list's AssignmentKey/ProjectKey (MS-010).
- Save week: Hours.Title = EntryKey (nieuwe/bijgewerkte rijen; DECISIONS.md D7), beide table-Patches en de Save-regressietests die Title vastleggen (not part of this build).

## 4b. Project / team UX round (after TP-PERIOD-01 is approved)

Decided, not built: Screen1 cards show Workers.Title (DECISIONS.md H10); inline orange card status (card level; conflicts with H17 if it carries message text: Eddy to confirm); summary popup before Save team; migration preview popup and rename the buttons to "Eenmalige omzetting: bekijken" / "Eenmalige omzetting: uitvoeren"; uncheck meaning option B (DECISIONS.md H11) in Src, AGENTS.md rules and TESTPLAN.md.

Also decided 27-10-2026 (Eddy), not built:
- Screen1 live validation on check: an invalid card gets a red border; the reason goes in the notification bar (H17: the earlier red reason text on the card conflicts with H17 and is dropped unless Eddy decides otherwise); Save team disabled while any card is red.
- Pickers locked while unsaved changes: show a visible hint text on the picker (exception to H17: it is a control hint, not a message; Eddy to confirm) telling how to unlock: Screen1 "haal vinkje weg om te ontgrendelen"; Weekly Hours: Save or Discard changes. Reason: dpTeamWeek/dpHoursWeek are DisplayMode.Disabled when dirty, so the existing OnChange Notify "Week niet gewisseld..." is practically never seen.
- Messages (Eddy 29-10-2026, DECISIONS.md H17, replaces the earlier status-line items): ALL messages only via the notification bar (Notify): errors red, success green, one at a time, short; no message text in the form or as a status line (remove lblSelectionLoadStatus as message carrier); invalid field = red border only, the bar says what is wrong ("Fix: ... (+n more)"). Built on Contractors first.
- Migration preview result is shown ONLY in the framed popup on Screen1 (not in the notification bar, not as status text).
- The summary popup (above) must include a reopen notice ("Terug in team vanaf KWxx").
- Screen1: employer line of one card shown bold. Cause: Subtitle4.FontWeight = If(ThisItem.IsSelected, Semibold, Normal) follows the gallery's selected item, not data. Make it Normal; requires changing the AGENTS.md Subtitle4 rule and artifacts/Test-Fonts.ps1 in the UX round.
- Hours Summary pickers (TP-PERIOD-01 6.1): built in pickerfix build (PROJECT_STATUS.md); Studio test open.
- Screen1 team dropdown (ddTeam) gets an extra option "Alle teams" (Eddy 27-10-2026, not built): read-only overview of all project members with a period overlapping the picked week; each card shows its team label (e.g. "Team 2"); checkboxes and Save team disabled; hint text "Kies een team om te wijzigen". Delegable: same load as now (Project Workers and Assignment Periods filtered on ProjectKey only), no extra filter on team; team grouping is done locally.
- Guard (decided 27-10-2026, not built): a worker whose Title starts with "Test " can only be linked to project TEST-000; Save team blocks with a message.
- Language and naming (decided 27-10-2026, ADMIN_PLAN.md): Dutch messages (Notify, status lines) become English; "Employer" in existing UI text becomes "Contractor"; existing screens convert their texts to translation table T (App.Formulas, varLang default "en"). Adjust AGENTS.md and the label/font tests accordingly.
- Te beslissen bij de bouw (not decided by Eddy): behaviour of the Weekly Hours button/Home tile and the migration buttons while "Alle teams" is selected (Weekly Hours needs one team); keeping the dropdown under the 500-choice limit.

## 5. Week Report

```bash
claude << 'EOF'
Task. AGENTS.md auto-loaded. Read PROJECT_STATUS.md + relevant Src. Commit checkpoint.
Delegate: 1 + 2 logic -> powerfx-logic; layout -> powerfx-ui; tests + pack -> verifier; reviewer before pack; docs -> docs-keeper.

1. New screen scrWeekReport, visible title "Week Report". Read-only, no writes.
- Selection: ModernDatePicker week (shows chosen day, no jump; week Mon-Sun; label "YYYY KWxx"), project dropdown (colProjectsCache), employer dropdown ("All employers" + employers derived from week data).
- Default week = current ISO week. Footer actions right: prev week / next week, Refresh (secondary style). Nav left: Home, Project / team, Hours Summary. Add the Week Report tile on scrHome.
- Table: Name | Employer | Mon..Sun (header day + dd-mm) | Week total. Total row per day + grand total. Whole hours no trailing comma/point, "–" for 0. Hours centered.
- Rows: workers with Hours entries in week for project; employer = historical Hours.Employer. Current week only: add active Project Workers (all teams) with 0, employer = current Workers.Employer. (Revisit after Assignment periods: row source then follows the period rule.)
- Load: 1 delegated query StartsWith(EntryKey, varProjectPrefix) + 'Work Date' range Mon..Mon+7 (global var, not With-scoped). Keep 500 guard, fail closed, load states, no Patch in loaders. Local checks as Hours Summary.
- Shared week/period loading + calc logic with Hours Summary. No duplicate divergent formulas.
- GEA colors, Inter, table style as Hours Summary.

2. Hours Summary btnBuildReport: active-with-0 rows only if period includes current ISO week. Else only workers with hours.

3. Uitsluiting TEST- projecten/TEST Employer in Week Report, Hours Summary-export en health check implementeren (zie AGENTS.md).

4. AGENTS.md: Week Report rules; active-row rule.

Quick tests per change; full suite + pack once at end. Update PROJECT_STATUS.md. Open MS items in reply. No Studio/functional pass claims.
EOF
```

## 6. Export spec/build (build after Week Report)

```bash
claude << 'EOF'
AGENTS.md export spec. Replace old xlsx afspraak. Don't build yet.
- Week Report: per project + employer: 1 PDF (Mon..Sun table, header project number/reference/employer/week) + 1 CSV.
- Hours Summary: CSV for selected period, 1 file per selection (project + employer or all). No PDF.
- CSV spec (both): long format, 1 row per worker per stored day entry (incl stored 0), workers with total 0 excluded. Columns: ProjectNumber;ProjectReference;EmployerCode;EmployerName;WorkerID;WorkerName;Trade;WorkDate;ISOYear;ISOWeek;Hours. UTF-8 BOM (UniChar(65279)), ";" separator, "." decimal, yyyy-mm-dd. Employer = historical Hours.Employer. EmployerCode column: check Employers metadata; unclear -> ask.
- Content built in app: one shared CSV formula (Concat) for both screens; HTML for PDF in app. Export only when report valid; fail closed like Save. Primary action style (green).
- Flow = generic file writer (Power Apps V2 trigger, input JSON list {fileName, type: csv|html2pdf, content}) -> save to Exports library -> html2pdf via Convert file -> respond links. No business logic in flow. PDF fonts Arial.
- Flow + Exports library = MS items; flow code delivered from chat.
Update PROJECT_STATUS.md.
EOF
```

## 7. Roadmap into repo

```bash
claude << 'EOF'
MERGE into ROADMAP.md (do not replace). Keep the existing sections: Open decisions (incl. the EmployerCode row) and Parked (WP Document Generator). Add the plan below above them; merge open decisions into the existing table without duplicates. Content:
Principle: every module standalone; integrations optional, never required; modules talk via JSON/CSV files or optional API.
Site Management (Power Apps + Lists):
1. Hours finish: combined build, Week Report, export PDF+CSV via generic flow, housekeeping, git push.
2. Landing screen tiles + Home buttons.
3. Workpackages list (replaces look ahead planning sheet); templates/media in SharePoint libraries synced via OneDrive; documents now Excel/VBA + Acrobat Pro reading Lists; later browser pdf-lib filling same Acrobat templates + photos/attachments, Inter/GEA Sans embedded; later 3D images + QR in WP PDF.
4. Inventory = registration only: StockItems (site, location, description, article no, qty, unit, photo, last checked, Contact person column). Qty edited directly, history via SharePoint versioning. Cross-site search. Optional QR per container. Request button -> form (qty, site/project, note) -> Teams message to Contact (standard connector). No ledger, no WP link, no reservations. Later: Requests list open/done.
pidtracker extension (React + r3f/three.js):
5. Run tracing -> P&ID connectivity per tag.
6. 3D viewer standalone: opens GLB or configuration JSON; tag labels, tap for tag/DN/status; QR from WP PDF = one entry. WP PDF: generated iso/front/side/top + cut/weld lists. No 3D PDF. Test 1 hand-modelled skid.
7. Configurator (after viewer proven), standalone: full library, save/open JSON + local browser storage. Optional filter source: none | pidtracker (tags + P&ID connection check) | CSV/Excel (tag, type, DN). Placed/not-placed. Port snapping, auto pipe, cut/weld lists. Later hygienic checks.
Component library (separate, versioned): typecode (aligned with pidtracker Family-Housing), visual GLB fine + lod1 (stainless material, real actuator/pump colors), logic JSON (ports: position, direction, DN, connection type; dims; meta), parametric fallback when no GLB. Instancing. Pipe color by medium (pidtracker MediumColor or standalone picklist, aligned NEN 3050), legend always visible, weld points numbered rings, clamp accent color, tag labels toggle.
Open decisions to merge (already in the table): hosting local/central; who draws layout; test skid export; GEA Sans in PDFs.
Commit "Full roadmap".
EOF
```

## 8. Production go-live (later)

Inhoud nog vast te leggen (aanleveren door Eddy). Er is nog geen productieapp; alleen testimports tot de functies compleet zijn (PROJECT_STATUS.md).

Notitie, beheerschermen (later, Workers-scherm): Worker Contacts (MS-012) + groep Site Supervisors in het Workers-scherm; contacten alleen tonen bij toegang, zonder toegang niets en geen fout (DECISIONS.md D7).

---

## Geparkeerd (andere repo)

### Component library pipeline (pidtracker repo, later)

```bash
claude << 'EOF'
pidtracker library pipeline (folder library/), use installed FreeCAD (FreeCADCmd.exe; find path Windows/Linux).
tools/step2glb.py via FreeCADCmd: import library/step/*.step, optional exclude list per file (name patterns: bolt, screw, seal, gasket, stem, spring), tessellation deviation param. Export 2 levels: fine (0.5%) -> <typecode>.glb, light (2%) -> <typecode>.lod1.glb, into library/glb_raw/.
gltf-transform: check bbox; if mm (>10 m) scale 0.001; ensure Y-up; dedup, weld, simplify, meshopt compress -> library/glb/.
Report per file: triangles, KB, bbox m; warn >20k tris (fine) / >5k (lod1) / >500 KB.
Ports JSON template per typecode: typecode, ports[{id, position_mm, direction, dn, connection: clamp|weld|flange}], meta{family, housing, dn}. Validate schema. Typecode aligned with Family-Housing naming.
.gitignore library/step + glb_raw. Ask before committing glb.
Test: convert 1 sample STEP, load in dev page via GLTFLoader, stainless material.
EOF
```

**Manual check of one part first (FreeCAD):** Open STEP → delete internal parts → select all → File → Export → glTF (.glb) → drag into gltf.report. Check size (DN50 valve ≈ 0.1–0.3 m), actuator up, < 20k triangles, < 500 KB. Too heavy: part → Properties → View → Deviation 1–2%. Do not use Part → Thickness.

---
