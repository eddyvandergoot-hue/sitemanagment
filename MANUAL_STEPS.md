# Manual steps (MS-xxx)

SharePoint and Power Automate changes that Claude Code cannot make. Done by hand; click-by-click steps and flow code come from the Claude chat. Rules for logging them: **AGENTS.md**. Not read by Claude Code unless a task says so.

**Werkwijze (vaste regel Eddy 16-11-2026, ook in AGENTS.md):** Claude maakt waar mogelijk een kant-en-klaar bestand; Eddy importeert of plakt alleen.
- Flows: importpakket (zip) uit Eddy's laatste export, alleen definition.json gewijzigd; Import Package (Legacy) > Update existing (of Create as new voor een nieuwe flow).
- App: Src > .msapp (pack).
- PDF-templates: HTML-bestand voor de bibliotheek Templates.
- Translations, AppSettings en andere gegevens: CSV voor plakken in de rasterweergave.
- Nieuwe SharePoint-lijst: .xlsx met kolommen, typen en voorbeeldrijen > New > List > From Excel; daarna de kolomtypen controleren.
- Lijst- of kolomopmaak: JSON voor Format column / Format view.
- Controles: lokale scripts (artifacts\).
Handklikstappen alleen als er geen importroute is (rechten, keuzes bewerken, heel kleine wijzigingen). Elke MS-stap noemt het bestand dat Claude levert, of waarom de stap handmatig is ("Waarom handmatig: ...").
Later te controleren (IT): is PnP PowerShell bij GEA toegestaan (app-registratie)? Zo ja, dan lijsten, kolommen en rechten via een script.

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
| MS-030 | 9-11-2026 | Done 13-11-2026 (Eddy); flowkoppeling samengevoegd (commit 74c37bf) |
| MS-031 | 12-11-2026 | Done 12-11-2026 (Eddy) |
| MS-032 | 13-11-2026 | Done 13-11-2026 (Eddy); 138 items |
| MS-033 | 13-11-2026 | Done 14-11-2026 (Eddy); metadata samengevoegd 14-11-2026 |
| MS-034 | 13-11-2026 | Stap 1 done 14-11-2026 (Eddy); stap 2-3 (Require) pas na goedkeuring v1.0.2 (Contractors-veld Language) |
| MS-035 | 14-11-2026 | Done 14-11-2026 (Eddy); Language keuze + index; metadata ververst en samengevoegd 14-11-2026 |
| MS-036 | 14-11-2026 | Gedaan (Eddy 14-11-2026) |
| MS-037 | 16-11-2026 | Done 16-11-2026 (Eddy): fix1 geïmporteerd als Update van flow 22e34f1b; TP-EXPORT-02 stap 2-4 PASS |
| MS-038 | 16-11-2026 | Done 16-11-2026 (Eddy): AppSettings csv.separator "," en csv.decimalSeparator "," |
| MS-039 | 16-11-2026 | Done 16-11-2026 (Eddy): 384 landregels in Translations (568) |
| MS-040 | 16-11-2026 | Open, later (Eddy): oude cloudkopieën van de app opruimen; niet nu |
| MS-041 | 16-11-2026 | Done 16-11-2026 (Eddy): verbinding "Translator SiteManagement" (Microsoft Translator V2) |
| MS-042 | 17-11-2026 | Done 18-11-2026 via importflow: Added 176, Updated 1112, Errors 0; Translations 1288 (Eddy) |
| MS-043 | 17-11-2026 | Done 18-11-2026: keuze Belarusian (Eddy) + 161 be-regels via importflow (Added 161, Errors 0); verwacht totaal 1449 |
| MS-044 | 17-11-2026 | Vervallen 18-11-2026 (H40): geen lijsten Customers/ProjectSafety |
| MS-045 | 17-11-2026 | Vervallen 18-11-2026 (H40) |
| MS-046 | 17-11-2026 | Done 17-11-2026 (Eddy): v2 geïmporteerd (Update), aan, Imports gesynchroniseerd; eerste run MS-042 OK: bibliotheek Imports + importpakket "SiteManagement - Import rows" (Create as new) + Sync; daarna importeert Claude lijstgegevens |
| MS-047 | 18-11-2026 | Open (Eddy): kolommen Projects (CustomerCity, CustomerPhone, SupervisorPhone) en Project Workers (ConsentStatus, ConsentDate) + metadata-save in Incoming; daarna bouw consent |
| MS-048 | 18-11-2026 | Done 18-11-2026 (Eddy): schone start v1 (H41): testrijen van echte projecten verwijderen (Hours 24, Assignment Periods 20, Project Workers 19) + Exports-map van FC; TEST-000 blijft |
| MS-049 | 18-11-2026 | Open (Eddy): importflow v3 importeren (Import Package > Update "SiteManagement - Import rows") |
| MS-050 | 19-11-2026 | Done 19-11-2026 (Eddy): flow v2 geïmporteerd (Update), SharePoint + Office 365 Outlook, aan; in Studio toegevoegd; metadata uit Incoming\20261119-SiteManagement-mail.msapp samengevoegd (alleen data source + verbindingen). Open: geschoonde export van de flow later in de repo |
| MS-051 | 19-11-2026 | Done 19-11-2026 (Claude via importflow): Translations mail.body, 9 talen (Added 9, Errors 0) |
| MS-052 | 19-11-2026 | Done 19-11-2026 (Claude via importflow): AppSettings hours.fillPattern = 10,10,10,10,10,0,0 (Added 1, Errors 0) |
| MS-053 | 19-11-2026 | Done 19-11-2026 (Eddy): Classic Combo box op Home, Incoming\20261119-SiteManagement-combobox.msapp; Claude nam alleen de template combobox 2.4.0 over |
| MS-054 | 19-11-2026 | Done 19-11-2026 (Eddy): country-choices.txt geplakt in Employers.Country (geen standaard) en Projects.Country (standaard Netherlands) |
| MS-055 | 19-11-2026 | Done 19-11-2026 (Claude via importflow): Translations country.Belarus, 9 talen (templates/translations-countries-belarus.csv; Added 9, Errors 0; verwacht totaal 1467) |

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
- **Go-live, flows (Eddy 14-11-2026):** de flow "SiteManagement - Export file" wordt voor gebruikers gedeeld als **Run only**; bij Run only users kies je voor de SharePoint- en de OneDrive-verbinding "Use this connection" (Eddy's verbinding), niet "Provided by run-only user". Dan hebben gebruikers géén rechten nodig op de bibliotheken Templates en Exports; alleen Eddy's account schrijft daar.

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
- **Instellingen (Eddy 14-11-2026; controleren):** versiebeheer **major versions aan** (opnieuw exporteren overschrijft, de vorige versie blijft in de versiegeschiedenis; de tenant kan oude versies automatisch laten verlopen); gevoeligheidslabel **None of GEA INTERNAL** (Eddy kiest; noteer de keuze hier); rechten: unieke rechten, Eddy (verbinding van de flow) Full Control; wie exports moet openen Read; niemand anders Edit. Met Run only + Eddy's verbinding (MS-021) hebben app-gebruikers voor het exporteren zelf geen rechten op Exports nodig.

## MS-027 — Employers: kolom "Report Language"

- **Added:** 9-11-2026. **Status:** Done 10-11-2026 (Eddy). Metadata samengevoegd 10-11-2026 (zie MS-028). Let op: in de metadata heet de kolom intern én als weergavenaam "Language" (niet "Report Language"); keuzes staan niet in de metadata. Fase C gebruikt de interne naam Language op Employers. Eddy: controleer of de weergavenaam in SharePoint "Report Language" is; voor de app maakt het niet uit.
- **Reason:** tweede taal van het Week Report per contractor (DECISIONS.md WR1).
- **Kolom:** Employers, "Report Language", type keuze; keuzes Dutch, English, Polish, Romanian, German, Ukrainian; geen standaardwaarde.
- **Let op:** de keuzes van Employers.Language, Workers.Language en Translations.Language moeten exact gelijk blijven (H30); bij een nieuwe taal de procedure "Nieuwe taal" onderaan volgen.
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

- **Added:** 9-11-2026. **Status:** Done 13-11-2026 (Eddy): flow in Studio toegevoegd, save `Incoming\20261113-Site Management.msapp` (745701 bytes, SHA-256 0EDA514839D49C367C6F25ED04043754D61538EEEAAC18B384C9AB762D2AAFD1; kopie met Id e723e153-8a04-482e-94b4-761730022950, niet overgenomen). App in Power Apps hernoemd naar "SiteManagement" (Eddy); het bronbestand blijft Site Managment_VS.msapr.
- **Samengevoegd (Claude, 13-11-2026, commit 74c37bf):** `msapp\References\DataSources.json` uit de save (verschil: nieuwe bron **SiteManagment-Exportfile**, weergavenaam "SiteManagment - Export file", flow-ID 22e34f1b-8ed5-4ab3-a193-d4bfb6aa41a6; trigger text..text_4 = Folder, FileName, Format, Content, TemplateName (optioneel); response status, fileurl, message; Project Workers alleen andere volgorde van de naamtoewijzing) en in Properties.json alleen LocalConnectionReferences (nieuw: logicflows-verbinding 05aa5755 voor de flow, OneDrive for Business 6c6381a7 als afhankelijkheid van de flow, SharePoint b4a62a3e met de flow als dependent). App Id 88e53928 en de rest van Properties.json ongewijzigd; geen ondertekende URL's. Niet overgenomen: Src, Templates.json, Resources.json, Header/PublishInfo/AppChecker.
- **Gekoppelde flows in de app:** SiteManagment-Exportfile (nieuw) en de oude PowerAppV2-flow "PowerAppV2->LastIDinit,BatchCountinit,ReportHoursInit" (stond er al, niet gebruikt, niet verwijderd). GetWeeklyHoursData, SiteHoursConnector en FlowConfig zijn niet gekoppeld.
- **Stappen:**
  1. Open de app in Studio en voeg via Data (of het Power Automate-paneel) de flow "SiteManagement - Export file" toe. Maak geen verbindingen zelf in YAML.
  2. Wijzig verder niets en sla op.
  3. Zet de save in Incoming\ (bijvoorbeeld via Save as -> This computer).
  4. Meld de exacte naam waarmee de flow in Studio verschijnt (bv. 'SiteManagement-Exportfile'). Daarna neem ik alleen de flowkoppeling over in de .msapr, zoals bij MS-028: App Id 88e53928, de rest uit die save niet.
- **Nodig voor fase C:** zonder deze save kan de Export-knop de flow niet aanroepen en faalt de Studio-import.

## MS-032 — Documentteksten importeren in Translations

- **Added:** 13-11-2026. **Status:** Done 13-11-2026 (Eddy): CSV via de rasterweergave in Translations geplakt, 138 items (lijst was leeg). Weergave "Per key" (gegroepeerd op Key) toegevoegd.
- **Reason:** fase C (Week Report-PDF) leest de doc.*-teksten uit de lijst Translations (WEEKREPORT_PLAN.md 6.3, WR5). Bron: templates/translations-weekreport.csv (23 sleutels x 6 talen = 138 regels; UTF-8 met BOM, scheiding ";").
- **Stappen:**
  1. Controleer in SharePoint de kolomnamen van Translations: Key (interne naam Title), Language (sinds MS-035 keuze, verplicht), Text (meerdere regels). Wijken ze af, meld dat vóór de import.
  2. Importeer de CSV (bv. openen in Excel en plakken in de rasterweergave van de lijst). Language exact zoals in de CSV: Dutch, English, Polish, Romanian, German, Ukrainian (= keuzes van Workers.Language).
  3. Bestaande doc.*-regels met dezelfde Key + Language: vervangen, niet dubbel laten staan.
  4. Controleer na de import: 138 regels met Key "doc.*", Oekraïense teksten in Cyrillisch leesbaar (geen ?-tekens), placeholders {date} {user} {page} {pages} ongewijzigd.
- **Let op:** pl/ro/de/uk zijn nog niet door native speakers gecontroleerd (backlog). Wijzigingen in de lijst ook in de repo-CSV vastleggen.


## MS-033 — Lijst AppSettings (primaire rapporttaal)

- **Added:** 13-11-2026. **Status:** Done 14-11-2026 (Eddy): lijst AppSettings (Key = hernoemde Title, Value), item report.primaryLanguage = Dutch; in Studio toegevoegd, Translations en Employers ververst; save `Incoming\20261114-SiteManagement.msapp` (SHA-256 C6C784794CED198C07829EC3D74FE0C22E12EA29D97B2D4E90C744C5CE42FC39). **Samengevoegd 14-11-2026 (Claude):** DataSources.json uit die save (Translations.Language keuze, Employers) + LocalConnectionReferences; App Id 88e53928. Let op: in die save ontbreekt de databron AppSettings (Studio laat een ongebruikte databron vermoedelijk weg bij opslaan). De definitie van AppSettings komt daarom uit de eerdere save `Incoming\20261114-Site Management.msapp` (zelfde lijst-ID 5d247665-b8a2-4178-a6f8-90c66b53ca42; daar heet de kolom nog Title, niet Key: de app gebruikt de interne naam Title). Controle bij de import van build c4: TP-EXPORT-02 V1. De app leest nu `Filter(AppSettings, Title = "report.primaryLanguage")`; ontbreekt de sleutel, is Value leeg, staat hij er twee keer in of faalt de read: geen export, rode melding. ReportPrimaryLanguage is weg.
- **Reason:** DECISIONS.md H27: de taal van pagina 1 van de Week Report-PDF is een instelling (standaard Dutch), geen vaste waarde in formules. Er is geen bestaande configuratielijst in de app (FlowConfig is een flow, niet gekoppeld). Tot deze stap gedaan is gebruikt de app één named formula `ReportPrimaryLanguage = "Dutch"` in App.Formulas.
- **Stappen:**
  1. Maak op https://geacloud.sharepoint.com/sites/GEASiteManagment de lijst **AppSettings**: kolom Title hernoemen naar **Key** (interne naam blijft Title, enkele regel tekst, verplicht, unieke waarden afdwingen), kolom **Value** (enkele regel tekst). Geen andere kolommen.
  2. Item toevoegen: Key `report.primaryLanguage`, Value `Dutch` (zelfde schrijfwijze als de keuzes van Language: Dutch, English, Polish, Czech, Romanian, Ukrainian, German, French).
  3. Rechten: lezen voor alle app-gebruikers; wijzigen alleen eigenaren.
  4. Open de app in Studio, voeg via Data de lijst AppSettings toe, wijzig verder niets, sla op en zet het bestand in `Incoming\` (zoals MS-030). Meld bestandsnaam en SHA-256.
- **Daarna (Claude):** metadata samenvoegen (DataSources.json + LocalConnectionReferences, zoals MS-028/MS-030) en ReportPrimaryLanguage vervangen door een lookup in AppSettings (Key = "report.primaryLanguage"). Fail-closed (Eddy 14-11-2026, H29): sleutel ontbreekt, lege Value of leesfout = geen export, rode melding. Geen bouw vóór de Incoming-save.

## MS-034 — Employers: rapporttaal (kolom Language) verplicht

- **Added:** 13-11-2026. **Status:** Stap 1 done 14-11-2026 (Eddy): weergavenaam "Language", ingevuld bij alle Employers (één echte contractor heeft Czech). Require staat nog uit (stap 2-3 open, na het Contractors-veld).
- **Reason:** DECISIONS.md H27: pagina 2 van de Week Report-PDF is de rapporttaal van de contractor (Employers, kolom **Language**: interne naam en weergavenaam volgens de metadata), zonder terugval. Een lege waarde blokkeert de export voor die contractor (rode melding). Daarom verplicht in SharePoint.
- **Stappen:**
  1. Nu: vul Language in bij alle bestaande Employers (actief en inactief) via een weergave met filter Language is leeg. Dit volstaat voor de export (lege taal = rode melding, geen export voor die contractor).
  2. **Nog niet** aanzetten: kolominstelling "Require that this column contains information = Yes". Reden: het Contractors-scherm heeft het veld Language nog niet; met verplicht aan weigert SharePoint dan elke **New** contractor (Patch zonder verplichte kolom) en een Save van een bestaand item zonder taal. Eerst krijgt Contractors het veld (backlog, aparte opdracht); daarna zet je stap 2 aan.
  3. Na de Contractors-wijziging: Require = Yes, geen standaardwaarde.
- **Controle:** geen enkel Employers-item met lege Language.

## MS-035 — Translations: index op Language

- **Added:** 14-11-2026. **Status:** Done 14-11-2026 (Eddy, 00:30-00:40): Translations.Language van tekst naar **Choice** (Dutch, English, Polish, Romanian, German, Ukrainian), verplicht, waarden behouden (138), index verwijderd en opnieuw gemaakt op Language. De app leest nu `Filter(Translations, Language.Value = <taal>)` (gedelegeerd). **Metadata:** ververst in Incoming\20261114-SiteManagement.msapp en samengevoegd 14-11-2026 (Test-Languages PASS). Sinds 14-11-2026 8 keuzes (Czech en French erbij, Eddy).
- **Reason:** DECISIONS.md H29: de Week Report-export leest Translations per taal met `Filter(Translations, Language = <taal>)` (gedelegeerd). Een index op Language houdt die read werkend als de lijst later groot wordt (andere documenten). Lokale metadata bewijst geen index (AGENTS); controleer online.
- **Stappen:** lijst Translations > List settings > Indexed columns > Create a new index > kolom **Language** (enkele regel tekst). Geen andere wijziging.
- **Controle:** Indexed columns toont Language. Meld het als de index niet kan (bv. kolomtype). Controleer ook dat Language overal exact gespeld is (Dutch, English, Polish, Czech, Romanian, Ukrainian, German, French; geen spatie ervoor of erna): de read vergelijkt nu exact op de server; een afwijkende spelling geeft bij de export "texts missing".

## MS-036 — Translations: teksten voor Czech en French

- **Added:** 14-11-2026. **Status:** Gedaan (Eddy 14-11-2026; vastgelegd 15-11-2026).
- **Uitvoering (Eddy):** 46 regels Czech/French geplakt; de eerste keer twee keer geplakt, de 46 dubbele regels verwijderd. Resultaat: Translations 184 items, weergave "Per key" toont per sleutel 8 talen (23 x 8, geen dubbele meer). Functionele controle in de app: TP-EXPORT-02 stap 11.
- **Reason:** Czech en French zijn sinds 14-11-2026 keuzes in Workers.Language, Employers.Language en Translations.Language (H30). Zonder deze teksten geeft de export voor een contractor met Czech of French de rode melding "texts missing in Translations" (geen export voor die contractor).
- **Bron:** templates/translations-weekreport-cs-fr.csv (46 regels = 23 sleutels x Czech + French; UTF-8 met BOM, scheiding ";", kop Key;Language;Text). De volledige lijst staat in templates/translations-weekreport.csv (184 regels = 23 x 8).
- **Stappen:**
  1. Open de lijst Translations > Edit in grid view.
  2. Plak de 46 regels uit translations-weekreport-cs-fr.csv (zonder de kopregel) zoals bij MS-032. Language moet de keuze Czech of French worden; controleer dat geen regel leeg blijft.
  3. Controle: weergave "Per key" toont per sleutel 8 talen; filter Language = Czech geeft 23 items, French 23 items. Totaal 184.
- **Daarna:** TP-EXPORT-02 stap 11. Native-speaker-controle van cs/fr staat in de backlog (PROJECT_STATUS).

## MS-037 — Flow "SiteManagement - Export file": CSV-map, extensies en retry

- **Added:** 16-11-2026. **Status:** Done 16-11-2026 (Eddy: geïmporteerd als Update van flow 22e34f1b; stap 2, 3 en 4 PASS: pdf + csv met extensie, groen).
- **Reden:** TP-EXPORT-02 c6 (Eddy 16-11-2026): de PDF-aanroep werkt; de CSV-aanroep geeft in de app "UnexpectedError" en de run blijft op Running staan. Review van de flowexport (Incoming\Flows\Sitemanage-Exportfile_20261116094746.zip, geschoonde kopie flows/SiteManagement-Export-file.definition.json) tegen het contract WEEKREPORT_PLAN par. 6.5.
- **Bevindingen:**
  - F1 (blokkerend, CSV): Case_CSV > Create file, Folder Path = `/Exports/@{triggerBody()?['text_1']}@{triggerBody()?['text_3']}` = FileName + de hele CSV-inhoud als mapnaam (BOM, regeleinden, ";", aanhalingstekens, honderden tekens). Moet `/Exports/@{triggerBody()?['text']}` (Folder) zijn, zoals in de PDF-tak.
  - F2 (blokkerend, contract): File Name is in beide takken alleen FileName (`text_1`). Het contract zegt "FileName zonder extensie"; de flow moet `.csv` en `.pdf` toevoegen. De huidige PDF heet dus waarschijnlijk zonder `.pdf` (controleer in Exports/TEST-000).
  - F3 (waarschijnlijke verklaring van de vastgelopen run, niet bewezen): geen enkele actie heeft een retry-instelling, dus Power Automate gebruikt de standaard (tot 4 herhalingen met oplopende wachttijd). Een Create file met dit ongeldige pad kan zo lang opnieuw geprobeerd worden dat de run op Running blijft staan terwijl de app de aanroep al als fout ("UnexpectedError") afsluit. Open in de vastgelopen run Try > Switch > Case_CSV > Create file: staat daar een herhaling of foutcode, dan is dit bevestigd. Na F1 verdwijnt de directe oorzaak; met retry None komt een fout voortaan meteen bij de Catch.
  - F4 (klein): CSV antwoordt Status "Ok", PDF "OK". De app vergelijkt hoofdletterongevoelig; zet beide op "OK" volgens het contract.
  - F5 (klein): PDF FileUrl = `Create_file_2` body/Path (serverpad, niet klikbaar); CSV gebruikt Get file properties {Link}. Contract: FileUrl klikbaar. Zet PDF ook op Get file properties 1 > Link to item.
  - Gecontroleerd en goed: trigger (Power Apps V2) met Folder/FileName/Format/Content verplicht en TemplateName optioneel; Switch op Format met cases `csv` en `pdf` en default "Unknown format"; vier Respond-acties met status/fileurl/message; Catch-Respond draait na Try Failed/TimedOut; PDF-volgorde template -> header -> BODY -> HEADER -> OneDrive .html -> Convert -> SharePoint -> tijdelijk bestand verwijderen; geen concurrency-instelling op de trigger (er is dus geen wachtrij door de flowinstellingen).
- **Werkwijze (Eddy 16-11-2026):** flowwijzigingen via import van een pakket, niet in de designer. Claude past alleen definition.json aan in een kopie van Eddy's export; manifest, connections en ID's blijven gelijk.
- **Pakket fix1:** artifacts\flows\SiteManagement-Export-file-fix1.zip (4010 bytes, SHA-256 372AF1B4D3819AA1EE922990A58CD31EBCF89E35BD877433C0BA82DE34E2BDC4; niet in git). Gemaakt uit Incoming\Flows\Sitemanage-Exportfile_20261116094746.zip; alleen definition.json gewijzigd (de andere 4 entries byte-gelijk; terugdraaien van de 5 wijzigingen geeft exact het origineel).
- **Wijzigingen in fix1:**
  1. Case_CSV > Create file: Folder Path = `/Exports/@{triggerBody()?['text']}` (Folder).
  2. File Name = `@{triggerBody()?['text_1']}.csv` (Case_CSV > Create file) en `@{triggerBody()?['text_1']}.pdf` (Case_PDF > Create file 2).
  3. Retry Policy op alle 9 SharePoint/OneDrive-acties = fixed, 2 keer, interval PT5S (de app wacht synchroon; begrensd in plaats van de standaard tot 4 oplopende herhalingen).
  4. CSV-antwoord Status = `OK`.
  5. PDF-antwoord FileUrl = Get file properties 1 > Link (`body/{Link}`), klikbaar.
- **Stappen (import):**
  1. Annuleer eerst de vastgelopen run: make.powerautomate.com > My flows > SiteManagement - Export file > Run history (All runs) > open de run die Running staat > Cancel run.
  2. My flows > **Import** > **Import Package (Legacy)** > **Upload** > kies `SiteManagement-Export-file-fix1.zip` > wacht tot het pakket gelezen is.
  3. Bij de flow (Resource type Flow) > **Import setup** (Action "Create as new") > kies **Update** > selecteer de bestaande flow **SiteManagement - Export file** (ID 22e34f1b…) > **Save**. Niet "Create as new": dan krijgt de flow een nieuw ID en verliest de app de koppeling.
  4. Bij de verbindingen (SharePoint en OneDrive for Business, Related resources) > **Select during import** > kies je bestaande verbinding > **Save**. Doe dit voor beide.
  5. **Import** > wacht op "All package resources were successfully imported".
  6. Open de flow > controleer bovenaan dat hij **On** staat (anders **Turn on**). Controleer in Details > Run only users dat SharePoint en OneDrive nog op "Provided by run-only user" staan (zoals voor de import).
  7. Optioneel ter controle: Edit > Case_CSV > Create file toont Folder Path `/Exports/` + Folder en File Name FileName + `.csv`; ... > Settings bij een actie toont Retry Policy Fixed interval, Count 2, Interval PT5S. Niets opslaan als je niets wijzigt.
  8. Ruim in Exports/TEST-000 een PDF zonder extensie op, en een eventuele vreemde map die met `TEST_WeekReport` begint.
- **Daarna:** TP-EXPORT-02 stap 2 opnieuw (Test Contracter 2): verwacht groen "Exported. Saved in Exports/TEST-000: ….pdf and ….csv", twee bestanden met extensie, run history twee runs Succeeded. Stuur na de wijziging een nieuwe flowexport naar Incoming\Flows, dan vergelijk ik hem met flows/SiteManagement-Export-file.definition.json.

## MS-038 — AppSettings: CSV-scheidingsteken en decimaalteken

- **Added:** 16-11-2026. **Status:** Done 16-11-2026 (Eddy): csv.separator `,` en csv.decimalSeparator `,` toegevoegd; TP-EXPORT-02 c7 stap 5a PASS (Excel Hours 7,5 en 3 elk in één kolom), 5c PASS.
- **Reden:** TP-EXPORT-02 c6 stap 5 (Eddy 16-11-2026): de GEA-pc's hebben decimaal "," en lijstscheiding ","; Excel splitste 7,5 in 7 | 5. Vanaf build c7 zet de app alle tekst-, datum- en urenvelden tussen aanhalingstekens en leest het scheidingsteken en het decimaalteken uit AppSettings (DECISIONS H32). Excel splitst bij dubbelklikken op de lijstscheiding van de pc: "7,5" blijft één veld zodra csv.separator gelijk is aan die lijstscheiding. Excel > Data > From Text/CSV werkt altijd (scheidingsteken kiezen in het venster). Ontbreekt een sleutel, dan geldt de standaard; een dubbele sleutel of een andere waarde geeft rood (geen export).
- **Stappen:** SharePoint GEASiteManagment > lijst **AppSettings** > **+ New** (twee keer):
  1. Key `csv.separator`, Value `,` (toegestaan: `;` of `,`). Voor de GEA-pc's met lijstscheiding "," is `,` naar verwachting juist; stap 5a van TP-EXPORT-02 c7 beslist. Zonder deze regel gebruikt de app `;`.
  2. Key `csv.decimalSeparator`, Value `,` (toegestaan: `,` of `.`).
  - Exact deze spelling, geen spaties. Elke sleutel precies één keer.
- **Wanneer welke waarde:** kies `csv.separator` gelijk aan de lijstscheiding van de pc's die de CSV openen (Windows: Taal en regio > Aanvullende instellingen > Lijstscheidingsteken). Pc's met verschillende lijstscheidingen kunnen niet tegelijk met dubbelklikken bediend worden; daar werkt Excel > Data > From Text/CSV.
- **Daarna:** TP-EXPORT-02 c7 stap 5a/5b.

## MS-039 — Translations: landnamen (country.*) plakken

- **Added:** 16-11-2026. **Status:** Done 16-11-2026 (Eddy): 384 landregels geplakt, Translations 568 items; TP-EXPORT-02 c8 stap 4 PASS (Land Nederland / Kraj Holandia).
- **Reden:** v1.0.0 (Eddy 16-11-2026): het Land in het PDF-infoblok (Projects.Country) moet in de paginataal staan; nu staat overal "Netherlands". Vanaf build c8 leest de app de vertaling uit Translations, Key `country.<keuzewaarde>` (DECISIONS H33). Ontbreekt een regel, dan toont de PDF de ruwe waarde (geen blokkade).
- **Bron:** templates/translations-countries.csv: 384 regels = 48 landen x 8 talen (UTF-8 met BOM, scheiding ";", kop Key;Language;Text). Daarna Translations 568 items (184 + 384); per taal 71 (ruim onder de 500-grens).
- **Stappen:**
  1. Open de lijst Translations > Edit in grid view.
  2. Plak de 384 regels uit translations-countries.csv (zonder de kopregel) zoals bij MS-036, in delen als het plakken traag is. Language moet de keuze worden; controleer dat geen regel leeg blijft en dat niets dubbel geplakt is.
  3. Controle: filter Language = Dutch geeft 71 items, Polish 71; totaal 568. Zoek `country.Netherlands`: 8 regels (Dutch Nederland, Polish Holandia).
  4. Vergelijk de keuzes van **Projects.Country** (lijst Projects > kolom Country > Column settings > Edit) met de landen in de CSV: de Key na `country.` moet exact de keuzewaarde zijn (de app negeert hoofdletters en spaties aan begin/eind). Staat een keuze er niet in, meld de exacte waarde aan Claude (dan komt er een regel per taal bij); zonder regel toont de PDF de Engelse keuzewaarde.
- **Daarna:** TP-EXPORT-02 c8 stap 4.

## MS-040 — Oude cloudkopieën van de app opruimen (later)

- **Added:** 16-11-2026. **Status:** Open, later (Eddy). Niet nu.
- **Reden:** v1.0.0 is gepubliceerd in de cloud-app "SiteManagement" (cloud App ID 5d595ec0-97d7-49f5-80b4-09a65cfa1e30; vervangt de oorspronkelijke "Site Managment"). Eerdere Studio-saves in de cloud staan nog als losse apps en worden niet gebruikt: 20261114-SiteManagement, 20261113-Site Management, Site Managment 10-11-2026, 20261104…, 20261102Components, 20261031…, 20261027…, 20262610…, 20261026… (2x).
- **Waarom handmatig:** apps verwijderen kan alleen in make.powerapps.com (Apps > … > Delete); er is geen importroute.
- **Stappen (pas na bevestiging, één voor één):** controleer per kopie dat het niet de cloud-app 5d595ec0-97d7-49f5-80b4-09a65cfa1e30 is (Details > App ID) en dat niemand hem gebruikt (gedeeld met / laatst geopend); verwijder daarna. Verwijder nooit "SiteManagement".
- **Voorkomen:** Studio "Save as" voor Incoming altijd naar "This computer", nooit in de cloud.

## MS-041 — Verbinding Microsoft Translator V2 (H34)

- **Added/Done:** 16-11-2026 (Eddy). **Status:** Done.
- **Uitgevoerd:** in Power Automate een verbinding "Translator SiteManagement" voor de connector Microsoft Translator V2 (Standard), zonder subscription key. Status Connected, geen DLP-blokkade. Microsoft Translator V3 is afgewezen (vereist een Azure-resource).
- **Waarom handmatig:** een verbinding aanmaken vraagt om je eigen aanmelding; er is geen importroute.
- **Daarna (bij de bouw van werkpakketten):** Claude levert de vertaalflow als importpakket (Create as new). Bij het importeren kies je deze verbinding.

## MS-042 — Consentteksten in Translations (H36, H37)

- **Added:** 17-11-2026. **Status:** Done 18-11-2026 via de importflow (bestand upsert_translations-ms042-8lang.csv = weekreport 184 + countries 384 + consent-8 720 = 1288 regels; resultaat Added 176, Updated 1112, Exists 0, Duplicates 0, Errors 0; Eddy telde 1288). Historie: deels geplakt. Op 17-11-2026 telde Translations 1111 regels; verwacht na translations-consent-8.csv is 1288, dus er ontbreken er circa 177. **Nieuwe route (17-11-2026):** niet meer plakken. Na MS-046 zet Claude translations-consent-8.csv in Imports/Translations/ (alleen toevoegen). De flow voegt de ontbrekende regels toe en meldt EXISTS en DUPLICATE; dubbele regels worden alleen opgesomd, niet verwijderd. De stappen hieronder zijn alleen nog een terugvaloptie.
- Niet dringend: de consent is nog niet gebouwd.
- **Bestanden** (UTF-8 met BOM, scheiding ";", kop Key;Language;Text): `templates/translations-consent-8.csv` (720 regels = 90 sleutels × 8 bestaande talen) en `templates/translations-consent-be.csv` (90 regels Belarusian). Bron en controle: `templates/translations-consent.csv` (810 regels, Test-Templates).
- **Stappen:**
  1. Open Translations > Edit in grid view.
  2. Plak translations-consent-8.csv zonder de kopregel. Plak in delen als het traag gaat en controleer dat niets dubbel geplakt is.
  3. Plak translations-consent-be.csv pas na MS-043 stap 1 (Belarusian als keuze).
  4. Controle: zoek op `consent.`; je vindt 720 regels, en 810 na Belarusian. Totaal Translations: was 568 (184 doc + 384 land), wordt 1288 na translations-consent-8.csv, en 1449 na alle Belarusian-regels (23 + 48 + 90 = 161). Per taal 161 regels, ruim onder de 500.
- **Wijziging 17-11-2026 (H38):** `consent.lblSignature` is nu neutraal "Handtekening:" (zonder "(Fill & Sign)"). Had je translations-consent-8.csv al eerder geplakt, pas dan in Translations de 8 regels van consent.lblSignature aan (of plak die regels opnieuw).
- **Let op:** NL, PL, UK en BE zijn letterlijk overgenomen uit de voorbeeldformulieren, met de wijzigingen van H36. EN, CS, RO, DE en FR zijn vertaald vanuit NL; hun voettekst zegt "unofficial translation" (in de eigen taal). Al het niet-Nederlandse moet nog door een moedertaalspreker gecontroleerd worden (backlog).
## MS-043 — Belarusian als 9e taal (H37, V6)

- **Added:** 17-11-2026. **Status:** Done 18-11-2026. Stap 1 Eddy; stap 2-3 via de importflow (translations-ms043-be.csv, 161 regels, alleen toevoegen): Added 161, Updated 0, Exists 0, Duplicates 0, Errors 0. Verwacht totaal Translations 1449 (Eddy kan dit online bevestigen). De app-taalcode be volgt in de consent-build.
- **Waarom handmatig (stap 1):** keuzes van een keuzekolom bewerken kan alleen in de kolominstellingen; er is geen importroute. De teksten zijn bestanden.
- **Stappen:**
  1. Voeg in **Workers.Language**, **Employers.Language** en **Translations.Language** de keuze `Belarusian` toe: exact deze spelling, met hoofdletter en zonder spaties (procedure "Nieuwe taal", stap 1).
  2. Translations > Edit in grid view: plak `templates/translations-weekreport-be.csv` (23 regels) en `templates/translations-countries-be.csv` (48 regels), zonder kopregel.
  3. Plak `templates/translations-consent-be.csv` (90 regels, MS-042).
  4. Controle: filter Language = Belarusian geeft 161 regels (23 + 48 + 90). Totaal Translations daarna 1449 (als MS-042 gedaan is: 1288 + 161).
- **Opgelost in v1.0.2 (19-11-2026):** taalcode `be` zit in de app (Week Report). Oorspronkelijke opmerking: de taalcode `be` in de app volgt bij de volgende build. Tot dan geeft het Week Report voor een contractor met Language = Belarusian rood "no file language code" (geen export). Kies Belarusian dus nog niet bij een contractor met uren die geëxporteerd moeten worden. Alle Belarusian-teksten moeten nog door een moedertaalspreker gecontroleerd worden.

## MS-044 — Lijsten Customers en ProjectSafety (From Excel; DESIGN_CUSTOMERS_SAFETY.md)

- **Added:** 17-11-2026. **Status:** Vervallen 18-11-2026 (H40: geen lijsten Customers/ProjectSafety). Niet uitvoeren.
- **Bestanden:** `artifacts\lists\Customers.xlsx` (4 kolommen) en `artifacts\lists\ProjectSafety.xlsx` (18 kolommen). Ze staan niet in git; maak ze opnieuw met `py -E -P artifacts\lists\make_list_templates.py`.
- **Stappen:**
  1. Ga naar SharePoint GEASiteManagment > New > List > From Excel en upload Customers.xlsx (tabel tblCustomers).
  2. Controleer de kolomtypen in het importvenster: Title en City = Single line of text. Phone = Single line of text (niet Number). Active = Yes/No; biedt het venster dat niet aan, kies dan tekst en zet het type daarna om. Lijstnaam: **Customers**.
  3. Doe hetzelfde met ProjectSafety.xlsx (tabel tblProjectSafety), lijstnaam **ProjectSafety**. PlanStartDate = Date. AssemblyPoint = Multiple lines of text (plain). Alle telefoonnummers en 112 = Single line of text (niet Number). De rest = Single line of text.
  4. Controleer dat Title gebruikt is voor de kolom "Title" uit Excel (geen tweede, lege Title). Zie je toch een extra kolom, meld het: dan pas ik het ontwerp aan.
  5. ProjectSafety: verander de voorbeeldrij in TEST-000 (Title = het ID van TEST-000 als tekst) of verwijder hem. Customers: laat "TEST Customer" staan (TEST-regel) en verwijder "TEST Customer 2".
- **Daarna:** MS-045.

## MS-045 — Uniek, lookups en standaardwaarden (na MS-044)

- **Added:** 17-11-2026. **Status:** Vervallen 18-11-2026 (H40). Niet uitvoeren.
- **Waarom handmatig:** unieke waarden, lookupkolommen en standaardwaarden kun je niet via een Excel-import instellen.
- **Stappen:**
  1. Customers > kolom Title (Customer Name): Require = Yes, Enforce unique values = Yes. Weergavenaam "Customer Name".
  2. Customers > Active: standaard Yes.
  3. ProjectSafety > Title: Require = Yes, Enforce unique values = Yes (ProjectKey).
  4. ProjectSafety > Add column > Lookup: naam **Project**, bron Projects, kolom Title.
  5. Projects > Add column > Lookup: naam **Customer**, bron Customers, kolom Title, één waarde, niet verplicht.
  6. Laat Projects."Customer Name" (tekst) staan; die verwijderen we pas na jouw akkoord (D4).
  7. Studio: Data > Add data > Customers en ProjectSafety; Projects > Refresh; Save as > This computer > Incoming. Daarna voegt Claude de metadata samen.

## MS-046 — Importroute voor lijstgegevens: flow "SiteManagement - Import rows" (eenmalig)

- **Added:** 17-11-2026. **Status:** Done 17-11-2026 (Eddy): v1 gaf een nestingfout, v2 geïmporteerd met Update, flow aan, Imports gesynchroniseerd. Eerste run (MS-042) geslaagd; traag (1288 regels in ca. 6 uur), aanvaard door Eddy. Daarna levert en importeert Claude lijstgegevens zelf (werkwijze Eddy 17-11-2026); het plakken in de rasterweergave vervalt.
- **Waarom deze route:** Graph PowerShell (route 1) is geblokkeerd door GEA Conditional Access. Met een apparaatcode is de aanmelding geldig, maar het apparaat moet "managed by GEA" zijn. Bij de interactieve Windows-aanmelding kwam er geen token.
- **Bestand:** `artifacts\flows\SiteManagement-Import-rows-v2.zip` (niet in git; v2 17-11-2026: v1 gaf bij importeren of aanzetten "nested at level 9 ... maximum nesting limit of 8"; v2 heeft maximaal diepte 4 en geen OneDrive-verbinding meer, controle artifacts/Test-FlowNesting.ps1). Maak het opnieuw met `py -E -P flows\make_import_rows_package.py`; dat gebruikt je laatste export van de Export-flow in Incoming\Flows.
- **Stappen:**
  1. SharePoint GEASiteManagment > New > Document library, naam **Imports**. Waarom handmatig: er is geen importroute voor een bibliotheek.
  2. Power Automate > My flows > Import > Import Package (Legacy). Upload de zip en kies bij de flow **Create as new**; de naam is al "SiteManagement - Import rows". Kies bij SharePoint je bestaande verbinding (vanaf v2 is er geen OneDrive-verbinding meer). Is de flow uit v1 al aangemaakt, kies dan **Update** > "SiteManagement - Import rows" in plaats van Create as new. Klik Import.
  3. Open de flow en controleer dat de trigger "When a file is created (properties only)" de bibliotheek **Imports** toont. Zie je een fout of een lege bibliotheek, kies dan Imports in de keuzelijst en klik Save. Zet de flow aan (Turn on).
  4. Open de bibliotheek Imports en klik **Sync**, zodat hij in Verkenner staat (OneDrive). Geef Claude het lokale pad. Claude zet daar voortaan de CSV-bestanden neer en leest de resultaten.
- **Werking (voor controle):**
  - **Invoer:** een CSV in `Imports/<Lijst>/`. Toegestane lijsten: Translations, AppSettings, Customers, ProjectSafety.
  - **Formaat:** UTF-8, ";" als scheidingsteken, kopregel met interne kolomnamen ("Key" telt als Title), geen aanhalingstekens. Alleen de laatste kolom mag ";" bevatten.
  - **Sleutel:** voor Translations Title + Language, anders Title.
  - **Standaard alleen toevoegen:** bestaat de sleutel al, dan EXISTS en geen wijziging. Bijwerken alleen als de bestandsnaam begint met `upsert_`. Meerdere rijen met dezelfde sleutel: DUPLICATE, niets gewijzigd en niets verwijderd.
  - **De flow verwijdert nooit iets.**
  - **Na afloop:** het resultaat staat in `Imports/Done/<tijd>_<bestand>.result.csv` (eerste regel Summary met Added/Updated/Exists/Duplicates/Errors). Het bronbestand wordt verplaatst naar Imports/Done.
- **Beperkingen v1:**
  - Datumkolommen moeten in de regionale notatie van de site staan.
  - Lookups als ID.
  - Gegevens met regeleinden kunnen niet.
  - Nog niet online getest: de eerste run (MS-042) is de acceptatietest.

## MS-047 — Kolommen voor de consent (H40)

- **Added:** 18-11-2026. **Status:** Open (Eddy). Daarna bouwt Claude de consent.
- **Waarom handmatig:** kolommen toevoegen aan een bestaande lijst kan niet via de importflow of een Excel-import.
- **Belangrijk:** typ bij het aanmaken eerst exact de naam hieronder (zonder spaties; dat wordt de interne naam). De weergavenaam mag je daarna aanpassen (tussen haakjes de voorgestelde weergavenaam).
- **Stappen:**
  1. Projects > Add column > Single line of text: `CustomerCity` (Customer City), `CustomerPhone` (Customer Phone), `SupervisorPhone` (Supervisor Phone). Niet verplicht, geen standaard. De bestaande kolom Customer Name (intern CustomerName) blijft de klantnaam; Site Managers blijft de VGM-toezichthouder.
  2. Project Workers > Add column > Choice: `ConsentStatus` (Consent Status), keuzes exact `Not generated`, `Generated`, `Signed`; geen standaardwaarde (leeg = Not generated), niet verplicht, geen eigen waarden toestaan.
  3. Project Workers > Add column > Date and time: `ConsentDate` (Consent Date), alleen datum, niet verplicht.
  4. Studio (app uit v1.0.0): Data > Projects > Refresh en Data > Project Workers > Refresh. Daarna Save as > This computer > Incoming. Meld de bestandsnaam; Claude voegt alleen de metadata samen.
- **Controle:** de kolommen staan in Projects en Project Workers; bestaande gegevens veranderen niet.

## MS-048 — Schone start v1: testgegevens van echte projecten verwijderen (H41)

- **Added:** 18-11-2026. **Status:** Done 18-11-2026 (Eddy): project 1 verwijderd uit Hours (24), Assignment Periods (20) en Project Workers (19); Exports-map 100611613201 verwijderd; TEST-000 behouden.
- **Waarom handmatig:** verwijderen gebeurt bewust niet door de app of de importflow (die verwijderen nooit). Een aparte verwijderflow is voor ca. 63 rijen niet sneller dan filteren + selecteren + Delete, en riskanter.
- **Sleutels:** TEST-000 = project-ID 2 (ProjectKey `2`, EntryKey begint met `2|`). Friesland Campina = ID 1 (`1`, `1|`). Test-001 (ID 3) heeft geen rijen.
- **Verwachte aantallen** (export 18-11 17:52 + 2 teruggezette PW-rijen): Hours 37 → verwijder 24 → 13 over; Assignment Periods 31 → verwijder 20 → 11 over; Project Workers 28 → verwijder 19 → 9 over. Wijkt een aantal af: stop en meld het.
- **Volgorde:** eerst Hours, dan Assignment Periods, dan Project Workers (Hours verwijzen naar Project Workers).
- **Stappen per lijst (moderne lijstweergave):**
  1. **Hours:** open de lijst > klik de kolomkop **EntryKey** > **A to Z**. Alle `1|…`-rijen staan nu bovenaan, vóór de `2|…`-rijen. Klik het vinkje van de eerste rij, scroll naar de laatste `1|…`-rij en Shift+klik zijn vinkje (24 geselecteerd, teller rechtsboven). Controleer dat geen `2|`-rij geselecteerd is > **Delete** > Delete. Controle: 13 rijen over, allemaal `2|…`.
  2. **Assignment Periods:** kolomkop **ProjectKey** > **Filter by** > vink alleen `1` aan > Apply. Selecteer alles met het vinkje in de kop (20) > **Delete**. Filter wissen. Controle: 11 rijen over, allemaal ProjectKey `2`.
  3. **Project Workers:** zelfde als stap 2 met ProjectKey `1` (19 rijen). Controle: 9 rijen over, allemaal ProjectKey `2`.
  4. **Exports:** open de bibliotheek Exports > selecteer de map `100611613201` (FC, alleen testexports uit de bouwfase) > Delete. Laat de TEST-000-map staan. Andere mappen van echte projecten: idem.
  5. Sluit de app en open hem opnieuw (caches leeg).
- **Daarna (Eddy):** echte teams via Project / team met de echte startweek (bv. 2026 KW46), uren in Weekly Hours, Week report exporteren. Controlelijst in PROJECT_STATUS.md (H41).
- **Terugdraaien:** binnen 93 dagen via de prullenbak van de site.

## MS-050 — Flow "SiteManagement - Mail draft" (Week Report Mail, v1.0.2, H42)

- **Added:** 19-11-2026. **Status:** Done 19-11-2026 (Eddy): pakket v2 geïmporteerd met Update, verbindingen SharePoint + Office 365 Outlook, flow aan, toegevoegd in Studio; Incoming\20261119-SiteManagement-mail.msapp. Claude heeft alleen de data source `SiteManagement-Maildraft` en de verbindingen samengevoegd (App Id 88e53928 ongewijzigd). Nog open (Eddy, later): de vaste flow exporteren naar Incoming\Flows, zodat Claude de geschoonde definitie in de repo zet.
- **Bestand:** `artifacts\flows\SiteManagement-Mail-draft-v2.zip` (niet in git), SHA-256 `c5cc2d9ddae6714b9d943edf95710586199b8a6e6ecd9be343d66cd845d9d56a`. v2 (19-11-2026, na Eddys eerste import): de sleutel `@odata.type` in Add_attachment gaf "invalid expression" en is nu `@@odata.type` (letterlijke @); de Outlook-verbinding is niet meer gekoppeld aan de oude OneDrive-verbindingsnaam. Flow al geïmporteerd: Import Package (Legacy) > bij de flow **Update** > "SiteManagement - Mail draft", bij Office 365 Outlook je Outlook-verbinding kiezen. Maak het opnieuw met `py -E -P flows\make_mail_draft_package.py`.
- **Waarom deels handmatig:** een flow aan de app koppelen kan alleen in Studio; de metadata moet daarna uit een Studio-save komen.
- **Stappen:**
  1. Power Automate > My flows > Import > **Import Package (Legacy)** > upload de zip.
  2. Bij de flow: **Setup** > **Create as new**, naam **SiteManagement - Mail draft** (exact zo).
  3. Bij SharePoint: kies je bestaande SharePoint-verbinding. Bij **Office 365 Outlook**: kies je Outlook-verbinding of maak er een (Create new, aanmelden met je GEA-account). Klik **Import**.
  4. Open de flow > **Edit**. Controleer de stap **Create_draft** (Send an HTTP request): URI `https://graph.microsoft.com/v1.0/me/messages`, Method `POST`, Body gevuld, Content-Type `application/json`. Is een veld leeg of krijg je een foutmelding over parameters: stop en stuur mij een screenshot plus de Code view van die stap. Klik **Save**. De flow staat aan (Turn on als hij uit staat).
  5. Power Apps Studio: open de app (de huidige v1.0.2-testbuild of de gepubliceerde app) > linkermenu **Power Automate** (of Data) > **Add flow** > kies **SiteManagement - Mail draft**. Er verschijnt een data source (verwacht: `SiteManagement-Maildraft`); noteer de exacte naam als hij anders is.
  6. **File > Save as > This computer** en zet het .msapp-bestand in `Incoming\` (map Incoming in de projectmap). Niet publiceren.
- **Controle:** de flow staat aan en heeft 2 verbindingen (SharePoint, Office 365 Outlook). Meld de naam van de data source en het bestand in Incoming.

## MS-051 — Translations: mail.body (9 talen)

- **Added/Done:** 19-11-2026 (Claude, importflow, opdracht Eddy in de Mail-opdracht). Bron `templates/translations-mail.csv` (Key;Language;Text, 9 regels, plaatshouders {0} project, {1} week, {2} contractor, {n} nieuwe regel). Resultaat: Rows 9, Added 9, Updated 0, Exists 0, Duplicates 0, Errors 0. Verwacht totaal Translations 1458 (1449 + 9).
- **Let op:** de teksten zijn door Claude gemaakt; native-speaker-controle hoort bij het backlogpunt vertalingen.

## MS-052 — AppSettings: hours.fillPattern (Fill week, H43)

- **Added/Done:** 19-11-2026 (Claude, importflow, opdracht Eddy). Bron `templates/appsettings-fillpattern.csv` (Key;Value). Resultaat: Rows 1, Added 1, Errors 0.
- **Waarde:** `10,10,10,10,10,0,0` (ma..zo). Aanpassen: in AppSettings de Value van hours.fillPattern wijzigen. Met decimalen: scheid met `;`, bv. `7,5;7,5;7,5;7,5;7,5;0;0`. Ongeldig = rode melding bij Fill week, er wordt niets gevuld.

## MS-053 — ComboBox-template via Studio (zoekbare keuzelijsten, v1.0.2)

- **Added:** 19-11-2026. **Status:** Done 19-11-2026 (Eddy; template merged door Claude, alleen Templates.json).
- **Waarom handmatig:** de app bevat nog geen ComboBox-template (alleen Dropdown). Een nieuw controltype mag pas als Studio de template in de app zet (AGENTS, technische randvoorwaarden).
- **Stappen:**
  1. Open in Studio de testbuild v1.0.2 (zoals bij de vorige test).
  2. Open een willekeurig scherm (bv. Contractors). Insert > zoek **Combo box** en kies de **Classic**-versie (niet de moderne). Er verschijnt een combobox op het scherm; laat hem staan, niets instellen.
  3. File > **Save as** > **This computer** > zet het bestand in `Incoming\` (bv. `20261120-combobox.msapp`). Niet publiceren.
- **Daarna (Claude):** template en controlversie uit het bestand overnemen, de losse combobox niet overnemen, ComboBox bouwen in cmpField (Country/Language Contractors, Country Projects, Language/Trade Workers), tests, reviewer, pack v1.0.2.

## MS-054 — Keuzes Country gelijk maken (Employers + Projects)

- **Added:** 19-11-2026. **Status:** Done 19-11-2026 (Eddy).
- **Waarom handmatig:** de keuzes van een keuzekolom kun je alleen in de kolominstellingen bewerken; er is geen importroute.
- **Bestand:** `artifacts\lists\country-choices.txt` (49 landen, A-Z, één per regel; exact de spelling van de country.*-sleutels in Translations, gecontroleerd door Test-Templates). Bevat beide bestaande spellingen Czech Republic/Czechia en Turkey/Türkiye, omdat ze al in gegevens kunnen staan; nieuw: Belarus.
- **Stappen (per lijst, eerst Employers, dan Projects):**
  1. Lijst > instellingen (tandwiel) > **List settings** > klik de kolom **Country**.
  2. Open `country-choices.txt` in Kladblok, Ctrl+A, Ctrl+C. Klik in het vak **Type each choice on a separate line**, Ctrl+A, Ctrl+V.
  3. Laat staan: Display choices using = Drop-Down Menu, Allow fill-in choices = No. Standaardwaarde: Employers leeg, Projects **Netherlands**. Klik **OK**.
- **Controle:** maak in beide lijsten een weergave of filter op Country en kijk of er items zijn met een waarde die niet in de lijst staat (SharePoint laat die staan). Meld ze, dan pas ik de lijst aan.
- **Na MS-054:** in Studio Data > Employers en Projects > Refresh is niet nodig (de keuzes worden live gelezen).

## MS-049 — Importflow v3 (sneller), v1.0.1

- **Added:** 18-11-2026. **Status:** Open (Eddy).
- **Bestand:** `artifacts\flows\SiteManagement-Import-rows-v3.zip` (niet in git). Maak het opnieuw met `py -E -P flows\make_import_rows_package.py`.
- **Stappen:** ga naar Power Automate > My flows > Import > Import Package (Legacy). Upload de zip en kies bij de flow **Update** > "SiteManagement - Import rows". Kies je bestaande SharePoint-verbinding, klik Import en laat de flow aan staan.
- **Werking v3:**
  - De bestaande rijen worden één keer gelezen in plaats van per regel.
  - Er worden 10 regels tegelijk verwerkt.
  - Dubbele sleutels in het bestand: het hele bestand wordt geweigerd ("duplicate keys in file").
  - Een lijst van 5000 rijen of meer wordt geweigerd.
  - Een mislukte leesactie geeft een ERROR-regel.
  - Verder ongewijzigd: standaard alleen toevoegen, `upsert_` om bij te werken, nooit verwijderen.
- **Controle:** de eerstvolgende import (Claude) is de acceptatietest. Claude meldt de tellingen en de doorlooptijd.

## Procedure — Nieuwe taal (H30)

- **Wanneer:** een nieuwe rapport- of medewerkerstaal is nodig.
- **Stappen:**
  1. Voeg de taal met exact dezelfde spelling (Engelse naam, hoofdletter, geen spaties) toe als keuze in **Workers.Language**, **Employers.Language** en **Translations.Language**.
  2. Voeg in Translations de 23 doc.*-regels toe voor die taal (zelfde Key als Dutch; doc.contractorAll en doc.total mogen leeg, die worden niet gebruikt). Leg ze ook vast in templates/translations-weekreport.csv. Voeg ook de country.*-regels voor die taal toe (templates/translations-countries.csv, H33; ontbrekend = Engelse landnaam in de PDF).
  3. Meld het aan Claude: taalcode toevoegen in de app (Switch in scrWeekReport, ISO 639-1, bv. "fr") en in Test-Languages/Test-Templates. Geen vaste limiet op het aantal talen per export (Eddy 14-11-2026); de app leest per benodigde taal één keer.
  4. Controle: vergelijk online de drie keuzelijsten (de keuzewaarden staan niet in de app-metadata).
