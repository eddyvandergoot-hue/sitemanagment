# Week Report + export: plan (9-11-2026; besluiten Eddy 9-11-2026; fase A in bouw)

Bron: AGENTS.md (Export, Admin screen pattern, Uren en rapportage), DECISIONS.md H4/H5, E1-E5 en WR1-WR5 (9-11-2026). Dit plan vervangt NEXT_COMMANDS.md par. 5/6.

## 1. Doel en afbakening
- Week Report (H4): officieel weekoverzicht van één project, één ISO-week, per contractor; Mon t/m Sun per medewerker, alle teams, alleen-lezen. Basis voor PDF + CSV per project + contractor + week (E1).
- Hours Summary (H5) blijft het periode-overzicht; krijgt alleen een CSV-export (E1), geen PDF.
- Bestandsinhoud wordt in de app opgebouwd (E3); flow = generieke bestandsschrijver (par. 6.5); geen e-mail (E4); PDF in Arial (E5).
- Niet in scope: Excel-export, automatische verzending, wijziging van gegevens. Week Report schrijft nooit naar een lijst.

## 2. Fasering (elke fase eigen build + Studio-test, tag pas na Eddy's OK)
1. Fase A, scherm (geen export): scrWeekReport alleen-lezen, Home-tegel "Week report" actief, TEST-regel, codes met fallback, rapporttaal (zonder Employers.Report Language tot MS-027 is samengevoegd). Studio-test TP-WEEKREPORT-01.
2. Fase B, export-proef: na MS-029 (flow) en MS-030 (flow in de app): één CSV + één PDF van TEST-000 (flowcontract, PDF-opmaak, link). TP-EXPORT-01.
3. Fase C, Week Report-export: PDF (tweetalig: pagina 1 NL, pagina 2 tweede taal, H24; teksten uit Translations, par. 6.3) + CSV per contractor; Report Language van Employers; vereist de metadata-refresh na MS-027 + MS-028. TP-EXPORT-02.
4. Fase D, Hours Summary-export: CSV van de gekozen periode (zelfde CSV-formule). TP-EXPORT-03.

## 3. Scherm scrWeekReport (fase A)
- Admin screen pattern: cmpTitleBar ("Week Report"; spinner tijdens laden), cmpMessageBar (geen Notify), cmpField-dropdowns Project en Contractor, pagina #F5F6F8, witte kaarten; teksten uit `T` (sleutels `wr*`; app-UI Engels).
- Weekkiezer (B6): hetzelfde patroon als dpHoursWeek op Weekly Hours (ModernDatePicker@1.0.2, "dd-mm-yyyy", StartOfWeek.Monday, 256 px, gekozen dag blijft zichtbaar, label "Week" + "YYYY KWxx" ernaast, OnChange laadt alleen bij een andere week, geen Load-knop, geen Reset na gewone keuze). Gedocumenteerde uitzondering op "geen hand-gebouwd veld"; geen nieuw component. Standaard = week van vandaag; eigen variabelen (varWr*), los van Screen1/Weekly Hours.
- Project: colProjectsCache-achtige eigen read van Projects (alle projecten, TEST inbegrepen, B5). Contractor: "All contractors" + contractors die in de geladen week voorkomen.
- Tabelkaart: Name | Trade | Mon..Sun (dag + dd-mm) | Week total, gegroepeerd per contractor (kopregel: naam + Contractor Code; geen rapporttaal op het scherm, H24) met subtotaalregel; eindtotaal bij "All contractors". Stijl als Hours Summary (kop #0303B8 wit Semibold, zebra, lijnen #DCDCDC, 0 = "–", hele uren zonder komma/punt). Kolommen (Eddy 11-11-2026, H24): vaste breedtes naam | trade | dag | totaal = 240 | 96 | 72 | 88 (kaartinhoud >= 928), 200 | 80 | 56 | 64 (>= 736), anders 140 | 72 | 44 | 64; de tabel stopt na Week total (niet uitrekken); uren en dagkoppen rechts uitgelijnd (padding rechts 8, in de 44-stand 2); smaller dan de tabel: horizontaal scrollen in het inhoudsvlak.
- Footer (B7): nieuw component cmpReportFooter (Home 110 met Icon.Home links; rechts Refresh secundair, Export groen primair, Export onzichtbaar in fase A via input ExportVisible). cmpFooter en de beheerschermen blijven ongewijzigd.
- Weekpijlen (Eddy 11-11-2026): niet in de footer maar in de selectiekaart direct links en rechts van de weekkiezer: [‹] [datum] [›], daarna het KW-label. btnWrPrev/btnWrNext (Classic/Button), vierkant zo hoog als dpWrWeek (36), 6 px ertussen, secundair (wit, rand 1 px #0303B8) met navy chevron #000F41, hover/pressed #D5EDFF, focus navy 3 px; zelfde guard in DisplayMode en als eerste OnSelect-voorwaarde, zelfde logica als de oude footerpijlen (week ±7 dagen, Reset(dpWrWeek), Select(btnWrLoad)). Selectie op één rij vanaf schermbreedte 1344 px (Project op X 520); daaronder week op rij 1, Project | Contractor op rij 2 (vanaf 688 px naast elkaar). De weekrij is 520 px breed (past vanaf 584 px scherm); smaller wordt de selectiekaart niet smaller dan de weekrij en scrolt het inhoudsvlak horizontaal, zodat beide pijlen en het KW-label bereikbaar blijven.
- Guards: zelfde voorwaarde in Enabled en als eerste OnXxx-voorwaarde; geen navigatie/weekwissel/Refresh tijdens laden.

## 4. Laden (fase A)
- Laadstatussen NotLoaded/Loading/Failed/Loaded; staging-collections, vervangen pas na volledig geslaagde load; geen Patch/Update/Remove; fouten in cmpMessageBar.
- Reads (predicaten alleen kolommen + globale variabelen, vooraf gezet):
  1. Hours: `Filter(Hours, StartsWith(EntryKey, varWrQueryPrefix) && 'Work Date' >= varWrMonday && 'Work Date' < varWrNextMonday)`, varWrQueryPrefix = Text(projectID) & "|". 500 = terugval op 7 uitgeschreven dagbatches; een volle dag blokkeert het rapport.
  2. Project Workers en Assignment Periods: `ProjectKey = varWrProjectKey` (500-guard).
  3. Workers: eigen read (ook Language en Worker Code; colWorkersCache heeft die niet), 500-guard.
  4. Employers: één read (Title, Employer Code, Active; na MS-027 ook Report Language), 500-guard. Projects: één read (500-guard).
- Rijen (B3, AGENTS punt 3): medewerkers met een inzetperiode die de week overlapt, plus medewerkers met opgeslagen uren die week. Lege dagen "–"; weektotaal 0 blijft zichtbaar.
- Contractor per uurregel = historische Hours.Employer; rij zonder uren = huidige Workers.Employer; uren onder twee contractors in dezelfde week = een rij per contractor.
- Trade per uurregel = historische Hours.Trade (F -> Fitter, W -> Welder); rij zonder uren = Workers.Trade.
- ISO-jaar/KW-formule gelijk aan Hours Summary (week 53 en jaarwisseling getest).

## 5. Codes, TEST-regel en rapporttaal
- EmployerCode (B1): Employers.'Employer Code' alleen lezen (voor weergave en export); leeg -> "EMP-" & Text(ID,"000") (zelfde regel als flow MS-019), geen blokkade.
- WorkerID (B2): Worker Code (WKR-..., field_1); leeg -> "WKR-" & Text(ID,"000").
- TEST (B5): TEST-projecten (Project Number begint met "TEST-") blijven kiesbaar; exportbestanden krijgen prefix "TEST_"; bij echte projecten worden regels van contractor "TEST Employer" weggelaten (tabel en export) met een Attention-melding.
- Rapporttaal (WR1, per rapport = project + contractor + week): primair Nederlands + tweede taal. Volgorde tweede taal: (1) Employers.'Report Language' als gevuld (MS-027, vanaf fase C); (2) anders de meerderheid van Workers.Language van de medewerkers in dat rapport (gelijkstand -> English); (3) anders English. Uitkomst Dutch -> alleen Nederlands. Geen taal per team. Alleen voor de PDF-export (H24): het scherm toont geen rapporttaal; ReportLanguage blijft in de groepsrecord voor fase C. Taalnamen worden als tekst vergeleken (keuzenaam), zonder vaste lijst in de app (W5).

## 6. Export (fase B-D)
### 6.1 CSV (E2; B4, B10)
- Lang formaat, één regel per opgeslagen dagregistratie (ook opgeslagen 0); medewerkers met totaal 0 vallen weg.
- Kolommen (vaste Engelse technische namen, niet vertaald): ProjectNumber;ProjectReference;EmployerCode;EmployerName;WorkerID;WorkerName;Trade;WorkDate;ISOYear;ISOWeek;Hours.
- UTF-8 BOM via UniChar(65279), ";" scheiding, decimale komma (H25, Nederlandse Excel; Text(h,"0.##","nl-NL"), dus 7,5), datum yyyy-mm-dd, CRLF, ISOWeek twee cijfers. RFC 4180-quoting bij ";", '"' of regeleinde (een komma in tekst hoeft niet gequote; ";" is de scheiding).
- Eén gedeelde opbouw: beide schermen vullen colExportRows (vast schema); één named formula (ExportCsvText) in App.Formulas bouwt de tekst (Studio-controle dat een named formula een collection mag lezen; anders één formule per scherm met tekstgelijkheidstest).
- Hours Summary: colReportFacts krijgt Trade (historisch, F/W-mapping) in fase D, geen extra read.

### 6.2 Identiteiten in export
- WorkerName = huidige First Name + " " + Surname; EmployerName = historische Hours.Employer.Value; codes volgens par. 5.

### 6.3 PDF (Week Report, per project + contractor + week; WR1-WR3)
- HTML in de app, Arial (E5), A4 liggend, geen externe verwijzingen.
- Tweetalig: alleen statische teksten (titel, kolomkoppen, dagnamen, voetnoten, labels) vertaald; gegevens ongewijzigd. Opmaak (H24, Eddy 11-11-2026): pagina 1 volledig Nederlands, pagina 2 dezelfde inhoud in de tweede taal (paginascheiding); bij tweede taal Dutch alleen pagina 1.
- Documentteksten data-gestuurd (WR5, Eddy 9-11-2026; talen groeien): sleutels `doc.*` in SharePoint-lijst "Translations" (MS-028): Key (hernoemde Title), Language (tekst = keuzenaam, bv. "Polish"), Text (meerdere regels); index op Language. App-UI-teksten blijven in T (ongewijzigd).
  - Laden één keer per rapport(taalset), lokaal per taal: drie aparte reads `Filter(Translations, Language = varDocLangQuery)` voor de tweede taal, "Dutch" en "English" (elk een 500-guard, leesfout = geen export). Eén read met `||` mag ook (delegeerbaar), maar dan is de 500-guard per taal niet aantoonbaar; daarom drie reads.
  - Fallback: sleutel ontbreekt in de tweede taal -> Engelse tekst; ontbreekt in Dutch -> de sleutel zelf + waarschuwing alleen in debug (Trace), niet in de UI. (Eddy's keuze; let op: dan kan een sleutelnaam in een officieel document staan. Test-Export controleert dat alle fase-C-sleutels in de aangeleverde CSV voor Dutch en English bestaan.)
  - Geen vaste talenlijst in de app: beschikbare talen = unieke Language in Translations ∪ keuzes van Workers.Language. Taal toevoegen = keuze in Workers.Language en Employers.Report Language (gelijk houden) + rijen in Translations; geen app-build.
  - Vertalingen: de Claude-chat levert een CSV voor import (sleutels uit fase C); native-speaker-controle vóór livegang (backlog).
- Inhoud (opmaakfeedback Eddy 12-11-2026):
  - **Titelbalk:** documenttitel wit rechts in de logobalk.
  - **Infoblok:** Project name (Projects.Title), Project number, Project reference, Contractor ("All contractors" of "naam · EmployerCode") en Week ("YYYY KWxx" + datumbereik). Volgorde: Project name, Country (Projects.Country, keuzewaarde ongewijzigd; Eddy 13-11-2026), Project number, Project reference, Contractor, Week. Location bestaat niet in Projects (AGENTS), dus geen locatieregel.
  - **Tabel:** Name | Trade | Mon..Sun | Total met eenheid ("Totaal (uur)" / "Total (hrs)"), daarna subtotaal per contractor en een totaalrij.
  - **Voettekst per pagina:** "Gegenereerd <datum tijd> door <gebruiker>" links en "Pagina x van y" rechts. Gebruiker = User().FullName.
  - **Rijen:** als op het scherm (B3: ook weektotaal 0, dagen "–").
- Sleutels in Translations die fase C nodig heeft (Language Dutch en English verplicht). Namen vastgesteld 13-11-2026 (Eddy: "use doc.* keys from 6.3, no new names"; doc.country toegevoegd voor de Country-regel). Importbestand: templates/translations-weekreport.csv (Key;Language;Text, UTF-8 met BOM, ";"; 23 sleutels x 6 talen Dutch, English, Polish, Romanian, German, Ukrainian = 138 regels; Test-Templates controleert volledigheid, placeholders en dat de infolabels van sample-body.html gelijk zijn aan de CSV). Import in de lijst: MS-032. Native-speaker-controle pl/ro/de/uk: backlog.
  - **Kop en infoblok:** doc.title, doc.projectName, doc.country, doc.projectNumber, doc.projectReference, doc.contractor, doc.contractorAll, doc.week, doc.weekRangeSep ("t/m" / "to").
  - **Tabel:** doc.colName, doc.colTrade, doc.day1..doc.day7, doc.colTotal ("Totaal (uur)" / "Total (hrs)"), doc.subtotal, doc.total.
  - **Voettekst:** doc.footerGenerated ("Gegenereerd {date} door {user}"), doc.footerPage ("Pagina {page} van {pages}").
- Namen HTML-escapen (&, <, >, "). Daarnaast "{" in gegevens als `&#123;` schrijven, zodat een naam nooit een token ({{BODY}}/{{HEADER}}) kan vormen.
- Templates (H25, Eddy 12-11-2026): opmaak staat in SharePoint-bibliotheek "Templates" (MS-031); bron in de repo `templates/`.
  - `header.html`: snippet (geen html/body), blauwe balk #0303B8 van 40 px over de volle breedte met het officiële witte logo (Assets/GEA_logo_white.svg, ongewijzigd, base64-data-URI, hoogte 24, niet gerekt), Arial.
  - `weekreport.html` (opmaak Eddy 12-11-2026):
    - Volledige HTML, Arial, `@page` A4 liggend (marge 12 mm, onder 16 mm).
    - Voettekst via de margeboxen `@bottom-left`/`@bottom-right`: lettertype en grootte (8 pt) staan in het template, de tekst komt van de app.
    - Titel `h1.doc-title` wit rechts in de balk.
    - Tabel 100 % breed (rechterrand gelijk aan de balk). De naamkolom neemt de rest, Trade 24 mm, dag 15 mm, Total 28 mm.
    - Kop #0303B8 wit; za/zo (klasse `we`) #F0F0F0, ook in de kop (tekst Navy).
    - Zebra `alt` #F0F0F0 (za/zo op een zebrarij #E6E6E6); lijnen #DCDCDC.
    - Groepsregel blauw met een lijn van 2 px; `subtotal` #D5EDFF; `total` Navy #000F41 met witte vette tekst.
    - Total-kolom vet, geen verticale lijn ervoor; getallen rechts.
    - Klasse `page` met page-break-after (niet op de laatste pagina). Token {{BODY}} precies één keer, als enige inhoud van body. Geen teksten in het template.
  - `sample-body.html`: 2 pagina's (nl + en) met synthetische TEST-gegevens, voor de flowtest.
  - Content die de app stuurt, per taal:
    ```
    <section class="page" lang="xx" style="page: wr-xx">
    <style>@page wr-xx { @bottom-left { content: "<generated-tekst>"; } @bottom-right { content: "<Pagina> " counter(page) " <van> " counter(pages); } }</style>
    {{HEADER}}<h1 class="doc-title">..</h1> ... </section>
    ```
    - De style bevat alleen de vertaalde voettekst; de opmaak blijft in het template.
    - CSS-strings escapen: `\` als `\\` en `"` als `\"`.
    - counter(pages) telt het hele document, dus de Engelse pagina zegt "Page 2 of 2".
    - Klassen: `meta`, `report`, `group`, `alt`, `subtotal`, `total`, `num`, `we`, `total-col`, `daydate`, `doc-title`, `c-name`/`c-trade`/`c-day`/`c-total` (colgroup). Controle: artifacts/Test-Templates.ps1 (tokens, palet, Arial, logo-hash, tagbalans, samenvoeging als de flow, optioneel PDF via Edge headless).
- Logo: base64 in header.html. OPGELOST 12-11-2026 (flowtest T2): de converter is Chromium en toont het SVG-logo; er is geen PNG nodig. Achtergrond: Eddy vroeg om een PNG uit de repo. De enige PNG (Assets/GEA_Logo_w_Claim_CMYK_VibrantBlue.png) is de claimversie en staat bewust buiten git (AGENTS: geen claimbestanden); zelf omzetten van de SVG mag niet. Daarom nu het officiële witte SVG op Vibrant Blue. Edge rendert het goed; of de OneDrive-conversie (Convert file) SVG toont, blijkt bij de flowtest. Zo niet: Eddy levert een officiële PNG zonder claim uit de logobank en alleen de base64 in header.html wordt vervangen.

### 6.4 Bestandsnamen (B8) en map
- H25 (Eddy 12-11-2026): één Export-klik = .pdf + .csv met dezelfde basisnaam, voorbeeld `Exports/<ProjectNumber>/WeekReport_<ProjectNumber>_<YYYY>KW<ww>.pdf/.csv`.
- Besloten (Eddy 12-11-2026: "filename per 6.4"; punt 3 expliciet): basisnaam `[TEST_]WeekReport_<ProjectNumber>_<YYYY>KW<ww>_<EmployerCode|ALL>` + .pdf/.csv, map `Exports/<ProjectNumber>`, geen tijdstempel. Interpretatie bevestigd door Eddy 13-11-2026: EmployerCode of ALL, prefix TEST_, alleen projectmap. Eén contractor gekozen = `_<EmployerCode>` (leeg: "EMP-" & Text(ID,"000")); "All contractors" = één bestandspaar `_ALL` met alle contractors (groepsregels + subtotalen, zoals sample-body.html). De eerdere open punten:
  1. Geen EmployerCode in de naam. Een Week Report is per project + contractor + week (WR1), en bij "All contractors" komen er per contractor twee bestanden. Twee contractors in dezelfde week krijgen dan dezelfde naam en overschrijven elkaar. Besloten: `_<EmployerCode>` erbij.
  2. Geen prefix "TEST_" voor TEST-projecten (E10, AGENTS Werkwijze). Besloten: prefix houden.
  3. Geen tijdstempel: BESLOTEN (Eddy 12-11-2026, T3 PASS). Opnieuw exporteren overschrijft; de versiegeschiedenis van Exports bewaart oud (de GEA-tenant laat oude versies automatisch verlopen). De lijsten zijn de historie: elke week kan opnieuw worden gemaakt (toont dan de actuele gegevens, inclusief latere correcties).
  4. Map `<ProjectNumber>` zonder submap per ISO-jaar (eerder `<ProjectNumber>/<ISO-jaar>`). Besloten: alleen projectmap.
- Eerder (9-11-2026, vervangen door H25 tenzij Eddy anders kiest): `[TEST_]<ProjectNumber>_<YYYY>-KW<ww>_<EmployerCode>_<yyyymmdd-hhmm>`; Hours Summary: `[TEST_]<ProjectNumber>_<yyyymmdd>-<yyyymmdd>_<EmployerCode|ALL>_<yyyymmdd-hhmm>` (Hours Summary blijft alleen CSV, E1). Folder was `<ProjectNumber>/<ISO-jaar>`.

### 6.5 Flowcontract (B9, Eddy 9-11-2026; flow gebouwd en getest 12-11-2026, MS-029 gedaan)
- Gebouwd (Eddy 12-11-2026):
  - Trigger-invoer in deze volgorde: Folder, FileName, Format, Content, TemplateName (optioneel).
  - Uitvoer: Status, FileUrl, Message.
  - Samenvoegen: eerst BODY vervangen, dan HEADER.
  - Opslag in SharePoint. Tijdelijke map in Eddy's OneDrive: SiteManagementTemp; het bestand wordt na de conversie verwijderd.
  - Exports en Templates: major versions aan.
- Risico "Word-engine" GESLOTEN: Convert file gebruikt Chromium, niet Word. SVG, `@page` A4 liggend en CSS-pagina-einde werken (T2). De template mag dus Chromium-CSS gebruiken (o.a. `@page`-margeboxen met paginatellers).
- Naam "SiteManagement - Export file"; trigger Power Apps (V2); alleen standaardconnectors.
- Invoer (tekst): Folder, FileName (zonder extensie), Format ("csv" | "pdf"), Content (tekst), TemplateName (H25; bv. "weekreport.html"; alleen gebruikt bij pdf, bij csv leeg).
- Content csv: de app zet zelf de UTF-8 BOM (U+FEFF) vooraan; de flow voegt niets toe en wijzigt niets. Content pdf (H25): alleen de pagina's (per taal `<section class="page">`, elke pagina begint met {{HEADER}}); opmaak, Arial en logo komen uit het template.
- csv: SharePoint Create file in Exports/Folder.
- pdf: (1) lees TemplateName en header.html uit bibliotheek Templates (MS-031); (2) html = replace(template, '{{BODY}}', Content); (3) html = replace(html, '{{HEADER}}', header) (replace() vervangt alle voorkomens); (4) OneDrive tijdelijk .html -> Convert file (PDF) -> SharePoint Create file Exports/Folder -> tijdelijk bestand verwijderen. Volgorde BODY vóór HEADER is verplicht (de HEADER-tokens zitten in Content). Template of header niet gevonden = Status "Error" met Message, geen bestand.
- Uitvoer (tekst): Status ("OK" | "Error"; de app vergelijkt hoofdletterongevoelig), FileUrl (klikbaar), Message.
- BOM in Power Fx: Eddy noemde Char(65279). Char is volgens Microsoft bedoeld voor ASCII-codes; voor U+FEFF gebruikt de app UniChar(65279) (AGENTS, par. 6.1). Het resultaat in het bestand is hetzelfde: BOM EF BB BF.
- Eén aanroep per bestand; één Export-klik = twee aanroepen (PDF + CSV, zelfde basisnaam); "All contractors" = één bestandspaar met suffix `_ALL`, dus ook twee aanroepen (6.4, bevestigd 13-11-2026).
- Flowtest (fase B): Content = inhoud van templates/sample-body.html, TemplateName "weekreport.html", Format "pdf", Folder "TEST-000"; verwacht een PDF van 2 pagina's gelijk aan de Edge-render van Test-Templates.ps1 -RenderPdf. Resultaat: PASS (TESTPLAN TP-EXPORT-01).

### 6.6 Toelating en foutafhandeling (fail-closed)
- Export alleen als: Loaded zonder fouten, geen afgekapte batch, geen lopende load/export, selectie gelijk aan de geladen selectie, minstens één regel. Zelfde voorwaarde in DisplayMode/Enabled en als eerste OnSelect-voorwaarde.
- Flowaanroep in IfError; Status <> "ok" of lege FileUrl = fout met Message in de meldingsbalk; bij meerdere bestanden telt elk resultaat apart, nooit "geslaagd" bij een fout. Links tonen en openen met Launch().
- Trace `DIAG|Export|End` (Files, ElapsedMs, Errors), zonder namen.

## 7. Tests (lokaal, artifacts)
- Fase A: nieuw Test-WeekReport.ps1 (loaders/staging/500-guards/predicaten, geen mutaties, guard-pariteit, rijregel, contractorhistorie, codefallbacks, TEST-regel, rapporttaal incl. gelijkstand, ISO-week 53); Test-Layout, Test-Components (cmpReportFooter), Test-GeaColors, Test-Fonts, Test-HomeIcons (tegel actief), Check-WeeklySource.
- Fase B-D: Test-Export.ps1 (CSV in de Power Fx-interpreter: BOM, kop, ";", ".", datum, quoting, 0-regels, F/W; HTML-escaping; bestandsnamen; export-guard; tweetalige koppen).

## 8. Handmatige stappen (MANUAL_STEPS.md)
- Bibliotheek Exports: gemaakt door Eddy 9-11-2026.
- MS-027: Employers kolom "Report Language" (keuze Dutch, English, Polish, Romanian, German, Ukrainian; geen standaard); daarna metadata-refresh (alleen Employers) in Incoming\, merge alleen databronnen, App Id 88e53928.
- MS-028: SharePoint-lijst "Translations" (Title hernoemd naar Key; Language tekst; Text meerdere regels; index op Language), vullen met de CSV uit de Claude-chat. Metadata-refresh na MS-027 + MS-028 samen in Incoming\ (Employers + Translations), merge alleen databronnen.
- MS-029: flow "SiteManagement - Export file" volgens par. 6.5.
- MS-030: flow toevoegen aan de app in Studio, opslaan, aanleveren in Incoming\ (verbindingen niet zelf maken).
- Later (backlog): veld Report Language op het Contractors-scherm; native-speaker-controle vertalingen.
