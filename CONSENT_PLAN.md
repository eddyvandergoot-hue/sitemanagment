# Consent agreement: plan (app-versie van FOR-010.040)

Stand 17-11-2026. Ontwerp, niet gebouwd. Besluit: DECISIONS.md H36. Achtergrond: EXCEL_MIGRATION.md 3.1 (de huidige Excel/Acrobat-route) en onderdeel C.

## 1. Uitgangspunt (H36, Eddy 17-11-2026)

- De app maakt een eigen versie van het gecontroleerde GEA-formulier FOR-010.040 (20-03-2023). Daarbij past ze nu al AVG-dataminimalisatie toe.
- Er is geen HSE-goedkeuring vooraf. GEA HSE geeft feedback als Eddy de app presenteert; dat staat in de backlog.
- Alle teksten komen uit de lijst Translations (sleutels `consent.*`). Zo kan een tekst teruggezet worden, of het officiële formuliernummer terugkomen, door alleen de lijst te bewerken; er is dan geen build nodig.

## 2. Wijzigingen ten opzichte van FOR-010.040

| Onderdeel | Origineel | App-versie |
|---|---|---|
| Woonadres, postcode/plaats en telefoon van de medewerker | Velden op het formulier | **Verwijderd**: niet opgeslagen en niet afgedrukt (Workers bevat ze bewust niet, D7) |
| Checklistpunt identiteit | "Kopie paspoort/ID ingeleverd" | **"Paspoort/ID getoond"** (`consent.idShown`): het document wordt bekeken, er wordt geen kopie bewaard |
| Voettekst | Formuliernummer en datum | `consent.footer`: "GEA INTERNAL \| based on FOR-010.040 (20-03-2023) \| app version \| <taal> version \| Page {page} of {pages}", vertaald per taal |
| Al het andere | | **Gelijk** aan het origineel: werkgever, klant, project, VGM-toezichthouder, introductiechecklist, PBM, opmerkingen, handtekening |

## 3. Opbouw van het document (structuur gelijk aan het origineel)

1. **Kop:** GEA-logo (officieel bestand), titel (`consent.title`) en taal.
2. **Medewerker:** naam (First Name + Surname) en functie (Workers.Trade, volledig uitgeschreven). Geen adres en geen telefoon.
3. **Werkgever (contractor):** naam, adres, postcode/plaats en telefoon uit Employers.
4. **Klant:** naam, plaats en telefoon. De bron volgt uit V4 van EXCEL_MIGRATION: klantvelden op Projects of een lijst Customers.
5. **Project:** projectnummer en VGM-toezichthouder (Projects.SiteManagers; de telefoon volgt uit onderdeel A).
6. **Introductiechecklist:** de punten van het origineel als `consent.check*`-sleutels, waarbij het ID-punt is vervangen door `consent.idShown`.
7. **PBM:** de punten van het origineel (`consent.ppe*`).
8. **Opmerkingen:** een leeg vak.
9. **Handtekening:** medewerker (naam en datum) en GEA (toezichthouder en datum). De lijnen zijn leeg en worden met de hand getekend (V5 open).
10. **Voettekst** per pagina: `consent.footer`.

De exacte teksten en de volgorde van checklist en PBM komen uit het officiële formulier FOR-010.040. Eddy levert de tekst in alle talen (PDF of Word); Claude zet ze om naar CSV voor Translations. Daar worden geen teksten verzonnen.

## 4. Techniek (volgens het Week Report-patroon)

- **Template:** HTML `templates/consent.html` in de bibliotheek Templates (Arial, GEA-palet, logo als base64). De app stuurt alleen pagina's met gegevens en vertaalde teksten.
- **Flow:** de bestaande "SiteManagement - Export file" (Format pdf, TemplateName consent.html). Er komt geen nieuwe flow.
- **Taal:** Workers.Language van de medewerker. Of er ook een PDF in de primaire taal bij moet, is nog open (V11). Een ontbrekende tekst betekent geen PDF en een rode melding (zoals H28).
- **Bestand:** `[TEST_]Consent_<ProjectNumber>_<WorkerCode>_<taalcode>_UNSIGNED.pdf` in Exports/<ProjectNumber>/Consent/. Er komt geen naam in de bestandsnaam: de Worker Code volstaat (dataminimalisatie).
- **Registratie:** lijst ConsentAgreements (onderdeel C van EXCEL_MIGRATION; kolommen bij de bouw als .xlsx).
- **Veiligheidsplan deel 1:** zat in Excel in hetzelfde pakket. Volgt als apart ontwerp, met de gegevens van onderdeel A.

## 5. Teksten

- **Al geleverd:** `templates/translations-consent.csv` met `consent.idShown` en `consent.footer` in 9 talen: de 8 app-talen plus Belarusian.
- **Moedertaalcontrole:** alle talen behalve Dutch en English moeten nog door een moedertaalspreker gecontroleerd worden. Dat staat in de backlog bij de bestaande vertaalcontrole.
- **Belarusian** is nog geen keuze in Translations.Language. Plak de 2 Belarusian-regels pas na de procedure "Nieuwe taal" (MANUAL_STEPS; V6).
- **Nog te leveren:** de overige `consent.*`-sleutels (titel, sectiekoppen, checklist, PBM, handtekeningregels). Die komen uit het officiële formulier (zie 3).

## 6. Open vragen
- **V11:** alleen een PDF in de taal van de medewerker, of ook in de primaire rapporttaal (zoals het Week Report)?
- **V5** (EXCEL_MIGRATION): ondertekenen op papier met een scan uploaden, of digitaal? En wie ontvangt het getekende pakket?
- **V4** (EXCEL_MIGRATION): de bron van de klantgegevens.
- **V6** (EXCEL_MIGRATION): Belarusian als 9e taal. Dit besluit gaat daarvan uit.
- **Bron:** de originele FOR-010.040-teksten in alle talen (Eddy).
