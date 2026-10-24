# Onderzoek trage gegevensophaling — 21 oktober 2026

Status: **fase 1 voorbereid, nog niet gemeten.** Alle getallen hieronder zijn afgeleid uit de broncode (aantal aanvragen per formule), niet uit metingen. Er zijn geen online metingen uitgevoerd. Echte tijden, aantallen en fouten volgen uit de Live Monitor-uitvoer.

Basis: hoofdbron Src, gelijk aan build `summary-labels-20261021_105544`. Eerdere performancedocumenten (PERFORMANCE_EN_INDEXEN.md) gaan over een teruggedraaide cacheversie en zijn historisch.

## 1. Diagnostische build

`artifacts\diagnostics-20261021_120112\SiteManagement_Diagnostics_20261021_120112.msapp`

- Gemaakt met `artifacts\Make-DiagnosticBuild.ps1` uit een kopie van Src (`artifacts\diagnostics-20261021_120112\source`). Src zelf is niet gewijzigd.
- 45 markeringen `Trace("DIAG|<scenario>|<stap>", ..., {ElapsedMs, aantallen, Errors})`. Daarnaast alleen timers `Set(varDiag…T0, Now())`. Er zijn geen data-, laad- of opslagstappen toegevoegd of gewijzigd. Het script controleert dat het weghalen van de markeringen exact de originele bron oplevert, dat alle 1469 formules parseren en dat de Save-guards onveranderd vooraan staan.
- Scenario's en stappen:
  - `App|OnStart`, `Screen1|OnVisible`.
  - `Team|Start, AfterRefresh, AfterMasters, AfterWorkersCheck, AfterAssignments, AfterWorkerLookups, End`, plus `Team|RefreshClick`.
  - `Week|OnVisible, Start, AfterRefresh, AfterYearBounds, AfterAssignments, AfterHoursQueries, AfterLocalBuild, End`, plus `Week|RefreshClick` en `Week|BlockedUnsaved`.
  - `Summary|OnVisible` (met `WillLoad`), `Report|Start … AfterProjects, AfterRefresh, AfterAssignments, AfterWorkerLookups, AfterHoursQueries, AfterLocalPeriods, End`.
  - `Build|Start, End/Stopped`: de lokale verwerking van het rapport.
  - `Summary|ContractorChange, FromChange, TillChange, RefreshClick`.
  - `SaveTeam|Start, BeforeReload` en `SaveWeek|Start, AfterWrites, End`.
  - `Nav|…` bij iedere navigatieknop.
- `ElapsedMs` is de tijd sinds `Start` van dezelfde laadactie. Het verschil tussen twee opeenvolgende stappen is de tijd per laadstap. De aantallen in de Trace zijn de lokaal ontvangen rijen. Netwerkaanvragen, duur, status (429 = throttling), responsgrootte en waarschuwingen staan als Network-events in Live Monitor.

## 2. Meten met Live Monitor (kort)

1. Importeer de diagnostische build als **aparte** app (make.powerapps.com → Apps → Import app → From file), met dezelfde SharePoint-verbinding.
2. Apps → selecteer de diagnostische app → menu naast **Details** → **Live monitor** → **Play published app**.
3. Voer per scenario de stappen uit. Wacht tot de statusregel klaar is voordat je verdergaat. Noteer kort de volgorde.
   1. App openen, nog niets kiezen.
   2. Project kiezen, daarna team kiezen.
   3. Weekly Hours openen. Daarna KW +1, daarna een ander ISO-jaar.
   4. Terug naar Project / team en meteen weer naar Weekly Hours (dezelfde selectie).
   5. Hours Summary openen. From wijzigen, Till wijzigen, contractor wijzigen.
   6. Terug naar Project / team en weer naar Hours Summary (zelfde project).
   7. Refresh op alle drie schermen.
   8. Save week met **één echte, gewenste** wijziging. Let op: dit schrijft naar de productielijsten. Sla over als er niets op te slaan valt.
   9. Optioneel Save team zonder wijziging. Dit schrijft alle geselecteerde koppelingen opnieuw (nieuwe versie/Modified, zelfde waarden). Sla over als je dat niet wilt.
4. Exporteer de sessie. Biedt Live monitor een download/export (JSON of CSV), sla die op en stuur het bestand. Zonder exportknop: filter op Category **Trace** en **Network**, en stuur schermafbeeldingen plus de details van de traagste events (tab Details en Response).
5. Optioneel: Instellingen → **Debug published app** koppelt events aan formules, maar vertraagt de app. Alleen in deze diagnostische app gebruiken.

Per scenario uit de uitvoer halen:

- de totale wachttijd (`…|End.ElapsedMs`) en de tijd per stap;
- het aantal Network-events tussen Start en End, en welke herhaald worden;
- de rijen per stap (Trace-velden);
- de status 429/5xx en waarschuwingen (delegatie, throttling);
- de lokale verwerkingstijd (`Build|End.ElapsedMs` en `Week AfterLocalBuild → End`).

## 3. Bevindingen uit de code (vastgesteld in de bron, niet gemeten)

N = actieve teamleden, A = koppelingen in het project, W = unieke medewerkers in het project, Y = kalenderjaren met uren per koppeling, C = gewijzigde dagcellen, S = geselecteerde teamleden.

| Scenario | Wat de code doet | Aanvragen volgens code |
| --- | --- | --- |
| App openen | btnReadTeam: Projects gesorteerd, Choices(Team), First(Workers). Gallery leest Workers per pagina. | ca. 3 + gallerypagina's |
| Project/team kiezen | Beide dropdowns starten btnReadTeam. Per teamlid een aparte `LookUp(Workers, ID=…)`. | per keuze: 1 (First(Workers)) + 1 (koppelingen) + **N** |
| Terug naar Project / team | OnVisible laadt het team altijd opnieuw (behalve bij onopgeslagen selectie). | N + 2, iedere keer |
| Weekly Hours openen of week wijzigen | Iedere keer: Refresh(Hours) en Refresh(Project Workers), **twee keer een sortering over de hele Hours-lijst** (alleen voor het jaarbereik van de dropdown), koppelingen, en **per teamlid een urenquery**. Geen hergebruik bij terugkeren. | N + 3 (+ verversen) |
| Hours Summary openen | Refresh van 4 bronnen, Projects, koppelingen, **per medewerker een LookUp(Workers)**, **per koppeling 2 queries (eerste/laatste datum) + 1 per kalenderjaar**. | ca. 2 + W + Σ(2 + Y) = bij 20 koppelingen, 1 jaar ≈ 82 |
| Periode/contractor wijzigen | Alleen lokale opbouw (btnBuildReport). | 0 netwerk; alleen lokale verwerkingstijd |
| Terug naar Summary | Herladen alleen als het rapport ongeldig is of het project anders. Na iedere Save (week of team) is het rapport ongeldig, dus volledig opnieuw. | 0 of volledig |
| Save week | Per gewijzigde cel: LookUp(Hours, EntryKey) + LookUp(Workers) + Patch. Bij nieuwe regels ook `Choices(Hours.Assignment)` en `Choices(Hours.Employer)`. Daarna Refresh(Hours) + per geschreven regel een controle-LookUp. | ca. 4–6 × C |
| Save team | Per geselecteerde medewerker LookUp + Patch, per verwijderde LookUp + Patch, daarna geforceerd herladen (3 × Refresh, projecten/teamkeuzes, team). | 2 × S + herladen |

Gevolg: de wachttijd groeit lineair met teamgrootte (Weekly Hours, Screen1) en met projectomvang en historie (Hours Summary). De aanvragen worden achter elkaar in één gedrag uitgevoerd.

Correctheids- en schaalrisico's (uit code, niet bevestigd):

- **List View Threshold:** `First(Sort(Hours, 'Work Date'))` sorteert de hele Hours-lijst. Bij meer dan 5000 items en geen index op 'Work Date' kan SharePoint dit weigeren. Dan blokkeert Weekly Hours, fail-closed. Bij 30 medewerkers × 5 dagen × 50 weken komt dat binnen ongeveer een jaar in zicht.
- **Choices op een lookup bij nieuwe uren:** `Choices(Hours.Assignment)` haalt items uit de Project Workers-lijst. Dat is niet gedelegeerd en vermoedelijk begrensd tot de datarijlimiet. Ligt een koppeling buiten dat deel, dan stopt Save met "Assignment … ontbreekt". Er gaat niets verloren, maar opslaan wordt geblokkeerd. Te bevestigen zodra Project Workers meer dan 500 items heeft.

## 4. Vermoedens (te bevestigen met de meting)

- De grootste wachttijden zitten in Hours Summary (`AfterHoursQueries`) en in de N losse queries per teamlid in Weekly Hours en Screen1.
- De twee volledige Hours-sorteringen bij iedere weekwissel kosten merkbaar tijd zonder functionele winst.
- `Refresh()` bij iedere load veroorzaakt extra of herhaalde aanvragen.
- Een jaarwissel in Weekly Hours start mogelijk twee loads: OnChange jaar plus Reset week. De Trace laat zien of `Week|Start` twee keer verschijnt.
- Lokale verwerking (GroupBy/AddColumns in het rapport, LookUp-opbouw van de week) is waarschijnlijk klein ten opzichte van netwerktijd. Bevestigen met `Build|End` en `AfterLocalBuild`.
- Throttling (429) is bij deze aantallen mogelijk bij grote projecten of meerdere gelijktijdige gebruikers.

## 5. Vergelijking van oplossingen

Score: + gunstig, 0 neutraal, − nadelig. "Winst" is een schatting op basis van aanvraagaantallen totdat er metingen zijn.

| Optie | Verwachte winst | Correctheid/volledigheid | Actualiteit meerdere gebruikers | Fouten, sluiten, heropenen | Onderhoud en voorzieningen |
| --- | --- | --- | --- | --- | --- |
| 1. Betere serverfilters, minder aanvragen, indexen | + groot voor Weekly Hours en Screen1 (N+3 → 2–3 aanvragen); minder groot voor Summary zonder schemawijziging | + gelijk of beter; 500-grenzen blijven bewaakt | + altijd actueel | + ongewijzigd fail-closed | + geen nieuwe voorzieningen; indexen instellen in SharePoint (beheerder) |
| 2. Gerichte sessiecache, gecontroleerd verversen | + groot bij terugkeren en week heen en weer | 0 vereist strikte sleutels (project/team/week) en validatie; eerdere versie gaf problemen en is teruggedraaid | − toont mogelijk verouderde data tot Refresh | + bij sluiten weg (geen risico); bij fout herladen | 0 meer logica en tests |
| 3. Alleen gewijzigde records opslaan, daarna caches bijwerken | + Save week doet dit al deels (alleen gewijzigde cellen); winst vooral door per-cel LookUps te bundelen en geen volledige herlaadactie na opslaan | + mits na serverbevestiging bijgewerkt; nu al teruglezen per record | 0 conflictcontrole per record blijft nodig | + bestaande gedeeltelijke-opslagblokkade blijft | 0 beperkt |
| 4. Voorberekende weektotalen in SharePoint | + zeer groot voor Summary (1 query per periode) | − dubbele waarheid; moet bij iedere urenwijziging (ook buiten de app) worden bijgewerkt; risico op afwijkende totalen | 0 afhankelijk van bijwerkmoment | − flow/updatefout geeft stille afwijking tenzij gecontroleerd | − nieuwe lijst, flow of extra schrijfstap, reconciliatie |
| 5. Persistente lokale cache + synchronisatiewachtrij | 0/+ alleen opstarten; geen serverwinst | − hoog risico: dubbele records en conflicten zonder serverondersteuning | − verouderd tussen gebruikers en apparaten | − zie beperkingen hieronder | − complex; geen geschikte browservoorziening |

Optie 5 in de browser (Microsoft Learn, SaveData/LoadData, bijgewerkt oktober 2026):

- SaveData is in Teams en in een webbrowser beperkt tot **1 MB**.
- Data in de browser wordt **onversleuteld (plain text)** opgeslagen.
- De functies werken **niet in Power Apps Studio**.
- Gegevens zijn per app gescheiden, maar niet gegarandeerd per Power Apps-gebruiker bij hetzelfde besturingssysteemaccount.
- Opslag is per browser en apparaat, en verdwijnt bij het wissen van browsergegevens.
- Er is geen achtergrondsynchronisatie. Synchronisatie loopt alleen terwijl de app open is, via dezelfde Patch-routes.

Een betrouwbare offline wachtrij met conflictafhandeling vraagt in de praktijk Dataverse-offline, een premium functie, en dat valt buiten de randvoorwaarden. Een lokale conceptopslag van onopgeslagen invoer zou hooguit een gemak zijn, duidelijk gemarkeerd als concept en nooit in rapportage of export. Dat lost de traagheid niet op.

## 6. Aanbeveling

1. **Eerst meten** met de diagnostische build: bovenstaande scenario's, één keer met een klein en één keer met het grootste project.
2. **Daarna optie 1** als eerste verbetering. Laag risico, geen nieuwe opslag of voorzieningen, opslagbeveiliging ongewijzigd. Per punt afzonderlijk bouwen en testen:
   - Jaarbereik van Weekly Hours niet bij iedere weekwissel bepalen: eenmaal per sessie of bij expliciete Refresh. Dat zijn twee volledige Hours-sorteringen minder per wissel.
   - `Refresh()` alleen bij de expliciete Refresh-knop en na eigen opslag, niet bij iedere load.
   - Medewerkergegevens niet per teamlid opvragen. Workers eenmaal per sessie laden, met de bestaande 500-grens en foutblokkade, en lokaal opzoeken. `First(Workers)` vervalt.
   - Weekly Hours: uren per week met **één** datumfilter ophalen (`'Work Date'` binnen de week) en lokaal op Assignment-ID koppelen. Bij ≥ 500 rijen terugvallen op de huidige query per koppeling (fail-closed blijft).
   - Save week: lookup-records direct als `{Id, Value}` meegeven in plaats van `Choices(...)`. Dat bespaart aanvragen en neemt het 500-risico weg. Workers alleen opvragen voor nieuwe regels.
   - SharePoint-indexen controleren en zo nodig aanmaken (beheerder): Hours 'Work Date', Assignment, EntryKey; Project Workers Project, Team, Active, AssignmentKey.
3. **Hours Summary** blijft daarna waarschijnlijk het traagst: per koppeling meerdere queries, omdat Hours geen projectkolom heeft. Twee mogelijke vervolgstappen, alleen op basis van meetresultaten en na jouw akkoord:
   - een Project-lookupkolom op Hours. Dat is een schemawijziging, wordt bij nieuwe uren gevuld en historische regels moeten eenmalig gecontroleerd worden aangevuld;
   - of optie 2 voor alleen Hours Summary: een sessiecache per project met verplichte Refresh-knop en invalidatie na eigen opslag.

   Optie 4 alleen als ook dat onvoldoende is.
4. **Optie 5 niet uitvoeren** in de browser. Geen synchronisatieverbouwing.

Randvoorwaarden: SharePoint blijft de bron. Bestaande guards, fail-closed laden en de 500-grenzen blijven. Er komt geen succesmelding vóór serverbevestiging (Save week leest al terug). Rapportage gebruikt alleen opgeslagen gegevens.

Bronnen: [SaveData/LoadData](https://learn.microsoft.com/en-us/power-platform/power-fx/reference/function-savedata-loaddata) · [Trace](https://learn.microsoft.com/en-us/power-platform/power-fx/reference/function-trace) · [Live monitor voor canvas-apps](https://learn.microsoft.com/en-us/power-apps/maker/monitor-canvasapps) · [Live monitor overzicht](https://learn.microsoft.com/en-us/power-apps/maker/monitor-overview)
