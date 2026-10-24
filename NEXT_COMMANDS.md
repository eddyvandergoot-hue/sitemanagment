# Next commands (queue)

Run top to bottom in Claude Code, started in `C:\Users\vandergoot.ed\Dev\Sitemanagment` (last command, in the pidtracker repo).
After a command is done and its build is approved: delete its section here and commit.
Rules live in AGENTS.md (auto-loaded by Claude Code, no need to tell it to read), status in PROJECT_STATUS.md, plan in ROADMAP.md.
Agents: subagents in .claude/agents/ are picked automatically by task; commands below also name them explicitly.
Model tip: default opus (medium). Mixed builds: `/model opusplan`. Save/load logic: `/effort high`. Pure layout/docs: `/model sonnet`.


## 2. Sync repo docs (right after path fix)

```bash
claude << 'EOF2'
Doc sync. No app changes. Delegate to docs-keeper if installed, else main session. Inputs: README.md + NEXT_COMMANDS.md (provided by Eddy, place in repo root), PROJECT_OVERVIEW.md (reference, delete after sync).
Rule: one topic = one file. README = index/layout/screens/file map. AGENTS = rules. PROJECT_STATUS = status. ROADMAP = plan + open decisions. MANUAL_STEPS = MS items. NEXT_COMMANDS = queue. No duplicated content; link to owning file instead.
1. Compare PROJECT_OVERVIEW.md sections 4-6, 8, 9 with AGENTS.md, PROJECT_STATUS.md, ROADMAP.md, MANUAL_STEPS.md. Report table: topic | overview says | repo file says | conflict yes/no.
2. Do NOT write future rules into AGENTS.md (pending builds add their own rules). Only move: way-of-working rules (MS items, git checkpoint, test tiers, /clear, import check SHA) -> AGENTS.md if missing; status table -> PROJECT_STATUS.md (mark items Done only if evidence in Src/build); open decisions + parked doc generator -> ROADMAP.md; MS-001 -> MANUAL_STEPS.md if missing.
3. Conflicts: don't resolve by guessing; list them, ask Eddy.
4. AGENTS.md: add "Doc map: see README.md; read ROADMAP/MANUAL_STEPS/NEXT_COMMANDS only when task says so".
5. Delete PROJECT_OVERVIEW.md. Commit "Doc sync" (or folder checkpoint if git not yet).
Report changed files + line counts.
EOF2
```

## 3. Install subagents + decision log

Place the five agent files in `.claude/agents/` and DECISIONS.md + README.md in the repo root first.

```bash
claude << 'EOF'
Files placed: .claude/agents/{powerfx-logic,powerfx-ui,verifier,reviewer,docs-keeper}.md, DECISIONS.md, README.md (updated).
1. Validate agent frontmatter (name, description, model, effort, disallowedTools). List agents you see.
2. AGENTS.md: add short section "Agents": logic changes -> powerfx-logic; presentation -> powerfx-ui; tests/pack -> verifier; logic builds reviewed by reviewer before pack; docs/status/MS items -> docs-keeper. Doc map incl DECISIONS.md (read only when task says so).
3. Adapt verifier test names to actual artifacts/*.ps1 if different; report.
4. Commit "Agents + decision log" (or folder checkpoint if no git yet).
EOF
```

## 4. Combined build (next)

```bash
claude << 'EOF'
Combined build: items 1, 3, 4 missing (2, 5 done, keep). Checkpoint first.
Delegate: PART 1 -> powerfx-logic; PART 2 + 3 -> powerfx-ui; quick tests after each part -> verifier; reviewer on PART 1 before pack; full tier + pack -> verifier; status -> docs-keeper. Do all parts; if a part fails, stop + report, don't pack partial.

PART 1 — scrHours week date picker
- Replace ddHoursYear + ddHoursWeek with dpHoursWeek: ModernDatePicker@1.0.0, same props/style as dpReportFrom (Format "dd-mm-yyyy", StartOfWeek.Monday, 256 px), at old dropdown position. No StartDate/EndDate.
- Vars: varHoursPickedDay (shown day), varHoursWeekMonday (derived). DefaultDate = Coalesce(varHoursPickedDay, Today()). No visible jump, no Reset after normal pick.
- OnChange: skip while varWeekLoading/varWeekSaving. Dirty (same JSON check as old dropdowns) -> Reset back to varHoursPickedDay + Notify, no load. Monday changed -> set vars + Select(btnReadWeek). Same week -> only varHoursPickedDay. Reset-triggered OnChange = no-op.
- DisplayMode Disabled when loading/saving/dirty.
- Label beside picker "YYYY KWxx" (KW 2 digits, ISO year = Year(monday+3), same KW formula as Hours Summary). 01-01-2027 -> "2026 KW53".
- Replace ALL refs Value(ddHoursYear...)/Value(ddHoursWeek...) (btnReadWeek, cache-hit, 7 txt DisplayMode/OnChange, btnSaveWeek DisplayMode+OnSelect guards, nav, refresh) with varLoadedWeekMonday = varHoursWeekMonday. btnReadWeek: varPendingWeekMonday = varHoursWeekMonday; keep setting varWeekLoadedISOYear/KW from monday.
- Remove year-range loading (varEntryFirstISOYear/LastISOYear sorts, varEntryYearsLoaded), lblISOYears/lblKW -> single label "Week". Zero dd refs left.

PART 2 — Hours Summary table restyle (presentation only)
- Zebra #FFFFFF / #F0F0F0. Lines #DCDCDC.
- Period total column: no fill; text #000F41 Bold; 1px left line #DCDCDC.
- 0 values in week cells + period total display "–" Normal weight. Data/export keep 0.
- Replace floating lblReportGrandTotal with Total row at table bottom (outside gallery, above footer): fill #D5EDFF, 2px top line #0303B8, Bold black; "Total" in Name col, sum per visible week col (same paging/offset as header), period total under Period total col.
- Reserve scrollbar width: header, rows, total row same right edge.

PART 3 — GEA colors app-wide (presentation only)
- Title bars, table headers, nav buttons: #0303B8, white text. Nav hover/pressed #000F41.
- Primary actions only (btnSaveWeek, btnAddtoTeam): fill #1AFF80, text #000F41 (never white), hover/pressed #18DD6E.
- Secondary actions (all Refresh, week arrows): fill white, 1px border + text #0303B8, hover fill #D5EDFF.
- Disabled all buttons: fill #E6E6E6, text #787878.
- Inputs/dropdowns: fill #F0F0F0, border #DCDCDC, focus/hover border #0303B8, selection fill #0303B8 white text. Week total cells (scrHours lblWeekTotal): fill #D5EDFF, text #000F41.
- Errors #DB1E28. Body text black.
- Replace every non-GEA color literal: #7040A0 #593080 #194296 #123273 #E8EDF5 #EEE7F5 #193F83 #EAF1FC #F4F6FA, RGBA(25,66,150), RGBA(0,120,212), RGBA(16,110,190), RGBA(231,240,252), RGBA(244,246,250) etc. Grep all hex/RGBA/ColorValue literals; map each to GEA token; leave Color.White/Black/Transparent. Report mapping table.
- Never Energetic Pink / Active Blue as fill.

AGENTS.md: replace Weekly Hours dropdown rule (part 1), Hours Summary table/accent rules (part 2), "Appbrede knopkleuren" (part 3) with GEA palette + roles + hex list.

Verify: grep 0x for all old literals; dd refs 0; Test-WeeklyCalculations (monday, KW53, no reload same week), Test-SaveRegression (guards equivalent), Test-SummaryStyle/Labels/Dates, Test-FooterRow -GeometryOnly, Measure-FontFit Inter+Arial. Pack ONE msapp, give exact path + SHA-256 + table item|Src|build. Update PROJECT_STATUS.md.
EOF
```

**Test after import:** one date picker with `2026 KW43`; Wednesday picked → loads once; same-week Friday → no reload; 01-01-2027 → `2026 KW53`; unsaved input blocks week change. Vibrant Blue headers, one green Save with dark text, white Refresh with blue border, no purple. Summary: grey/white rows, "–" for 0, blue total row aligned under columns.

## 6. Housekeeping (after combined build approved)

```bash
claude << 'EOF'
Housekeeping, no app changes. Delegate to docs-keeper.
1. PROJECT_STATUS.md: move all except current state to PROJECT_STATUS_ARCHIVE.md (never read unless asked). Keep ≤80 lines: current baseline build path+SHA, open items, open MS items, known limits.
2. AGENTS.md: rewrite as current rules only, ≤150 lines. No dates/history/superseded rules. Keep all active rules (data/keys, load/save safety, delegation, layout, GEA colors/fonts, week label format, export spec, MS steps, home screen exception). Old version -> AGENTS_ARCHIVE.md.
3. Test tiers in AGENTS.md: quick (relevant test only) per change; full suite + pack once at task end.
Report before/after line counts. Commit.
EOF
```

## 7. Landing screen + Week Report

```bash
claude << 'EOF'
Task after housekeeping. AGENTS.md auto-loaded. Read PROJECT_STATUS.md + relevant Src. Commit checkpoint.
Delegate: 1 + 2 logic -> powerfx-logic; layout/tiles/footer -> powerfx-ui; tests + pack -> verifier; reviewer before pack; docs -> docs-keeper.

1. New screen scrWeekReport, visible title "Week Report". Read-only, no writes.
- Selection: ModernDatePicker week (shows chosen day, no jump; week Mon-Sun; label "YYYY KWxx"), project dropdown (colProjectsCache), employer dropdown ("All employers" + employers derived from week data).
- Default week = current ISO week. Footer actions right: prev week / next week, Refresh (secondary style). Nav left: Home, Project / team, Hours Summary.
- Table: Name | Employer | Mon..Sun (header day + dd-mm) | Week total. Total row per day + grand total. Whole hours no trailing comma/point, "–" for 0. Hours centered.
- Rows: workers with Hours entries in week for project; employer = historical Hours.Employer. Current week only: add active Project Workers (all teams) with 0, employer = current Workers.Employer.
- Load: 1 delegated query StartsWith(EntryKey, varProjectPrefix) + 'Work Date' range Mon..Mon+7 (global var, not With-scoped). Keep 500 guard, fail closed, load states, no Patch in loaders. Local checks as Hours Summary.
- Shared week/period loading + calc logic with Hours Summary. No duplicate divergent formulas.
- GEA colors, Inter, table style as Hours Summary.

2. Hours Summary btnBuildReport: active-with-0 rows only if period includes current ISO week. Else only workers with hours.

3. New screen scrHome = StartScreen, title "Site Management". Tile grid (Vibrant Blue tiles, white text, Inter Semibold, min 200x120, wrap, no overlap): Project / team, Weekly Hours, Week Report, Hours Summary. Weekly Hours tile without loaded project/team -> Screen1 + Notify "Choose project and team first".

4. All screens: Home button left in footer (nav style). Update footer min widths, Test-FooterRow.

5. AGENTS.md: home screen exception (tiles = content, no footer actions on home); Week Report rules; active-row rule.

Quick tests per change; full suite + pack once at end. Update PROJECT_STATUS.md. Open MS items in reply. No Studio/functional pass claims.
EOF
```

## 8. Export spec (record now, build after Week Report)

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

## 9. Roadmap into repo

```bash
claude << 'EOF'
Create/replace ROADMAP.md. Read only when task says so (add to AGENTS.md). Content:
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
Open decisions: hosting local/central; who draws layout; test skid export; GEA Sans in PDFs.
Commit "Full roadmap".
EOF
```

## 10. Component library pipeline (pidtracker repo, later)

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
