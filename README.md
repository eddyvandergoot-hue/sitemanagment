# Site Management

Power Apps canvas app on SharePoint Lists for GEA site management: project/team assignment, weekly hours, reports and exports. Part of a set of standalone modules (see ROADMAP.md).

## Where things are

| Topic | File | Read by Claude Code every task |
|---|---|---|
| Projects, locations, folder layout, screens, file map | **README.md** (this file) | No |
| Rules: data, keys, load/save safety, delegation, way of working, GEA colors/fonts, week labels, export spec | **AGENTS.md** | Yes |
| Current status, current baseline build, open items | **PROJECT_STATUS.md** | Yes |
| Plan, phases, open decisions | **ROADMAP.md** | Only when the task says so |
| Manual SharePoint / Power Automate steps (MS-xxx) | **MANUAL_STEPS.md** | Only when the task says so |
| Decision log: what was decided and why | **DECISIONS.md** | Only when the task says so |
| Manual Studio/browser test cases (TP-xxx) | **TESTPLAN.md** | Only when the task says so |
| Security: WAF SE-checklist, threats, incident plan | **SECURITY.md** | Alleen lezen als de opdracht erom vraagt |
| Commands still to run | **NEXT_COMMANDS.md** | No (queue for Eddy) |
| Subagents (who does which kind of task) | **.claude/agents/*.md** | Descriptions always; full text only when the agent runs |
| History (do not read unless asked) | **PROJECT_STATUS_ARCHIVE.md**, **AGENTS_ARCHIVE.md**, **NEXT_COMMANDS_ARCHIVE.md** | No, niet lezen tenzij gevraagd |

One topic, one file. Other files link here instead of repeating content.

## Projects and locations

| Project | Stack | Location | Repo |
|---|---|---|---|
| **Site Management** | Power Apps canvas + SharePoint Lists + Power Automate | `C:\Users\vandergoot.ed\Dev\Sitemanagment` | Private GitHub `eddyvandergoot-hue/sitemanagment` |
| **pidtracker** | React/Vite + FastAPI/SQLite (+ React Three Fiber for 3D) | Linux ZBook + Windows | `eddyvandergoot-hue/PID-Tracker` |

Old OneDrive folder `OneDrive - GEA\Projects\Development\Sitemanagment\SiteManagement_20261019_232919` = read-only backup. Never write there.

SharePoint site: `https://geacloud.sharepoint.com/sites/GEASiteManagment`  Lists: Projects, Employers, Workers, Project Workers, Hours.

## Folder layout

```
Sitemanagment/
├─ Src/                      Power Apps source (*.pa.yaml)
├─ Site Managment_VS.msapr   Original package metadata (connections, templates)
├─ artifacts/
│  ├─ *.ps1                  Test scripts
│  └─ <build-name>/          Packed test builds (*.msapp) — git-ignored
├─ .claude/agents/          Subagents: powerfx-logic, powerfx-ui, verifier, reviewer, docs-keeper
├─ README.md  AGENTS.md  PROJECT_STATUS.md  ROADMAP.md  MANUAL_STEPS.md  DECISIONS.md  NEXT_COMMANDS.md  TESTPLAN.md  SECURITY.md  *_ARCHIVE.md
└─ Assets/ (GEA logo, only GEA_logo_white.svg tracked)  .gitignore
```

## Screens

| Internal name | Visible title | Purpose |
|---|---|---|
| `scrHome` | Site Management | Startscherm: tegels naar de schermen (placeholders "Coming soon") |
| `Screen1` | Project / team | Choose project + team, link workers, Save team |
| `scrHours` | Weekly Hours | Enter hours Mon–Sun per team |
| `scrWeekReport` *(planned)* | Week Report | Daily hours per worker for one week; export PDF + CSV |
| `scrWeeklyHours` | Hours Summary | Period overview; CSV export |

Internal names stay unchanged so references do not break.

## Who does what

| What | Where |
|---|---|
| App source, tests, pack, git | Claude Code in VS Code, started in the project folder |
| SharePoint lists/columns/indexes, Power Automate flows, Office Scripts, design | Claude chat (via MS-xxx items) |
| Import and test builds | Eddy, make.powerapps.com → Apps → Import app → From file |

## Subagents

Claude Code (main session: Opus 5.5) picks a subagent by matching the task to each agent's `description`, or you name it in the command ("use powerfx-logic for part 1"). Each runs in its own context, so test logs and file dumps stay out of the main conversation.

| Agent | Model / effort | Does | Never |
|---|---|---|---|
| `powerfx-logic` | Opus / high | Loaders, Save, guards, filters, delegation, keys, calculations, export content | Change colors/layout |
| `powerfx-ui` | Sonnet / medium | Colors, fonts, positions, labels, tables, footers, tiles | Touch OnSelect/OnChange/Items logic/Patch |
| `verifier` | Sonnet / medium | Quick tests per change; full suite + pac pack + SHA at task end | Edit files |
| `reviewer` | Opus / high | Independent read-only review against AGENTS.md before packing logic changes | Edit files |
| `docs-keeper` | Sonnet / medium | AGENTS, PROJECT_STATUS, ROADMAP, MANUAL_STEPS, DECISIONS, README, NEXT_COMMANDS | Duplicate content or write rules for unbuilt changes |

Typical task flow: main session plans → `powerfx-logic` and/or `powerfx-ui` change Src → `verifier` quick tests → `reviewer` (logic changes only) → `verifier` full tier + pack → `docs-keeper` status + MS items → git commit.
