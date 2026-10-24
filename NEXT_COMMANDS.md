# Next commands (queue)

Run top to bottom in Claude Code, started in `C:\Users\vandergoot.ed\Dev\Sitemanagment` (last command, in the pidtracker repo).
After a command is done and its build is approved: delete its section here and commit.
Rules live in AGENTS.md (auto-loaded by Claude Code, no need to tell it to read), status in PROJECT_STATUS.md, plan in ROADMAP.md.
Agents: subagents in .claude/agents/ are picked automatically by task; commands below also name them explicitly.
Model tip: default opus (medium). Mixed builds: `/model opusplan`. Save/load logic: `/effort high`. Pure layout/docs: `/model sonnet`.


## 1. Housekeeping (next, before testing the combined build)

```bash
claude << 'EOF'
Housekeeping, no app changes. Delegate to docs-keeper.
1. PROJECT_STATUS.md: move all except current state to PROJECT_STATUS_ARCHIVE.md (never read unless asked). Keep ≤80 lines: current baseline build path+SHA, open items, open MS items, known limits.
2. AGENTS.md: rewrite as current rules only, ≤150 lines. No dates/history/superseded rules. Keep all active rules (data/keys, load/save safety, delegation, layout, GEA colors/fonts, week label format, export spec, MS steps, home screen exception). Old version -> AGENTS_ARCHIVE.md.
Report before/after line counts. Commit.
EOF
```

## 2. Combined build: verify + import (no rebuild)

The combined build (week picker, table restyle, GEA colors) was built on 22-10-2026; Src already contains it.

```bash
claude << 'EOF'
Combined build check. No app changes, no rebuild, no pack. Delegate to verifier.
1. Verify Src contains parts 1-3 with grep evidence: part 1 week picker (dpHoursWeek, lblHoursWeekKW, 0 refs ddHoursYear/ddHoursWeek, no year-range loading); part 2 Hours Summary restyle (zebra #F0F0F0, "–" for 0, galReportTotalWeeks total row, Width-616); part 3 GEA colors (recHoursHeaderBar, 0 old literals #7040A0 #593080 #194296 #123273 #E8EDF5 #EEE7F5 #193F83 #EAF1FC #F4F6FA and old RGBA values).
2. Confirm Src is byte-equal to artifacts/combined-gea-20261022_134040/source/Src.
3. Name the existing build: artifacts/combined-gea-20261022_134040/SiteManagement_CombinedGea_20261022_134040.msapp + SHA-256 (recorded: C7616A268B6B6FF7F303F8E88C9C33D63B12674641EC598950BB5E338FCE3B6C).
Report table part | evidence. Update PROJECT_STATUS.md only if something differs.
EOF
```

Then Eddy imports this build, tests and approves. After approval: record it in PROJECT_STATUS.md (docs-keeper) and delete this section.

**Test after import:** one date picker with `2026 KW43`; Wednesday picked → loads once; same-week Friday → no reload; 01-01-2027 → `2026 KW53`; unsaved input blocks week change. Vibrant Blue headers, one green Save with dark text, white Refresh with blue border, no purple. Summary: grey/white rows, "–" for 0, blue total row aligned under columns.

## 3. Landing screen + Week Report

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

## 4. Export spec (record now, build after Week Report)

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

## 5. Roadmap into repo

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

## 6. Component library pipeline (pidtracker repo, later)

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
