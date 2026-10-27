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
| MS-020 | 27-10-2026 | Open (Eddy) |
| MS-021 | 27-10-2026 | Postponed to go-live |
| MS-022 | 27-10-2026 | Done 27-10-2026 (reported by Eddy) |

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
- **Done when:** a new employer without a code gets `EMP-` + 3-digit ID, no loop (satisfied 27-10-2026, Eddy).

## MS-013 — Projects cleanup and new columns

- **Added/Done:** 27-10-2026 (Eddy). List Projects: columns Location, Site Supervisor and Client Name deleted; Status (choice: Active / On hold / Closed), Site Managers (Person, multiple) and Country added.
- **App impact:** none; the app (Src) does not reference Projects.Location / Site Supervisor / Client Name (grep 27-10-2026). The Studio metadata in the .msapr (26-10-2026) still lists the old columns; refresh when the admin screens use the new columns.

## MS-014 — Employers: Country

- **Added/Done:** 27-10-2026 (Eddy). Column Country added to Employers. No app impact yet.

## MS-015 — Workers: Language and Worker Code

- **Added/Done:** 27-10-2026 (Eddy). Workers: column Language (choice, default Nederlands) added; Worker Code (internal field_1) is unique, not required, filled by flow MS-017 (extension). No app impact yet.

## MS-016 — TEST-001 status

- **Added/Done:** 27-10-2026 (Eddy). Projects: TEST-001 Status = Closed (see MS-005 addendum).

## MS-005 addendum — TEST-001

- TEST-001 exists (Active = No), test project only (added 27-10-2026, noted by Eddy). Used read-only for the "no periods and no hours" test (TESTPLAN.md TP-PERIOD-01, 6.3). The TEST- prefix rule applies: excluded from Week Report and exports once built (AGENTS.md).

## MS-020 — Refresh data sources for the admin screens

- **Added:** 27-10-2026. **Status:** Open (Eddy).
- **Where:** Power Apps Studio, the app test file. Data sources Employers, Projects, Workers.
- **Reason:** the metadata in the .msapr (26-10-2026) lacks the new columns (Employers Contact Name/Email/Phone; Projects Street, House Number, Postal Code, City, Project Leader, Country) and still has Employer Code required. Admin build plan: ADMIN_PLAN.md (phase 0).
- **Steps:** refresh the three data sources in Studio, then File > Save as > This computer, save the .msapp into `Incoming\` in the project folder.
- **Then (Claude):** merge the metadata, regression build with no screen changes, check Title display-name renames in formulas, report path + SHA-256, wait for Eddy's OK before the Contractors build.

## MS-021 — Site Supervisors permissions on Employers, Projects, Workers

- **Added:** 27-10-2026. **Status:** Postponed to go-live (test phase: Eddy is the only user).
- **Where:** https://geacloud.sharepoint.com/sites/GEASiteManagment, lists Employers, Projects, Workers.
- **Reason:** the admin screens write to these lists. Group "Site Supervisors" (MS-012) gets Edit on the three lists.
- **Note:** when adding members, uncheck "Send an email invitation".

## MS-022 — Projects: Project Number unique

- **Added/Done:** 27-10-2026 (reported by Eddy). Projects.'Project Number' (internal name ProjectName): Enforce unique values = Yes. Backstop for the duplicate block on the Projects screen (ADMIN_PLAN.md).
