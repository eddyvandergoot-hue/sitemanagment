# Projectregels (alleen geldende regels)

Bestaande Power Apps canvas-app voor site management; bouw voort op de bestaande app en de werkwijze van de Excel/VBA-versie. Begin elke opdracht met het lezen van de lokale bronbestanden. Documentkaart: README.md. Lees ROADMAP.md, MANUAL_STEPS.md, DECISIONS.md en NEXT_COMMANDS.md alleen als de opdracht erom vraagt. Archieven (*_ARCHIVE.md) niet lezen tenzij gevraagd.

## Project, paden, git
- Projectmap = bronmap = git-root: C:\Users\vandergoot.ed\Dev\Sitemanagment (Src, artifacts, Site Managment_VS.msapr, docs). Pack vanuit de projectmap.
- De oude OneDrive-map (OneDrive - GEA\Projects\Development\Sitemanagment) is een alleen-lezen backup; schrijf daar nooit.
- Scripts in artifacts gebruiken alleen paden relatief aan $PSScriptRoot; pointerbestanden (artifacts/*-backup.txt, *-builddir.txt, *-buildpath.txt) bevatten paden relatief aan de bronmap. Geen absolute paden in scripts of pointers.
- Git: branch main. Checkpoint = git commit vóór elke opdracht (werkboom schoon, daarna pas wijzigen). Geen mapkopieën in checkpoints/ (historisch, in .gitignore). Zet geen backupbestanden in Src (PAC weigert bestanden die niet op .pa.yaml eindigen).
- Push naar origin na een opdracht alleen als verifier (volledige set + pack) en reviewer (geen blokkerende bevindingen) slagen. Tag `approved-<datum>-<onderwerp>` alleen na Eddy's Studio-test en bevestiging (dan ook "approved by Eddy" in PROJECT_STATUS.md en de tag pushen); nooit op basis van pack of tests alleen. Laatste goedgekeurde tag: approved-20261026-savefix.
- Overschrijf of publiceer de bestaande productieapp niet automatisch.

## Platform
- Power Apps canvas (browser), SharePoint voor gegevens, Power Automate voor serververwerking/export, VS Code. Blijf bij canvas + SharePoint-lijsten; stel geen Dataverse/SQL voor. Een flow alleen voor aantoonbaar noodzakelijke verwerking.
- Power Platform CLI 2.11.2, layout SourceCode (niet Experimental). Vaste kopie: C:\Users\vandergoot.ed\Dev\Sitemanagment\pac\tools (in gebruikers-PATH; hele map nodig). Niet de extensiekopie gebruiken.
- Pack: `pac canvas pack --sources "." --layout SourceCode --msapp "<apart testbestand>.msapp"`. Import: make.powerapps.com, Apps, Import app, From file. Rapporteer bij iedere build exact pad en SHA-256 (Eddy controleert die vóór import).
- Gebruik uitsluitend geldige SourceCode-schema's, controlversies en eigenschappen; controleer Microsoft-documentatie bij twijfel. Verzin geen SharePoint-kolommen of flowparameters: controleer kolomnamen/typen in metadata en formules.

## Bestaande app
- Screen1 (zichtbaar "Project / team"): medewerkers selecteren en koppelen aan project en team.
- scrHours ("Weekly Hours"): uren invoeren in een weektabel, Mon t/m Sun.
- scrWeeklyHours ("Hours Summary"): administratieve samenvatting per week en medewerker/werkgever, met periodetotaal. Interne schermnamen en verwijzingen blijven.
- Bronnen: Projects, Employers, Workers, 'Project Workers', Hours; SharePoint-site https://geacloud.sharepoint.com/sites/GEASiteManagment. Testbuilds gebruiken dezelfde site en lijst-ID's; wijzig of vervang verbindingen niet. Een testapp schrijft bij expliciet opslaan naar dezelfde gegevens.
- Behoud Screen1, scrHours, bestaande verbindingen en werkende ureninvoer; wijzig ander onderdeel alleen indien noodzakelijk en licht dit toe.
- Latere onderdelen (nog niet gebouwd): beheerschermen, WorkPackages/planning/jobcards, foto's en bijlagen, documentgeneratie en consent agreements.

## Functionele afspraken
1. Workers, Employers en Projects zijn centrale lijsten. Project Workers koppelt een bestaande medewerker aan project en team; medewerkers worden niet opnieuw ingevoerd.
2. Een medewerker kan in dezelfde week op meerdere projecten werken. Actieve projectleden blijven zichtbaar in de ureninvoer, ook bij 0 uur of ziekte (ook met periodetotaal 0).
3. Geen verplichte inzetperiode. Team is een keuzelijst 1 t/m 10.
4. Trade: Workers.Trade en Hours.Trade zijn keuzekolommen Fitter / Welder / Unknown (Workers: standaard Unknown, verplicht). Documenten gebruiken de volledige naam. Historische Hours-regels kunnen F/W bevatten (F = Fitter, W = Welder); map bij rapportage.
5. Volledige naam = voornaam + achternaam.

## Uren en rapportage
- Ureninvoer: tabel per werkweek, Mon t/m Sun, met weektotaal. Hele uren zonder losse komma/punt. Uren en weekkoppen gecentreerd.
- Weeklabel overal "YYYY KWxx": ISO-jaar = Year(maandag+3), KW twee cijfers via ISOWeekNum (01-01-2027 geeft "2026 KW53"). ISO-jaren moeten correct werken rond de jaarwisseling en week 53.
- Weekly Hours: één datumkiezer dpHoursWeek (ModernDatePicker@1.0.0, "dd-mm-yyyy", StartOfWeek.Monday, 256 px, geen StartDate/EndDate), vrije keuze, standaard week van vandaag; veldlabel "Week", lblHoursWeekKW ernaast.
  - Gekozen dag (varHoursPickedDay) blijft zichtbaar; varHoursWeekMonday = maandag; DefaultDate = Coalesce(varHoursPickedDay, Today()).
  - OnChange: overgeslagen tijdens laden/opslaan; andere week laadt (Select(btnReadWeek)); andere dag in dezelfde week bewaart alleen de dag; met onopgeslagen uren Reset + melding en niet laden; OnChange na Reset is no-op. Geen Reset na gewone keuze. DisplayMode uit tijdens laden/opslaan of onopgeslagen invoer. Geen Load-knop.
  - Alle selectiecontroles (invoer, cache-hit, Save-guard) gebruiken varLoadedWeekMonday = varHoursWeekMonday; varWeekLoadedISOYear/KW volgen uit de geladen maandag.
- Hours Summary: periode met twee datumkiezers From/Till (dd-mm-yyyy); From naar maandag, Till naar zondag; altijd volledige ISO-weken, meerdere jaren toegestaan, één kolom per week plus periodetotaal per medewerker. Zelfde week = één week; Till vóór From blokkeert met melding (ValidationState.Error op Till). Selecteerbare datums en standaardperiode komen uit beschikbare uren (maandag eerste t/m zondag laatste week met uren). Projectnummer en project reference horen in rapport en export. Rapportperiode: varReportFrom = varReportStartMonday, varReportUntil = varReportEndSunday + 1 dag (exclusief); basis voor export.
- Datumkiezers Hours Summary (ModernDatePicker@1.0.0, Monday, geen Load-knop, OnChange overgeslagen bij varReportBusy): geen zichtbare normalisatie; gekozen dagen in varReportFromPickedDay/varReportUntilPickedDay; DefaultDate = Coalesce(gekozen dag, varReportStartMonday / varReportEndSunday). OnChange bewaart de dag, normaliseert naar varReportStartMonday/varReportEndSunday en bouwt alleen bij gewijzigde weekgrens via Select(btnBuildReport). Reset van de kiezers alleen bij laden (eerst gekozen dagen wissen, dan Reset) of bij een geblokkeerde wijziging; nooit na gewone keuze. lblReportFromWeek/lblReportUntilWeek ("YYYY KWxx", From = week van varReportStartMonday, Till = week van varReportEndSunday) staan rechts uitgelijnd in de labelrij, zelfde X/Y/breedte/hoogte als het veldlabel, Inter/Arial 12 Normal zwart. Geen aparte perioderegel.

## Gegevens en sleutels
- SharePoint bevat de blijvende gegevens; collections zijn tijdelijke caches en selecties sessiestaat. Een lege collection/selectie bewijst geen dataverlies. Bij incidenten eerst savepad, Modified/Modified By en versiegeschiedenis onderzoeken; geen nieuwe lijsten, testdata of automatische correcties.
- Project Workers: Project, Worker, Team, Active, AssignmentKey (= project-ID|worker-ID), ProjectKey. Hours: 'Work Date', Assignment, Employer, Team, Trade, Hours, EntryKey (= AssignmentKey|yyyymmdd); geen aparte ISO-jaar/KW-kolommen (afleiden uit Work Date).
- Gebruik echte lookup-ID's voor project-, medewerker- en werkgeveridentiteit. Bewaar de werkgever op de urenregistratie (historie); een latere werkgeverswijziging verplaatst oude uren niet. Employer Code (EMP-001) is uniek; maak geen tweede handmatige identificatie.
- Trade op Hours is een momentopname van Workers.Trade bij opslaan: Patch als `{Value: <trade>}`, nooit `Choices()`. Bestaande Hours-regels krijgen nooit een herschreven Trade/Employer.
- Historische projectkoppelingen worden inactief gezet, niet verwijderd. Schrijf of repareer sleutels nooit automatisch tijdens laden.

## Laden en opslagveiligheid
- Laadacties doen geen Patch/Update/Remove en maken geen lijsten of testdata; Save week en Save team blijven de enige opslagroute. Bij onvolledige/afwijkende sleutels: opslaan blokkeren, gegevens laten controleren.
- Laadstatussen NotLoaded, Loading, Failed, Loaded; alleen volledig en foutloos Loaded mag opslaan. Bewaar geladen project-/team-ID's, ISO-jaar/KW, weekmaandag, rijaantallen en originele snapshot los van de selectiecontrols. Toon onderscheid tussen ontbrekende selectie, lege geldige selectie en laad-/verbindingsfout; blokkeer opslaan na een mislukte of onvolledige load.
- Laad eerst naar tijdelijke staging-collections; vervang selectie/invoer/originele uren pas na een volledig geslaagde load. Bij fout: oude gegevens alleen-lezen behouden, selectie niet als geladen markeren, fout tonen. Onopgeslagen invoer blokkeert Refresh en herladen, ook in OnSelect/loader. Een volledig Loaded selectie (zelfde project/team/week en versie) wordt hergebruikt; Refresh forceert via force-vlaggen; varTeamDataVersion maakt Weekly Hours ongeldig na een teamload.
- Actieve bron: directe lookup-ID-/datumloaders, staging-collections en lokale rapportberekening; geen geneste week-/projectcaches of epochguards. Breng cacheoptimalisaties pas terug na afzonderlijke Studio-binding-, fout- en functionele tests.
- Iedere Save heeft exact dezelfde volledige toelatingscontrole in DisplayMode en als eerste OnSelect-voorwaarde (mismatch, ontbrekende originele rijen, laadfout, lopende load/opslag, afwijkende sleutels = geen mutatie). DisplayMode alleen is geen veiligheidsgrens.
- Lege/onvolledige collection is geen opdracht tot deactiveren, verwijderen of uren wissen. Save team met lege selectie is geblokkeerd; deactivering vereist expliciete verwijdering van een oorspronkelijk geladen medewerker.
- Pre-save validatie: alle lokale validatie per wijziging (ook expliciete 0) loopt vóór de eerste read/write; fouten worden verzameld; één fout betekent nul writes. Nul writes + fout: toon de echte reden, week blijft Loaded. ≥1 write + fout: Failed, opslag geblokkeerd, invoer behouden, geen automatisch ongedaanmaken (controleer per item aantoonbare vorige waarden voordat herstel wordt voorgesteld). Beide Saves zijn geen SharePoint-transactie.
- Save week controleert bij een bestaande EntryKey ook Assignment-ID en Work Date, en: koppeling/sleutel consistent, medewerker in colWorkersCache, Employer.Id/Value, Trade (Unknown toegestaan, leeg blokkeert), Team, uren 0-24 met max 2 decimalen. Meldingen zeggen wat in SharePoint moet worden aangepast.
- 500-rijbeveiliging: datarijlimiet 500 blijft; verlaag niet zonder de afkapcontroles te herzien; verhogen bewijst geen volledigheid. Een bereikte batchgrens blokkeert het hele rapport; toon geen deeltotalen of afgekapte resultaten als compleet. Maximaal 500 keuzeregels in een klassieke dropdown.
- IfError rond een reeks acties met puntkomma's stopt niet gegarandeerd na een fout: controleer risicovolle stappen apart en geef een rapport pas vrij zonder fouten.
- Controleer SharePoint-indexen online (lokale metadata bewijst niets); een lookupindex lost de List View Threshold niet op.

## Delegatie en queries
- Lookup-ID's (Project.Id, Worker.Id, Assignment.Id) zijn niet filterbaar; filter daarna lokaal. Project Workers uitsluitend op `ProjectKey = <vooraf berekende tekst>` (geen OR/StartsWith-fallback). Hours op `StartsWith(EntryKey, "<id>|")` (altijd met afsluitend "|") plus 'Work Date'-bereik.
- Predicaten op SharePoint-bronnen gebruiken alleen kolommen, functies en globale variabelen (Set): geen With-namen of ForAll-recordvelden. Hours: `StartsWith(EntryKey, varXxxQueryPrefix)`; datumvensters met globale var of `DateAdd(globale var, constante, ...)`; dagterugval uitschrijven, niet via ForAll. Bekende uitzondering: maand-/dagpaginering van Hours Summary binnen `ForAll(Sequence(monthCount))`.
- Groepsberekeningen pas op expliciet geladen lokale gegevens. Geen `Choices()` en geen remote LookUp/Filter binnen ForAll of per cel/medewerker/label.
- Caches (colWorkersCache/colProjectsCache) vullen met expliciete ForAll-recordprojectie met weergavenamen ({ID, 'First Name', Surname, 'Employer Name', Employer, Trade}; projecten {ID, Title, 'Project Number', 'Project Reference'}), niet met ShowColumns (geeft interne namen field_x).
- Lookupwaarden lokaal opbouwen: Assignment `{Id, Value: Project Workers.Title}` uit colWeekAssignments; Employer `{Id, Value}` uit colWorkersCache.Employer; Team/Trade als `{Value}`. Metadata: Hours.Assignment.Value = Assignment/Title, Employer.Value = Employer/Title, Team/Trade IsChoice.
- `Concurrent` alleen voor onafhankelijke loads; elke tak schrijft naar zijn eigen foutcollection, samenvoegen erna. Stringliterals bevatten geen regeleinde.
- Verifieer werkelijke serverqueries in Studio/Monitor; verberg geen delegatiewaarschuwingen.

## Opslaan in batch
- Save week = 1 pre-read + table Patch(es) + 1 verify read, met hetzelfde filter: `Filter(Hours, StartsWith(EntryKey, "<projectID>|") && 'Work Date' >= maandag && < maandag+7)`. Volle batch (500) valt terug op 7 dagbatches; een volle dag blokkeert. colWeekOriginal wordt alleen vanuit de verify read bijgewerkt.
- Hooguit twee table-Patches: bestaande regels alleen Title + Hours; nieuwe regels volledig record. Niet samenvoegen (lege kolommen zouden bestaande Employer wissen). Basisrecords komen uit de pre-read-collection.
- Save team = 1 pre-read + hooguit 2 table-Patches (upsert, deactivering). Pre-read: `Filter('Project Workers', ProjectKey = varTeamSaveProjectKey)` inclusief inactieve; `varTeamSaveProjectKey = Text(varTeamLoadedProjectID)` vooraf gezet. Bij ≥500 rijen of `Project.Id <> varTeamLoadedProjectID`: fout, nul writes. Match lokaal op `AssignmentKey = varTeamSaveProjectKey & "|" & Text(person.ID)`; verwijderingen vóór de eerste write gecontroleerd. Risico: koppeling met lege/afwijkende ProjectKey wordt niet gevonden en kan dubbel ontstaan.
- Trace `DIAG|SaveWeek|End` registreert ElapsedMs, Changes, Reads, Writes, PatchedRows, VerifiedRows, Errors.

## Knoppen, footer, titelbalk
- Zichtbare knoppen: Height 40; Font ="Inter, Arial, sans-serif"; Size 14; Semibold; Align.Center en VerticalAlign.Middle waar ondersteund; PaddingTop/Bottom 0, Left/Right 16; ondersteunde radii 8; naast elkaar dezelfde Y en 12 px tussenruimte; breedte laat volledige tekst passen (huidig: Weekly Hours 170, Hours Summary 190, Project / team 180, Refresh 110, Save team 160, Save 140, pijlen 48). Verborgen technische knoppen uitgezonderd. Behoud teksten, OnSelect, Visible, DisplayMode.
- Titelbalk (blauw) bevat alleen de schermtitel; Hours Summary rechts de alleen-lezen projectregel lblReportProjectDetails ("Project Number: ... | Project Reference: ..." via LookUp op ddReportProject.Selected.ID, wit, rechts uitgelijnd, PaddingRight 24; lblWeeklyHoursTitle vaste 400 px (logo + titel); labels overlappen niet). Geen knoppen in de titelbalk.
- GEA-logo: uitsluitend het officiële bestand Assets/GEA_logo_white.svg, ongewijzigd (nooit hertekenen, omkleuren of rekken); wit logo alleen op Vibrant Blue #0303B8. Eén Image@2.2.3-control (Image = mediaresource GEA_logo_white) links in de titelbalk van elk scherm: imgLogoScreen1, imgLogoHours, imgLogoSummary; een toekomstig Home-scherm krijgt hetzelfde. 99x30 px, ImagePosition Fit, X = titel-X+15, verticaal gecentreerd in de balk van 56 px (13 px boven/onder; de vrije ruimte ≥15 px geldt horizontaal), AccessibleLabel "GEA", geen Fill/OnSelect; direct na het titellabel in Children. Titellabels PaddingLeft 129 (tekst 15 px na het logo); Hours Summary-titel 400 px. Smalle vensters: titels op Screen1/scrHours knippen onder ~430 px, de Hours Summary-titelbalk past onder ~440 px niet, de projectregel knipt onder ~810 px. Geen CMYK-, claim- of printbestanden (.ai/.eps/.pdf) in de app; de overige Assets-bestanden zijn gitignored.
- Media: mediabestanden leven in de .msapr (msapp\Assets\Images + References\Resources.json); pack leest de projectmap Assets\ niet (alleen het officiële bronbestand blijft getrackt). Nieuw mediabestand: eenmalig in Studio uploaden, opslaan ("Save as → This computer" of apppakket) en opnieuw uitpakken; verwijder elke SAS-querystring uit RootPath en commit nooit ondertekende URL's. Studio-downloads met SAS-token blijven in de gitignored map artifacts\.
- Alle zichtbare navigatie-/actieknoppen staan per scherm in één vaste onderste balk (Screen1, scrHours, scrWeeklyHours), buiten scrollende content: navigatie links, acties (Refresh, Save, weekpijlen, toekomstige Export) rechts, alle directe kinderen van dezelfde rijcontainer, geen tweede rij. Y = lblFooterButtonMetrics.Y (16), Height = lblFooterButtonMetrics.Height (40), X = 40 randmarge, Width = 12 tussenruimte. Footer verankerd aan Parent.Height-Self.Height; binnenrij 72 px, buitenbalk 88 px; LayoutWrap=false, horizontale overflow Scroll, verticale Hide. Minimale rijbreedtes: Screen1 746, Weekly Hours 534, Hours Summary 502 px; knoppen nooit over elkaar of op een tweede rij. Houd status, koppen, tabellen en totalen boven de balk; let bij parentwissel op Parent-/Self-verwijzingen. Een terugknop bij ureninvoer navigeert niet tijdens opslaan of met onopgeslagen wijzigingen.
- Layoutwijzigingen laten kleuren, teksten, acties, Items, filters, laad-/opslaglogica, validaties, Visible en DisplayMode ongemoeid; gebruik gewone layoutcontainers zodat Reset-/Select-acties werken.
- Hours Summary selectie: lblSummaryFieldWidth.Width = 256; dpReportFrom/dpReportUntil 256 px, Project (ddReportProject) en Contractor 512 px; labels exact Project, Contractor, From, Till (Bold, Engelstalig). Linkermarge 40, label direct boven veld (4 px), 12 px tussen groepen; links Project/Contractor, rechts 24 px ernaast From/Till (naast elkaar vanaf selectie-inhoud 792 px, scherm vanaf 888 px; anders onder Contractor). Velden rekken niet mee met schermbreedte. Selectieblok scrolt apart (max 220 px) als het niet past; smal venster: horizontaal scrollen, verhouding niet krimpen. Telefoonlayout van de rapporttabel is een aparte wijziging.
- Hours Summary tabel: geen toelichting/statistiekregel; selectieblok 12 px onder titelbalk; lblReportStatus direct onder het selectieblok (alleen laden, fouten, "geen opgeslagen uren"; zonder tekst 0 px hoog). Tabelkop één balk #0303B8 van Name t/m Period total (galReportWeekHeaders zelfde Fill), wit, Y=lblReportNameHeader.Y, hoogte 40, Semibold (Period total Bold). Rijgallery Parent.Width-80 (16 px scrollbar), kop/rijen/totaalrij eindigen op breedte-56; weekgebied Parent.Width-616; Period total X = Parent.Width-176 (in rij scrWeeklyHours.Width-216), breedte 120; zichtbare weken RoundDown((breedte-616)/90); onder ~666 px geen weekkolom. Zebra #FFFFFF/#F0F0F0 op zichtbare rijpositie, rijlijnen 1 px #DCDCDC, 44 px per rij, weekuren gecentreerd. 0 wordt als "–" (Normal) getoond; data/export behouden 0. Period total: tekst #000F41 Bold, lijn links 1 px #DCDCDC. Totaalrij direct onder de rijen (buiten gallery, boven footer): Fill #D5EDFF, 2 px bovenlijn #0303B8, Bold zwart, "Total", weeksommen via galReportTotalWeeks met dezelfde paginering/offset als de kop (uit colReportSelectedHours), periodetotaal Sum(colReportRows, PeriodTotal); alleen zichtbaar bij varReportValid && !varReportBusy.

## GEA-typografie en kleuren
- Alle controls met tekst (ook verborgen technische) gebruiken `Font: ="Inter, Arial, sans-serif"`; geen Font-enum, Open Sans, Segoe UI of Montserrat. GEA Sans niet in de app. Exports gebruiken Arial.
- Gewichten: Semibold = schermtitels, tabel-/kolomkoppen, zichtbare knoppen; Normal (expliciet) = body, labels, status, invoer, dropdowns, checkboxen, tabelgegevens; Bold = veldlabels Project/Contractor/From/Till, kop en waarden Period total, algemeen periodetotaal. Subtitle4 op Screen1 behoudt zijn voorwaardelijke gewicht.
- Tekstkleur: zwart #000000 (ook hover/pressed), geen grijze tekst; wit op #0303B8 voor titels, koppen, knoppen; rood alleen fout.
- Tekstpassing: `artifacts/Measure-FontFit.ps1 -InterDir <map> [-ArialDir <map>]` (fontbestanden nooit in Src; met timeout draaien); slechtste geval Inter/Arial (Arial Semibold = arialbd.ttf); verbreed de control, niet de tekstgrootte.
- Palet (alleen deze literals plus Color.White/Black/Transparent; Energetic Pink/Active Blue nooit als vlak):

  | Token | Hex | Gebruik |
  |---|---|---|
  | Vibrant Blue | #0303B8 | titelbalken, tabelkoppen, navigatieknoppen, secundaire rand/tekst, hover/focusrand invoer, selectie |
  | Navy | #000F41 | tekst op primaire knoppen, hover/pressed navigatie, Period total-waarden, weektotaal-tekst |
  | Green / hover | #1AFF80 / #18DD6E | uitsluitend primaire actie (btnSaveWeek, btnAddtoTeam); tekst #000F41, nooit wit |
  | Light Blue | #D5EDFF | hover secundair, totaalrij, lblWeekTotal, geselecteerde medewerkerkaart |
  | Light Grey | #F0F0F0 | invoer/dropdowns/datumkiezers (rand #DCDCDC, hover/focus #0303B8), zebra, footerbalk, achtergrond Screen1 |
  | Line Grey | #DCDCDC | randen, tabellijnen |
  | Disabled | #E6E6E6 / #787878 | vlak+rand / tekst uitgeschakeld |
  | Error | #DB1E28 | fouten, ook blokkerende stamgegevenswaarschuwingen in galleryrijen |
  | Wit / zwart | #FFFFFF / #000000 | achtergrond / body |

- Rollen: navigatieknoppen vlak/rand #0303B8, wit, hover/pressed #000F41; secundaire acties (Refresh, weekpijlen) wit vlak, 1 px rand en tekst #0303B8, hover #D5EDFF; dropdownselectie #0303B8 met witte tekst; zachte waarschuwingschip (niet-blokkerend, bv. "Trade onbekend"): witte Fill, rand #0303B8, zwarte tekst. Kleur is nooit het enige signaal; tekst draagt de betekenis.
- Dropdowns (alle Classic/DropDown@2.3.1, ook toekomstige): HoverFill #D5EDFF, HoverColor #000F41, PressedFill #D5EDFF, PressedColor #000F41, SelectionFill #0303B8, SelectionColor White, Fill #F0F0F0, Color #000000, BorderColor #DCDCDC, HoverBorderColor #0303B8, BorderThickness 1, ChevronBackground #F0F0F0, ChevronFill #0303B8, ChevronHoverBackground #D5EDFF. HoverFill mag nooit gelijk zijn aan Fill. Check: Test-GeaColors.ps1.
- Checks: Test-Fonts.ps1 (lettertype/gewichten), Test-GeaColors.ps1 (kleuren, rollen), Test-Logo.ps1 (logo: geometrie, volgorde, officiële SVG-hash, resource→bestand, geen ondertekende URL).

## Export (afspraak, nog niet gebouwd)
- Hours Summary: CSV van de gekozen periode (varReportFrom t/m varReportUntil), één bestand per selectie (project + werkgever, of alle werkgevers), geen PDF. Week Report: PDF + CSV per werkgever. Beide gebruiken dezelfde CSV-specificatie: lang formaat, één regel per opgeslagen dagregistratie (Hours-record).
- Inhoud wordt in de app opgebouwd: één gedeelde CSV-formule (Concat), HTML voor PDF in de app, UTF-8 BOM via UniChar(65279). CSV-kolommen, scheidings-/decimaalteken en datumnotatie niet zelf invullen: overnemen uit de bestaande Week Report-werkwijze zodra aangeleverd.
- Flow = generieke bestandsschrijver zonder bedrijfslogica: invoer JSON-lijst `{fileName, type: "csv" | "html2pdf", content}`; opslaan in documentbibliotheek Exports; bij html2pdf Convert file naar PDF; antwoord met bestandslinks. Flow en bibliotheek maakt Eddy in de Microsoft-omgeving (MS-xxx); verzin geen extra parameters, kolommen of bibliotheekvelden. De bestaande flow (PowerAppV2) is niet bewerkbaar en wordt niet gebruikt.
- Export alleen bij geldig rapport, fail-closed: dezelfde toelatingscontrole in DisplayMode en als eerste OnSelect-voorwaarde; geen export bij laadfout, afgekapte batch (500), lopende load, ongeldige periode of afwijkende selectie. Een mislukte of onvolledige flowrespons wordt gemeld, nooit als geslaagd getoond. Geen automatische e-mail.

## Werkwijze
- Pas bestanden rechtstreeks aan; behoud werkende schermen en functionaliteit; los delegatieproblemen op.
- Tests in twee niveaus: per wijziging de relevante snelle test; aan het einde van de opdracht eenmaal de volledige set plus pack. Actieve checks: Test-SaveRegression, Test-WeeklyCalculations, Test-GeaColors, Test-Fonts, Test-FooterRow -GeometryOnly, Test-SummaryDates, Test-SummaryStyle, Test-SummaryLabels, Test-Logo, Check-WeeklySource (historische checkpoint-diffs alleen met -HistoricalDiff; oudere scripts zijn geen acceptatietest).
- Een geslaagde pack, syntaxiscontrole of lokale test bewijst geen Studio-import, binding, volledigheid of functioneel resultaat; zet zulke acceptatiecriteria nooit op geslaagd en claim geen tests die je niet uitvoerde.
- Benodigde SharePoint-/Power Automate-wijzigingen voer je niet zelf uit: leg ze vast in MANUAL_STEPS.md als MS-xxx (ID, datum, reden, exacte namen/typen, status) en noem open MS-items in je antwoord.
- Sessie wordt tussen opdrachten gewist: leg alles voor de volgende opdracht vast in de projectdocumenten. Eigendom: AGENTS = geldende regels; PROJECT_STATUS = actuele status en buildpad (einde van iedere opdracht bijwerken; onderscheid geïmplementeerd / technisch gecontroleerd / functioneel getest).
- Communiceer in het Nederlands; houd handmatige stappen kort en concreet.

## Agents (.claude/agents/, overzicht in README.md)
- Datalogica (laden, Save, guards, filters, delegatie, sleutels, berekeningen, exportinhoud) → powerfx-logic. Presentatie (kleuren, fonts, posities, labels, tabellen, footer) → powerfx-ui. Tests en pack → verifier. Logicawijzigingen: eerst reviewer, dan pas pack. Documentatie, status, MS-items → docs-keeper.
- Veiligheid: geen hulpfuncties/aliassen die PowerShell-aliassen overschrijven (Rd/rm/del/ri = Remove-Item); verwijder nooit Src-bestanden; geen git stash/checkout/reset op een werkboom met niet-gecommitte wijzigingen (HEAD-vergelijking: `git worktree add` in de scratchpad); langlopende scripts met timeout.

## Technische randvoorwaarden
- Classic/Button@2.2.0 ondersteunt AccessibleLabel niet in SourceCode (Studio-fout PA2108): niet toevoegen aan dit controltype; wel behouden bij typen die het ondersteunen. Een algemene eigenschappenlijst bewijst geen ondersteuning per controlversie.
- Nieuwe controltypen alleen met een door Microsoft gedocumenteerde of door Studio bevestigde control-ID/versie; de Templates.json in de .msapr moet de template bevatten (Image@2.2.3 is gedekt). ModernDatePicker@1.0.0 is toegestaan in artifacts/Check-WeeklySource.ps1 (versieverschil met Studio: PROJECT_STATUS.md). Studio-import is de eerste acceptatiecontrole; geef importfouten exact terug.
- Het .msapr-bestand is een ZIP met originele metadata, verbindingen en controltemplates; de opgeslagen App Checker-resultaten zijn historisch en valideren gewijzigde YAML niet.
- Incident-/onlinecontrole: artifacts/SAVE_INCIDENT_EN_TEST.md.
