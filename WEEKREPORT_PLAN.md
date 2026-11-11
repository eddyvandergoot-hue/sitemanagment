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
- UTF-8 BOM via UniChar(65279), ";" scheiding, "." decimaal (Text(h,"0.##","en-US")), datum yyyy-mm-dd, CRLF, ISOWeek twee cijfers. RFC 4180-quoting bij ";", '"' of regeleinde.
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
- Inhoud: kop met Project Number, Project Reference, Contractor (naam + code), week "YYYY KWxx" + datumbereik; tabel Name | Trade | Mon..Sun | Total; totaalrij; "Generated dd-mm-yyyy HH:mm". Rijen als in het scherm (B3: ook weektotaal 0, dagen "–").
- Namen HTML-escapen (&, <, >, "). Logo: base64 PNG (flowcontract, geen SVG). OPEN: alleen een officieel GEA-logobestand in PNG (logobank, voor witte achtergrond) mag; geen zelf omgezet of hertekend logo. Eddy levert dat bestand aan vóór fase C; tot dan PDF zonder logo.

### 6.4 Bestandsnamen (B8) en map
- `[TEST_]<ProjectNumber>_<YYYY>-KW<ww>_<EmployerCode>_<yyyymmdd-hhmm>` + extensie via Format; Hours Summary: `[TEST_]<ProjectNumber>_<yyyymmdd>-<yyyymmdd>_<EmployerCode|ALL>_<yyyymmdd-hhmm>`.
- Folder: `<ProjectNumber>/<ISO-jaar>` (voorbeeld uit het contract "TEST-000/2026").

### 6.5 Flowcontract (B9, Eddy 9-11-2026)
- Naam "SiteManagement - Export file"; trigger Power Apps (V2); alleen standaardconnectors.
- Invoer (tekst): Folder, FileName (zonder extensie), Format ("csv" | "pdf"), Content (CSV met BOM of volledige HTML).
- csv: SharePoint Create file in Exports/Folder. pdf: OneDrive tijdelijk .html -> Convert file (PDF) -> SharePoint Create file Exports/Folder -> tijdelijk bestand verwijderen.
- Uitvoer (tekst): Status ("ok" | "error"), FileUrl (klikbaar), Message.
- Eén aanroep per bestand; "All contractors" = per contractor twee aanroepen (PDF + CSV).

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
