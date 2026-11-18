# Release notes

## v1.0.1 — 18-11-2026 (fixrelease)

Goedgekeurd door Eddy op 18-11-2026 na de Studio-test op TEST-000 (PASS: Project / team filter, zoeken en weekpijlen; Weekly Hours teamkeuze, uitgeschakeld bij onopgeslagen uren; Week report TEST-000). Gepubliceerd door Eddy op 18-11-2026 (Replace "SiteManagement" + Publish). Tags: `v1.0.1` en `approved-20261118-v1.0.1`. Testbuild: `v1.0.1-20261118_212114` (SHA-256 `05cf668efc48f68c0a856752549c5d75b317ce0bb56fcdc2eb74846998dfd8ce`).

### Wijzigingen
- **Weekly Hours:**
  - Een nieuwe dag voor een inactieve medewerker geeft een eigen melding met de naam: "Not saved: <name> is inactive in Workers but still active in Project / team. …". Er wordt dan niets opgeslagen. Vroeger kwam hier de verwarrende conflictmelding.
  - Bij het laden krijgt de rij van zo'n medewerker het label "Inactive worker (no new days)". Nieuwe dagen staan dan uit; bestaande dagen kun je nog corrigeren.
  - Nieuwe teamkeuze (Team) naast de week. Met onopgeslagen uren is die uitgeschakeld (amber melding als het toch gebeurt). De echte conflictmelding blijft voor echte conflicten.
- **Project / team:**
  - Na het laden een amber waarschuwing bij een inzetperiode zonder Project Workers-rij en bij een inactieve medewerker met een actieve koppeling.
  - De lijst toont geen inactieve medewerkers, behalve met een periode in de gekozen week. Medewerkers van TEST Employer zie je alleen op TEST-projecten. Geselecteerde medewerkers blijven altijd zichtbaar.
  - Nieuw: een filter op contractor, een zoekveld en weekpijlen naast de week.
- **Week Report:** de melding bij een periode zonder koppeling noemt nu de oorzaak en de oplossing: "Project Workers row missing (deleted?) – restore it from the SharePoint Recycle Bin."
- **Workers:** de melding bij een geblokkeerde deactivering noemt project, team en de week waarin de koppeling opende.
- **Importflow "SiteManagement - Import rows" v3** (los pakket, MS-049):
  - leest de lijst één keer in plaats van per regel en verwerkt 10 regels tegelijk;
  - dubbele sleutels in het bestand blokkeren het bestand;
  - lijsten met meer dan 5000 rijen worden geweigerd;
  - een mislukte leesactie staat als fout in het resultaat.

### Bekend / niet getest
- Niet getest: de deactiveringsmelding van Workers met project, team en "open since". Er was geen actieve gekoppelde testmedewerker; hertest zodra het geval zich voordoet (backlog).
- De inactieve-medewerkerpaden in Weekly Hours en de amber waarschuwing in Project / team zijn alleen technisch getest.
- Importflow v3 is nog niet geïmporteerd (MS-049, bij de volgende import).

## v1.0.0 — 16-11-2026 (eerste stabiele versie)

Goedgekeurd door Eddy op 16-11-2026 na de Studio-test TP-EXPORT-02 (c7-hertest en c8 stap 4 PASS). Tags: `v1.0.0` en `approved-20261116-weekreport-c8`. De Src van deze release is gelijk aan testbuild c8 (`weekreport-export-c8-20261116_201344`, SHA-256 `D76BD5A8557948213B0637EB763BC9586C00D2ED217BCC051DA803DC6B528BE8`).

Gepubliceerd door Eddy op 16-11-2026 als cloud-app "SiteManagement" (vervangt de oorspronkelijke "Site Managment"; cloud App ID 5d595ec0-97d7-49f5-80b4-09a65cfa1e30).

Power Apps canvas-app (Power Apps Studio, browser) op SharePoint-lijsten, met één Power Automate-flow voor het schrijven van exportbestanden. Bij deze release hoort geen .msapp en geen persoonsgegevens; het pakket maak je uit de bron (zie Publiceren).

### Inhoud

**Startscherm**
- Home met tegels per categorie. Actief zijn Team & hours en Master data. Inventory, CAD tools en Knowledge zijn nog "Soon".

**Stamgegevens (beheerschermen)**
Alle drie volgen hetzelfde patroon: lijst plus formulier, meldingsbalk, opslaan met conflictcontrole, nooit verwijderen maar deactiveren.
- **Contractors** (lijst Employers): naam, Contractor Code (alleen-lezen, flow vult `EMP-<ID>`), adres, contact.
- **Projects**: Project Number (uniek), Status (Active/On hold/Closed), adres en Country, Project Leader en Site Managers.
- **Workers**: First Name, Surname, Contractor, Trade (Fitter/Welder/Unknown) en Language. Worker Name en Worker Code worden automatisch gevuld. Telefoonnummers staan in een aparte lijst (Worker Contacts).

**Team en uren**
- **Project / team**: medewerkers koppelen aan project en team (1-10) per week, met inzetperiodes (Assignment Periods).
- **Weekly Hours**: uren per week invoeren, maandag t/m zondag, met weektotaal en opslaan in batch met verificatie.
- **Hours Summary**: overzicht per medewerker en contractor over een periode van volledige ISO-weken, met periodetotaal.

**Week Report en export**
- Alleen-lezen weekrapport per project, per contractor of alle contractors.
- Export per contractor. Een bestand bevat nooit uren van een andere contractor; bij "All contractors" krijgt elke contractor zijn eigen bestanden.
- **PDF per taal**: `…_<code>_<taal>.pdf`. De eerste PDF is in de primaire rapporttaal uit AppSettings, de tweede in de taal van de contractor. Zijn die talen gelijk, dan komt er één PDF.
- **Eén CSV per contractor**: alle tekst-, datum- en urenvelden staan tussen aanhalingstekens. Scheidingsteken en decimaalteken komen uit AppSettings.
- Het land in het infoblok wordt in de paginataal getoond.
- TEST-projecten krijgen het voorvoegsel `TEST_`.
- Elke uitkomst krijgt een melding: groen bij opgeslagen, amber bij deels opgeslagen of overgeslagen, rood bij niet opgeslagen. Een melding noemt altijd de reden.
- Bestanden komen in de bibliotheek Exports, map `<ProjectNumber>`.

**Power Automate**
- **"SiteManagement - Export file"**: generieke bestandsschrijver (Folder, FileName, Format csv/pdf, Content, TemplateName → Status, FileUrl, Message). Versie fix1, geïmporteerd 16-11-2026. Een geschoonde definitie staat in `flows/`.
- **"Workers - Worker Name sync"** (MS-017) en de flow die Employer Code vult (MS-019).

**SharePoint**
- **Lijsten**: Projects, Employers, Workers, Project Workers, Assignment Periods, Hours, Worker Contacts, Translations en AppSettings.
- **Bibliotheken**: Templates (PDF-opmaak, bron in `templates/`) en Exports.
- **Translations**, 568 regels:
  - 23 documentteksten × 8 talen (Dutch, English, Polish, Czech, Romanian, Ukrainian, German, French);
  - 48 landnamen × 8 talen.

  De bronbestanden staan in `templates/translations-weekreport.csv` en `templates/translations-countries.csv`.
- **AppSettings**: `report.primaryLanguage` = Dutch, `csv.separator` = `,`, `csv.decimalSeparator` = `,`.

### Handmatige stappen (MANUAL_STEPS.md)
- **Gedaan:** MS-001, MS-005, MS-008, MS-009, MS-010, MS-013 t/m MS-020, MS-022 t/m MS-033, MS-034 stap 1, MS-035 t/m MS-039.
- **Open:**
  - MS-034 stap 2-3: Employers.Language op "Require" zetten. Pas doen nadat het Language-veld op het Contractors-scherm staat; dat werk staat op een aparte branch en is geen onderdeel van v1.0.0.
  - MS-012 deels: groep Site Supervisors, unieke rechten en het opschonen van de versiegeschiedenis.
  - MS-021: rechten Site Supervisors, bij go-live.
  - MS-004, MS-007 en MS-011: gepland (SECURITY.md).

### Bekende beperkingen en backlog
- **Language van contractors**: op het Contractors-scherm is dit veld nog niet zichtbaar; je vult het in SharePoint in. Ontbreekt de taal, dan wordt er voor die contractor niets geëxporteerd en krijg je een rode melding.
- **Landnamen**: een land van Projects.Country dat niet in Translations staat, verschijnt in het Engels in de PDF. Dat blokkeert de export niet.
- **CSV in Excel**: bij dubbelklikken splitst Excel op de lijstscheiding van de pc. `csv.separator` moet daar dus gelijk aan zijn. Excel > Data > From Text/CSV werkt altijd.
- **Vertalingen**: pl, ro, de, uk, cs en fr zijn nog niet door een moedertaalspreker gecontroleerd.
- **Hours Summary-export**: nog niet gebouwd.
- **UX-ronde 4b**:
  - Weekly Hours: Save is actief zonder wijzigingen, en een mislukte Save geeft een dubbele melding.
  - Project / team en Weekly Hours gebruiken nog Notify in plaats van de meldingsbalk.
- **Workers**: een medewerker die al inactief is, krijgt bij Save van een nieuwe dag de algemene conflictmelding (er wordt niets geschreven). Verdere details staan in PROJECT_STATUS.md.
- **ISO-week 53 rond de jaarwisseling**: alleen lokaal getest. Het natuurlijke testmoment is 28-12-2026 t/m 03-01-2027.
- **Smalle vensters en telefoon**: niet volledig getest. Tabellen scrollen dan horizontaal.
- **Niet volledig gecontroleerd in Monitor**: delegatie van de serverqueries (Studio Monitor).

### Publiceren (handmatig door Eddy)
De app wordt niet automatisch gepubliceerd en de bestaande productieapp wordt niet overschreven.
1. Pack uit de projectmap: `pac canvas pack --sources "." --layout SourceCode --msapp <bestand>.msapp`. Je kunt ook de c8-build gebruiken; controleer dan eerst de SHA-256.
2. Power Apps Studio > Open > Browse files > het .msapp-bestand.
3. Controleer of de verbindingen naar GEASiteManagment en de flow "SiteManagment-Exportfile" wijzen.
4. Save, en daarna Publish.
5. Deel de app met de gebruikers. De rechten (MS-021) volgen bij go-live.
