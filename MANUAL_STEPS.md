# Manual steps (MS-xxx)

SharePoint and Power Automate changes that Claude Code cannot make. Done by hand; click-by-click steps and flow code come from the Claude chat. Rules for logging them: **AGENTS.md**. Not read by Claude Code unless a task says so.

| ID | Added | Status |
|---|---|---|
| MS-001 | ≤ 24-10-2026 | Done 25-10-2026 (Eddy) |
| MS-008 | 25-10-2026 | Done (Workers.Trade 25-10-2026, Hours.Trade 26-10-2026, Eddy) |
| MS-005 | 26-10-2026 | Done 26-10-2026 (Eddy) |
| MS-009 | 26-10-2026 | Done 26-10-2026 (Eddy) |
| MS-010 | 26-10-2026 | List done 26-10-2026 (Eddy); open: display-name decision |

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

## MS-010 — Assignment Periods list

- **Added:** 26-10-2026. **Status:** List created 26-10-2026 (Eddy); open: display-name decision (see Note). Migration replaced (see Migration).
- **Where:** the existing site https://geacloud.sharepoint.com/sites/GEASiteManagment (new list).
- **Reason:** several periods per worker per project (decision DECISIONS.md H9). Project Workers stays one record per project+worker.
- **List:** "Assignment Periods" with columns:

  | Column | Type | Note |
  |---|---|---|
  | AssignmentKey | Single line of text | indexed; same format as Project Workers.AssignmentKey (project-ID\|worker-ID) |
  | ProjectKey | Single line of text | indexed |
  | From | Date | always a Monday |
  | Until | Date | always a Sunday; blank = open |

- **Indexes:** AssignmentKey and ProjectKey. Check online first whether they exist; local metadata does not show this.
- **Migration:** NOT a manual SharePoint step anymore; replaced by an explicit per-project migration action in the app (being built). Original idea (superseded): each existing active assignment gets one period: From = Monday of its earliest Hours record, Until blank.
- **Created as (26-10-2026, verified by the orchestrator from the Studio metadata):** Title has display name "AssignmentKey" (internal name Title; required; indexed; NOT unique, since several periods per assignment); ProjectKey (text, required, indexed); From (date only, required; internal name From); Until (date only, optional).
- **Note (open decision, Eddy):** the internal name of Until is "Till" and its display name is currently "Untill" (typo, double l). Eddy still decides whether to rename the display name to "Until". The app uses the internal name. Data source "Assignment Periods" was added to the app in Studio by Eddy (Studio file in Incoming/, not committed).
- **Done when:** list, columns, indexes and migration are in place and Eddy confirms; report back date + who. Test on TEST-000 (MS-005).

## MS-012 — Worker Contacts list (phone out of Workers)

- **Added:** 26-10-2026. **Status:** Open. Not needed until the Workers admin task starts; removing/migrating Workers.Phone may be done earlier at Eddy's discretion.
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
- **Decision point (Eddy, open):** the Workers schema also has an Email column. Check whether Workers.Email contains data; if unused, clear and remove it like Phone. Email is not moved to Worker Contacts.
- **Version history:** Workers version history still contains the phone numbers. Decide (Eddy) whether to clean old versions.
- **Done when:** list, columns, unique permissions and group "Site Supervisors" are in place, numbers are migrated and Workers.Phone is removed (and the Workers.Email decision is made); Eddy confirms; report back date + who. Also check in Studio Monitor whether Workers rows (incl. Phone/Email columns) are transferred to the client (SECURITY.md open points).
