# Projectstatus (huidige stand, 26-10-2026)

Geschiedenis en eerdere builds: PROJECT_STATUS_ARCHIVE.md (niet lezen tenzij gevraagd). Volgorde van open punten: NEXT_COMMANDS.md. Open beslissingen: ROADMAP.md. Handmatige stappen: MANUAL_STEPS.md. "Gebouwd" = aantoonbaar in Src; dat zegt niets over Studio-import of functionele test.

Er is nog geen productieapp; er zijn alleen testimports, bewust, tot de functies compleet zijn.

## Goedgekeurde baseline
- Git-tag approved-20261026-discard (annotated, commit 7c7a46a). Approved by Eddy (Studio-test 26-10-2026): Discard changes (TP-DISCARD-01), met 2 open teststappen (zie Open items).
- Build: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\discard-20261026_151949\SiteManagement_Discard_20261026_151949.msapp, 107489 bytes, SHA-256 6E9C5516387084DAA3163CB653B75E3E51C6A57BB05D3B5C92A190CC75610D72 (Src en .msapr van de commit bytegelijk aan deze build).
- Eerdere goedgekeurde: approved-20261026-savefix (commit 01af074; logo-build, SHA-256 8EAE873731E01A50C49A50F02D31153C4ECCA52EDB0A30CE25CA298168FF2085). Eerdere baseline: baseline-footer-row-20261020_215936 (archief).

## Huidige build
- Huidige build = Home-testbuild (pac 2.11.2): C:SERSANDERGOOT.EDDEVSITEMANAGMENTRTIFACTSHOME-20261026_165630SITEMANAGEMENT_HOME_20261026_165630.MSAPP, 110979 BYTES, SHA-256 55F62B4D6397E5BB2C6205145C341CB782CADC6B339965C2EAAC11FF8F80EE4E (21 ENTRIES = DISCARD-BUILD + SRCSCRHOME.PA.YAML; LOGO ONGEWIJZIGD; SRC 6/6 BYTEGELIJK; UNPACK ROUND TRIP OK). STATUS: GEIMPLEMENTEERD EN TECHNISCH GECONTROLEERD (VERIFIER VOLLEDIG, REVIEWER ZONDER BLOKKERENDE PUNTEN); NIET IN STUDIO GEIMPORTEERD, NIET FUNCTIONEEL GETEST, NIET GOEDGEKEURD (TP-HOME-01). DE GOEDGEKEURDE BASELINE BLIJFT APPROVED-20261026-DISCARD. GEDRAG: AGENTS.MD; TESTPLAN: TESTPLAN.MD.
- TP-DD-01, TP-SAVE-01, TP-LOGO-01: geslaagd (Eddy, 26-10-2026, zonder detailrapport). TP-DISCARD-01: stappen 1-5 en 7 geslaagd (Eddy, 26-10-2026; footer past, geen overlap); stap 6 (Monitor) overgeslagen; stap 8 (Failed) open tot TEST-000. De oude Studio-testlijst staat in het archief.
- Bevestigd door Eddy in Studio op 26-10-2026: weeklabel van dpHoursWeek toont voor 01-01-2027 `2026 KW53` (TP-WEEK-01); Hours Summary-restyle (zebra, "–" bij 0, totaalrij, Period total-kolom, scrollbarruimte, GEA-tabelkop) is visueel ok (TP-SUM-01); hergebruik van geladen selecties, scenario 1-7 via Monitor (TP-REUSE-01, op Eddy's melding "alles werkt"; Monitor-regels niet afzonderlijk gemeld); weekkiezer: een andere week laadt automatisch en onopgeslagen invoer blokkeert wisselen (kiezer uitgeschakeld, Refresh grijs, alleen Save actief). Verder niets bevestigd.
- Nog niet functioneel getest in Studio: weekkiezer dpHoursWeek: andere dag in dezelfde week bewaart de dag zonder herlaad; overige GEA-kleuren; fail-closed blokkades (rest); Monitor-delegatie; wijziging van een andere gebruiker verschijnt pas na Refresh (vereist TEST-000).

## Studio-bewijs (26-10-2026, opgeslagen app artifacts\Logo_download\20261026-Sitemanagment_logo.msapp)
- Eddy importeerde de dropdown-build, uploadde het logo en sloeg op: Studio-import geslaagd, alle wijzigingen staan in de opgeslagen Src. Functioneel daarna bevestigd door Eddy (zie Huidige build).
- App checker (Studio, 141 meldingen): 0 delegatiewaarschuwingen, 0 formulefouten. Toegankelijkheid: acc-TabIndexShouldBeDefinedForInteractiveControl 53, acc-FocusBorderShouldBeVisible 38, acc-AccessibleLabelNeeded 16, acc-ReadableScreenNameNeeded 1. Hygiëne: app-CollectingReadOnlyTable 11, app-CrossScreenEventDependencies 9, app-ForAllWithMutation 6, app-UnusedVariables 5 (varSelectionHasWorkers, varPendingLoadedWeekMonday, varHoursProjectID, varHoursProjectKey, varHoursTeam), app-WarnLiteralPredicate 1 (scrWeeklyHours.btnBuildReport.OnSelect), app-UnusedMediaResources 1 (logo vóór gebruik).
- Studio schreef ModernDatePicker@1.0.0 om naar @1.0.2 (dpHoursWeek, dpReportFrom, dpReportUntil); onze Src zegt nog 1.0.0. De .msapr-Templates.json bevat nu modernDatePicker@1.0.2 en image@2.2.3 (40 gewone templates identiek).

## Open items
- Functionele Studio-tests van de hierboven genoemde niet-geteste onderdelen.
- Discard: Monitor-spoor DIAG|Week|Discard niet gecontroleerd (stap 6 overgeslagen); Failed-tak (stap 8) pas testbaar met TEST-000.
- Later, niet blokkerend: App checker-meldingen doorlopen (toegankelijkheid, ongebruikte variabelen, WarnLiteralPredicate).
- Src en Check-WeeklySource uitlijnen op ModernDatePicker@1.0.2 (NEXT_COMMANDS.md 2b).
- Opslagsnelheid Save week / Save team niet expliciet bevestigd (laden is door Eddy getest: snel, geen fouten).
- Jaargrens/week 53 in Hours Summary (periode/rapport over de jaarwisseling) alleen lokaal getest; het Weekly Hours-weeklabel is wel bevestigd in Studio (zie Huidige build); natuurlijk testmoment ISO-week 53 van 2026 (28-12-2026 t/m 03-01-2027). Geen testuren in gedeelde lijsten zetten.
- Open punt: komen medewerkers met periodetotaal 0 in de CSV-export voor?
- SECURITY.md aangemaakt (WAF SE-checklist); open: GitHub 2FA bevestigen, IT-vragen, MS-004/007/011 (gepland), TP-SEC-01.
- Volgende werk (volgorde: NEXT_COMMANDS.md): Studio-test TP-HOME-01 van de Home-build, daarna Assignment periods (besluit 26-10-2026, DECISIONS.md H9; ontwerp, niet gebouwd), Week Report, export, roadmap-merge.
- Uitsluiting van TEST-projecten/TEST Employer in Week Report, Hours Summary-export en health check: gepland bij de Week Report-taak, niet geïmplementeerd (regel in AGENTS.md).
- Export (PDF + CSV, generieke flow): niet gebouwd; spec in AGENTS.md.

## GEA-logo
- Goedgekeurd in Studio (TP-LOGO-01, Eddy 26-10-2026); regel en maten: AGENTS.md; bron Assets/GEA_logo_white.svg (1130 bytes, SHA-256 5D460376D030AF075E004E50191C8BE0C8DB05C5E0A9E593F53612DA52606087, bytegelijk aan het officiële logobankbestand). Technisch gecontroleerd met artifacts/Test-Logo.ps1. Geen MS-item.

## Open MS-items (MANUAL_STEPS.md)
- MS-010 (lijst Assignment Periods + migratie): open, nog niet nodig tot de taak Assignment periods start.
- TEST-000 beschikbaar (MS-005) — open testgevallen met opslaan nu uitvoerbaar: TP-DISCARD-01 stap 8 (Failed), TP-REUSE-01 cross-user.
- Gecontroleerd door Eddy (26-10-2026): Workers.Title (Worker Name) = First Name + Surname voor alle medewerkers (datacontrole, geen SharePoint-constraint).
- SharePoint dwingt nu een verplichte, unieke Employer Code af (MS-009, Eddy 26-10-2026).
- MS-001 (25-10-2026), MS-005 en MS-009 (26-10-2026) en MS-008 (Workers.Trade 25-10, Hours.Trade 26-10-2026) zijn gedaan.
- De aparte controle "geen lege ProjectKey in Project Workers" is niet gemeld en blijft relevant (Save team-risico).

## Bekende beperkingen
Savefix (goedgekeurd):
1. Na aanvullen van Trade/Employer in SharePoint: eerst onopgeslagen invoer terugdraaien, dan Refresh op Project / team, dan opnieuw invoeren.
2. Employer/Trade-validatie blokkeert ook correcties van bestaande Hours-regels (bewust, fail-closed).
3. Screen1: naam kan de rode waarschuwing overlappen bij zeer smalle galleries (scherm < ~604 px).
4. lblWeekLoadStatus (2 regels) kan zeer lange meldingen op smalle schermen afkappen.
5. Rode tekst in galleryrijen voor blokkerende stamgegevenswaarschuwingen (toegestaan in AGENTS.md).
6. Logica en presentatie zitten in één build (op verzoek).
7. Historische Hours-regels kunnen F/W bevatten, nieuwe Fitter/Welder/Unknown: relevant voor groepering in rapport/export.

Discard (goedgekeurd):
8. Na Discard in Failed met mislukte geforceerde herlaad meldt de loader "Vorige invoer behouden" terwijl de invoer is verwijderd; het grid toont colWeekOriginal (deels geverifieerde waarden), de gedetailleerde opslagfout is gewist; opslaan blijft geblokkeerd.
9. Na geslaagde Discard-herlaad in Failed: controleer SharePoint-versies (Modified/Modified By) van de betrokken rijen; de eerdere deelopslag is dan alleen nog in Notify/Trace zichtbaar.
10. Getypte waarde waarvan OnChange nog niet is afgegaan is niet dirty: de eerste klik op de nog uitgeschakelde Discard laat alleen het veld los; daarna wordt de knop actief.
11. Screen1: na mislukte/deels bevestigde Save team is de staat Failed maar blijft varTeamDirty true; checkboxes vereisen Loaded en niet dirty, Refresh en dropdowns zijn geblokkeerd: alleen herstart helpt. Besluit Eddy 26-10-2026: Discard alleen op Weekly Hours; selectiefouten in Loaded worden met een nieuwe Save team gecorrigeerd. Bekende uitzondering: Failed, uitweg = app herstarten (NEXT_COMMANDS.md).

Algemeen:
- Smalle vensters: Hours Summary-tabel heeft onder ~666 px geen weekkolom, footer scrolt horizontaal; zes bekende tekstoverschrijdingen; geen telefoonlayout voor de rapporttabel. Door het logo (lblReportProjectDetails 120 px smaller) knipt de projectregel onder ~810 px (was ~690), titels op Screen1/scrHours knippen onder ~430 px en de Hours Summary-titelbalk past onder ~440 px niet.
- Historische scripts falen ook op HEAD en zijn geen acceptatietests: Test-NavigationLayout, Test-Performance, Test-ReadExisting, Test-PerformanceFix, Test-SummaryFields (vergelijken met oude checkpoints).
- Save week/team zijn geen SharePoint-transactie; gedeeltelijke opslag blijft mogelijk (invoer behouden, opslag geblokkeerd).
- Bekende delegatie-uitzondering: maand-/dagpaginering van Hours Summary binnen ForAll(Sequence(monthCount)).
- Home (niet-blokkerend, reviewer): (a) btnWeeklyProjectTeam (scrHours), btnSummaryProjectTeam (Summary) en btnGotoHoursSummary (Screen1) hebben hun guard alleen in DisplayMode, niet als eerste OnSelect-voorwaarde (bestaand; later logicataak); (b) Studio: uren typen en direct op Home klikken (OnChange-on-blur versus OnSelect), de OnSelect-guard beperkt het risico; (c) de Weekly Hours-tegel leest ddProject/ddTeam van Screen1 (app-CrossScreenEventDependencies); (d) Notify op Home is Engels, de meeste meldingen Nederlands; (e) "Component library" past krap (173/176 px bij tegel 200 px); (f) geen schermovergang op Home-navigatie (cosmetisch). Placeholder-tegels zijn bewust zonder logica.
- Logo: 13 px vrije ruimte boven/onder in de balk van 56 px (de regel ≥15 px geldt horizontaal).
- ModernDatePicker: Src 1.0.0 versus Studio 1.0.2 (zie Studio-bewijs).
- artifacts\Logo_download\20261026-Sitemanagment_logo.msapp bevat een read-only SAS-token, geldig tot 27-10-2026 10:57 UTC; lokaal en gitignored; Eddy mag het verwijderen.
