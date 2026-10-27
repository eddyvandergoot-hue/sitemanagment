# Beveiliging (Site Management)

Bereik: Site Management canvas-app, de SharePoint-lijsten (Projects, Employers, Workers, Project Workers, Hours) en Power Automate (exportflow, nog niet gebouwd), binnen de GEA-tenant. Bouwregels staan in AGENTS.md; dit bestand is de beveiligingsbasis, geen bouwregel.

Gebruik: niet lezen tenzij de opdracht erom vraagt. Alles wat hieronder staat is voorstel of intentie totdat Eddy het bevestigt. "Eddy bevestigt" betekent: Eddy controleert het in de omgeving en meldt het; pas dan wordt de status in deze tabel aangepast. Geen tenantinstelling geldt als geverifieerd tenzij dat er expliciet bij staat. Review: voor go-live en elk kwartaal.

## WAF-checklist (Microsoft Well-Architected Framework, pijler Security)

Gebruikte indeling: SE:01 t/m SE:12 zoals bekend uit Microsoft Learn; de titels zijn kort weergegeven uit geheugen en moeten bij de eerste review met Microsoft Learn worden vergeleken. Geen enkel punt is geverifieerd in de tenant.

| Punt | Betekenis voor deze app | Status | Actie |
|---|---|---|---|
| SE:01 Baseline | GEA M365-baseline (MFA, encryptie, DLP) plus de regels in AGENTS.md. De M365-baseline is een aanname van Eddy, niet door ons gecontroleerd. | deels | Te bevestigen door IT. |
| SE:02 Veilige ontwikkelcyclus | Private git-repo, reviewer-agent, tests, SHA-256 bij elke build, goedgekeurde tags, geen secrets in de repo. | deels | GitHub 2FA: Eddy bevestigt (open). |
| SE:03 Classificatie | Label Confidential (MS-011, gepland). Data-inventaris: namen van medewerkers, telefoon, werkgever, uren. Geen ID/BSN, bankgegevens of geboortedatum. Workers bevat geen telefoon of e-mail meer; telefoons staan in de lijst Worker Contacts (alleen WorkerID + Phone; MS-012, deels gedaan, rechten open); e-mail wordt niet opgeslagen. Hours.Title bevat nu naam | datum en wordt EntryKey (gepland, DECISIONS.md D7). | open | MS-011 plannen en uitvoeren; MS-012 rechten afronden; inventaris door Eddy bevestigen. |
| SE:04 Segmentatie | Test- en productie-app gescheiden; testgegevens alleen op TEST-000. | deels | IT vragen om een aparte omgeving. |
| SE:05 Identiteit en toegang | Entra ID met MFA, least privilege, geen verwijderrechten (MS-004, gepland), tweede eigenaar, kwartaalreview van toegang. Groep "Site Supervisors" (Edit) met unieke rechten op Worker Contacts, eigenaren Full control (MS-012, gepland). | open | MS-004 uitvoeren; tweede eigenaar benoemen; eerste kwartaalreview plannen; MS-012 (groep en rechten). |
| SE:06 Netwerk | Alleen Microsoft-gehoste onderdelen (Power Apps, SharePoint, Power Automate); geen eigen netwerk. | open, te bevestigen | Eddy/IT bevestigt. |
| SE:07 Encryptie | Uitsluitend native M365-encryptie; geen eigen versleuteling in de app. | open, te bevestigen | IT bevestigt. |
| SE:08 Hardening | Least privilege op lijsten, geen verwijderrechten, vastgelegde app-eigenaren. | open, te bevestigen | Via MS-004 en eigenaarsoverzicht. |
| SE:09 Geheimen | Geen geheimen in de app (gebruikersverbindingen); nooit tokens in de repo. | deels | Eddy bevestigt; controle op tokens in de repo bij review. |
| SE:10 Monitoring | Health check (MS-007, gepland; moet ook melden: Workers.Title ongelijk aan First Name + Surname, lege Trade of Employer, lege Hours.Assignment-lookup op echte rijen: invullen of kolom laten vervallen, te beslissen) en vraag aan IT over de audit log. | open | MS-007 plannen; IT vragen naar audit log. |
| SE:11 Testen | TESTPLAN.md en een permissietest met een niet-eigenaar account (TP-SEC-01, open). | deels | TP-SEC-01 uitvoeren op TEST-000. |
| SE:12 Incidentrespons | Plan hieronder. | deels | Contactpersonen invullen; plan oefenen. |

## Dreigingen (de zes van Eddy; maatregelen zijn voorstel, Eddy bevestigt)

Maatregelen met "gepland" bestaan nog niet als MS-item in MANUAL_STEPS.md (alleen MS-001, -005, -008, -009, -010, -012 bestaan).

| # | Dreiging | Maatregelen (bestaand of voorgesteld) |
|---|---|---|
| 1 | Verkeerde toegang: te brede rechten, verkeerde mensen | Least privilege op de site en lijsten; geen verwijderrechten (MS-004, gepland); groep "Site Supervisors" (Edit) en unieke rechten op Worker Contacts, eigenaren Full control (MS-012); dataminimalisatie (telefoon en e-mail uit Workers verwijderd, telefoon in Worker Contacts); kwartaalreview van toegang |
| 2 | Verwijderen of overschrijven van uren of koppelingen | Geen verwijderrechten (MS-004, gepland); versiegeschiedenis (MS-002, gepland) en recycle bin; fail-closed Save met nul writes bij een afwijking; koppelingen worden inactief gezet, niet verwijderd (AGENTS.md); Save week wijzigt bestaande Employer/Team/Trade niet; backupflow (MS-006, gepland) |
| 3 | Dubbele records en fouten in de app | Unieke sleutels in SharePoint (MS-003, gepland; Employer Code is al uniek, MS-009; leeg gevuld door flow MS-019); EntryKey/AssignmentKey-controles en verify read na Save; reviewer, tests, TEST-000 voor opslaantests; health check (MS-007, gepland) |
| 4 | Export of bestanden gelekt | Export alleen via de generieke flow naar de bibliotheek Exports, geen automatische e-mail (nog niet gebouwd); Exports-bibliotheek met beperkte rechten; label Confidential (MS-011, gepland); DLP-beleid via IT |
| 5 | Gekaapt account | Entra ID met MFA (GEA-baseline, aanname, IT bevestigt); least privilege beperkt de schade; geen secrets in de app of repo; GitHub 2FA (open); audit log via IT; incidentplan hieronder |
| 6 | Eén eigenaar = single point of failure | Tweede eigenaar van site, app en flow (open); eigenaarsoverzicht; backupflow (MS-006, gepland); documentatie in de repo (private GitHub) |

## Incidentplan (voorstel, Eddy bevestigt)

1. Melden: wie ziet iets afwijkends meldt het direct aan Eddy (te vullen door Eddy: contactgegevens, reservecontact).
2. Indammen: rechten of verbinding intrekken, app of flow uitschakelen, niet verder opslaan; huidige stand en tijdstip vastleggen (Modified/Modified By).
3. Herstellen: versiegeschiedenis van het item, recycle bin, backup, of een eerdere app-versie; geen automatische correcties (zie AGENTS.md).
4. Datalek van persoonsgegevens: melden bij de GEA privacy officer binnen 72 uur (te vullen door Eddy: naam en contact).
5. Post-mortem: oorzaak, genomen maatregelen en een extra test in TESTPLAN.md; beslissing in DECISIONS.md.

## Open punten

- GitHub 2FA bevestigen (Eddy).
- IT-vragen: aparte omgeving voor test, audit log, DLP en labels, M365-baseline (SE:01), netwerk en encryptie (SE:06, SE:07).
- Gepland, bestaan nog niet in MANUAL_STEPS.md: MS-002 (versiegeschiedenis), MS-003 (unieke sleutels), MS-004 (geen verwijderrechten), MS-006 (backupflow), MS-007 (health check; ook Workers.Title/Trade/Employer, zie SE:10), MS-011 (label Confidential). Inhoud volgt van Eddy.
- Geen persoonsgegevens in de repo (AGENTS.md); geschiedenis kan nog oude gegevens bevatten (zie RISK_ANALYSIS.md).
- Tweede eigenaar benoemen (site, app, flow); eerste kwartaalreview van toegang plannen.
- TP-SEC-01 uitvoeren (TESTPLAN.md).
- Titels van de SE-punten vergelijken met Microsoft Learn.
- MS-012: Worker Contacts bestaat, telefoons gemigreerd, Workers.Phone/Email/Employer Code/Employer Name verwijderd (Eddy 26-10-2026). Open (onbevestigd): groep Site Supervisors en unieke rechten op Worker Contacts.
- Monitor-controle Phone/Email in het clientgeheugen: opgelost door verwijdering (de kolommen bestaan niet meer in Workers).
- De versiegeschiedenis van Workers kan nog telefoonnummers bevatten; opschonen (beslissing Eddy, open).
- Workers.Email is verwijderd (Eddy 26-10-2026); e-mail wordt niet opgeslagen.
