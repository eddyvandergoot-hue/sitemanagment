# Manual steps (MS-xxx)

SharePoint and Power Automate changes that Claude Code cannot make. Done by hand; click-by-click steps and flow code come from the Claude chat. Rules for logging them: **AGENTS.md**. Not read by Claude Code unless a task says so.

| ID | Added | Status |
|---|---|---|
| MS-001 | ≤ 24-10-2026 | Done 25-10-2026 (Eddy) |
| MS-008 | 25-10-2026 | Done (Workers.Trade); Hours.Trade-keuzes: bevestiging Eddy open |

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
- **Hours.Trade (choice):** must contain Fitter / Welder / Unknown. Status: **to confirm** (Eddy). Do not change historical Hours rows.
- **App behaviour:** blank Workers.Trade blocks Save week before any write ("Trade ontbreekt in Workers (aanvullen in SharePoint, daarna Refresh op Project / team)"). If the new-rows Patch fails while a row has Trade Unknown, the app adds "Mogelijk ontbreekt Trade 'Unknown' in de Hours-lijst (MS-008)".
- **Done when:** Hours.Trade choices confirmed as Fitter / Welder / Unknown; report back date + who.
