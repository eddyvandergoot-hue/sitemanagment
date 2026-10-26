# Testplan (handmatige Studio-/browsertests)

Handmatige testcases voor Studio en browser; pack en lokale scripts vervangen deze niet. Status per case: open / geslaagd / mislukt, met datum en wie. Huidige testbuild: PROJECT_STATUS.md.

| Case | Onderwerp | Status | Datum | Wie |
|---|---|---|---|---|
| TP-DD-01 | Dropdown hover zichtbaar | geslaagd | 26-10-2026 | Eddy |
| TP-SAVE-01 | Savefix-controles | geslaagd | 26-10-2026 | Eddy |
| TP-LOGO-01 | Logo zichtbaar | geslaagd | 26-10-2026 | Eddy |
| TP-WEEK-01 | Weeklabel 01-01-2027 = 2026 KW53 (Weekly Hours) | geslaagd | 26-10-2026 | Eddy |
| TP-SUM-01 | Hours Summary restyle | geslaagd | 26-10-2026 | Eddy |
| TP-REUSE-01 | Hergebruik geladen selecties | geslaagd | 26-10-2026 | Eddy |

## TP-DD-01 dropdown hover zichtbaar

Stappen:
1. Open Screen1: de dropdowns Project en Team.
2. Open Hours Summary: de dropdowns Project en Contractor.
3. Open per dropdown de lijst en beweeg de muis over de rijen.

Verwacht:
- De rij onder de muis is lichtblauw #D5EDFF met donkere navy tekst.
- Het gekozen item is Vibrant Blue #0303B8 met witte tekst.
- Indrukken toont lichtblauw.
- Het gesloten control is lichtgrijs met een blauwe chevron.

Mislukt: meld in de browser welke rijkleuren wel zichtbaar zijn (hover, gekozen, ingedrukt). Context: PROJECT_STATUS_ARCHIVE.md.

## TP-SAVE-01 savefix

Geslaagd (Eddy, 26-10-2026: "savefix ok"). De oorspronkelijke testlijst staat in PROJECT_STATUS_ARCHIVE.md.

## TP-LOGO-01 logo zichtbaar

Stappen:
1. Open Screen1, Weekly Hours en Hours Summary.
2. Kijk links in de blauwe titelbalk.

Verwacht:
- Wit GEA-logo links in de titelbalk, scherp en niet uitgerekt, minstens 15 px vrij links/rechts.
- De titel staat na het logo en niets is afgekapt bij uw gebruikelijke venstergrootte.
- Hours Summary: de projectregel (Project Number | Project Reference) blijft leesbaar.

Mislukt: noteer scherm, vensterbreedte en wat is afgekapt.

## TP-WEEK-01 weeklabel Weekly Hours

Stappen: kies in dpHoursWeek 01-01-2027. Verwacht: lblHoursWeekKW toont `2026 KW53`.
Geslaagd (Eddy, 26-10-2026, Studio). Alleen het label is bevestigd; het OnChange-gedrag van de kiezer is niet getest.

## TP-SUM-01 Hours Summary restyle

Stappen: open Hours Summary met een rapport en bekijk de tabel.
Verwacht: zebra, "–" bij 0, totaalrij, Period total-kolom, scrollbarruimte, GEA-tabelkop.
Geslaagd (Eddy, 26-10-2026: "Hours summary restyle is ok"), visueel in Studio.

## TP-REUSE-01 hergebruik geladen selecties

Geslaagd (Eddy, 26-10-2026, Studio, goedgekeurde build logo-20261026_120726), scenario 1-7 via Monitor. Op Eddy's melding "alles werkt"; de Monitor-regels (CacheHit versus AfterHoursQueries) zijn niet afzonderlijk gemeld.
Interpretatie: alle scenario's gedragen zich zoals verwacht. Bij uren typen zonder opslaan is de weekkiezer uitgeschakeld, Refresh grijs en alleen Save actief (Eddy): dat is het ontwerp (AGENTS.md); het blokkeren gaat via uitgeschakelde controls, de melding "Niet geladen: onopgeslagen uren behouden..." is alleen een vangnet.

Setup: Studio > Advanced tools > Open monitor > Play; zoek op DIAG.

| # | Stap | Verwacht |
|---|---|---|
| 1 | Project + Team kiezen, naar Weekly Hours | laadt |
| 2 | Terug en weer naar Weekly Hours, zonder wijziging | Week\|CacheHit, geen nieuwe Hours-aanroep |
| 3 | Andere week kiezen | laadt |
| 4 | Terug naar de eerste week | laadt (cache onthoudt alleen de laatste selectie; geen fout) |
| 5 | Refresh | laadt, geen CacheHit |
| 6 | Refresh op Project / team, daarna Weekly Hours | laadt (teamversie gewijzigd) |
| 7 | Uren typen zonder opslaan | weekkiezer, Refresh en navigatie uitgeschakeld; alleen Save actief |

Niet getest: "wijziging van een andere gebruiker verschijnt pas na Refresh" (vereist TEST-000; geen echte uren wijzigen).
