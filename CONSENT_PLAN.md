# Consent agreement: plan (app-versie van FOR-010.040)

Stand 18-11-2026. Ontwerp, niet gebouwd. Besluiten: DECISIONS.md H36, H37 en **H40**. H40 vervangt de lijst Customers, onderdeel A (ProjectSafety) en de lijst ConsentAgreements. Bouw na MS-047 + metadata-save.

**H40 in het kort:** klant = Projects.CustomerName + CustomerCity + CustomerPhone; VGM-toezichthouder = Projects.SiteManagers (naam) + SupervisorPhone; status per project + medewerker op Project Workers (ConsentStatus Not generated / Generated / Signed, ConsentDate). Scherm: medewerkers van het projectteam, status, Generate per medewerker of alle, Signed handmatig. Veiligheidsplan deel 1 hoort niet bij de app. Waar hieronder Customers, ProjectSafety of ConsentAgreements staat, geldt H40.

Oorspronkelijk besluit: DECISIONS.md H36. Achtergrond: EXCEL_MIGRATION.md 3.1 (de huidige Excel/Acrobat-route) en onderdeel C.

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
4. **Klant (H38):** naam, plaats en telefoon uit de lijst Customers, via de lookup Customer op het project.
5. **Project:** projectnummer en VGM-toezichthouder (Projects.SiteManagers; de telefoon volgt uit onderdeel A).
6. **Introductiechecklist:** de 13 punten van het origineel (`consent.intro*`), waarbij het ID-punt is vervangen door `consent.idShown`, plus de twee vrije regels van het origineel als lege regels (H38, geen tekst).
7. **PBM:** de punten van het origineel (`consent.ppe*`).
8. **Opmerkingen:** een leeg vak.
9. **Handtekening (H38):** naam, datum en "Handtekening:" (neutraal label). Eddy laat tekenen in Adobe (Fill & Sign, touch of getypt); op papier werkt het label ook.
10. **Voettekst** per pagina: `consent.footer`.

De exacte teksten en de volgorde van checklist en PBM komen uit Eddy's voorbeeld-PDF's per taal (`Incoming\Examples\Forms\`, gitignored; H37). Die zijn alleen een voorbeeld van de huidige werkwijze; de app wordt app-eigen gebouwd met HTML-template, Translations en de export-flow. De vaste teksten worden letterlijk overgenomen, met de wijzigingen van H36. Een ontbrekende taal wordt vertaald vanuit NL; de voettekst krijgt dan "unofficial translation" en de taal komt in de backlog voor moedertaalcontrole. Er komen geen namen of persoonswaarden uit de voorbeelden in de repo.

## 4. Techniek (volgens het Week Report-patroon)

- **Template:** HTML `templates/consent.html` in de bibliotheek Templates (Arial, GEA-palet, logo als base64). De app stuurt alleen pagina's met gegevens en vertaalde teksten.
- **Flow:** de bestaande "SiteManagement - Export file" (Format pdf, TemplateName consent.html). Er komt geen nieuwe flow.
- **Taal (H37, V11 beantwoord):** alleen één PDF in de taal van de medewerker (Workers.Language): het ondertekende document. Geen kopie in de primaire rapporttaal. Een ontbrekende tekst betekent geen PDF en een rode melding (zoals H28).
- **Bestand:** `[TEST_]Consent_<ProjectNumber>_<WorkerCode>_<taalcode>_UNSIGNED.pdf` in Exports/<ProjectNumber>/Consent/. Er komt geen naam in de bestandsnaam: de Worker Code volstaat (dataminimalisatie).
- **Registratie:** lijst ConsentAgreements (onderdeel C van EXCEL_MIGRATION; kolommen bij de bouw als .xlsx).
- **Veiligheidsplan deel 1:** zat in Excel in hetzelfde pakket. Volgt als apart ontwerp, met de gegevens van onderdeel A.

## 5. Teksten (compleet 17-11-2026)

- **Bestand:** `templates/translations-consent.csv` bevat 90 sleutels `consent.*` × 9 talen = 810 regels. Plakbestanden: `-8.csv` (720 regels) en `-be.csv` (90 regels), zie MS-042.
- **Bron:**
  - NL, PL, UK en BE komen letterlijk uit de voorbeeldformulieren (`Incoming\Examples\Forms\Declaration_Of_Consent_<NL|PL|UA|BY>_Editable.pdf`; alleen vaste teksten, geen ingevulde waarden).
  - EN, CS, RO, DE en FR zijn vertaald vanuit NL, met "unofficial translation" (in de eigen taal) in de voettekst.
  - Al het niet-Nederlandse moet nog door een moedertaalspreker gecontroleerd worden (backlog).
- **Sleutels (volgorde = het document):**
  - **Kop en voet:** formsLabel, title, footer.
  - **Medewerker:**
    - secWorker, lblName, lblRole;
    - lblWorkerType met optGpbe / optThirdParty (keuze "Werknemer: GPBE / Derden").
  - **Werkgever:** secEmployer, lblOrgName, lblAddress, lblPostcodeCity, lblPhone.
  - **Klant/project:** secCustomer, lblCity, lblProjectNumber, lblSupervisor.
  - **Introductie:**
    - kop secIntro;
    - 13 punten: introSiteTour, introWork, introSafetyPlan1, introSafetyRules2, introCustomerRules, introFireEscape, introAlarmNumbers, introPpeChecklist, **idShown**, introA1, introLimosa, introLmra, introVca.
  - **PBM-tabel:**
    - kop en kolommen: secPpe, ppeColPpe/Protection/Application/YesNo;
    - ppeSecEmployer, gevolgd door 15 regels ppe<X> + ppe<X>Use: Helmet, BumpCap, Shoes, Goggles, Gloves, WeldingHelmet, Earplugs, Earmuffs, Workwear, FrClothing, HiVis, Jacket, Training, FirstAid, Extinguisher;
    - beschermingswaarden prot*: Head, Feet, Eyes, Hands, Ears, Body, Environment;
    - ppeSecGea, met ppeOverall, lblQuantity en lblSize.
  - **Opmerkingen:** secRemarks, remark1-6.
  - **Handtekening:** secSignature, signatureStatement, lblName, lblDate, lblSignature.
- **H36 toegepast:**
  - Geen labels voor het woonadres, de postcode/woonplaats en de telefoon van de medewerker. lblAddress, lblPostcodeCity en lblPhone horen alleen bij werkgever en klant.
  - idShown vervangt "Kopie paspoort/ID ingeleverd".
  - De voettekst is de app-versie.
## 6. Open vragen
- **V11** — beantwoord 17-11-2026 (H37): alleen de taal van de medewerker.
- **V5** (EXCEL_MIGRATION): ondertekenen in Adobe (H38). Nog open: wie ontvangt het getekende pakket en hoe lang wordt het bewaard?
- **V4** — beantwoord 17-11-2026 (H38): lijst Customers.
- **V6** — beantwoord 17-11-2026 (H37): Belarusian wordt 9e taal (MS-043).
- **Handtekeninglabel** — beantwoord 17-11-2026 (H38): neutraal "Handtekening:" in alle talen.
- **Extra introductieregels** — beantwoord 17-11-2026 (H38): ja, als twee lege regels.
