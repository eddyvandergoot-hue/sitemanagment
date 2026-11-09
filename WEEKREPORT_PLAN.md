# Week Report + export: plan (9-11-2026, niet gebouwd)

Status: PLAN, wacht op Eddy's antwoorden (par. 9). Bron: AGENTS.md (Export, Admin screen pattern, Uren en rapportage), DECISIONS.md H4/H5 en E1-E5, NEXT_COMMANDS.md par. 5/6 (oudere opzet, dit plan vervangt die). Er wordt niets gebouwd voordat Eddy de beslispunten beantwoordt.

## 1. Doel en afbakening
- Week Report (H4): officieel weekoverzicht van één project, één ISO-week, per contractor; Mon t/m Sun per medewerker, alle teams, alleen-lezen. Basis voor PDF + CSV per project + contractor (E1).
- Hours Summary (H5) blijft het periode-overzicht; krijgt alleen een CSV-export (E1), geen PDF.
- Alle bestanden worden in de app opgebouwd (E3); de flow is een generieke bestandsschrijver zonder bedrijfslogica; geen e-mail (E4); PDF in Arial (E5).
- Niet in scope: Excel-export, automatische verzending, nieuwe SharePoint-kolommen, wijziging van Hours-gegevens. Week Report schrijft nooit naar Hours, Workers, Employers of Projects.

## 2. Fasering (elke fase eigen build + Studio-test, tag pas na Eddy's OK)
1. Fase A, scherm (geen export): scrWeekReport alleen-lezen + Home-tegel "Week report" actief + TEST-regel (par. 7). Studio-test TP-WEEKREPORT-01.
2. Fase B, export-proef: Eddy maakt bibliotheek Exports en de flow (MS-items, par. 8) en voegt de flow toe aan de app in Studio; daarna een minimale proef-export (één CSV + één PDF van TEST-000) om flowcontract, PDF-opmaak en downloadlink te bewijzen. Studio-test TP-EXPORT-01.
3. Fase C, Week Report-export: PDF + CSV per contractor. Studio-test TP-EXPORT-02.
4. Fase D, Hours Summary-export: CSV van de gekozen periode (zelfde CSV-formule). Studio-test TP-EXPORT-03.
Fase B kan parallel aan fase A voorbereid worden zodra Eddy de flow heeft; de app-kant van de export komt pas na fase A.

## 3. Scherm scrWeekReport (Admin screen pattern)
- Componenten: cmpTitleBar (titel "Week Report", spinner tijdens laden/export), cmpMessageBar (geen Notify), cmpField voor Project en Contractor (dropdowns), pagina #F5F6F8, witte kaarten (radius 8, DropShadow.Light, marges 24). Teksten uit `T` (sleutels `wr*`).
- Selectiekaart bovenaan: Week (ModernDatePicker@1.0.2 + label "YYYY KWxx", gedrag als dpHoursWeek: gekozen dag blijft zichtbaar, geen Load-knop, OnChange laadt bij andere week), Project (cmpField dropdown uit colProjectsCache), Contractor ("All contractors" + contractors die in de geladen week voorkomen).
  - Week-veld: cmpField kent geen datum. Voorstel: eerst een Studio-proef met ModernDatePicker binnen cmpField (InputType "date"); lukt dat niet, dan een hand-gebouwde datumkiezer met cmpField-stijl als gedocumenteerde uitzondering op "geen hand-gebouwd veld" (beslispunt B6).
- Tabelkaart: kolommen Name | Contractor | Trade | Mon..Sun (kop dag + dd-mm) | Week total; totaalrij per dag + eindtotaal; stijl als Hours Summary (kop #0303B8 wit Semibold, zebra, lijnen #DCDCDC, 0 = "–", uren gecentreerd, hele uren zonder komma/punt, max 2 decimalen). Bij "All contractors" gegroepeerd per contractor met subtotaal per contractor.
- Footer: cmpFooter heeft vaste knoppen (Home, New, Refresh, Discard, Save) en past niet. Voorstel: nieuw component cmpReportFooter (Home links; rechts weekpijlen 48, Refresh secundair, Export groen primair), zelfde maten als cmpFooter (h68, knoppen h40 Y14). Alternatief: cmpFooter uitbreiden met Visible-inputs (raakt de goedgekeurde beheerschermen; afgeraden). Beslispunt B7.
- Guards (zelfde voorwaarde in DisplayMode/Enabled en als eerste OnSelect-voorwaarde): Home/weekpijlen/Refresh niet tijdens laden of export; Export alleen bij geldig rapport (par. 6.4).

## 4. Laden (fase A)
- Laadstatussen NotLoaded/Loading/Failed/Loaded; staging-collections, vervangen pas na volledig geslaagde load; geen Patch/Update/Remove in loaders; fouten in cmpMessageBar.
- Reads (alle predicaten met globale variabelen, vooraf gezet):
  1. Hours: `Filter(Hours, StartsWith(EntryKey, varWrQueryPrefix) && 'Work Date' >= varWrMonday && 'Work Date' < varWrNextMonday)` met varWrQueryPrefix = Text(projectID) & "|". 500 = terugval op 7 dagbatches (uitgeschreven, niet via ForAll); een volle dag blokkeert het rapport.
  2. Project Workers + Assignment Periods: `ProjectKey = varWrProjectKey` (500-guard).
  3. Workers: colWorkersCache hergebruiken als varMastersReady && varWorkersCacheReady, anders verse read naar staging (zelfde projectie als Screen1).
  4. Employers: één read voor naam + Employer Code (500-guard), alleen voor weergave en export (par. 6.2).
- Rijen (AGENTS punt 3): medewerkers met een periode die de week overlapt of met opgeslagen uren die week. Contractor per uurregel = historische Hours.Employer; rij zonder uren = huidige Workers.Employer. Een medewerker met uren onder twee contractors in dezelfde week = twee rijen (één per contractor).
- Trade per uurregel = historische Hours.Trade (F -> Fitter, W -> Welder); rij zonder uren = Workers.Trade.
- Lokale berekening; geen remote LookUp/Filter in ForAll of per cel. Week-/ISO-logica gedeeld met Hours Summary-formules (zelfde ISO-jaar/KW-formule, getest rond week 53).

## 5. TEST-regel (AGENTS: Werkwijze)
- Projecten met Project Number "TEST-..." en contractor TEST Employer horen niet in Week Report en exports, maar functionele tests mogen alleen op TEST-000. Voorstel (beslispunt B5): TEST-projecten blijven kiesbaar in Week Report (testen), export van een TEST-project krijgt bestandsnaamprefix "TEST_"; in echte projecten worden regels van TEST Employer uit tabel en export weggelaten met een melding (Attention).

## 6. Export (fase B-D)
### 6.1 CSV (E2, één gedeelde formule voor beide schermen)
- Lang formaat, één regel per opgeslagen dagregistratie (ook opgeslagen 0); medewerkers met totaal 0 in het bestand vallen weg.
- Kolommen: ProjectNumber;ProjectReference;EmployerCode;EmployerName;WorkerID;WorkerName;Trade;WorkDate;ISOYear;ISOWeek;Hours.
- UTF-8 BOM via UniChar(65279), scheiding ";", decimaal ".", datum yyyy-mm-dd, regeleinde CRLF (Char(13) & Char(10)), kopregel zoals hierboven.
- Getallen: Text(h, "0.##", "en-US") (8 -> "8", 7.5 -> "7.5"). ISOYear = Year(maandag+3), ISOWeek twee cijfers ("01").
- Tekstvelden met ";", '"' of regeleinde: tussen aanhalingstekens, '"' verdubbeld (RFC 4180). Voorstel B4.
- Gedeelde vorm: beide schermen vullen dezelfde collection colExportRows (vast schema) en één named formula in App.Formulas bouwt de tekst (ExportCsvText). Studio-controle dat een named formula een collection mag lezen; anders één verborgen label-/knopformule per scherm met een tekstvergelijkingstest die beide gelijk houdt.
- Hours Summary: colReportFacts heeft nog geen Trade; fase D voegt Trade (historisch, F/W-mapping) toe aan de staging, geen extra read.

### 6.2 Identiteiten (beslispunten)
- EmployerCode: komt uit Employers.EmployerCode1 (flow MS-019 vult "EMP-<ID>"). AGENTS zegt nu "de app leest/schrijft Employer Code niet"; Contractors toont hem al alleen-lezen. Voorstel B1: alleen-lezen gebruik voor export toestaan; lege code blokkeert export ("Fix: Contractor Code empty"), nooit zelf invullen.
- WorkerID: voorstel B2 = Worker Code (WKR-..., field_1, flow MS-017); lege code (net aangemaakte medewerker, ~1 min) blokkeert export met melding. Alternatief: SharePoint-ID (altijd gevuld, maar niet zichtbaar in de app).
- WorkerName = huidige First Name + " " + Surname (Hours bevat geen naam); EmployerName = historische Hours.Employer.Value.

### 6.3 PDF (Week Report, per project + contractor)
- HTML in de app, Arial (E5), A4 liggend; kop: Project Number, Project Reference, Contractor (naam + code), week "YYYY KWxx" + datumbereik; tabel Name | Trade | Mon..Sun (dag + dd-mm) | Total; totaalrij; voet: "Generated <dd-mm-yyyy HH:mm>" + paginanummer als de converter dat ondersteunt.
- Medewerkers met weektotaal 0: voorstel B3 = weglaten in PDF (gelijk aan CSV); alternatief tonen met "–".
- Namen HTML-escapen (&, <, >, "). Logo: het officiële GEA-logo alleen als de converter SVG/data-URI correct rendert (proef in fase B); anders zonder logo. Geen hertekend of omgezet logo.
- Bestandsnamen (voorstel B8): `<ProjectNumber>_<YYYY>KW<xx>_<EmployerCode>_<yyyymmdd-HHmm>.pdf/.csv`; Hours Summary `<ProjectNumber>_<yyyymmdd>-<yyyymmdd>_<EmployerCode|ALL>_<yyyymmdd-HHmm>.csv`. Tijdstempel voorkomt overschrijven.

### 6.4 Toelating en foutafhandeling (fail-closed)
- Export alleen als: Loaded zonder fouten, geen afgekapte batch (500), geen lopende load/export, selectie (project/contractor/week of periode) gelijk aan de geladen selectie, minstens één regel, alle EmployerCode/WorkerID gevuld. Zelfde voorwaarde in DisplayMode en als eerste OnSelect-voorwaarde.
- "All contractors" = één flowaanroep met per contractor een PDF + CSV.
- Flowaanroep in IfError; antwoord wordt gecontroleerd (aantal bestanden = aantal gevraagd, elk met link); anders melding "Export failed" met de reden, nooit "geslaagd". Links worden in de meldingsbalk/kaart getoond en geopend met Launch(); geen automatische e-mail.
- Trace `DIAG|Export|End` (Files, ElapsedMs, Errors), zonder namen.

## 7. Tests (lokaal, artifacts)
- Nieuw Test-WeekReport.ps1: loaderstructuur (staging, 500-guards, predicaten), geen mutaties, guard-pariteit, rijregel (periode/uren/contractorhistorie), ISO-week 53 en jaarwisseling, TEST-regel.
- Nieuw Test-Export.ps1: CSV-formule geëvalueerd in de Power Fx-interpreter (BOM, kop, ";", ".", datum, quoting, 0-regels, F/W-mapping), HTML-escaping, bestandsnamen, export-guard.
- Bestaande set uitbreiden: Test-Layout (scrWeekReport 1366/1000/700), Test-Components (cmpReportFooter), Test-GeaColors, Test-Fonts, Test-HomeIcons (tegel actief).

## 8. Handmatige stappen Eddy (worden MS-items bij de bouw)
- MS-a: documentbibliotheek "Exports" op de site GEASiteManagment (rechten: wie exporteert moet kunnen schrijven/lezen).
- MS-b: generieke flow (ontwerp uit de Claude-chat): Power Apps V2-trigger, invoer één tekstparameter met JSON-lijst `{fileName, type: "csv" | "html2pdf", content}`; per item opslaan in Exports; bij html2pdf eerst .html opslaan, dan Convert file naar PDF; antwoord per item `{fileName, link, ok, error}`. Eddy levert het definitieve contract (naam van flow en parameter, antwoordformaat) aan; de app volgt dat exact, er worden geen parameters verzonnen.
- MS-c: flow toevoegen aan de app in Studio (Power Automate-paneel), opslaan als .msapr, aanleveren in Incoming; dan pakken we hem uit (verbindingen niet zelf maken).
- MS-d (fase B-proef): converterproef met Arial, A4 liggend, logo.

## 9. Beslispunten voor Eddy
- B1 EmployerCode alleen-lezen voor export gebruiken (AGENTS-regel aanpassen)? Lege code blokkeert export.
- B2 WorkerID in CSV = Worker Code (WKR-...) of SharePoint-ID?
- B3 Medewerkers met weektotaal 0: weglaten in PDF (zoals CSV) of tonen met "–"?
- B4 CSV-quoting volgens RFC 4180 bij ";", '"' of regeleinde in tekst: akkoord?
- B5 TEST-regel zoals par. 5 (TEST-projecten kiesbaar, export met prefix "TEST_", TEST Employer weggelaten in echte projecten)?
- B6 Weekkiezer: Studio-proef in cmpField, anders hand-gebouwd als uitzondering?
- B7 Nieuwe cmpReportFooter (aanbevolen) of cmpFooter uitbreiden?
- B8 Bestandsnamen met tijdstempel zoals par. 6.3?
- B9 Het flowcontract uit de Claude-chat (naam, parameter, antwoordformaat): graag aanleveren of plakken; tot dan is par. 8 MS-b een voorstel.
- B10 AGENTS-regel "CSV-kolommen ... overnemen uit de bestaande Week Report-werkwijze zodra aangeleverd" vervangen door "volgens DECISIONS.md E2"?
