# Project overview

Short overview for new readers: what the app is, for whom, how big, how it is built, and where it is going. Details: README.md (document map), AGENTS.md (binding rules), ROADMAP.md (order and designs), DECISIONS.md (why).

## What and for whom
- Power Apps canvas app "SiteManagement" for GEA site management (Excel/VBA predecessor): project teams, weekly hours, Hours Summary, Week Report with PDF/CSV export and Outlook drafts, master data (Workers, Contractors, Projects).
- Users: site supervisors / site managers and project leaders of one business unit (BU).
- In production use since v1.0.1 (first real FC week reports KW46, Eddy 18-11-2026).

## Scale (Eddy 20-11-2026, H54)
- About 6 supervisors; typical small projects of about 4 people, at most about 20 people per week.
- SharePoint lists + standard connectors (Power Automate) are sufficient at this scale. Azure or other platforms only later, if real limits are hit (measured, not expected). No Dataverse/SQL (AGENTS.md, Platform).

## How it is built
- Canvas app in SourceCode YAML (git, VS Code, pac pack); data in SharePoint lists; Power Automate flows only for server work (Export file, Import rows, Mail draft, Translate).
- Fail-closed load/save rules, admin screen pattern with components, GEA colours and fonts (AGENTS.md).

## Where it is going (ROADMAP.md, design first, Eddy approves before any build)
1. v1.0.2 release, then the consent build (CONSENT_PLAN.md).
2. Weld sticker register (WELDSTICKERS_PLAN.md), then certificates register (CERTIFICATES_PLAN.md, H49).
3. Archive option A (H50): data stays in the same lists, closed projects/years marked, read-only Archive screen.
4. Configurable app (H51, CONFIGURABLE_PLAN.md to be written): company specifics into AppSettings/Templates/Translations.
5. Multi business unit (H52): each BU its own installation, data fully separated; depends on 4.
6. Installation package + INSTALL.md (H53): a new BU live in one afternoon.
