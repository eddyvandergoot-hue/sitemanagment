# Projectstatus — 22 oktober 2026

## Overzicht - 25 oktober 2026

"Gebouwd" = aantoonbaar in Src; dat zegt niets over Studio-import of functionele test (zie de secties hieronder). Volgorde van open punten: NEXT_COMMANDS.md. Open beslissingen: ROADMAP.md. Handmatige stappen: MANUAL_STEPS.md.

| Onderdeel | Status | Bewijs |
|---|---|---|
| Batch-opslag Save week / Save team + Concurrent loads | Gebouwd. Laden getest door Eddy 22-10-2026: snel, geen fouten. **Open controle:** opslagsnelheid (Save week / Save team) nog niet expliciet bevestigd | Src: `Concurrent(`, `DIAG\|SaveWeek\|End` |
| Delegatiecorrectie Save team (ProjectKey = globale var) | Gebouwd. App checker: geen fouten en geen delegatiewaarschuwingen (gemeld door Eddy 22-10-2026) | Src: `varTeamSaveProjectKey` (4×) |
| MS-001 indexen (Hours.EntryKey, Hours.'Work Date', Project Workers.ProjectKey) | Open: uitvoeren / controleren | MANUAL_STEPS.md |
| Hours Summary-datumkiezers: KW-label, geen sprong | Gebouwd | Src: `lblReportFromWeek` |
| Lettertype Inter + Arial | Gebouwd | Src: 69× `"Inter, Arial, sans-serif"` |
| Projectmap naar Dev-map | Klaar | Hashvergelijking Src 5/5; commit ec0d408 |
| Bronmap platgeslagen naar projectmap (git-root) | Klaar, 25-10-2026 | Paden in docs/manifesten aangepast; pac pack vanuit de projectmap geslaagd; Test-SaveRegression PASS |
| Gecombineerde build (weekkiezer Weekly Hours, tabelrestyle, GEA-kleuren) | Gebouwd, niet geïmporteerd/goedgekeurd. Build: artifacts\combined-gea-20261022_134040\SiteManagement_CombinedGea_20261022_134040.msapp, SHA-256 C7616A268B6B6FF7F303F8E88C9C33D63B12674641EC598950BB5E338FCE3B6C (opnieuw gecontroleerd 25-10; Src 5/5 bytegelijk aan de bron in deze build) | Src: `dpHoursWeek`, 0× `ddHoursYear`, `recHoursHeaderBar`, `galReportTotalWeeks`, 0× oude paarse literals |
| **Save week-fix + Trade Unknown (nieuwste build)** | Gebouwd, niet geïmporteerd/goedgekeurd, niet functioneel getest. Build: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\savefix-trade-20261025_163517\SiteManagement_SaveFixTrade_20261025_163517.msapp, 101640 bytes, SHA-256 1891281F7F62DF1F739BA282D11B8218DEDBECF74066027731394BF8CF4033C7 (pac 2.11.2; Src 5/5 bytegelijk aan de bron). Details: sectie hieronder | Src: lokale validatie in `btnSaveWeek`; verifier 0 FAIL |
| MS-008 Trade-keuzes Workers/Hours | Workers.Trade klaar (Eddy, 25-10-2026); Hours.Trade-keuzes: bevestiging Eddy open | MANUAL_STEPS.md |
| Git: repository, branch main, baselinetag | Klaar | Commits ec0d408, 1fa3b94; tag baseline-footer-row-20261020_215936 |
| Push naar private GitHub | Remote ingesteld; Claude Code mag pushen na geslaagde verifier + reviewer (AGENTS.md); approved-tags alleen na Eddy | origin = github.com/eddyvandergoot-hue/sitemanagment |
| Housekeeping (status archiveren, AGENTS inkorten) | Open | — |
| Startscherm + Week Report | Open | Src: 0× `scrHome`, 0× `scrWeekReport` |
| Export (PDF + CSV, generieke flow) | Open; afspraak in AGENTS.md | — |
| Volledige roadmap in repo | Open; ROADMAP.md bevat nu alleen open beslissingen en geparkeerde punten | — |

## Save week-fix + Trade Unknown - 25 oktober 2026

Status: **geïmplementeerd en technisch gecontroleerd; niet in Studio geïmporteerd, niet functioneel getest, niet goedgekeurd door Eddy.**

**Incident (testbuild 22-10 op de echte lijsten):** Save week gaf "Opslag niet volledig bevestigd". Enige wijziging: Rafal Wielgos di 20-10-2026 = 10 u (nieuwe Hours-regel). Geen gegevensschade: er is niets geschreven (Writes=0, afgeleid uit de code en Eddy's waarneming: geen nieuwe regel, overige rijen ongewijzigd, geen duplicaten).
- Oorzaak: Workers.Trade was leeg voor Rafal (Trade kwam uit een Excel-import; de keuzekolom had geen keuzes). De bestaande controle in btnSaveWeek blokkeerde terecht (nul writes) met "Assignment, Employer, Team of Trade ontbreekt.", maar de eindhandler toonde bij elke fout "Opslag niet volledig bevestigd...", zette de week op Failed en verving de echte melding. Dus: juiste blokkade, misleidende melding; geen Patch-fout en geen verify-mismatch.
- SharePoint door Eddy hersteld: MS-008 (Workers.Trade Fitter / Welder / Unknown, standaard Unknown, verplicht, lege waarden gevuld). Hours.Trade-keuzes: bevestiging Eddy open.

**Geïmplementeerd (Src):**
- btnSaveWeek: lokale validatie per wijziging (nieuw + bestaand, ook expliciete 0) vóór Refresh/pre-read/write: koppeling en AssignmentKey/EntryKey consistent, medewerker in colWorkersCache, Employer.Id/Value, Trade (Fitter/Welder/Unknown toegestaan, leeg blokkeert), Team, uren 0-24 met max 2 decimalen (lege cel ongewijzigd). Alle fouten verzameld; één fout = nul writes.
- Nul writes + fout: echte eerste melding ("Niet opgeslagen; er is niets naar SharePoint geschreven. ..."), week blijft Loaded. ≥1 write + fout: Failed, opslag geblokkeerd, invoer behouden, geen automatisch ongedaanmaken (ongewijzigd). Gedragswijziging: sleutel-/duplicaatfouten uit de pre-read zetten varWeekReady niet meer op false (veilig: iedere Save leest opnieuw en schrijft dan niets).
- Trade op Hours = momentopname van Workers bij opslaan; nieuwe regels `Trade:{Value:<trade>}`, geen Choices(); bestaande regels alleen Title + Hours. Bij mislukte Patch van nieuwe regels met Trade Unknown: extra melding over MS-008.
- Patroon ongewijzigd: 1 pre-read + max 2 table-Patches + 1 verify read; 500/dag-terugval.
- lblWeekLoadStatus toont blijvende opslagfout ("Medewerker: melding [sleutel] (+N meer)"), rood #DB1E28, hoogte 40. btnReadWeek wist colHoursErrors bij echte load en cache-hit (achter de onopgeslagen-invoerpoort).
- UI: Screen1 lblWorkerWarning en scrHours lblItemWarning: chip "Trade onbekend" (niet-blokkerend) en rode blokkerende waarschuwingen voor ontbrekende Employer/Trade; alleen lokale colWorkersCache-lookups. Urenvelden HintText "" zodat leeg versus opgeslagen 0 zichtbaar is. Tekstbreedtes gemeten (Inter/Arial slechtste geval), passen op één regel.
- Tests uitgebreid: Test-SaveRegression (nieuw-recordpad, lege Trade, Unknown, expliciete 0, urenbereik/decimalen, "Opslag niet volledig bevestigd" alleen bij writes > 0, label, MS-008-melding); Test-GeaColors (kleur lblWeekLoadStatus).

**Technisch gecontroleerd:** reviewer tweemaal, geen blokkerende bevindingen. Verifier volledige set, 0 FAIL: Test-SaveRegression 175, Test-WeeklyCalculations 65, Test-GeaColors 179, Test-Fonts 177, Test-FooterRow -GeometryOnly 196, Test-SummaryDates 186, Test-SummaryStyle 197, Test-SummaryLabels 183, Check-WeeklySource OK. Vijf historische scripts falen identiek op HEAD 8d09ec8 (geverifieerd in aparte worktree) en zijn geen acceptatietests: Test-NavigationLayout, Test-Performance, Test-ReadExisting, Test-PerformanceFix, Test-SummaryFields (vergelijken met oude checkpoints).

**Functioneel getest: nee.** Studio-importcontrole, App checker en functionele test staan open.

**Studio-testlijst voor Eddy:**
1. Import + App checker op btnSaveWeek, btnReadWeek, lblWeekLoadStatus, lblItemWarning, lblWorkerWarning.
2. Medewerker met lege Trade + nieuwe cel: echte melding, week blijft Loaded, Trace `DIAG|SaveWeek|End` Writes=0.
3. Trade Unknown + nieuwe cel en expliciete 0: opgeslagen met Trade Unknown op Hours (faalt als Hours.Trade geen Unknown heeft; dan MS-008).
4. Uren 24,01 / 7,255: melding per cel.
5. Gewone Save met een bestaande + een nieuwe cel.
6. Chip/waarschuwing zichtbaar en niet afgekapt op Screen1 en Weekly Hours; leeg versus 0 in urenvelden.
7. Daarna: tag `approved-<datum>-savefix`, hier "approved by Eddy", tag pushen. Tot dan NIET goedgekeurd.

**Bekende beperkingen / niet-blokkerende reviewpunten:**
1. Na aanvullen van Trade/Employer in SharePoint: eerst onopgeslagen invoer terugdraaien (Refresh/Project-team-navigatie is geblokkeerd bij onopgeslagen invoer), dan Refresh op Project / team, dan opnieuw invoeren. Mogelijke latere verbetering: veilige Workers-cache-reload op scrHours.
2. Employer/Trade-validatie blokkeert ook correcties van bestaande Hours-regels (velden worden daar niet geschreven): bewust, fail-closed.
3. Screen1: naam kan de rode waarschuwing overlappen bij zeer smalle galleries (TemplateWidth < ~512, scherm < ~604 px).
4. lblWeekLoadStatus (2 regels) kan een zeer lange melding op smalle schermen afkappen.
5. Rode tekst in galleryrijen voor blokkerende stamgegevenswaarschuwingen (AGENTS.md aangepast).
6. Logica en presentatie zitten in één build (op verzoek).
7. Historische Hours-regels kunnen F/W bevatten, nieuwe Fitter/Welder/Unknown: relevant voor groepering in rapport/export.

**Procesincident:** een PowerShell-hulpfunctie `Rd` (alias van Remove-Item) van een subagent verwijderde Src/scrHours.pa.yaml met niet-gecommitte wijzigingen. Herbouwd uit de vastgelegde edits van de logica-agent; orchestrator verifieerde gelijkwaardigheid (alleen witregels verschilden). Geen verlies; regel toegevoegd aan AGENTS.md (Agents).

## Verhuizing projectmap naar C:\Users\vandergoot.ed\Dev\Sitemanagment - 22 oktober 2026

Status: **verhuisd en lokaal technisch gecontroleerd. App-inhoud (Src) ongewijzigd; geen nieuwe Studio-import nodig voor deze stap.**
- Oude OneDrive-map = alleen-lezen backup; er is niets naar geschreven.
- Git is nog niet geïnstalleerd; checkpoints blijven mapkopieën in checkpoints\.
- **Hashvergelijking (SHA256) met de OneDrive-map:**
  - Src: 5/5 .pa.yaml identiek. De oude Src bevatte nog een losse onvolledige download, `Unconfirmed 391983.crdownload`, die niet is meegekopieerd (terecht).
  - artifacts: 248/248 en checkpoints: 175/175 identiek.
  - Site Managment_VS.msapr, AGENTS.md en PROJECT_STATUS.md waren identiek.
- **Paden:**
  - De .ps1-scripts bevatten geen absolute paden; ze gebruikten al $PSScriptRoot.
  - De 24 pointerbestanden (artifacts\*-backup.txt, *-builddir.txt, *-buildpath.txt) zijn nu relatief aan de bronmap.
  - 10 scripts lossen die pointers op via $projectRoot/$root: Test-FooterRow, Test-NavigationLayout, Test-Performance, Test-PerformanceFix, Test-ReadExisting, Test-SummaryDates, Test-SummaryLabels, Test-SummaryStyle, Test-SummaryFields, Verify-PerformancePackage.
  - In PROJECT_STATUS.md, artifacts\VALIDATIE.md, latest-functional-test.json en preserved-screens.sha256.json is het oude pad vervangen door het nieuwe.
  - Niet aangepast: historische logs, namelijk pac-pack.txt per build, de diagnostische trace-JSON en checkpoints.
- Checkpoint vóór de wijziging: checkpoints\path-migration-20261022_144708.
- **Gecontroleerd vanaf het nieuwe pad:**
  - pac 2.11.2 canvas pack (SourceCode) is geslaagd: artifacts\path-migration-20261022_144819\SiteManagement_PathMigration_20261022_144819.msapp.
  - PASS: Test-SaveRegression, Test-WeeklyCalculations, Test-FooterRow -GeometryOnly, Test-SummaryDates, Test-SummaryStyle, Test-SummaryLabels, Test-Fonts, Test-GeaColors.
  - Test-SummaryLabels -HistoricalDiff en Verify-PerformancePackage vinden hun checkpoint/build op het nieuwe pad. Ze falen inhoudelijk zoals verwacht (historisch).
- **Vaste pac-locatie:** C:\Users\vandergoot.ed\Dev\Sitemanagment\pac\tools\pac.exe.
  - Dit is een kopie van het extensiepakket, gemaakt op 22-10-2026, met alle 1413 bestanden in tools. Versie 2.11.2+g47bc199 is gecontroleerd.
  - De kopie wordt niet bijgewerkt door updates van de VS Code-extensie.
  - De scripts vinden pac via `Get-Command pac` en laden de DLL's uit dezelfde map. Daarom moet de hele tools-map blijven staan.
  - Gebruikers-PATH: alleen ...\Sitemanagment\pac\tools, niet ook de extensiemap (%APPDATA%\Code\User\globalStorage\microsoft-isvexptools.powerplatform-vscode\pac\tools).
  - Controleer met `(Get-Command pac).Source`.
  - Bevestigd op 22-10-2026 in een nieuwe terminal:
    - `Get-Command pac -All` vindt alleen ...\Sitemanagment\pac\tools\pac.exe.
    - Gebruikers-PATH bevat alleen die map; de extensiemap staat er niet in.
    - Versie 2.11.2+g47bc199.
    - De tools-map bevat 279 bestanden.
    - `pac canvas pack --layout SourceCode` vanuit de bronmap is geslaagd (testbestand alleen in de scratchmap, geen build).
- De nieuwste functionele testbuild blijft de gecombineerde build hieronder; de path-migration-pack is alleen een packtest.

## Gecombineerde build: weekkiezer Weekly Hours, tabelrestyle Hours Summary, GEA-kleuren - 22 oktober 2026

Status: **alle drie de delen geïmplementeerd en lokaal technisch gecontroleerd. Niet in Studio geïmporteerd, niet in de browser bekeken, niet functioneel getest.**
- Checkpoint vóór de wijziging: checkpoints\combined-gea-20261022_132638 (YAML, AGENTS.md, PROJECT_STATUS.md, testscripts, Measure-FontFit).
- De eerdere onderdelen 2 (From/Till-weeklabels) en 5 (Inter/Arial) zijn behouden.
- Er zijn geen SharePoint-gegevens gelezen of gewijzigd; er is geen loader-, filter- of opslaglogica gewijzigd, behalve de weekselectie in deel 1.

**Deel 1: weekkiezer Weekly Hours (scrHours)**
- ddHoursYear en ddHoursWeek zijn vervangen door dpHoursWeek (ModernDatePicker@1.0.0, "dd-mm-yyyy", StartOfWeek.Monday, 256 px, op de oude positie, zonder StartDate/EndDate).
- De labels "ISO Year"/"KW" zijn één label "Week" geworden. Naast de kiezer staat lblHoursWeekKW met "YYYY KWxx".
- **Variabelen:**
  - varHoursPickedDay is de getoonde dag; varHoursWeekMonday is de afgeleide maandag.
  - OnVisible zet bij het eerste bezoek vandaag en leidt de maandag af.
  - DefaultDate = Coalesce(varHoursPickedDay, Today()).
- **OnChange:**
  - Overgeslagen tijdens laden en opslaan.
  - Een andere week laadt (Select(btnReadWeek)); dezelfde week bewaart alleen de dag.
  - Met onopgeslagen uren: Reset plus een melding, en niet laden.
  - De OnChange na een Reset is een no-op. Er is geen Reset na een gewone keuze.
- **Alle verwijzingen naar de dropdowns** (15× in de invoervelden en de cache-hit, 2× in de Save-guard) zijn vervangen door `varLoadedWeekMonday=varHoursWeekMonday`.
  - btnReadWeek gebruikt varPendingWeekMonday = varHoursWeekMonday.
  - varWeekLoadedISOYear/KW worden uit de maandag afgeleid.
  - Het jaarbereik (twee `Sort(Hours,'Work Date')`-queries, varEntryFirst/LastISOYear, varEntryYearsLoaded) is verwijderd.
  - Er zijn 0 dropdownverwijzingen over.
- **Gedragsverandering:** de standaardweek is nu de week van vandaag. Voorheen was dat dezelfde ISO-week via de dropdowns, dus in de praktijk gelijk. Er is geen grens aan de kiesbare datums meer (dat was jaar ±5 rond de uren).

**Deel 2: tabel Hours Summary (alleen presentatie)**
- **Zebra en lijnen:** zebra #FFFFFF/#F0F0F0; rijlijnen 1 px #DCDCDC.
- **Period total-kolom:** geen vlakkleur, tekst #000F41 Bold, 1 px #DCDCDC-lijn links.
- **Nulwaarden:** 0 in weekcellen, Period total en de totaalrij wordt getoond als "–" (Normal). De gegevens behouden 0 (alleen de tekstformule heeft een extra vertakking).
- **Totaalrij:** lblReportGrandTotal is vervangen door een totaalrij direct onder de rijen (buiten de gallery, boven de footer).
  - #D5EDFF, 2 px bovenlijn #0303B8, Bold zwart.
  - "Total" in de Name-kolom.
  - Weeksommen in galReportTotalWeeks, met exact dezelfde Items-paginering en -offset als de kop.
  - Periodetotaal onder de Period total-kolom.
  - De rijgallery is zo hoog als haar rijen (maximaal tot boven de totaalrij).
- **Scrollbarruimte (16 px):** kop, rijcellen en totaalrij eindigen op breedte-56. Daarvoor zijn de breedteformules gewijzigd: `Width-600` → `Width-616` (20×), Period total-X -160/-200 → -176/-216. Er zijn daardoor één tot enkele weekkolommen minder zichtbaar op dezelfde schermbreedte. Weekkolommen vanaf ongeveer 666 px (was 650).

**Deel 3: GEA-kleuren app-breed (alleen presentatie)**
- 271 kleurwaarden zijn omgezet en 58 rol-eigenschappen toegevoegd, zoals de rand van secundaire knoppen, FocusedBorderColor van invoer en Fill van tekstinvoer. Volledig log: artifacts\combined-gea-20261022_134040\color-mapping-log.txt.
- Weekly Hours-kolomkoppen staan nu wit op een doorlopende balk #0303B8 (nieuwe rechthoek recHoursHeaderBar). Dat vervangt de blauwe tekst uit de fontopdracht.

| Oud | Nieuw (GEA) | Rol / plaats |
|---|---|---|
| RGBA(25,66,150) | #0303B8 | titelbalken, tabelkoppen, hover-rand invoer, selectie |
| #194296 | #0303B8 | navigatieknoppen |
| #123273 | #000F41 | hover/pressed navigatie |
| #7040A0 | #1AFF80 (Save/Save team), wit (Refresh/pijlen) | actieknoppen naar primair/secundair |
| #593080 | #18DD6E (primair), #D5EDFF (secundair hover), #0303B8 (secundaire rand) | hover/pressed acties |
| #E5E7EB / #6B7280 / #596579 | #E6E6E6 / #787878 / #E6E6E6 | uitgeschakelde knoppen |
| RGBA(0,120,212), RGBA(16,110,190), #193F83, RGBA(50,49,48) chevron | #0303B8 | spinner, checkbox, selectie, focus/hover-randen, chevrons |
| RGBA(244,246,250), #F4F6FA, RGBA(240,245,252), RGBA(234,241,252), #EAF1FC (hover), RGBA(245,245,245) (vlak), RGBA(240,240,240), RGBA(242,246,252) (invoer) | #F0F0F0 | invoer, dropdowns, footerbalk, schermachtergrond Screen1 |
| RGBA(210,218,230), RGBA(245,245,245) (rand), #E1E6EF | #DCDCDC | randen |
| #EAF1FC (geselecteerde kaart), RGBA(231,240,252) (lblWeekTotal) | #D5EDFF | selectie, weektotaal |
| RGBA(242,246,252), RGBA(231,240,252) (koppen) | #0303B8 | weekend-/totaalkoppen Weekly Hours |
| RGBA(161,159,157), RGBA(225,223,221), RGBA(166,166,166) | #787878 | uitgeschakelde tekst, icoon |
| RGBA(96,94,92) | #0303B8 | checkboxrand |
| Color.Red | #DB1E28 | foutstatus |
| RGBA(0,0,0,0), RGBA(242,242,241,0) | Color.Transparent | |
| RGBA(255,255,255,1) / RGBA(0,0,0,1) | Color.White / Color.Black | |
| #E8EDF5 / #EEE7F5 | #F0F0F0 / verwijderd | zebra / Period total-accent (deel 2) |

**Grep in Src (en gelijk in de build):**
- 0×: #7040A0, #593080, #194296, #123273, #E8EDF5, #EEE7F5, #193F83, #EAF1FC, #F4F6FA, #E5E7EB, #6B7280, #596579, #E1E6EF, `RGBA(`, Color.Red.
- 0×: ddHoursYear, ddHoursWeek, varEntry*ISOYear, varEntryYearsLoaded, lblISOYears, lblReportGrandTotal.
- Alleen GEA-tokens in gebruik:

| Token | Aantal |
|---|---|
| #0303B8 | 109 |
| Color.White | 49 |
| #000000 | 41 |
| #F0F0F0 | 39 |
| Color.Transparent | 37 |
| #787878 | 24 |
| #000F41 | 24 |
| #E6E6E6 | 22 |
| #DCDCDC | 21 |
| #D5EDFF | 13 |
| #18DD6E | 8 |
| Color.Black | 5 |
| #1AFF80 | 4 |
| #DB1E28 | 2 |
| #FFFFFF | 1 |

**Tests (alle uitgevoerd op de definitieve bron)**

| Script | PASS | Wat |
|---|---|---|
| Test-SaveRegression | 132 | 1549 formules zonder syntaxfout; 101 controls met geldige template-eigenschappen. De Save-guard is gelijk aan het checkpoint na exact één herschrijving (ISO-jaar/KW → gekozen week). Andere/geen gekozen week blokkeert. Overige Save-asserts en delegatiescan. |
| Test-WeeklyCalculations | 65 | Echte dpHoursWeek.OnChange met acties als labels: zelfde week → alleen dag; na Reset → niets; andere week → laden; onopgeslagen → Reset+melding; tijdens laden → niets; leeg → Reset. Maandag-normalisatie. Weeklabel 2026 KW53 (01-01-2027), 2020 KW53, 2025 KW01. Geen dropdowns of jaarbereik-queries. |
| Test-SummaryDates | 143 | From/Till-kiezers, weeklabels en layout 320–1920 (ongewijzigd gedrag). |
| Test-SummaryStyle (herschreven) | 154 | Zebra, "–" voor 0 (Normal), Period total-kolom, totaalrij (sommen en paginering met fixture), kop/rijen/totaal uitgelijnd met scrollbarruimte. |
| Test-SummaryLabels (herschreven) | 140 | Labels, titelbalk, Number vóór Reference, rechterrand totaalrij = Period total-kolom. |
| Test-FooterRow -GeometryOnly | 153 | Footer op alle schermen. Totaalrij direct onder de rijen bij 1 en 100 rijen, boven de footer. Gelijke rechterranden. |
| Test-Fonts (aangepast) | 134 | 69× Inter/Arial; gewichtsrollen inclusief de nieuwe controls. |
| Test-GeaColors (nieuw) | 136 | 0× oude literals, alleen tokens; knoprollen inclusief disabled; koppen, invoer, weektotaal, fout. |

- **Measure-FontFit (Inter en Arial, slechtste geval):** alle nieuwe teksten passen, waaronder "Week", "2026 KW53" (92 van 110 px), "28-12-2026", "Total" en "123456,25" (80,7 van 110 px). Dezelfde 6 bekende overschrijdingen bij smalle vensters blijven.
- **Historische checkpoint-diffs** (SummaryStyle/Labels/Dates) draaien alleen met `-HistoricalDiff`. Test-PerformanceFix, Test-Performance, Test-ReadExisting, Test-SummaryFields en Test-NavigationLayout zijn historisch en niet aangepast.
- **PAC-pack** geslaagd. De YAML in de build is gelijk aan Src; Properties/DataSources/Templates/Resources/Themes zijn gelijk aan .msapr; site GEASiteManagment.

**Nieuwe aparte testbuild** (vervangt gea-fonts-20261022_125238; Save schrijft naar de bestaande lijsten):
artifacts\combined-gea-20261022_134040\SiteManagement_CombinedGea_20261022_134040.msapp
- Grootte 100294 bytes; SHA-256 C7616A268B6B6FF7F303F8E88C9C33D63B12674641EC598950BB5E338FCE3B6C.
- Logs: pac-pack.txt, package-checks.txt, color-mapping-log.txt, font-fit.txt.

| Onderdeel | Src | Build | AGENTS.md |
|---|---|---|---|
| 1 Weekkiezer Weekly Hours | ja | ja | ja (regel weekkeuze) |
| 2 From/Till-weeklabels, geen reset | ja | ja | ja |
| 3 Tabelrestyle + totaalrij | ja | ja | ja (opmaak tekst en tabel) |
| 4 GEA-kleuren | ja | ja | ja (sectie GEA-kleuren, vervangt knopkleuren) |
| 5 Inter/Arial | ja | ja | ja |

**Open en alleen in Studio/browser te bevestigen**
1. Import: ModernDatePicker nu ook op scrHours, met BorderColor/BorderThickness. De template is nog steeds onbevestigd.
2. Weekly Hours:
   - kies een woensdag: de kiezer blijft woensdag, het label toont de juiste KW en de week laadt;
   - kies een andere dag in dezelfde week: geen laadactie;
   - met onopgeslagen uren is de kiezer uitgeschakeld.
3. Save week na weekwissel: werkt alleen voor de geladen week (de guard is herschreven, opnieuw testen).
4. Hours Summary:
   - de werkelijke scrollbarbreedte van de gallery (aangenomen 16 px);
   - "–" en de totaalrij bij weinig en veel rijen;
   - de totaalrij sluit direct aan op de laatste rij.
5. Kleurcontrast en knoppen in de browser; groen #1AFF80 met #000F41-tekst; secundaire knoppen met 1 px rand.
6. Nog steeds open: de zomertijdcontrole van het aantal weekkolommen (From 23-03-2026, Till 05-04-2026), en de delegatie van de maand/dag-paginering van Hours Summary.

## GEA-typografie: Inter met Arial-fallback - 22 oktober 2026

Status: **geïmplementeerd en lokaal technisch gecontroleerd; alleen presentatie.** Niet in Studio geïmporteerd, niet in de browser bekeken. Checkpoint: checkpoints\gea-fonts-20261022_124840 (YAML, AGENTS.md, PROJECT_STATUS.md, Test-OpenSans.ps1, Measure-FontFit.ps1).

**Wijzigingen (Src, 107 eigenschappen)**
- **Font:** alle 68 Font-eigenschappen zijn nu `="Inter, Arial, sans-serif"`, waarvan 67× Open Sans en 1× Segoe UI op de verborgen btnBuildReport. Er is geen Font-enum en geen GEA Sans meer in de app.
- **Gewichten:** ongewijzigd. Semibold voor titels, kolomkoppen en knoppen; Bold voor de Hours Summary-veldlabels en Period total; Normal voor de rest. Subtitle4 houdt zijn voorwaardelijke gewicht.
- **Tekstkleuren volgens GEA:**
  - Grijze body-tekst wordt zwart #000000:
    - Screen1: Subtitle4, Checkbox1 (ook hover/pressed), ddProject/ddTeam (ook hover), lblProject, lblTeam, Label2 en de statusregel buiten de fouttoestand.
    - Weekly Hours: lblISOYears, lblKW, ddHoursYear/ddHoursWeek (ook hover), lblItemTitle, txtMon t/m txtSun, lblWeekTotal (tabeldata, was blauw) en de statusregel buiten de fouttoestand.
  - Kolomkoppen van Weekly Hours (Worker, Mon t/m Sun, Total): `RGBA(25,66,150)` wordt Vibrant Blue #0303B8.
  - Ongewijzigd: titels, de Hours Summary-tabelkop, de titelbalkregel en knoppen (wit op blauw), de rode fouttoestand, uitgeschakelde kleuren en alle vlakkleuren (Fill).
- **Breedte:** btnReportPreviousWeeks en btnReportNextWeeks gaan van 44 naar 48 px. In Inter is "<" 12,9 px breed bij 12 px beschikbaar. De rijbreedte rekent mee: de minimale knoppenrij van Hours Summary is nu 502 px (was 494).

**Tekstpassing (Measure-FontFit.ps1, nu Inter en Arial, slechtste geval, 3% marge)**
- Gebruikte fontbestanden: C:\Windows\Fonts\Inter-Regular/SemiBold/Bold.ttf (Inter staat op deze machine) en arial.ttf/arialbd.ttf. Arial Semibold bestaat niet; de browser toont dan Bold, dus Semibold is met arialbd gemeten.
- Alle knoppen, labels, veldlabels, weeklabels, koppen en totalen passen. Krapste gevallen:
  - "Refresh" 72,5 van 78 px
  - "Weekly Hours" 129,8 van 138 px
  - "Hours Summary" 149,1 van 158 px
  - "<"/">" 12,9 van 16 px
- Er blijven 6 overschrijdingen. Die bestonden al met Open Sans en zijn niet verslechterd tot nieuwe gevallen:
  - titel "Hours Summary" bij 320 px;
  - dagkoppen en invoer van Weekly Hours bij 768 px;
  - weekkop bij 650 px;
  - projectregel op één regel bij 768 px (wrapt naar twee).
- Uitvoer: artifacts\gea-fonts-20261022_125238\font-fit.txt.

**Tests**
- Nieuw: Test-Fonts.ps1 (vervangt Test-OpenSans.ps1; de oude versie staat in het checkpoint). Uitkomst: 158 PASS.
  - 68× Inter/Arial; geen Font-enum, Open Sans, Segoe UI, Montserrat of GEA Sans.
  - Gewichtsrollen kloppen en zijn ongewijzigd.
  - Kleurregels: kopblauw, wit op blauw en zwarte body.
  - Diff tegen het checkpoint: alleen Font, tekstkleuren en de pijlbreedte.
- Test-SaveRegression (154 PASS): de byte-gelijkheid van Save-knopeigenschappen zondert nu alleen `Font` uit. Guards, OnSelect en DisplayMode blijven strikt.
- Test-SummaryDates (165 PASS, verwacht nu de Inter-waarde), Test-WeeklyCalculations (47) en Test-FooterRow -GeometryOnly (175; Hours Summary-rij 502 px bij alle breedtes): geslaagd.
- De historische diff-scripts (SummaryLabels/Style/Fields, NavigationLayout, Performance, ReadExisting, PerformanceFix) zijn niet aangepast; zij verwachten oudere checkpoints of Open Sans.
- PAC-pack geslaagd. De YAML is gelijk aan Src; Properties/DataSources/Templates/Resources/Themes zijn gelijk aan .msapr.

**Nieuwe aparte testbuild** (vervangt summary-weeklabels-20261022_123059):
artifacts\gea-fonts-20261022_125238\SiteManagement_GeaFonts_20261022_125238.msapp
- Grootte 100458 bytes; SHA-256 3E13A0CDD73563FDB7DDB8D13328C1EE6794332AA518373D830DE296137B2A55.

**Te controleren door jou (Studio/browser)**
1. Import zonder fout, ook voor Font als tekstwaarde op ModernDatePicker. Bij een fout de exacte melding doorgeven.
2. Op een apparaat met Inter: de tekst staat in Inter. Op een apparaat zonder Inter: Arial. Controleer in de browser via DevTools → Computed → Rendered Fonts.
3. Knoppen, titels, weeklabels en Period total zonder afkappen, bij 100% en 125% zoom.
4. Kolomkoppen van Weekly Hours in Vibrant Blue; body-tekst zwart; statusregels rood bij een fout.

## Hours Summary: weeklabel per datumkiezer, geen zichtbare normalisatie - 22 oktober 2026

Status: **geïmplementeerd en lokaal technisch gecontroleerd. Niet in Studio geïmporteerd, niet in de browser bekeken, niet functioneel getest.**
- Checkpoint vóór de wijziging: checkpoints\summary-weeklabels-20261022_122433.
- Alleen scrWeeklyHours.pa.yaml is gewijzigd ten opzichte van de vorige build (delegation-fix). Er zijn geen SharePoint-gegevens gelezen of gewijzigd.

**Wijzigingen (scrWeeklyHours)**
- **dpReportFrom / dpReportUntil**
  - De reset na een gewone keuze is verwijderd. De kiezer blijft de gekozen dag tonen.
  - Nieuwe variabelen varReportFromPickedDay / varReportUntilPickedDay.
  - DefaultDate = `Coalesce(gekozen dag, varReportStartMonday / varReportEndSunday)`.
  - Normalisatie ongewijzigd: From → maandag, Till → zondag. Bouwen alleen bij een gewijzigde weekgrens; een andere dag in dezelfde week bouwt niet opnieuw.
  - Reset alleen bij een leeg gemaakt veld. Dan wordt ook de gekozen dag gewist en toont de kiezer de genormaliseerde datum.
  - DisplayMode, StartDate/EndDate, Format en ValidationState zijn ongewijzigd.
- **btnLoadReport**
  - Wist bij de standaardperiode en bij een mislukte load eerst de gekozen dagen, en reset daarna de kiezers, zoals voorheen.
  - Verder ongewijzigd (geen loader-, filter- of 500-wijziging).
- **Nieuw: lblReportFromWeek / lblReportUntilWeek** (Label@2.5.1, bestaande template)
  - Tonen "YYYY KWxx": ISO-jaar = Year(maandag+3), KW met twee cijfers via ISOWeekNum (zoals Weekly Hours).
  - From toont de week van varReportStartMonday, Till die van varReportEndSunday.
  - Ze staan in hetzelfde vak als het veldlabel (zelfde X/Y/breedte 256/hoogte 24), rechts uitgelijnd; het veldlabel staat links.
  - Open Sans 12 Normal, zwart.
  - Er zijn geen veld- of kolombreedtes gewijzigd. Er is geen aparte perioderegel.
- **Till vóór From:** geblokkeerd zoals voorheen (melding in de build en ValidationState.Error op Till). Beide weeklabels blijven de gekozen weken tonen.

**Lokaal gecontroleerd**
- Test-SummaryDates.ps1 (herschreven): 167 PASS. Het historische checkpoint-diffdeel faalde al sinds eerdere opdrachten op niet-gerelateerde wijzigingen; het draait nu alleen met `-HistoricalDiff`.
  - **Structuur:**
    - De labels staan in conSummaryFiltersContent.
    - De DefaultDate-vorm klopt.
    - `Reset(dpReport…)` komt alleen voor in btnLoadReport en in de lege-veldtak van de eigen OnChange.
    - Er is geen `If(selectedDay<>…, Reset)` meer.
    - De gekozen dag wordt opgeslagen.
    - De 500-grenzen in de loader en ValidationState zijn ongewijzigd.
  - **Normalisatie:** 8 datums, waaronder 28-12-2020, 03-01-2021 en de jaarwisseling. Gecontroleerd:
    - normalisatie naar maandag/zondag;
    - geen nieuwe build bij herhaalde OnChange met dezelfde dag (geen lus);
    - geen nieuwe build bij alle 7 dagen van dezelfde week.
  - **Weeklabels:**
    - 2026 KW43
    - 2020 KW53 (28-12-2020 t/m 03-01-2021)
    - 2026 KW53 over de jaarwisseling
    - 2025 KW01 (vanaf 30-12-2024)
    - 2027 KW01
    - Till vóór From (2026 KW10 / KW02)
    - leeg bij geen periode
  - De lokale interpreter kent geen ISOWeekNum. In de test is die daarom vervangen door de donderdagregel, die eerst dag voor dag over 2000–2040 gelijk is bevonden aan de ISO-referentie.
  - **Layout** bij 320, 480, 768, 888, 1024, 1366 en 1920 px:
    - Labels direct boven hun veld.
    - Project/Contractor 512 px, From/Till 256 px.
    - Twee kolommen vanaf 888 px, anders gestapeld.
    - Weeklabels in het 256-px-labelvak.
    - Geen overlap behalve het bewust gedeelde labelvak.
    - De containerhoogte snijdt niets af.
  - **Tekstpassing:** "From"/"Till" Bold + "2026 KW53": conservatieve schatting 137 px < 256 px. **Niet gemeten**, want er zijn geen Open Sans-fontbestanden lokaal.
- Test-SaveRegression (156 PASS), Test-WeeklyCalculations (47) en Test-FooterRow -GeometryOnly (177): geslaagd.
- Test-PerformanceFix stopt nu op zijn historische diff (`dpReportFrom.DefaultDate`). Dat is verwacht en het script is historisch. De overige diff-scripts geven dezelfde meldingen als vóór deze opdracht.
- PAC-pack geslaagd. De YAML is gelijk aan Src; Properties/DataSources/Templates/Resources/Themes zijn gelijk aan .msapr.

**Nieuwe aparte testbuild** (vervangt delegation-fix-20261022_113850):
artifacts\summary-weeklabels-20261022_123059\SiteManagement_SummaryWeekLabels_20261022_123059.msapp
- Grootte 100465 bytes; SHA-256 98E8C4E06BC85CC14A19B31457115C019AA04D609865D92F864319374D1CA843.

**Bijvinding, niet gewijzigd: zomertijd en het aantal weken**
- In de lokale Power Fx-interpreter (tijdzone W. Europe) geeft `DateDiff(Date(2026,3,23), Date(2026,4,6), TimeUnit.Days)` **13** in plaats van 14. Dat komt door de 23-uursdag bij de overgang naar zomertijd. In de herfst is het resultaat 14.
- btnBuildReport bepaalt het aantal weekkolommen met `Sequence(DateDiff(varReportFrom,varReportUntil,TimeUnit.Days)/7)`.
- Gedraagt Power Apps in de browser zich hetzelfde, dan mist een periode over eind maart de laatste week, en worden ook urenregels in die week niet meegeteld.
- Niet bewezen voor canvas/browser. **Controle:** kies From 23-03-2026 en Till 05-04-2026 en controleer dat er 2 weekkolommen zijn (KW13, KW14).
- Mogelijke correctie in een volgende opdracht: het aantal weken afleiden via `Round(DateDiff(…, TimeUnit.Hours)/24, 0)/7` of via een weekteller op de maandagen.

**Te controleren door jou (Studio/browser)**
1. Import zonder fout. De ModernDatePicker-template is nog steeds onbevestigd.
2. Kies From = woensdag:
   - de kiezer blijft woensdag tonen (geen sprong);
   - het weeklabel toont de juiste "YYYY KWxx";
   - het rapport begint op maandag;
   - een andere dag in dezelfde week bouwt niet opnieuw (geen "Laden"-flits).
3. Kies Till = dinsdag: het rapport loopt t/m zondag van die week.
4. Kies Till vóór From: foutmelding en rode Till, beide weeklabels zichtbaar.
5. Ander project: de kiezers springen terug naar de standaardperiode.
6. Wis een datumveld: de genormaliseerde datum verschijnt terug.
7. Tekstpassing van "From" + weeklabel bij 100% en 125% zoom.
8. De zomertijdcontrole hierboven.

## Delegatiecorrectie: globale variabelen in SharePoint-predicaten - 22 oktober 2026

Status: **geïmplementeerd en lokaal technisch gecontroleerd. Niet in Studio geïmporteerd, App checker niet uitgevoerd, niet functioneel getest.** Er zijn geen SharePoint-records gelezen of gewijzigd.

Aanleiding: Studio gaf een delegatiewaarschuwing op `StartsWith(AssignmentKey, projectKeyValue & "|")` in btnAddtoTeam. `projectKeyValue` is een With-naam. Dit filter week bovendien af van de AGENTS-regel (Project Workers alleen op ProjectKey).

**Wijzigingen**
- **Save team (Screen1.btnAddtoTeam)**
  - Eerst `Set(varTeamSaveProjectKey, Text(varTeamLoadedProjectID))`.
  - Daarna één read: `Filter('Project Workers', ProjectKey = varTeamSaveProjectKey)`, inclusief inactieve koppelingen.
  - Bij ≥500 rijen of `Project.Id <> varTeamLoadedProjectID`: fout en nul writes.
  - Lokale match en dubbelcontrole op `AssignmentKey = varTeamSaveProjectKey & "|" & Text(person.ID)`.
  - Guard, meldingen en writes zijn ongewijzigd.
  - **Terug naar het risico van de vorige keuze:** een koppeling met een juiste AssignmentKey maar een lege of afwijkende ProjectKey wordt niet gevonden. Save team kan dan een dubbele koppeling aanmaken. De SharePoint-controle uit punt 1 hieronder ("ProjectKey is leeg" → verwacht 0 items) is daarom nu voorwaardelijk voor Save team.
- **Save week (scrHours.btnSaveWeek)**
  - De With-namen `projectPrefix`, `dateFrom` en `dateUntil` zijn vervangen door `varSaveQueryPrefix`, `varSaveQueryFrom` en `varSaveQueryUntil` (Set vóór de pre-read).
  - De dagterugval (alleen bij ≥500 rijen) bestaat nu uit 7 uitgeschreven queries met `DateAdd(varSaveQueryFrom, k, Days)` in plaats van `ForAll(Sequence(7))` met With-namen. Dat geldt voor zowel de pre-read als de verify read.
  - De guard is nog steeds byte-gelijk aan het checkpoint.
- **Week laden (scrHours.btnReadWeek)**
  - Dezelfde omzetting: `varWeekQueryPrefix/From/Until`.
  - De dagterugval is uitgeschreven. De 500-dagcontrole gebeurt nu lokaal met `CountIf` op de verzamelde regels; volle dag = blokkade, zoals voorheen.
- **Hours Summary (scrWeeklyHours.btnLoadReport)**
  - Het With-blok met `projectPrefix` is vervangen door `Set(varReportQueryPrefix, varReportProjectKey & "|")`. Alle `StartsWith(EntryKey, …)` gebruiken die variabele.
- **Niet opgelost (open):** de maand- en dagpaginering van Hours Summary gebruikt nog `monthFrom/monthUntil` en `dayFrom/dayUntil` binnen `ForAll(Sequence(monthCount))`. Set is niet toegestaan binnen ForAll en het aantal maanden is variabel, dus uitschrijven kan niet.
  - Dit pad wordt alleen gebruikt bij ≥500 urenregels voor het project.
  - Geeft Studio daar een delegatiewaarschuwing, geef dan de exacte regel door.
  - Mogelijke oplossingen (nog niet gebouwd): een timergestuurde lus die per stap een globale var zet, of een vaste bovengrens van maandqueries met blokkade daarboven.
- **Stringliterals:** in heel Src staat geen stringliteral met een regeleinde (gecontroleerd met een tokenizer per formule). De `"|"` in Save team stond al op één regel.

**Lokaal gecontroleerd**
- Test-SaveRegression.ps1 (bijgewerkt en uitgebreid): 156 PASS, 0 FAIL.
  - 1469 formules zonder syntaxfouten.
  - Guards zijn byte-gelijk.
  - Save week: 16 Hours-filterplaatsen (1+7 pre-read, 1+7 verify) en globale query-variabelen die vóór de eerste read worden gezet.
  - Save team: ProjectKey-filter, geen StartsWith, Project.Id-controle en lokale AssignmentKey-match.
  - **Nieuw over alle schermen:**
    - Geen regeleinde in stringliterals.
    - Alle 33 predicaten op Hours/'Project Workers' gebruiken alleen kolommen, functies en globale variabelen.
    - Het tweede argument van StartsWith is altijd een enkele globale var.
    - Enige toegestane uitzondering: de rapport-maand/dagpaginering.
- Test-WeeklyCalculations (47 PASS) en Test-FooterRow -GeometryOnly (177 PASS): geslaagd.
- Test-PerformanceFix: twee loader-asserts aangepast aan de globale prefixvariabele en de lokale 500-dagcontrole. De bedoeling blijft gelijk (EntryKey-prefix met afsluitend "|", volle dag blokkeert). Zonder de historische Save-diffregels: alle asserts PASS. Met die regels faalt het, zoals verwacht, op de Save week-diff.
- De overige diff-scripts (Performance, ReadExisting, SummaryDates/Labels/Style/Fields, OpenSans, NavigationLayout, FooterRow-diff): dezelfde historische meldingen als vóór deze opdracht.
- PAC-pack geslaagd vanuit een schone kopie (het .crdownload-bestand staat nog in Src).
  - De YAML is gelijk aan Src.
  - Properties/DataSources/Templates/Resources/Themes zijn gelijk aan .msapr.
  - Site GEASiteManagment.

**Nieuwe aparte testbuild** (vervangt save-batch-20261022_091955; Save schrijft naar de bestaande lijsten):
artifacts\delegation-fix-20261022_113850\SiteManagement_DelegationFix_20261022_113850.msapp
- Grootte 100329 bytes; SHA-256 1ED1B296DB61E6A728D742DB8390EB13446AE94C9DB2591ABB305779B7CBC978.
- Log: pac-pack.txt, package-checks.txt.

**Te controleren door jou**
1. **SharePoint (alleen lezen), vóór Save team:** in Project Workers verwacht 0 items met een lege ProjectKey, en ProjectKey = project-ID. Is dat niet zo, stuur dan aantallen en ID's en gebruik Save team niet voor die projecten.
2. **Studio/App checker:** geen delegatiewaarschuwing op btnAddtoTeam, btnSaveWeek, btnReadWeek en btnLoadReport. Bij een melding: geef de exacte formuleregel door. Verwacht hooguit iets in de maand/dag-paginering van btnLoadReport.
3. **Monitor:**
   - Save team: één getRows op Project Workers met `$filter=ProjectKey eq '<id>'`.
   - Save week: `startswith(EntryKey,'<id>|')` met het Work Date-bereik.
4. Daarna de functionele Save-tests uit de vorige sectie.

## Exportspecificatie vastgelegd (niet gebouwd) - 22 oktober 2026

Status: **alleen een afspraak in AGENTS.md. Er zijn geen app-, flow- of SharePoint-wijzigingen. Er is niets gebouwd, getest of verpakt.** De nieuwste testbuild blijft save-batch-20261022_091955.

Vastgelegd in AGENTS.md, sectie "Export (afspraak 22-10-2026, nog niet gebouwd)":
- Hours Summary: CSV van de gekozen periode, één bestand per selectie (project + werkgever, of alle werkgevers), lang formaat per opgeslagen dagregistratie. Geen PDF.
- Week Report: PDF + CSV per werkgever, ongewijzigd.
- Eén gedeelde CSV-formule (Concat), HTML voor de PDF in de app, en een UTF-8 BOM via UniChar(65279).
- Generieke flow: invoer `[{fileName, type: csv|html2pdf, content}]`, opslaan in de bibliotheek Exports, html2pdf via Convert file, antwoord met links. Geen bedrijfslogica in de flow.
- Export alleen bij een geldig rapport, fail-closed zoals Save.

Vervangen of aangepast in AGENTS.md:
- De .xlsx-afspraak (per project en werkgever, naam/weektotalen/periodetotaal) is vervangen.
- De regel "export gescheiden per project en werkgever" is vervangen; "alle werkgevers" in één bestand is nu toegestaan.
- De regel over de bestaande flow verwijst nu naar de nieuwe generieke flow. De bestaande flow-ID's en parameters zijn niet aangepast.

Open punten vóór het bouwen (graag aanleveren):
1. **Week Report bestaat lokaal niet:** geen scherm in deze app en geen kolomdefinitie in de bron of documentatie. Ik neem aan dat het de Excel/VBA-werkwijze is. Lever de CSV-kolommen, de volgorde, het scheidingsteken (`,` of `;`), het decimaalteken, de datumnotatie en eventuele kopregels aan, bijvoorbeeld als voorbeeld-CSV.
2. **Periodetotaal 0:** de oude afspraak sloot deze medewerkers uit. In lang formaat per dagregistratie zou een medewerker met alleen 0-uurregistraties regels met 0 krijgen. Moeten die eruit, of horen ze er bij "zelfde spec als Week Report" juist in?
3. **"Alle werkgevers":** bedoel je één bestand voor het gekozen project, of ook over alle projecten heen?
4. **Week Report-PDF/CSV in deze app:** hoort een Week Report-scherm bij de exportopdracht, of alleen de gedeelde CSV-formule?
5. **Microsoft-onderdelen:** de flow en de bibliotheek Exports maak jij aan in Power Automate/SharePoint. Graag daarna de bibliotheek-URL en de flownaam doorgeven, zodat de app aan dat contract wordt gekoppeld.

Bekende technische aandachtspunten (nog niet onderzocht of gecontroleerd):
- Grootte van de flowinvoer bij een lange periode.
- Of Convert file HTML naar PDF in de gebruikte connector ondersteunt; online te bevestigen.
- Delegatie/500-grens: de export gebruikt de al geladen rapportgegevens, geen nieuwe query per regel.

## Batch-opslag Save week / Save team + Concurrent stamgegevens - 22 oktober 2026

Status: **geïmplementeerd en lokaal technisch gecontroleerd.** Niet in Studio geïmporteerd, App checker niet uitgevoerd, niet functioneel getest, geen tijd gemeten. Er zijn geen SharePoint-records gelezen of gewijzigd.
- Checkpoint vóór de wijziging: checkpoints\save-batch-20261021_222721 (YAML, AGENTS.md, PROJECT_STATUS.md, Test-SaveRegression.ps1).

**Oorzaak van de trage opslag (uit de code):** Save week deed per gewijzigde cel achter elkaar:
- LookUp(Hours) en LookUp(Workers)
- 4× Choices() bij een nieuwe regel
- Patch
- na afloop Refresh en een LookUp per geschreven ID

Dat zijn ongeveer 6–8 aanvragen per cel.

**Wijzigingen**
- **Save week (btnSaveWeek.OnSelect)**
  - De guard in DisplayMode en de eerste OnSelect-voorwaarde, de blokkeringsmelding en alle bestaande validatieregels/-meldingen zijn byte-gelijk.
  - De opbouw van colHoursChanges is ongewijzigd (lokaal).
  - Pre-read: Refresh(Hours) en daarna één `Filter(Hours, StartsWith(EntryKey,"<projectID>|") && 'Work Date' in de geladen week)` naar colSaveCheckRaw. Bij ≥500 volgen 7 dagbatches; een volle dag blokkeert opslaan.
  - Lokale controle per wijziging: koppeling/datum, opgeslagen uren = OldHours, team, en Assignment/Employer/Team/Trade bij een nieuwe regel. Iedere fout betekent **nul writes**.
  - Nieuwe controles (fail-closed, met eigen nieuwe meldingen):
    - dubbele HourID in de pre-read
    - meer dan één regel met dezelfde EntryKey
  - Het schrijfplan wordt lokaal opgebouwd, zonder Choices() en zonder remote LookUp:
    - Assignment `{Id, Value: Title}` uit colWeekAssignments
    - Employer `{Id, Value}` uit colWorkersCache
    - Team/Trade als `{Value}`
  - Patch in tabelvorm (Microsoft-documentatie: `Patch(DataSource, BaseRecordsTable, ChangeRecordTable)`, één-op-één, retourneert een tabel):
    - **Afwijking van de opdracht:** het zijn hooguit **2** table-Patches in plaats van 1. Bestaande regels krijgen alleen Title + Hours; nieuwe regels een volledig record.
    - Reden: een changetabel heeft één schema. Een gezamenlijke tabel zou bij bestaande regels Employer/Team/Trade leeg meesturen en daarmee historische werkgevers overschrijven.
    - Het retouraantal moet per Patch gelijk zijn aan het aantal regels en ieder ID moet gevuld zijn. Anders volgt het bestaande foutpad. Nieuwe regels worden pas geschreven als de update foutloos was.
  - Verify: Refresh(Hours) en één read met hetzelfde filter (met dezelfde dagterugval). Daarna een lokale vergelijking op EntryKey, koppeling, datum en uren, en UpdateIf colWeekOriginal alleen voor geverifieerde regels.
  - Ongewijzigd: de eindmelding, Failed/blokkeren, het behouden van invoer en geen automatisch ongedaanmaken.
  - Trace `DIAG|SaveWeek|End` registreert ElapsedMs, Changes, Reads, Writes, PatchedRows, VerifiedRows en Errors.
  - Verwacht aantal aanvragen bij een normale week (<500 regels): 2 reads en 1–2 Patch-aanroepen, ongeacht het aantal cellen. Hoeveel HTTP-requests de connector per table-Patch werkelijk doet, is **niet gemeten**.
- **Save team (btnAddtoTeam.OnSelect)**
  - De guard en de expliciete verwijderingsfilter zijn byte-gelijk.
  - Pre-read: Refresh('Project Workers') en één `Filter('Project Workers', StartsWith(AssignmentKey, "<projectID>|"))`, inclusief inactieve koppelingen. Dit filter heb je gekozen in plaats van ProjectKey, met dezelfde matchsemantiek als de vroegere LookUp, zodat er geen duplicaten ontstaan bij een lege ProjectKey.
  - Het blokkeert op:
    - 500 of meer koppelingen
    - een koppeling naar een ander Project.Id
    - een dubbele AssignmentKey
  - Verwijderingen worden gecontroleerd **vóór** de eerste write. Voorheen gebeurde dat pas na het upserten.
  - Daarna hooguit 2 table-Patches (upsert, deactivering), met dezelfde velden als voorheen.
  - Kleine gedragswijziging: een te verwijderen koppeling waarvan de AssignmentKey intussen naar een ander project wijst, geeft nu "niet meer beschikbaar" in plaats van "ander project of team".
- **btnReadTeam**
  - Projects, Choices('Project Workers'.Team) en Workers worden geladen in `Concurrent`, naar de bestaande pending-collections.
  - Iedere tak heeft zijn eigen foutcollection (colProjectsLoadErrors, colTeamChoicesLoadErrors, colWorkersLoadErrors) met dezelfde meldingen. Deze worden na Concurrent samengevoegd in colSelectionLoadErrors.
  - De rest van de loader is ongewijzigd.
- AGENTS.md heeft een nieuwe sectie "Opslaan in batch".

**Lokaal gecontroleerd**
- Metadata (artifacts\DataSources.review.json):
  - Hours.Assignment is een lookup met Value = `Assignment/Title`.
  - Employer is een lookup met `Employer/Title`.
  - Team en Trade zijn keuzekolommen (`IsChoice`), ook in Workers (field_6).
- Test-SaveRegression.ps1 (uitgebreid): alles PASS.
  - 1469 formules zonder syntaxfouten.
  - Guards, blokkeringsmelding en alle overige knopeigenschappen zijn byte-gelijk aan het checkpoint.
  - Alle validatie- en eindmeldingen zijn aanwezig.
  - Geen Choices()/remote LookUp. Precies 4 Hours-filterplaatsen (pre, dag, verify, dag) en precies 2 Patch-aanroepen per Save.
  - Bestaande regels alleen Title+Hours.
  - Validatie vóór de eerste Patch; baseline pas na de verify.
  - DIAG-trace aanwezig.
  - Power Fx-evaluatie van de letterlijke bronpredicaten: andere koppeling/datum en gewijzigde of verwijderde uren blokkeren; een nieuwe cel en ongewijzigde uren zijn toegestaan.
  - Concurrent-takken schrijven alleen hun eigen foutcollection.
- Test-WeeklyCalculations en Test-FooterRow -GeometryOnly: geslaagd.
- Test-PerformanceFix faalt nu (verwacht) op zijn eigen diff-assert "Save week byte-gelijk" tegen het performance-fix-checkpoint; dit script is daarmee historisch. Een tijdelijke kopie zonder alleen die twee Save-diffregels: alle loader-, cache-, 500- en prefixasserts PASS.
- Test-Performance, -ReadExisting, -SummaryDates, -SummaryLabels, -SummaryStyle, -SummaryFields, -OpenSans, -NavigationLayout en Test-FooterRow (diff-modus) faalden al vóór deze opdracht met dezelfde meldingen, gecontroleerd tegen de checkpointbron. Ze zijn historisch.
- PAC-pack (CLI 2.11.2, SourceCode) is geslaagd vanuit een schone kopie, omdat "Unconfirmed 391983.crdownload" nog in Src staat.
  - De vijf YAML-bestanden in de build zijn gelijk aan Src.
  - Properties/DataSources/Templates/Resources/Themes zijn gelijk aan .msapr.
  - Site https://geacloud.sharepoint.com/sites/GEASiteManagment met de oorspronkelijke lijst-ID's.

**Nieuwe aparte testbuild** (apart importeren; Save schrijft naar de bestaande productielijsten):
artifacts\save-batch-20261022_091955\SiteManagement_SaveBatch_20261022_091955.msapp
- Grootte 99908 bytes; SHA-256 DEB030170358892B835A1E9159C9BE1CA7205E634476C18FF212F45A5A628BD6.
- Log: pac-pack.txt, package-checks.txt.

**Risico's die alleen Studio/online kan beslissen**
1. **Table-Patch met basisrecords uit een collection** (colSaveCheckRaw/colTeamSaveCheck), en een If(Defaults(), collectionrecord) in de upserttabel van Save team. Verwacht: Studio accepteert dit als records van dezelfde bron. Meldt Studio een type- of "record niet gevonden"-fout, geef dan de exacte melding door.
2. **Lookup-/keuzerecords zonder Choices():**
   - Trade/Team worden niet meer vooraf gecontroleerd tegen de Hours-keuzes. Een waarde die niet in de Hours.Trade-keuzes voorkomt, zou SharePoint kunnen weigeren (foutpad) of, bij invulkeuzes, accepteren.
   - Controleer eenmalig dat de Trade-keuzes in Workers en Hours gelijk zijn (F/W).
3. **Employer komt uit colWorkersCache** (sessiecache) in plaats van live uit Workers. Een werkgeverswijziging van een andere gebruiker wordt pas meegenomen na Refresh op Project / team.
4. **Concurrent:** Studio meldt een fout als takken van elkaar afhangen. Dat is hier niet zo verwacht, maar het is niet gecontroleerd.
5. De pre-read/verify read worden niet meer per regel gedaan. Of de connector ze werkelijk als één request met `$filter` uitvoert, blijkt alleen uit Monitor.

**Testen door jou (testproject, Monitor aan)**
1. Importeer de build en open App checker. Geef type-/delegatiemeldingen op btnSaveWeek, btnAddtoTeam en btnReadTeam exact door.
2. Weekly Hours, bestaande uren: wijzig 2 cellen en kies Save. Verwacht:
   - succesmelding
   - Trace `DIAG|SaveWeek|End` met Reads=2, Writes=1
   - in SharePoint is alleen Hours/Modified gewijzigd en Employer gelijk gebleven
3. Lege week of nieuwe cellen: vul 2 cellen in en kies Save. Verwacht:
   - Writes=1 (alleen nieuw), of 2 bij een mix met bestaande regels
   - nieuwe regels hebben Assignment, Employer, Team, Trade en EntryKey gevuld
4. Conflict: open dezelfde week in twee tabbladen, sla in tab A op en daarna in tab B een andere waarde voor dezelfde cel. Verwacht in B "Deze uren zijn sinds het laden gewijzigd…" en **geen** enkele write (controleer Modified).
5. Save team:
   - Voeg één medewerker toe en sla op.
   - Haal één medewerker weg (checkbox) en sla op.
   - Verwacht: 1 Project Workers-read met `startswith(AssignmentKey,…)` en daarna Patch.
6. Project / team → Refresh: in Monitor starten de drie stamgegevensrequests gelijktijdig.
7. Noteer ElapsedMs uit de DIAG-traces van oud (vorige build) en nieuw bij hetzelfde aantal cellen.

## Herstel regressies na performancewijziging - 21 oktober 2026

Status: **geïmplementeerd en lokaal technisch gecontroleerd. Niet in Studio geïmporteerd, App checker niet uitgevoerd, niet functioneel getest.** Checkpoint vóór dit herstel: checkpoints\regression-fix-20261021_195413. Er zijn geen SharePoint-records gelezen of gewijzigd.

1. **Delegatiewaarschuwing in het Project Workers-filter**
   - Oorzaak: in de vorige stap heb ik `|| StartsWith(AssignmentKey, key & "|")` toegevoegd als vangnet voor koppelingen met een lege of afwijkende ProjectKey. Studio meldt daarop een delegatiewaarschuwing, zodat het hele filter niet als volledig gedelegeerd kan gelden.
   - Metadata: ProjectKey en AssignmentKey zijn gewone tekstkolommen (string, lees/schrijf, eq/startswith).
   - Volledigheid: Save team schrijft bij iedere koppeling `ProjectKey = Text(project-ID)` en `AssignmentKey = project|worker`. Of alle bestaande records gevuld zijn, kan ik lokaal niet zien.
   - Correctie: alle drie de laders gebruiken nu uitsluitend `ProjectKey = <vooraf berekende tekst>`. Screen1 en Weekly Hours voegen daar `Team.Value` en `Active = true` aan toe, Hours Summary laadt alle koppelingen (inclusief historie). Er is geen OR- of StartsWith-fallback meer.
   - Behouden: de lokale controle op Project.Id, de 500-grens en de sleutelcontrole (alleen-lezen bij een afwijkende AssignmentKey).
   - Hours blijft op `StartsWith(EntryKey, projectPrefix)` + Work Date. Meldt Studio ook daar een waarschuwing, geef dan de exacte regel door.

2. **Medewerkersschema**
   - Oorzaak (meest waarschijnlijk, alleen lokaal afgeleid): de caches werden gevuld met `ShowColumns(Workers, …)` en `ShowColumns(Sort(Projects, …), …)` op een SharePoint-bron. De collection kreeg daardoor de interne kolomnamen (`field_2` First Name, `field_3` Surname, `field_5` Employer Name; bij projecten `ProjectName` en `ProjectReference`) in plaats van de weergavenamen. Daarom faalden `ThisItem.'First Name'`, `ThisItem.'Employer Name'` en Save team (`person.'First Name'`). Dezelfde fout zou de projectregel ('Project Number') hebben geraakt.
   - Correctie: één expliciet schema via een ForAll-recordprojectie, identiek op Screen1 en in Hours Summary.
     - Medewerkers: `{ID, 'First Name', Surname, 'Employer Name', Employer (lookup Id/Value), Trade}`.
     - Projecten: `{ID, Title, 'Project Number', 'Project Reference'}`, gesorteerd op Title.
   - Werkgevernaam ('Employer Name') en werkgever-ID (Employer.Id) blijven gescheiden.
   - Keten gecontroleerd: Workers → colPendingWorkers → colWorkersCache → Gallery1.Items → Checkbox Collect(ThisItem) / laadactie → colSelectedWorkers, colTeamOriginalSelection, colTeamSelectionToSave → Save team (ID, 'First Name', Surname).
     - Alle records komen uit dezelfde cache, dus geen incompatibele Collect-structuren.
     - Hours Summary gebruikt ID, 'First Name', Surname en Employer.Id/Value. De projectregel gebruikt 'Project Number' en 'Project Reference'.
   - AssignmentKey- en EntryKey-opbouw en de Save-guards zijn ongewijzigd. Bij een mislukte of onvolledige load blijft opslaan geblokkeerd.
   - Er is geen remote LookUp per galerijrij toegevoegd.

Lokaal gecontroleerd:
- Test-PerformanceFix.ps1 (bijgewerkt), alles PASS:
  - Geen ShowColumns op Workers/Projects.
  - Assignment-filters zijn het kale ProjectKey-filter, zonder OR/StartsWith.
  - Synthetische keten: Save team-titel "Jan de Vries | P1" uit de cache, werkgevernaam/-ID gescheiden, selectie op worker-ID, projectcache op Title met Number/Reference.
- Test-SaveRegression (1469 formules zonder syntaxfouten, Save-asserties), Test-WeeklyCalculations en Test-FooterRow -GeometryOnly: geslaagd.
- Pack geslaagd vanuit een schone kopie. YAML is gelijk aan Src; Properties/DataSources/Templates zijn gelijk aan .msapr; dezelfde site en lijst-ID's.
- Niet lokaal te controleren: naam-, type- en delegatiecontrole van Studio/App checker. De parser controleert alleen syntaxis.

Nieuwe aparte testbuild:
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\regression-fix-20261021_195537\SiteManagement_RegressionFix_20261021_195537.msapp
Grootte 99301 bytes; SHA-256 6F98BE650B54EB29A91D1193D0867F0A4FB8BB62148BFD7CFD101DDE8AB50581. Vervangt de build performance-fix-20261021_185604.

Openstaande controles door jou:
1. **SharePoint (alleen lezen):** maak in Project Workers een weergave met het filter "ProjectKey is leeg" (en daarnaast AssignmentKey leeg). Verwacht 0 items. Vergelijk bij enkele records ProjectKey met het project-ID.
   - Zijn er lege of afwijkende waarden, stuur dan het aantal en de ID's. Ik stel dan een gecontroleerde aanvulling voor (per record ProjectKey = Text(Project-ID), met vooraf een export of controle van de versiegeschiedenis). Niets automatisch.
   - Tot dan zijn zulke koppelingen onzichtbaar in de app.
2. **Studio:** importeer de build en open App checker. Verwacht geen naamfouten op 'First Name', Surname, 'Employer Name' of 'Project Number' en geen delegatiewaarschuwing op de Project Workers-filters. Geef de exacte melding door als die er wel is.
3. **Functioneel (testproject):**
   - Medewerkerskaarten tonen naam en werkgever.
   - Selecteren en deselecteren werkt.
   - Save team met één bewuste wijziging slaagt en herlaadt.
   - Hours Summary toont de projectregel en de juiste namen.
4. **Monitor:** de Project Workers-request bevat `$filter` met ProjectKey (en Team/Active); verder gelden dezelfde meetpunten als hieronder.

## Performanceherstel laden (fase 2) - 21 oktober 2026

Status: **geïmplementeerd en lokaal technisch gecontroleerd. Niet functioneel getest, niet in Studio geïmporteerd en niet gemeten.** Er is geen snelheidswinst geclaimd; die volgt pas uit jouw nieuwe Monitor-opname. Basis: de Monitor-bevindingen uit ChatGPT (A t/m D) en de actuele bron (gelijk aan de labelbuild summary-labels-20261021_105544). Checkpoint vóór de wijziging: checkpoints\performance-fix-20261021_184940.

Bevestigd in de lokale metadata (artifacts\DataSources.review.json): `Project#Id`, `Worker#Id` en `Assignment#Id` hebben geen filterfuncties, wat het ontbreken van `$filter` in Monitor verklaart. `ProjectKey`, `AssignmentKey` en `EntryKey` (tekst) ondersteunen eq/startswith. `Work Date` (alleen datum) ondersteunt ge/lt. Sleutels in bron en opslag: AssignmentKey = `<projectID>|<workerID>`, EntryKey = `<AssignmentKey>|yyyymmdd`. Projectprefix `<projectID>|` met afsluitend scheidingsteken: project 1 matcht dus niet 10 of 11.

Wijzigingen:
- **A. Medewerkerscache.** Eén gedeelde `colWorkersCache` = `ShowColumns(Workers, ID, 'First Name', Surname, 'Employer Name', Employer, Trade)`. Eén aanvraag, geladen met de stamgegevens op Screen1 of, indien nog niet aanwezig, in Hours Summary. Bij ≥500 rijen wordt laden gestopt. De koppelingen op Screen1 en de rapportmedewerkers gebruiken `LookUp(colWorkersCache, …)` in plaats van een SharePoint-LookUp per medewerker. Gallery1 toont de cache in plaats van rechtstreeks Workers. `First(Workers)` is vervallen.
- **Projectcache.** `colProjectsCache` (ID, Title, 'Project Number', 'Project Reference') wordt één keer geladen. Screen1 (`colSelectionProjects`) en Hours Summary (`colReportProjects`) gebruiken deze cache. De projectregel in de titelbalk zoekt lokaal in `colReportProjects`; de volgorde Number vóór Reference is ongewijzigd.
- **B. Projectkoppelingen** (alle drie de laders): `Filter('Project Workers', (ProjectKey = "<id>" || StartsWith(AssignmentKey, "<id>|")) [&& Team.Value = team && Active = true])`. Daarna volgt een lokale controle `Project.Id = project`; bij afwijking wordt laden gestopt en opslaan geblokkeerd. Hours Summary leest zoals voorheen ook inactieve, historische koppelingen. De sleutelcontrole (alleen-lezen bij afwijkende sleutels) blijft bestaan.
- **C. Uren.**
  - Weekly Hours: één aanvraag `StartsWith(EntryKey, "<id>|") && 'Work Date' >= maandag && < maandag+7`. Daarna wordt lokaal op de koppelingen van het team gefilterd. Bij ≥500 rijen volgen 7 dagaanvragen; een volle dag blokkeert.
  - Hours Summary: één aanvraag op de projectprefix. Bij ≥500 rijen volgen de eerste/laatste werkdatum en aanvragen per maand; een volle maand wordt per dag gelezen en een volle dag blokkeert het hele rapport.
  - Nieuwe controles: dubbele HourID, uren zonder datum/werkgever/waarde, en een urenregel waarvan de koppeling niet bij het project hoort (blokkeert). Weekly Hours markeert een EntryKey die afwijkt van `AssignmentKey|yyyymmdd` als sleutelprobleem; opslaan wordt dan geblokkeerd.
  - De historische werkgever komt zoals voorheen uit Hours.Employer.
- **D. Navigatie.**
  - Screen1.OnVisible en btnReadTeam slaan het laden over bij een volledig geladen (Loaded, foutloze) selectie voor hetzelfde project/team.
  - btnReadWeek slaat het laden over bij dezelfde project/team/ISO-jaar/KW en dezelfde teamversie. De controle op onopgeslagen invoer blijft als eerste staan.
  - Hours Summary hergebruikte zijn rapport al. De stamgegevens laden daar nu niet meer opnieuw.
  - Dubbele aanroepen via OnChange/Reset/Select worden daardoor no-ops.
  - Het jaarbereik van Weekly Hours (twee sorteeraanvragen) wordt één keer per sessie geladen.
- **Refresh tegenover navigeren.** De Refresh-knoppen zetten een force-vlag (`varForceTeamRefresh`, `varWeekForceRefresh`, `varReportForceRefresh`) en lezen opnieuw van SharePoint, inclusief stamgegevens en jaarbereik.
- **Caches na opslaan.**
  - Iedere geslaagde teamload verhoogt `varTeamDataVersion`, zodat Weekly Hours na een teamwijziging opnieuw laadt.
  - Save team zet geen force-vlag meer. Na het opslaan worden alleen de koppelingen opnieuw gelezen (`Refresh('Project Workers')` gebeurt nu bij iedere echte teamload), niet projecten/medewerkers/teamkeuzes.
  - Save week blijft byte-gelijk en werkt zijn baseline al per geverifieerde cel bij.
  - Beide saves maken het rapport zoals voorheen ongeldig.
- **Trace.** 17 `DIAG|…`-markeringen met ElapsedMs, aantallen en `CacheHit`/`Forced`/`Paged` in de laders en in OnVisible, plus navigatiemarkeringen. Dezelfde scenarionamen als in de diagnostische build.
- **Ongewijzigd:** beide Save-guards (DisplayMode en OnSelect), Save week, layout, kleuren, labels, datumselectie, rapportberekening (Build alleen Trace/timer) en de verbindingen.

Daadwerkelijk lokaal gecontroleerd:
- Nieuw: artifacts\Test-PerformanceFix.ps1, met allemaal PASS:
  - Diff tegen het checkpoint: alleen de genoemde eigenschappen zijn gewijzigd. Save week is byte-gelijk. Save team verschilt alleen in de verwijderde force-vlag. Build verschilt alleen in Trace/timer.
  - Geen remote LookUp, `First(Workers)`, `Project.Id`-filter of `Assignment.Id`-filter in de laders; alle Hours-filters beginnen met de EntryKey-prefix.
  - De 500-grenzen en kruiscontroles zijn aanwezig. Screen1 en Hours Summary gebruiken dezelfde cachevorm. Cache-hitvoorwaarden en force-vlaggen zijn aanwezig. De laders bevatten geen Patch/Update/Remove.
  - Synthetische Power Fx-tests: prefix 1 versus 10/11; totaal oud (per Assignment.Id, inclusief inactief) = nieuw (prefix) = 19,5; een week-venster; blokkade bij een projectsleutel op een koppeling van een ander project; maandvensters over de jaarwisseling en een schrikkelfebruari; de EntryKey-kruiscontrole.
- Test-SaveRegression (1469 formules zonder syntaxfouten, alle Save-asserties), Test-WeeklyCalculations en Test-FooterRow -GeometryOnly: geslaagd.
- Test-SummaryDates, -SummaryLabels, -SummaryStyle en -OpenSans melden "Unexpected change". Dat is verwacht: ze vergelijken met hun eigen oudere checkpoint en staan alleen hun eigen wijziging toe. Ze zijn historisch voor deze opdracht.
- PAC-pack geslaagd, vanuit een schone kopie (alleen *.pa.yaml + .msapr) vanwege het .crdownload-bestand in Src. De vijf YAML-bestanden zijn gelijk aan Src; Properties/DataSources/Templates zijn gelijk aan .msapr. Alle vijf lijsten verwijzen naar https://geacloud.sharepoint.com/sites/GEASiteManagment met de oorspronkelijke lijst-ID's. Logs naast de build.

Nieuwe aparte testbuild (apart importeren; Save schrijft naar de bestaande productielijsten):
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\performance-fix-20261021_185604\SiteManagement_PerformanceFix_20261021_185604.msapp
Grootte 99236 bytes; SHA-256 7647F4277ECAED3354A76247E682A9B2B394B481C7B5D551C763114B1D1EA435.

Risico's en beperkingen (online te controleren):
- **Delegatie** van `Team.Value = …` (keuzekolom), `Active = true` en `StartsWith` met `||` is volgens Microsoft-documentatie en metadata ondersteund, maar alleen Monitor bewijst de werkelijke `$filter`. Ziet u bij Project Workers of Hours nog `$top=500` zonder `$filter`, dan geldt de load als niet bewezen volledig.
- **Gegevens met ontbrekende of afwijkende sleutels worden niet meer opgehaald.** Het gaat om uren zonder juiste EntryKey-prefix en koppelingen waarvan zowel ProjectKey als AssignmentKey niet kloppen. De oude Assignment.Id-/Project.Id-filters lazen ze wel, maar haalden door het ontbrekende `$filter` alleen de eerste 500 records van de hele lijst. De app schrijft deze sleutels zelf altijd. Controleer eenmalig in SharePoint dat er geen Hours-regels zijn met een lege EntryKey en geen Project Workers met een lege ProjectKey/AssignmentKey. Zijn die er wel, meld het dan; niets automatisch repareren.
- **Grote projecten.** Paginering per maand/dag gebruikt een gesorteerde top-1-query op `Work Date`, net als het jaarbereik van Weekly Hours. Bij meer dan 5000 Hours-items is een SharePoint-index op Work Date (en eventueel EntryKey) nodig. Bij ≥500 medewerkers of projecten blokkeert de app zoals de andere 500-grenzen.
- **Cachewerking.** Wijzigingen van andere gebruikers zijn zichtbaar na Refresh, na een andere project/team/week-keuze of na opslaan, niet bij terugnavigeren. Volgens AGENTS.md vereist het hergebruik van geladen selecties een afzonderlijke Studio-binding-, fout- en functionele test.
- Studio-import (inclusief de nog openstaande ModernDatePicker-bevestiging) en App checker zijn niet uitgevoerd.

Online meting door jou (Monitor aan, niets opslaan):
1. Open de testapp → Project/team (kies project + team) → Weekly Hours → Project/team → Hours Summary → Project/team.
2. Controlepunten:
   - Geen getRows `Workers` met `$filter=ID eq …` per medewerker.
   - Project Workers-requests met een `$filter` op ProjectKey/AssignmentKey (en Team/Active).
   - Hours-requests met `startswith(EntryKey,'<id>|')` en, bij Weekly Hours, een Work Date-bereik.
   - Terug naar Project/team: Trace `DIAG|Screen1|OnVisible` met CacheValid=true en geen getRows.
   - Terug naar Weekly Hours met dezelfde week: `DIAG|Week|CacheHit` en geen getRows.
3. Totalen: vergelijk het Period total en enkele weekcellen met de vorige build (zelfde project, contractor en periode).
4. Daarna eenmalig Refresh op elk scherm: hier moeten de requests wél verschijnen.

## Performanceonderzoek fase 1: diagnostische build - 21 oktober 2026

Status: diagnostische build gemaakt en lokaal gecontroleerd. **Nog niets gemeten**; geen online uitvoering, tijden of aanvraagaantallen beschikbaar. Rapport met codebevindingen, vermoedens, optievergelijking en aanbeveling: artifacts/PERFORMANCE_ONDERZOEK.md.

Gemaakt:
- artifacts/Make-DiagnosticBuild.ps1: kopieert de *.pa.yaml uit Src naar artifacts\diagnostics-20261021_120112\source en voegt 45 Trace-markeringen in (DIAG|scenario|stap, met ElapsedMs, rijaantallen en foutaantallen) plus Set(varDiag…T0,Now())-timers. Src zelf is niet gewijzigd; hoofdbron is gelijk aan build summary-labels-20261021_105544.
- Gecontroleerd door het script: elke anker precies één keer gevonden; het weghalen van de markeringen geeft de originele bron exact terug; markeringen bevatten uitsluitend Trace/timer (geen Patch, Collect, Refresh, Select e.d.); 1469 formules zonder syntaxfouten; de Save-guards staan ongewijzigd vooraan in DisplayMode/OnSelect.
- PAC-pack geslaagd; vijf YAML-bestanden in de build gelijk aan de diagnostische bron; Properties/DataSources/Templates gelijk aan .msapr. Logs: pac-pack.txt, package-checks.txt, diagnostic-checks.txt.

Diagnostische testbuild (apart importeren, niet als productie gebruiken):
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\diagnostics-20261021_120112\SiteManagement_Diagnostics_20261021_120112.msapp
Grootte 98386 bytes; SHA-256 4EC9FAF27E271C7DE0F0823E3139CD623B99F50100CAF284DA41B714D556EBA5.
Bevat dezelfde functionaliteit als de labelbuild (incl. ModernDatePicker; Studio-import daarvan is nog onbevestigd). Save in deze build schrijft naar de productielijsten.

Belangrijkste codebevindingen (niet gemeten): Weekly Hours voert bij iedere weekwissel N+3 aanvragen uit, inclusief twee sorteringen over de hele Hours-lijst alleen voor het jaarbereik; Screen1 vraagt per teamlid een Workers-record op; Hours Summary doet per koppeling 2 + jaren queries plus per medewerker een Workers-LookUp en laadt volledig opnieuw na iedere Save; Save week kost ongeveer 4–6 aanvragen per gewijzigde cel. Risico's: List View Threshold bij sorteren zonder index op 'Work Date' en Choices(Hours.Assignment) bij meer dan 500 koppelingen.

Aanbeveling (zie rapport): eerst meten; daarna optie 1 (minder/gerichtere serveraanvragen en indexen) in kleine, afzonderlijk geteste stappen; Hours Summary daarna op basis van metingen (Project-kolom op Hours of sessiecache, alleen na akkoord); geen persistente browsercache/synchronisatie (SaveData max 1 MB, onversleuteld, niet in Studio, per browser).

Let op: in Src staat een onvoltooide browserdownload "Unconfirmed 391983.crdownload" (3 MB, 21-10-2026 11:54), niet door deze werkzaamheden gemaakt. Niet aangeraakt. PAC weigert of verpakt mogelijk extra bestanden in Src; verplaats of verwijder dit bestand zelf vóór de volgende pack vanuit Src. De diagnostische build kopieert alleen *.pa.yaml en is daardoor niet geraakt.

Volgende stap: diagnostische build importeren, de scenario's in PERFORMANCE_ONDERZOEK.md §2 uitvoeren met Live Monitor (klein en groot project) en de export of schermafbeeldingen terugsturen. Daarna wordt het rapport aangevuld met gemeten waarden.

## Hours Summary: Engelse labels, titelbalk en Period total-accent - 21 oktober 2026

Geïmplementeerd en lokaal technisch gecontroleerd; Studio-import en visuele/online controle NIET uitgevoerd. Alleen Src/scrWeeklyHours.pa.yaml gewijzigd, uitsluitend presentatie en labels. Bouwt voort op de nog niet goedgekeurde datumkiezer-build hieronder.

Wijzigingen:
- Veldlabels exact Project, Contractor, From, Till; alle vier Bold (Open Sans). "Van"/"Tot en met" vervangen door From/Till, ook in de schermlezerlabels van de datumkiezers en in de twee foutmeldingen die de veldnamen noemen ("Selecteer From en Till.", "Till ligt vóór From. ..."). Veldindeling ongewijzigd. Omdat de ISO-regel is vervallen, staan de twee kolommen weer naast elkaar vanaf 888 px schermbreedte; daaronder gestapeld.
- Titelbalk: "Hours Summary" links (vaste 280 px). Rechts daarnaast een eigen blauw label met witte tekst, rechts uitgelijnd, verticaal gecentreerd, 24 px rechtermarge: "Project Number: <waarde> | Project Reference: <waarde>". Dezelfde LookUp op Projects en dezelfde volgorde; alleen het scheidingsteken is "|" met enkele spaties, en zonder project staat er "Select a project.". De titel en de projectregel liggen naast elkaar, dus geen overlap. De oude projectregel onder de selectie is weg.
- Verwijderd: de ISO-perioderegel (lblReportIsoPeriod) en de vrijgekomen ruimte. De statusregel staat direct onder het selectieblok; zonder melding geen ruimte. Op twee kolommen is het selectieblok 152 px hoog (was 180), en de tabel begint ongeveer 68 px hoger (projectregel en ISO-regel weg).
- Period total: kop Bold (blauw/wit). Waarden in de kolom met achtergrond #EEE7F5, zwart, Bold, gecentreerd. Het algemene totaal onder de tabel ("Period total: <waarde> hours") is nu een vak van maximaal 280 px met dezelfde accentkleur, zwart Bold en gecentreerd, rechts uitgelijnd met de Period total-kolom. Berekeningen en getalnotatie ongewijzigd.
- Ongewijzigd: datumselectie en normalisatie, filters, laden en controles, opslagbeveiliging, knoppen en de onderste knoppenrij, Screen1, Weekly Hours en App.

Daadwerkelijk lokaal gecontroleerd:
- Test-SummaryLabels.ps1 t.o.v. checkpoints\summary-labels-20261021_105112: alleen de bovengenoemde eigenschappen gewijzigd; btnBuildReport verschilt alleen in de twee veldnamen in meldingen; de projectregel heeft na terugzetten van scheidingsteken/lege tekst exact dezelfde formule (Number vóór Reference); labels, accentkleuren en Bold gecontroleerd. Geometrie op 320-1920 px: titel en projectregel overlappen niet, de projectregel loopt tot de rechterrand van de balk, en het algemene totaal ligt binnen de marges en vanaf 650 px exact onder de Period total-kolom.
- Test-SummaryDates (diff, normalisatie, selectorlayout op zeven breedtes, nu zonder ISO-regel), Test-WeeklyCalculations (47 asserties), Test-SummaryStyle, Test-OpenSans, Test-FooterRow -GeometryOnly (21 cases) en Test-SaveRegression (1469 formules, Save-guards gelijk) geslaagd. Check-WeeklySource: 477 formules, 34 controls.
- Measure-FontFit met officiële Open Sans Bold: alle nieuwe teksten passen ("Period total: 12345,25 hours" Bold 209 van 270 px; From/Till/Project/Contractor; Period total-waarden; titel 236 van 259 px). Voorbeeld-projectregel (505 px): op één regel vanaf ongeveer 900 px schermbreedte, twee regels bij 768 px; onder ongeveer 690 px drie of meer regels en wordt die afgekapt.
- PAC-pack geslaagd; vijf YAML-bestanden gelijk aan Src; Properties/DataSources/Templates gelijk aan .msapr. Logs naast build.

Beperkingen/open:
- Smal venster: projectregel in de titelbalk kan onder ongeveer 690 px afgekapt worden. De titel "Hours Summary" zelf past niet bij 320 px (al bestaand).
- Studio-import (ModernDatePicker nog steeds open), visuele controle van Bold-labels, titelbalk en accentkleur.

Nieuwe aparte testbuild:
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\summary-labels-20261021_105544\SiteManagement_SummaryLabels_20261021_105544.msapp
Grootte 96680 bytes; SHA-256 20BF57E6CF29928F207FE04BD6B847D9DE687BF9F6631E5B60F70324580C7CBA.
Goedgekeurde baseline blijft footer-row-20261020_215936.

Korte online controle (zonder opslaan):
1. Titelbalk: "Hours Summary" links; rechts in wit "Project Number: … | Project Reference: …" met de juiste waarden van het gekozen project (niet verwisseld). Verklein het venster: geen overlap met de titel.
2. Labels Project, Contractor, From, Till in Bold; geen ISO-perioderegel meer.
3. Period total-kolom lichtpaars met vette zwarte waarden; kop blauw met vette witte tekst; algemeen totaal onder de tabel in hetzelfde lichtpaarse vak, rechts onder de kolom.
4. Datumkeuze, contractor en de datumtests van de vorige build werken ongewijzigd.

## Hours Summary: Van/Tot en met-datumkiezers en compacte selectie - 21 oktober 2026

Geïmplementeerd en lokaal technisch gecontroleerd; Studio-import en online tests NIET uitgevoerd. Alleen Src/scrWeeklyHours.pa.yaml gewijzigd. Bouwt voort op de nog niet goedgekeurde Open Sans-build hieronder.

Wijzigingen:
- Verwijderd: ddReportStartYear, ddReportStartWeek, ddReportEndYear, ddReportEndWeek, hun vier labels, colReportYears, colReportStartWeeks, colReportEndWeeks, varReportDefaultStartYear/EndYear en de >500-controle op jaarkeuzes. Geen verwijzingen meer in Src.
- Nieuw: lblReportFrom/dpReportFrom ("Van"), lblReportUntil/dpReportUntil ("Tot en met") en lblReportIsoPeriod. Datumkiezers: ModernDatePicker@1.0.0 met Format "dd-mm-yyyy", StartOfWeek.Monday, Open Sans Normal 12, zwarte tekst, dezelfde DisplayMode als de vervangen periodedropdowns, en StartDate/EndDate begrensd op de eerste maandag t/m de laatste zondag met uren.
- Normalisatie: Van naar de maandag, Tot en met naar de zondag van de gekozen week (varReportStartMonday/varReportEndSunday). OnChange bouwt het rapport alleen als de weekgrens verandert en zet de kiezer één keer terug op de genormaliseerde datum; de daaropvolgende OnChange bouwt en reset niet. Een andere dag in dezelfde week bouwt niet opnieuw. Tijdens laden wordt OnChange overgeslagen. Geen Load-knop.
- Rapport (btnBuildReport): varReportFrom = Van-maandag, varReportUntil = Tot en met-zondag + 1 dag. Tot en met vóór Van blokkeert met "Tot en met ligt vóór Van. Kies een eindweek die gelijk is aan of later is dan de beginweek."; de kiezer toont ValidationState.Error en de ISO-regel "Tot en met ligt vóór Van.". Weekkolommen, filters, contractorfilter, periodetotalen en de grens van 50000 weken ongewijzigd.
- ISO-regel onder de datumgroep, bijvoorbeeld "ISO 2026 KW52 t/m 2027 KW01 (3 weken)" of "ISO 2026 KW53 (1 week)".
- Laden (btnLoadReport): na volledige foutloze load wordt de standaardperiode de volledige beschikbare urenperiode en worden contractor en beide kiezers gereset. Bij een laadfout worden de datums leeggemaakt. Alle bestaande 500-grenzen, foutpaden, Loaded/Failed-status en het ontbreken van schrijfacties zijn behouden.
- Layout: links Project met daaronder Contractor (beide 512 px, X = 0). Rechts, 24 px ernaast, Van naast Project en Tot en met naast Contractor (beide 256 px), met daaronder de ISO-regel. Twee kolommen vanaf 962 px schermbreedte (rechts minstens 330 px nodig voor de ISO-regel); smaller staan de datumvelden onder Contractor, zonder overlap. Het selectieblok is op twee kolommen 180 px hoog (voorheen vier periodevelden in rijen); gestapeld 332 px, dan scrollt het blok binnen maximaal 220 px.
- Weekly Hours (scrHours), Screen1, App, opslaglogica en footer ongewijzigd.

Daadwerkelijk lokaal gecontroleerd:
- Test-SummaryDates.ps1: diff t.o.v. checkpoints\summary-dates-20261021_004647 (alleen de genoemde controls/eigenschappen), geen verwijzingen naar verwijderde controls/collections, loader-veiligheidscontroles aanwezig en geen schrijfacties, normalisatie komt na één reset tot rust zonder tweede build, layout op 320/480/768/888/1024/1366/1920 px (labels direct boven velden, vaste breedtes, 24 px kolomafstand, uitlijning Van/Project en Tot en met/Contractor, ISO-regel eronder en minstens 330 px, geen overlap, contenthoogte).
- Test-WeeklyCalculations.ps1: 52 asserties, waaronder maandag/zondag-normalisatie (ook 31-12-2026, 03-01-2027, 01-01-2021), weekaantallen (1, 3 en 4 weken, ook over de jaarwisseling), blokkade van eind vóór begin, ISO-regel inclusief 2020 KW53, 2026 KW53 en 2025 KW01, plus de bestaande ISO-, filter- en batchgrenstests.
- Check-WeeklySource: 477 formules zonder syntaxfouten; 35 controls. ModernDatePicker@1.0.0 is gecontroleerd tegen de door Microsoft gedocumenteerde eigenschappenlijst, niet tegen een app-template (die ontbreekt in de oorspronkelijke .msapr).
- Test-SaveRegression (1469 formules, Save-guards gelijk), Test-SummaryStyle, Test-OpenSans (beide met expliciete uitzondering voor de datumwijziging), Test-FooterRow -GeometryOnly (21 cases) en Measure-FontFit (0 nieuwe overlopende teksten; ISO-regel past in 320 px) geslaagd.
- PAC SourceCode-pack geslaagd; vijf YAML-bestanden gelijk aan Src; Properties/DataSources/Templates gelijk aan .msapr. Logs naast build.

Risico's en beperkingen:
- ModernDatePicker staat niet in de oorspronkelijke Templates.json en de app-vlag fluentv9controls staat op false. Studio moet de control bij import herkennen. Mislukt de import of meldt App checker een fout bij dpReportFrom/dpReportUntil, geef dan de exacte melding door. Mogelijk moet in de testapp "Modern controls" bij Instellingen > Updates aan staan.
- Reset- en OnChange-timing van de modern datumkiezer is lokaal niet uitvoerbaar. De normalisatieweergave na het kiezen van een woensdag moet online worden bevestigd.
- Datums buiten de periode met uren zijn niet selecteerbaar (StartDate/EndDate). Zonder uren voor het project zijn beide kiezers uitgeschakeld, zoals de oude periodedropdowns.

Nieuwe of aangepaste scripts: Test-SummaryDates.ps1 (nieuw), summary-dates-backup.txt, Test-WeeklyCalculations.ps1 (periodetests op de nieuwe bron), Check-WeeklySource.ps1 (gedocumenteerde ModernDatePicker-eigenschappen), Test-SummaryStyle.ps1/Test-OpenSans.ps1 (uitzondering voor datumcontrols), Measure-FontFit.ps1 (nieuwe teksten).

Nieuwe aparte testbuild:
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\summary-dates-20261021_005247\SiteManagement_SummaryDates_20261021_005247.msapp
Grootte 96868 bytes; SHA-256 B5E426343163C52EDB11B8AD39E7AA6D85AC9E307D893DF8525067CFA9C0CB34.
Goedgekeurde baseline blijft footer-row-20261020_215936.

Online acceptatietest (zonder opslaan; resultaat graag terugkoppelen):
1. Eén week: kies bij Van en Tot en met dezelfde woensdag. Verwacht: Van = maandag, Tot en met = zondag van die week (dd-mm-jjjj), ISO-regel "... (1 week)", één weekkolom, totalen gelijk aan Weekly Hours van die week.
2. Meerdere weken: Van in week A, Tot en met in week A+2. Verwacht: drie weekkolommen, periodetotaal = som van de weken.
3. Jaarwisseling: zodra er uren rond 28-12-2026 t/m 10-01-2027 zijn, kies Van 21-12-2026 en Tot en met 10-01-2027. Verwacht: "ISO 2026 KW52 t/m 2027 KW01 (3 weken)", met kolom 2026 KW53 waarin 1 t/m 3 januari meetellen. Zolang er geen uren buiten 2026 zijn, is dit alleen lokaal getest.
4. Ongeldige periode: Tot en met een week vóór Van. Verwacht: foutmelding, Tot en met rood gemarkeerd, ISO-regel "Tot en met ligt vóór Van.", geen tabel of totaal.
5. Project en contractor: ander project kiezen (datums worden de volledige urenperiode van dat project), daarna een contractor (datums blijven, totalen alleen voor die contractor).
6. Smal venster: verklein tot onder 962 px. Verwacht: Van/Tot en met onder Contractor, geen overlap, selectieblok scrollbaar, tabel, totaal en onderste knoppenrij zichtbaar.
Controleer daarnaast: wordt na kiezen van een datum maar één keer opnieuw berekend (geen knipperen of herhaald "Uren ophalen...")?

## Appbreed Open Sans (vervangt Montserrat) - 20 oktober 2026

Geïmplementeerd en lokaal technisch gecontroleerd; Studio-/browserweergave NIET getest. Bouwt voort op de nog niet goedgekeurde Hours Summary-opmaakbuild hieronder.

Wijzigingen (Src/Screen1.pa.yaml, Src/scrHours.pa.yaml, Src/scrWeeklyHours.pa.yaml):
- Alle 69 zichtbare controls met een fontinstelling: Font =Font.'Open Sans' (ingebouwd Power Apps-font, dus geen browserafhankelijkheid zoals bij Montserrat). Verborgen btnBuildReport ongewijzigd.
- FontWeight.Semibold: drie schermtitels, kolomkoppen (Weekly Hours: Worker, Mon-Sun, Total; Hours Summary: Name, Contractor, weekkoppen, Period total) en alle elf zichtbare knoppen.
- FontWeight.Normal (expliciet): alle overige labels, statusregels, invoervelden, dropdowns, checkbox en tabelgegevens. Hierdoor van Bold/Semibold naar Normal: Screen1 lblProject en Title4 (medewerkernaam in kaart), Weekly Hours weektotaal per rij, Hours Summary veldlabels Project/Contractor, periodetotaal per medewerker en het eindtotaal.
- Behouden: Subtitle4 (werkgever in medewerkerkaart) houdt het bestaande voorwaardelijke gewicht Semibold bij selectie, omdat dit selectieterugkoppeling is. Alle tekstgroottes, kleuren, teksten, acties, Visible en DisplayMode ongewijzigd.
- Tekstpassing: Open Sans is 3-8% breder dan Segoe UI. Gemeten met de officiële OpenSans-Regular/SemiBold.ttf (googlefonts/opensans, alleen tabellen gelezen, niet geïnstalleerd). Twee knopteksten pasten niet meer: Screen1 "Hours Summary" (150 > 148 px) en Weekly Hours "Project / team" (131 > 128 px). Daarom breder: Screen1 Weekly Hours 160 -> 170 en Hours Summary 180 -> 190; Weekly Hours Project / team 160 -> 180. Hours Summary Refresh terug naar de appbrede 110 (Open Sans past: 71 van 78 px). Rijminima footer: Screen1 746, Weekly Hours 534, Hours Summary 494 px.

Daadwerkelijk lokaal gecontroleerd:
- Test-OpenSans.ps1: 114 eigenschapsverschillen t.o.v. checkpoints\open-sans-20261020_235054, uitsluitend Font, FontWeight en de vier knopbreedtes; gewichtenindeling exact zoals hierboven; App/_EditorState bytegelijk; verborgen controls ongewijzigd.
- Measure-FontFit.ps1: 48 tekstcases (knoppen incl. "Saving...", titels, veldlabels, koppen, statusmeldingen, tabelwaarden, weekkop "2026 KW53") met Open Sans en Segoe UI vergeleken, 3% marge: 0 nieuwe overlopende teksten.
- Al bestaand en niet door Open Sans veroorzaakt (ook met Segoe UI te krap): titel "Hours Summary" bij 320 px schermbreedte; Weekly Hours dagkoppen/invoervelden bij 768 px (kolommen ca. 25 px); Hours Summary weekkop bij 650 px (50-px-cel). Geen telefoonlayout; niet gewijzigd.
- Dynamische namen (medewerker, werkgever, project) zijn niet vooraf meetbaar; labels lopen zoals voorheen om binnen hun bestaande hoogte.
- Test-SaveRegression: 1513 formules zonder parserfouten, 95 controls tegen templates (FontWeight op checkbox/dropdown/tekstinvoer toegestaan), alle Save-asserties geslaagd. Test-WeeklyCalculations: 30 asserties geslaagd. Test-SummaryStyle (cumulatief t.o.v. summary-style-checkpoint) en Test-FooterRow -GeometryOnly (21 cases) geslaagd.
- PAC SourceCode-pack geslaagd; vijf YAML-bestanden gelijk aan Src; Properties/DataSources/Templates gelijk aan .msapr. Logs naast build: pac-pack.txt, package-checks.txt, open-sans-checks.txt, font-fit.txt, summary-style-checks.txt, footer-checks.txt, calculations.txt.

Nieuwe of aangepaste scripts: artifacts/Apply-OpenSans.ps1 (eenmalig, niet opnieuw uitvoeren), Test-OpenSans.ps1, Measure-FontFit.ps1 (fontmap als parameter), open-sans-backup.txt; Test-SummaryStyle.ps1 verwacht nu Open Sans.

Openstaand (vereist jouw terugkoppeling): Studio-import/App checker; visuele controle van Open Sans en Semibold/Normal op alle drie schermen; volledige knopteksten in de onderste balk; daarnaast de nog openstaande Hours Summary-opmaakpunten hieronder (blauwe kop, rijkleuren, zwarte tekst, statusregel).

Nieuwe aparte testbuild:
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\open-sans-20261020_235254\SiteManagement_OpenSans_20261020_235254.msapp
Grootte 96660 bytes; SHA-256 2F453DFC778149E414ACA3E517D3FFDD632926D84D827D50DDF961E072CECB34.
Goedgekeurde baseline blijft footer-row-20261020_215936 tot deze build is goedgekeurd.

## Hours Summary-opmaak: tekst, Montserrat, tabelkop en rijen - 20 oktober 2026

Let op: het Montserrat-deel hieronder is vervangen door appbreed Open Sans (sectie hierboven); de overige opmaakwijzigingen gelden nog.

Geïmplementeerd en lokaal technisch gecontroleerd; Studio-/browserweergave NIET getest. Alleen Src/scrWeeklyHours.pa.yaml gewijzigd; geen laad-, opslag-, filter- of berekeningslogica gewijzigd.

Wijzigingen:
- lblSummaryPurpose (toelichtingstekst) verwijderd; conSummarySelectors begint 12 px onder de titelbalk (Y 116 -> 92).
- Statistiekregel verborgen via uitsluitend lblReportStatus.Text: laden, laad-/rapportfouten (varReportMessage bij ongeldig rapport) en "Geen opgeslagen uren voor dit project; actieve medewerkers staan op 0." blijven; bij een geldig rapport verder geen tekst. Lege statusregel heeft hoogte 0 en geen 8 px marge. btnBuildReport/btnLoadReport en varReportMessage zijn ongewijzigd. Periodetotaal blijft.
- Font ="Montserrat, 'Segoe UI', sans-serif" op alle zichtbare controls, inclusief titel, dropdowns en de vier footerknoppen. Verborgen btnBuildReport behoudt Segoe UI.
- Alle gewone labels, dropdowntekst, rijgegevens en totaal #000000 (was grijs RGBA(35,45,60)/RGBA(85,100,120)). Wit op titel, kop en knoppen behouden.
- Tabelkop: galReportWeekHeaders kreeg blauwe Fill, zodat de balk van Name t/m Period total doorloopt, ook achter ontbrekende weekcellen. Alle koppen Semibold en VerticalAlign.Middle; weekkoppen padding links/rechts 0 voor tekstruimte. Posities/breedtes ongewijzigd.
- Rijen: galReportRows.Items voegt alleen RowNumber toe (zelfde rijen, velden en sortering op WorkerName); TemplateFill wisselt #FFFFFF/#E8EDF5 op rijpositie (voorheen op worker-ID, waardoor twee even ID's na elkaar dezelfde kleur kregen). galReportWorkerWeeks expliciet transparant, zodat de rijkleur over de volle breedte doorloopt.
- Footerknoppen breder vanwege het bredere Montserrat: Project / team 160 -> 180, Refresh 110 -> 120. Kleuren, acties, Y/hoogte, Visible en DisplayMode ongewijzigd. Minimale rijbreedte Hours Summary 474 -> 504 px.

Montserrat-beperking (gemeld, niet stil vervangen): Montserrat staat niet in de ingebouwde Font-lijst van Power Apps (Arial, Courier New, Dancing Script, Georgia, Great Vibes, Lato-varianten, Open Sans-varianten, Patrick Hand, Segoe UI, Verdana). Een fontnaam als tekst wordt doorgegeven aan de browser. Montserrat verschijnt alleen als het op het apparaat/in de browser beschikbaar is; anders gebruikt de browser de expliciet opgegeven terugval Segoe UI. Power Apps laadt geen eigen webfont voor canvas-controls. Controleer in de browser of Montserrat echt zichtbaar is; zo niet, beslis tussen Segoe UI houden of een ingebouwd font (bijv. Lato/Open Sans).

Gewijzigde bestanden: Src/scrWeeklyHours.pa.yaml; AGENTS.md (opmaakafspraak Hours Summary, Montserrat-uitzondering, rijminimum 504, footertest -GeometryOnly); dit bestand; artifacts/latest-functional-test.json; nieuw artifacts/Test-SummaryStyle.ps1 en summary-style-backup.txt; artifacts/Test-FooterRow.ps1 (schakelaar -GeometryOnly, titel meten, statustekst in Self-context). Checkpoint vooraf: checkpoints\summary-style-20261020_233759.

Daadwerkelijk lokaal gecontroleerd:
- Test-SummaryStyle.ps1: 66 eigenschapsverschillen, uitsluitend de bovengenoemde; alleen lblSummaryPurpose verwijderd, geen nieuwe controls. Screen1, scrHours, App en _EditorState bytegelijk. Alle OnSelect/OnChange/Default/loaders/filters/Visible/DisplayMode en knopkleuren gelijk. Alle zichtbare controls Montserrat; geen grijze tekst.
- Statustekst lokaal geëvalueerd: laden, laadfout, rapportfout, geldig rapport (statistiek weg), project zonder uren (melding blijft) en geen project. Rijnummering behoudt sortering, aantallen, totalen en WorkerEntries; rijkleuren wisselen FFFFFF/E8EDF5.
- Kop/rijen numeriek bij 320, 480, 600, 650, 768, 1024, 1366 en 1920 px met 1, 3, maximaal en meer dan maximaal zichtbare weken: vanaf 650 px blauwe kop ononderbroken 40..breedte-40, rijcellen exact onder kopcellen, weekcellen binnen de blauwe gallery. Onder 650 px past geen weekkolom (bestaande beperking; geen telefoonlayout).
- Test-FooterRow.ps1 -GeometryOnly: 21 cases op drie schermen geslaagd; Hours Summary-rij 504 px.
- Test-SaveRegression.ps1: 1479 formules zonder parserfouten, 95 controls, alle Save-asserties geslaagd. Test-WeeklyCalculations.ps1: rekenasserties geslaagd.
- PAC SourceCode-pack geslaagd; alle vijf gepakte YAML-bestanden gelijk aan Src; Properties/DataSources/Templates gelijk aan .msapr. Logs naast build: pac-pack.txt, package-checks.txt, summary-style-checks.txt, footer-checks.txt, calculations.txt.

Openstaand (vereist jouw terugkoppeling):
- Studio-import en App checker (o.a. Gallery Fill, fonttekst, RowNumber-Items).
- Wordt Montserrat werkelijk getoond? Tekstpassing in koppen ("2026 KW53"), knoppen en dropdowns.
- Ononderbroken blauwe kop bij weinig en veel weken, rijkleuren, zwarte tekst, gecentreerde uren, geen statistiekregel, foutmeldingen nog zichtbaar, scrollen.

Nieuwe aparte testbuild:
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\summary-style-20261020_234303\SiteManagement_SummaryStyle_20261020_234303.msapp
Grootte 96635 bytes; SHA-256 350E0AFB99435463D951C0E9487E349C0C5473B8FBDB02EC1C27764114567293.
Baseline blijft footer-row-20261020_215936 tot deze build is goedgekeurd.

## BASELINE: footer-row-20261020_215936 - vastgesteld door gebruiker 20 oktober 2026

Gebruiker heeft de nieuwste build getest en als baseline aangewezen:
artifacts\footer-row-20261020_215936\SiteManagement_OneFooterRow_20261020_215936.msapp
SHA-256 1EB3788816043A0F1799539F51958ED38221A904F6791158FB64F0F1912C8F15.

Functioneel getest door gebruiker (gemeld, niet door mij uitgevoerd): import, Project/team selecteren, Weekly Hours toont teamuren, terug naar Project / team, Hours Summary-selecties en uren. Resultaat volgens gebruiker: alles OK.

Technisch gecontroleerd door mij: hash van het geteste bestand komt overeen met de vastgelegde build; alle vijf Src-bestanden zijn inhoudelijk gelijk aan de bronnen in deze build. Src is dus de baselinebron.

Baselinecheckpoint (buiten Src): checkpoints\baseline-footer-row-20261020_215936 met Src, AGENTS.md, Site Managment_VS.msapr, de .msapp en SHA256SUMS.txt.

Aanvullend gemeld door gebruiker op deze baseline (functioneel getest door gebruiker):
- Save: goed getest.
- Geen onterechte blokkades tijdens normaal gebruik gezien.
- Hours Summary-totalen kloppen.
- Hours Summary hiermee door gebruiker functioneel geaccepteerd als basis voor de exportopdracht.

Bewust uitgesteld / nog niet expliciet getest:
- Footer-/knoppenweergave bij smal venster en horizontaal scrollen: lage prioriteit volgens gebruiker.
- Fail-closed blokkades (laadfout, onopgeslagen invoer vóór Refresh/navigatie), App checker-meldingen en Monitor-delegatie zijn niet afzonderlijk gemeld.
- Jaargrens/week 53 in Hours Summary: functioneel niet testbaar, want alle opgeslagen uren vallen in ISO-jaar 2026 en Summary toont alleen jaren uit opgeslagen uren (colReportYears; zo bedoeld). Alleen lokaal getest (30 rekenasserties incl. 2020/53 en 2026/53). Geen testuren in de gedeelde productielijsten invoeren. Natuurlijk testmoment: ISO 2026 heeft 53 weken; KW53 = 28 dec 2026 t/m 3 jan 2027, KW1 2027 begint 4 jan 2027. Test dan Start 2026/KW52 t/m End 2027/KW1 (drie kolommen) en 2026/KW53 als één week, inclusief uren op 1-3 jan 2027 onder 2026/KW53.
- Save-incident 21:15: niet opgehelderd; gebruiker kan het niet meer herleiden. De laatste test gebruikte de baseline van 21:59, met de nieuwe Save-guards. Geen dataverlies vastgesteld. Bij twijfel over gegevens alleen-lezen Modified/Modified By en versiegeschiedenis in Project Workers en Hours rond 21:05-21:25 bekijken; geen automatisch herstel.

Eerstvolgende stap: exportopdracht volgens AGENTS.md (.xlsx per project en werkgever, zonder periodetotaal 0, geen e-mail), gebouwd op deze baseline.

## Gebruikerstest oudere build testbuild-20261020_210403 - gemeld 20 oktober 2026

Functioneel getest door gebruiker (gemeld, niet door mij uitgevoerd) op build artifacts\testbuild-20261020_210403\SiteManagement_Test.msapp (SHA-256 92D9051A669BB97405B0170E41F5EF139F011ABA08A0EBC4005FA83E713B68DC):
- Import .msapp: OK.
- Screen1: project en team selecteren: OK.
- Weekly Hours: teamuren worden getoond: OK.
- Terug naar Project / team en naar Hours Summary: selecties werken, uren getoond: OK.

Betekenis en beperkingen:
- Dit is de build van vóór de Save-regressieherstelbuild (21:36), de knopkleuren en de vaste onderste knoppenrij. Deze build bevat nog de inmiddels teruggenomen sessiecaches en epochguards. De uitkomst bewijst dus niet dat de huidige bron (nieuwste build footer-row-20261020_215936) importeert of werkt.
- Wel bevestigd voor deze oudere build: import en teruglezen van bestaande SharePoint-gegevens op alle drie schermen met dezelfde verbindingen.
- Niet gemeld/getest: App checker-meldingen, Save/Save team, laadfout-/blokkadegedrag, rapporttotalen tegen controlegegevens, jaargrens/week 53, Monitor-delegatie.
- Het Save-incident rond 21:15 viel na het pakken van deze build (21:04) en vóór de herstelbuild; de alleen-lezen controle van Project Workers en Hours (Modified, Modified By, versiegeschiedenis) blijft open.

Eerstvolgende stap: dezelfde korte test (import, project/team, Weekly Hours, Hours Summary, zonder opslaan) herhalen met de nieuwste build footer-row-20261020_215936 en daarbij App checker en de onderste knoppenrij controleren.

## Layoutcorrectie: een vaste onderste knoppenrij - 20 oktober 2026

Geimplementeerd en technisch gecontroleerd; Studio-/browserweergave nog open. Alle drie schermen hebben nu een vaste onderste balk met een gezamenlijke rij: navigatie links, acties rechts. Alle elf zichtbare knoppen gebruiken letterlijk dezelfde appbrede Y-waarde lblFooterButtonMetrics.Y (16) en hoogte lblFooterButtonMetrics.Height (40). Dezelfde opmaakcontrol bevat 40 px randmarge en 12 px tussenruimte. Geen afzonderlijke verticale uitlijning per groep.

Wijzigingen / reden:
- Src/Screen1.pa.yaml: Refresh en Save team verplaatst naar dezelfde rij als Weekly Hours en Hours Summary. Statuspositie losgemaakt van de oude Refreshpositie. Gedeelde verborgen opmaakcontrol toegevoegd; geselecteerdenteller en gallery blijven boven de balk.
- Src/scrHours.pa.yaml: Refresh en Save verplaatst naast Project / team in dezelfde rij; status/gallery niet meer afhankelijk van Refresh-Y bij de inhoud.
- Src/scrWeeklyHours.pa.yaml: Refresh en beide weekschuifknoppen verplaatst naar dezelfde rij als Project / team. Pijlen ook 40 px hoog en conform bestaande knoptypografie. Oude verwijzingen van alle tabelkoppen en eerste periodeveldlabel naar de verplaatste actieknoppen hersteld naar inhoudscontrols. Periodevelden blijven compact en rapporttotaal boven de balk.
- De drie bestaande navcontainers hebben nu een niet-omlopende AutoLayout-viewport met een ManualLayout-binnenrij. Buitenbalk 88 px hoog, binnenrij 72 px; 16 px extra ruimte gereserveerd voor horizontale scrollbar. Bij onvoldoende breedte horizontaal scrollen binnen die vaste balk, nooit een tweede knoppenrij. Rijminima 726 / 514 / 474 px voor respectievelijk Screen1 / Weekly Hours / Hours Summary. Bestaande tabeltelefoonlayout niet opnieuw ontworpen.
- AGENTS.md bijgewerkt: deze afspraak vervangt de eerdere plaatsing van acties bij inhoud. PROJECT_STATUS.md, VALIDATIE.md en manifest bijgewerkt. artifacts/Layout-FooterRow.ps1 is een eenmalig verplaatsingsscript; niet opnieuw uitvoeren op de eindbron. artifacts/Test-FooterRow.ps1 controleert actuele layout en behoud van gedrag.
- Checkpoint buiten Src: C:\Users\vandergoot.ed\Dev\Sitemanagment\checkpoints\footer-row-20261020_215425.

Daadwerkelijk lokaal gecontroleerd:
- Parsed diff tegen checkpoint: alleen layout-/knopopmaakeigenschappen gewijzigd. Alle bestaande teksten, kleuren, OnSelect, OnChange, Items, filters, laad-/opslaglogica, validaties, Visible, DisplayMode en schermacties exact behouden. App.pa.yaml en _EditorState.pa.yaml bytegelijk. Verborgen technische knoppen niet verplaatst.
- Alle 1475 appformules zonder parser-syntaxfouten; 96 controls door gerichte structuur-/templatecontrole (Hours Summary: 502 formules/39 controls). Vier nieuwe controls zijn drie binnenrijcontainers en een gedeeld maatlabel. Geen AccessibleLabel op Classic/Button toegevoegd.
- 21 numerieke layoutcases geslaagd: alle drie schermen bij 320x600, 480x600, 600x600, 768x600, 1024x768, 1366x768 en 1920x1080. Werkelijke footer-/knopformules gevalueerd: gelijke Y/40px, 12px in groepen, minstens 12px tussen zijden, juiste parent, vaste ondergrens, rijminima/scrollconfiguratie en inhoud/totaal boven balk. Summary-content getest met maximale selectieviewport als conservatieve grens; dit is geen volledige nieuwe veld-/telefoontabeltest.
- Bestaande 25 lokale Save-veiligheids-/risicoasserties geslaagd. Guards zijn exact behouden en gelijk in DisplayMode/OnSelect. Geen gegevens of SharePoint-records gewijzigd.
- PAC SourceCode-pack geslaagd. Alle vijf gepakte YAML-bestanden exact gelijk aan Src. Properties.json, DataSources.json en Templates.json exact gelijk aan oorspronkelijke .msapr. Logs naast build: footer-checks.txt, pac-pack.txt, package-checks.txt.

Nog open / beperkingen:
- Studio-import/App checker en werkelijke AutoLayout-scrollbar, uitlijning, tekstpassing, focus/tabvolgorde en vast blijven bij inhoudscrollen op alle drie schermen moeten online worden gecontroleerd. Onder minimale rijbreedte bewust horizontaal scrollen; geen garantie dat alle knoppen tegelijk zichtbaar zijn in een smaller venster.
- De eerdere laad-/Save-incidentcontrole en functionele acceptatie blijven open. Deze opdracht verandert geen gegevens-, opslag- of laadlogica. Geen online functionaliteit of snelheidsmeting geclaimd; productie niet overschreven/gepubliceerd.

Nieuwste aparte testbuild:
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\footer-row-20261020_215936\SiteManagement_OneFooterRow_20261020_215936.msapp
Grootte 96521 bytes; SHA-256 1EB3788816043A0F1799539F51958ED38221A904F6791158FB64F0F1912C8F15.

Eerstvolgende stap: importeer apart, voer App checker uit en controleer op elk scherm de gezamenlijke onderrij bij brede/smalle vensters en scrollende inhoud. Controleer horizontale bereikbaarheid en dat totalen/invoer boven de balk blijven. De eerdere incidenttest blijft artifacts/SAVE_INCIDENT_EN_TEST.md.

Bron voor scroll/wrap-instellingen: https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/controls/control-horizontal-container en https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/build-responsive-apps.

## Appbrede knopkleuren - 20 oktober 2026

Geimplementeerd: vier zichtbare schermnavigatieknoppen blauw (#194296 / hover #123273), zeven zichtbare actieknoppen paars (#7040A0 / hover #593080), inclusief de twee lokale weekschuifknoppen. Witte normale/hover/ingedrukte tekst; disabled achtergrond #E5E7EB en tekst #6B7280. Ingedrukt volgt hover; randen volgen de bijbehorende achtergrondkleur. Groen is geen algemene actiekleur meer.

Gewijzigd: Src/Screen1.pa.yaml, Src/scrHours.pa.yaml en Src/scrWeeklyHours.pa.yaml uitsluitend voor knopkleuren; AGENTS.md voor de blijvende afspraak; dit statusbestand, VALIDATIE.md en buildmanifest voor oplevering. Eenmalig kleurhulpscript artifacts/Apply-ButtonColors.ps1 toegevoegd. Checkpoint buiten Src: C:\Users\vandergoot.ed\Dev\Sitemanagment\checkpoints\button-colors-20261020_214829.

Technisch gecontroleerd:
- Parsed eigenschapsdiff tegen checkpoint: uitsluitend 119 kleurverschillen/toevoegingen op 11 zichtbare knoppen. Alle overige eigenschappen inclusief teksten, acties, validaties, DisplayMode, Visible, posities en afmetingen exact behouden. Schermacties behouden; App.pa.yaml en _EditorState.pa.yaml bytegelijk. Verborgen technische knoppen ongewijzigd. Vaste onderste navigatie en inhoudsactieplaatsing behouden.
- Alle 1398 appformules zonder parser-syntaxfouten; 92 controls door de gerichte structuur/templatecontrole. Hours Summary: 461 formules/38 controls. Geen AccessibleLabel op Classic/Button toegevoegd.
- Bestaande 25 lokale Save-veiligheids-/risicoasserties opnieuw geslaagd; predicates in DisplayMode en OnSelect blijven identiek. Geen aanvullende functionele of SharePoint-controle uitgevoerd.
- PAC SourceCode-pack geslaagd. Alle vijf gepakte YAML-bronnen exact gelijk aan Src; Properties.json, DataSources.json en Templates.json exact gelijk aan oorspronkelijke .msapr. Logs color-diff.txt, package-checks.txt en pac-pack.txt naast build.

Nog open: Studio-import/App checker, visuele normale/hover/pressed/disabled-kleuren en eventuele browser-/toegankelijkheidscontrole. Het Save-incident rond 21:15, werkelijk laden, online foutafhandeling en de eerdere functionele acceptatietests blijven open; een kleurbuild verandert die status niet. Geen productiepublicatie of SharePoint-schrijf-/herstelacties uitgevoerd.

Nieuwste testbuild: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\button-colors-20261020_214931\SiteManagement_ButtonColors_20261020_214931.msapp
Grootte 96254 bytes; SHA-256 C9D904567CCF34A9CA6F3879927B01B9B59F80C6D966C00D26C763DC7AAD70D0.
Eerstvolgende stap: importeer apart, controleer de kleuren op alle drie schermen en voer vervolgens artifacts/SAVE_INCIDENT_EN_TEST.md uit zonder ingeschakelde Save voor uitsluitend teruglezen.

## Urgente Save-regressie en herstelbuild - 20 oktober 2026

**Stand: geimplementeerd en lokaal technisch gecontroleerd; niet online functioneel getest.** Gebruiker meldt een Save rond **21:15**, knop en melding onbekend. Geen SharePoint-records gelezen of gewijzigd vanuit dit onderzoek. Geen daadwerkelijke wijziging of dataverlies vastgesteld.

Bevindingen / mogelijke gevolgen:
- Save team controleerde in OnSelect slechts project/team. DisplayMode was onvoldoende als enige laadbeveiliging. Met oude geladen koppelingen en een lege/gedeeltelijke geselecteerde collection kon de deactiveringslus bestaande leden op Active=false zetten. Lokaal met twee voorbeeldkoppelingen gereproduceerd. Waren beide collections werkelijk leeg, dan doorliep de lus geen records. Ook aanmaken/reactiveren/teamwijziging van geselecteerde medewerkers was mogelijk. Geen fysieke verwijderactie.
- Save week schreef alleen afwijkende dagwaarden; volledig lege rijen/ontbrekende geladen maandag werden afgevangen. Leegte alleen maakt geen 0-urenpatch. Lokale 0 tegenover geladen niet-nuluren kon wel als wijziging worden opgeslagen zonder volledige laadstatuscontrole. Bestaande conflictdetectie bleef aanwezig. Updates wijzigden uitsluitend Title/Hours; nieuwe records bevatten wel datum/assignment/werkgever/team/trade. Geen bewijs welke route rond 21:15 is uitgevoerd.
- Geen automatische externe Patch/Remove/Update of flow.Run in de app aangetroffen; input-Patch/checkbox-RemoveIf en snapshot-UpdateIf zijn lokaal. Eventuele externe SharePoint-triggerflows niet lokaal geinventariseerd. Save is niet transactioneel en kan gedeeltelijk slagen.
- Teamdeactivering kan actieve leden uit ureninvoer laten verdwijnen, maar verwijdert geen centrale Workers, Team-keuzewaarden of jaar/KW-keuzes. De definitieve runtime-oorzaak van alle lege keuzes is zonder Studio-/Monitor-melding niet vastgesteld. Connectorauthenticatie/rechten zijn niet online gecontroleerd.

Uitgevoerde beveiligingen / laadherstel:
- Beide Save-acties hebben dezelfde fail-closed predicate in DisplayMode en direct aan het begin van OnSelect. Alleen Loaded, geen fouten/bezigstatus, overeenkomende selectie/snapshot/rijaantallen en geldige sleutels worden toegelaten. Weekcontrole bevat ISO-jaar, KW en bijpassende maandag.
- Save team met lege selectie geblokkeerd. Alleen expliciet uitgevinkte oorspronkelijk geladen medewerkers zijn kandidaten voor deactivering; ontbrekende collectionregels zonder expliciete verwijderopdracht blokkeren opslaan. Het leegmaken van een volledig team via een lege Save-selectie is bewust niet beschikbaar.
- Save week valideert bovendien EntryKey tegen bestaande Assignment-ID en Work Date. Ontbrekende/afwijkende assignment-/projectkeys blokkeren schrijven. Bestaande uurvalidatie, serverconflictdetectie en historische werkgevers blijven behouden.
- Screen1 en Weekly Hours lezen eerst naar tijdelijke collections; foutpaden wissen geen zichtbare selectie/uren of oorspronkelijke snapshot. Pas na geslaagde volledige load worden actieve gegevens vervangen. Oude gegevens na fout zijn alleen-lezen, met zichtbare fout en geblokkeerde Save. Onopgeslagen invoer blokkeert Refresh/opnieuw laden in zowel UI als OnSelect/loader. Checkboxevents controleren actuele Self.Value en berekenen dirty uit de werkelijke selectie.
- Nieuwe geneste week-/rapportcaches en epochguards teruggenomen. Vergelijking met checkpoint performance-20261020_201156/Src (vóór caches), eerdere read-existing-bron en oorspronkelijke metadata. Geen claim dat deze oudere gewijzigde bron opnieuw online is getest. Eerst directe project-/Team Choices-/Workers-/weekload, daarna Hours Summary terug op historische directe loader. Jaar/KW-keuzes niet meer afhankelijk van een cachehit; KW heeft een ISO-jaar-fallback.
- Na een toegestane Save worden rapportresultaten ongeldig gemaakt. Gedeeltelijke/onzekere opslag blokkeert verder opslaan en bewaart invoer; geen automatische compensatie of SharePoint-herstel.

Gewijzigde bestanden / reden:
- Src/Screen1.pa.yaml: masterdata/teamkeuzes, staging, laadstatus/snapshot, Save-guards, expliciete verwijderintenties, behoud van selectie en Refresh/navigatie-/editbeveiliging.
- Src/scrHours.pa.yaml: directe weekload met staging, status/snapshot/volledigheidscontrole, Save-guard en assignment/datumcontrole, invoer-/Refreshbeveiliging en KW-fallback.
- Src/scrWeeklyHours.pa.yaml: nieuwe cache en verkorte historische route teruggenomen; directe loader hersteld met status/foutpad. Compacte layout en lokale berekening behouden.
- AGENTS.md: blijvende opslagveiligheid; actuele cacheterugname expliciet gemaakt. PROJECT_STATUS.md, VALIDATIE.md en latest-functional-test.json bijgewerkt.
- artifacts/SAVE_INCIDENT_EN_TEST.md: mogelijke gevolgen, alleen-lezen controle rond 21:15, herstelvoorwaarden en online fout-/invoerbehoudtest. artifacts/Test-SaveRegression.ps1: actuele guards uit de echte bron getest, schrijfpadscan en stagingchecks; team/week-save-guard.fx zijn inspectiekopieen van de guards. Eenmalig Repair-SaveRegression.ps1 is een tussenstapscript, geen opnieuw uit te voeren installer voor de eindbron.
- App.pa.yaml en _EditorState.pa.yaml bytegelijk aan incidentcheckpoint. Geen productiepublicatie, vervangende lijsten/testdata of verbindingwijzigingen. Checkpoint: C:\Users\vandergoot.ed\Dev\Sitemanagment\checkpoints\save-regression-20261020_211839.

Daadwerkelijk gecontroleerd:
- Alle 1306 appformules zonder parser-syntaxfouten; 92 controls door gerichte structuur/templatecontrole. Hours Summary: 419 formules/38 controls. Geen volledige Canvas-binding-/delegatiecontrole geclaimd.
- 25 lokale veiligheids-/risicoasserties op de echte Save-predicates en bronsemantiek: koude start, NotLoaded/Loading/Failed, laadfout met stale Loaded, project/team/week/monday-mismatch, ontbrekende baseline, lege selectie/uren, sleutelprobleem, expliciete verwijdering, oud deactiveringsrisico en geen automatische nulwijziging bij ongewijzigde/lege uren. Zelfde guard in DisplayMode/OnSelect bevestigd.
- Scan: externe Patch uitsluitend in beide expliciete Save.OnSelect-actions; geen externe Remove/Update/flow.Run, geen bronmutatie in vier loaders/builders, geen geneste cacheverwijzingen. Stagingcommit en ontbreken van Clear op actieve selectie-/urenrijen in loaders gecontroleerd.
- 30 bestaande lokale rapportrekenasserties geslaagd: ISO-jaar/week 53, jaargrens, perioden, contractor-/assignmentisolatie en 499/500/501-grens. Tien numerieke Summary-layoutcontroles geslaagd, geen visuele browsercontrole.
- PAC SourceCode-pack geslaagd. Alle vijf gepakte YAML-bestanden exact gelijk aan Src. Properties.json, DataSources.json en Templates.json exact gelijk aan oorspronkelijke .msapr. Buildlogs naast testbestand.

Nog open / beperkingen:
- Studio-import, App checker/binding, connectorrechten, echte serverdelegatie, werkelijk laden van alle drie schermen, offline fouttest/Save-blokkade en invoerbehoud online zijn niet uitgevoerd.
- Werkelijke mutaties rond 21:15: controleer Project Workers Active/Team en Hours Hours/Work Date, plus Created/Modified/Modified By en versiegeschiedenis. Begin venster 21:05-21:25, verruim bij latere wijzigingen. Geen herstel zonder aantoonbare eerdere waarden en rekening houden met legitieme latere bewerkingen.
- Directe loads kunnen langzamer zijn; Summary leest nog volledige projecthistorie voor periodekeuzes en blokkeert bij >=500 in een batch. Geen indexaanwezigheid of online snelheidswinst vastgesteld. Export ongewijzigd uitgesteld.
- Een mislukte/gedeeltelijke Save is geen rollback. Bij blokkade na zo'n fout de lokale invoer noteren en eerst SharePoint-versies controleren. Een team volledig leeg opslaan is bewust geblokkeerd.

Nieuwste aparte hersteltestbuild:
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\save-safety-20261020_213657\SiteManagement_SaveSafety_20261020_213657.msapp
Grootte 95748 bytes; SHA-256 D35131BD17A13A2C6D6575C13A2AFC710152729E9C54F0973663F10A5E828562.

Eerstvolgende stap: controleer eerst alleen-lezen de incidentrecords en importeer daarna de aparte herstelapp; volg artifacts/SAVE_INCIDENT_EN_TEST.md. Bij blijvende lege keuzes zijn de exacte status/App checker-melding en Monitor-log nodig. Geen ingeschakelde Save gebruiken voor uitsluitend teruglezen.

## Nieuwe testversie - 2026-10-20 21:04

Huidige bron opnieuw verpakt; geen appformules of layout gewijzigd. Uitgevoerd: Hours Summary-parsercontrole (419 formules, geen syntaxfouten), gerichte structuur/templatecontrole (38 controls), PAC SourceCode-pack geslaagd en alle vijf verpakte YAML-bronnen exact vergeleken met Src. Geen nieuwe functionele of online performancetest uitgevoerd. Bestaande beperkingen blijven gelden. Productie en eerdere builds behouden.

Gewijzigd: PROJECT_STATUS.md, artifacts/latest-functional-test.json en artifacts/VALIDATIE.md; nieuwe build/logbestanden buiten Src.

Testbuild: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\testbuild-20261020_210403\SiteManagement_Test.msapp
Grootte: 95026 bytes. SHA-256: 92D9051A669BB97405B0170E41F5EF139F011ABA08A0EBC4005FA83E713B68DC.

Openstaand / eerstvolgende stap: importeer als aparte app in Power Apps Studio, voer App checker uit en volg artifacts/PERFORMANCE_EN_INDEXEN.md. Een geslaagde pack bewijst geen geslaagde Studio-import of functionele test.

## Performance-optimalisatie - 20 oktober 2026

Huidige functionele stand: geimplementeerd in bron en aparte testbuild; lokaal technisch gecontroleerd. Studio-import, Canvas-binding/delegatie, functioneel gedrag en online snelheidsmetingen zijn nog niet uitgevoerd. Power Apps + bestaande SharePoint-lijsten zijn de vaste architectuur.

Gevonden knelpunten en uitvoering:
- Screen1 ververste Projects/Workers/Project Workers bij ieder bezoek of project/teamwijziging en las projectkeuzes opnieuw. De loader slaat nu dezelfde succesvolle selectie/epoch over; projectkeuzes worden eenmaal per epoch gelezen. De extra Refresh bij navigeren naar ureninvoer is verwijderd. Expliciete Refresh toegevoegd.
- Weekly Hours ververste bronnen en berekende historische jaargrenzen bij iedere weekwisseling. Volledig gevalideerde weken worden nu per project/team/ISO-jaar/KW/epoch hergebruikt; dezelfde selectie wordt overgeslagen. Jaargrenzen eenmaal per epoch. Cacheherstel behoudt bestaande EntryKey en opslagcontext. Refresh toegevoegd, geblokkeerd bij onopgeslagen uren. Alleen voor de nieuwe actieknoppen is ruimte in de inhoud vrijgemaakt; titel/navigatie behouden.
- Hours Summary laadde alle historie opnieuw bij schermbezoek. Laden is gescheiden van de zichtbare Refresh via btnLoadReport. Projectfacts, actieve medewerkers en beschikbare perioden worden gecachet; terugkeer naar hetzelfde project behoudt de selectie, terugkeer naar een ander gecachet project herstelt alle contractors/de volledige beschikbare periode. Contractor- en periodewissels blijven lokaal.
- Historische scan: eerst een smalle batch per assignment; bij minder dan 500 regels direct verwerken, vanaf 500 eerst de bestaande gecontroleerde kalenderjaarbatches ophalen. Daardoor vervallen bij kleinere assignments de twee datumbereikformules en jaarlus. Dit is een vermindering van query-expressies, geen gemeten HTTP-aantal of tijdwinst.
- Hours-batches gebruiken expliciete ShowColumns na het serverfilter. Geen externe lookup per tabelcel aangetroffen/toegevoegd. Profielophaling blijft per betrokken medewerker bij een nieuwe project/teamload.
- Refresh en iedere expliciete opslagpoging verhogen varDataEpoch en legen beide caches. Afzonderlijke Refresh-fouten blokkeren resultaat/opslag via bestaande foutpaden. Geen automatisch Patch tijdens laden. Bestaande Save-/Save team-opslagkern exact behouden, uitsluitend cache-invalidering vooraf toegevoegd.

Gewijzigde bestanden en scope:
- Src/Screen1.pa.yaml: team/project-laadguard, projectkeuzecache, expliciete Refresh, dubbele navigatie-Refresh verwijderd, opslagcache-invalidering; status/gallery verplaatst voor de actie.
- Src/scrHours.pa.yaml: volledige weekcache, jaargrenscache, guards, smalle urenprojectie, expliciete Refresh en benodigde actie/statuslayout, opslagcache-invalidering.
- Src/scrWeeklyHours.pa.yaml: verborgen loader, projectcache, expliciete Refresh, verkorte historische scan, smalle projectie, OnVisible/projectactie aangepast. Bestaande berekening, contractoractie en compacte selectieopmaak behouden.
- AGENTS.md: vaste SharePoint-architectuur en cache-/Refresh-/correctheidsregels. PROJECT_STATUS.md en artifacts/VALIDATIE.md/buildmanifest bijgewerkt.
- artifacts/PERFORMANCE_EN_INDEXEN.md: onderzochte routes, cachegeldigheid, resterende schaalbeperking, indexinventaris en online Monitor-test. Nieuwe lokale wijzigings-/controlescripts staan buiten Src; Optimize-Loading/Refine-Loading/Cache-Reports/Optimize-History zijn eenmalige scripts en mogen niet opnieuw op de gewijzigde bron worden uitgevoerd.
- Regressiescripts aangepast voor de afgescheiden loader en gecontroleerde cacheprefix bij opslag. Test-SummaryFields -GeometryOnly controleert geometrie zonder de vroegere eis dat alle acties ongewijzigd moeten zijn. App.pa.yaml en _EditorState.pa.yaml bytegelijk aan checkpoint.
- Checkpoint buiten Src: C:\Users\vandergoot.ed\Dev\Sitemanagment\checkpoints\performance-20261020_201156.

Daadwerkelijk uitgevoerde lokale controles:
- Alle 1306 appformules zonder parser-syntaxfouten; 92 controls door de gerichte structuur/templatecontrole. Hours Summary: 419 formules, 38 controls. Geen AccessibleLabel op Classic/Button toegevoegd. Geen volledige Canvas-bindingcontrole geclaimd.
- Eigenschapsdiff bestaande controls tegen checkpoint gecontroleerd: alleen bedoelde laad-/Refresh-/cache-/opslagprefix- en benodigde layoutwijzigingen. Expliciete opslagkern exact vergeleken met oorspronkelijke backup. App-start en editorstaat ongewijzigd.
- Vijf laad-/rapportacties gecontroleerd op ontbreken van Patch/Update/Remove/SubmitForm en externe collectionmutaties. Vier bestaande terugleesvoorbeelden, 30 rapportrekenasserties en zes aanvullende lokale cache-/grensasserties geslaagd, inclusief nested cache-isolatie en ongeldig epoch.
- Tien bestaande numerieke Hours Summary-layoutcontroles geslaagd (320x600 t/m 1920x1080); geen browser-/scrolltest. Nieuwe Refresh-acties buiten titel/navigatie geplaatst. Visuele controle op alle schermen blijft open.
- PAC SourceCode-pack geslaagd. Alle vijf verpakte YAML-bestanden exact gelijk aan de bron. Properties.json, DataSources.json en Templates.json exact gelijk aan oorspronkelijke .msapr. Geen productieapp overschreven/gepubliceerd, geen live gegevens/indexen gewijzigd.
- Logs naast testapp: performance-checks.txt, calculations.txt, summary-layout.txt, package-checks.txt, pac-pack.txt.

Beperkingen / nog te testen:
- Eerste rapportload leest nog volledige projecthistorie voor exacte beschikbare perioden: Hours heeft geen opgeslagen ISO-jaar/KW. Beschikbare perioden en historische factophaling zijn nog gecombineerd. Grote assignments behouden jaarlussen; een jaarbatch >=500 stopt bewust. Geen ongefundeerde serverflow toegevoegd. Alleen de gekozen invoerweek wordt voor scrHours gelezen.
- Indexaanwezigheid niet online zichtbaar: benodigde kolommen en concrete stappen staan in artifacts/PERFORMANCE_EN_INDEXEN.md. Niet beweren dat indexen ontbreken. Lookupindex alleen is geen oplossing voor de SharePoint List View Threshold.
- Sessiecaches zijn geen realtime abonnement; wijzigingen van anderen vereisen Refresh. Cachegeheugen groeit tot Refresh/opslaan/sessie-einde; grote datasets en snelle selectiewissels nog online testen.
- Studio-import/schema/binding (met name nested cachetabellen), App checker/delegatie, echte serverfilters/projectie, connectorrechten, Refresh-foutscenario en historische totalen/actieve nulurenleden zijn openstaand. Geen online metingen beschikbaar.

Nieuwste testapp: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\performance-20261020_201746\SiteManagement_Performance_Test.msapp
Grootte 95026 bytes; SHA-256 5E4DC3C75ADA4E81FD07240BFFCA76D6959CD75EAECDA072072CC191237DB90B.

Eerstvolgende stap: importeer apart en voer de vijf scenario's plus Live monitor uit volgens artifacts/PERFORMANCE_EN_INDEXEN.md. Lever eventuele exacte Studio-melding, selectie en Monitor-log aan. Eerst overzicht/ureninvoer functioneel accepteren; export blijft volgende opdracht.

## Laatste opdracht: compacte vaste selectievelden op Hours Summary

Geïmplementeerd, uitsluitend layout:
- Eén gedeelde visuele breedte: lblSummaryFieldWidth.Width=256 px. De vier ISO Year/KW-dropdowns zijn exact 256 px; Project en Contractor exact 2x die breedte (512 px). Geen MaxLength, tekenlimiet of invoer-/datarijlimiet veranderd.
- Alle groepen beginnen links op dezelfde marge van 40 px. Labels hebben dezelfde X en breedte als hun eigen veld, Height=24 en 4 px afstand tot het veld. Groepen gebruiken 12 px tussenruimte; de velden rekken niet meer mee met de schermbreedte.
- Op een breed scherm staan Project, Contractor en Refresh in de eerste rij, met daaronder Start ISO Year, Start KW, End ISO Year en End KW. Op smallere schermen lopen groepen in dezelfde volgorde door naar volgende rijen. Refresh staat rechts van Contractor als er ruimte is, anders op een volgende rij.
- De selecties en Refresh staan in gewone GroupContainer-layoutcontainers, zonder Gallery-/recordscope. De bestaande Reset- en Select-acties en de controlnamen zijn behouden. Er is geen variabele of laadactie toegevoegd om de breedte te initialiseren.
- Een afzonderlijk scrollbaar selectieblok houdt omgelopen velden bereikbaar bij beperkte hoogte. Onder een 512-px-veld plus marge is horizontaal scrollen de noodzakelijke uitwijkmogelijkheid om de vaste verhouding te behouden. De selectieviewport is maximaal 220 px hoog en wordt bij kleinere schermhoogte verder begrensd om rapport/totaal/navigatie vrij te houden. 16 px breedte is gereserveerd voor de verticale scrollbar.
- Projectdetails, status, weekschuifknoppen, tabelkoppen en rapporttabel sluiten qua Y aan op de selectieviewport. De onderste navigatiebalk en rapporttotaal blijven op hun bestaande vaste positie. Geen velden of knoppen in de blauwe titelbalk geplaatst.

Gewijzigde bestanden:
- Src/scrWeeklyHours.pa.yaml: alleen X/Y/Width/Height van bestaande controls gewijzigd plus een verborgen maatlabel en twee layoutcontainers toegevoegd. Selectiecontrols/Refresh daarin herplaatst. Alle overige appbronnen zijn bytegelijk aan de backup.
- AGENTS.md: compacte veldstandaard, volgorde, regelomloop, scrolluitwijking en behoud van gedrag vastgelegd.
- PROJECT_STATUS.md, artifacts/VALIDATIE.md en latest-functional-test.json: actuele oplevering/buildverwijzing en Studio-controles.
- artifacts/Layout-SummaryFields.ps1: eenmalig lokaal layoutscript; niet opnieuw uitvoeren op reeds heringedeelde bron zonder de uitgangssituatie te herstellen.
- artifacts/Test-SummaryFields.ps1: gedrag-/scopevergelijking met backup en evaluatie van werkelijke layoutformules op tien schermformaten.
- artifacts/Test-WeeklyCalculations.ps1: controlzoeken recursief gemaakt, zodat dezelfde bestaande Refresh-formule ook binnen de layoutcontainers wordt getest.
- artifacts/Check-WeeklySource.ps1: de gedocumenteerde auto-layout-kind-eigenschap FillPortions uitsluitend toegelaten bij kinderen van een AutoLayout-container. Andere controles blijven gehandhaafd; geen AccessibleLabel op Classic/Button toegevoegd.
- Backup buiten Src: checkpoints/summary-fields-20261020_182843.

Daadwerkelijk technisch gecontroleerd:
- Vergelijking per bestaande control: uitsluitend X/Y/Width/Height verschillen. Items, Items.Value, Default, OnChange, alle acties/laadformules/filters, Visible, DisplayMode en overige eigenschappen exact behouden. Screen.OnVisible identiek. App.pa.yaml, Screen1.pa.yaml, scrHours.pa.yaml en _EditorState.pa.yaml bytegelijk aan backup.
- Alle 1261 appformules zonder syntaxfouten met Microsoft Power Fx-parser; 89 controls door de gerichte structuur/templatecontrole (Hours Summary: 414 formules, 37 controls). Geen volledige Canvas-binding/importcontrole geclaimd.
- Tien numerieke layoutcontroles geslaagd: 320x600, 600x600, 768x600, 1024x768, 1132x768, 1156x768, 1254x720, 1280x720, 1366x768 en 1920x1080. Werkelijke formules voor breedtes, labels, regelomloop, contenthoogte, overlap en vrije ruimte boven totaal/navigatie geëvalueerd. De smalste cases testen het selectieblok en zijn geen validatie van een volledige telefoonlayout van de bestaande rapporttabel.
- Behoud van gedeelde SharePoint-laadroute en ongewijzigde expliciete Save-acties gecontroleerd; vier lokale terugleesvoorbeelden en 30 bestaande Hours Summary-rekenassertions opnieuw geslaagd.
- PAC SourceCode-pack geslaagd, afsluitcode 0. Alle gepakte YAML-bronnen exact gelijk aan Src. Properties.json, DataSources.json en Templates.json gelijk aan oorspronkelijke .msapr; geen andere site/lijst of gegevens aangemaakt, verwijderd of gewijzigd. Productie en oudere builds behouden.
- Logs naast testapp: layout-checks.txt, read-regression.txt, summary-calculations.txt, pac-pack.txt en package-checks.txt.

Nog open / beperkingen:
- Studio-import, volledige Canvas-binding, de AutoLayout-overflow/FillPortions-weergave, focus/scrollgedrag en echte browserweergave zijn niet uitgevoerd. Pack en numerieke tests bewijzen geen geslaagde import of visuele test.
- Controleer op een breed scherm de twee gewenste rijen, vaste 256/512-breedtes, labels op dezelfde X, 12 px groepsafstand en Refresh rechts. Verklein vervolgens het venster en controleer regelomloop plus bereikbaarheid van alle velden door het selectieblok te scrollen. De navigatiebalk en rapporttotaal mogen niet verdwijnen of bedekt raken.
- Controleer behoud van geselecteerde waarden bij resizing, automatisch doorwerken van project/contractor/jaar/KW en Refresh, inclusief bestaande Reset-acties. Dit is lokaal tekstueel behouden maar nog niet live getest.
- Een veld van 512 px kan fysiek niet tegelijk volledig zichtbaar zijn binnen een venster van 320 px; daarom blijft de breedte vast en is de selectie-inhoud horizontaal bereikbaar. De bestaande rapporttabel is niet opnieuw ontworpen voor telefoonbreedtes onder 768 px.
- De huidige tests hanteren minimaal 600 px hoogte. Kleiner hoogten, browserzoom en langere dynamische teksten vereisen aparte visuele beoordeling. Eerdere gegevens-/delegatiebeperkingen blijven gelden.
- Geen nieuwe invoerlimieten, gegevenslogica, export of opslagacties toegevoegd.

Eerstvolgende stap: importeer de nieuwste aparte testapp, voer App checker uit en controleer breed/smal de vaste veldbreedtes, regelomloop, scroll/focus, behouden selecties en de vaste navigatie. Geef bij fouten de exacte control/eigenschap en Studio-melding terug.

Referenties voor de gebruikte container-eigenschappen:
- Microsoft verticale container (overflow, fill portions): https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/controls/control-vertical-container
- Microsoft responsive containers en scrolling: https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/build-responsive-apps


## Laatste opdracht: bestaande SharePoint-data teruglezen in iedere testbuild

### Onderzoek en onderscheid

- De oorspronkelijke .msapr, de export Site Managment_VS.msapp en deze nieuwe testbuild verwijzen naar dezelfde site https://geacloud.sharepoint.com/sites/GEASiteManagment en dezelfde vijf lijst-ID's. De volledige DataSources.json is behouden. De exacte lijst-ID's staan in artifacts/GEGEVENSBRONNEN_EN_TEST.md en sharepoint-sources.json naast de build.
- Geen vervangende lijsten of testdata aangemaakt en geen live SharePoint-mutaties uitgevoerd. Er is geen tool/verbinding beschikbaar waarmee hier de live authenticatie, rechten of lijstinhoud kon worden geïnspecteerd. Die oorzaken zijn dus niet uitgesloten op runtime-niveau.
- App.OnStart initialiseerde alleen varSaving. Screen1 had geen OnVisible-laadactie. Workers werd rechtstreeks door Gallery.Items opgehaald, dus het ontbreken van OnStart-caches bewijst op zichzelf niet dat medewerkers ontbreken. Teamcollecties werden uitsluitend via project-/team-OnChange gevuld.
- Het teruglezen van koppelingen in Screen1 en scrHours filterde op de afgeleide tekst ProjectKey; Hours Summary gebruikte al de echte Project.Id. Daardoor kon een bestaand record met een lege/afwijkende ProjectKey uit ureninvoer/selectie verdwijnen terwijl het wel in de bron/rapportage bestaat. Dit codeprobleem is aangetoond met een lokaal voorbeeld; of zulke records werkelijk in de site staan is niet live vastgesteld.
- Weekly Hours had drie kopieën van dezelfde laadformule en las dagwaarden uitsluitend via berekende EntryKey. Een afwijkende opgeslagen sleutel kon daardoor een lege dagcel opleveren. Er was geen consequente foutmelding of veilige blokkering na een onvolledige load. De invoerjaren waren beperkt tot vandaag +/- 5 jaar.
- Een lege collection bij een nieuwe app/sessie is geen verlies van SharePoint-data. Schermselecties blijven sessiestaat en bepalen welke opgeslagen records zichtbaar worden. De actuele datum als standaardweek toont niet automatisch uren van een andere opgeslagen week.

### Geïmplementeerd

- App.StartScreen expliciet Screen1. App.OnStart initialiseert alleen de bestaande opslagflags; er worden geen bronrecords aangemaakt of gewist.
- Screen1.OnVisible en beide selectiecontrols roepen één verborgen, uitsluitend lezende btnReadTeam aan. De projecten komen uit Projects, medewerkers blijven rechtstreeks uit Workers beschikbaar; opgeslagen actieve koppelingen worden met Project.Id/Team/Active teruggelezen en medewerkers op Worker.Id opgezocht.
- Projectkeuze blijft op ID bewaard bij refresh. Ontbrekende selecties, geen projecten/medewerkers, geen actieve teamkoppelingen en laadfouten krijgen afzonderlijke statusmeldingen. Een mislukte of mogelijk afgeknotte load blokkeert Save team en navigatie vanuit de onvolledige selectie. Afwijkende bestaande AssignmentKey/ProjectKey blokkeren teamopslag, met uitleg; er wordt niets automatisch gerepareerd.
- scrHours.OnVisible en de jaar-/weekkeuzes gebruiken één verborgen btnReadWeek. Jaarwijziging reset KW en laadt automatisch. De jaarlijst omvat naast het bestaande +/-5-jaarsvenster ook de oudste/nieuwste opgeslagen ISO-jaren uit Hours; meer dan 500 keuzewaarden geeft een expliciete blokkade.
- Opgeslagen uren worden gelezen met Assignment.Id en een weekdatumbereik, in begrensde batches. De dagregels worden lokaal per datum gekoppeld aan de bestaande Mon-Sun-rij. Bestaande EntryKey heeft voorrang; nieuwe lokale dagsleutels volgen het bestaande project-ID|worker-ID|yyyymmdd-schema. Er is geen nieuwe SharePoint-kolom of sleuteldefinitie ingevoerd.
- Bestaande actieve medewerkers zonder opgeslagen dagregels blijven met lege invoercellen en nulweektotaal zichtbaar. De melding onderscheidt geen actieve koppelingen van nul opgeslagen uren voor de gekozen week; er wordt niet gevraagd stamgegevens of uren opnieuw aan te maken.
- Dubbele dagregels of laadfouten blokkeren het weekoverzicht. Ontbrekende/dubbele EntryKey of afwijkende bestaande AssignmentKey: uren kunnen worden teruggelezen, maar bewerken/opslaan wordt geblokkeerd. Save en Save team blijven expliciete bestaande acties; hun volledige OnSelect is ongewijzigd.
- Hours Summary en zijn project-/historische werkgeversfilters zijn niet gewijzigd: het gebruikt dezelfde Hours-lijst en de reeds bestaande ID-/datumlaadroute. colWeekStored/colWeekRows/colWeekOriginal en colReportFacts/colReportRows zijn uitsluitend tijdelijke caches.
- Statuslabels toegevoegd op project/team en Weekly Hours; galleries verschoven om daarvoor plaats te reserveren zonder navigatie of tabelkoppen te overlappen.

### Gewijzigde bestanden

- Src/App.pa.yaml: vaste koude start en uitsluitend opslagflags initialiseren.
- Src/Screen1.pa.yaml: centraal teruglezen, selectie-/foutmeldingen, veilige bediening en statusruimte.
- Src/scrHours.pa.yaml: centraal weekteruglezen via lookup-ID/datum, behoud bestaande sleutel, jaarbereik, fout-/alleen-lezen-toestanden en statusruimte.
- Src/scrWeeklyHours.pa.yaml en Src/_EditorState.pa.yaml: ongewijzigd ten opzichte van de backup.
- AGENTS.md: gedeelde duurzame bronnen versus tijdelijke caches, read-only laden en de consequentie van opslaan naar gedeelde lijsten vastgelegd.
- PROJECT_STATUS.md, artifacts/VALIDATIE.md, artifacts/GEGEVENSBRONNEN_EN_TEST.md en latest-functional-test.json: bronverantwoording, actuele resultaten en korte bevestigingstest.
- artifacts/read-team.fx, read-week.fx, Repair-ReadExisting.ps1: gebruikte eenmalige herstelbestanden; Src blijft de actuele appbron. Niet opnieuw uitvoeren op later gewijzigde bron zonder de uitgangssituatie te controleren.
- artifacts/Test-ReadExisting.ps1: syntaxis/templates, onveranderde expliciete Save-acties, afwezigheid van schrijfacties bij laden en lokale terugleesvoorbeelden.
- artifacts/Test-NavigationLayout.ps1: -LayoutOnly toegevoegd voor actuele geometriecontrole zonder de bewust gewijzigde laad-/DisplayMode-formules aan de historische navigatiesnapshot gelijk te eisen; nieuwe statuslabels op overlap gecontroleerd.
- Backup: checkpoints/read-existing-20261020_175917, buiten Src.

### Daadwerkelijk technisch gecontroleerd

- 1235 formules inclusief App geparsed: nul syntaxfouten. Alle 86 controls door de gerichte schema-/templatecontrole; dit is geen volledige Canvas-bindingcontrole.
- Vier actuele laad-/rapportacties gescand: geen Patch/Update/Remove/SubmitForm en Collect/Clear uitsluitend op lokale col-collections. App.OnStart bevat alleen Set. Bestaande Save-/Save team-OnSelect exact vergeleken met de backup: behouden.
- Vier lokale Power Fx-terugleesvoorbeelden geslaagd: juiste project/team ondanks lege ProjectKey; verkeerde projecten/teams/inactieven uitgesloten; de juiste dagregels in ISO-week 53 op assignment/datum; opgeslagen EntryKey behouden; ouder ISO-jaar selecteerbaar. Hierbij zijn geen bronrecords geschreven.
- De 30 eerdere Hours Summary-rekenassertions opnieuw uitgevoerd en geslaagd.
- Layoutformules voor 768x600, 1024x768, 1280x720, 1366x768 en 1920x1080 opnieuw numeriek gecontroleerd; galleries, statuslabels, tabelkoppen, totalen en navigatie passen volgens de formules. Geen browserrendering uitgevoerd.
- PAC SourceCode-pack geslaagd, afsluitcode 0. Alle gepakte bronnen exact gelijk aan Src. DataSources.json, Properties.json en Templates.json gelijk aan oorspronkelijke .msapr; site/lijst-ID's ook vergeleken met de oorspronkelijke .msapp-export.
- Logs naast de nieuwe build: read-existing-checks.txt, summary-calculations.txt, layout-checks.txt, package-checks.txt, pac-pack.txt en sharepoint-sources.json.

### Openstaande controles en beperkingen

- Niet functioneel getest in Studio of tegen live SharePoint. Authenticatie, importverbinding, gebruikersrechten, de echte recordinhoud en werkelijke serverdelegatie zijn niet bewezen. De lokale kwetsbaarheden zijn hersteld, maar de daadwerkelijk ervaren runtime-oorzaak kan pas met de bevestigingstest en eventuele connectorfout worden vastgesteld.
- Controleer App checker/binding van de nieuwe verborgen laadknoppen, ForAll-records, jaarlijst en fout-/alleen-lezen-vlaggen. Een geslaagde pack is geen geslaagde import of functionele test.
- Voer de korte test in artifacts/GEGEVENSBRONNEN_EN_TEST.md uit zonder iets in te voeren of op te slaan. Controleer koude start, automatisch aangevinkte opgeslagen teamleden, de bekende opgeslagen ISO-week en hetzelfde project/week in Hours Summary; herhaal na sluiten/starten.
- Controleer met Monitor dat Project.Id-, Assignment.Id- en datumfilters en sortering naar SharePoint gaan, met relevante records buiten de eerste 500 lijstitems. Datarijlimiet blijft 500; een batch op de grens wordt bewust afgewezen. Geen serverpaginering toegevoegd.
- De invoer toont actieve huidige project-/teamkoppelingen. Historische uren van inactieve/andere-teamkoppelingen horen in Hours Summary en verschijnen niet automatisch als huidige invoerrij. Een andere project/team/weekselectie is geen ontbrekende brondata.
- Afwijkende sleutels worden niet automatisch gecorrigeerd. Bij een melding de bestaande records laten onderzoeken, geen vervangende records invoeren. De gegevens blijven behouden; opslag kan bewust geblokkeerd zijn.
- Er is geen transactionele serversnapshot bij gelijktijdig wijzigen. De jaargrenzen komen uit alle toegankelijke Hours-regels; de geselecteerde invoer blijft beperkt tot gekozen project/team/week. Een ongeldige werkdatum in Hours blokkeert de bepaling van het jaarbereik met uitleg.
- Een nieuwe build onthoudt geen vorige schermselectie of tijdelijke onopgeslagen wijzigingen. Alleen expliciet opgeslagen SharePoint-data blijft duurzaam beschikbaar.
- Een aparte testapp met deze lijsten schrijft bij expliciet Save of Save team naar dezelfde bestaande gegevens. Tijdens dit werk is niets in SharePoint geschreven; productie is niet overschreven of gepubliceerd.

Eerstvolgende stap: importeer de nieuwste testapp, gebruik dezelfde toegestane SharePoint-verbinding en voer de korte terugleestest uit zonder invoer/opslag. Geef bij ontbreken van data de exacte status-/Notify-melding en gekozen project/team/ISO-jaar/KW door, plus een eventuele App Checker-/Monitor-fout.


## Laatste opdracht: vaste onderste navigatie en acties bij inhoud

Geïmplementeerd:
- Alle drie schermen hebben een vaste onderste balk (GroupContainer@1.5.0, ManualLayout), Height=72, Y=Parent.Height-Self.Height, buiten de scrollende galleries. Navigatieknoppen staan daarin op Y=16, Height=40.
- Screen1: bestaande knoppen Weekly Hours en Hours Summary verplaatst naar navProjectTeam, met 12 px tussenruimte. De bestaande project-/teamvalidaties, acties en DisplayMode zijn behouden. Save team en de selectieteller staan boven de navigatie bij de medewerkersgallery. De galleryhoogte eindigt boven deze actierij; de selectievelden zijn onder een afzonderlijke blauwe titel Project / team geplaatst. Breedte van de medewerkerkaart volgt nu de gallerybreedte.
- scrHours: blauwe titel Weekly Hours bevat uitsluitend de titel. Jaar/KW en Save staan op de inhoudsrij eronder. De ureninvoergallery eindigt 12 px boven navWeeklyHours. Een nieuwe knop Project / team geeft een terugroute; die is uitgeschakeld bij varWeekSaving of verschillen tussen colWeekRows en colWeekOriginal, overeenkomstig de bestaande beveiliging van de weekkeuzes. Bestaande invoer-/opslagacties zijn behouden.
- scrWeeklyHours: Project / team staat in navHoursSummary. Refresh staat bij de project-/werkgeverselecties op Y=148, buiten de titelbalk. Selecties hebben voldoende ruimte naast Refresh. De vier periodekeuzes gebruiken schermbreedteafhankelijke breedtes. Rapporttotaal staat 12 px boven de onderbalk; de tabel eindigt 12 px boven het totaal. De titelbalk bevat alleen Hours Summary.
- Bestaande knopteksten, OnSelect, OnChange, OnCheck, OnUncheck, Items, Default, Visible en DisplayMode zijn vergeleken en behouden. De nieuwe terugknop is de enige nieuwe navigatieactie. Bestaande reken-, filter- en opslagformules zijn niet aangepast. De knopstandaard blijft toegepast; geen AccessibleLabel op Classic/Button@2.2.0 toegevoegd.

Gewijzigde bestanden:
- Src/Screen1.pa.yaml, Src/scrHours.pa.yaml, Src/scrWeeklyHours.pa.yaml: plaatsing, vaste balken, inhoudsruimte en bovengenoemde nieuwe titel/terugknop.
- AGENTS.md: blijvende regels voor titelbalk, vaste navigatie, acties bij inhoud, reservering van ruimte en controle van gewijzigde parents.
- PROJECT_STATUS.md, artifacts/VALIDATIE.md en latest-functional-test.json: actuele resultaten, testinstructies en buildpad.
- artifacts/Place-Navigation.ps1: eenmalig lokaal plaatsingsscript; voer dit niet opnieuw uit op reeds aangepaste bron zonder de uitgangssituatie te herstellen.
- artifacts/Test-NavigationLayout.ps1: gedragvergelijking met backup, control-/syntaxcontrole, controle van navigatieparents en numerieke evaluatie van de werkelijke layoutformules.
- artifacts/Check-WeeklySource.ps1: mapping Classic/TextInput naar het oorspronkelijke template 'text' toegevoegd, zodat bestaande ureninvoercontrols ook kunnen worden gecontroleerd.
- Backup buiten Src: checkpoints/navigation-20261020_172627. App.pa.yaml, _EditorState.pa.yaml en de oorspronkelijke .msapr zijn niet gewijzigd.

Daadwerkelijk technisch gecontroleerd:
- Drie oorspronkelijke navigatieacties geïnventariseerd; alle bestaande en de ene nieuwe Navigate-knop staan nu als kinderen in de vaste onderbalken. De balken zijn directe kinderen van het scherm en scrollen niet mee met de gallery-inhoud volgens de controlstructuur.
- 1194 Power Fx-formules geparsed: nul syntaxfouten. Alle 82 controls tegen de gerichte structuurregels en bestaande templates gecontroleerd (19 Screen1, 29 scrHours, 34 Hours Summary).
- Bestaande gedrags-/selectie-eigenschappen per controlnaam en OnVisible per scherm met de backup vergeleken: behouden ondanks hergroepering. De beschermde bestaande teksten zijn ook gelijk.
- Werkelijke X/Y/Width/Height-formules met de lokale Microsoft Power Fx-interpreter numeriek geëvalueerd op 768x600, 1024x768, 1280x720, 1366x768 en 1920x1080. Alle controles geslaagd: navigatieknoppen binnen balk, gallerys en totalen erboven, Refresh vrij van selecties, 12 px afstand tussen naast elkaar geplaatste navigatieknoppen. Parent en Self zijn hiervoor als lokale numerieke context gemodelleerd; er is geen browserrendering uitgevoerd.
- PAC SourceCode-pack succesvol, afsluitcode 0. Alle bronnen in de ZIP exact gelijk aan de huidige Src; DataSources.json, Templates.json en Properties.json inhoudelijk exact gelijk aan de oorspronkelijke .msapr-metadata. Geen productieapp of eerdere testbuild overschreven/publiceerd.
- Logs naast de nieuwste testapp: navigation-checks.txt, package-checks.txt en pac-pack.txt. Geen nieuwe functionele uren- of serverdelegatietest uitgevoerd; eerdere rekencontroles hieronder zijn historisch.

Openstaande Studio-/browsercontroles en beperkingen:
- Importeer als aparte testapp; controleer App checker op Canvas-binding, gewijzigde parents en schemafouten. Een geslaagde pack/parser/templatecontrole is geen geslaagde Studio-import.
- Controleer op alle drie schermen de blauwe titelbalk, vaste onderste navigatie bij galleryscrollen, volledige teksten, zichtbare laatste tabelrijen, selectieteller en rapporttotaal. Controleer visueel de genoemde vijf formaten en de werkelijke browserzoom.
- Test de bestaande project-/teamvalidatie bij navigeren naar Weekly Hours, beide navigatieknoppen op Screen1 en terug via Project / team. Controleer dat de nieuwe terugknop in Weekly Hours blokkeert bij onopgeslagen uren en tijdens opslaan, en na geslaagd opslaan weer werkt.
- Controleer Save team, Save en Refresh bij de inhoud; hun bestaande acties en toestanden mogen niet veranderen. Test de bestaande rapport-/urencontroles uit artifacts/VALIDATIE.md.
- De numerieke layoutcontrole is beperkt tot de genoemde formaten vanaf 768x600. Kleinere afmetingen zijn niet gecontroleerd; dit is geen volledige telefoon-/responsive-herbouw. Langere dynamische teksten en browserfonts vereisen visuele inspectie.
- Eerdere beperkingen over datarijlimiet 500, echte delegatie, ontbrekende serversnapshot en historische koppelingen blijven gelden. Export is niet gebouwd.

Eerstvolgende stap: importeer de nieuwste aparte testbuild, voer App checker uit en test de vaste navigatie bij scrollen, de actieplaatsing en de beveiliging bij onopgeslagen uren. Daarna de eerdere rapportage-/delegatietests afronden.


## Laatste opdracht: consistente zichtbare tekstknoppen

Geïmplementeerd:
- De zes zichtbare actie-/navigatieknoppen gestandaardiseerd: Screen1.btnGotoHours, btnAddtoTeam, btnGotoHoursSummary; scrHours.btnSaveWeek; scrWeeklyHours.btnSummaryProjectTeam en btnRefreshReport.
- Height 40, Segoe UI, Size 14, Semibold, Align.Center, VerticalAlign.Middle, verticale padding 0, horizontale padding 16 en vier hoekradii 8. Deze eigenschappen zijn gecontroleerd tegen het bestaande Classic/Button@2.2.0-template.
- Screen1: Weekly Hours breedte 160; Save team breedte 160, direct na Weekly Hours met 12 px; Hours Summary breedte 180, direct na Save team met 12 px. Alle drie Y=701. Rij beslaat X=310 t/m 834 (voorheen tot 840); geen extra horizontale ruimte nodig.
- Hours Summary: Refresh Y=32/Height=40, Project / team breedte 160 met dezelfde Y en precies 12 px vóór Refresh. Beide passen binnen de bestaande titelstrook Y=24 t/m 80. De onderste rand van de knoppen ligt op Y=72, boven de toelichting Y=80.
- Weekopslaan blijft op de bestaande locatie met breedte 140, nu expliciet volgens de opmaakstandaard.
- Verborgen btnBuildReport, beide compacte pijlknoppen en alle andere pictogramcontrols geheel behouden. Geen containers aangepast: de rijen passen binnen de bestaande beschikbare ruimte. Tekstpassing is ruim ingeschat via de expliciete breedtes; werkelijke rendering moet nog visueel worden gecontroleerd.
- Gewijzigd: Src/Screen1.pa.yaml, Src/scrHours.pa.yaml, Src/scrWeeklyHours.pa.yaml (uitsluitend opmaak/positie), AGENTS.md (standaard), PROJECT_STATUS.md, artifacts/VALIDATIE.md en buildmanifest. artifacts/Style-Buttons.ps1 bevat het gebruikte lokale opmaakscript.
- Backup buiten Src: checkpoints/buttons-20261020_172050.

Daadwerkelijk technisch gecontroleerd:
- Vergelijking van alle bronnen met de backup: uitsluitend 81 toegestane stijl-/positie-eigenschappen op de zes doelknoppen verschillen. Alle acties, teksten, kleuren, Visible, DisplayMode, oorspronkelijke overige eigenschappen en uitgezonderde controls zijn behouden. App.pa.yaml en _EditorState.pa.yaml ongewijzigd.
- Alle 1131 appformules met de Microsoft Power Fx-parser gecontroleerd: nul syntaxfouten. Hours Summary afzonderlijk: 380 formules en 33 controls door de gerichte structuur/templatecontrole; alle zes aangepaste knopcontrols ook afzonderlijk tegen bestaande templates gecontroleerd. Geen AccessibleLabel toegevoegd.
- PAC SourceCode-pack succesvol, afsluitcode 0, naar nieuw apart bestand. Alle gepakte YAML-bronnen exact gelijk aan actuele Src. Productie en eerdere builds niet overschreven of gepubliceerd.
- De 30 rekentests zijn in deze opmaakopdracht niet opnieuw uitgevoerd: geen berekenings- of gedragsformules gewijzigd. Eerdere resultaten hieronder zijn historisch.

Openstaand:
- Studio-import, App checker en visuele test van uitlijning, tekstpassing (ook Saving...), 12 px tussenruimte, beide titelbalkknoppen en het project-/teamknoppenblok.
- Controleer de layout bij de gebruikte browser-/venstergrootte en zoom, en klik alle zes knoppen om bestaand gedrag en disabled-/savingtoestanden te bevestigen. Er is geen browserrendering uitgevoerd; dit is geen claim dat elk vensterformaat functioneel getest is.
- Eerdere openstaande rapportage-/delegatiecontroles blijven gelden. Export is niet gebouwd.

Eerstvolgende stap: importeer de nieuwste aparte opmaaktestbuild, voer App checker uit en controleer de knoplayout en acties op alle drie schermen. Een geslaagde pack bewijst geen geslaagde Studio-import of visuele test.


## Laatste opdracht: Weekly Hours versus Hours Summary

Geïmplementeerd:
- Weekly Hours is de ureninvoer op scrHours (Mon t/m Sun). Hours Summary is het administratieve overzicht op scrWeeklyHours. De interne schermnaam scrWeeklyHours is behouden.
- Src/scrWeeklyHours.pa.yaml: zichtbare titel Hours Summary; toelichting dat opgeslagen uren worden samengevat en invoer via Weekly Hours gaat; knop Project / team naar Screen1.
- Src/Screen1.pa.yaml: bestaande knop Hours hernoemd naar Weekly Hours. Knop Hours Summary toegevoegd naar scrWeeklyHours, omdat een rapportagelink in de huidige bron ontbrak. Bestaande project-/teamcontroles voor ureninvoer zijn behouden.
- Src/scrHours.pa.yaml: uitsluitend een label Weekly Hours toegevoegd. Invoer, opslag en Mon–Sun-berekeningen zijn behouden.
- AGENTS.md: functioneel onderscheid en latere .xlsx-exportafspraak vastgelegd. Apart bestand per project/werkgever, nulperiodetotalen uitsluiten, projectnummer/reference/werkgever/periode bovenaan, naam/weektotalen/periodetotaal in tabel, downloaden en opslaan, geen automatische e-mail. Export is NIET gebouwd.
- PROJECT_STATUS.md, artifacts/VALIDATIE.md en latest-functional-test.json bijgewerkt. Backup vóór wijziging: checkpoints/naming-20261020_135709, buiten Src.

Daadwerkelijk technisch gecontroleerd:
- Eigenschapsvergelijking van alle bronbestanden met de backup: alleen twee bestaande teksteigenschappen gewijzigd (rapporttitel en navigatieknop). Geen bestaande eigenschappen verwijderd. De overige wijzigingen zijn vier nieuwe controls voor titel, toelichting en navigatie. Alle bestaande selectie-, laad-, filter-, groep-, week- en opslagformules zijn behouden.
- Alle 1071 Power Fx-formules in de appbronnen geparsed: geen syntaxfouten. Het overzicht afzonderlijk: 360 formules en 33 controls door de gerichte structuur/templatecontrole. Dit is geen volledige Canvas-bindingvalidatie.
- Alle 30 lokale rekenassertions geslaagd. Geen AccessibleLabel toegevoegd aan de nieuwe Classic/Button@2.2.0-controls.
- Nieuwe aparte PAC SourceCode-pack succesvol, afsluitcode 0. Alle YAML-bestanden in de ZIP exact gelijk aan de actuele Src-bestanden. Productie en eerdere testbuilds niet overschreven of gepubliceerd.
- App.pa.yaml en _EditorState.pa.yaml zijn behouden; nieuwe navigatie verwijst naar bestaande interne schermnamen.

Nog open / beperkingen:
- Studio-import van deze build, App checker, de eerdere PA2108-correctie, volledige Canvas-binding en functionele gegevensverwerking zijn niet uitgevoerd of geclaimd.
- Test de zichtbare titels, navigatie Screen1 → Weekly Hours / Hours Summary en Hours Summary → Project / team, de layout van de nieuwe labels/knoppen, en project-/teamkeuze vóór ureninvoer.
- Test ongewijzigde project-/werkgever-/periodefilters, één week/jaargrens/KW53, historische werkgevers, actieve nulrijen, weekverschuiving en totaalcijfers.
- Controleer SharePoint-delegatie, foutafhandeling en volledigheid met Monitor zoals eerder beschreven. Datarijlimiet 500 blijft vereist; de eerdere beperkingen gelden nog.
- Geen exportfunctie aanwezig. Die volgt pas in een volgende opdracht na acceptatie van Hours Summary.

Eerstvolgende stap: importeer de nieuwste Hours Summary-testbuild als aparte app, controleer App checker en voer de naamgevings-, navigatie- en rapportagetests uit. Een geslaagde pack is geen geslaagde Studio-import of functionele test.


## Laatste correctie: PA2108 bij Classic/Button@2.2.0

- Gebruiker meldde twee daadwerkelijke Studio-importfouten: AccessibleLabel wordt niet ondersteund door Classic/Button@2.2.0. De eerdere lokale algemene eigenschapscontrole miste dit; de eerdere geslaagde structuurcontrole bewees dus geen geslaagde import.
- In Src/scrWeeklyHours.pa.yaml uitsluitend de twee AccessibleLabel-regels van btnReportPreviousWeeks en btnReportNextWeeks verwijderd. De volledige schermtekst is vergeleken met de vorige testbuild na uitsluitend die twee verwijderingen: exact gelijk. Acties, teksten, posities en overige instellingen zijn behouden.
- Alle appbronnen doorlopen: zeven Classic/Button@2.2.0-controls gecontroleerd, geen AccessibleLabel meer aanwezig. Acht AccessibleLabel-eigenschappen bij andere controltypen zijn behouden.
- artifacts/Update-WeeklySource.ps1 aangepast zodat het de twee ongeldige eigenschappen niet terugplaatst. artifacts/Check-WeeklySource.ps1 aangescherpt met expliciete PA2108-controle en AccessibleLabel uit de algemene toegestane basiseigenschappen verwijderd.
- Schema-eis vastgelegd in AGENTS.md. Status, buildmanifest en buildverwijzing in artifacts/VALIDATIE.md bijgewerkt.
- Daadwerkelijk uitgevoerd: 346 Power Fx-formules zonder syntaxfouten; 31 controls door de gerichte structuur/templatecontrole; 30 lokale rekenassertions geslaagd. Alle bronnen in de nieuwe ZIP exact vergeleken met de actuele Src-bestanden.
- Nieuwe aparte PAC SourceCode-pack geslaagd, afsluitcode 0; productie en eerdere builds niet overschreven. PAC-log staat naast het nieuwe testbestand.
- Studio-import van deze correctie is OPENSTAAND. Eerst opnieuw importeren als aparte testapp en controleren dat beide PA2108-meldingen verdwenen zijn; daarna App checker en de eerder beschreven functionele/Monitor-tests uitvoeren. De pack en lokale controles bewijzen geen geslaagde Studio-import of juiste gegevensverwerking.


## Laatste opdracht: voorbereiding functionele test — 20 oktober 2026

### Review van de zes hoofdbestanden

Er is geen .git-map in de bron- of projectmap en Git is hier niet beschikbaar. De IDE-lijst van exact zes gewijzigde bestanden is niet meegeleverd. De zes hieronder zijn de hoofdbestanden uit de vorige oplevering; dit is geen geverifieerde Git-changelist. Voor het scherm en AGENTS.md is checkpoint 20261020_104809 gebruikt. De overige vier bestanden zijn in de vorige opdracht toegevoegd en hebben lokaal geen oudere volledige baseline; daarvan is de huidige inhoud beoordeeld. Aanvullende formulekopieën, het eenmalige herstelscript, schema en gegenereerde artifacts zijn ook bekeken.

| Bestand | Waarom gewijzigd / reviewresultaat |
| --- | --- |
| Src/scrWeeklyHours.pa.yaml | Verschillen met checkpoint betreffen gegevensophaling/foutafhandeling, project-/contractor- en periodekeuzes, 0-rijen, formatering en gezamenlijke weekverschuiving. Exportvoorbereiding verwijderd conform scope. Geen schermwijziging nodig in deze voorbereidingsopdracht. Eigenschapsverschillen staan in artifacts/weekly-property-diff.json. |
| AGENTS.md | Tijdelijke voortgang verplaatst naar dit statusbestand; blijvende afspraken, scopescheiding en technische randvoorwaarden vastgelegd. Geen nieuwe functionele scope geïntroduceerd. Deze opdracht niet gewijzigd. |
| PROJECT_STATUS.md | Voortgang, controlebewijs, beperkingen en huidig buildpad vastleggen. In deze opdracht bijgewerkt met deze review en de nieuwe testbuild. |
| artifacts/VALIDATIE.md | Korte Studio-/Monitor-checklist plus reproduceerbare referentietotalen. Buildverwijzing bijgewerkt naar de nieuwe aparte testversie. |
| artifacts/Check-WeeklySource.ps1 | Controleert huidige YAML-syntaxis, de 348 Power Fx-formules, een gerichte subset van de structuur en 31 controls tegen bestaande templates. Controleert geen volledige Canvas-binding. Deze opdracht niet gewijzigd. |
| artifacts/Test-WeeklyCalculations.ps1 | ISO-, periode-, contractor-, nul- en grensberekeningen met synthetische gegevens. Review vond dat formulekopieën werden gelezen: nu leest de test rechtstreeks de huidige OnSelect-formules uit Src/scrWeeklyHours.pa.yaml. Ongebruikte aggregatie-extractie verwijderd. Geen claim dat de volledige laad-/rapportprocedure is uitgevoerd. |

Geen onbedoelde appwijzigingen buiten Weekly Hours gevonden binnen de beschikbare vergelijkingsbasis. App.pa.yaml, Screen1.pa.yaml, scrHours.pa.yaml en _EditorState.pa.yaml zijn qua UTF-8-tekst exact gelijk aan de ingepakte SiteManagement_Baseline.msapp. De nieuwe build bevat alle actuele bronbestanden; DataSources.json, Templates.json en Properties.json zijn exact gelijk aan de oorspronkelijke .msapr-metadata. De productieapp en bestaande testbestanden zijn niet overschreven.

### Deze opdracht daadwerkelijk uitgevoerd

- Huidige bron en bovenstaande zes bestanden inhoudelijk beoordeeld; scherm op eigenschapsniveau vergeleken met checkpoint. Geen volledige historische diff voor de vier nieuwe documenten/scripts beschikbaar.
- Test-WeeklyCalculations.ps1 uitgevoerd op de actuele YAML: 348 formules zonder parserfouten, 31 controls door de gerichte structuur/templatecontrole en alle 30 lokale assertions geslaagd.
- PAC SourceCode-pack uitgevoerd met nieuw, uniek uitvoerpad; afsluitcode 0. Logbestanden staan naast de nieuwe build: technical-checks.txt, pac-pack.txt en package-checks.txt.
- Gepakte bronnen vergeleken met Src; andere schermen vergeleken met baseline; verbindingen/templates/instellingen vergeleken met oorspronkelijke .msapr. Alle vergelijkingen geslaagd.
- Buildgrootte en SHA-256 vastgelegd in artifacts/latest-functional-test.json.

### Nog open en beperkingen

- Geen functionele Studio-test, App Checker-validatie, echte SharePoint-ophaling of Monitor-delegatiecontrole uitgevoerd. Een geslaagde pack bewijst dit niet.
- De syntax- en structuurcontrole bewijst geen geldige Canvas-naam-/typebinding; met name GroupBy/AddColumns en de geneste gallery vereisen Studio.
- De lokale rekentests voeren geïsoleerde expressies uit, niet de complete OnSelect-procedure, connectorfoutafhandeling of actieve 0-rij-opbouw. Die moeten functioneel worden getest.
- Afkapbeveiliging blijft afhankelijk van datarijlimiet 500 en werkelijke serverdelegatie. Batchgrenzen zijn alleen synthetisch getest; echte fout-/limietscenario's staan open.
- Alle overige bekende beperkingen hieronder blijven gelden. Export blijft buiten scope.

Eerstvolgende stap: importeer de nieuwste build onderaan als aparte testapp en volg artifacts/VALIDATIE.md. Rapporteer exacte App Checker- en Monitor-meldingen voordat de app functioneel geaccepteerd wordt.


## Huidige functionele stand

Geïmplementeerd in scrWeeklyHours, nog niet functioneel geaccepteerd in Studio:

- Projectkeuze uit de echte Projects-lijst; projectleden ophalen op Project.Id in plaats van het afgeleide ProjectKey.
- Contractorselectie met Alle contractors en unieke werkgever-ID's uit projecturen plus actieve projectleden. De historische werkgever komt uit Hours.Employer.
- Start ISO Year, Start KW, End ISO Year en End KW uit opgeslagen projecturen. Inclusieve eindweek, jaargrenzen en ISO-week 53. Iedere tussenliggende week krijgt een kolom, ook zonder uren.
- Automatische verwerking van keuzes; geen extra Load-knop. Refresh leest bronnen opnieuw. Projectkeuze blijft op ID bewaard en is afgeschermd tegen resetgebeurtenissen tijdens laden.
- Groepering per medewerker/werkgever; historische projectleden met uren blijven beschikbaar. Actieve projectleden krijgen zo nodig een 0-rij, ook bij een project zonder uren. In dat laatste geval zijn er geen periodekeuzes of weekkolommen.
- Volledige naam uit First Name/Surname, historische lookupnaam als terugval. Project Number en Project Reference blijven zichtbaar. Nederlandse urenweergave met aparte formaten voor gehele en gebroken uren; weekcellen en totalen zijn gecentreerd.
- Gezamenlijke weekverschuiving via vorige/volgende-knoppen. De niet in de oorspronkelijke templates aanwezige slider is verwijderd; alle 31 controls gebruiken bestaande controltypes en versies.
- Expliciete foutregistratie per refresh, gegevensophaling en rapportberekening. Iedere laadfout of afkapmelding houdt het rapport ongeldig; oude rijen en eindtotalen worden verborgen/gewist.
- Exportvoorbereiding uit de vorige opdracht is verwijderd uit het gewijzigde scherm. Export en de flow zijn buiten scope en niet ontwikkeld.

## Gewijzigde bestanden en reden

- Src/scrWeeklyHours.pa.yaml: bovenstaande herstelwerkzaamheden, leesbare formuleblokken en afgeschermde automatische selectieafhandeling.
- AGENTS.md: blijvende afspraken behouden, tijdelijke voortgang verwijderd en de scheiding met dit statusbestand vastgelegd. Huidige scope en technische randvoorwaarden toegevoegd.
- PROJECT_STATUS.md: nieuw status-/overdrachtsbestand.
- artifacts/VALIDATIE.md: actuele Studio-instructies en controleerbare rekenvoorbeelden; eerdere exportinstructies vervangen.
- artifacts/Check-WeeklySource.ps1: herhaalbare YAML-, Power Fx-syntax-, structuur- en controltemplatecontroles.
- artifacts/Test-WeeklyCalculations.ps1: lokale berekeningstests met de Microsoft Power Fx-interpreter en synthetische gegevens.
- artifacts/weekly-checks.txt en weekly-package-checks.txt: daadwerkelijke controleresultaten.
- artifacts/weekly-refresh.fx, weekly-build.fx en Update-WeeklySource.ps1: formulekopieën en het eenmalige lokale herstelscript. Src is de appbron; voer het herstelscript niet opnieuw uit na latere handmatige bronwijzigingen zonder deze kopieën bij te werken.
- artifacts/pa.schema.json: gedownload officieel Microsoft-schema, waarvan de inhoud YAML is ondanks de bestandsnaam. Gebruikt voor structuurregels, niet als volledige Canvas-bindingchecker.
- artifacts/preserved-screens.sha256.json: hashes vooraf voor behoudscontrole.
- Backup vóór deze opdracht: checkpoints/20261020_104809/scrWeeklyHours.pa.yaml en AGENTS.md, buiten Src.

Screen1.pa.yaml, scrHours.pa.yaml en App.pa.yaml zijn bytegewijs ongewijzigd volgens SHA-256. Bestaande verbindingen, controltemplates en appinstellingen zijn in de testbuild inhoudelijk gelijk aan de oorspronkelijke .msapr-metadata.

## Daadwerkelijk technisch gecontroleerd

- Lokale SharePoint-metadata gelezen: Projects.Title, Project Number/Project Reference; Workers.First Name/Surname/Employer; Project Workers.Project/Worker/Active; Hours.Work Date/Assignment/Employer/Hours. Geen nieuwe SharePoint-kolommen of flowparameters verzonnen.
- Datarijlimiet 500 en errorhandling=true in appmetadata bevestigd.
- Alle 348 Power Fx-formules uit de uiteindelijke YAML: 0 syntaxfouten met de lokaal aanwezige Microsoft Power Fx-parser.
- YAML geladen met YamlDotNet. Structurele regels van het officiële schema en 31 unieke controls met versies/eigenschappen tegen bestaande apptemplates gecontroleerd. Dit is een gerichte structuurcontrole, geen volledige Canvas-schemabinding.
- 30 lokale assertions geslaagd: negen ISO-datums inclusief 2020/53 en 2026/53, drie periodebereiken, vier periode-/contractorfilters, een lege weeksom, batchgrenzen 499/500/501 en het uitsluiten van een andere assignment-ID.
- Concrete lokale totalen: één week 2020/53 = 15,5; twee weken over jaargrens = 25,5; historische contractor 10 = 19,5; contractor 20 = 6.
- GroupBy/AddColumns-binding en Text-taalplaceholders konden niet met de losse interpreter volledig worden uitgevoerd: deze vereist hiervoor Canvas-functionaliteit. Daarover wordt geen geslaagde runtimetest geclaimd. De placeholders zijn getoetst aan Microsoft-documentatie.
- pac canvas validate geprobeerd: CLI 2.11.2 meldt dat dit commando niet meer ondersteund wordt.
- pac canvas pack --sources "." --layout SourceCode --msapp ".\artifacts\SiteManagement_WeeklyHours_Test_20261020.msapp" succesvol, afsluitcode 0. Laatste herbouw gebruikte --overwrite uitsluitend voor dit aparte testbestand.
- De uiteindelijke ZIP bevat exact de huidige YAML-bronnen (vergelijking met genormaliseerde regeleinden) en ongewijzigde DataSources.json, Templates.json en Properties.json. Geen publicatie of wijziging van de productieapp uitgevoerd.

## Nog niet gecontroleerd in Power Apps Studio

- Openen/importeren en verwerken van de gewijzigde YAML, App checker, volledige naam-/typebinding en gallerygedrag.
- Echte SharePoint-delegatie en sortering in Monitor, inclusief een relevante regel buiten de eerste 500 Hours-items.
- Volledige rapportopbouw per medewerker/contractor, actieve 0-rijen, een project zonder uren en werkgeverswisselingen met echte gegevens.
- Nederlandse getalnotatie in Canvas, browserlayout, weekverschuiving, jaar-/weekresets en projectkeuzebehoud bij Refresh.
- Foutinjectie/netwerkfout en batchlimietmelding met echte bronnen; nooit oude/gedeeltelijke totalen tonen.
- Regressie van bestaande navigatie en ureninvoer. Bronnen zijn behouden, maar dat vervangt geen functionele test.

## Bekende beperkingen en acceptatiestatus

- Dit is een technisch gecontroleerde testbuild, geen functioneel geaccepteerde app. Het acceptatiecriterium 'geen nieuwe formule- of schemafouten' is pas volledig aangetoond na Studio/App checker; lokaal is syntax/structuur gecontroleerd.
- Geen serverpaginering toegevoegd. Projecten en projectkoppelingen blokkeren vanaf 500 geladen items, uren vanaf 500 per assignment/kalenderjaar. Dit is bewust conservatief: ook exact 500 kan volledig zijn, maar wordt afgewezen omdat volledigheid niet bewezen is.
- Contractor- en jaarlijsten met meer dan 500 opties blokkeren vanwege de klassieke dropdownlimiet. Periodebereiken boven 50000 weken worden expliciet geweigerd.
- De beveiliging veronderstelt dat de datarijlimiet 500 blijft en dat de gedocumenteerd delegeerbare lookup-ID-, datumfilters en sortering daadwerkelijk naar SharePoint gaan. Dat laatste is nog een verplichte Monitor-controle; alleen afwezige waarschuwingen zijn onvoldoende bewijs.
- Laden kost per koppeling twee datumgrensqueries plus één query per kalenderjaar met mogelijk uren, en eenmaal per unieke medewerker een Workers-lookup. Grote projecten kunnen traag laden; fouten zoals throttling moeten het rapport blokkeren.
- De app kan projecthistorie alleen reconstrueren zolang historische Project Workers-koppelingen blijven bestaan. Verwijderde koppelingen kunnen niet betrouwbaar worden herleid; volgens projectafspraak worden ze inactief gezet.
- Een actieve medewerker zonder Worker-record/werkgever of een urenregel zonder historische werkgever/uren blokkeert het overzicht met een melding.
- Er is geen consistente serversnapshot bij gelijktijdige wijzigingen. Refresh haalt de huidige bronnen opnieuw op; acceptatie gebeurt met stabiele controlegegevens.
- De testapp behoudt de bestaande SharePoint-verbindingen. Uren opslaan schrijft naar de bestaande lijsten.
- Geen aanvullende gebruikersinformatie nodig voor de uitgevoerde lokale wijzigingen. Volledige acceptatie vereist nu Studio-toegang en de resultaten van de beschreven tests.

## Nieuwste testbuild

Nieuwste: Save week-fix + Trade Unknown (25-10-2026), zie het overzicht bovenaan:
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\savefix-trade-20261025_163517\SiteManagement_SaveFixTrade_20261025_163517.msapp
SHA-256: 1891281F7F62DF1F739BA282D11B8218DEDBECF74066027731394BF8CF4033C7 (101640 bytes). Niet geïmporteerd/goedgekeurd.

Vorige: de gecombineerde build (zie "Gecombineerde build" hieronder):
C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\combined-gea-20261022_134040\SiteManagement_CombinedGea_20261022_134040.msapp

Grootte: 100294 bytes.
SHA-256: C7616A268B6B6FF7F303F8E88C9C33D63B12674641EC598950BB5E338FCE3B6C

Studio-import, functionele test en goedkeuring door Eddy: openstaand. Goedgekeurde baseline: footer-row-20261020_215936.

## Eerstvolgende stap

Importeer deze aparte testbuild en voer artifacts/VALIDATIE.md uit. Geef eventuele App Checker-meldingen met control/eigenschap en Monitor-bevindingen terug. Herstel die in Src en herbouw de testapp. Begin pas na acceptatie van Weekly Hours aan de afzonderlijke exportopdracht.

## Bronnen

- Microsoft SharePoint-delegatie: https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/connections/connection-sharepoint-online
- Microsoft IfError en reeks acties: https://learn.microsoft.com/en-us/power-platform/power-fx/reference/function-iferror
- Microsoft dropdownlimiet: https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/controls/control-drop-down
- Microsoft Text en taalplaceholders: https://learn.microsoft.com/en-us/power-platform/power-fx/reference/function-text
- Officieel SourceCode-schema: https://go.microsoft.com/fwlink/?linkid=2304907
