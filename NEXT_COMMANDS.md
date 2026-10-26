# Next commands (queue)

Run top to bottom in Claude Code, started in `C:\Users\vandergoot.ed\Dev\Sitemanagment`.
After a command is done and its build is approved: remove its section here (history goes to NEXT_COMMANDS_ARCHIVE.md only if not already in PROJECT_STATUS_ARCHIVE.md) and commit.
Rules live in AGENTS.md (auto-loaded by Claude Code, no need to tell it to read), status in PROJECT_STATUS.md, plan in ROADMAP.md.
Agents: subagents in .claude/agents/ are picked automatically by task; commands below also name them explicitly.
Model tip: default opus (medium). Mixed builds: `/model opusplan`. Save/load logic: `/effort high`. Pure layout/docs: `/model sonnet`.


## 2b. ModernDatePicker 1.0.2

Src en de Check-WeeklySource-allow-list uitlijnen op ModernDatePicker@1.0.2 (Studio schreef 1.0.0 om naar 1.0.2); een Studio-import bevestigt de combinatie. Optioneel erbij: App checker-toegankelijkheidsmeldingen doorlopen (PROJECT_STATUS.md, Studio-bewijs). Bij punt 3 en 5 ook het logo op scrHome en scrWeekReport.

## 3. Home + logo (landing)

```bash
claude << 'EOF'
Task. AGENTS.md auto-loaded. Read PROJECT_STATUS.md + relevant Src. Commit checkpoint.
Delegate: layout/tiles/footer -> powerfx-ui; tests + pack -> verifier; docs -> docs-keeper.

1. New screen scrHome = StartScreen, title "Site Management", logo as on the other screens. Tile grid (Vibrant Blue tiles, white text, Inter Semibold, min 200x120, wrap, no overlap): Project / team, Weekly Hours, Hours Summary (Week Report tile added with the Week Report task). Weekly Hours tile without loaded project/team -> Screen1 + Notify "Choose project and team first".
2. All screens: Home button left in footer (nav style). Update footer min widths, Test-FooterRow.
3. AGENTS.md: home screen exception (tiles = content, no footer actions on home).

Quick tests per change; full suite + pack once at end. Update PROJECT_STATUS.md. Open MS items in reply. No Studio/functional pass claims.
EOF
```

## 4. Assignment periods (design: DECISIONS.md H9; MS-010 first)

Design only, not built. Build after Home. Needs MS-010 (list "Assignment Periods": AssignmentKey, ProjectKey, From = Monday, Until = Sunday, blank = open; plus migration) done, and TEST-000 (MS-005) for testing. Rules to implement: AGENTS.md, Functionele afspraken punt 3.

To-do for the build (consequences, no design yet):
- Screen1: week picker "Week" (label "YYYY KWxx"); Save team creates/reopens/closes periods; validation Until >= From and no overlap, otherwise block with a message; periods never deleted.
- Save team also writes Assignment Periods: the current pattern "1 pre-read + max 2 table-Patches" in AGENTS.md must be revisited at build time; fail-closed validation before any write stays. Active flag on Project Workers = has an open period.
- Weekly Hours row source changes from "active Project Workers" to period overlap with Monday..Sunday + any worker with stored Hours in that week. Days not worked stay blank (= 0 in totals/reports/export); the app never auto-writes 0.
- Hours Summary is Hours-based and unaffected.
- Check online the indexes on the new list's AssignmentKey/ProjectKey (MS-010).
- Test on TEST-000 (MS-005).
- Update AGENTS.md (replace the design marker by the built rule, revisit the Save team line) and PROJECT_STATUS.md.

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
