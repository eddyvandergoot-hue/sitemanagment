# Projectstatus (huidige stand, 26-10-2026)

Geschiedenis en eerdere builds: PROJECT_STATUS_ARCHIVE.md (niet lezen tenzij gevraagd). Volgorde van open punten: NEXT_COMMANDS.md. Open beslissingen: ROADMAP.md. Handmatige stappen: MANUAL_STEPS.md. "Gebouwd" = aantoonbaar in Src; dat zegt niets over Studio-import of functionele test.

Er is nog geen productieapp; er zijn alleen testimports, bewust, tot de functies compleet zijn.

## Goedgekeurde baseline
- Git-tag approved-20261026-savefix (annotated, commit 01af074). Approved by Eddy (Studio-test 26-10-2026): savefix, dropdownhover, logo; MS-008 bevestigd.
- Build: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\logo-20261026_120726\SiteManagement_Logo_20261026_120726.msapp, 107224 bytes, SHA-256 8EAE873731E01A50C49A50F02D31153C4ECCA52EDB0A30CE25CA298168FF2085 (savefix + dropdownstatuskleuren + GEA-logo; Src en .msapr van de commit bytegelijk aan deze build).
- Eerdere baseline: baseline-footer-row-20261020_215936 (details in het archief).

## Huidige build
- Er is geen openstaande testbuild; de goedgekeurde build hierboven is de laatste build.
- Testcases TP-DD-01, TP-SAVE-01, TP-LOGO-01: geslaagd (Eddy, 26-10-2026, zonder detailrapport; zie TESTPLAN.md). De oude Studio-testlijst staat in het archief.
- Bevestigd door Eddy in Studio op 26-10-2026: weeklabel van dpHoursWeek toont voor 01-01-2027 `2026 KW53` (TP-WEEK-01); Hours Summary-restyle (zebra, "–" bij 0, totaalrij, Period total-kolom, scrollbarruimte, GEA-tabelkop) is visueel ok (TP-SUM-01); hergebruik van geladen selecties, scenario 1-7 via Monitor (TP-REUSE-01, op Eddy's melding "alles werkt"; Monitor-regels niet afzonderlijk gemeld); weekkiezer: een andere week laadt automatisch en onopgeslagen invoer blokkeert wisselen (kiezer uitgeschakeld, Refresh grijs, alleen Save actief). Verder niets bevestigd.
- Nog niet functioneel getest in Studio: weekkiezer dpHoursWeek: andere dag in dezelfde week bewaart de dag zonder herlaad; overige GEA-kleuren; fail-closed blokkades (rest); Monitor-delegatie; wijziging van een andere gebruiker verschijnt pas na Refresh (vereist TEST-000).

## Studio-bewijs (26-10-2026, opgeslagen app artifacts\Logo_download\20261026-Sitemanagment_logo.msapp)
- Eddy importeerde de dropdown-build, uploadde het logo en sloeg op: Studio-import geslaagd, alle wijzigingen staan in de opgeslagen Src. Functioneel daarna bevestigd door Eddy (zie Huidige build).
- App checker (Studio, 141 meldingen): 0 delegatiewaarschuwingen, 0 formulefouten. Toegankelijkheid: acc-TabIndexShouldBeDefinedForInteractiveControl 53, acc-FocusBorderShouldBeVisible 38, acc-AccessibleLabelNeeded 16, acc-ReadableScreenNameNeeded 1. Hygiëne: app-CollectingReadOnlyTable 11, app-CrossScreenEventDependencies 9, app-ForAllWithMutation 6, app-UnusedVariables 5 (varSelectionHasWorkers, varPendingLoadedWeekMonday, varHoursProjectID, varHoursProjectKey, varHoursTeam), app-WarnLiteralPredicate 1 (scrWeeklyHours.btnBuildReport.OnSelect), app-UnusedMediaResources 1 (logo vóór gebruik).
- Studio schreef ModernDatePicker@1.0.0 om naar @1.0.2 (dpHoursWeek, dpReportFrom, dpReportUntil); onze Src zegt nog 1.0.0. De .msapr-Templates.json bevat nu modernDatePicker@1.0.2 en image@2.2.3 (40 gewone templates identiek).

## Open items
- Functionele Studio-tests van de hierboven genoemde niet-geteste onderdelen.
- Later, niet blokkerend: App checker-meldingen doorlopen (toegankelijkheid, ongebruikte variabelen, WarnLiteralPredicate).
- Src en Check-WeeklySource uitlijnen op ModernDatePicker@1.0.2 (NEXT_COMMANDS.md 2b).
- Opslagsnelheid Save week / Save team niet expliciet bevestigd (laden is door Eddy getest: snel, geen fouten).
- Jaargrens/week 53 in Hours Summary (periode/rapport over de jaarwisseling) alleen lokaal getest; het Weekly Hours-weeklabel is wel bevestigd in Studio (zie Huidige build); natuurlijk testmoment ISO-week 53 van 2026 (28-12-2026 t/m 03-01-2027). Geen testuren in gedeelde lijsten zetten.
- Open punt: komen medewerkers met periodetotaal 0 in de CSV-export voor?
- Volgende werk (volgorde: NEXT_COMMANDS.md): TEST-000 setup, Discard changes-knop, startscherm + Week Report, export, roadmap-merge.
- Export (PDF + CSV, generieke flow): niet gebouwd; spec in AGENTS.md.

## GEA-logo
- Goedgekeurd in Studio (TP-LOGO-01, Eddy 26-10-2026); regel en maten: AGENTS.md; bron Assets/GEA_logo_white.svg (1130 bytes, SHA-256 5D460376D030AF075E004E50191C8BE0C8DB05C5E0A9E593F53612DA52606087, bytegelijk aan het officiële logobankbestand). Technisch gecontroleerd met artifacts/Test-Logo.ps1. Geen MS-item.

## Open MS-items (MANUAL_STEPS.md)
- Geen open MS-items: MS-001 (25-10-2026) en MS-008 (Workers.Trade 25-10, Hours.Trade 26-10-2026) zijn gedaan.
- De aparte controle "geen lege ProjectKey in Project Workers" is niet gemeld en blijft relevant (Save team-risico).

## Bekende beperkingen
Savefix-build (goedgekeurd):
1. Na aanvullen van Trade/Employer in SharePoint: eerst onopgeslagen invoer terugdraaien, dan Refresh op Project / team, dan opnieuw invoeren.
2. Employer/Trade-validatie blokkeert ook correcties van bestaande Hours-regels (bewust, fail-closed).
3. Screen1: naam kan de rode waarschuwing overlappen bij zeer smalle galleries (scherm < ~604 px).
4. lblWeekLoadStatus (2 regels) kan zeer lange meldingen op smalle schermen afkappen.
5. Rode tekst in galleryrijen voor blokkerende stamgegevenswaarschuwingen (toegestaan in AGENTS.md).
6. Logica en presentatie zitten in één build (op verzoek).
7. Historische Hours-regels kunnen F/W bevatten, nieuwe Fitter/Welder/Unknown: relevant voor groepering in rapport/export.

Algemeen:
- Smalle vensters: Hours Summary-tabel heeft onder ~666 px geen weekkolom, footer scrolt horizontaal; zes bekende tekstoverschrijdingen; geen telefoonlayout voor de rapporttabel. Door het logo (lblReportProjectDetails 120 px smaller) knipt de projectregel onder ~810 px (was ~690), titels op Screen1/scrHours knippen onder ~430 px en de Hours Summary-titelbalk past onder ~440 px niet.
- Historische scripts falen ook op HEAD en zijn geen acceptatietests: Test-NavigationLayout, Test-Performance, Test-ReadExisting, Test-PerformanceFix, Test-SummaryFields (vergelijken met oude checkpoints).
- Save week/team zijn geen SharePoint-transactie; gedeeltelijke opslag blijft mogelijk (invoer behouden, opslag geblokkeerd).
- Bekende delegatie-uitzondering: maand-/dagpaginering van Hours Summary binnen ForAll(Sequence(monthCount)).
- Logo: 13 px vrije ruimte boven/onder in de balk van 56 px (de regel ≥15 px geldt horizontaal).
- ModernDatePicker: Src 1.0.0 versus Studio 1.0.2 (zie Studio-bewijs).
- artifacts\Logo_download\20261026-Sitemanagment_logo.msapp bevat een read-only SAS-token, geldig tot 27-10-2026 10:57 UTC; lokaal en gitignored; Eddy mag het verwijderen.
