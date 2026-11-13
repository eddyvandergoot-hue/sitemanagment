# Manual steps (MS-xxx)

SharePoint and Power Automate changes that Claude Code cannot make. Done by hand; click-by-click steps and flow code come from the Claude chat. Rules for logging them: **AGENTS.md**. Not read by Claude Code unless a task says so.

| ID | Added | Status |
|---|---|---|
| MS-001 | ≤ 24-10-2026 | Done 25-10-2026 (Eddy) |
| MS-008 | 25-10-2026 | Done (Workers.Trade 25-10-2026, Hours.Trade 26-10-2026, Eddy) |
| MS-005 | 26-10-2026 | Done 26-10-2026 (Eddy) |
| MS-009 | 26-10-2026 | Done 26-10-2026 (Eddy) |
| MS-010 | 26-10-2026 | Done 26-10-2026 (Eddy) |
| MS-012 | 26-10-2026 | Partly done 26-10-2026 (Eddy); open: group/permissions/version cleanup (unconfirmed) |
| MS-013 | 27-10-2026 | Done 27-10-2026 (Eddy) |
| MS-014 | 27-10-2026 | Done 27-10-2026 (Eddy) |
| MS-015 | 27-10-2026 | Done 27-10-2026 (Eddy) |
| MS-016 | 27-10-2026 | Done 27-10-2026 (Eddy) |
| MS-017 | 27-10-2026 | Done 27-10-2026 (Eddy); extended 27-10-2026 (Worker Code) |
| MS-018 | 27-10-2026 | Done 27-10-2026 (Eddy, verified) |
| MS-019 | 27-10-2026 | Done 27-10-2026 (Eddy) |
| MS-020 | 27-10-2026 | Done 28-10-2026 (Eddy, Studio regression PASS) |
| MS-021 | 27-10-2026 | Postponed to go-live |
| MS-022 | 27-10-2026 | Done 27-10-2026 (reported by Eddy) |
| MS-025 | 7-11-2026 | Done 8-11-2026 (Eddy) |
| MS-026 | 7-11-2026 | Done 7-11-2026 (Eddy) |
| MS-027 | 9-11-2026 | Done 10-11-2026 (Eddy); metadata samengevoegd |
| MS-028 | 9-11-2026 | Done 10-11-2026 (Eddy); metadata samengevoegd |
| MS-029 | 9-11-2026 | Done 12-11-2026 (Eddy); flowtest T1-T4 PASS |
| MS-030 | 9-11-2026 | Open (Eddy) |
| MS-031 | 12-11-2026 | Done 12-11-2026 (Eddy) |
| MS-032 | 13-11-2026 | Open (Eddy) |

---

## MS-001 — SharePoint indexes for Hours and Project Workers

- **Where:** https://geacloud.sharepoint.com/sites/GEASiteManagment → list → Settings → List settings → Indexed columns.
- **Reason:** the app's delegated filters use these columns; lists must stay fast and within the List View Threshold past 5,000 items. Why: DECISIONS.md D5.
- **Indexes (single-column):**

  | List | Column (display / internal) | Type | Used by |
  |---|---|---|---|
  | Hours | EntryKey | Single line of text | `StartsWith(EntryKey, "<projectID>\|")` in loaders, Save week pre-read/verify |
  | Hours | Work Date / `WorkDate` | Date | `'Work Date'` range in the same queries |
  | Project Workers | ProjectKey | Single line of text | `ProjectKey = <precomputed text>` in Save team / team load |

- **Check first:** whether each index already exists. Local app metadata does not show index presence; do not assume it is missing. Background: `artifacts/PERFORMANCE_EN_INDEXEN.md`.
- **Also check (not part of this item):** no Project Workers row with empty ProjectKey (AGENTS.md, Save team known risk).
- **Done when:** all three indexes listed under Indexed columns; report back date + who.
- **Status:** Done 25-10-2026 (Eddy): Hours.EntryKey, Hours.'Work Date' and 'Project Workers'.ProjectKey created and confirmed under Indexed columns. The "no empty ProjectKey" check above was not part of this report.

## MS-008 — Trade choices in Workers and Hours

- **Where:** https://geacloud.sharepoint.com/sites/GEASiteManagment → list → Settings → column Trade.
- **Reason:** incident 25-10-2026: Save week blocked a new Hours record because Workers.Trade was empty for one worker (Trade came from an Excel import; the choice column had no choices). Save week copies Trade from Workers onto each new Hours record as `{Value: <Workers.Trade.Value>}` (snapshot, no Choices()); SharePoint may reject a value that is not a choice in Hours.Trade.
- **Workers.Trade (choice):** choices Fitter / Welder / Unknown, default Unknown, required; empty values filled. Status: done by Eddy (25-10-2026).
- **Hours.Trade (choice):** must contain Fitter / Welder / Unknown. Status: done, confirmed by Eddy 26-10-2026. Do not change historical Hours rows.
- **App behaviour:** blank Workers.Trade blocks Save week before any write ("Trade ontbreekt in Workers (aanvullen in SharePoint, daarna Refresh op Project / team)"). If the new-rows Patch fails while a row has Trade Unknown, the app adds "Mogelijk ontbreekt Trade 'Unknown' in de Hours-lijst (MS-008)".
- **Done when:** Hours.Trade choices confirmed as Fitter / Welder / Unknown; report back date + who.
- **Status:** Done. Workers.Trade 25-10-2026; Hours.Trade choices Fitter / Welder / Unknown confirmed by Eddy 26-10-2026 ("Done when" satisfied).

## MS-005 — TEST-000 test data

- **Where:** https://geacloud.sharepoint.com/sites/GEASiteManagment (lists Employers, Projects, Workers) and the app screen Project / team.
- **Reason:** all functional tests with saves must run on a test project so real hours and projects are never touched.
- **Employers:** new item "TEST Employer", Employer Code "TEST-EMP" (Employer Code is unique; existing business-code rule).
- **Projects:** new item Title "TEST-000 Testproject", Project Number "TEST-000", Project Reference "Test only - not for reports".
- **Workers** (Employer = TEST Employer): "Test Fitter" (Trade Fitter), "Test Welder" (Trade Welder), "Test Unknown" (Trade Unknown). First Name "Test" and Surname "Fitter" / "Welder" / "Unknown" (display name "Test Fitter" etc.). Assumption confirmed: Eddy checked 26-10-2026 that Workers.Title (Worker Name) equals First Name + Surname for all workers.
- **In the app:** Project / team: link all 3 workers to TEST-000, team 1, Save team.
- **Done when:** Eddy confirms; report back date + who.
- **Status:** Done 26-10-2026 (Eddy): TEST Employer (Employer Code TEST-EMP), project "TEST-000 Testproject" (Project Number TEST-000), workers Test Fitter / Test Welder / Test Unknown linked to TEST-000 team 1 via Save team ("Done when" satisfied).
- **Extension (added 26-10-2026) — Status: Done 26-10-2026 (Eddy confirmed the three workers exist in Workers; not yet linked to TEST-000):** three extra test workers for the Assignment periods test: "Test Fitter 2" (Trade Fitter), "Test Welder 2" (Trade Welder), "Test Unknown 2" (Trade Unknown); Employer = TEST Employer; First Name "Test", Surname "Fitter 2" / "Welder 2" / "Unknown 2" (same naming rule as above). NOT linked to TEST-000: the period test links them. Eddy has not yet confirmed that they exist.

## MS-009 — Employer Code required and unique

- **Added:** 26-10-2026. **Status:** Done 26-10-2026 (Eddy): Employers.'Employer Code' set to Required + Enforce unique values (indexed); "Done when" satisfied.
- **Where:** https://geacloud.sharepoint.com/sites/GEASiteManagment → list Employers → Settings → column "Employer Code".
- **Reason:** Employer Code (e.g. EMP-001, TEST-EMP) is the unique business key (AGENTS.md); this makes SharePoint enforce it.
- **Settings:** "Require that this column contains information" = Yes; "Enforce unique values" = Yes. SharePoint requires the column to be indexed for unique enforcement and asks for / creates the index.
- **Check first:** no existing Employer row has an empty or duplicate Employer Code (SharePoint refuses the setting otherwise).
- **Done when:** both settings are active; report back date + who.
- **Correction 27-10-2026 (Eddy):** Required is now **No**; Enforce unique values stays Yes. Empty codes are filled by flow MS-019. Employers.Title (display name "Employer Name") is the employer name; Employer Code is a separate column (internal name EmployerCode1). The Studio metadata merged 26-10-2026 still shows Required and Title as "Title"; it predates this change and has no app impact (the app does not read or write Employer Code), so no metadata refresh is needed now.

## MS-010 — Assignment Periods list

- **Added:** 26-10-2026. **Status:** Done 26-10-2026 (Eddy): list, columns and indexes in place; display name "Until" corrected and From/Until changed to date only (Eddy 26-10-2026). Migration of existing assignments is an app action (see Migration), not a manual step.
- **Where:** the existing site https://geacloud.sharepoint.com/sites/GEASiteManagment (new list).
- **Reason:** several periods per worker per project (decision DECISIONS.md H9). Project Workers stays one record per project+worker.
- **List:** "Assignment Periods" with columns:

  | Column | Type | Note |
  |---|---|---|
  | AssignmentKey | Single line of text | indexed; same format as Project Workers.AssignmentKey (project-ID\|worker-ID) |
  | ProjectKey | Single line of text | indexed |
  | From | Date only (no time) | the app writes a Monday; required |
  | Until (internal name Till) | Date only (no time) | the app writes a Sunday; blank = open |

- **Indexes:** AssignmentKey and ProjectKey. Check online first whether they exist; local metadata does not show this.
- **Migration:** NOT a manual SharePoint step; it is an explicit per-project migration action in the app (built, Studio-tested on TEST-000 27-10-2026: TESTPLAN.md TP-MIGR-01). Original idea (superseded): each existing active assignment gets one period: From = Monday of its earliest Hours record, Until blank.
- **Created as (26-10-2026, verified from the Studio metadata):** Title has display name "AssignmentKey" (internal name Title; required; indexed; NOT unique, since several periods per assignment); ProjectKey (text, required, indexed); From (date only, required); Until (internal name Till, date only, optional). The app uses the internal names. Data source "Assignment Periods" was added in Studio by Eddy and merged into the .msapr.
- **Done when:** list, columns and indexes are in place and Eddy confirms (satisfied). Functional test on TEST-000 (MS-005): TESTPLAN.md TP-PERIOD-01.

## MS-012 — Worker Contacts list (phone out of Workers)

- **Added:** 26-10-2026. **Status:** Partly done 26-10-2026 (Eddy reported): list "Worker Contacts" exists with the phones migrated; Workers.Phone removed; Workers.Email removed (no worker email); Workers.'Employer Code' and 'Employer Name' also removed. **Still open / unconfirmed (ask Eddy):** group "Site Supervisors" + unique permissions on Worker Contacts (steps 1, 3, 4) and the version-history cleanup of Workers.
- **Where:** https://geacloud.sharepoint.com/sites/GEASiteManagment (new list; list Workers for the migration).
- **Reason:** data minimisation (DECISIONS.md D7, SECURITY.md): the phone number must not be readable by everyone with read access to Workers. The current screens do not read or show them.
- **List:** "Worker Contacts" with columns:

  | Column | Type | Note |
  |---|---|---|
  | WorkerID | Number | required, unique, indexed; intended meaning = the SharePoint item ID of the Workers item |
  | Phone | type: to be confirmed (assumption: single line of text) | |

  There is NO Email column: worker email is not stored (decided by Eddy 26-10-2026, no use case).

- **Steps:** (1) create the SharePoint group "Site Supervisors" (Eddy decides the members = all supervisors); (2) create the list "Worker Contacts" (WorkerID + Phone); (3) break permission inheritance; (4) owners = Full control, "Site Supervisors" = Edit, nobody else; (5) migrate.
- **Migration:** copy the existing phone numbers from Workers.Phone to Worker Contacts; clear the values; then remove the column Workers.Phone.
- **Workers.Email:** removed by Eddy (26-10-2026); not moved to Worker Contacts.
- **Version history:** Workers version history still contains the phone numbers. Decide (Eddy) whether to clean old versions.
- **Done when:** list, columns, unique permissions and group "Site Supervisors" are in place, numbers are migrated and Workers.Phone is removed (and the Workers.Email decision is made); Eddy confirms; report back date + who. Also check in Studio Monitor whether Workers rows (incl. Phone/Email columns) are transferred to the client (SECURITY.md open points).

## MS-017 — Flow "Workers - Worker Name sync"

- **Added:** 27-10-2026. **Status:** Done 27-10-2026 (Eddy). Tested OK, no loop.
- **Where:** Power Automate, site https://geacloud.sharepoint.com/sites/GEASiteManagment, list Workers.
- **Reason:** Workers.Title ("Worker Name") is no longer required, is hidden in the SharePoint form and is never typed by hand; the flow keeps it equal to First Name + Surname (the app shows it).
- **Flow:** "Workers - Worker Name sync". Trigger: SharePoint "When an item is created or modified" on Workers, with trigger condition `Title <> trim(field_2 + " " + field_3)`. Action: "Update item" with Id + Title only; Title = `trim(First Name + " " + Surname)`. Trade and Active are not touched.
- **Internal names (Workers):** First Name = field_2, Surname = field_3, Trade = field_6.
- **Extension, Done 27-10-2026 (Eddy):** the same flow also fills Worker Code (internal field_1) = `WKR-` + ID padded to 3 digits (e.g. WKR-007) when empty. Trigger condition is now: Title mismatch OR field_1 empty. Existing empty codes are filled on the next edit of the item. The app never writes Worker Code.
- **Update 7-11-2026 (MS-026):** since First Name and Surname are required, the "Update item" also passes First Name + Surname from the trigger; test run Succeeded.
- **Done when:** a new or edited worker gets the correct Title without a loop (satisfied).

## MS-018 — Assignment Periods: From required

- **Added:** 27-10-2026. **Status:** Done 27-10-2026 (Eddy, verified: From is required).
- **Where:** https://geacloud.sharepoint.com/sites/GEASiteManagment → list Assignment Periods → Settings → column From.
- **Reason:** prevents a period without From (known limitation: a blank From is ignored for the Hours Summary minimum and is not blocked at load; PROJECT_STATUS.md).
- **Setting:** "Require that this column contains information" = Yes.
- **Note:** the Studio metadata merged 26-10-2026 (DataSources.json in Site Managment_VS.msapr) already lists From as required for Assignment Periods (required: Title, ProjectKey, From), and MS-010 says "From (date only, required)". Eddy: check the list settings; if it is already Yes, close MS-018 without change.
- **Done when:** Eddy confirms the setting (satisfied 27-10-2026).

## MS-019 — Flow: fill Employer Code

- **Added:** 27-10-2026. **Status:** Done 27-10-2026 (Eddy).
- **Where:** Power Automate, site https://geacloud.sharepoint.com/sites/GEASiteManagment, list Employers.
- **Reason:** Employer Code (internal name EmployerCode1) is unique but no longer required (MS-009 correction); the flow gives every employer a code.
- **Flow:** on create/modify of an Employers item, when Employer Code is empty, "Update item" with Id + Employer Code only = `EMP-` + SharePoint item ID padded to 3 digits (e.g. EMP-007). Flow name "Employers - Employer Code"; trigger condition `empty(EmployerCode1)`, so the update does not retrigger itself. Employer Code: not required, unique; Title = Employer Name. Title (Employer Name) is not touched.
- **Update 7-11-2026 (MS-026):** since Title (Employer Name) is required, the "Update item" also passes Title from the trigger. The flow in Power Automate is now named "Employers - Employers code".
- **Done when:** a new employer without a code gets `EMP-` + 3-digit ID, no loop (satisfied 27-10-2026, Eddy).

## MS-013 — Projects cleanup and new columns

- **Added/Done:** 27-10-2026 (Eddy). List Projects: columns Location, Site Supervisor and Client Name deleted; Status (choice: Active / On hold / Closed), Site Managers (Person, multiple) and Country added.
- **App impact:** none; the app (Src) does not reference Projects.Location / Site Supervisor / Client Name (grep 27-10-2026). The Studio metadata in the .msapr (26-10-2026) still lists the old columns; refresh when the admin screens use the new columns.

## MS-014 — Employers: Country

- **Added/Done:** 27-10-2026 (Eddy). Column Country added to Employers. No app impact yet.

## MS-015 — Workers: Language and Worker Code

- **Added/Done:** 27-10-2026 (Eddy). Workers: column Language (choice, default Nederlands; 9-11-2026: default is Dutch) added; Worker Code (internal field_1) is unique, not required, filled by flow MS-017 (extension). No app impact yet.

## MS-016 — TEST-001 status

- **Added/Done:** 27-10-2026 (Eddy). Projects: TEST-001 Status = Closed (see MS-005 addendum).

## MS-005 addendum — TEST-001

- TEST-001 exists (Active = No), test project only (added 27-10-2026, noted by Eddy). Used read-only for the "no periods and no hours" test (TESTPLAN.md TP-PERIOD-01, 6.3). The TEST- prefix rule applies: TEST projects stay selectable in Week Report, export files get prefix TEST_, TEST Employer rows are excluded on real projects (DECISIONS.md E10); health check and Hours Summary exports exclude them (AGENTS.md).

## MS-020 — Refresh data sources for the admin screens

- **Added:** 27-10-2026. **Status:** Done 28-10-2026 (Eddy): regression build ms020b imported in Studio, Home / Project / team / Weekly Hours / Hours Summary load as before; tag approved-20261028-ms020b. Workers.Language default "Nederlands" was set in SharePoint (9-11-2026: default is Dutch; choices Dutch, English, Polish, Romanian, German, Ukrainian) (the merged metadata still shows "English"; the app prefills explicitly anyway); old duplicate columns (old Email / old ProjectLeader) checked by Eddy.
- **Where:** Power Apps Studio, the app test file. Data sources Employers, Projects, Workers.
- **Reason:** the metadata in the .msapr (26-10-2026) lacks the new columns (Employers Contact Name/Email/Phone; Projects Street, House Number, Postal Code, City, Project Leader, Country) and still has Employer Code required. Admin build plan: ADMIN_PLAN.md (phase 0).
- **Steps:** refresh the three data sources in Studio, then File > Save as > This computer, save the .msapp into `Incoming\` in the project folder.
- **Progress 27-10-2026:** Eddy saved `Incoming\20261027-Site Managment.msapp` (21:39, SHA-256 5964541D62D3848E6FFC688AE8B105993463654954F0381B53D6EC74A4E441EE). That save has a different App Id (31305539-d231-4b69-8196-8a58575e5308, a copy): not taken over; repo App Id stays 88e53928-0a0b-49fe-ac52-05833b5ca1e0. Merged into the .msapr: only `msapp\References\DataSources.json` (all 6 SharePoint sources; table/dataset IDs identical; no signed URLs). Not taken: Resources.json (SAS sig), Properties.json (other App Id), Templates.json, Header/PublishInfo/Controls/AppChecker (Studio state).
- **Src comparison:** Studio Src vs repo Src per control/property: no formula changes, no Title/column renames. Only Studio re-serialisation (property order, omitted defaults) and ModernDatePicker 1.0.0 -> 1.0.2 on dpTeamWeek/dpHoursWeek/dpReportFrom/dpReportUntil; not taken over (standing rule).
- **Regression build (no screen changes):** `artifacts\ms020-20261027_214611\SiteManagement_MS020_20261027_214611.msapp`, 121194 bytes, SHA-256 49E0B5B93DBC84C3BA16EA8DFB19FE080ADEB174F5CDCCC409CE8592D73CF1FF. 10 active checks pass; Src byte-identical; vs the approved pickerfix build only DataSources.json and packed.json differ; App Id and connections unchanged. Not imported in Studio yet: Eddy imports and checks Project / team load, Weekly Hours, Hours Summary.
- **Second merge 27-10-2026:** Eddy changed columns (Contact Email -> single line of text, Project Leader -> single person, Language default) and saved `Incoming\20261027-Site Managment_adjusted.msapp` (22:22, SHA-256 77394229144ADE9B1858E39BFD28375C1406484E6AB0924AEADD863C37F2BEE8); again a copy with another App Id (6dc0d2cc-3161-4062-9c00-2630a0f9c9c3): not taken. Merged only `msapp\References\DataSources.json` (table/dataset IDs identical, no signed URLs). Studio Src: no formula changes, only re-serialisation + ModernDatePicker 1.0.2; not taken. Verified types: Employers Contact Email = internal ContactEmail1 (string, plain text; NEW column, the old Email (uri) is gone; CHECK by Eddy: old values are not in the new column unless copied); Country text; no required columns. Projects Country choice (default Netherlands); Project Leader = ProjectLeader1 (single person, new column); SiteManagers single person; required ProjectName, Status. Workers Language choice: metadata default is "English", NOT "Nederlands" (9-11-2026: SharePoint default is Dutch): MISMATCH with Eddy's answer; Eddy checks the column default in SharePoint list settings and refreshes again if it was changed after the save; otherwise the app prefills "Nederlands" explicitly. Required on Workers: field_6.
- **Regression build ms020b (replaces ms020-20261027_214611):** `artifacts\ms020b-20261027_222702\SiteManagement_MS020b_20261027_222702.msapp`, 121143 bytes, SHA-256 221B713357545CD9F6E367F19BED7EF1CBA706418C4D4C6532511A516044FD13. 10 checks pass; vs the approved pickerfix build only DataSources.json and packed.json differ; App Id/Properties identical. Not imported in Studio: Eddy checks Project / team load, Weekly Hours, Hours Summary and gives OK.
- **Then (Claude):** merge the metadata, regression build with no screen changes, check Title display-name renames in formulas, report path + SHA-256, wait for Eddy's OK before the Contractors build.

## MS-021 — Site Supervisors permissions on Employers, Projects, Workers

- **Added:** 27-10-2026. **Status:** Postponed to go-live (test phase: Eddy is the only user).
- **Where:** https://geacloud.sharepoint.com/sites/GEASiteManagment, lists Employers, Projects, Workers.
- **Reason:** the admin screens write to these lists. Group "Site Supervisors" (MS-012) gets Edit on the three lists.
- **Note:** when adding members, uncheck "Send an email invitation".

## MS-022 — Projects: Project Number unique

- **Added/Done:** 27-10-2026 (reported by Eddy). Projects.'Project Number' (internal name ProjectName): Enforce unique values = Yes. Backstop for the duplicate block on the Projects screen (ADMIN_PLAN.md).

## MS-023 — Control templates for canvas components (Studio save with scrTemplates)

- **Added:** 30-10-2026. **Status:** Done 30-10-2026. Eddy saved `Incoming\20261031Site Managment-templates.msapp` (342879 bytes, SHA-256 1E80ED48D69F63BA310D2B6EA68A37E8E5274329FA5E2E7FE25C35CE037CDACC; a copy with App Id 0ec93860-..., not taken). Merged into the .msapr: only six new entries appended to `msapp\References\Templates.json` (htmlViewer 2.1.0, modernToggle 1.0.1, modernSpinner 1.1.0, modernBadge 1.0.0, modernTextInput 1.1.2, modernDropdown 1.0.3); existing entries byte-identical; Src (scrTemplates never entered the repo), Properties.json, Resources.json, DataSources and Studio state not taken. App Id stays 88e53928. Check-WeeklySource, Test-SaveRegression, Test-AdminScreens pass after the merge.
- **Where:** Power Apps Studio, the app test file (App Id 88e53928-0a0b-49fe-ac52-05833b5ca1e0 must stay; a Studio copy with another App Id is only used as template source).
- **Reason:** the .msapr Templates.json has no HTML text, modern Toggle, Spinner, Badge, modern Text input or modern Dropdown template; AGENTS allows a new control type only once its template is in the .msapr. Needed for the canvas components (cmpField, cmpMessageBar, cmpListCard, cmpFooter, cmpTitleBar; NEXT_COMMANDS.md section 1).
- **Steps (Eddy):** add a screen `scrTemplates`, insert one of each: HTML text (classic), Toggle (modern), Spinner (modern), Badge (modern), Text input (modern), Dropdown (modern). File > Save as > This computer, save the .msapp into `Incoming\` (name e.g. `20261030-Site Managment_templates.msapp`).
- **Then (Claude):** merge only the templates (Templates.json and the matching template files) into the .msapr; do not take Src, Properties.json (App Id), Resources.json (SAS), DataSources or Studio state; remove scrTemplates from the app (templates stay in the metadata); report SHA-256 of the source file; then step 1 (test the modern controls with GEA colours/Inter, report only).

## MS-024 — Employers: adresvelden (Street, House Number, Country als keuze)

- **Added/Done:** 4-11-2026 (Eddy meldde: gedaan). List Employers: nieuwe kolommen Street en House Number; Country is nu een keuzekolom zoals bij Projects (was tekst, MS-014). De oude kolom Address blijft in SharePoint tot Eddy goedkeurt. Bevestigd 4-11-2026 uit de metadata: Street (intern Street, tekst), House Number (intern HouseNumber, tekst), Country keuze zonder standaard, Address (tekst) bestaat nog en wordt door de app niet meer gebruikt.
- **Status:** gedaan en afgerond. Metadata samengevoegd (commit 58dee1b): alleen msapp\References\DataSources.json uit Incoming\20261104.msapp (562352 bytes, SHA-256 29E0DF4215D9194812E7F3B1737548135F1FBEE7703602DFC3F3760A1E79131D); alleen Employers wijzigde, App Id blijft 88e53928. Item 9 gebouwd (PROJECT_STATUS.md).
- **Open (Eddy):** beslissen over migratie van bestaande Address-waarden naar Street/House Number (niet gekopieerd) en wanneer de kolom Address mag vervallen.

## MS-025 — Power Automate: ongebruikte flows uitzetten

- **Added:** 7-11-2026. **Status:** Done 8-11-2026 (Eddy): GetWeeklyHoursData, SiteHoursConnector and "Recurrence -> FlowConfig,Current KW" turned Off (not deleted). Read check (Weekly Hours / Hours Summary after Off): part of the retest, not separately reported; listed as done per Eddy.
- **Reason:** Power Automate heeft 5 flows. In gebruik: "Employers - Employers code" (MS-019, SharePoint-trigger) en "Workers - Worker Name sync" (MS-017, SharePoint-trigger). Niet gebruikt volgens controle van Src + Site Managment_VS.msapr: GetWeeklyHoursData (Instant, Power Apps-trigger; nergens een verwijzing), SiteHoursConnector (Instant; nergens een verwijzing) en "Recurrence -> FlowConfig,Current KW" (Scheduled; geen lijst FlowConfig onder de gegevensbronnen en geen verwijzing naar FlowConfig/Current KW: de app leest geen data uit deze flow). Gegevensbronnen van de app: alleen Projects, Employers, Workers, Project Workers, Hours, Assignment Periods (+2 statische voorbeelden) en één legacy-flowbron "PowerAppV2 -> LastID init,BatchCount init,ReportHours Init" (FlowNameId 523dd121-144a-47d6-90d8-45e78243ae72), geregistreerd in de .msapr-metadata maar in Src nooit aangeroepen (.Run).
- **Stappen (Eddy):** zet GetWeeklyHoursData, SiteHoursConnector en "Recurrence -> FlowConfig,Current KW" UIT (niet verwijderen). Controleer eerst in de URL/details van elke flow of het ID 523dd121-144a-47d6-90d8-45e78243ae72 is (de geregistreerde legacy-flow kan hernoemd zijn); uitzetten blijft veilig omdat de app hem nooit uitvoert, maar noteer het. Na het uitzetten: app eenmaal openen in Studio (geen fout verwacht) en Weekly Hours laden + Hours Summary draaien als leescontrole.
- **Later, apart besluit (niet nu):** de legacy-flowbron uit de app verwijderen.
- **Done when:** Eddy meldt de drie flows uit en de leescontrole zonder fouten.

## MS-026 — Verplichte kolommen (Employers, Projects, Workers)

- **Added/Done:** 7-11-2026 (Eddy). **Status:** Done.
- **Reason:** voorkomt lege records via SharePoint-raster/snelbewerking (incident lege Employers-records, PROJECT_STATUS.md).
- **Instellingen ("Require that this column contains information" = Yes):** Employers Title (Employer Name); Projects Title (Project Name); Workers First Name + Surname.
- **Flows:** MS-017 (hernoemd "Workers - Worker Name sync") geeft in "Update item" First Name + Surname door uit de trigger; testrun Succeeded. MS-019 ("Employers - Employers code") geeft Title door uit de trigger.
- **App impact:** geen (de app valideert deze velden al vóór opslaan). Metadata-refresh later meenemen (verplicht-vlaggen).

## Bibliotheek Exports (Week Report/export)

- **Status:** Done 9-11-2026 (Eddy). Documentbibliotheek Exports bestaat; gebruikt door de flow van MS-029 (WEEKREPORT_PLAN.md par. 6.4-6.5).

## MS-027 — Employers: kolom "Report Language"

- **Added:** 9-11-2026. **Status:** Done 10-11-2026 (Eddy). Metadata samengevoegd 10-11-2026 (zie MS-028). Let op: in de metadata heet de kolom intern én als weergavenaam "Language" (niet "Report Language"); keuzes staan niet in de metadata. Fase C gebruikt de interne naam Language op Employers. Eddy: controleer of de weergavenaam in SharePoint "Report Language" is; voor de app maakt het niet uit.
- **Reason:** tweede taal van het Week Report per contractor (DECISIONS.md WR1).
- **Kolom:** Employers, "Report Language", type keuze; keuzes Dutch, English, Polish, Romanian, German, Ukrainian; geen standaardwaarde.
- **Let op:** de keuzes van Employers.Report Language en Workers.Language moeten gelijk blijven; bij een nieuwe taal in beide toevoegen.
- **Daarna:** metadata-refresh samen met MS-028 (zie MS-028).

## MS-028 — SharePoint-lijst "Translations"

- **Added:** 9-11-2026. **Status:** Done 10-11-2026 (Eddy): lijst Translations (Key = hernoemde Title, Language tekst, Text meerdere regels, index op Language).
- **Metadata samengevoegd 10-11-2026 (Claude):** uit `Incoming\Site Managment 10-11-2026.msapp` (747051 bytes, SHA-256 ADECF65C4AF9249E67AE79094DCEAF155D6747E188BFA614797EEF137A377519; kopie met App Id 0ac96947-6b19-452e-8044-44c03832d0ea, niet overgenomen) alleen `msapp\References\DataSources.json` in de .msapr vervangen. App Id blijft 88e53928. Geen ondertekende URL's. Verschil: nieuwe bron Translations (tabel 369863f7-427c-4e7b-adc5-68311e3d179e; intern Title (weergave in de metadata nog "Title", niet "Key"), Language tekst, Text); Employers + Language (keuze); verplicht-vlaggen ververst (Projects Title/ProjectName/Status, Employers Title, Workers field_2/field_3/field_6); overige bronnen alleen revisie/naamtoewijzing; dataset- en tabel-ID's gelijk. Uit Properties.json alleen de Translations-regels in LocalConnectionReferences (SharePoint-verbinding b4a62a3e: dataSources-lijst + tableName; reviewerbevinding, anders heeft de bron geen verbindingsreferentie); Id en de rest van Properties.json ongewijzigd. Niet overgenomen: Src, Resources.json, Templates.json, Header/PublishInfo/AppChecker. Fase A gebruikt Translations en Employers.Language nog niet.
- **Reason:** data-gestuurde documentteksten (DECISIONS.md WR5; WEEKREPORT_PLAN.md par. 6.3).
- **Lijst:** "Translations"; Title hernoemen naar Key; Language = tekst, één regel (waarde = keuzenaam, bv. "Polish"); Text = meerdere regels; index op Language. Vullen met de CSV uit de Claude-chat.
- **Na MS-027 + MS-028:** één metadata-refresh (Employers + Translations), opgeslagen in Incoming\; alleen databronnen samenvoegen; App Id 88e53928.

## MS-029 — Power Automate: flow "SiteManagement - Export file"

- **Added:** 9-11-2026. **Status:** Done 12-11-2026 (Eddy; zie onderaan deze sectie).
- **Reason:** generieke bestandsschrijver voor CSV/PDF. Contract: WEEKREPORT_PLAN.md par. 6.5 (invoer Folder, FileName, Format csv|pdf, Content; uitvoer Status, FileUrl, Message).
- **11-11-2026 (Eddy):** Eddy bouwt de flow met de hand. Bevestigd contract:
  - Trigger Power Apps (V2). Invoer, alle tekst: Folder, FileName (zonder extensie), Format ("csv" | "pdf"), Content.
  - Uitvoer, alle tekst: Status ("OK" | "Error"), FileUrl, Message.
  - CSV: de app zet de BOM er zelf voor. De flow schrijft Content ongewijzigd.
  - PDF: Content is volledige HTML (Arial, logo als base64). Vervangen door H25 (12-11), zie hieronder.
  - Melden als gedaan, met de exacte namen van de invoer en uitvoer zoals ze in de flow staan. Daarna pas MS-030.
- **12-11-2026 (Eddy, H25): contractwijziging.**
  - Extra invoer **TemplateName** (tekst, bv. "weekreport.html"), alleen gebruikt bij pdf; bij csv leeg.
  - PDF-stappen:
    1. Lees het bestand TemplateName en header.html uit bibliotheek Templates (MS-031).
    2. `replace(template, '{{BODY}}', Content)`.
    3. Daarna `replace(<resultaat>, '{{HEADER}}', header)`. Eerst BODY, dan HEADER: de HEADER-tokens zitten in Content.
    4. Daarna zoals gepland: tijdelijk .html in OneDrive, Convert file naar PDF, Create file in Exports/Folder, tijdelijk bestand verwijderen.
  - Content bij pdf = alleen de pagina's, zonder opmaak of logo.
  - Template of header niet gevonden: Status "Error" met Message, geen bestand.
  - Flowtest: Content = de inhoud van templates/sample-body.html, Format "pdf", TemplateName "weekreport.html", Folder "TEST-000", FileName bv. "TEST_flowtest". Verwacht een PDF van 2 pagina's (Weekrapport NL en Week report EN, blauwe balk met GEA-logo). Meld of het logo zichtbaar is: het is een SVG, en of Convert file dat toont, is niet bekend.
- **Done 12-11-2026 (Eddy): gebouwd en getest** (TESTPLAN.md TP-EXPORT-01: T1 csv, T2 pdf, T3 overschrijven, T4 onbekend formaat, alle PASS).
  - Trigger-invoer in deze volgorde: Folder, FileName, Format, Content, TemplateName (optioneel).
  - Uitvoer: Status, FileUrl, Message.
  - Samenvoegen: eerst BODY vervangen, dan HEADER.
  - Opslag in SharePoint (Exports). Tijdelijke map in Eddy's OneDrive: SiteManagementTemp. Het bestand wordt na de conversie verwijderd.
  - De converter is Chromium, niet Word: het SVG-logo, A4 liggend en het CSS-pagina-einde werken.
  - Exports: major versions aan.

## MS-031 — SharePoint-bibliotheek "Templates"

- **Added:** 12-11-2026. **Status:** Done 12-11-2026 (Eddy): bibliotheek Templates (label None, unieke rechten: Eddy Full Control, rest Read, major versions), header.html + weekreport.html geüpload.
- **Reason:** PDF-opmaak centraal en aanpasbaar zonder app-build (DECISIONS.md H25).
- **Stappen:** maak op https://geacloud.sharepoint.com/sites/GEASiteManagment de documentbibliotheek **Templates** (geen extra kolommen). Upload uit de repo-map templates/ de bestanden **header.html** en **weekreport.html** (ongewijzigd). sample-body.html hoeft er niet in (alleen voor de flowtest). Rechten: lezen voor de flow-eigenaar; bewerken alleen voor beheerders.
- **Let op:** een wijziging in de bibliotheek ook in de repo vastleggen (bron = repo; Test-Templates.ps1 controleert de repo-versie).

## MS-030 — Flow toevoegen aan de app

- **Added:** 9-11-2026. **Status:** Open (Eddy). MS-029 is gedaan, dus deze stap kan nu.
- **Stappen:**
  1. Open de app in Studio en voeg via Data (of het Power Automate-paneel) de flow "SiteManagement - Export file" toe. Maak geen verbindingen zelf in YAML.
  2. Wijzig verder niets en sla op.
  3. Zet de save in Incoming\ (bijvoorbeeld via Save as -> This computer).
  4. Meld de exacte naam waarmee de flow in Studio verschijnt (bv. 'SiteManagement-Exportfile'). Daarna neem ik alleen de flowkoppeling over in de .msapr, zoals bij MS-028: App Id 88e53928, de rest uit die save niet.
- **Nodig voor fase C:** zonder deze save kan de Export-knop de flow niet aanroepen en faalt de Studio-import.

## MS-032 — Documentteksten importeren in Translations

- **Added:** 13-11-2026. **Status:** Open (Eddy).
- **Reason:** fase C (Week Report-PDF) leest de doc.*-teksten uit de lijst Translations (WEEKREPORT_PLAN.md 6.3, WR5). Bron: templates/translations-weekreport.csv (23 sleutels x 6 talen = 138 regels; UTF-8 met BOM, scheiding ";").
- **Stappen:**
  1. Controleer in SharePoint de kolomnamen van Translations: Key (interne naam Title), Language (tekst), Text (meerdere regels). Wijken ze af, meld dat vóór de import.
  2. Importeer de CSV (bv. openen in Excel en plakken in de rasterweergave van de lijst). Language exact zoals in de CSV: Dutch, English, Polish, Romanian, German, Ukrainian (= keuzes van Workers.Language).
  3. Bestaande doc.*-regels met dezelfde Key + Language: vervangen, niet dubbel laten staan.
  4. Controleer na de import: 138 regels met Key "doc.*", Oekraïense teksten in Cyrillisch leesbaar (geen ?-tekens), placeholders {date} {user} {page} {pages} ongewijzigd.
- **Let op:** pl/ro/de/uk zijn nog niet door native speakers gecontroleerd (backlog). Wijzigingen in de lijst ook in de repo-CSV vastleggen.