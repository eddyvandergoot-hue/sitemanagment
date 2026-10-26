# Testplan (handmatige Studio-/browsertests)

Handmatige testcases voor Studio en browser; pack en lokale scripts vervangen deze niet. Status per case: open / geslaagd / mislukt, met datum en wie. Huidige testbuild: PROJECT_STATUS.md.

| Case | Onderwerp | Status | Datum | Wie |
|---|---|---|---|---|
| TP-DD-01 | Dropdown hover zichtbaar | geslaagd | 26-10-2026 | Eddy |
| TP-SAVE-01 | Savefix-controles | geslaagd | 26-10-2026 | Eddy |
| TP-LOGO-01 | Logo zichtbaar | geslaagd | 26-10-2026 | Eddy |
| TP-WEEK-01 | Weeklabel 01-01-2027 = 2026 KW53 (Weekly Hours) | geslaagd | 26-10-2026 | Eddy |
| TP-SUM-01 | Hours Summary restyle | geslaagd | 26-10-2026 | Eddy |
| TP-REUSE-01 | Hergebruik geladen selecties | open | - | - |

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

Open. Observatie Eddy 26-10-2026: gegevens komen goed terug uit de lijsten; hergebruik "lijkt ok" (indruk, geen gerichte test).
Stappen: open dezelfde project/team/week twee keer; klik Refresh; laat een andere gebruiker iets wijzigen.
Verwacht: tweede keer geen herlaad (Trace DIAG|Week|CacheHit); Refresh forceert herlaad; wijziging van de ander verschijnt pas na Refresh.
