# Risicoregister (Site Management)

Aanvulling op SECURITY.md. Niet lezen tenzij de opdracht erom vraagt. Alles hieronder is voorstel totdat Eddy bevestigt; geen enkel punt is geverifieerd. Zonder kans/impact-scores.

| ID | Risico | Gerelateerd besluit/MS | Maatregel | Status |
|---|---|---|---|---|
| R1 | Telefoon (en mogelijk e-mail, als Workers.Email data bevat) staat in Workers, zichtbaar voor iedereen met leestoegang | DECISIONS.md D7, MS-012 | Aparte lijst Worker Contacts (alleen WorkerID + Phone) met unieke rechten (eigenaren Full control, Site Supervisors Edit); kolom Phone uit Workers verwijderen; Workers.Email controleren en zo nodig legen/verwijderen | gepland |
| R2 | De versiegeschiedenis van Workers bevat nog telefoonnummers | MS-012 | Opschonen na MS-012 (beslissing Eddy) | open |
| R3 | De app laadt mogelijk volledige Workers-rijen incl. kolommen Phone/Email (indien gevuld) in het clientgeheugen (de app gebruikt ze niet) | MS-012 | Controleren in Studio Monitor; kolom verwijderen/verplaatsen | open |
| R4 | Hours.Title dupliceert naam + datum (persoonsgegevens) | DECISIONS.md D7 | Title = EntryKey voor nieuwe/bijgewerkte rijen, bij de volgende Save-taak; bestaande rijen: open beslissing | gepland |
| R5 | E-mail zonder concreet gebruik | MS-012 | E-mail wordt niet opgeslagen (Eddy 26-10-2026); bestaande Workers.Email: zie R1/MS-012 | besloten: e-mail wordt niet opgeslagen |
| R6 | Overige dreigingen (wijzigen/verwijderen, brede rechten, datalek, testfouten, supply chain, verlies) | SECURITY.md, dreigingen 1-6 | Zie SECURITY.md; hier niet gedupliceerd | verwijzing |
