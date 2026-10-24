We bouwen een bestaande Power Apps canvas-app voor site management. Lees eerst de lokale bronbestanden. Bouw verder op de bestaande app en behoud de werkwijze van onze Excel/VBA-versie.

Sla onderstaande projectafspraken op in AGENTS.md. Vul technische bevindingen aan nadat je de bestanden hebt onderzocht.

## Project en ontwikkelomgeving

Projectmap:
C:\Users\vandergoot.ed\OneDrive - GEA\Projects\Development\Sitemanagment

Huidige uitgepakte bronmap:
SiteManagement_20261019_232919

Platform:
- Power Apps canvas-app voor gebruik in de browser.
- SharePoint voor gegevens.
- Power Automate voor serververwerking en export.
- VS Code met Power Platform Tools en Codex.
- Power Platform CLI 2.11.2; gebruik de layout SourceCode, niet Experimental.

De ongewijzigde app is succesvol uitgepakt, opnieuw ingepakt en getest in Power Apps Studio. De route voor lokaal bewerken werkt.

## Bestaande app

De oorspronkelijke app heeft drie schermen:
- Screen1: medewerkers selecteren en koppelen aan project en team.
- scrHours: zichtbare naam Weekly Hours; uren invoeren in een weektabel, Mon t/m Sun.
- scrWeeklyHours: zichtbare naam Hours Summary; administratieve samenvatting van opgeslagen uren per week en medewerker/werkgever, met periodetotaal. Behoud voorlopig deze interne schermnaam en verwijzingen.

Bestaande gegevensbronnen:
Projects, Employers, Workers, 'Project Workers', Hours en een beginnende Power Automate-flow.

Controleer de werkelijke kolomnamen en typen in de lokale metadata en formules. Verzin geen SharePoint-kolommen of flowparameters.

## Functionele afspraken

1. Workers is één centrale medewerkerslijst. Employers is één centrale werkgeverslijst.
2. Projects is de centrale projectenlijst.
3. Project Workers koppelt een bestaande medewerker aan een project en team. Medewerkers worden niet telkens opnieuw ingevoerd.
4. Een medewerker kan in dezelfde week op meerdere projecten werken.
5. Actieve projectleden blijven zichtbaar in de ureninvoer, ook bij 0 uur of ziekte.
6. Gebruik geen verplichte inzetperiode. Planning komt later vanuit WorkPackages.
7. Team is een keuzelijst, voorlopig 1 t/m 10.
8. Trade: F betekent Fitter, W betekent Welder. Documenten moeten de volledige functienaam kunnen gebruiken.
9. Voor weergave en documenten wordt de volledige naam samengesteld uit voornaam en achternaam.

## Uren en rapportage

- Ureninvoer blijft een tabel per werkweek met Mon t/m Sun en een weektotaal.
- Wijzigen van invoerjaar of KW laadt automatisch de juiste week. Voeg geen onnodige Load-knop toe.
- Rapportage heeft Start ISO Year, Start KW, End ISO Year en End KW.
- Gelijke begin- en eindwaarden betekenen één week.
- Een periode mag meerdere jaren omvatten.
- ISO-jaren moeten correct werken rond de jaarwisseling en bij week 53.
- Jaar- en weekkeuzes komen uit beschikbare urenregistraties.
- Het rapport toont één kolom per week en een periodetotaal per medewerker.
- Projectnummer en project reference horen in rapport en export.
- Hele uren mogen geen losse komma of punt achter het getal krijgen.
- Uren en weekkoppen worden gecentreerd binnen het urenoverzicht.

Export wordt gescheiden per project-ID en contractor/employer-ID. Eén medewerker kan daardoor in meerdere exports voorkomen. Medewerkers met periodetotaal 0 worden uitgesloten van de export; zij blijven wel beschikbaar in de ureninvoer.

Exportafspraak voor een volgende opdracht: Hours Summary levert eenvoudige .xlsx-bestanden, apart per project en werkgever, zonder medewerkers met periodetotaal 0. Bovenaan staan projectnummer, project reference, werkgever en rapportageperiode; de tabel bevat naam, weektotalen en periodetotaal. Bestanden moeten downloadbaar en op te slaan zijn. Geen automatische e-mailverzending. Bouw export pas na naamgeving en validatie van Hours Summary.

## Gegevens en sleutels

- Nieuwe testbuilds gebruiken dezelfde bestaande SharePoint-site en lijst-ID's als de oorspronkelijke app: https://geacloud.sharepoint.com/sites/GEASiteManagment. Wijzig of vervang deze verbindingen niet voor een testbuild.
- SharePoint bevat de blijvende medewerkers, projecten, werkgevers, projectkoppelingen en uren. Collections zijn tijdelijke schermcaches en schermselecties zijn sessiestaat; een lege collection of een lege/andere selectie betekent niet dat opgeslagen gegevens weg zijn.
- Laad bij openen en relevante selectiewijzigingen uit SharePoint wanneer geen volledig gevalideerde cache voor dezelfde selectie en geldigheidsversie bestaat. Hergebruik geldige sessiecaches; expliciete Refresh haalt wijzigingen van andere gebruikers op. Gebruik echte project-/assignmentlookup-ID's voor teruglezen; lees uren per koppeling en werkdatum, met behoud van bestaande EntryKey. Schrijf of repareer sleutels nooit automatisch tijdens laden.
- Laadacties mogen geen Patch, Update, Remove, vervangende lijsten of testdata aanmaken. Bestaande expliciete Save-/Save team-acties blijven de enige opslagroute. Bij onvolledige/afwijkende sleutels: gegevens laten controleren en opslaan blokkeren in plaats van nieuwe records aanmaken.
- Toon onderscheid tussen ontbrekende selecties, een lege geldige selectie en een verbindings-/laadfout. Maak fouten zichtbaar en blokkeer opslaan na een mislukte of onvolledige laadactie.
- Een aparte testapp met dezelfde lijsten schrijft bij expliciet opslaan naar dezelfde bestaande gegevens. Vergelijk verpakte site/lijst-ID's met de oorspronkelijke app; daadwerkelijke connectorauthenticatie en gebruikersrechten vereisen een Studio-/browsertest.

In de onderzochte app:
- Project Workers heeft Project, Worker, Team, Active, AssignmentKey en ProjectKey.
- AssignmentKey is project-ID | worker-ID.
- Hours heeft 'Work Date', Assignment, Employer, Team, Trade, Hours en EntryKey.
- EntryKey bestaat uit AssignmentKey | datum in yyyymmdd.
- Hours heeft momenteel geen aparte ISO Year- en KW-kolommen; deze worden uit Work Date afgeleid.
- Bewaar historische werkgevergegevens op de urenregistratie. Een latere werkgeverswijziging mag oude uren niet naar een andere contractor verplaatsen.
- De zakelijke Employer Code, zoals EMP-001, is uniek. Maak geen tweede handmatig ingevoerde werkgeversidentificatie. SharePoint heeft daarnaast zijn interne numerieke ID voor lookups.
- Historische projectkoppelingen worden inactief gezet en niet zomaar verwijderd.

## Werkwijze voor wijzigingen

- Pas bestanden rechtstreeks aan; laat mij niet telkens losse eigenschappen invoeren.
- Behoud bestaande werkende schermen, verbindingen en functionaliteit.
- Gebruik uitsluitend geldige Power Apps Source Code-schema’s, controlversies en eigenschappen.
- Controleer actuele Microsoft-documentatie bij twijfel.
- Los delegatieproblemen op; verberg waarschuwingen niet als daardoor gegevens ontbreken.
- Maak checkpoints of backups buiten Src. PAC weigert backupbestanden in Src die niet op .pa.yaml eindigen.
- Pack met: pac canvas pack --sources "." --layout SourceCode --msapp "<apart testbestand>.msapp"
- Importeer een testbestand via make.powerapps.com → Apps → Import app → From file (.msapp).
- Een geslaagde pack is geen bewijs dat Power Fx correct is. Studio/App checker en een functionele test zijn nodig.
- Overschrijf of publiceer de bestaande productieapp niet automatisch.
- Claim geen uitgevoerde tests die je niet daadwerkelijk kunt uitvoeren.
- Communiceer in het Nederlands en houd handmatige stappen kort en concreet.

## Latere onderdelen

Na urenrapportage en export bouwen we:
- Beheerschermen voor medewerkers, werkgevers, projecten en projectkoppelingen, zodat gebruikers niet rechtstreeks SharePoint-lijsten hoeven te bewerken.
- WorkPackages, planning en jobcards.
- Foto’s en bijlagen per WorkPackage.
- Documentgeneratie en consent agreements in de taal van de medewerker.

Deze onderdelen zijn nog geen voltooide functies.

## Voortgang en oplevering

- Blijvende projectafspraken staan in AGENTS.md. Tijdelijke bevindingen, uitgevoerde controles, beperkingen, Studio-controles en het actuele buildpad staan in PROJECT_STATUS.md in deze bronmap.
- Werk PROJECT_STATUS.md aan het einde van iedere opdracht bij. Maak onderscheid tussen geïmplementeerd, technisch gecontroleerd en functioneel getest.
- Rond eerst Hours Summary (administratieve rapportage) af en valideer dit overzicht. Weekly Hours blijft de bestaande ureninvoer op scrHours. Export is een afzonderlijke volgende opdracht.
- Behoud Screen1, scrHours, bestaande SharePoint-verbindingen en werkende ureninvoer. Wijzig andere onderdelen alleen indien noodzakelijk en licht dit toe.
- Zet de status van acceptatiecriteria die Studio vereisen nooit op geslaagd op basis van pack, syntaxiscontrole of lokale referentietests.

## Technische randvoorwaarden

- Classic/Button@2.2.0 ondersteunt AccessibleLabel niet in SourceCode (Studio-importfout PA2108). Voeg deze eigenschap niet toe aan dit controltype; behoud haar bij andere controltypen die haar ondersteunen. Een algemene lijst van basiseigenschappen is geen bewijs van ondersteuning per controlversie.

- Het .msapr-bestand is een ZIP-container met oorspronkelijke metadata, verbindingen en controltemplates. De daarin opgeslagen App Checker-resultaten zijn historisch en valideren gewijzigde YAML niet.
- Gebruik de werkelijke lookup-ID's voor project-, medewerker- en werkgeveridentiteit. Bewaar werkgeveridentiteit van Hours voor historische rapportregels.
- De huidige rapportbeveiliging is gebaseerd op de in de appmetadata bevestigde datarijlimiet 500 en ingeschakelde formulefoutafhandeling. Verlaag de rijlimiet niet zonder tegelijk de afkapcontroles te herzien. Alleen de limiet verhogen bewijst geen volledigheid.
- Een bereikt maximum van een opgehaalde batch moet het gehele rapport blokkeren; toon geen gedeeltelijke totalen. Houd ook rekening met de maximale 500 keuzeregels van een klassieke dropdown.
- Gebruik gedelegeerde filters op brongegevens en voer groepsberekeningen pas uit op expliciet geladen lokale gegevens. Verifieer de werkelijke serverqueries in Studio/Monitor.
- IfError rond een reeks acties met puntkomma's is geen garantie dat na een eerdere fout wordt gestopt. Controleer afzonderlijke risicovolle stappen en geef een rapport pas vrij als er geen fouten zijn.
- De gekoppelde flow heeft lokaal nog geen invoer-/uitvoercontract of bewerkbare definitie. Verzin geen flowparameters; export is nog niet geïmplementeerd.

## Standaard voor zichtbare actie- en navigatieknoppen

- Height 40; Font Segoe UI; Size 14; FontWeight Semibold.
- Horizontaal Align.Center en verticaal VerticalAlign.Middle, uitsluitend waar het controltype dit ondersteunt.
- PaddingTop/Bottom 0; PaddingLeft/Right 16; alle ondersteunde hoekradii 8.
- Naast elkaar geplaatste knoppen hebben dezelfde Y-positie en 12 px tussenruimte. Breedte mag verschillen, maar moet voldoende ruimte voor de volledige tekst laten.
- Behoud bestaande teksten, OnSelect, Visible en DisplayMode; kleuren volgen de appbrede kleurafspraak. Pas breedte, positie en zo nodig containers aan zonder overlap of afsnijden.
- Verborgen technische knoppen zijn uitgezonderd. Zichtbare compacte pijlknoppen volgen ook de gedeelde rijhoogte van 40 px. Voeg geen AccessibleLabel toe aan Classic/Button@2.2.0.
- Controleer tekstpassing en layout na import in Studio; pack en lokale eigenschapscontrole bewijzen de browserweergave niet.

## Plaatsing van titel, navigatie en acties

- De blauwe titelbalk bevat uitsluitend de schermtitel; plaats er geen navigatie- of actieknoppen in.
- Alle zichtbare navigatie-, terug- en actieknoppen staan per scherm in een enkele vaste onderste knoppenbalk, buiten scrollende galleries of inhoudcontainers. Veranker de balk aan de onderkant van het scherm, zodat inhoudscrollen de balk niet verplaatst.
- Reserveer ruimte boven de balk voor tabellen, invoervelden, acties en totalen. Gebruik de balkpositie als ondergrens van de inhoud; laat niets achter de balk verdwijnen.
- Navigatie staat links en acties zoals Refresh, Save, weekschuiven en een toekomstige Export staan rechts binnen dezelfde onderste balk. Geen tweede actierij bij de inhoud; de titelbalk bevat uitsluitend de titel.
- De afgesproken knopstandaard blijft gelden: hoogte 40, Segoe UI 14 Semibold, gecentreerd, ondersteunde radii 8 en 12 px tussenruimte tussen naast elkaar geplaatste knoppen.
- Behoud bestaande acties, validaties, Visible en DisplayMode bij verplaatsing. Let bij een gewijzigde parent op Parent-/Self-verwijzingen. Een nieuwe terugknop bij ureninvoer mag niet tijdens opslaan of met onopgeslagen wijzigingen navigeren.
- Controleer layoutformules op meerdere schermformaten en voer daarna Studio-/browsercontroles uit voor tekstpassing, overlap en daadwerkelijk scrollgedrag. Lokale rechthoekcontroles zijn geen visuele test.

## Hours Summary: compacte selectievelden

- Gebruik één gedeelde visuele veldbreedte: lblSummaryFieldWidth.Width = 256 px. ISO Year- en KW-velden hebben exact die breedte; Project en Contractor exact tweemaal die breedte. Dit is opmaak, geen teken- of invoerlimiet.
- Rek de velden niet uit met de schermbreedte. Gebruik een linkermarge van 40 px, 12 px horizontale/verticale ruimte tussen groepen en een label direct boven ieder veld op dezelfde X-positie (4 px label/veldafstand).
- Volgorde: Project, Contractor; daarna Start ISO Year, Start KW, End ISO Year, End KW. Actieknoppen staan in de vaste onderste balk. Laat groepen op smallere schermen doorlopen naar volgende rijen met behoud van de breedtes en linkermarge.
- Houd de onderste navigatie vast. Gebruik zo nodig een afzonderlijk scrollbaar selectieblok om alle omgelopen velden bereikbaar te houden zonder tabel/totaal of titelbalk te overlappen. Bij vensters smaller dan een 512-px-veld plus marges is horizontaal scrollen de uitwijkmogelijkheid; krimp de breedteverhouding niet.
- Gebruik gewone layoutcontainers zodat bestaande Reset-/Select-acties hun controls behouden; wijzig bij een layoutopdracht geen Items, Default, OnChange, filters, acties of gegevens.
- De standaard betreft de selectievelden; een volledige telefoonlayout voor de bestaande rapporttabel is een afzonderlijke wijziging. Controleer AutoLayout-overflow en behouden selectiegedrag in Studio/browser.

## Vaste architectuur, laden en opslagveiligheid

- Power Apps canvas + de bestaande SharePoint-lijsten blijven de vaste basis. Stel geen migratie naar Dataverse, SQL of een ander opslagplatform voor. Power Automate uitsluitend voor aantoonbaar noodzakelijke serververwerking/paginering; een flow is niet automatisch sneller.
- Na de Save-regressie van 20 oktober 2026 zijn de geneste week-/projectcaches en epochguards teruggenomen. De actieve bron gebruikt directe lookup-ID-/datumloaders, tijdelijke stagingcollections en lokale rapportberekening. Breng cacheoptimalisaties pas terug na afzonderlijke Studio-binding-, fout- en functionele tests. Eerdere performanceverslagen zijn historisch.
- Gebruik expliciete laadstatussen NotLoaded, Loading, Failed, Loaded. Alleen volledig en foutloos Loaded mag opslaan. Bewaar de geladen project-/team-ID's, ISO-jaar/KW, weekmaandag, rijaantallen en oorspronkelijke snapshot afzonderlijk van de huidige selectiecontrols.
- Iedere Save heeft exact dezelfde volledige toelatingscontrole in DisplayMode en als eerste OnSelect-voorwaarde. Bij mismatch, ontbrekende oorspronkelijke rijen, laadfout, lopende load/opslag of afwijkende sleutels geen bronmutatie uitvoeren. DisplayMode alleen is nooit een veiligheidsgrens.
- Een lege of onvolledige collection is geen opdracht tot deactiveren/verwijderen of uren wissen. Save team met geheel lege selectie is geblokkeerd. Deactivering vereist expliciete checkbox-verwijdering van een oorspronkelijk geladen medewerker; andere ontbrekende selectiegegevens blokkeren Save.
- Laad eerst naar tijdelijke collections. Vervang zichtbare selectie/invoer en oorspronkelijke uren pas na een volledige geslaagde load. Bij fout oude gegevens behouden als alleen-lezen, huidige selectie niet als geladen markeren en fout zichtbaar tonen. Onopgeslagen invoer/selectie blokkeert Refresh en opnieuw laden, ook in OnSelect/loader.
- Save week controleert bij een bestaande EntryKey ook Assignment-ID en Work Date. Bestaande historische Employer niet wijzigen. Geen automatische sleutelreparatie of gegevensreconstructie tijdens laden.
- Beide Save-acties kunnen gedeeltelijk slagen; zij zijn geen SharePoint-transactie. Bij onzekere/gedeeltelijke opslag verder opslaan blokkeren en lokale invoer behouden. Geen automatisch ongedaanmaken. Controleer per item aantoonbare vorige waarden en legitieme latere wijzigingen voordat een herstel wordt voorgesteld.
- Deel- of afkapresultaten nooit als compleet gebruiken. Behoud de 500-regelbeveiliging; verhoog niet alleen de limiet en verberg geen delegatiewaarschuwingen. Filter waar ondersteund op SharePoint en verifieer queries/projectie in Studio/Monitor. Geen SharePoint-LookUp per tabelcel.
- SharePoint bevat blijvende gegevens; tijdelijke collections/lege keuzelijsten bewijzen geen dataverlies. Bij incidenten eerst savepad, Modified/Modified By en beschikbare versiegeschiedenis onderzoeken. Geen nieuwe lijsten, vervangende testdata of automatische correcties.
- Controleer actuele SharePoint-indexen online op basis van werkelijke filters. Lokale metadata bewijst niet dat een index aanwezig/afwezig is; een lookupindex alleen lost de List View Threshold niet op.
- Claim geen online import, correcte binding, volledigheid, functionele uitkomst of tijdwinst op basis van parser/pack. Actieve veiligheidscontroles: artifacts/Test-SaveRegression.ps1 en Test-WeeklyCalculations.ps1. Oude cache-/exact-ongewijzigde-Save-tests zijn niet de acceptatietest voor de nieuwe guard/stagingroute.
- Incident-/onlinecontrole-instructies staan in artifacts/SAVE_INCIDENT_EN_TEST.md. Voortgang en het exacte nieuwste buildpad staan in PROJECT_STATUS.md.
## Appbrede knopkleuren

- Schermnavigatieknoppen: achtergrond #194296, hover #123273, witte tekst.
- Actieknoppen (Save, Refresh en lokale weekschuifknoppen): achtergrond #7040A0, hover #593080, witte tekst. Paars vervangt eerdere groene actiekleurvoorstellen; gebruik geen groen als algemene actiekleur.
- Ingedrukte toestand gebruikt dezelfde achtergrond als hover, met witte tekst. Randkleuren volgen de betreffende achtergrond/hoverkleur.
- Uitgeschakelde zichtbare knoppen: achtergrond #E5E7EB en tekst #6B7280, voor zowel navigatie als acties.
- Gebruik duidelijke bestaande knopteksten naast kleur; kleur mag het enige onderscheid niet zijn. Verborgen technische knoppen blijven buiten de visuele standaard.
- Behoud de vaste onderste balk: navigatie links, alle zichtbare acties rechts binnen dezelfde rij. Een kleuropdracht verandert geen posities, afmetingen, acties, validaties, Visible of DisplayMode.
## Een vaste onderste knoppenrij op alle schermen

- Screen1, Weekly Hours en Hours Summary hebben ieder een vaste onderste balk met precies een gezamenlijke rij. Navigatie links, acties rechts; alle zichtbare knoppen zijn directe kinderen van dezelfde rijcontainer. Geen aparte actiebalk of tweede rij.
- Gebruik appbreed uitsluitend lblFooterButtonMetrics.Y = 16 voor de Y-positie van iedere zichtbare knop, en lblFooterButtonMetrics.Height = 40 voor de hoogte. X = 40 is de randmarge; Width = 12 is de gedeelde tussenruimte. Deze verborgen opmaakcontrol bevat geen gegevens- of laadlogica.
- Binnen navigatie-/actiereeksen exact 12 px tussenruimte; tussen beide zijden minimaal 12 px en op brede schermen vrije ruimte. Behoud knopbreedtes en tekst; geen ongemerkte regelomloop.
- Footer blijft verankerd aan Parent.Height-Self.Height. De binnenrij is 72 px hoog; de vaste buitenbalk 88 px inclusief 16 px ruimte voor een horizontale scrollbar. LayoutWrap=false, horizontale overflow Scroll, verticale overflow Hide.
- Als alle knoppen niet passen, blijft de rij breed genoeg en is zij horizontaal scrollbaar. Minimale rijbreedtes met huidige knoppen: Screen1 726 px, Weekly Hours 514 px, Hours Summary 474 px. Geen knoppen over elkaar, wegknippen of automatisch op een tweede rij plaatsen. Controleer werkelijk scroll-/focusgedrag in Studio/browser.
- Houd status, headers, tabellen en totalen boven de buitenbalk. Verwijder bij verplaatsing inhoudsposities die nog naar oude actieknop-Y/Height verwijzen; zulke verwijzingen hebben na een parentwissel een andere oorsprong.
- Een layoutcorrectie behoudt alle kleuren, teksten, OnSelect/OnChange, Items, filters, laad-/opslaglogica, validaties, Visible en DisplayMode. Hidden technische laadknoppen blijven op hun bestaande plek. Controleer de parsed diff en de werkelijke parentafhankelijkheden.
- Gebruik artifacts/Test-FooterRow.ps1 voor de huidige layout-/gedragsdiff en numerieke controle op alle drie schermen. Eerdere geometriescripts die uitgaan van actieknoppen bij de inhoud zijn historisch. PAC-pack en deze controles vervangen geen Studio-import of browsercontrole.