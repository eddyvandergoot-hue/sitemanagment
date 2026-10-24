**Historisch performanceverslag.** Na de Save-regressie zijn de beschreven geneste caches en epochroute teruggenomen. Actuele bron/veiligheid en online controles: [SAVE_INCIDENT_EN_TEST.md](SAVE_INCIDENT_EN_TEST.md). De indexinventaris blijft een te controleren advies, geen vastgestelde online inventaris.

# Performance: uitvoering en online controle

Power Apps canvas + de bestaande SharePoint-lijsten blijven de vaste architectuur. Geen nieuwe lijsten, kolommen, testdata of flow aangemaakt. De testapp gebruikt dezelfde site en lijst-ID's als productie; expliciet opslaan wijzigt dus dezelfde gegevens. Zie GEGEVENSBRONNEN_EN_TEST.md.

## Onderzochte laadroute

| Onderdeel | Gevonden | Gewijzigd |
| --- | --- | --- |
| App.OnStart | Alleen statusvariabelen; geen bulkload | Behouden |
| Screen1.OnVisible / project / team | Iedere keer Refresh van drie bronnen, projecten opnieuw lezen, geselecteerde medewerkers opnieuw opzoeken | Zelfde succesvolle project/team/epoch overslaan; projecten eenmaal per epoch; expliciete Refresh apart |
| Naar Weekly Hours | Extra Refresh Project Workers vlak voor volgende loader | Verwijderd; loader bepaalt zelf wat nodig is |
| Weekly Hours: jaar / KW / OnVisible | Refresh van twee bronnen en twee globale datumbereiken bij iedere wissel; Reset en Select kunnen dezelfde load opnieuw plannen | Volledige weekcache per project/team/ISO-jaar/KW/epoch, identieke selectie overslaan; datumbereik eenmaal per epoch; expliciete Refresh |
| Hours Summary.OnVisible | Alle historie opnieuw ophalen, selecties opnieuw initialiseren | Succesvol geladen project behouden; meerdere projectcaches binnen sessie |
| Hours Summary.Refresh | Zowel automatisch laden als expliciet verversen | Verborgen btnLoadReport voor laden; zichtbare Refresh ververst bronnen en invalideert caches |
| Hours Summary historie | Twee datumbereikformules plus een query per kalenderjaar per assignment | Eerst een smalle assignmentbatch; alleen bij >=500 regels terugvallen op de bestaande gecontroleerde jaarbatches |
| Contractor / rapportperiode | Reeds lokale filters en berekening | Behouden; geen SharePoint-query nodig voor deze veranderingen |
| Tabelcellen | Uren en samenvatting gebruiken al lokale gegevens | Behouden; geen SharePoint-LookUp per uren-/rapportcel toegevoegd |

Hours-queries filteren op Assignment.Id en voor een week/jaarbatches ook op Work Date vóór ophalen. ShowColumns beperkt ze expliciet tot ID, datum, uren en respectievelijk EntryKey of historische Employer. Werkelijke connectorprojectie en serverdelegatie blijven Monitor-controles. Medewerkerprofielen worden nog één keer per betrokken unieke medewerker per projectload opgezocht; Screen1 per actieve koppeling. De grote centrale Workers-gallery blijft rechtstreeks gekoppeld, zonder onvolledige bulkcache van alle medewerkers.

## Cache en correctheid

- colWeekCache bevat uitsluitend succesvol gevalideerde weken, inclusief nulurenmedewerkers, opgeslagen sleutels en opslagcontext. Identiteit bevat project, team, ISO-jaar en KW. Een lege maar geldige week kan eveneens worden gecachet.
- colReportCache bevat uitsluitend volledig geladen projectfacts, historische werkgevers, actieve medewerkers en beschikbare perioden/contractors. Bij terugkeer naar een ander eerder geladen project worden standaard de volledige beschikbare periode en alle contractors gekozen. Bij terugkeer naar hetzelfde scherm/project blijven de huidige selecties behouden.
- varDataEpoch is de gedeelde geldigheidsversie. Iedere expliciete Refresh en iedere Save/Save team-poging verhoogt deze en leegt beide caches, ook na een mislukte opslagpoging. Zo wordt mogelijk gewijzigde data opnieuw gelezen. De bestaande opslagkern is exact behouden.
- Andere gebruikers maken deze lokale sessiecache niet automatisch ongeldig. Gebruik Refresh op het betreffende scherm, of open een nieuwe sessie. Refresh haalt Hours/Project Workers voor invoer, Projects/Workers/Project Workers voor teambeheer, en alle vier bronnen voor rapportage opnieuw op.
- Een mislukte Refresh wordt per bron gevangen in de foutcollection. De loader blokkeert dan de weergave/opslag van resultaten en toont de fout. Een foutbatch wordt niet als geldige cache opgeslagen.
- Busy-vlaggen beschermen lopende loads; selectie- en epochcontroles voorkomen dat na Reset/Select opnieuw geplande identieke loads opnieuw queryen. Weekcacheherstel gebeurt eveneens met de laadblokkade actief. Dit moet nog met snelle selectiewissels in Studio worden bevestigd.
- De bestaande 500-regelbeveiliging is behouden. >=500 in een jaarbatch, weekbatch of assignmentlijst stopt het overzicht. De eerste historische batch van >=500 wordt nooit gebruikt als complete dataset: eerst gecontroleerde jaarbatches laden. Geen limiet verhoogd of waarschuwing verborgen.
- ISO-berekeningen, week 53, jaarovergangen, historische werkgevers en actieve nulurenmedewerkers zijn behouden. Geen automatische gegevensmutaties tijdens laden.

## Resterende schaalbeperking

Hours heeft geen opgeslagen ISO-jaar/KW en de beschikbare perioden moeten exact uit opgeslagen datums komen. Daarom blijft een eerste volledige projecthistorielezing nodig voor de periodekeuzes, ook wanneer daarna één week wordt getoond. Periodekeuzes en berekening zijn gescheiden, maar periodedetectie en historische factophaling zijn nog gecombineerd. De scan wordt nu hergebruikt en voor kleine assignments verkort; voor grote assignments blijven lussen per assignment en kalenderjaar bestaan. Een jaarbatch van 500 of meer blokkeert bewust. Zonder online volumemeting en contract voor serverpaginering is geen aanvullende flow toegevoegd. Een flow wordt pas overwogen als Monitor aantoont dat gecontroleerde serverpaginering nodig is; SharePoint blijft de opslag.

De caches groeien met succesvol bezochte weken/projecten tot Refresh, opslaan of afsluiten. Geheugengebruik en grote projecten zijn nog niet online gemeten. Dit is geen claim van onbeperkte schaalbaarheid.

## SharePoint-indexen: controleren, aanwezigheid onbekend

Lokale appmetadata bevat geen betrouwbare actuele indexinventaris. Geen index is hier als daadwerkelijk ontbrekend vastgesteld en geen index is gewijzigd.

Open https://geacloud.sharepoint.com/sites/GEASiteManagment en ga per lijst naar **Instellingen > Lijstinstellingen > Geindexeerde kolommen**. Controleer onderstaande kolommen. Maak een ontbrekende enkelvoudige index via **Nieuwe index maken > primaire kolom > Maken**; wacht tot het indexeren klaar is. Laat bestaande indexen staan.

| Lijst | Kolom | Werkelijk gebruik / prioriteit |
| --- | --- | --- |
| Hours | Work Date (intern WorkDate) | Datumrange week/jaar en oudste/nieuwste datum; eerste controle |
| Hours | Assignment | Equality op lookup-ID voor alle urenloads; controleer index, maar zie thresholdbeperking hieronder |
| Hours | EntryKey | Equality in bestaande expliciete Save/controle; tekstindex |
| Project Workers | Project | Equality op lookup-ID bij team/invoer/rapport; lookupbeperking hieronder |
| Project Workers | Team | Bestaande teamfilters; enkelvoudige Choice |
| Project Workers | Active | Bestaande actieve-teamfilters; lage selectiviteit, alleen ondersteunend |
| Project Workers | ProjectKey | Bestaande expliciete teamopslag/terugleescontrole; tekstindex |
| Project Workers | AssignmentKey | Bestaande assignmentidentiteit bij teamopslag; tekstindex |
| Projects | Title | Sortering van projectkeuzes; lagere prioriteit |
| Workers / Projects / Employers | ID | SharePoint-systeemindex; geen nieuwe ID-kolom/index aanmaken |

Een Employer-index is voor het huidige lokale contractorfilter niet nodig. Verander geen historische werkgevers om een index te gebruiken. ProjectKey/AssignmentKey zijn geen vervanging voor de huidige lookupfilters: bestaande afwijkende sleutelgegevens mogen niet verdwijnen.

Een geindexeerde lookupkolom lost volgens Microsoft de SharePoint List View Threshold niet op. Work Date moet eveneens worden gecontroleerd; bij thresholdfouten moet de werkelijke query/selectiviteit met Monitor worden onderzocht. Indexen bewijzen geen Power Apps-delegatie en geen volledige totalen. Bron: [Microsoft: index toevoegen en lookupbeperking](https://support.microsoft.com/en-us/sharepoint/data-and-lists/add-an-index-to-a-list-or-library-column).

## Online test en Monitor

1. Importeer de nieuwste .msapp als aparte app. Open App checker en controleer schema, binding (ook nested cachetabellen), delegatie en verbindingen. Start een nieuwe sessie; kies bestaand project/team. Controleer medewerkers, actieve nulurenleden en een bekende opgeslagen week.
2. Wissel week en rapportperiode. Vergelijk bekende dag-/weektotalen, één week, meerdere weken en ISO 2020-W53 naar 2021-W01. Wacht op afgeronde laadstatus; probeer ook snel achtereen selecties. Geen andere projecten/teams in resultaten.
3. Wissel contractor op Hours Summary. Historische uren blijven bij hun opgeslagen werkgever. Dit hoort uitsluitend lokaal te filteren: geen nieuwe Hours-aanvragen door deze actie.
4. Keer terug naar een al geladen week en project. Vergelijk totalen met de eerste weergave; controleer dat de cache wordt gebruikt. Bij projectwisseling in rapportage worden periode/contractor opnieuw op de volledige projectperiode/alle contractors ingesteld.
5. Laat een bevoegde gebruiker een echte, bedoelde wijziging opslaan in SharePoint of de werkende app. Klik Refresh op het betreffende testscherm en controleer die wijziging. Geen nieuwe testdata nodig. Refresh in ureninvoer is geblokkeerd bij onopgeslagen lokale edits. Controleer bij een echte verbindingsfout dat een duidelijke fout verschijnt en geen gedeeltelijke totalen/opslaan beschikbaar blijven.

Open **Live monitor** vanuit Power Apps Studio (geavanceerde hulpmiddelen), start de preview en voer elk scenario afzonderlijk uit. Noteer geselecteerd project/team/jaar/KW of periode, tijd tot bruikbaar resultaat, aantal netwerkgebeurtenissen, Data source, Duration, status, formule/control en query/response. Inspecteer bij Hours het serverfilter Assignment-ID plus datumrange en de geselecteerde kolommen. Controleer dat een capbatch niet als compleet wordt gebruikt en dat dezelfde selectie niet opnieuw parallel wordt geladen. Vergelijk een koude start met een herbezoek in dezelfde sessie; vergelijk baseline en nieuwe testapp met dezelfde data/account. Exporteer het Monitor-log voor analyse. Geen productiepublicatie nodig.

De verwachting van minder query-expressies is uit de bron afgeleid; aantallen werkelijke HTTP-aanvragen en tijdwinst zijn niet lokaal gemeten. Een geslaagde PAC-pack bewijst geen geslaagde Studio-import, delegatie, cachebinding of functionele test.

Aanvullende bronnen: [Microsoft querypatronen](https://learn.microsoft.com/en-us/power-apps/maker/canvas-apps/optimized-query-data-patterns), [kleine payloads](https://learn.microsoft.com/power-apps/maker/canvas-apps/small-data-payloads), [Live monitor](https://learn.microsoft.com/en-us/power-apps/maker/monitor-canvasapps).
