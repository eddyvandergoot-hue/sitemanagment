# Projectstatus (huidige stand, 25-10-2026)

Geschiedenis en eerdere builds: PROJECT_STATUS_ARCHIVE.md (niet lezen tenzij gevraagd). Volgorde van open punten: NEXT_COMMANDS.md. Open beslissingen: ROADMAP.md. Handmatige stappen: MANUAL_STEPS.md. "Gebouwd" = aantoonbaar in Src; dat zegt niets over Studio-import of functionele test.

Er is nog geen productieapp; er zijn alleen testimports, bewust, tot de functies compleet zijn.

## Goedgekeurde baseline
- Git-tag baseline-footer-row-20261020_215936 (door Eddy getest en aangewezen, 20-10-2026).
- Build: artifacts\footer-row-20261020_215936\SiteManagement_OneFooterRow_20261020_215936.msapp, SHA-256 1EB3788816043A0F1799539F51958ED38221A904F6791158FB64F0F1912C8F15 (vastgelegd in het archief).
- Latere builds (o.a. gecombineerde build met weekkiezer, tabelrestyle en GEA-kleuren, 22-10) zijn niet afzonderlijk goedgekeurd; hun inhoud zit in de huidige Src en dus in de testbuild hieronder.

## Huidige testbuild (niet goedgekeurd, wacht op Eddy's Studio-test)
- Pad: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\savefix-trade-20261025_163517\SiteManagement_SaveFixTrade_20261025_163517.msapp
- 101640 bytes, SHA-256 1891281F7F62DF1F739BA282D11B8218DEDBECF74066027731394BF8CF4033C7 (pac 2.11.2; Src 5/5 bytegelijk aan de bron).
- Inhoud: Save week-fix (lokale pre-save validatie, echte foutmelding bij nul writes, lblWeekLoadStatus) + Trade Unknown (Fitter/Welder/Unknown, Trade-chip en waarschuwingen op Screen1/scrHours).
- Status: **geïmplementeerd en technisch gecontroleerd** (reviewer tweemaal zonder blokkerende bevindingen; verifier volledige set 0 FAIL, Check-WeeklySource OK). **Niet in Studio geïmporteerd, niet functioneel getest, niet goedgekeurd.**
- Studio-testlijst (Eddy):
  1. Import + App checker op btnSaveWeek, btnReadWeek, lblWeekLoadStatus, lblItemWarning, lblWorkerWarning.
  2. Lege Trade + nieuwe cel: echte melding, week blijft Loaded, Trace `DIAG|SaveWeek|End` Writes=0.
  3. Trade Unknown + nieuwe cel en expliciete 0: opgeslagen met Trade Unknown (faalt als Hours.Trade geen Unknown heeft: MS-008).
  4. Uren 24,01 / 7,255: melding per cel.
  5. Gewone Save met een bestaande + een nieuwe cel.
  6. Chip/waarschuwing niet afgekapt op Screen1 en Weekly Hours; leeg versus 0 in urenvelden.
  7. Alleen na Eddy's bevestiging: tag `approved-<datum>-savefix` en "approved by Eddy" hier; tag pushen.
- Ook nog niet in Studio getest (zitten in deze build): weekkiezer dpHoursWeek (OnChange-gedrag, `2026 KW53` voor 01-01-2027, onopgeslagen invoer blokkeert wisselen); Hours Summary-restyle (zebra, "–" voor 0, totaalrij, scrollbarruimte); GEA-kleuren; hergebruik van geladen selecties; fail-closed blokkades; Monitor-delegatie; App checker-meldingen.

## Open items
- Studio-import en functionele test van de huidige build (hierboven).
- Opslagsnelheid Save week / Save team niet expliciet bevestigd (laden is door Eddy getest: snel, geen fouten).
- Jaargrens/week 53 in Hours Summary alleen lokaal getest; natuurlijk testmoment ISO-week 53 van 2026 (28-12-2026 t/m 03-01-2027). Geen testuren in gedeelde lijsten zetten.
- Open punt: komen medewerkers met periodetotaal 0 in de CSV-export voor?
- Volgende werk (volgorde: NEXT_COMMANDS.md): TEST-000 setup, Discard changes-knop, startscherm + Week Report, export, roadmap-merge.
- Export (PDF + CSV, generieke flow): niet gebouwd; spec in AGENTS.md.

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

Algemeen:
- Smalle vensters: Hours Summary-tabel heeft onder ~666 px geen weekkolom, projectregel in titelbalk kan onder ~690 px afkappen, footer scrolt horizontaal; zes bekende tekstoverschrijdingen bij smalle vensters; geen telefoonlayout voor de rapporttabel.
- Historische scripts falen ook op HEAD en zijn geen acceptatietests: Test-NavigationLayout, Test-Performance, Test-ReadExisting, Test-PerformanceFix, Test-SummaryFields (vergelijken met oude checkpoints).
- Save week/team zijn geen SharePoint-transactie; gedeeltelijke opslag blijft mogelijk (invoer behouden, opslag geblokkeerd).
- Bekende delegatie-uitzondering: maand-/dagpaginering van Hours Summary binnen ForAll(Sequence(monthCount)).
