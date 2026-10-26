# Risicoanalyse (Site Management)

Aanvulling op SECURITY.md. Niet lezen tenzij de opdracht erom vraagt. Alles hieronder is voorstel van Eddy/Claude totdat Eddy het bevestigt; kansen (laag/middel/hoog) zijn niet geverifieerd. Alleen feiten uit de projectdocumenten; waar die ontbreken staat "te bevestigen".

## a. Gegevens nu

| Categorie | Doel | Gebruikers | Impact bij lek en reden |
|---|---|---|---|
| Namen van medewerkers (Workers: First Name, Surname) | Selecteren en koppelen aan project/team, urenrapport | Gebruikers van de app (kring te bevestigen) | Middel: persoonsgegevens; naam plus werkgever plus project laat zien wie waar werkt |
| Telefoon (nu in Workers; verhuist naar Worker Contacts, MS-012) | Geen gebruik in de huidige schermen | Iedereen met leestoegang tot Workers (nu) | Middel: direct contactgegeven; daarom dataminimalisatie (DECISIONS.md D7). E-mail wordt niet opgeslagen; bestaande Workers.Email: te controleren |
| Werkgever / contractor (Employers: naam, Employer Code) | Rapportage per werkgever, historie op Hours | Gebruikers van de app | Laag-middel: bedrijfsgegevens, geen persoonsgegevens |
| Trade (Fitter/Welder/Unknown) | Weergave en documenten | Gebruikers van de app | Laag: functieaanduiding |
| Uren per medewerker per dag (Hours, nu incl. naam in Hours.Title) | Urenregistratie, rapportage, export | Gebruikers van de app | Middel: persoonsgebonden arbeidstijd; aanvullend gevoelig doordat gegevens financieel (facturatie) gebruikt kunnen worden |
| Projectnamen, projectnummers, project reference (Projects) | Selectie, rapport, export | Gebruikers van de app | Middel-hoog: klantvertrouwelijkheid; een lek toont klanten en lopende opdrachten (hoofdrisico volgens Eddy) |
| Exportbestanden (CSV, later PDF; nog niet gebouwd) | Administratie, facturatie | Wie de downloadlink krijgt | Middel-hoog: bundelt namen, uren, werkgever en project in een los bestand dat buiten SharePoint kan worden doorgestuurd |

## b. Gegevens later (nog niet gebouwd)

| Categorie | Doel | Gebruikers | Impact bij lek en reden |
|---|---|---|---|
| Toestemmingsdocumenten (consent agreements) | Per medewerker, in de eigen taal | Te bevestigen (supervisors, administratie) | Hoog: ondertekende documenten per persoon; mogelijk meer persoonsgegevens dan nu |
| Foto's en bijlagen per WorkPackage | Voortgang, jobcards | Te bevestigen | Middel-hoog: kunnen personen, locaties of klantinstallaties tonen |
| P&ID- en 3D-bestanden | Planning, installatiegegevens (pidtracker) | Te bevestigen | Hoog: klantvertrouwelijke technische documentatie |
| Voorraadlocaties (inventory) | Materiaal op locatie | Te bevestigen | Laag-middel: afhankelijk van wat vastgelegd wordt; te bevestigen |

## c. Lekroutes (kans = voorstel, niet geverifieerd) en maatregelen

| Route | Kans | Maatregelen |
|---|---|---|
| Te brede rechten op de SharePoint-site of lijsten | middel | Least privilege, unieke rechten op Worker Contacts (MS-012), kwartaalreview van toegang, groep Site Supervisors (SECURITY.md dreiging 1) |
| Export of downloadlink wordt doorgestuurd | middel | Export alleen via de generieke flow, geen automatische e-mail, Exports-bibliotheek met beperkte rechten, label Confidential (MS-011, gepland), DLP via IT (dreiging 4) |
| Gekaapt account | laag-middel | MFA via Entra (aanname), least privilege, audit log via IT, incidentplan (dreiging 5) |
| Persoonsgegevens in bijproducten: Workers.Phone/Email in clientgeheugen en versiegeschiedenis, Hours.Title, de git-repo en lokale diagnosebestanden | middel | Zie R2 t/m R4 en R7 hieronder; dataminimalisatie (D7) |
| Verlies of overschrijven van gegevens (geen lek, wel impact op betrouwbaarheid) | laag-middel | Fail-closed Save, versiegeschiedenis, recycle bin, backup (dreiging 2 en 6) |
| Eén beheerder | middel | Tweede eigenaar benoemen (dreiging 6) |

## d. Conclusie (Eddy)

- Risico nu: beperkt-middel.
- Hoofdrisico's: klantvertrouwelijkheid van projectnamen/-referenties en exportbestanden.
- De beslissing over een DPIA ligt bij de GEA privacy officer.
- Opnieuw beoordelen voordat documenten, foto's, CAD (P&ID/3D) of inventory live gaan.

## Risicoregister

| ID | Risico | Gerelateerd besluit/MS | Maatregel | Status |
|---|---|---|---|---|
| R1 | Telefoon (en mogelijk e-mail, als Workers.Email data bevat) staat in Workers, zichtbaar voor iedereen met leestoegang | DECISIONS.md D7, MS-012 | Aparte lijst Worker Contacts (alleen WorkerID + Phone) met unieke rechten (eigenaren Full control, Site Supervisors Edit); kolom Phone uit Workers verwijderen; Workers.Email controleren en zo nodig legen/verwijderen | gepland |
| R2 | De versiegeschiedenis van Workers bevat nog telefoonnummers | MS-012 | Opschonen na MS-012 (beslissing Eddy) | open |
| R3 | De app laadt mogelijk volledige Workers-rijen incl. kolommen Phone/Email (indien gevuld) in het clientgeheugen (de app gebruikt ze niet) | MS-012 | Controleren in Studio Monitor; kolom verwijderen/verplaatsen | open |
| R4 | Hours.Title dupliceert naam + datum (persoonsgegevens) | DECISIONS.md D7 | Title = EntryKey voor nieuwe/bijgewerkte rijen, bij de volgende Save-taak; bestaande rijen: open beslissing | gepland |
| R5 | E-mail zonder concreet gebruik | MS-012 | E-mail wordt niet opgeslagen (Eddy 26-10-2026); bestaande Workers.Email: zie R1/MS-012 | besloten: e-mail wordt niet opgeslagen |
| R6 | Overige dreigingen (verkeerde toegang, verwijderen/overschrijven, dubbele records/bugs, export gelekt, gekaapt account, enige eigenaar) | SECURITY.md, dreigingen 1-6 | Zie SECURITY.md; hier niet gedupliceerd | verwijzing |
| R7 | De git-geschiedenis bevat de echte naam van een medewerker (worker A; 2 commits, geen tagberichten) en een lokaal, git-genegeerd diagnosebestand bevat dezelfde naam | AGENTS.md (geen persoonsgegevens in de repo) | Werkboom is opgeschoond (26-10-2026). Geschiedenis niet herschreven; repo is privé. Opschonen vereist een herschrijving van de geschiedenis met force-push en nieuwe tags (beslissing Eddy). Lokaal diagnosebestand zelf verwijderen of laten staan (Eddy) | open |
