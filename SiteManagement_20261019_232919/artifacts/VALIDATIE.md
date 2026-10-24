**Actuele layouttest:** alle drie schermen hebben nu een gezamenlijke vaste onderste knoppenrij. Controleer bij breed/smal venster: navigatie links, acties rechts, gelijke Y/40px, 12px tussenruimte, geen tweede rij, horizontaal scrollen als nodig en inhoud/totaal boven de balk. Controleer dat de balk blijft staan als de inhoud scrollt. App checker en native scrollbar nog online testen. Eerdere instructies met acties bij inhoud zijn achterhaald.

**Actueel na Save-regressie:** volg eerst [SAVE_INCIDENT_EN_TEST.md](SAVE_INCIDENT_EN_TEST.md). De geneste caches zijn teruggenomen; eerdere cacheverwachtingen hieronder zijn historisch. Controleer eerst incidentrecords rond 21:15 en voer geen ingeschakelde Save uit voor alleen-lezen tests.

# Hours Summary in Studio valideren

Gebruik uitsluitend de nieuwste testbuild: C:\Users\vandergoot.ed\Dev\Sitemanagment\SiteManagement_20261019_232919\artifacts\footer-row-20261020_215936\SiteManagement_OneFooterRow_20261020_215936.msapp

1. Importeer als aparte testapp via make.powerapps.com > Apps > Import app > From file (.msapp). Open Studio en laat YAML verwerken. Controleer App checker: geen formule- of schemafouten op scrWeeklyHours, vooral btnRefreshReport.OnSelect, btnBuildReport.OnSelect en de geneste weekgallery. Bewaar datarijlimiet 500 en formulefoutafhandeling.
2. Kies een project en daarna Alle contractors en iedere contractor afzonderlijk. Vergelijk met bekende Hours-regels: gelijke begin-/eindweek, meerdere weken en een jaargrens met week 53. Jaren/weken mogen alleen uit dit project komen. Controleer namen, projectnummer/reference, gehele uren zonder decimaalteken en gezamenlijk verschuiven via < en >.
3. Controleer een actieve medewerker zonder uren, een inactieve medewerker met historische uren en een werkgeverswisseling. Oude uren moeten onder de opgeslagen werkgever blijven staan. Test ook een project zonder enige uren: actieve medewerkers blijven op 0 zichtbaar, periodekeuzes zijn leeg/uitgeschakeld.
4. Gebruik Monitor bij meer dan 500 Hours-regels, met een relevante regel buiten de eerste 500. Requests moeten op de server filteren op projectlookup-ID, assignment-ID en datumgrenzen en sorteren op Work Date. Een gefilterde batch van 500 of een mislukte aanvraag moet een foutmelding geven en rijen, weekkolommen en eindtotaal verbergen. Verlaag de datarijlimiet niet: dan correspondeert de afkapbeveiliging niet meer met de appinstelling.
5. Controleer navigatie, project/teamselectie en automatisch herladen van jaar/KW in scrHours. Vervang/publiceer productie niet. Opslaan in de testapp gebruikt de behouden verbindingen en schrijft naar de bestaande SharePoint-lijsten.

Geef bij fouten de control/eigenschap, exacte App Checker-melding en gekozen project-/periode-/contractorwaarden terug. De bron wordt rechtstreeks hersteld; handmatig eigenschappen aanpassen is niet nodig.

## Herleidbare rekenvoorbeelden

Lokale synthetische regels: medewerker 1 heeft 8 uur op 28-12-2020 en 7,5 uur op 03-01-2021 onder werkgever 10; 6 uur op 04-01-2021 onder werkgever 20. Medewerker 2 heeft 4 uur op 05-01-2021 onder werkgever 10.

- Alleen 2020-KW53: 15,5 uur, werkgever 10.
- 2020-KW53 t/m 2021-KW01: 25,5 totaal; werkgever 10: 19,5; werkgever 20: 6.
- Verwachte rapportgroepen: medewerker 1/werkgever 10: 15,5; medewerker 1/werkgever 20: 6; medewerker 2/werkgever 10: 4. Een actieve medewerker zonder regels hoort aanvullend als 0-rij te verschijnen.

Deze fixtures zijn niet in SharePoint aangemaakt. Lokaal zijn periode-/contractorfilters en sommen getest, niet de volledige Canvas-rapportopbouw of serverdelegatie.

PA2108-correctie: controleer bij import eerst dat AccessibleLabel op de twee weekknoppen geen fout meer veroorzaakt. Deze import is lokaal niet uitgevoerd.

Naamgeving: controleer Weekly Hours op scrHours (Mon-Sun-invoer), Hours Summary op scrWeeklyHours (opgeslagen uren), de toelichting en de nieuwe navigatie vanaf Screen1 en terug via Project / team. Controleer dat de nieuwe titels en knoppen niet overlappen. Export is nog niet gebouwd.

Knopopmaak: controleer zes zichtbare tekstknoppen op hoogte 40, Segoe UI 14 Semibold, centrering, padding, hoekradius en 12 px rijafstand. Controleer volledige teksten, ook Saving..., plus kleuren, acties en disabled-toestanden. Verborgen techniek- en compacte pijlknoppen zijn bewust ongewijzigd.

Vaste navigatie: scroll de galleries op alle drie schermen; de onderbalk moet zichtbaar blijven en de laatste rijen/totaal mogen er niet achter vallen. Alleen de schermtitel staat in de blauwe balk. Test 768x600, 1024x768, 1280x720, 1366x768 en 1920x1080 visueel. Controleer Refresh bij de rapportselecties, Save bij jaar/KW, Save team bij de selectie en de bestaande navigatievalidaties. De nieuwe terugknop bij Weekly Hours moet blokkeren tijdens opslaan en met onopgeslagen wijzigingen.

Bestaande gegevens: voer eerst artifacts/GEGEVENSBRONNEN_EN_TEST.md uit. Kies bekende project-/team-/ISO-jaar-/KW-waarden en controleer automatisch teruggelezen koppelingen/daguren zonder Save team of Save te klikken. Herhaal na sluiten/starten. Lege caches/selecties zijn geen gewiste SharePoint-data; meld exacte fouten in plaats van records opnieuw in te voeren.

Compacte selectievelden: controleer op breed scherm twee rijen (Project/Contractor/Refresh, daarna vier ISO Year/KW-velden). Breedtes blijven 512/256 px, labels staan erboven op dezelfde X, groepen hebben 12 px ruimte. Verklein het venster: groepen lopen om en blijven via het selectieblok bereikbaar; onder 608 px zo nodig horizontaal scrollen. Controleer AutoLayout-scroll, focus, behouden selecties en Refresh/Reset. De onderste navigatie en het rapporttotaal blijven vrij. Onder 768 px is de bestaande rapporttabel geen volledige telefoonlayout.


## Performance-testbuild

Voer eerst de vijf scenario's en Monitor-controle uit in [PERFORMANCE_EN_INDEXEN.md](PERFORMANCE_EN_INDEXEN.md). Let op nested cachebinding, Refresh, historische totalen en indexinventaris. De eerdere verwijzingen naar exact ongewijzigde Save-formules gelden voor oudere builds: nu is uitsluitend cache-invalidering voor de verder exact behouden opslagkern toegevoegd.


Kleurbuild: controleer op alle drie schermen blauwe schermnavigatie, paarse acties, witte tekst en grijze disabled-toestand. Controleer hover en ingedrukte toestand. Afmetingen, plaatsing en Save-beveiliging moeten gelijk blijven. De incident-/laadtests blijven open.
