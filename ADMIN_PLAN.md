# Admin screens: bouwplan (Contractors -> Projects -> Workers)

Status 27-10-2026: PLAN, niets gebouwd, niets in Studio getest. Besluiten: DECISIONS.md H13. Regels die bij de bouw gaan gelden komen pas dan in AGENTS.md. Bronnen: logica-, UI- en reviewplan van 27-10-2026 (samengevoegd; bij conflict wint Eddy's besluit).

## 0. Status en besluiten (samenvatting)
- Bouwvolgorde: Contractors, daarna Projects, daarna Workers. Een scherm per build; per build: powerfx-logic, reviewer, powerfx-ui, verifier (volledige set + pack), dan Eddy's Studio-test en akkoord vóór het volgende scherm.
- UI-taal Engels op alle schermen; term "Contractor" overal in de UI (SharePoint-lijst blijft Employers, interne namen ongewijzigd). Titels en Home-tegels: Contractors / Projects / Workers. Documenten later Nederlands.
- Vertaaltabel T vanaf de nieuwe schermen (par. 2.8); bestaande schermen volgen in UX-ronde 4b (Nederlandse meldingen naar Engels, "Employer" naar "Contractor", omzetten naar T). Globe-icoon (taalkeuze) later, niet nu.
- Duplicaten: Projects BLOKKEREN op Project Number; Contractors BLOKKEREN op gelijke naam (Trim, hoofdletterongevoelig); Workers WAARSCHUWEN met bevestigingsvinkje (First Name + Surname + Contractor).
- Person-velden (Project Leader, Site Managers; elk één persoon) alleen-lezen in v1; later people picker. Geen Office365Users-connector (verbindingen blijven ongewijzigd).
- Geen filter op login nu ("My projects" later). Admin-tegels zichtbaar voor iedereen; rechten (MS-021) uitgesteld tot go-live (testfase: Eddy is enige gebruiker).
- Groene Save op de beheerschermen: ja. De AGENTS-regel (groen alleen btnSaveWeek/btnAddtoTeam) en Test-GeaColors.ps1 worden pas bij de Contractors-build aangepast.
- Nieuwe testrecords toegestaan met prefix TEST (bv. "TEST Contractor 2", TEST-002, "Test Admin"); nooit verwijderen, alleen deactiveren.
- Besluit 11 (Screen1 verbergt Closed projecten en inactieve medewerkers; On hold blijft zichtbaar; Hours Summary toont alles; admin "Show inactive" standaard uit) wijzigt goedgekeurde schermen. Voorstel, bevestigen: Closed in de Projects-build, inactieve medewerkers in de Workers-build (par. 4.5, 5.5).

## 1. Fase 0 (voor de Contractors-build)
1. MS-020 (Eddy) - gedaan 27-10-2026: Incoming\20261027-Site Managment.msapp. Reden: lokale metadata (26-10) mist de nieuwe kolommen en heeft Employer Code nog verplicht (een Patch van een nieuwe contractor faalt dan client-side).
2. Gedaan 27-10-2026: alleen DataSources.json in de .msapr samengevoegd (app-ID, lijst-ID's, verbindingen ongewijzigd); interne namen hieronder.
3. Regressiebuild gebouwd (pad/SHA-256: PROJECT_STATUS.md). Studio-Src vergeleken: geen formulewijzigingen, geen hernoemde Title/kolommen; alleen herserialisatie en ModernDatePicker 1.0.2 (niet overgenomen). Conventie: de app gebruikt interne namen; Title-weergavenamen van Employers en Projects blijven "Title" (Workers: "Worker Name").
4. Identifiercontrole: 'Project Number' heeft interne naam ProjectName (valkuil). Statische test: kale identifier `ProjectName` komt nergens voor; 'Project Name' alleen voor Title.
5. Wacht op Eddy's Studio-regressiecheck (Project / team, Weekly Hours, Hours Summary); dan pas de Contractors-build.
- Interne namen (DataSources.json 27-10-2026; weergavenaam tussen aanhalingstekens):
  - Employers: Title; EmployerCode1 "Employer Code" (niet meer verplicht); Address; Postalcode; City; ContactPerson "Contact Name"; Phone "Contact Phone"; ContactEmail1 "Contact Email" (string, gewone tekst; NIEUWE kolom, de oude Email (uri) bestaat niet meer); Country (tekst); Active (boolean). Geen verplichte kolommen.
  - Projects: Title; ProjectName "Project Number" (verplicht); ProjectReference; CustomerName; Status (keuze, verplicht, standaard Active); Street; House_x0020_Number "House Number"; Postal_x0020_Code "Postal Code"; City; Country (KEUZE, standaard "Netherlands"); ProjectLeader1 "Project Leader" (Person, ENKEL; NIEUWE kolom, oude meervoudige ProjectLeader weg); SiteManagers "Site Managers" (Person, ENKEL); ProjectHomeSiteURL "ProjectHomeSite URL" (format uri). Location en SiteSupervisor bestaan niet meer.
  - Workers: Title "Worker Name"; field_1 "Worker Code"; field_2 First Name; field_3 Surname; field_6 Trade (verplicht); Language (keuze; metadata-standaard "English"; verplicht op Workers is alleen field_6); Active (boolean).
- Fase-0 punten (a)-(d) beantwoord door Eddy 27-10-2026 en in de tweede metadata-merge (MS-020) gecontroleerd: (a) Contact Email = tekst (ContactEmail1); OPEN CONTROLE: waarden uit de oude Email-kolom staan niet in de nieuwe kolom tenzij Eddy ze kopieerde; (b) Projects.Country blijft keuze (standaard Netherlands): keuzedropdown op Projects, tekst op Contractors; (c) Project Leader en Site Managers zijn elk ENKELE persoon (DECISIONS.md H14); (d) OPEN: Workers.Language heeft in de metadata standaard "English", niet "Nederlands". Eddy controleert de kolomstandaard in SharePoint en ververst de metadata opnieuw als die na de save is gewijzigd; anders rekent de app niet op de SharePoint-standaard en vult het nieuwe-medewerkerformulier "Nederlands" expliciet voor.

## 2. Gedeeld ontwerp
### 2.1 Layout (powerfx-ui)
- Scherm #F0F0F0; blauwe titelbalk 56 px met logo (imgLogoEmployers/Projects/Workers, regels uit AGENTS.md) en titel. Body tussen titelbalk en footer in een scrollbare container; footer erbuiten.
- Breed (schermbreedte >= 1000): links lijstpaneel 400 px (zoekvak 40 + Gallery@2.15.0, rij 56 px; regel 1 naam, regel 2 code/plaats/status; geselecteerd #D5EDFF), rechts wit formulierpaneel (X = 40+400+24, radius 10, rand #DCDCDC). Smal (< 1000): lijst bovenaan (max 280 px, eigen scroll), formulier eronder. Breakpoint via verborgen layoutlabel (zoals lblHomeLayout). Velden rekken niet mee: kort 256, lang 512; twee 256-velden naast elkaar vanaf paneelbinnenbreedte 536.
- Controls alleen uit Templates.json: Label 2.5.1, Classic/TextInput 2.3.2, Classic/DropDown 2.3.1 (volledige AGENTS-dropdownset), Classic/CheckBox 2.1.0, Gallery 2.15.0, Button 2.2.0 (geen AccessibleLabel), GroupContainer 1.5.0, Rectangle 2.3.0, Image 2.2.3. Geen Form/EditForm, ComboBox, Toggle of people picker (geen template).
- Invoer: Fill #F0F0F0, rand #DCDCDC, hover/focus #0303B8, Inter Normal 12, hoogte 40. Alleen-lezen velden (Contractor Code, Worker Name, Worker Code, Person-velden): Label@2.5.1 met zwarte tekst en suffix "(automatic)"; geen uitgeschakelde invoer met grijze tekst.
- Inactief wordt als tekst "Inactive" in de subregel getoond (kleur is nooit het enige signaal). Geen Delete-knop.
- Footer (volgens AGENTS): Home 90 links (eerste); rechts New, Refresh, Discard changes, Save (Save groen #1AFF80, hover #18DD6E, tekst #000F41). Y/Height/X/gap uit lblFooterButtonMetrics van Screen1 (niet dupliceren). Minimale rijbreedte ~808 px; breedtes bij de bouw met Measure-FontFit.
- Home: tegels btnTileEmployers/btnTileProjects/btnTileWorkers worden pas actief als hun scherm gebouwd is (actieve stijl uit AGENTS; iconen alleen uit bewezen enumwaarden, bv. Icon.People, Icon.DetailList; Icon.Building/Icon.Cog niet geverifieerd); lblTileSub* ("Coming soon") dan weg. Tegeltitels Contractors / Projects / Workers.

### 2.2 Namen
- Interne schermnamen blijven bij de lijsten: scrEmployers (UI "Contractors"), scrProjects, scrWorkers. Unieke controlnamen app-wide met schermprefix: conEmpBody, navEmp, conEmpButtonRow, btnEmpSave, ... (Prj, Wrk analoog). Variabelen en collections met prefix Emp/Prj/Wrk (varEmpDirty, colAdminEmployers, colEmpSaveErrors); geen gedeelde varAdminDirty.
- Per scherm: varXxxLoadState (NotLoaded/Loading/Failed/Loaded), varXxxBusy, varXxxSaving, varXxxSaveFailed, varXxxMode ("", "New", "Edit"), varXxxEdit (snapshot), varXxxSelectedID, colAdminXxx (geladen lijst), colPendingAdminXxx (staging), colXxxLoadErrors, colXxxSaveErrors, colXxxPre (pre-read).

### 2.3 Status, fouten, dirty
- Statusregel: vaste hoogte 34, max 2 regels met "...", gecentreerd, zwart; rood #DB1E28 alleen bij fout; een samenvattende melding. Alle validatiefouten van een Save staan als lijst (AutoHeight-label) in het scrollende formulier, gevoed door colXxxSaveErrors; veldrand rood #DB1E28 bij fout. Meldingen zeggen wat te doen ("fix in the form" / "Refresh" / "check in SharePoint").
- Dirty: de guard vergelijkt de `.Text`/`.Value` van de inputs rechtstreeks met varXxxEdit (dezelfde expressie in DisplayMode en OnSelect), niet via OnChange (blur-beperking). Het formulier bindt nooit aan `gal.Selected` maar aan varXxxEdit + varXxxSelectedID. Gallery-selectie, New, Refresh en Home zijn geblokkeerd bij dirty/busy/saving (DisplayMode + eerste OnSelect-voorwaarde, tekstueel gelijk).
- Discard changes: lokaal Reset naar varXxxEdit; in varXxxSaveFailed geforceerd herladen via de loader; nooit bronmutatie.

### 2.4 Laden (staging, 500-guard)
- Loader (verborgen knop btnXxxLoad, gestart door OnVisible als niet Loaded en niet dirty): Busy aan, LoadState Loading, `ClearCollect(colPendingAdminXxx, ForAll(Sort(<bron>,...) As x, {expliciete recordprojectie}))` met IfError per bron, geen ShowColumns/Choices in lussen. >= 500 rijen = fout, beheer geblokkeerd. Pas bij geen fouten: colAdminXxx = staging, Loaded; anders Failed, oude lijst alleen-lezen, Save geblokkeerd. Geen Patch/Update/Remove in loaders. Onafhankelijke loads (Workers + Contractors) via Concurrent met eigen foutcollecties.
- Keuzewaarden (Status, Language, Trade) één keer in de loader via Choices(), met controle op verwachte waarden (anders Failed). Dropdownwaarden zijn SharePoint-waarden en worden niet vertaald.
- Zoeken lokaal op de volledig geladen collectie (Filter + `in`/Lower); "Show inactive" standaard uit. Uitwijk bij ooit >= 500: StartsWith met globale variabele (min. 2 tekens).

### 2.5 Opslaan (fail-closed)
- Guard (DisplayMode = eerste OnSelect-voorwaarde): `varXxxLoadState="Loaded" && !varXxxBusy && !varXxxSaving && !varXxxSaveFailed && dirty && varXxxMode in ["New","Edit"] && IsEmpty(colXxxLoadErrors)` en bij Edit een ID.
- Volgorde: guard; Saving aan, globale vars voor predicaten (varXxxSaveID, varXxxSaveName/Number...); alle lokale validatie (fouten verzamelen; een fout = nul reads/writes, staat blijft Loaded); pre-read op ID (exact 1 rij) + duplicaatquery (delegeerbaar, `=` op kolom met globale var); conflictcheck (2.6); een Patch (nieuw: `Patch(Source, Defaults(Source), rec)`, bewerken: `Patch(Source, preReadRecord, rec)`); verify-read op ID en vergelijk alle geschreven velden (Coalesce naar ""); alleen uit de verify-read colAdminXxx en varXxxEdit bijwerken, dirty uit, Mode "Edit", cache-invalidatie (2.7), Trace.
- Patch niet geslaagd of verify mislukt na write: SaveFailed, invoer behouden, Save geblokkeerd, melding "check the item in SharePoint (Modified / version history)"; geen automatische herhaling of correctie. Nieuw item met Patch-fout: onzeker of het bestaat; advies Refresh en zoeken op naam. Geen Remove/RemoveIf; deactiveren = Active uit (Projects: Status).
- Totaal 2 pre-reads + 1 Patch + 1 verify; geen Choices()/remote LookUp in lussen.
- Trace (alleen ID's en aantallen, nooit namen of FirstError.Message): `DIAG|Admin|LoadEnd`, `|SaveEnd` (Screen, Mode, ItemID, ElapsedMs, Reads, Writes, Verified, DupFound, Errors), `|Discard`, `|Conflict`.

### 2.6 Gelijktijdigheidscheck
- Vergelijk pre-read met varXxxEdit via één projectiefunctie voor laden en pre-read, alleen over velden die de app schrijft en bij lookups alleen `Employer.Id` (niet `.Value`). Niet vergelijken: Modified, Person-velden, door flows gezette velden (Workers.Title en Worker Code via MS-017, Contractor Code via MS-019). Afwijking = fout "item changed in SharePoint, Refresh", nul writes, Trace Conflict. Flows lussen niet: Workers-Title = `Trim(fn) & " " & Trim(sn)` gelijk aan de flowuitkomst.

### 2.7 Cache-invalidatie na geverifieerde Save
- Vlaggen op false en de bron verversen (vlaggen alleen verversen de connectorcache niet; `Refresh` is geen mutatie):
  - Contractors: varWorkersCacheReady, varMastersReady, varReportReady; `Refresh(Employers)`, `Refresh(Workers)`; Workers-scherm LoadState NotLoaded.
  - Projects: varProjectsCacheReady, varMastersReady, varReportReady; `Refresh(Projects)`.
  - Workers: varWorkersCacheReady, varMastersReady, varReportReady; `Refresh(Workers)`.
- Screen1.OnVisible herlaadt dan (alleen als niet dirty) en verhoogt varTeamDataVersion; Hours Summary herlaadt bij OnVisible. Inactieve medewerkers/Closed projecten worden nooit uit colWorkersCache/colProjectsCache gefilterd (Save week eist de medewerker in de cache; Hours Summary toont historie); verbergen gebeurt in de Items van keuzelijsten. Projecties van de bestaande caches blijven ongewijzigd tenzij par. 4.5/5.5 wordt goedgekeurd (dan in beide loaders identiek).

### 2.8 Vertaaltabel T en taal
- Benoemde formule `T` in App.Formulas: een record met per sleutel de tekst `Switch(varLang, "nl", "<nl>", "<en>")`; nu alleen "en" gevuld, "nl" volgt. varLang standaard "en" (later Language() en globe-icoon, keuze onthouden). Alle labels, knoppen, tegelteksten en meldingen van de nieuwe schermen gebruiken `T.<sleutel>` (sleutelschema `<scherm><Element>`); parameters via Substitute. SharePoint-keuzewaarden en interne namen worden niet vertaald. Tests (Test-Fonts, Test-GeaColors, Measure-FontFit) lezen de Engelse tekst; knopbreedtes meten op de langste taal zodra "nl" bestaat.
- "Language" op Workers is een attribuut van de medewerker (voor documenten), geen app-taal.

## 3. Contractors (scrEmployers) - bouw 1
- Velden (zoals Eddy ze gaf): Contractor Name (Title), Contractor Code (EmployerCode1, alleen-lezen; flow MS-019 vult EMP-<ID>; nieuw: tekst "assigned automatically"; de app schrijft hem nooit), Address, Postalcode, City, Country (tekst, niet verplicht, geen voorvulling), Contact Name, Contact Email (ContactEmail1, tekst), Contact Phone (tekst), Active. Interne namen: par. 1.
- Patch: alleen deze velden (Trim op tekst); nooit Contractor Code. Lijstsubtekst: Code | City | Inactive.
- Validatie: naam verplicht, Trim, max 255; e-mail leeg of `IsMatch(..., Match.Email)`; telefoon leeg of tekens `[0-9 +()-]`, 6-20; tekstvelden max 255.
- Duplicaat: BLOKKEREN op gelijke naam (Trim, hoofdletterongevoelig, eigen ID uitgezonderd): lokaal op colAdminEmployers (live) en autoritatief server `Filter(Employers, Title = varEmpSaveName)` incl. inactieve; of SharePoint `=` hoofdletterongevoelig is, in Studio testen (anders lokale Lower-vergelijking beslissend).
- Deactiveren met actieve medewerkers: voorstel, bevestigen: waarschuwing, niet blokkeren; telling uit een aparte Workers-load (colWorkersCache heeft geen Active).
- Naamwijziging werkt door in alle lookupweergaven, ook historie (identiteit via ID); in de UI-help vermelden.
- Build levert ook: AGENTS-regel groen Save voor beheerschermen + Test-GeaColors; Home-tegel Contractors actief; Test-AdminScreens.ps1 (par. 6).

## 4. Projects (scrProjects) - bouw 2
- Velden: Project Name (Title; weergavenaam in SharePoint "Title"), Project Number (intern ProjectName), Project Reference, Customer Name, ProjectHomeSite URL (tekstveld), Status (dropdown, SharePoint-waarden Active / On hold / Closed uit Choices, niet vertaald), Street, House Number, Postal Code, City, Country (keuzekolom, standaard Netherlands: keuzedropdown; op Contractors is Country tekst), Project Leader (ProjectLeader1) en Site Managers (SiteManagers), elk één persoon, alleen-lezen weergave van DisplayName. Interne namen: par. 1.
- Patch laat Project Leader en Site Managers weg (nooit wissen). Later people picker: `Choices(Projects.ProjectLeader)` via SharePoint, ComboBox-template eenmalig door Eddy in Studio toevoegen; Patch dan met claims-record; niet in v1.
- Validatie: Project Name en Project Number verplicht (Trim, max 255); Status verplicht en in de geladen keuzes; URL leeg of begint met `https://`.
- Duplicaat: BLOKKEREN op Project Number (server `Filter(Projects, 'Project Number' = varPrjSaveNumber)` (interne kolom ProjectName) + lokaal live). Geen duplicaatcontrole op Title. SharePoint dwingt uniek af (MS-022 Done) als vangnet; een afwijzing wordt als duplicaat gemeld.
- Status naar Closed: waarschuwing als het project open periodes heeft (een delegeerbare read `Filter('Assignment Periods', ProjectKey = varPrjSaveKey)` met 500-guard); periodes worden niet automatisch gesloten.
- Nummerwijziging breekt geen sleutels (ProjectKey/AssignmentKey gebruiken project-ID) maar wijzigt rapportkop en TEST-uitsluiting.
- 4.5 Voorstel, bevestigen (besluit 11): in deze build verbergt Screen1/ddProject Projects met Status Closed (On hold blijft zichtbaar); Hours Summary (ddReportProject) toont alles. Vergt Status in de colProjectsCache-projectie (beide loaders identiek; Test-SaveRegression). Admin-lijst "Show inactive" = Closed tonen.

## 5. Workers (scrWorkers) - bouw 3
- Velden: First Name (field_2), Surname (field_3), Worker Name (Title, alleen-lezen, flow MS-017), Worker Code (field_1, alleen-lezen, flow), Trade (dropdown Fitter / Welder / Unknown, default Unknown), Contractor (lookup Employer; dropdown met actieve contractors + de huidige van het item, inactief gemarkeerd; max 500 regels), Language (dropdown, expliciet voorvullen met Nederlands tot de SharePoint-standaard bevestigd is; waarden uit Choices), Active.
- Patch: `{'First Name': fn, Surname: sn, Title: fn & " " & sn, Trade: {Value}, Employer: {Id, Value}, Language: {Value}, Active}` met fn/sn getrimd; nooit Worker Code. Contractorwissel: info "old hours keep the old contractor". Geen telefoon/e-mail (Worker Contacts/MS-012 buiten v1; later alleen met toegang).
- Validatie: First Name en Surname verplicht (max 255, niet alleen cijfers); Trade, Contractor (aanwezig in de geladen lijst; nieuwe toewijzing alleen aan actieve contractor), Language verplicht.
- Duplicaat: WAARSCHUWEN, opslaan alleen met aangevinkt bevestigingsvinkje: server `Filter(Workers, 'First Name' = varWrkSaveFirst && Surname = varWrkSaveSurname)`, daarna lokaal op `Employer.Id` (lookup-ID niet filterbaar) en ID <> eigen.
- Deactiveren (Active uit) met een open inzetperiode: BLOKKEREN. De melding noemt het/de project(en) en zegt "Uncheck in Project / team first". Detectie: zie par. 8 punt 2 (Project Workers `Active = true`, eenmalige read, fail-closed bij >= 500).
- 5.5 Voorstel, bevestigen (besluit 11): Screen1-kandidaten verbergen inactieve medewerkers (Active toevoegen aan de colWorkersCache-projectie in beide loaders identiek); Weekly Hours-rijen volgen nog periodes of opgeslagen uren; Hours Summary toont alles. Admin "Show inactive" standaard uit.
- 5.6 Weekly Hours stale cache (reviewer-blokkade, in deze build oplossen): `btnTileWeeklyHours.OnSelect` (scrHome) en de Weekly Hours-knop van Screen1 krijgen dezelfde extra voorwaarde `Coalesce(varMastersReady,false) && Coalesce(varWorkersCacheReady,false)`; ongeldig = `Navigate(Screen1)` (OnVisible herlaadt). Alleen varWorkersCacheReady is onvoldoende (Hours Summary vult colWorkersCache zonder varTeamDataVersion te verhogen). Save week blijft ongewijzigd; controleer bij de bouw ook andere routes naar scrHours. Reviewer verplicht.

## 6. Tests (verifier)
- Nieuw artifacts/Test-AdminScreens.ps1 per scherm: (1) Save-guard in DisplayMode tekstueel gelijk aan de eerste OnSelect-voorwaarde, idem Home/New/Refresh/gallery; (2) loaders zonder Patch/Update/Remove/Collect naar een SharePoint-bron; (3) nergens Remove/RemoveIf op de drie lijsten; (4) elke ClearCollect uit een bron gevolgd door `>=500`-guard; (5) predicaten alleen kolommen + globale vars, `=`/StartsWith, geen Search(); (6) geen Choices() binnen ForAll; (7) Patch-vorm: Trade/Language/Status als `{Value:`, Employer `{Id, Value}`, Workers-Patch zonder Worker Code, Contractors-Patch zonder Contractor Code, Title = getrimde fn & " " & sn; (8) een Patch per Save, daarna verify-read, colAdmin* alleen na verify; (9) cache-invalidatie incl. Refresh; (10) traces zonder namen/FirstError.Message; (11) alle zichtbare teksten via `T.`; (12) kale `ProjectName` ontbreekt.
- Bijwerken per scherm: Test-Fonts, Test-GeaColors (tegelset, rollen, groene Save, dropdowns), Test-FooterRow -GeometryOnly (nieuwe configs, ~808 px), Test-Logo (imgLogo*), Check-WeeklySource, artifacts/preserved-screens.sha256.json en schermlijsten in de checks bij wijzigingen aan scrHome of Screen1. Bestaande set blijft groen. Pack aan het eind.
- Studio (TESTPLAN.md, TP-ADM-EMP/PRJ/WRK-01, alleen TEST-records): laden, zoeken, nieuw/bewerken, duplicaatblokkade/-waarschuwing, conflict (item in SharePoint wijzigen tijdens bewerken), navigatieguards, cache-invalidatie (Screen1, Weekly Hours, Hours Summary tonen nieuwe waarden), Monitor (delegatie, aantal calls), deactivatieblokkade, Closed/inactief-filter.

## 7. Risico's
1. Metadata-refresh kan Title-namen in bestaande formules herschrijven (fase 0 vangt dit).
2. Flows MS-017/MS-019 wijzigen items na de verify; daarom veldvergelijking i.p.v. Modified; Contractor Code/Worker Code verschijnen pas na Refresh.
3. Lookup-ID (Employer) niet filterbaar: duplicaat- en contractortellingen lokaal, afhankelijk van volledige load (500-guard).
4. Patch is geen transactie: Patch kan slagen en verify mislukken (Failed, geen auto-herstel).
5. Beheerschermen schrijven echte lijstitems; testen alleen op TEST-records; rename van contractor/project werkt door in historische weergave.
6. Wijziging van goedgekeurde schermen (Screen1 filters, Home-tegel/Weekly Hours-voorwaarde, cacheprojecties): raakt Test-SaveRegression en vergt Studio-hertest.
7. Rechten: zolang MS-021 uitgesteld is, kan iedere appgebruiker met lijstrechten wijzigen; pas in productie sluiten.

## 8. Open punten
1. Interne namen/typen staan in par. 1; open: Workers.Language-standaard ("English" in metadata, par. 1 punt d), controle van de waarden uit de oude Email-kolom, en de Status-/Language-waarden uit Choices.
2. Detectie open periode per medewerker (voor de deactiveringsblokkade): Assignment Periods is alleen op ProjectKey filterbaar. Voorstel, bevestigen: eenmalige read `Filter('Project Workers', Active = true)` (Active = open periode), lokaal op Worker.Id; dit wijkt af van de AGENTS-regel "Project Workers uitsluitend op ProjectKey" en vergt een Studio-delegatietest; bij >= 500 rijen of leesfout wordt deactiveren geblokkeerd.
3. Besluit 11 timing (Closed in Projects-build, inactief in Workers-build) en het Status/Active-veld in de cacheprojecties: bevestigen.
4. Contractor deactiveren met actieve medewerkers: waarschuwing (voorstel) of blokkeren.
5. Of SharePoint-`=` hoofdletterongevoelig vergelijkt (duplicaatnaam): Studio-test.
6. Worker Contacts (telefoon) buiten v1; volgorde-keuze New/Refresh in de footer is vastgelegd als New, Refresh, Discard changes, Save.
7. MS-021 (rechten) bij go-live; bij leden toevoegen "Send an email invitation" uitvinken.
