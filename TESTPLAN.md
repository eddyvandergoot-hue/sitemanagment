# Testplan (handmatige Studio-/browsertests)

Handmatige testcases voor Studio en browser; pack en lokale scripts vervangen deze niet. Status per case: open / geslaagd / mislukt, met datum en wie. Huidige testbuild: PROJECT_STATUS.md.

| Case | Onderwerp | Status | Datum | Wie |
|---|---|---|---|---|
| TP-DD-01 | Dropdown hover zichtbaar | open | - | - |
| TP-SAVE-01 | Savefix-controles | open | - | - |
| TP-LOGO-01 | Logo zichtbaar | open | - | - |

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

Mislukt: meld in de browser welke rijkleuren wel zichtbaar zijn (hover, gekozen, ingedrukt). Context en alternatief: PROJECT_STATUS.md (Dropdownbuild).

## TP-SAVE-01 savefix

Zie PROJECT_STATUS.md, Studio-testlijst.

## TP-LOGO-01 logo zichtbaar

Stappen:
1. Open Screen1, Weekly Hours en Hours Summary.
2. Kijk links in de blauwe titelbalk.

Verwacht:
- Wit GEA-logo links in de titelbalk, scherp en niet uitgerekt, minstens 15 px vrij links/rechts.
- De titel staat na het logo en niets is afgekapt bij uw gebruikelijke venstergrootte.
- Hours Summary: de projectregel (Project Number | Project Reference) blijft leesbaar.

Mislukt: noteer scherm, vensterbreedte en wat is afgekapt.
