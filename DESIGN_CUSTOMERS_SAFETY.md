# Ontwerp roadmap 1: klanten en projectveiligheid

**VERVALLEN 18-11-2026 (DECISIONS.md H40):** geen lijsten Customers en ProjectSafety, veiligheidsplan deel 1 buiten de app; klant en VGM-toezichthouder als kolommen op Projects (MS-047). Dit document blijft alleen als historie.

Stand 17-11-2026. **Ontwerp ter goedkeuring door Eddy; niet gebouwd.** Besluiten: H38 (V4), H36/H37 (consent). Dit is de basis voor de consent (CONSENT_PLAN.md) en het veiligheidsplan deel 1 (EXCEL_MIGRATION onderdelen A en B).

Feature freeze v1.0.0: dit zijn nieuwe functies, gebouwd na Eddy's akkoord op dit ontwerp.

## 1. Lijsten (SharePoint)

### 1.1 Customers (nieuw)

| Kolom (intern = kop in .xlsx) | Weergavenaam | Type | Verplicht | Opmerking |
|---|---|---|---|---|
| Title | Customer Name | Eén regel tekst | Ja | Uniek afdwingen (MS-045); bedrijfsnaam |
| City | City | Eén regel tekst | Nee | Plaats |
| Phone | Phone | Eén regel tekst | Nee | Algemeen nummer van het bedrijf (geen persoon) |
| Active | Active | Ja/Nee, standaard Ja | – | Nooit verwijderen, alleen deactiveren (Admin screen pattern) |

- **Bestand:** `artifacts\lists\Customers.xlsx` (tabel tblCustomers, 2 synthetische voorbeeldrijen: TEST Customer en TEST Customer 2). Opnieuw maken: `py -E -P artifacts\lists\make_list_templates.py`.
- **Geen persoonsgegevens:** alleen het bedrijfstelefoonnummer. Contactpersonen vallen buiten dit ontwerp.

### 1.2 ProjectSafety (nieuw, 1:1 met Projects)

| Kolom | Type | Opmerking |
|---|---|---|
| Title | Eén regel tekst, uniek | **ProjectKey** = `Text(Projects ID)`, zelfde patroon als Project Workers (filterbaar met `Title = <tekst>`) |
| Project | Lookup → Projects (Title) | Handmatig toevoegen na de import (MS-045); de app schrijft hem mee als controle |
| PlanRelease | Eén regel tekst | Uitgave/revisie van het veiligheidsplan |
| PlanStartDate | Datum (alleen datum) | Startdatum project/plan |
| SupervisorPhone | Eén regel tekst | Telefoon van de GEA-toezichthouder; de persoon zelf = Projects.SiteManagers |
| AssemblyPoint | Meerdere regels tekst (platte tekst) | Verzamelplaats; vertaling: zie vraag D1 |
| FirstAidPhone | Eén regel tekst | BHV + EHBO |
| EmergencyNumber | Eén regel tekst | bv. 112 |
| FireNumber | Eén regel tekst | Brandweer |
| HospitalName, HospitalAddress, HospitalPostalCode, HospitalCity, HospitalPhone | Eén regel tekst | Ziekenhuis |
| PoliceCity, PolicePhone | Eén regel tekst | Politie |
| InspectionName, InspectionCity, InspectionPhone | Eén regel tekst | Arbeidsinspectie (optioneel) |

- **Bestand:** `artifacts\lists\ProjectSafety.xlsx` (tabel tblProjectSafety, 1 synthetische voorbeeldrij met Title "TEST").
- **Geen dubbel adres:** het siteadres staat al op Projects (Street, House Number, Postal Code, City, Country) en wordt daar gebruikt; ProjectSafety herhaalt het niet.
- **Waarom een aparte lijst:** Projects blijft klein, de veiligheidsgegevens kunnen later eigen rechten krijgen, en het Projects-scherm (goedgekeurd, layout-freeze) verandert zo min mogelijk.

### 1.3 Projects (wijziging)
- **Nieuwe kolom Customer:** lookup naar Customers, kolom Title, één waarde, niet verplicht. Maak je handmatig (MS-045).
- **Bestaande kolom 'Customer Name' (tekst):** blijft voorlopig staan, als overgang. De app leest hem alleen nog om een oude waarde te tonen en schrijft hem niet meer. Verwijderen pas na jouw akkoord, als alle projecten een Customer hebben (zoals Employers.Address).

## 2. Schermen

### 2.1 scrCustomers (nieuw, kopie van het Contractors-patroon)
- **Opbouw:** cmpTitleBar "Customers", cmpMessageBar, twee kaarten, cmpFooter (Home, New, Refresh, Discard changes, Save).
- **Lijstkaart:**
  - per rij: regel 1 Customer Name, regel 2 "City";
  - Show inactive;
  - de eerste rij wordt automatisch geselecteerd.
- **Formulier "Customer details":**
  - sectie CUSTOMER met Customer Name* (cmpField), City, Phone;
  - onderaan de Active-switch en "Last changed in SharePoint";
  - statuschip Active / Inactive / New.
- **Opslaan (zelfde regels als Contractors):**
  1. Refresh met een verse read;
  2. lokale validatie;
  3. duplicaatcontrole op naam (Trim, hoofdletterongevoelig): blokkeert;
  4. conflictcontrole;
  5. één Patch;
  6. verify.

  Verwijderen bestaat niet, alleen deactiveren. Deactiveren is toegestaan; projecten houden hun koppeling.
- **Laden:** `Customers` volledig lezen; bij 500 of meer rijen geblokkeerd, met melding.
- **Home:** de tegel "Customers" in Master data wordt actief na de bouw. Het icoon komt uit set v1 als dat past, anders als Soon-icoon; dat zie je in de bouwronde.

### 2.2 scrProjects (kleine wijziging)
- **Veld Customer:** wordt een dropdown (cmpField-dropdown) met de actieve Customers, gesorteerd op naam, plus de huidige waarde als die inactief is.
- **Opslaan:** `Customer: {Id, Value}`; leeg kan.
- **Overgang:** heeft het project nog alleen de oude tekst 'Customer Name', dan toont een grijze subregel "Old value: <tekst>, choose a customer". Die waarde wordt niet geschreven.
- **Conflict- en verifyvergelijking:** gebeurt op Customer.Id.
- **Layout-freeze:** het veld blijft op dezelfde plek (sectie GENERAL, 4e veld); alleen het type verandert.

### 2.3 scrProjectSafety (nieuw, Admin screen pattern)
- **Lijstkaart:** dezelfde projectlijst als Projects (nummer · stad), met Show closed.
- **Formulier "Site safety"** voor het gekozen project, in secties:
  - PLAN: Release, Start date;
  - SUPERVISION: Site supervisor (alleen-lezen uit Projects.SiteManagers), Supervisor phone;
  - EMERGENCY: Assembly point (meerdere regels), First aid (BHV/EHBO), Emergency, Fire;
  - HOSPITAL: Name, Address, Postal code, City, Phone;
  - POLICE: City, Phone;
  - LABOUR INSPECTION: Name, City, Phone.
- **Laden:** per gekozen project één read `Filter(ProjectSafety, Title = varPsfKey)`, met `varPsfKey = Text(<project-ID>)` vooraf gezet (gedelegeerd, geen With-naam in het predicaat).
  - 0 rijen: leeg formulier, status "No safety data yet". Save maakt de rij aan.
  - 1 rij: bewerken.
  - Meer dan 1 rij: rood "Duplicate ProjectSafety rows for this project; fix in SharePoint" en Save geblokkeerd. Nooit automatisch repareren.
- **Opslaan:**
  1. verse read op dezelfde sleutel;
  2. lokale validatie (Release verplicht? zie D3);
  3. conflictcontrole (velden genormaliseerd met Trim);
  4. één Patch: nieuw = `Title` + `Project {Id, Value}` + velden, bestaand = alleen velden;
  5. verify-read;
  6. bij ≥1 write en daarna een fout: Failed.
- **Home:** een nieuwe tegel "Site safety" in Master data. Alternatief: een knop op Projects; footerknoppen zijn daar beperkt, vraag D2.

### 2.4 Teksten
- UI-teksten in T (Engels), zoals bij de andere beheerschermen.
- Documentteksten van het veiligheidsplan volgen later in Translations (`safety.*`), zoals bij de consent.

## 3. Handmatige stappen (MANUAL_STEPS)
- **MS-044:** maak Customers en ProjectSafety met New > List > From Excel uit de twee .xlsx-bestanden. Controleer daarna de kolomtypen. Verwijder daarna de voorbeeldrij "TEST" van ProjectSafety, of zet hem op TEST-000 (zie de stap).
- **MS-045:**
  - uniek afdwingen op Customers.Title en ProjectSafety.Title;
  - lookup ProjectSafety.Project → Projects;
  - lookup Projects.Customer → Customers;
  - Active standaard Ja.

  Waarom handmatig: lookups, unieke waarden en standaardwaarden maak je niet via een Excel-import.
- **Daarna:** metadata verversen in Studio (Data > Add data: Customers, ProjectSafety; Projects > Refresh), opslaan als "This computer" in Incoming. Claude voegt alleen de databronnen samen.

## 4. Volgorde na goedkeuring
1. Eddy: MS-044 en MS-045, daarna een metadata-save in Incoming.
2. Bouw 1: scrCustomers, het Customer-veld op Projects en de Home-tegel, met tests, reviewer en pack.
3. Bouw 2: scrProjectSafety.
4. Bouw 3: de consent (CONSENT_PLAN.md), die Customers en ProjectSafety gebruikt.

## 5. Vragen voor Eddy
- **D1:** de verzamelplaats is vrije tekst per project. In Excel werd hij per taal vertaald (Document Texts). Hoe wil je dat?
  - **a:** alleen Nederlands invullen en vertalen met Translator (H34-patroon, status Draft/Checked);
  - **b:** extra velden per taal;
  - **c:** alleen Nederlands op het document.
- **D2:** Site safety als eigen Home-tegel (voorstel), of via een knop vanaf Projects?
- **D3:** welke ProjectSafety-velden zijn verplicht voordat een consent of veiligheidsplan gemaakt mag worden? Voorstel: SupervisorPhone, AssemblyPoint, FirstAidPhone, EmergencyNumber, HospitalName en HospitalPhone. Ontbreekt er een, dan geen document en een rode melding.
- **D4:** komen de bestaande waarden van 'Customer Name' over naar Customers? Voorstel: jij maakt de klanten aan, ik lever een controlelijst van projecten zonder Customer (alleen in de app, niet in de repo).
