# Beveiliging (Site Management)

Bereik: Site Management canvas-app, de SharePoint-lijsten (Projects, Employers, Workers, Project Workers, Hours) en Power Automate (exportflow, nog niet gebouwd), binnen de GEA-tenant. Bouwregels staan in AGENTS.md; dit bestand is de beveiligingsbasis, geen bouwregel.

Gebruik: niet lezen tenzij de opdracht erom vraagt. Alles wat hieronder staat is voorstel of intentie totdat Eddy het bevestigt. "Eddy bevestigt" betekent: Eddy controleert het in de omgeving en meldt het; pas dan wordt de status in deze tabel aangepast. Geen tenantinstelling geldt als geverifieerd tenzij dat er expliciet bij staat. Review: voor go-live en elk kwartaal.

## WAF-checklist (Microsoft Well-Architected Framework, pijler Security)

Gebruikte indeling: SE:01 t/m SE:12 zoals bekend uit Microsoft Learn; de titels zijn kort weergegeven uit geheugen en moeten bij de eerste review met Microsoft Learn worden vergeleken. Geen enkel punt is geverifieerd in de tenant.

| Punt | Betekenis voor deze app | Status | Actie |
|---|---|---|---|
| SE:01 Baseline | GEA M365-baseline (MFA, encryptie, DLP) plus de regels in AGENTS.md. De M365-baseline is een aanname van Eddy, niet door ons gecontroleerd. | deels | Te bevestigen door IT. |
| SE:02 Veilige ontwikkelcyclus | Private git-repo, reviewer-agent, tests, SHA-256 bij elke build, goedgekeurde tags, geen secrets in de repo. | deels | GitHub 2FA: Eddy bevestigt (open). |
| SE:03 Classificatie | Label Confidential (MS-011, gepland). Data-inventaris: namen van medewerkers, telefoon, werkgever, uren. Geen ID/BSN, bankgegevens of geboortedatum. | open | MS-011 plannen en uitvoeren; inventaris door Eddy bevestigen. |
| SE:04 Segmentatie | Test- en productie-app gescheiden; testgegevens alleen op TEST-000. | deels | IT vragen om een aparte omgeving. |
| SE:05 Identiteit en toegang | Entra ID met MFA, least privilege, geen verwijderrechten (MS-004, gepland), tweede eigenaar, kwartaalreview van toegang. | open | MS-004 uitvoeren; tweede eigenaar benoemen; eerste kwartaalreview plannen. |
| SE:06 Netwerk | Alleen Microsoft-gehoste onderdelen (Power Apps, SharePoint, Power Automate); geen eigen netwerk. | open, te bevestigen | Eddy/IT bevestigt. |
| SE:07 Encryptie | Uitsluitend native M365-encryptie; geen eigen versleuteling in de app. | open, te bevestigen | IT bevestigt. |
| SE:08 Hardening | Least privilege op lijsten, geen verwijderrechten, vastgelegde app-eigenaren. | open, te bevestigen | Via MS-004 en eigenaarsoverzicht. |
| SE:09 Geheimen | Geen geheimen in de app (gebruikersverbindingen); nooit tokens in de repo. | deels | Eddy bevestigt; controle op tokens in de repo bij review. |
| SE:10 Monitoring | Health check (MS-007, gepland) en vraag aan IT over de audit log. | open | MS-007 plannen; IT vragen naar audit log. |
| SE:11 Testen | TESTPLAN.md en een permissietest met een niet-eigenaar account (TP-SEC-01, open). | deels | TP-SEC-01 uitvoeren op TEST-000. |
| SE:12 Incidentrespons | Plan hieronder. | deels | Contactpersonen invullen; plan oefenen. |

## Dreigingen (voorstel, Eddy bevestigt)

| # | Dreiging | Maatregelen |
|---|---|---|
| 1 | Onbedoeld of kwaadwillend wijzigen of verwijderen van uren en koppelingen in SharePoint | Geen verwijderrechten (MS-004), versiegeschiedenis, Save-validatie, fail-closed opslaan, inactief zetten in plaats van verwijderen |
| 2 | Misbruik van brede rechten, te veel eigenaren | Least privilege, tweede eigenaar, kwartaalreview van toegang |
| 3 | Datalek van persoonsgegevens (namen, telefoon, werkgever) via export of delen | Labels en DLP (MS-011, IT), export alleen via de gecontroleerde flow, geen automatische e-mail |
| 4 | Fouten door testen op echte gegevens | TEST-000, op echte projecten alleen leescontroles, TEST-uitsluiting in rapporten (gepland) |
| 5 | Onbetrouwbare app-wijzigingen, supply chain | Private repo, reviewer, tests, SHA-controle, goedgekeurde tags, geen onbekende controls |
| 6 | Verlies van gegevens of beschikbaarheid | Versiegeschiedenis, recycle bin, backup, herstel van een eerdere app-versie |

## Incidentplan (voorstel, Eddy bevestigt)

1. Melden: wie ziet iets afwijkends meldt het direct aan Eddy (te vullen door Eddy: contactgegevens, reservecontact).
2. Indammen: rechten of verbinding intrekken, app of flow uitschakelen, niet verder opslaan; huidige stand en tijdstip vastleggen (Modified/Modified By).
3. Herstellen: versiegeschiedenis van het item, recycle bin, backup, of een eerdere app-versie; geen automatische correcties (zie AGENTS.md).
4. Datalek van persoonsgegevens: melden bij de GEA privacy officer binnen 72 uur (te vullen door Eddy: naam en contact).
5. Post-mortem: oorzaak, genomen maatregelen en een extra test in TESTPLAN.md; beslissing in DECISIONS.md.

## Open punten

- GitHub 2FA bevestigen (Eddy).
- IT-vragen: aparte omgeving voor test, audit log, DLP en labels, M365-baseline (SE:01), netwerk en encryptie (SE:06, SE:07).
- MS-011 (label Confidential), MS-004 (geen verwijderrechten), MS-007 (health check): gepland, bestaan nog niet in MANUAL_STEPS.md.
- Tweede eigenaar benoemen; eerste kwartaalreview van toegang plannen.
- TP-SEC-01 uitvoeren (TESTPLAN.md).
- Titels van de SE-punten vergelijken met Microsoft Learn.
