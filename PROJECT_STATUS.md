# Projectstatus (huidige stand, 26-10-2026)

Geschiedenis en eerdere builds: PROJECT_STATUS_ARCHIVE.md (niet lezen tenzij gevraagd). Volgorde van open punten: NEXT_COMMANDS.md. Open beslissingen: ROADMAP.md. Handmatige stappen: MANUAL_STEPS.md. "Gebouwd" = aantoonbaar in Src; dat zegt niets over Studio-import of functionele test.

Er is nog geen productieapp; er zijn alleen testimports, bewust, tot de functies compleet zijn.

## Goedgekeurde baseline
- Git-tag baseline-footer-row-20261020_215936 (door Eddy getest en aangewezen, 20-10-2026).
- Build: artifacts\footer-row-20261020_215936\SiteManagement_OneFooterRow_20261020_215936.msapp, SHA-256 1EB3788816043A0F1799539F51958ED38221A904F6791158FB64F0F1912C8F15 (vastgelegd in het archief).
- Latere builds (o.a. gecombineerde build met weekkiezer, tabelrestyle en GEA-kleuren, 22-10) zijn niet afzonderlijk goedgekeurd; hun inhoud zit in de huidige Src en dus in de testbuild hieronder.

## Huidige testbuild (niet goedgekeurd, wacht op Eddy's Studio-test)
- Pad: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\dropdown-states-20261026_051056\SiteManagement_DropdownStates_20261026_051056.msapp
- 101644 bytes, SHA-256 75819FA0832453672AE8D3D8A9D4479394D0695CBA28956524F62D092B5470A8 (pac 2.11.2; Src 5/5 bytegelijk aan de bron; 19 entries, geen Assets-entries).
- Inhoud: de savefix-inhoud (hieronder) plus dropdownstatuskleuren op alle 4 Classic/DropDown@2.3.1 (ddProject, ddTeam, ddReportProject, ddReportContractor; waarden: AGENTS.md). Oorzaak: HoverFill was gelijk aan Fill (#F0F0F0), dus geen zichtbaar verschil.
- Status: **geïmplementeerd en technisch gecontroleerd** (verifier snelle tier geslaagd, 0 FAIL; reviewer: geen blokkerende bevindingen; Test-GeaColors controleert nu ook dat er precies deze 4 dropdowns zijn). **Niet in Studio geïmporteerd, niet functioneel getest, niet goedgekeurd.**
- Vorige build (savefix, niet getest): artifacts\savefix-trade-20261025_163517\SiteManagement_SaveFixTrade_20261025_163517.msapp, 101640 bytes, SHA-256 1891281F7F62DF1F739BA282D11B8218DEDBECF74066027731394BF8CF4033C7. De huidige build bevat de savefix; de savefix-test staat nog open, dus één import van de huidige build volstaat voor beide.
- Savefix-inhoud: Save week-fix (lokale pre-save validatie, echte foutmelding bij nul writes, lblWeekLoadStatus) + Trade Unknown (Fitter/Welder/Unknown, Trade-chip en waarschuwingen op Screen1/scrHours).
- Testcases: TESTPLAN.md (TP-DD-01, TP-SAVE-01).
- Studio-testlijst (Eddy):
  0. Dropdowns (Team, Project, Contractor): rij onder de muis lichtblauw zichtbaar, gekozen item blauw/wit, ingedrukt lichtblauw (TP-DD-01).
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

## GEA-logo (regel vastgelegd in AGENTS.md, app-implementatie niet gedaan)
- Bestand Assets/GEA_logo_white.svg (1130 bytes, SHA-256 5D460376D030AF075E004E50191C8BE0C8DB05C5E0A9E593F53612DA52606087) is bytegelijk aan het officiële logobankbestand GEA_Logo_wo_Claim_sRGB_Solid_neg.svg (Screen/Solid/NEG, zonder claim, wit, viewBox 93,34 x 28,35); alleen dit bestand is getrackt.
- Geblokkeerd op een Studio-stap: pac (SourceCode) bewaart media in de .msapr (msapp\Assets\Images + msapp\References\Resources.json), niet in de projectmap Assets\; het Resources.json-schema en de gedocumenteerde control-ID/versie van Image zijn niet geverifieerd. Daarom geen logo in Src/.msapr.
- Open (Eddy, eenmalig): huidige testbuild importeren, Media > Upload Assets\GEA_logo_white.svg, één Image-control (Image = de upload) in de titelbalk van één scherm, app opslaan; daarna opnieuw uitpakken, echte media-entry en controlversie lezen en naar alle schermen repliceren. Rendert de SVG niet: fallback = officiële NEG-PNG uit dezelfde logobank (Screen/Solid/NEG/PNG, zonder claim), nooit hertekend of omgekleurd.

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
- Smalle vensters: Hours Summary-tabel heeft onder ~666 px geen weekkolom, projectregel in titelbalk kan onder ~690 px afkappen, footer scrolt horizontaal; zes bekende tekstoverschrijdingen bij smalle vensters; geen telefoonlayout voor de rapporttabel.
- Historische scripts falen ook op HEAD en zijn geen acceptatietests: Test-NavigationLayout, Test-Performance, Test-ReadExisting, Test-PerformanceFix, Test-SummaryFields (vergelijken met oude checkpoints).
- Save week/team zijn geen SharePoint-transactie; gedeeltelijke opslag blijft mogelijk (invoer behouden, opslag geblokkeerd).
- Bekende delegatie-uitzondering: maand-/dagpaginering van Hours Summary binnen ForAll(Sequence(monthCount)).
