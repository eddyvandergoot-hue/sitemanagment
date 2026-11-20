# Plan Certificatenregister (Certificates register)

Status: **ontwerp, niet gebouwd** (Eddy 20-11-2026, DECISIONS.md H49). Bouw na de consent-build en na het lasstickerregister (WELDSTICKERS_PLAN.md). Pas bouwen na Eddy's akkoord op dit plan.

## 1. Uitgangspunt (H49)
- **Nooit kopieën of scans opslaan.** Het certificaat blijft bij de medewerker en bij de uitgevende instantie; daar is het op te vragen. Dit vervangt het scan-deel van H39 (1).
- De app registreert alleen gegevens om het certificaat terug te vinden en de controle aan te tonen.
- Geen paspoort- of andere identiteitsgegevens (H36, dataminimalisatie).

## 2. Registratie per certificaat
| Veld | Inhoud |
|---|---|
| Worker | lookup Workers (+ WorkerKey tekst voor delegatie, zoals bij andere lijsten) |
| Type | keuze: Welding (EN ISO 9606-1), VCA, Forklift, AWP (hoogwerker), overige (lijst later vast te stellen) |
| Certificate number | tekst |
| Issuing body | tekst of lookup naar een lijst Issuing Bodies (zie par. 5) |
| Expiry date | datum (alleen datum) |
| Lassen, EN ISO 9606-1 (alleen bij Welding) | proces, materiaalgroep, producttype, dikte-/diameterbereik, lasposities (velden later exact vast te stellen) en de bevestiging elke 6 maanden (datum laatste bevestiging, door wie) |

## 3. Echtheidscontrole (authenticity check)
| Veld | Inhoud |
|---|---|
| Verified | ja/nee |
| Method | keuze: Online register / Phone / Email / Visual only |
| Verified by | persoon (wie controleerde) |
| Verified on | datum |
| Note | tekst (verplicht bij Visual only) |

Regels (fail-closed):
- **Lascertificaat:** controle bij de uitgevende instantie is **verplicht** voordat de registratie geldig is (Method = Online register, Phone of Email; Visual only is niet genoeg). Pas dan mogen lasstickers aan deze lasser worden uitgegeven (controle bij uitgifte, zie WELDSTICKERS_PLAN.md par. 10).
- **Overige certificaten:** controle aanbevolen; Visual only toegestaan, maar alleen met een notitie.
- Verlopen (Expiry date in het verleden) of zonder geldige 6-maandsbevestiging = niet geldig; de app toont dat, en bij lassen blokkeert het de stickeruitgifte.

## 4. Controlebronnen (ontwerphints, bij het ontwerp per bron op de officiële site bevestigen)
- **VCA:** centraal diplomaregister (CDR), online te raadplegen.
- **Lassen EN ISO 9606-1:** de uitgevende of aangemelde instantie (bijvoorbeeld TÜV, Lloyd's, Kiwa, Bureau Veritas): online controle of per mail/telefoon.
- **Heftruck / hoogwerker (AWP):** geen centraal register; controleren bij de opleider of alleen visueel (met notitie).
- Deze bronnen zijn nog niet tegen de officiële sites gecontroleerd; dat gebeurt bij het detailontwerp en wordt met de URL vastgelegd.

## 5. Uitgevende instanties
- Optionele lijst Issuing Bodies: naam, type(s) certificaat, en per instantie een **linkveld naar de online controlepagina**. De app toont die link bij de controle (Launch alleen bij klik).

## 6. Toegang en bewaartermijn
- **Beperkte toegang:** alleen site managers lezen en schrijven (SharePoint-rechten op de lijst; de app toont geen fout bij geen toegang, net als Worker Contacts).
- **Bewaartermijn:** vast te stellen met Eddy/HSE (voorstel: zolang de medewerker actief is plus een termijn daarna, en minstens zolang lasstickers van deze lasser in het stickerregister naar het certificaat verwijzen). Verwijderen alleen volgens dat beleid, nooit door de app.

## 7. Open vragen voor Eddy
- **C1:** definitieve lijst certificaattypen.
- **C2:** exacte EN ISO 9606-1-velden die geregistreerd moeten worden.
- **C3:** Issuing Body als vrije tekst of als lijst met controlelink.
- **C4:** bewaartermijn en wie hem goedkeurt (HSE?).
- **C5:** wie mag registreren en controleren (alleen site managers, of ook project leaders)?
