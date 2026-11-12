# Plan Lasstickerregister (Weld sticker register)

Status: **ontwerp, niet gebouwd** (Eddy 12-11-2026). Bouw pas na Week Report (fase C). Open vragen in par. 9 eerst beslissen.

## 1. Doel
- Uitgifteregister, geen laslog. De app registreert niet per las welke sticker is gebruikt.
- Vraag die het register moet beantwoorden: bij een probleem wordt een sticker aangewezen, dan volgt welke lasser, welke werkgever (contractor), welk project en in welke periode (uitgifte tot inname).
- Vervangt de papieren lijsten.

## 2. Stickerformaat en reeksen
- Sticker = `SSS-NNNN`: serie van 3 cijfers, nummer 0001 t/m 1000 (4 cijfers, voorloopnullen).
- Een reeks (range) = één aaneengesloten stuk van één serie, uitgegeven aan één lasser: Start No t/m End No.
- Overdracht halverwege een serie (vakantie, andere ploeg): de lopende reeks wordt gesloten met End No = laatst gebruikte nummer. De volgende uitgifte in die serie begint bij het eerste ongebruikte nummer (End No + 1).
- Ongebruikte nummers (End No + 1 t/m 1000) gaan terug naar de voorraad van die serie. Nummers onder de laatste End No worden nooit opnieuw uitgegeven; er ontstaan geen gaten.
- Serie op = laatste End No is 1000; dan geen nieuwe uitgifte in die serie.

## 3. SharePoint-lijst "Weld Sticker Ranges"
Eddy maakt de lijst (later MS-item, zie par. 8). Kolommen volgens Eddy 12-11-2026:

| Kolom | Type | Inhoud |
|---|---|---|
| Title | tekst | automatisch `SSS-NNNN-EEEE`; door de app geschreven, nooit getypt (vóór sluiten zie par. 9 V4) |
| Series | tekst (3 tekens) | `SSS`, voorloopnullen behouden; daarom tekst, geen getal |
| Start No | getal (geheel) | 1 t/m 1000 |
| End No | getal (geheel) | laatst gebruikte nummer; leeg zolang Issued, gevuld bij inname |
| Worker | lookup Workers (ID) | lasser |
| Project | lookup Projects (ID) | project van de uitgifte |
| Issued date | datum (alleen datum) | uitgiftedatum |
| Returned date | datum (alleen datum) | innamedatum; leeg zolang Issued |
| Status | keuze Issued / Closed | |
| Notes | meerdere regels tekst | vrij |

Voorgestelde extra kolommen (beslissen, par. 9):
- **WorkerKey** (tekst = Worker-ID) en **ProjectKey** (tekst = Project-ID): lookup-ID's zijn niet filterbaar (AGENTS, Delegatie). Zonder deze kolommen kan "lasser → reeksen" niet delegeerbaar.
- **Employer** (lookup Employers, momentopname bij uitgifte): net als bij Hours (historie). Zonder deze kolom toont de zoekfunctie de huidige werkgever van de lasser, en die is na een contractorwissel fout.
- **RangeKey** (tekst `SSS-NNNN` = serie + start, uniek afgedwongen, geïndexeerd): SharePoint voorkomt dan dat twee gebruikers tegelijk dezelfde start uitgeven (een app-controle alleen is geen transactie).

Indexen (online controleren): Series, Status, WorkerKey (en RangeKey door uniciteit).

## 4. App-regels (fail-closed, zelfde controle in DisplayMode en als eerste OnSelect-voorwaarde)
1. Serie = precies 3 cijfers; Start No en End No gehele getallen 1 t/m 1000.
2. Per serie hooguit één open reeks (Status Issued).
3. Nieuwe uitgifte: Start No = vorige End No + 1 binnen de serie (eerste uitgifte: 1). De app vult Start No zelf in; de gebruiker typt hem niet.
4. Geen overlap per serie: Start No > hoogste End No van alle gesloten reeksen van die serie.
5. Sluiten: End No >= Start No - 1 en <= 1000 (End No = Start No - 1 = niets gebruikt, zie par. 9 V5). Returned date >= Issued date.
6. Nooit verwijderen. Een gesloten reeks corrigeren mag alleen als het de laatste reeks van de serie is (net als inzetperiodes); anders blokkeren.
7. Uitgifte alleen aan een actieve lasser met Worker Code (field_1) en werkgever, en een niet-gesloten project.
8. Saveflow volgens het Admin screen pattern: verse pre-read van de serie (`Filter('Weld Sticker Ranges', Series = varWsSeries)`), lokale validatie vóór de eerste write, één Patch, verify read. Bij >= 500 rijen of leesfout: blokkeren. Bij afwijking sinds laden: de vaste conflictmelding.

## 5. Zoeken
- **Sticker → lasser:** invoer `SSS-NNNN` (formaat controleren). Read: `Filter('Weld Sticker Ranges', Series = <SSS>)`, lokaal de reeks met Start No <= N <= End No (gesloten) of Start No <= N (open). Resultaat: lasser (naam + Worker Code), werkgever, project (nummer + referentie), periode Issued date t/m Returned date (open: "Issued, not returned").
  - Open reeks: het nummer is uitgegeven maar nog niet als gebruikt bevestigd; dat staat zo in het resultaat.
  - Nummer boven de laatste End No zonder open reeks: "Not issued".
- **Lasser → reeksen:** lijst van alle reeksen van één lasser (`WorkerKey = <id>`), nieuwste eerst, met aantal gebruikt.
- Optioneel later: per project alle reeksen.

## 6. Innamebewijs (PDF)
- Bij sluiten: PDF via de bestaande flow "SiteManagement - Export file" (MS-029), Format pdf, TemplateName `weldsticker-receipt.html` (nieuw template in templates/, zelfde lagen als H25: template = opmaak, Translations = teksten, app = gegevens).
- Inhoud: project (nummer, naam, referentie), serie van-tot (`SSS-NNNN` t/m `SSS-EEEE`), aantal gebruikt (End - Start + 1), lasser (naam, Worker Code, vak), werkgever (naam, Contractor Code, adres), uitgifte- en innamedatum, handtekeningvakken lasser en site manager.
- Talen: zoals H24 (pagina 1 Nederlands, pagina 2 tweede taal); voorstel: tweede taal = Workers.Language van de lasser (de lasser tekent).
- Opslag: voorstel `Exports/<ProjectNumber>/WeldStickers/WeldStickerReceipt_<SSS>-<NNNN>-<EEEE>_<WorkerCode>.pdf`; TEST-projecten met voorvoegsel `TEST_` (E10).
- Optie (Eddy): hetzelfde bewijs bij uitgifte (End No dan "open", geen aantal).
- Geen CSV nodig voor het bewijs.

## 7. Scherm
- Voorstel: scrWeldStickers volgens het Admin screen pattern (cmpTitleBar, cmpMessageBar, cmpListCard, cmpField, cmpFooter). Lijst links = reeksen (regel 1 `SSS-NNNN-EEEE`, regel 2 lasser · project), formulier rechts; zoekveld bovenin voor sticker of lasser.
- Footer: Home, Issue (in plaats van New), Refresh, Discard changes, Save; bij een open reeks een actie "Return" (sluiten + bewijs).
- Home-tegel: categorie nog kiezen (par. 9 V7); eerst als Soon-tegel.
- Teksten uit T (UI Engels).

## 8. Handmatige stappen (pas na besluit, nog niet in MANUAL_STEPS.md)
- Lijst "Weld Sticker Ranges" met de definitieve kolommen, indexen en rechten.
- Translations-sleutels voor het bewijs (doc.ws.*).
- Template weldsticker-receipt.html uploaden naar Templates.
- Lijst aan de app toevoegen (Studio-save naar Incoming\), net als MS-030.

## 9. Open vragen voor Eddy
- **V1 (Eddy):** is een serie gebonden aan één project, of verplaatsbaar? Voorstel: niet gebonden; het project staat per reeks, zodat een serie naar een volgend project mee kan. Bij binding moet de app de eerste uitgifte als koppeling bewaren en een andere projectkeuze blokkeren.
- **V2:** extra kolommen WorkerKey/ProjectKey (delegatie) en Employer-momentopname (historie): akkoord?
- **V3:** RangeKey uniek afgedwongen als bescherming tegen gelijktijdige dubbele uitgifte: akkoord?
- **V4:** Title vóór sluiten: `SSS-NNNN-open`, of alleen `SSS-NNNN` en bij sluiten `SSS-NNNN-EEEE`?
- **V5:** reeks teruggeven zonder gebruik (End No = Start No - 1, aantal 0) toestaan, of moet een foute uitgifte anders worden afgehandeld?
- **V6:** nieuwe serie: alleen met expliciete bevestiging ("New series 123, start 0001"), tegen typfouten? Of eerst een aparte lijst met series?
- **V7:** Home-categorie: Inventory, Team & hours, of een nieuwe categorie (bv. Quality)?
- **V8:** wie mag uitgeven en innemen (alle app-gebruikers of alleen site managers)? Rechten op de lijst volgen daaruit.
- **V9:** bewijs ook bij uitgifte (optie) standaard aan of uit?
