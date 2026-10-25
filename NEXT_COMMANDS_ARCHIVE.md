Archief van NEXT_COMMANDS.md (afgeronde items, verplaatst 25-10-2026).
Niet lezen tenzij de opdracht erom vraagt.

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
