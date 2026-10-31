# Next commands (queue)

Run top to bottom in Claude Code, started in `C:\Users\vandergoot.ed\Dev\Sitemanagment`.
After a command is done and its build is approved: remove its section here (history goes to NEXT_COMMANDS_ARCHIVE.md only if not already in PROJECT_STATUS_ARCHIVE.md) and commit.
Rules live in AGENTS.md (auto-loaded by Claude Code, no need to tell it to read), status in PROJECT_STATUS.md, plan in ROADMAP.md.
Agents: subagents in .claude/agents/ are picked automatically by task; commands below also name them explicitly.
Model tip: default opus (medium). Mixed builds: `/model opusplan`. Save/load logic: `/effort high`. Pure layout/docs: `/model sonnet`.

## 1. Admin screens (plan: ADMIN_PLAN.md; Contractors approved 29-10-2026; canvas components steps 1-3 built)

Done: Contractors approved (tag approved-20261029-contractors); AGENTS.md "Admin screen pattern" (components mandatory, H19, H20); MS-023 templates merged (30-10-2026); logic fixes 4, 5, a, d, e (commit f500822); step 1 report (below); step 2 components (TP-COMP-01 PASS 30-10-2026); step 3 built 31-10-2026 (Contractors cceb635, Projects 34bbe2b; build components-20261031_074310, PROJECT_STATUS.md; layout items 1-7 delivered by the components).

**Now: waiting for Eddy's Studio test TESTPLAN.md TP-STEP3-01** (also the retest of TP-STYLE-01 and TP-PROJECTS-01). Do not start the next steps before Eddy's OK. After OK (approval and tag per AGENTS.md): (1) Home build (cmpTile, Assets/Icons, ADMIN_PLAN.md par. 11; block below), (2) Workers build (step 4, with H18 and the N3 fix; item 1 at the end). Open from the reviewer: N1 (control read after a Patch error before assuming zero writes), N3 (an unchanged Status/Country outside the list is re-patched; logic task).

Step 1 result (30-10-2026, report only; source: template definitions + Studio-assigned rules in the MS-023 save; pac pack of a throwaway test screen in a scratch worktree): pac pack also accepts NON-existing properties (Fill on ModernToggle packed fine), so pack proves nothing; Check-WeeklySource (template property check) and Studio import are the real checks.
- ModernToggle 1.0.1: only Checked/Default/Label/LabelPosition/ToggleSize/OnCheck/OnUncheck; no colour or font property (theme-driven) -> #0303B8/#B4B4B4 and Inter not settable per control. Recommendation: keep own switch (or change the app modern theme later, affects all modern controls).
- ModernSpinner 1.1.0: SpinnerColor + TrackColor + Width/Height -> white on #0303B8 possible. Recommendation: USE (replaces the animated SVG image).
- ModernBadge 1.0.0: Appearance/Intent/Shape only, no Fill/Color -> #1AFF80/#E6E6E6 not possible. Recommendation: keep own chip (Classic/Button).
- HtmlViewer 2.1.0 (HTML text): HtmlText, Font, Size, Color, Fill, AutoHeight, borders -> inline CSS (Inter, #DB1E28 star, bold head). Recommendation: USE for label+star and message bar.
- ModernTextInput 1.1.2 / ModernDropdown 1.0.3: theme-driven like Toggle. Recommendation: keep Classic/TextInput and Classic/DropDown (GEA styling already done). Notes: canvas components in SourceCode layout must use a schema Microsoft documents (component definitions in Src, check pa.yaml docs and pac 2.11.2 support before building; Studio import is the first check); component input/output/behavior properties must be documented property kinds. Layout items 1-7 were delivered through the components in step 3 (Test-Layout built).

**Queued by Eddy 30-10-2026, after step 3 is approved** (orchestrator decision: separate small build after step 3 is approved, before the Workers build of step 4, so Home and Workers are tested and approved separately):

```bash
claude << 'EOF'
Queue after step 3 (same build as Workers or separate small build, your call):
- cmpTile component: square 190, fill #0303B8, icon 56 white top-left, label bottom-left 18 medium white, arrow bottom-right; hover/pressed fill #000F41 (icon+arrow #1AFF80 if feasible); Soon variant grey #E6E6E6, icon #9B9B9B, "SOON" top-right, no arrow, inert.
- Home redesign per earlier block (Eddy 30-10): stacked categories full width, header + 2px #0303B8 line + horizontal tile row. Order: Team & hours, Master data, Inventory, CAD tools, Knowledge. Replaces 4-column home.
EOF
```

Home redesign spec (Eddy 30-10-2026, approved mockup; full text also in ADMIN_PLAN.md par. 11):

```bash
claude << 'EOF'
Home redesign spec (Eddy 30-10, approved mockup). For cmpTile + Home build (after step 3 approved, before Workers). Save in NEXT_COMMANDS / ADMIN_PLAN.
Replaces current 3/4-column home.

Page: bg white. cmpTitleBar title "Site Management". Content padding 32/40. Vertical scroll if taller than screen.
Categories stacked vertically, full width, gap 32. Each category:
- header text 16 semibold #000F41
- line 2px #0303B8 directly under header (8 px gap), full content width
- tile row 12 px below line: tiles horizontal, gap 10, wrap to next line when no room.

Order + tiles (active = navigates; soon = inert):
1 Team & hours: Project / team (active, scrTeam/Screen1), Weekly hours (active, scrHours), Hours summary (active, scrWeeklyHours), Week report (soon)
2 Master data: Contractors (active), Projects (active), Workers (soon until Workers build)
3 Inventory: Stock overview (soon), Locations (soon), Requests (soon)
4 CAD tools: 3D viewer (soon), P&ID tracker (soon), Component library (soon)
5 Knowledge: Knowledge base (soon; later Launch(KB URL named formula))
Removed from home: Skid configurator, Usage, Employers tile (now Contractors).

cmpTile (props: Label, Icon, Active bool, OnSelect event):
- 190x190 square, radius 0, padding 20.
- Active: fill #0303B8; icon 56 px white top-left; label bottom-left white 18 semibold (HTML text font-weight 500 ok), max 2 lines; arrow -> 28x20 white bottom-right.
- Hover/pressed/focus: fill #000F41; icon + arrow #1AFF80 if feasible, else white (report).
- Soon: fill #E6E6E6; icon #9B9B9B; label #6B6B6B; "SOON" 11 semibold uppercase #5A5A5A top-right; no arrow; DisplayMode disabled, no OnSelect.
- Icons: thin line style, same stroke for all. Suggested: team=two people, weekly hours=clock, hours summary=bar chart, week report=calendar, contractors=building, projects=clipboard, workers=hard hat, stock=warehouse, locations=map pin, requests=chat bubble, 3D viewer=cube, P&ID tracker=valve/diagram, component library=grid of shapes, knowledge=open book. Report which icon used per tile.

Responsive: >=1000 px tiles 190; 700-999 px tiles 160 (icon 48, label 16); <700 px tiles 2 per row width (screen-padding-gap)/2. Never overlap, never clip label.
Test TP-HOME-02: active tiles navigate, soon tiles inert, hover/pressed colors, wrap at ~900 and ~700 px, Home button on every screen returns here.
EOF
```

Decided after the spec (Eddy 30-10-2026): icons = Assets/Icons set v1 (README mapping; white for active, grey for Soon; icon-arrow.svg), no built-in icons on tiles; hover FINAL = fill #000F41, icon + arrow stay white. Embedding: named formula per icon with a data-URI (orchestrator choice; see ADMIN_PLAN.md par. 11). Build notes (orchestrator): Screen1 keeps its internal name (AGENTS: internal screen names stay; "scrTeam" is not a rename). Weekly hours tile keeps the existing guard (project/team loaded, else Navigate(Screen1) + message). Icons: Classic/Icon 2.5.0 has a fixed enum (no hard hat, warehouse, valve, cube?) and no stroke control; "thin line, same stroke" may need inline SVG images (one style, white/#9B9B9B/#1AFF80 variants via data-URI with a colour parameter) — check the enum first and report per tile. Hover icon colour: an icon/image inside the tile cannot read the button's hover state; feasible only if the tile is a component with its own hover tracking (no hover event exists in canvas) -> likely "else white" (report). Wrapping tile row: use a horizontal AutoLayout GroupContainer with LayoutWrap or a flexible-height gallery (WrapCount) — no manual X estimates. "18 medium": Inter has no Medium in Power Apps (use Semibold, or HtmlViewer font-weight:500 if the label is HTML). Existing Home tests (tiles, 4-column layout) must be rewritten. Tile hover icon colour change needs an icon control whose Color follows hover state of the tile button (check feasibility).

After the Home build, in this order:
1. Workers build (step 4; powerfx-logic, reviewer, powerfx-ui, verifier; after step 3 and the Home build are approved) on the Admin screen pattern with the five components (AGENTS.md; only fields and rules differ; ADMIN_PLAN.md par. 5), including the Weekly Hours stale-cache fix (DECISIONS.md H18, approved 29-10-2026, status "approved, not built"): in Save week, before the first write, Refresh(Workers) + re-read colWorkersCache (<=500, staging) and Refresh('Project Workers') + Filter on ProjectKey; compare Employer.Id/Trade/Team/Active of the involved workers with the loaded values; difference = zero writes + message "Worker or team changed in SharePoint; Refresh on Project / team". Save team and Confirm migration need no fix. Decision pending: ADMIN_PLAN.md 4.5 (hide Closed projects on Screen1) and 5.5 (inactive workers).

## 2b. ModernDatePicker 1.0.2

GEBOUWD 30-10-2026 in build components-20261030_135641 (Src en Check-WeeklySource op 1.0.2; 1.0.0 wordt geweigerd); Studio-hertest: TESTPLAN.md TP-COMP-01 stap 9. Optioneel erbij: App checker-toegankelijkheidsmeldingen doorlopen (PROJECT_STATUS.md, Studio-bewijs). Bij punt 5 ook het logo op scrWeekReport.

## 4. Assignment periods (built 26-10-2026, waiting for Studio test; design: DECISIONS.md H9)

Built (not imported, not functionally tested, not approved): build and known limits in PROJECT_STATUS.md; rules in AGENTS.md. Waiting for the Studio tests TESTPLAN.md TP-PERIOD-01 and TP-MIGR-01 on TEST-000 (MS-005). After approval: remove this section.

Still to do:
- Check online the indexes on the new list's AssignmentKey/ProjectKey (MS-010).
- Save week: Hours.Title = EntryKey (nieuwe/bijgewerkte rijen; DECISIONS.md D7), beide table-Patches en de Save-regressietests die Title vastleggen (not part of this build).

## 4b. Project / team UX round (after TP-PERIOD-01 is approved)

Decided, not built: Screen1 cards show Workers.Title (DECISIONS.md H10); inline orange card status (card level: it is a state, not a message, so it stays; decided 29-10-2026); summary popup before Save team; migration preview popup and rename the buttons to "Eenmalige omzetting: bekijken" / "Eenmalige omzetting: uitvoeren"; uncheck meaning option B (DECISIONS.md H11) in Src, AGENTS.md rules and TESTPLAN.md.

Also decided 27-10-2026 (Eddy), not built:
- Screen1 live validation on check: an invalid card gets a red border; the reason goes in the red notification bar (H17; the red reason text on cards is dropped, decided 29-10-2026: red card border + reason in the bar); Save team disabled while any card is red.
- Pickers locked while unsaved changes: show a visible hint text on the picker (exception to H17: it is a control hint, not a message; Eddy to confirm) telling how to unlock: Screen1 "haal vinkje weg om te ontgrendelen"; Weekly Hours: Save or Discard changes. Reason: dpTeamWeek/dpHoursWeek are DisplayMode.Disabled when dirty, so the existing OnChange Notify "Week niet gewisseld..." is practically never seen.
- Messages (Eddy 29-10-2026, DECISIONS.md H17, replaces the earlier status-line items; admin screens already use their own message bar, H19, and 4b decides whether the other screens take over that bar instead of Notify): ALL messages only via the notification bar (Notify): errors red, warnings orange, success green (no Information), one at a time, short; no message text in the form or as a status line (remove lblSelectionLoadStatus as message carrier); invalid field = red border only, the bar says what is wrong ("Fix: ... (+n more)"). Built on Contractors first.
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
