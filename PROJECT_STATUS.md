# Projectstatus (huidige stand, 26-10-2026)

Geschiedenis en eerdere builds: PROJECT_STATUS_ARCHIVE.md (niet lezen tenzij gevraagd). Volgorde van open punten: NEXT_COMMANDS.md. Open beslissingen: ROADMAP.md. Handmatige stappen: MANUAL_STEPS.md. "Gebouwd" = aantoonbaar in Src; dat zegt niets over Studio-import of functionele test.

Er is nog geen productieapp; er zijn alleen testimports, bewust, tot de functies compleet zijn.

## Goedgekeurde baseline
- Git-tag baseline-footer-row-20261020_215936 (door Eddy getest en aangewezen, 20-10-2026).
- Build: artifacts\footer-row-20261020_215936\SiteManagement_OneFooterRow_20261020_215936.msapp, SHA-256 1EB3788816043A0F1799539F51958ED38221A904F6791158FB64F0F1912C8F15 (vastgelegd in het archief).
- Latere builds (o.a. gecombineerde build met weekkiezer, tabelrestyle en GEA-kleuren, 22-10) zijn niet afzonderlijk goedgekeurd; hun inhoud zit in de huidige Src en dus in de testbuild hieronder.

## Huidige testbuild (niet goedgekeurd, wacht op Eddy's Studio-test)
- Pad: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\logo-20261026_120726\SiteManagement_Logo_20261026_120726.msapp
- 107224 bytes, SHA-256 8EAE873731E01A50C49A50F02D31153C4ECCA52EDB0A30CE25CA298168FF2085 (pac 2.11.2; Src 5/5 bytegelijk aan de bron; 20 entries = vorige 19 + Assets\Images\eb30143f-1bd0-4f86-b62e-527e69d881dc.svg; uitpak-rondrit OK; geen ondertekende URL).
- Inhoud: savefix + dropdownstatuskleuren + GEA-logo (Image@2.2.3: imgLogoScreen1, imgLogoHours, imgLogoSummary; regel: AGENTS.md).
- Status: **geïmplementeerd en technisch gecontroleerd** (verifier volledige set geslaagd; 5 historische scripts falen identiek op HEAD; reviewer: geen blokkerende bevindingen). **Niet in Studio geïmporteerd, niet functioneel getest, niet goedgekeurd.**
- Vorige build (dropdownstaten, Studio-geïmporteerd): artifacts\dropdown-states-20261026_051056\SiteManagement_DropdownStates_20261026_051056.msapp, SHA-256 75819FA0832453672AE8D3D8A9D4479394D0695CBA28956524F62D092B5470A8.
- Eerdere build (savefix): artifacts\savefix-trade-20261025_163517\SiteManagement_SaveFixTrade_20261025_163517.msapp, SHA-256 1891281F7F62DF1F739BA282D11B8218DEDBECF74066027731394BF8CF4033C7. De savefix zit in de huidige build; de savefix-test staat open.
- Savefix-inhoud: Save week-fix (lokale pre-save validatie, echte foutmelding bij nul writes, lblWeekLoadStatus) + Trade Unknown (Fitter/Welder/Unknown, Trade-chip en waarschuwingen op Screen1/scrHours).
- Testcases: TESTPLAN.md (TP-DD-01, TP-SAVE-01, TP-LOGO-01).
- Studio-testlijst (Eddy):
  0. Dropdowns (Team, Project, Contractor): rij onder de muis lichtblauw, gekozen item blauw/wit, ingedrukt lichtblauw (TP-DD-01).
  1. Logo: wit, scherp, niet uitgerekt op alle drie schermen; titels niet afgekapt; projectregel op Hours Summary leesbaar bij uw gebruikelijke venstergrootte (TP-LOGO-01).
  2. Lege Trade + nieuwe cel: echte melding, week blijft Loaded, Trace `DIAG|SaveWeek|End` Writes=0.
  3. Trade Unknown + nieuwe cel en expliciete 0: opgeslagen met Trade Unknown (faalt als Hours.Trade geen Unknown heeft: MS-008).
  4. Uren 24,01 / 7,255: melding per cel.
  5. Gewone Save met een bestaande + een nieuwe cel.
  6. Chip/waarschuwing niet afgekapt op Screen1 en Weekly Hours; leeg versus 0 in urenvelden.
  7. Alleen na Eddy's bevestiging: tag `approved-<datum>-savefix` en "approved by Eddy" hier; tag pushen.
- Ook nog niet functioneel getest: weekkiezer dpHoursWeek (OnChange, `2026 KW53` voor 01-01-2027, onopgeslagen invoer blokkeert wisselen); Hours Summary-restyle; GEA-kleuren; hergebruik van geladen selecties; fail-closed blokkades; Monitor-delegatie.

## Studio-bewijs (26-10-2026, opgeslagen app artifacts\Logo_download\20261026-Sitemanagment_logo.msapp)
- Eddy importeerde de dropdown-build, uploadde het logo en sloeg op: Studio-import geslaagd, alle wijzigingen staan in de opgeslagen Src. Alleen importbewijs; hover/Save niet functioneel gemeld.
- App checker (Studio, 141 meldingen): 0 delegatiewaarschuwingen, 0 formulefouten. Toegankelijkheid: acc-TabIndexShouldBeDefinedForInteractiveControl 53, acc-FocusBorderShouldBeVisible 38, acc-AccessibleLabelNeeded 16, acc-ReadableScreenNameNeeded 1. Hygiëne: app-CollectingReadOnlyTable 11, app-CrossScreenEventDependencies 9, app-ForAllWithMutation 6, app-UnusedVariables 5 (varSelectionHasWorkers, varPendingLoadedWeekMonday, varHoursProjectID, varHoursProjectKey, varHoursTeam), app-WarnLiteralPredicate 1 (scrWeeklyHours.btnBuildReport.OnSelect), app-UnusedMediaResources 1 (logo vóór gebruik).
- Studio schreef ModernDatePicker@1.0.0 om naar @1.0.2 (dpHoursWeek, dpReportFrom, dpReportUntil); onze Src zegt nog 1.0.0. De .msapr-Templates.json bevat nu modernDatePicker@1.0.2 en image@2.2.3 (40 gewone templates identiek).

## Open items
- Studio-import en functionele test van de huidige build (hierboven).
- Later, niet blokkerend: App checker-meldingen doorlopen (toegankelijkheid, ongebruikte variabelen, WarnLiteralPredicate).
- Src en Check-WeeklySource uitlijnen op ModernDatePicker@1.0.2 (NEXT_COMMANDS.md 2b).
- Opslagsnelheid Save week / Save team niet expliciet bevestigd (laden is door Eddy getest: snel, geen fouten).
- Jaargrens/week 53 in Hours Summary alleen lokaal getest; natuurlijk testmoment ISO-week 53 van 2026 (28-12-2026 t/m 03-01-2027). Geen testuren in gedeelde lijsten zetten.
- Open punt: komen medewerkers met periodetotaal 0 in de CSV-export voor?
- Volgende werk (volgorde: NEXT_COMMANDS.md): TEST-000 setup, Discard changes-knop, startscherm + Week Report, export, roadmap-merge.
- Export (PDF + CSV, generieke flow): niet gebouwd; spec in AGENTS.md.

## GEA-logo
- Geïmplementeerd in de huidige build (regel en maten: AGENTS.md); bron Assets/GEA_logo_white.svg (1130 bytes, SHA-256 5D460376D030AF075E004E50191C8BE0C8DB05C5E0A9E593F53612DA52606087, bytegelijk aan het officiële logobankbestand). Alleen technisch gecontroleerd (artifacts/Test-Logo.ps1); rendering in Studio/browser open (TP-LOGO-01). Geen MS-item.

## Open MS-items (MANUAL_STEPS.md)
- MS-008 Trade-keuzes: Workers.Trade klaar (Eddy, 25-10-2026); Hours.Trade-keuzes Fitter/Welder/Unknown: bevestiging Eddy open.
- MS-001 (indexen) is gedaan op 25-10-2026; de aparte controle "geen lege ProjectKey in Project Workers" is niet gemeld en blijft relevant (Save team-risico).

## Bekende beperkingen
Savefix-build:
1. Na aanvullen van Trade/Employer in SharePoint: eerst onopgeslagen invoer terugdraaien, dan Refresh op Project / team, dan opnieuw invoeren.
2. Employer/Trade-validatie blokkeert ook correcties van bestaande Hours-regels (bewust, fail-closed).
3. Screen1: naam kan de rode waarschuwing overlappen bij zeer smalle galleries (scherm < ~604 px).
4. lblWeekLoadStatus (2 regels) kan zeer lange meldingen op smalle schermen afkappen.
5. Rode tekst in galleryrijen voor blokkerende stamgegevenswaarschuwingen (toegestaan in AGENTS.md).
6. Logica en presentatie zitten in één build (op verzoek).
7. Historische Hours-regels kunnen F/W bevatten, nieuwe Fitter/Welder/Unknown: relevant voor groepering in rapport/export.

Dropdownbuild:
8. Het kleuren van de lijstrijen (hover/geselecteerd) gebeurt door de runtime-JS van het control (dropdownStyles); niet aantoonbaar uit template of pack. Toont hover in de browser niet, dan is het alternatief een modern Dropdown/ComboBox (ander controltype; eerst documentatie en importcontrole).

Algemeen:
- Smalle vensters: Hours Summary-tabel heeft onder ~666 px geen weekkolom, footer scrolt horizontaal; zes bekende tekstoverschrijdingen; geen telefoonlayout voor de rapporttabel. Door het logo (lblReportProjectDetails 120 px smaller) knipt de projectregel onder ~810 px (was ~690), titels op Screen1/scrHours knippen onder ~430 px en de Hours Summary-titelbalk past onder ~440 px niet.
- Historische scripts falen ook op HEAD en zijn geen acceptatietests: Test-NavigationLayout, Test-Performance, Test-ReadExisting, Test-PerformanceFix, Test-SummaryFields (vergelijken met oude checkpoints).
- Save week/team zijn geen SharePoint-transactie; gedeeltelijke opslag blijft mogelijk (invoer behouden, opslag geblokkeerd).
- Bekende delegatie-uitzondering: maand-/dagpaginering van Hours Summary binnen ForAll(Sequence(monthCount)).
- Logo: 13 px vrije ruimte boven/onder in de balk van 56 px (de regel ≥15 px geldt horizontaal).
- ModernDatePicker: Src 1.0.0 versus Studio 1.0.2 (zie Studio-bewijs).
- artifacts\Logo_download\20261026-Sitemanagment_logo.msapp bevat een read-only SAS-token, geldig tot 27-10-2026 10:57 UTC; lokaal en gitignored; Eddy mag het verwijderen.
