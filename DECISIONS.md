# Decision log

What was decided and why. Rules that follow from a decision live in **AGENTS.md**, the plan in **ROADMAP.md**, status in **PROJECT_STATUS.md**. This file is not read by Claude Code unless a task says so.

Dates: 21–24 October 2026.

---

## 1. Architecture

| # | Decision | Why |
|---|---|---|
| A1 | Site Management stays **Power Apps canvas + SharePoint Lists + Power Automate**. | Usable inside the GEA environment, high acceptance, no extra licences. |
| A2 | **No Dataverse, no premium connectors.** | Dataverse not available; premium needs per-user licences. |
| A3 | **No OneDrive data storage with background sync.** | Two copies of the truth, conflicts, slower, data on personal drives. |
| A4 | Performance is solved by **fewer, bulk server calls**, not by changing platform. | Slowness came from ~6–8 sequential calls per cell on Save; fixed, loading now fast. |
| A5 | **Every module works standalone**; integrations are optional and go via simple files (JSON/CSV) or an optional API. | Each module is useful sooner; one failing module does not block others. |
| A6 | pidtracker (React + FastAPI) hosts the **P&ID and 3D** work; Site Management hosts **administration** (hours, documents, inventory). | Power Apps cannot do 3D; pidtracker already has the P&ID data. |
| A7 | SPFx/React front end on the same Lists is the **fallback** if Power Apps ever becomes the bottleneck. | No data migration needed. |

## 2. Data and safety

| # | Decision | Why |
|---|---|---|
| D1 | SharePoint is the single source; collections are temporary caches. | Empty collection ≠ data loss. |
| D2 | Filters: Project Workers only `ProjectKey = <precomputed text>`; Hours `StartsWith(EntryKey, "<id>|")` + Work Date range, always with **global variables**, never With-scoped names. | Delegation; With-scoped names in StartsWith are not delegable. |
| D3 | Save = **1 pre-read + 1 table Patch + 1 verify read**; no `Choices()` or remote LookUp inside loops. | Speed with the same safety checks. |
| D4 | Fail closed: load first, then save; partial results block saving; no automatic repairs. | Prevent duplicates and silent data loss. |
| D5 | **Indexes** on Hours.EntryKey, Hours.'Work Date', Project Workers.ProjectKey (MS-001). | Stay fast past 5,000 items. |
| D6 | SharePoint/Power Automate changes are logged as **MS-xxx** in MANUAL_STEPS.md and handled in the Claude chat. | Claude Code cannot change SharePoint or flows. |
| D7 | **Dataminimalisatie (26-10-2026, ontwerp, nog niet gebouwd):** telefoon en e-mail van medewerkers staan niet in Workers maar in een nieuwe lijst "Worker Contacts" (alleen WorkerID en Phone; e-mail wordt niet opgeslagen, besloten 26-10-2026) met unieke rechten (overerving verbroken): eigenaren = Full control, nieuwe SharePoint-groep "Site Supervisors" (alle supervisors) = Edit, verder niemand (MS-012). Workers houdt naam, werkgever, trade en de bestaande velden. Huidige schermen lezen/tonen telefoon/e-mail niet; het toekomstige Workers-beheerscherm toont contacten alleen bij toegang (bij geen toegang niets tonen, geen fout). Hours.Title wordt = EntryKey voor nieuwe en bijgewerkte rijen (gepland bij de volgende Save-taak; bestaande rijen blijven staan tenzij Eddy anders besluit; open). | Persoonsgegevens beperken tot wat nodig is en scheiden van de lijst die iedereen leest; Title dupliceert nu naam + datum. |

## 3. Hours and reports

| # | Decision | Why |
|---|---|---|
| H1 | Hours are registered on **main project level** only. | Sub projects exist for inventory only. |
| H2 | **Weekly Hours**: one date picker; any day selects that ISO week (Mon–Sun); picker keeps showing the chosen day (no visible jump); label `YYYY KWxx`. | No week picker exists in Power Apps; simplest correct option. |
| H3 | **Hours Summary**: From/Till pickers, whole ISO weeks, `YYYY KWxx` label per picker in the field-label row, no visible jump. | Same behaviour on both screens. |
| H4 | New **Week Report** screen: one week, project, employer; Mon–Sun per worker; read-only across all teams. | Official weekly report = export basis. |
| H5 | Hours Summary remains a **period overview** for questions. | Different purpose than Week Report. |
| H6 | "Active" rows: workers with hours; active workers with 0 only if the period includes the **current week**. | Active flag has no history. |
| H7 | Employer in reports = **historical employer on the Hours record**. | Employer changes must not move old hours. |
| H8 | ISO weeks correct over year boundary: 01-01-2027 → `2026 KW53`. | Week 53 in 2026. |
| H9 | **Assignment periods (26-10-2026, not built yet; build after Home):** team = entry grouping only (reporting per project + employer, no team history). Multiple periods per worker per project in a new list "Assignment Periods" (MS-010: AssignmentKey, ProjectKey, From = Monday, Until = Sunday, blank = open). Project Workers stays one record per project+worker; Active = has an open period. Screen1 gets a "Week" picker; Save team writes/closes periods (never deleted). Weekly Hours rows = period overlap + any worker with stored Hours; days not worked stay blank, the app never auto-writes 0. Supersedes the earlier period proposal and the "no mandatory assignment period" rule; H6 ("active with 0 only in current week") is superseded for Weekly Hours at build time. | One open period per stint gives history (who was on site which week) without a second record per worker, and keeps Hours linked to one assignment. |

## 4. Export

| # | Decision | Why |
|---|---|---|
| E1 | **No Excel export.** Week Report → **PDF + CSV** per project + employer. Hours Summary → **CSV** per selection. | PDF to read/send, CSV as raw data for any software. |
| E2 | CSV: long format, one row per worker per stored day; columns ProjectNumber;ProjectReference;EmployerCode;EmployerName;WorkerID;WorkerName;Trade;WorkDate;ISOYear;ISOWeek;Hours; UTF-8 BOM, `;`, `.` decimal, `yyyy-mm-dd`; workers with total 0 excluded. | Importable everywhere; pivot-friendly. |
| E3 | The **app builds the file contents**; the flow is a **generic file writer** (save, HTML→PDF, return links). No business logic in the flow. | Logic stays in versioned app source; flow rarely changes. |
| E4 | No e-mail; files downloadable from the app. | Agreed scope. |
| E5 | Exported PDFs use **Arial**. | GEA rule for IT-generated output; converter has no Inter. |

## 5. Design

| # | Decision | Why |
|---|---|---|
| G1 | **GEA palette**: Vibrant Blue `#0303B8` (titles, headers, navigation), Night Blue `#000F41` (hover, emphasis), Active Green `#1AFF80` with Night Blue text for the **one primary action** per screen, secondary actions white with blue border, greys from GEA gray scale, total row `#D5EDFF`, errors `#DB1E28`. | GEA brand rules; green = activating colour in digital apps. |
| G2 | No purple, no lilac, no Energetic Pink or Active Blue as surfaces. | Not GEA / not allowed as surface. |
| G3 | Font **"Inter, Arial, sans-serif"**: Semibold titles/headers/buttons, Normal body, Bold emphasis. GEA Sans not in the app. | GEA typography; Inter installed on GEA laptops; Arial official fallback. |
| G4 | Hours Summary table: zebra white/`#F0F0F0`, "–" for 0 (display only), total row under the columns, scrollbar width reserved. | Calmer table, correct alignment. |
| G5 | **Landing screen** with tiles; Home button left in each footer. Tiles are the exception to the footer-navigation rule. | One clear entry point. |

## 6. Documents (workpackages)

| # | Decision | Why |
|---|---|---|
| W1 | Now: **Excel/VBA + Acrobat Pro** generator, reading data from the Lists; templates and media in SharePoint libraries synced via OneDrive. | Works today; local generation is fine. |
| W2 | Later: **browser generator (pdf-lib)** filling the same Acrobat templates, photos and attachments, Inter/GEA Sans embedded. | No Acrobat needed; prototype parked. |
| W3 | Power Apps cannot fill PDF forms with standard licences; Microsoft Forms is not a document generator. | Checked. |

## 7. Inventory

| # | Decision | Why |
|---|---|---|
| I1 | **Registration only**, no movement ledger. Quantities edited directly; SharePoint versioning = history. | Simple; supervisor needs to know what is where. |
| I2 | **Free stock** and **project stock**. Ownership **per stock line** (Owner = project/sub project, empty = free), because several projects and sub projects share **one storage location**. | Matches the sites. |
| I3 | Projects get **ParentProject** (sub projects) and **Members** (persons). | Sub project stock; visibility. |
| I4 | Visibility **option A**: app shows free stock + stock of projects where you are a Member (main project members see sub projects). Not real security. | Clarity, not confidentiality. |
| I5 | `StockKey = <location>|<owner or FREE>|<article>`; one line per owner per location per article. | No duplicates; safe moves. |
| I6 | Actions: Assign, Release, **Use for project** (writes a **Usage** record per project and location), Request (Teams message to contact). | Traceable consumption without a ledger. |
| I7 | QR per storage location (optional). | Fast lookup on site. |

## 8. 3D and component library

| # | Decision | Why |
|---|---|---|
| T1 | Most skids are **built on site from the P&ID**; 3D fills the gap between P&ID (what) and build (how). | Fitters work out the layout themselves today. |
| T2 | **No 3D PDF.** Web **viewer first** (React Three Fiber/three.js), QR code in the WP PDF; WP PDF gets iso/front/side/top images, tag labels, cut and weld lists. | 3D PDF fails on phones/browsers and is often blocked. |
| T3 | **Configurator only after the viewer proves itself**; standalone with the full library; optional filter source: none / pidtracker tags (+ P&ID check) / CSV. | Standalone principle. |
| T4 | **Component library** = visual GLB (fine + lod1) + logic JSON (type code, ports, DN, connection type). Parametric fallback; pipes, elbows, tees, clamps always parametric. | Recognisable for fitters, correct for logic. |
| T5 | **Fitters are visual**: real colours (actuators, pumps, feedback), stainless PBR material, pipe colour **by medium** (MediumColor / NEN 3050), numbered weld rings, clamp accent colour, legend always visible. | Recognition on site. |
| T6 | Model pipeline: **FreeCAD** (remove internals, Defeaturing, Deviation ~1%) → **Blender 5.1.2** (≤5 materials from `GEA_materials.blend`, join per material, Smooth by Angle, Decimate for lod1) → glTF Binary +Y up → gltf-transform meshopt. Budget valve ≤15k/≤4k triangles, ≤300 KB. | Lightweight and visually correct. |
| T7 | Type codes aligned with pidtracker Family-Housing naming. | Filtering without translation tables. |

## 9. Tooling and way of working

| # | Decision | Why |
|---|---|---|
| X1 | Project moved to `C:\Users\vandergoot.ed\Dev\Sitemanagment` (outside OneDrive); **git**, private GitHub repo `eddyvandergoot-hue/sitemanagment`. | Speed (no sync/scan), real history, backup. |
| X2 | **One topic, one file**: README (index), AGENTS (rules), PROJECT_STATUS (status), ROADMAP (plan), MANUAL_STEPS (MS items), DECISIONS (why), NEXT_COMMANDS (queue). | No drift between copies. |
| X3 | PROJECT_STATUS ≤ 80 lines, AGENTS ≤ 150 lines; history in archive files. | Less reading per task = faster. |
| X4 | Claude Code v2.1.308 auto-loads AGENTS.md; commands do not ask to read it again. | Avoid double reading. |
| X5 | Default model Opus 5.5 medium; `opusplan` for mixed builds; `/effort high` for save/load logic; Sonnet for pure layout/docs. | Speed vs care. |
| X6 | **Project subagents** in `.claude/agents/` route work to the right model and tools (see README). | Right agent per task, logs out of the main context. |
| X7 | Tests in two tiers: quick relevant test per change; full suite + pack once at task end. Checkpoint = git commit. | Speed with safety. |
| X8 | Claude chat writes Power Automate code (expressions, Office Scripts, import packages) and SharePoint steps. | Claude Code cannot touch those. |
| X9 | Save week validates all changes locally before any read/write; zero-write errors show the real reason and keep the week Loaded. Trade on Hours is a snapshot of Workers.Trade (Fitter/Welder/Unknown). | Incident 25-10-2026: a correct block was reported as "Opslag niet volledig bevestigd"; misleading messages hide the real fix. |
| X10 | Claude Code may push after verifier + reviewer pass; `approved-*` tags only after Eddy's Studio test. | Pack and tests do not prove Studio behaviour. |

## 10. Open decisions

See **ROADMAP.md** → Open decisions.
