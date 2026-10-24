We bouwen een bestaande Power Apps canvas-app voor site management. Lees eerst de lokale bronbestanden. Bouw verder op de bestaande app en behoud de werkwijze van onze Excel/VBA-versie.

Sla onderstaande projectafspraken op in AGENTS.md. Vul technische bevindingen aan nadat je de bestanden hebt onderzocht.

## Project en ontwikkelomgeving

Projectmap (sinds 22-10-2026, buiten OneDrive):
C:\Users\vandergoot.ed\Dev\Sitemanagment

Huidige uitgepakte bronmap:
SiteManagement_20261019_232919

- De oude map C:\Users\vandergoot.ed\OneDrive - GEA\Projects\Development\Sitemanagment is een alleen-lezen backup. Schrijf daar nooit.
- Scripts in artifacts gebruiken alleen paden relatief aan $PSScriptRoot. Pointerbestanden (artifacts/*-backup.txt, *-builddir.txt, *-buildpath.txt) bevatten paden relatief aan de bronmap. Zet geen absolute paden in scripts of pointerbestanden.
- Git is nog niet geïnstalleerd; sla gitstappen over. Tot dan: checkpoints als mapkopie in checkpoints/, buiten Src.

Platform:
- Power Apps canvas-app voor gebruik in de browser.
- SharePoint voor gegevens.
- Power Automate voor serververwerking en export.
- VS Code met Power Platform Tools en Codex.
- Power Platform CLI 2.11.2; gebruik de layout SourceCode, niet Experimental. Vaste kopie: C:\Users\vandergoot.ed\Dev\Sitemanagment\pac\tools (in gebruikers-PATH; hele map nodig, scripts laden DLL's eruit). Niet de extensiekopie gebruiken.

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
- **Weekly Hours weekkeuze (sinds 22-10-2026):** één datumkiezer dpHoursWeek (ModernDatePicker@1.0.0, "dd-mm-yyyy", StartOfWeek.Monday, 256 px, geen StartDate/EndDate). De ISO-jaar/KW-dropdowns en de jaarbereik-queries op Hours zijn vervallen.
  - De gekozen dag (varHoursPickedDay) blijft zichtbaar en springt niet naar maandag. varHoursWeekMonday is de maandag van die dag. DefaultDate = Coalesce(varHoursPickedDay, Today()).
  - OnChange wordt overgeslagen tijdens laden en opslaan.
    - Een andere week laadt automatisch (Select(btnReadWeek)).
    - Een andere dag in dezelfde week bewaart alleen de dag en laadt niet opnieuw.
    - Met onopgeslagen uren: Reset naar de gekozen dag plus een melding, en niet laden.
    - De OnChange na een Reset is een no-op.
  - Geen Reset na een gewone keuze. DisplayMode is uitgeschakeld tijdens laden/opslaan of met onopgeslagen invoer.
  - Naast de kiezer staat lblHoursWeekKW met "YYYY KWxx" (ISO-jaar = Year(maandag+3), KW twee cijfers via ISOWeekNum). Voorbeeld: 01-01-2027 → "2026 KW53". Het veldlabel boven de kiezer is "Week".
  - Alle selectiecontroles (invoervelden, cache-hit, Save-guard) gebruiken varLoadedWeekMonday = varHoursWeekMonday. varWeekLoadedISOYear/KW worden uit de geladen maandag afgeleid.
  - Voeg geen Load-knop toe.
- Hours Summary kiest de periode met twee datumkiezers, From en Till (dd-mm-jjjj). From wordt genormaliseerd naar de maandag, Till naar de zondag van de gekozen week; de rapportage omvat altijd volledige ISO-weken. De ISO-jaar/KW-koppen van de tabel tonen de periode; er is geen aparte perioderegel. Weekly Hours gebruikt de weekkiezer hierboven.
- From en Till in dezelfde week betekenen één week. Till vóór From blokkeert het rapport met een melding.
- Een periode mag meerdere jaren omvatten.
- ISO-jaren moeten correct werken rond de jaarwisseling en bij week 53.
- De selecteerbare datums (StartDate/EndDate) en de standaardperiode komen uit beschikbare urenregistraties: maandag van de eerste t/m zondag van de laatste ISO-week met uren. Weekly Hours: vrije datumkeuze, standaard de week van vandaag.
- Het rapport toont één kolom per week en een periodetotaal per medewerker.
- Projectnummer en project reference horen in rapport en export.
- Hele uren mogen geen losse komma of punt achter het getal krijgen.
- Uren en weekkoppen worden gecentreerd binnen het urenoverzicht.

Exportafspraken staan in de sectie "Export (afspraak 22-10-2026, nog niet gebouwd)" hieronder. Die vervangt de eerdere .xlsx-afspraak per project en werkgever.

Medewerkers met periodetotaal 0 blijven beschikbaar in de ureninvoer. Of zij in de CSV-export voorkomen, is een open punt; zie PROJECT_STATUS.md.

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
- Nieuwe controltypen buiten de oorspronkelijke templates alleen met een door Microsoft gedocumenteerde control-ID/versie en eigenschappenlijst (nu uitsluitend ModernDatePicker@1.0.0, expliciet toegestaan in artifacts/Check-WeeklySource.ps1). Studio-import is de eerste acceptatiecontrole; bij een importfout de exacte melding terugkoppelen.
- Gebruik de werkelijke lookup-ID's voor project-, medewerker- en werkgeveridentiteit. Bewaar werkgeveridentiteit van Hours voor historische rapportregels.
- De huidige rapportbeveiliging is gebaseerd op de in de appmetadata bevestigde datarijlimiet 500 en ingeschakelde formulefoutafhandeling. Verlaag de rijlimiet niet zonder tegelijk de afkapcontroles te herzien. Alleen de limiet verhogen bewijst geen volledigheid.
- Een bereikt maximum van een opgehaalde batch moet het gehele rapport blokkeren; toon geen gedeeltelijke totalen. Houd ook rekening met de maximale 500 keuzeregels van een klassieke dropdown.
- Gebruik gedelegeerde filters op brongegevens en voer groepsberekeningen pas uit op expliciet geladen lokale gegevens. Verifieer de werkelijke serverqueries in Studio/Monitor.
- IfError rond een reeks acties met puntkomma's is geen garantie dat na een eerdere fout wordt gestopt. Controleer afzonderlijke risicovolle stappen en geef een rapport pas vrij als er geen fouten zijn.
- De bestaande gekoppelde flow (PowerAppV2 met LastIDinit, BatchCountinit, ReportHoursInit) heeft lokaal geen bewerkbare definitie. De export gebruikt de nieuwe generieke bestandsflow uit de exportsectie. Verzin daarbuiten geen flowparameters. Export is nog niet geïmplementeerd.

## Standaard voor zichtbare actie- en navigatieknoppen

- Height 40; Font ="Inter, Arial, sans-serif" (GEA-typografie, zie hieronder); Size 14; FontWeight Semibold.
- Horizontaal Align.Center en verticaal VerticalAlign.Middle, uitsluitend waar het controltype dit ondersteunt.
- PaddingTop/Bottom 0; PaddingLeft/Right 16; alle ondersteunde hoekradii 8.
- Naast elkaar geplaatste knoppen hebben dezelfde Y-positie en 12 px tussenruimte. Breedte mag verschillen, maar moet voldoende ruimte voor de volledige tekst laten.
- Behoud bestaande teksten, OnSelect, Visible en DisplayMode; kleuren volgen de appbrede kleurafspraak. Pas breedte, positie en zo nodig containers aan zonder overlap of afsnijden.
- Verborgen technische knoppen zijn uitgezonderd. Zichtbare compacte pijlknoppen volgen ook de gedeelde rijhoogte van 40 px. Voeg geen AccessibleLabel toe aan Classic/Button@2.2.0.
- Controleer tekstpassing en layout na import in Studio; pack en lokale eigenschapscontrole bewijzen de browserweergave niet.

## Plaatsing van titel, navigatie en acties

- De blauwe titelbalk bevat uitsluitend de schermtitel (Hours Summary: plus rechts de alleen-lezen projectregel Project Number/Project Reference); plaats er geen navigatie- of actieknoppen in.
- Alle zichtbare navigatie-, terug- en actieknoppen staan per scherm in een enkele vaste onderste knoppenbalk, buiten scrollende galleries of inhoudcontainers. Veranker de balk aan de onderkant van het scherm, zodat inhoudscrollen de balk niet verplaatst.
- Reserveer ruimte boven de balk voor tabellen, invoervelden, acties en totalen. Gebruik de balkpositie als ondergrens van de inhoud; laat niets achter de balk verdwijnen.
- Navigatie staat links en acties zoals Refresh, Save, weekschuiven en een toekomstige Export staan rechts binnen dezelfde onderste balk. Geen tweede actierij bij de inhoud; de titelbalk bevat uitsluitend de titel.
- De afgesproken knopstandaard blijft gelden: hoogte 40, Inter/Arial 14 Semibold, gecentreerd, ondersteunde radii 8 en 12 px tussenruimte tussen naast elkaar geplaatste knoppen.
- Behoud bestaande acties, validaties, Visible en DisplayMode bij verplaatsing. Let bij een gewijzigde parent op Parent-/Self-verwijzingen. Een nieuwe terugknop bij ureninvoer mag niet tijdens opslaan of met onopgeslagen wijzigingen navigeren.
- Controleer layoutformules op meerdere schermformaten en voer daarna Studio-/browsercontroles uit voor tekstpassing, overlap en daadwerkelijk scrollgedrag. Lokale rechthoekcontroles zijn geen visuele test.

## Hours Summary: compacte selectievelden

- Gedeelde visuele veldbreedte: lblSummaryFieldWidth.Width = 256 px. From en Till (dpReportFrom/dpReportUntil) hebben exact die breedte; Project en Contractor exact tweemaal die breedte. Dit is opmaak, geen teken- of invoerlimiet.
- Zichtbare veldlabels exact Project, Contractor, From, Till; alle vier FontWeight.Bold (Inter/Arial). Zichtbare labels en koppen op Hours Summary zijn Engelstalig; de tabelkoppen behouden het ISO-jaar/KW-formaat.
- Rek de velden niet uit met de schermbreedte. Linkermarge 40 px; label direct boven ieder veld op dezelfde X en breedte (4 px label/veldafstand); 12 px verticale ruimte tussen veldgroepen.
- Twee kolommen: links Project met daaronder Contractor (X = 0); rechts, 24 px ernaast, From op de hoogte van Project en Till op de hoogte van Contractor. De rechterkolom staat naast de linker als de selectie-inhoud minstens 512 + 24 + 256 = 792 px breed is (scherm vanaf 888 px); anders komt de datumgroep onder Contractor, zonder overlap. Geen aparte ISO-perioderegel. Actieknoppen staan in de vaste onderste balk.
- Datumkiezers: ModernDatePicker@1.0.0 (gedocumenteerd door Microsoft; zit niet in de oorspronkelijke app-templates, Studio-import moet de template bevestigen). Format "dd-mm-yyyy", StartOfWeek.Monday. Geen Load-knop. Tijdens laden (varReportBusy) wordt OnChange overgeslagen.
  - **Geen zichtbare normalisatie:**
    - De kiezer blijft de gekozen dag tonen.
    - De gekozen dagen staan apart in varReportFromPickedDay / varReportUntilPickedDay.
    - DefaultDate = Coalesce(gekozen dag, varReportStartMonday / varReportEndSunday).
  - **OnChange:**
    - Bewaart de gekozen dag.
    - Normaliseert From naar maandag en Till naar zondag, in varReportStartMonday / varReportEndSunday.
    - Bouwt alleen bij een gewijzigde weekgrens, via Select(btnBuildReport). Een andere dag in dezelfde week bouwt niet opnieuw.
  - **Reset van de kiezers alleen:**
    - bij laden (nieuw project / standaardperiode): eerst de gekozen dagen wissen, dan Reset;
    - bij een geblokkeerde wijziging (leeg gemaakt veld).
    - Nooit na een gewone keuze.
  - **Weeklabel per kiezer:**
    - lblReportFromWeek / lblReportUntilWeek tonen "YYYY KWxx": ISO-jaar = Year(maandag+3), KW twee cijfers via ISOWeekNum.
    - From toont de week van varReportStartMonday, Till die van varReportEndSunday.
    - Het weeklabel staat in de labelrij, in hetzelfde 256-px-vak als het veldlabel (zelfde X/Y/breedte/hoogte), rechts uitgelijnd. Het veldlabel staat links; geen breedtewijziging.
    - Inter/Arial 12, Normal, zwart.
  - Till vóór From: rapport geblokkeerd met melding en ValidationState.Error op Till. Beide weeklabels blijven zichtbaar.
  - Er komt nog steeds geen aparte perioderegel.
- Het rapport gebruikt varReportFrom = varReportStartMonday en varReportUntil = varReportEndSunday + 1 dag (exclusief). Deze periode is ook de basis voor de toekomstige export.
- Houd de onderste navigatie vast. Het selectieblok is een afzonderlijk scrollbaar blok (maximaal 220 px hoog) als gestapelde velden niet passen, zonder tabel/totaal of titelbalk te overlappen. Bij vensters smaller dan een 512-px-veld plus marges is horizontaal scrollen de uitwijkmogelijkheid; krimp de breedteverhouding niet.
- Gebruik artifacts/Test-SummaryDates.ps1 voor structuur, verwijderde verwijzingen, normalisatie zonder reset-lus en zonder herhaald bouwen, weeklabels (incl. KW53/jaarwisseling) en de selectorlayout 320–1920 px. De historische checkpoint-diff draait alleen met -HistoricalDiff; Test-WeeklyCalculations.ps1 test maandag/zondag, weekaantallen, jaarwisseling/week 53 en de blokkade van eind vóór begin.
- Gebruik gewone layoutcontainers zodat bestaande Reset-/Select-acties hun controls behouden; wijzig bij een layoutopdracht geen Items, Default, OnChange, filters, acties of gegevens.
- De standaard betreft de selectievelden; een volledige telefoonlayout voor de bestaande rapporttabel is een afzonderlijke wijziging. Controleer AutoLayout-overflow en behouden selectiegedrag in Studio/browser.

## Hours Summary: opmaak van tekst en tabel

- Geen toelichtingstekst onder de titel en geen statistiekregel (aantal medewerkers/weken/uren). Het selectieblok begint 12 px onder de titelbalk. lblReportStatus staat direct onder het selectieblok en toont alleen laden, laad-/rapportfouten en de melding dat een project geen opgeslagen uren heeft; zonder tekst is de regel 0 px hoog (geen marge). Periodetotaal blijft.
- Blauwe titelbalk: links "Hours Summary" (lblWeeklyHoursTitle, vaste 280 px). Rechts daarnaast lblReportProjectDetails met dezelfde blauwe Fill, Y en hoogte, witte tekst, Align.Right, VerticalAlign.Middle, PaddingRight 24: "Project Number: <Projects.'Project Number'> | Project Reference: <Projects.'Project Reference'>" via LookUp op ddReportProject.Selected.ID (koppeling en volgorde niet verwisselen). Beide labels liggen naast elkaar en overlappen niet, ongeacht z-volgorde. Geen projectregel meer buiten de titelbalk. Onder ongeveer 690 px schermbreedte kan de projectregel worden afgekapt (bekende beperking smal venster). Dit is een tekst-/informatiebalk, geen knop: de regel "titelbalk alleen titel" betreft knoppen.
- Lettertype en tekstkleuren volgen de GEA-typografie hieronder.
- Gewone labels, dropdowntekst en tabelgegevens zwart #000000; geen grijze tekst. Wit blijft op titelbalk, tabelkop en knoppen.
- **Tabelkop:** één ononderbroken balk Vibrant Blue #0303B8 van Name tot en met Period total, met witte tekst. galReportWeekHeaders heeft dezelfde Fill, zodat de balk ook doorloopt bij weinig weekkolommen. Alle koppen Y=lblReportNameHeader.Y, hoogte 40, VerticalAlign.Middle; Semibold, behalve Period total (Bold).
- **Scrollbarruimte:** de rijgallery is Parent.Width-80 breed, inclusief 16 px voor de scrollbar. Kop, rijcellen en totaalrij eindigen alle drie op schermbreedte-56.
  - Weekgebied: Parent.Width-616.
  - Period total-kolom: X = Parent.Width-176 (in de rij scrWeeklyHours.Width-216), breedte 120.
  - Aantal zichtbare weken: RoundDown((breedte-616)/90).
- **Rijen:**
  - TemplateFill afwisselend #FFFFFF / #F0F0F0 op zichtbare rijpositie (RowNumber in galReportRows.Items, dezelfde sortering op WorkerName), niet op worker-ID.
  - Rijlijnen 1 px #DCDCDC.
  - Weekuren en totalen gecentreerd.
- **Nulwaarden:** een 0 in een weekcel, Period total of de totaalrij wordt getoond als "–" (Normal). De gegevens, berekening en export behouden 0; alleen de tekstweergave verandert.
- **Period total-kolom:** geen vlakkleur, tekst Navy #000F41 Bold (Normal bij "–"), 1 px #DCDCDC-lijn links. De kop blijft blauw met witte tekst, tekst "Period total".
- **Totaalrij** (vervangt het zwevende lblReportGrandTotal):
  - Direct onder de rijen, buiten de gallery en boven de footer. De rijgallery is zo hoog als haar rijen (44 px per rij), maximaal tot 12 px + 44 px boven de footer.
  - Fill Light Blue #D5EDFF, 2 px bovenlijn #0303B8, Bold zwart.
  - "Total" in de Name-kolom. Weeksommen via galReportTotalWeeks, met exact dezelfde Items-paginering en -offset als de kop (som uit colReportSelectedHours per maandag). Periodetotaal = Sum(colReportRows, PeriodTotal) onder de Period total-kolom.
  - Alleen zichtbaar bij een geldig rapport (varReportValid && !varReportBusy).
- Onder ongeveer 666 px schermbreedte is er geen ruimte voor een weekkolom; de bestaande tabel is daar geen telefoonlayout (afzonderlijke wijziging).
- **Testscripts:**
  - artifacts/Test-SummaryStyle.ps1: zebra, nul als "–", Period total-kolom, totaalrij (paginering en sommen), kop- en kolomuitlijning met scrollbarruimte.
  - artifacts/Test-SummaryLabels.ps1: labels, titelbalk, de koppeling Project Number/Reference, en de rechterrand van de totaalrij gelijk aan de Period total-kolom.
  - De historische checkpoint-diffs draaien alleen met -HistoricalDiff.
  - Visuele weergave en tekstpassing vereisen Studio/browser.

## GEA-typografie (sinds 22-10-2026, vervangt Open Sans)

- **Lettertype in de app:**
  - Alle controls met tekst op alle schermen gebruiken `Font: ="Inter, Arial, sans-serif"`. Dit is een tekstwaarde: Inter als het op het apparaat staat, anders Arial (officiële GEA-fallback). Dat geldt ook voor verborgen technische controls die een Font hebben.
  - Gebruik geen Font-enum (`Font.'…'`), Open Sans, Segoe UI of Montserrat.
- **GEA Sans** is alleen voor grote koppen (headlines) volgens de GEA-richtlijn en wordt niet in de app gebruikt.
- **Gewichtsrollen** (ongewijzigd):
  - Semibold: schermtitels, tabel- en kolomkoppen, alle zichtbare knoppen.
  - Normal (expliciet): body, labels, statusregels, invoervelden, dropdowns, checkboxen en tabelgegevens.
  - Bold (nadruk): de veldlabels Project, Contractor, From en Till op Hours Summary, de kop Period total, de Period total-waarden en het algemene periodetotaal.
  - Subtitle4 op Screen1 behoudt zijn voorwaardelijke gewicht als selectieterugkoppeling.
- **Tekstkleuren (GEA):**
  - Body, velden, dropdowns, invoer en tabelgegevens: zwart #000000, ook in hover/pressed-tekst. Geen grijze tekst.
  - Tabel- en kolomkoppen (ook Weekly Hours): wit op Vibrant Blue #0303B8, zie GEA-kleuren.
  - Titels, de Hours Summary-tabelkop, de titelbalkregel en knoppen: wit op blauw.
  - Rood alleen als fouttoestand van statusregels.
  - Uitgeschakelde kleuren en vlakkleuren (Fill) zijn geen onderdeel van deze afspraak.
- **Exports** (PDF/CSV via de flow) gebruiken Arial.
- **Tekstpassing:**
  - Meet met `artifacts/Measure-FontFit.ps1 -InterDir <map met Inter-Regular/SemiBold/Bold.ttf> [-ArialDir <map met arial.ttf/arialbd.ttf>]`. Fontbestanden horen nooit in Src.
  - Gebruik het slechtste geval van Inter en Arial. Arial Semibold bestaat niet; de browser toont dan Bold, dus Semibold wordt met arialbd.ttf gemeten.
  - Verbreed zo nodig de control, niet de tekstgrootte.
  - Huidige knopbreedtes: Weekly Hours 170, Hours Summary 190, Project / team 180, Refresh 110, Save team 160, Save 140, pijlen 48.
- artifacts/Test-Fonts.ps1 controleert het lettertype en de gewichtsrollen. Waarden die bij 0 "–" tonen, zijn Normal; anders Bold. Kleuren controleert Test-GeaColors.ps1. Test-OpenSans.ps1 is vervallen (bewaard in checkpoints/gea-fonts-20261022_124840).

## Vaste architectuur, laden en opslagveiligheid

- Power Apps canvas + de bestaande SharePoint-lijsten blijven de vaste basis. Stel geen migratie naar Dataverse, SQL of een ander opslagplatform voor. Power Automate uitsluitend voor aantoonbaar noodzakelijke serververwerking/paginering; een flow is niet automatisch sneller.
- Na de Save-regressie van 20 oktober 2026 zijn de geneste week-/projectcaches en epochguards teruggenomen. De actieve bron gebruikt directe lookup-ID-/datumloaders, tijdelijke stagingcollections en lokale rapportberekening. Breng cacheoptimalisaties pas terug na afzonderlijke Studio-binding-, fout- en functionele tests. Eerdere performanceverslagen zijn historisch.
- Delegatie (metadata + Monitor 21-10-2026): lookup-ID's (Project.Id, Worker.Id, Assignment.Id) zijn niet filterbaar en geven $top=500 zonder $filter. Filter Project Workers uitsluitend op ProjectKey = vooraf berekende tekst (geen OR/StartsWith-fallback: Studio meldt dan een delegatiewaarschuwing) en Hours op StartsWith(EntryKey,"<id>|") (altijd met afsluitend "|") plus 'Work Date'-bereik; controleer Project.Id/Assignment.Id daarna lokaal. Medewerkers/projecten via de gedeelde colWorkersCache/colProjectsCache, geen SharePoint-LookUp per medewerker of in labels.
- Vul caches uit SharePoint met een expliciete ForAll-recordprojectie met weergavenamen ({ID, 'First Name', Surname, 'Employer Name', Employer, Trade}; projecten {ID, Title, 'Project Number', 'Project Reference'}), niet met ShowColumns: ShowColumns op een SharePoint-bron gaf in de collection de interne namen (field_2, field_3, field_5, ProjectName), waardoor ThisItem.'First Name' e.d. en Save team faalden.
- Hergebruik van geladen selecties (sinds 21-10-2026): een volledig Loaded selectie voor dezelfde project/team/week wordt bij navigeren niet opnieuw geladen; Refresh-knoppen forceren via force-vlaggen; varTeamDataVersion maakt Weekly Hours ongeldig na een teamload. Studio-/functionele test hiervan nog open (zie PROJECT_STATUS.md).
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

## Export (afspraak 22-10-2026, nog niet gebouwd)

- **Hours Summary:** CSV-export van de gekozen periode (varReportFrom t/m varReportUntil, volledige ISO-weken).
  - Eén bestand per selectie: project + werkgever, of project + alle werkgevers.
  - Geen PDF.
  - Zelfde CSV-specificatie als Week Report: lang formaat, één regel per opgeslagen dagregistratie (Hours-record), met dezelfde kolommen en codering.
- **Week Report:** PDF + CSV per werkgever, ongewijzigd ten opzichte van de bestaande werkwijze.
- **Bestandsinhoud wordt in de app opgebouwd:**
  - Eén gedeelde CSV-formule (Concat) voor beide schermen. Geen tweede, afwijkende CSV-opbouw.
  - De HTML voor de PDF wordt in de app opgebouwd.
  - UTF-8 BOM via UniChar(65279) aan het begin van iedere CSV.
- **Flow = generieke bestandsschrijver, zonder bedrijfslogica:**
  - Invoer: JSON-lijst van `{fileName, type: "csv" | "html2pdf", content}`.
  - Iedere invoer wordt opgeslagen in de documentbibliotheek Exports.
  - Bij `html2pdf`: het HTML-bestand omzetten met Convert file naar PDF.
  - De flow antwoordt met de bestandslinks.
  - Geen filtering, berekening, splitsing of validatie in de flow.
- **Export alleen bij een geldig rapport, fail-closed zoals Save:**
  - Dezelfde volledige toelatingscontrole in DisplayMode én als eerste OnSelect-voorwaarde.
  - Geen export bij een laadfout, een afgekapte batch (500), een lopende load, een ongeldige periode (Till vóór From) of een selectie die afwijkt van het geladen rapport.
  - Een mislukte of onvolledige flowrespons wordt zichtbaar gemeld en nooit als geslaagd getoond.
- **Microsoft-onderdelen** (worden in de Microsoft-omgeving aangemaakt, niet in de lokale bron): de flow en de Exports-bibliotheek. Het invoer-/uitvoercontract hierboven is leidend. Verzin geen extra flowparameters, kolommen of bibliotheekvelden.
- Geen automatische e-mailverzending. Bestanden moeten downloadbaar en op te slaan zijn via de teruggegeven links.
- De CSV-kolommen, het scheidingsteken, het decimaalteken en de datumnotatie van Week Report zijn lokaal niet vastgelegd. Neem ze over uit de bestaande Week Report-werkwijze zodra die is aangeleverd, niet zelf invullen.

## Opslaan in batch (sinds 22-10-2026)

- Save week = 1 pre-read + table Patch + 1 verify read.
  - Pre-read en verify read gebruiken hetzelfde gedelegeerde filter: `Filter(Hours, StartsWith(EntryKey, "<projectID>|") && 'Work Date' >= maandag && < maandag+7)`.
  - Een volle batch (500) valt terug op 7 dagbatches. Een volle dag blokkeert.
  - Alle controles gebeuren lokaal vóór het schrijven: sleutel/koppeling/datum, opgeslagen uren = OldHours, team en ontbrekende velden. Eén fout betekent nul writes.
  - Na het schrijven wordt colWeekOriginal alleen bijgewerkt vanuit de verify read.
- Er zijn hooguit twee table-Patches per Save week, omdat een changetabel één uniform schema heeft:
  - Bestaande regels: alleen Title + Hours. Employer/Team/Trade/Assignment blijven onaangeroerd (historie).
  - Nieuwe regels: volledig record.
  - Voeg ze niet samen tot één Patch: lege kolommen in een gedeeld schema zouden bestaande Employer-waarden wissen.
- Save team = 1 pre-read + hooguit 2 table-Patches (upsert, deactivering):
  - De pre-read is `Filter('Project Workers', ProjectKey = varTeamSaveProjectKey)`, inclusief inactieve koppelingen. `varTeamSaveProjectKey = Text(varTeamLoadedProjectID)` wordt vóór de read gezet.
  - Bij ≥500 rijen of `Project.Id <> varTeamLoadedProjectID`: fout, nul writes.
  - De match gebeurt lokaal op `AssignmentKey = varTeamSaveProjectKey & "|" & Text(person.ID)`.
  - Bekend risico: een koppeling met een juiste AssignmentKey maar een lege/afwijkende ProjectKey wordt niet gevonden en kan worden gedupliceerd. Daarom moet de SharePoint-controle "geen lege ProjectKey" blijven gelden.
  - Verwijderingen worden gecontroleerd vóór de eerste write.
- Predicaten op SharePoint-bronnen (Hours, 'Project Workers') gebruiken uitsluitend kolommen, functies en **globale** variabelen (Set). Gebruik geen With-namen of ForAll-recordvelden in het predicaat.
  - Studio gaf een delegatiewaarschuwing op `StartsWith(AssignmentKey, <With-naam> & "|")`.
  - Hours: `StartsWith(EntryKey, varXxxQueryPrefix)`, met de prefix (inclusief afsluitend "|") vooraf gezet.
  - Datumvensters: globale var, of `DateAdd(globale var, constante, ...)`. Dagterugval van 7 dagen wordt uitgeschreven, niet via ForAll.
  - Bekende uitzondering: de maand- en dagpaginering van Hours Summary binnen `ForAll(Sequence(monthCount))`. Set kan niet binnen ForAll; zie PROJECT_STATUS.md.
- Stringliterals bevatten geen regeleinde; Test-SaveRegression controleert dit.
- Geen `Choices()` en geen remote `LookUp`/`Filter` binnen ForAll-lussen of per cel/medewerker.
  - Lookupwaarden worden lokaal opgebouwd:
    - Assignment `{Id, Value: Project Workers.Title}` uit colWeekAssignments.
    - Employer `{Id, Value}` uit colWorkersCache.Employer.
    - Team/Trade (keuzekolommen) als `{Value}`.
  - Metadata: Hours.Assignment.Value = `Assignment/Title`, Employer.Value = `Employer/Title`, Team/Trade `IsChoice`.
- De basisrecords voor een update in de table-Patch komen uit de pre-read-collection (oorspronkelijk uit dezelfde bron). Of Studio dat als traceerbaar basisrecord accepteert, moet bij import/App checker en in een functionele test blijken.
- `Concurrent` is toegestaan voor onafhankelijke loads (nu: Projects, Team-keuzes en Workers in btnReadTeam). Iedere tak schrijft alleen naar zijn eigen foutcollection. Voeg die na Concurrent samen; laat takken nooit dezelfde collection of variabele schrijven.
- Trace `DIAG|SaveWeek|End` registreert ElapsedMs, Changes, Reads, Writes (aantal Patch-aanroepen), PatchedRows, VerifiedRows en Errors.
- Gedeeltelijke opslag blijft mogelijk: dit is geen SharePoint-transactie. Na een fout wordt opslaan geblokkeerd, blijft de invoer behouden en volgt geen automatisch ongedaanmaken.
## GEA-kleuren (sinds 22-10-2026, vervangt de eerdere blauw/paarse knopkleuren)

- **Palet** (alleen deze kleurliterals, plus Color.White/Black/Transparent):

  | Token | Hex | Gebruik |
  |---|---|---|
  | Vibrant Blue | #0303B8 | titelbalken, tabelkoppen, navigatieknoppen, secundaire rand/tekst, hover/focusrand van invoer, selectie |
  | Navy | #000F41 | tekst op primaire knoppen, hover/pressed van navigatie, Period total-waarden, weektotaal-tekst |
  | Green | #1AFF80 | uitsluitend primaire actie (vlak) |
  | Green hover | #18DD6E | hover/pressed van de primaire actie |
  | Light Blue | #D5EDFF | hover van secundaire knoppen, totaalrij, weektotaalcellen, geselecteerde medewerkerkaart |
  | Light Grey | #F0F0F0 | invoer/dropdowns/datumkiezers, zebra, footerbalk, schermachtergrond Screen1 |
  | Line Grey | #DCDCDC | randen van invoer, tabellijnen |
  | Disabled | #E6E6E6 / #787878 | vlak / tekst van uitgeschakelde knoppen (ook uitgeschakelde tekst elders) |
  | Error | #DB1E28 | foutstatus |
  | Wit / zwart | #FFFFFF / #000000 | achtergrond / body-tekst |

- Energetic Pink en Active Blue worden nooit als vlakkleur gebruikt. Er zijn geen andere hex- of RGBA-waarden.
- **Rollen:**
  - **Titelbalken, tabelkoppen** (Weekly Hours met doorlopende balk recHoursHeaderBar, en Hours Summary): #0303B8 met witte tekst.
  - **Navigatieknoppen** (Weekly Hours, Hours Summary, Project / team): Fill/rand #0303B8, witte tekst, hover/pressed #000F41.
  - **Primaire acties**, uitsluitend btnSaveWeek en btnAddtoTeam: Fill #1AFF80, tekst #000F41 (nooit wit), hover/pressed #18DD6E.
  - **Secundaire acties** (alle Refresh-knoppen, weekpijlen): wit vlak, 1 px rand en tekst #0303B8, hover/pressed #D5EDFF.
  - **Uitgeschakelde knoppen:** vlak en rand #E6E6E6, tekst #787878.
  - **Invoer, dropdowns, datumkiezers:** Fill #F0F0F0, 1 px rand #DCDCDC, hover- en focusrand #0303B8. Selectie in dropdowns #0303B8 met witte tekst.
  - **Weektotaal-cellen** (lblWeekTotal): #D5EDFF met tekst #000F41.
  - **Fouten** #DB1E28; body-tekst zwart.
- Gebruik duidelijke bestaande knopteksten naast kleur; kleur mag nooit het enige onderscheid zijn. Verborgen technische knoppen hebben geen rol, maar wel GEA-literals.
- Behoud de vaste onderste balk: navigatie links, alle zichtbare acties rechts binnen dezelfde rij. Een kleuropdracht verandert geen posities, afmetingen, acties, validaties, Visible of DisplayMode.
- artifacts/Test-GeaColors.ps1 controleert:
  - 0× oude literals en alleen GEA-tokens;
  - knoprollen inclusief disabled;
  - titelbalken en koppen;
  - invoer;
  - weektotaal en foutkleur.
## Een vaste onderste knoppenrij op alle schermen

- Screen1, Weekly Hours en Hours Summary hebben ieder een vaste onderste balk met precies een gezamenlijke rij. Navigatie links, acties rechts; alle zichtbare knoppen zijn directe kinderen van dezelfde rijcontainer. Geen aparte actiebalk of tweede rij.
- Gebruik appbreed uitsluitend lblFooterButtonMetrics.Y = 16 voor de Y-positie van iedere zichtbare knop, en lblFooterButtonMetrics.Height = 40 voor de hoogte. X = 40 is de randmarge; Width = 12 is de gedeelde tussenruimte. Deze verborgen opmaakcontrol bevat geen gegevens- of laadlogica.
- Binnen navigatie-/actiereeksen exact 12 px tussenruimte; tussen beide zijden minimaal 12 px en op brede schermen vrije ruimte. Behoud knopbreedtes en tekst; geen ongemerkte regelomloop.
- Footer blijft verankerd aan Parent.Height-Self.Height. De binnenrij is 72 px hoog; de vaste buitenbalk 88 px inclusief 16 px ruimte voor een horizontale scrollbar. LayoutWrap=false, horizontale overflow Scroll, verticale overflow Hide.
- Als alle knoppen niet passen, blijft de rij breed genoeg en is zij horizontaal scrollbaar. Minimale rijbreedtes met de huidige knoppen: Screen1 746 px, Weekly Hours 534 px, Hours Summary 502 px (pijlen 48 px). Geen knoppen over elkaar, wegknippen of automatisch op een tweede rij plaatsen. Controleer werkelijk scroll-/focusgedrag in Studio/browser.
- Houd status, headers, tabellen en totalen boven de buitenbalk. Verwijder bij verplaatsing inhoudsposities die nog naar oude actieknop-Y/Height verwijzen; zulke verwijzingen hebben na een parentwissel een andere oorsprong.
- Een layoutcorrectie behoudt alle kleuren, teksten, OnSelect/OnChange, Items, filters, laad-/opslaglogica, validaties, Visible en DisplayMode. Hidden technische laadknoppen blijven op hun bestaande plek. Controleer de parsed diff en de werkelijke parentafhankelijkheden.
- Gebruik artifacts/Test-FooterRow.ps1 -GeometryOnly voor de numerieke footercontrole op alle drie schermen; de diff zonder schakelaar vergelijkt met het historische footer-checkpoint. Eerdere geometriescripts die uitgaan van actieknoppen bij de inhoud zijn historisch. PAC-pack en deze controles vervangen geen Studio-import of browsercontrole.