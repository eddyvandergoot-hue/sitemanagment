# Excel/VBA-migratie: inventarisatie (roadmap-item 1)

Stand 16-11-2026, alleen-lezen inventarisatie door Claude. Bron: `Incoming\Excel\<project>_Site_Management.xlsm` (de exacte naam staat in de chat; het bestand is gitignored en staat niet in git). SHA-256 van het geïnventariseerde bestand: 29D17F4D…0E14.

Gelezen op een tijdelijke kopie buiten de repo met openpyxl (keep_vba) en olevba. Er is geen macro uitgevoerd, het origineel is niet gewijzigd en de kopie is daarna verwijderd.

Dit document beschrijft alleen structuur: geen namen, adressen, telefoonnummers of klantwaarden. Waar in het werkboek persoonsgegevens staan, is dat alleen als soort gegeven genoemd.

## 1. Overzicht werkboek

14 werkbladen, 13 Excel-tabellen, 2 draaitabellen, 1 Power Query (HoursLog) en VBA in 21 modules. De macro's hebben Windows Excel nodig, en voor PDF's Adobe Acrobat desktop (AcroExch).

| Werkblad | Tabel | Doel | Invoer | Opzoekingen / formules |
|---|---|---|---|---|
| Project Settings | tblSettings (34 sleutels), tblLanguages (5) | Projectinstellingen, veiligheidsgegevens, mappen, talen | Handmatig, sleutel-waarde | Klant via Customer ID; matrixformules voor jaar- en weeklijsten (Hours-export) |
| Customers | tblCustomers | Klant: ID, naam, adres, postcode, plaats, telefoon | Handmatig | Bron voor Customer in de instellingen |
| Employers | tblEmployers | Werkgever: ID (automatisch), naam, adres, postcode, plaats, telefoon | Handmatig; ID via Worksheet_Change | Lijst EmployerNameList |
| Workers | tblWorkers (21 kolommen) | Medewerkers en hun documenten | Handmatig; knoppen "Sync" en "Consent" | Contractor = keuzelijst Employers; Form Language = keuzelijst talen |
| Hours Entry | tblHoursEntry | Uren in een breed raster: één kolom per medewerker, één rij per dag | Handmatig | ISO-week en ISO-jaar uit de datum |
| HoursLog | tblHoursLog | Lange lijst (datum, KW, jaar, naam, uren, contractor, trade, team) | Power Query (unpivot van Hours Entry) | Controle via macro HRVerifyHoursLog |
| Weekly Hours | tblWeeklyHours | Weekoverzicht per medewerker (ma-zo, som); export naar .xlsx | Periodekeuze (week- of datumbereik) | Projectnummer en -referentie uit de instellingen |
| Weekly Summary | 2 draaitabellen | Per team/contractor: uren F/W, totaal, gepland/gereed aantal, voortgang %, belangrijkste blokkade | Geen | GETPIVOTDATA op HoursLog en Progress Log |
| Lookahead Planning | tblLookahead | Werkpakketten (WP) | Handmatig; WP-ID automatisch "WP-###" | Readiness: Not checked / Blocked / Ready |
| Job Card | (opmaakblad) | Werkinstructie per WP (A4 staand) | WP-keuze in B2 | XLOOKUP op tblLookahead en tblSettings |
| Blockers | tblBlockers | Blokkades | Handmatig | Category: Material, Drawing, Access, Permit, Quality, Resource, Other. Status: Open, In progress, Awaiting decision, Resolved |
| Progress Log | tblProgress | Voortgang per dag per WP | Handmatig; WP uit een keuzelijst | Team, Area en Activity via de WP; KW en ISO-jaar |
| Document Texts | tblDocumentTexts | Vertalingen voor documenten (Assembly Point, Release) in NL/PL/RO/BY/UA | Handmatig of macro | Gebruikt door de consentmacro |
| Sheet1 | – | Kladblad (namen) | – | Niet migreren |

**Kolommen tblWorkers:** Name, Surname, Contractor, Trade (F/W), Team, Certificate Number, VCA Due, Welding permit, Welding Due, Forklift Certificate, MEWP Certificate, Form Language, Home Address, Postcode, City, Phone, email, passport, Limosa, LIMOSA DUE DATE, A1 VALID.

**Kolommen tblLookahead:** Work Package ID, Area, Location, Activity, Drawing Reference, Team, Planned Start, Planned Finish, Planned Qty, Unit, Readiness, Blocker ID, Photo Folder Link (relatief, standaard `Media\<WP>`), Work Instructions, Completion Check.

**Kolommen tblBlockers:** Blocker ID, Date Raised, Team, Area, Work Package, Category, Description, Owner, Required By, Status, Next Action, Resolution.

**Kolommen tblProgress:** Date, Team, Contractor, Area, Work Package, Activity, Planned Qty, Completed Qty, Unit, Blocker / Remark, KW, ISO Year.

**Sleutels tblSettings, in groepen:**
- Klant/locatie: Customer ID, Customer, Address, Postcode, Location, Phone.
- Project: Project Number, Project Reference, Project Name, Start Date, Release, Project Manager.
- Mappen (lokale Windows-paden): Local Project Folder, Consent Template Folder, Consent Draft Folder, PvP Template Folder, Photos.
- Toezicht: Site Supervisor, Site Supervisor Phone.
- Noodgegevens: Hospital, Hospital Address/postcode/City/Phone, Police City/Phone, BHV + EHBO, Emergency, Fire, Assembly Point.
- Arbeidsinspectie: Labour Inspection Name/City/Phone.

**tblLanguages:** Language Code (NL, PL, RO, BY, UA), Language (eigen schrijfwijze), Template File (`Declaration_Of_Consent_<code>_Editable.pdf`), Template File Safety (`SafetyPlan_Part1_<code>`).

## 2. VBA-macro's

| Module | Procedure(s) | Wat het doet |
|---|---|---|
| Module4 | GenerateWorkerForm, SetupConsentSafety | **Consent agreement + veiligheidsplan deel 1**; zie 3.1. SetupConsentSafety vult ontbrekende instellingen, de kolom Template File Safety en de documentteksten aan. |
| Module3 | BuildJobCard, ExportJobCardPDF | **Job Card**: bouwt de opmaak van de werkinstructie en maakt één PDF met foto's en bijlagen; zie 3.2. |
| Module1 | ExportWeeklyHours (+ WH-hulpfuncties) | Schrijft per week en een samenvatting een .xlsx met uren per medewerker. |
| HoursView | SetupWeeklyHoursView, RefreshWeeklyHours, HV* | Bouwt het blad Weekly Hours voor de gekozen periode (week- of datumbereik). |
| Module2 | SyncWorkers, FilterWeeklyHours, SetupWorkerButtons | Maakt per medewerker een urenkolom in Hours Entry (controleert lege en dubbele namen); plaatst knoppen boven tblWorkers. |
| WeeklyHoursRepair | InstallWeeklyHoursRepair, HRVerifyHoursLog | Herstelt de Power Query van HoursLog en vergelijkt de totalen met Hours Entry. |
| Sheet7 (Lookahead) | Worksheet_Change | Nummert nieuwe WP's automatisch `WP-###`. |
| Sheet11 (Employers) | Worksheet_Change | Nummert nieuwe werkgevers automatisch (ID). |
| Sheet1 (Weekly Hours) | Worksheet_Change/Activate | Bouwt de weergave opnieuw bij een andere periodekeuze. |

**Privacypunt:** de VBA bevat een hard gecodeerde persoonsnaam als standaardwaarde voor een instelling. Neem die niet over in de app.

## 3. Uitvoerdocumenten

### 3.1 Consent agreement (per medewerker, in de taal van de medewerker)

- **Start:** cel in de rij van de medewerker op Workers, dan de knop. De taal is Workers.Form Language, gekoppeld via tblLanguages aan de taalcode.
- **Bron:** een invulbaar PDF-formulier per taal (Declaration_Of_Consent_<code>_Editable.pdf) plus veiligheidsplan deel 1 per taal (SafetyPlan_Part1_<code>.pdf). Acrobat vult de velden in en voegt beide samen tot één pakket.
- **Controle door de macro:** de veldwaarden worden na het opslaan opnieuw gelezen, het aantal pagina's wordt gecontroleerd, en er mogen geen dubbele veldnamen zijn. De taalcode in het veiligheidsplan moet gelijk zijn aan Form Language. De oorspronkelijke "datum opstelling" van het veiligheidsplan wordt nooit overschreven.
- **Velden consent:**
  - medewerker: worker_name, worker_address, worker_postcode_city, worker_phone, worker_role (F → Fitter, W → Welder);
  - ondertekening: signed_worker_name, signature_date (vandaag);
  - werkgever: employer_name, employer_address, employer_postcode_city, employer_phone;
  - klant: customer_name, customer_city, customer_phone;
  - project: project_number, gea_safety_supervisor.
- **Velden veiligheidsplan:**
  - klant: safety_customer_name/address/postcode_city/phone/location;
  - inspectie: safety_inspection_name/city/phone;
  - safety_assembly_point (vertaald);
  - ziekenhuis: safety_hospital_name/address/phone;
  - politie: safety_police_city/phone;
  - toezicht: safety_supervisor_name/phone;
  - noodnummers: safety_first_aid_phone, safety_emergency_phone, safety_fire_phone;
  - project: safety_project_name/number/manager;
  - safety_release (vertaald);
  - controlevelden: safety_language_code en safety_preparation_date.
- **Talen:** NL, PL, RO, BY (Wit-Russisch), UA. Alleen Assembly Point en Release worden vertaald (Document Texts); de rest van de tekst staat al vertaald in het PDF-sjabloon.
- **Uitvoer:** `<medewerker>_Consent_<code>_UNSIGNED_<yyyymmdd_HHmmss>.pdf` in de map Consent Draft Folder. Daarna volgen de introductie en de ondertekening op papier (de macro zegt "voltooi de introductie voor ondertekening").
- **Ontvangers:** niet vastgelegd in het werkboek (vraag V5).

### 3.2 Job Card / site work instruction (per werkpakket)

- **Pagina 1 (A4 staand):**
  - blauwe kop "SITE WORK INSTRUCTION", logo rechtsboven;
  - klant | locatie, en "Project: nummer | Reference: …";
  - infoblok: Area, Work location, Assigned team, Planned start/finish, Activity, Drawing / revision, Quantity / unit, Readiness, Blocker reference;
  - blokken WORK INSTRUCTIONS en COMPLETION CHECK;
  - overzicht van foto's en bijlagen (aantallen);
  - lege regels "Completed by / Date" en "Checked by / Date";
  - voettekst "Page x of y".
- **Fotopagina's:** 4 foto's per pagina (jpg/jpeg/png uit `<projectmap>\Media\<WP>\Photo`), met bijschrift en de kop "PHOTO REFERENCES | <WP>".
- **Bijlagen:** afbeeldingen uit `…\Attachment` krijgen elk een eigen pagina. PDF's uit `…\Attachment` worden achteraan samengevoegd (Acrobat).
- **Uitvoer:** `<WP>_JobCard_<yyyymmdd_HHmmss>.pdf`, op een locatie die de gebruiker kiest (nooit in de map Attachment).
- **Taal:** alleen Engels. **Handtekening:** natte handtekening op de lege regels.

### 3.3 Overige uitvoer
- **Weekuren:** .xlsx per week (Module1). In de app vervangen door de Week Report-export (PDF per taal + CSV).
- **Weekly Summary:** alleen op het scherm (draaitabellen), geen document.

## 4. Vergelijking met de app (v1.0.0)

| Excel-onderdeel | In de app | Opmerking |
|---|---|---|
| Hours Entry, HoursLog, Weekly Hours, export | **Bestaat**: Weekly Hours, Hours Summary, Week Report + export | Lang formaat (Hours), per project en contractor; beter dan Excel (inzetperiodes, controles) |
| Workers: naam, contractor, trade, team, taal | **Bestaat**: Workers, Project Workers (team), Workers.Language | Trade F/W → Fitter/Welder (MS-008) |
| Workers: telefoon | **Bestaat** apart: Worker Contacts (D7) | Telefoon niet in Workers |
| Workers: e-mail | **Bewust niet** (D7) | |
| Workers: woonadres, postcode, plaats | **Ontbreekt** (bewust, D7) | Nodig voor consent? Vraag V2 |
| Workers: certificaten (VCA, lassen, heftruck, hoogwerker), Limosa, A1, paspoort | **Ontbreekt** | Gevoelig; vraag V3 |
| Employers: naam, adres, plaats, telefoon, ID | **Bestaat** (Contractors, Employer Code via flow) | Telefoon werkgever controleren |
| Customers | **Ontbreekt** (Client Name is uit Projects verwijderd) | Vraag V4 |
| Project Settings: nummer, referentie, naam, projectleider, toezicht | **Grotendeels**: Projects (Project Leader, Site Managers, adres, Country) | Ontbreekt: Start Date, Release, telefoon toezichthouder |
| Project Settings: nood- en veiligheidsgegevens, inspectie, verzamelplaats | **Ontbreekt** | Voor het veiligheidsplan |
| Talen + Document Texts | **Bestaat**: Translations (8 talen) + AppSettings | BY (Wit-Russisch) ontbreekt in de app; vraag V6 |
| Consent agreement + veiligheidsplan | **Ontbreekt** | Hoofdpunt 1 |
| Lookahead Planning (werkpakketten) | **Ontbreekt** | Hoofdpunt 2 |
| Job Card + foto's + bijlagen | **Ontbreekt** | Hoofdpunt 2 |
| Blockers | **Ontbreekt** | |
| Progress Log | **Ontbreekt** | |
| Weekly Summary (voortgang %, blokkade) | **Deels** (uren in Hours Summary) | Na de werkpakketten |
| P&ID-onderdelen | **Niet in het werkboek** | Alleen "Drawing Reference" per WP; vraag V8 |
| Lokale mappen (Media, Consent, PvP) | n.v.t. | Wordt SharePoint-bibliotheken |

## 5. Voorstel per ontbrekend onderdeel

De grootte is een schatting: S = één bouwronde, M = 2-3 rondes, L = meerdere rondes plus een Studio-test met foto's of documenten. Alles volgt de werkwijze artefacten (AGENTS.md): lijsten als .xlsx-import, teksten als CSV, templates als HTML en flows als importpakket.

| # | Onderdeel | SharePoint | Schermen | Template | Flow | Grootte |
|---|---|---|---|---|---|---|
| A | Projectveiligheid (nood-, ziekenhuis-, politie- en inspectiegegevens, verzamelplaats, Release, Start Date, telefoon toezichthouder) | Kolommen op Projects of een lijst ProjectSafety (1:1 met project) | Sectie of tab "Safety" op Projects | – | – | S |
| B | Klant | Kolommen op Projects (Client, Client address/city/phone) of een lijst Customers | Projects-formulier | – | – | S |
| C | Consent agreement + veiligheidsplan deel 1 per medewerker | Lijst ConsentAgreements (Worker, Project, Language, Status Draft/Issued/Signed/Archived, Generated, Signed date, FileUrl). Bibliotheek Consents (unsigned + gescande signed) | Op Workers of Project / team: "Generate consent" per medewerker of selectie; status + upload signed scan | HTML per document (consent, safety plan), vaste teksten per taal in Translations (veel tekst: juridisch, vraag V1) | Bestaande Export file (Format pdf, TemplateName) hergebruiken: per taal één PDF; samenvoegen is niet nodig als beide in één HTML zitten | L |
| D | Werkpakketten (Lookahead) | Lijst WorkPackages (WP-ID automatisch via flow zoals EMP/WKR, Project, Area, Location, Activity, Drawing Reference, Team, Planned Start/Finish, Planned Qty, Unit, Readiness, Work Instructions, Completion Check) | Beheerscherm WorkPackages (Admin screen pattern), filter per project | – | Kleine flow voor het WP-nummer (patroon MS-019) | M |
| E | Foto's en bijlagen per WP (veldtaak, telefoon) | Bibliotheek WorkPackageMedia, map per project/WP (Photo, Attachment) of bijlagen op het lijstitem | Veldscherm: camera/upload, bijschrift (koppelt aan v1.1 telefoonlayout) | – | – | M |
| F | Job Card-PDF | – | Knop "Job card" op WorkPackages | HTML job card (A4 staand, GEA-palet, logo) | Export file hergebruiken voor pagina 1. Foto's: base64 in de HTML is beperkt door de grootte. PDF-bijlagen samenvoegen kan niet met standaardconnectors (vraag V7) | L |
| G | Blockers | Lijst Blockers (zelfde kolommen, keuzes Category/Status, lookup WP) | Lijst + formulier, of veldscherm "Report blocker" | – | – | M |
| H | Progress Log | Lijst Progress (Date, WP, Contractor, Completed Qty, Remark; Team/Area/Activity via WP, ISO-week afgeleid) | Veldscherm "Daily progress" | – | – | M |
| I | Voortgangsoverzicht (Weekly Summary) | – | Uitbreiding Hours Summary of een nieuw rapport (uren + gepland/gereed + blokkade) | Eventueel export | – | S (na D, G, H) |
| J | Certificaten / Limosa / A1 | Lijst WorkerDocuments (Worker, Type, Valid until, Status; geen documentnummers tenzij verplicht) met beperkte rechten | Op Workers, met waarschuwing bij verlopen | – | Eventueel herinneringsflow | M |

**Aanbevolen volgorde:**
1. A en B (klein; nodig voor C).
2. C (consent, hoofdwens).
3. D en E (werkpakketten met foto's, samen met de telefoonlayout van de veldschermen).
4. F (job card).
5. G en H.
6. I.

J kan los, na Eddy's privacybesluit.

### 5.1 Ontwerp: vertaling van werkinstructies (H34, Eddy 16-11-2026; niet gebouwd)

**Doel:** de job card ook in de taal van het team of de contractor (taal 2), zonder alles met de hand te vertalen.

**SharePoint, lijst WorkPackages** (deel van onderdeel D). Naast de bestaande velden Work Instructions en Completion Check (taal 1):
- `Language2`: keuze, dezelfde 8 waarden als Workers/Employers/Translations (H30);
- `Work Instructions 2` en `Completion Check 2`: meerdere regels tekst;
- `Translation Status`: keuze Draft / Checked, standaard leeg;
- `Translation Checked By`: persoon;
- `Translation Checked`: datum.

De kolomnamen worden definitief bij het maken van de lijst (.xlsx-import) en daarna in de metadata gecontroleerd.

**Flow "SiteManagement - Translate text"** (nieuw, importpakket, Create as new):
- **Trigger:** Power Apps V2 met de invoer `text`, `from` en `to` (ISO 639-1-codes, zelfde mapping als de Week Report-export: nl, en, pl, cs, ro, uk, de, fr).
- **Actie:** Microsoft Translator V2 "Translate text" via de verbinding "Translator SiteManagement" (MS-041).
- **Respond:** `status` (OK | Error), `text`, `message`.
- Geen andere stappen, geen opslag en geen bedrijfslogica. De exacte operationId en parameternamen van de connectoractie worden bij de bouw gecontroleerd; niets verzinnen.

**App, scherm WorkPackages (beheerpatroon):**
1. Knop "Translate" (secundair) naast de taal-2-velden. Actief alleen als er een record geselecteerd is, `Language2` gevuld en anders dan taal 1, taal 1 niet leeg, en er geen onopgeslagen wijziging of lopende load/save is. Dezelfde voorwaarde geldt als eerste OnSelect-voorwaarde.
2. Twee aanroepen, één per veld; alleen die twee velden worden verstuurd.
3. Het resultaat komt in de concepttekst van `Work Instructions 2` / `Completion Check 2` en de status wordt Draft. Er wordt niet automatisch opgeslagen: Eddy controleert, past aan en slaat op met Save.
4. Fout, limiet of storing: amber "Not translated. <reden>. Paste the translation manually." De velden blijven bewerkbaar, dus handmatig plakken kan altijd.
5. "Mark checked" (of de switch Checked) zet Checked, Checked By (huidige gebruiker) en de datum. Elke latere wijziging van taal 1 of taal 2 zet de status terug naar Draft.

**Job card (onderdeel F; H35, V10 beantwoord 16-11-2026):**
- **Language2 leeg:** één PDF in taal 1.
- **Language2 gevuld en Checked:** daarnaast een tweede, eigen PDF in taal 2 met eigen paginanummering, zoals H31: `<basis>_<taalcode>.pdf`, met de taal-1-PDF eerst en PDF 2 pas als PDF 1 gelukt is.
- **Language2 gevuld en Draft (of een lege status):** alleen de PDF in taal 1, met de amber melding "Language 2 not checked; job card in <taal 1> only".
- De vaste labels van de job card komen uit Translations (doc.jc*-sleutels), net als bij het Week Report.

**Wit-Russisch (`be`, H35):** als Translator V2 de taal niet ondersteunt (te controleren bij de bouw), kan het alleen met handmatig plakken. De knop Translate is dan voor die taal uitgeschakeld, met de hint "Machine translation not available for Belarusian. Paste the translation manually." Checked en de tweede PDF werken verder gewoon.

**Privacy en grenzen:**
- Alleen instructietekst gaat naar Microsoft Translator. Daarom staan in de UI-hint en in AGENTS: geen namen, telefoonnummers of adressen in deze velden.
- Er gaan geen persoonsvelden of -records naar de flow.
- Lange teksten: de limiet van de connector wordt bij de bouw gecontroleerd. Boven de limiet volgt een melding en handmatig plakken; er wordt niet stilzwijgend afgekapt.
- Wit-Russisch (`be`): de taal komt er alleen als V6 "ja" is; machinevertaling alleen als Translator V2 de taal ondersteunt (zie hierboven).

**Grootte:** S bovenop D (één flowpakket, twee knoppen, vijf kolommen).

## 6. Vragen voor Eddy

1. **V1 Consent-tekst** — BEANTWOORD 17-11-2026 (H36, CONSENT_PLAN.md): eigen app-versie van FOR-010.040 als HTML-template, teksten in Translations, HSE-feedback bij de presentatie. Oorspronkelijke vraag: de consent en het veiligheidsplan zijn nu invulbare PDF's per taal. Mogen de vaste teksten als HTML-template nagebouwd worden (teksten per taal in Translations)? Of moet het originele PDF-formulier blijven? Dat laatste kan niet met standaardconnectors (premium Adobe/Encodian nodig). Wie is eigenaar van de juridische tekst?
2. **V2 Woonadres en telefoon in de consent** — BEANTWOORD 17-11-2026 (H36): van het formulier verwijderd, niet opgeslagen en niet afgedrukt. Oorspronkelijke vraag: de consent bevat woonadres, postcode/plaats en telefoon van de medewerker. Workers bevat die bewust niet (D7). Is het woonadres echt verplicht? Zo ja: als aparte lijst met beperkte rechten zoals Worker Contacts, of alleen invullen op het document (niet opslaan)?
3. **V3 Certificaten, Limosa, A1, paspoort:** welke moeten in de app staan? Alleen geldigheidsdatum en status, of ook nummers? Wie mag ze zien?
4. **V4 Klant:** aparte lijst Customers (hergebruik over projecten) of klantvelden op Projects?
5. **V5 Ondertekening en ontvangers:** consent op papier tekenen en de scan uploaden, of digitaal tekenen? Wie ontvangt het getekende pakket (klant, GEA-veiligheid, contractor) en hoe lang wordt het bewaard?
6. **V6 Wit-Russisch** — BEANTWOORD 17-11-2026 (H37): ja, 9e taal (MS-043). Oorspronkelijke vraag: het werkboek kent BY (Belarusian); de app niet. Toevoegen als 9e taal (procedure "Nieuwe taal", ISO-code `be`)?
7. **V7 Job Card-bijlagen:** PDF-bijlagen achter de job card samenvoegen kan alleen met een premium connector. Is een job card met een lijst links naar de bijlagen voldoende, met foto's in de PDF?
8. **V8 P&ID-onderdelen:** het werkboek bevat geen P&ID-gegevens, alleen "Drawing Reference" per WP. Wat bedoel je met P&ID parts: koppeling met de P&ID-tracker (ander project) of een onderdelenlijst per WP?
9. **V9 Werkpakketten per project of per team:** de WP-ID is in Excel per werkboek (= project) uniek. In de app WP-<ID> globaal, of `<projectnummer>-WP-###`?
10. **V10 Talen van de Job Card** — BEANTWOORD 16-11-2026 (H34, H35, 5.1): alleen tweetalig als Language2 gevuld is; taal 2 als eigen PDF, alleen bij Checked. Oorspronkelijke vraag: alleen Engels zoals nu, of ook in de taal van het team/contractor?

## 7. Niet migreren
- Het brede urenraster (kolom per medewerker), de Power Query HoursLog en de herstelmacro: vervangen door de lijst Hours.
- Sheet1 (kladblad).
- Lokale Windows-paden: worden SharePoint-bibliotheken.
- De .xlsx-weekexport: vervangen door de Week Report-export.
- Knoppen en automatische nummering in Excel: in de app via flows (EMP/WKR, straks WP).
