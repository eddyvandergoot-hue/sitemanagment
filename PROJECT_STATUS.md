# Projectstatus (huidige stand, 9-11-2026)

Geschiedenis en eerdere builds: PROJECT_STATUS_ARCHIVE.md (niet lezen tenzij gevraagd; daar staat ook het op 9-11-2026 verplaatste detail: oudere beperkingen, Studio-bewijs, incident lege Employers-records, MS-detail). Volgorde van open punten: NEXT_COMMANDS.md. Open beslissingen: ROADMAP.md. Handmatige stappen: MANUAL_STEPS.md. "Gebouwd" = aantoonbaar in Src; dat zegt niets over Studio-import of functionele test.

Er is nog geen productieapp; er zijn alleen testimports, bewust, tot de functies compleet zijn.

## Goedgekeurde baseline
- Approved by Eddy 9-11-2026: Workers-scherm (scrWorkers), H18 in Save week (stale-cachecheck), 5.6 (Home/Screen1 Weekly Hours-guard), Projects "Country unknown", Language-fix. Studio-hertest TP-WORKERS-01 op build workers-langfix-20261109_131247 (C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\workers-langfix-20261109_131247\SiteManagement_Workers_LangFix_20261109_131247.msapp, 174071 bytes, SHA-256 BA8107BA26B74F4F07D046E7A09829EE4BD541045E8DE0FC9234807D319A07A2): g en h OK; eerder 8-11-2026 a-f, i-m, o-q OK; r (Monitor-delegatie) open, niet blokkerend. Tag approved-20261109-workers (Src gelijk aan 8c1ccf4); vervangt approved-20261107-contractoraddr (build contractoraddr-20261104_221534, Src 9d64acf). Layout-freeze actief (DECISIONS.md H23).
- Language: SharePoint-keuzes Dutch, English, Polish, Romanian, German, Ukrainian; standaard Dutch (Eddy 9-11-2026); de metadata in de .msapr toont nog "English" (niet ververst; de app rekent er niet op). Bekend: de code controleert voor de New-standaard eerst "Nederlands" (bestaat niet) en dan "Dutch"; opruimen bij de eerstvolgende Workers-wijziging.
- Testprojecten: TEST-000 (MS-005, opslaan toegestaan) en TEST-001 (Active = Nee; alleen-lezen, voor "geen periodes en geen uren"). TEST-regel Week Report/exports: AGENTS.md (Werkwijze), DECISIONS.md E10.

## Huidige build
- Week Report fase A gebouwd 9-11-2026: scrWeekReport (alleen-lezen), cmpReportFooter, Home-tegel actief, TEST-regel, codefallbacks EMP-/WKR-<ID>, rapporttaal = meerderheid Workers.Language (legacy "Nederlands" telt als Dutch), fail-closed gegevenscontroles. TESTBUILD: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\weekreport-a-20261109_203719\SiteManagement_WeekReportA_20261109_203719.msapp, 186666 bytes, SHA-256 6A8D56DF8B499D8478CF957E50849B7CAF950758183556ECE866F239D0F6C35C. Technisch gecontroleerd: 15 checks PASS (incl. nieuw Test-WeekReport), pack OK, reviewer geen blokkerende bevindingen (ook sleutelcontroles: koppelingssleutel, volledige EntryKey, periodes zonder koppeling/From blokkeren); NIET Studio-getest; volgende stap: Eddy Studio-test TP-WEEKREPORT-01 (TESTPLAN.md). Geen export in fase A.
- Na fase A: Week Report-export (fase B/C), plan WEEKREPORT_PLAN.md goedgekeurd (Eddy 9-11-2026).
- Bekende beperkingen Workers-build (vastgelegd, niet blokkerend): (a) medewerker die bij het laden van de week al inactief is in Workers: Save van een nieuwe dag toont elke keer de algemene conflictmelding (nul writes; trace Reason Inactive); (b) PW Active=false met open periode wordt door de deactiveringscheck niet gezien (V1-gat); (c) de telling "actieve medewerkers" op Contractors is na een Workers-save verouderd tot Refresh op Contractors; (d) laadfouttekst van de workercache op Weekly Hours is Nederlands (UX-ronde 4b); (e) Home-tegel Weekly hours meldt "Choose project and team first" ook als alleen de caches verouderd zijn; (f) na een H18-conflict blijft varMastersReady false tot Project / team herlaadt (fail-closed). Overige oudere beperkingen (Savefix, Discard, smalle vensters, Home, datumkiezer): archief.
- Alleen in Studio te controleren: Patch {Until: Blank()} wist de datum; JSON() van projecties; Sort op ID/Modified (delegatie); gedrag ModernDatePicker bij wijzigen van StartDate/EndDate tijdens Reset.

## Prioriteit (Eddy 4-11-2026, DECISIONS.md H23)
Doel = documentgeneratie. Volgorde: (1) GEDAAN: contractoraddr goedgekeurd 7-11-2026, tag approved-20261107-contractoraddr; (2) layout-freeze ACTIEF (cosmetica alleen via de backlog hieronder); (3) GEDAAN: Workers-scherm goedgekeurd 9-11-2026, tag approved-20261109-workers; (4) Week Report + PDF/CSV-export: plan goedgekeurd door Eddy 9-11-2026 (WEEKREPORT_PLAN.md), fase A gebouwd 9-11-2026, Studio-test open; (5) toegankelijkheidsronde + N2/N5. Details: NEXT_COMMANDS.md.

## Backlog cosmetica
- Veld Report Language op het Contractors-scherm (na MS-027).
- Native-speaker-controle van de vertalingen (Translations) vóór livegang.
- GEA-logo als PNG (officieel bestand uit de logobank) is nodig vóór fase C (PDF).
- Home-tegel Tab-focus (TP-HOME-03 punt 6; geen prioriteit).
- Optie "Worker Code direct na aanmaken": de app schrijft WKR-<ID> meteen na het aanmaken; flow MS-017 blijft terugval (nu verschijnt de code na ongeveer 1 minuut). Botst met de AGENTS-regel "de app schrijft Worker Code nooit" en met de uniciteit van field_1; vereist Eddy's besluit en een formaatcontrole tegen flow MS-017 vóór bouw.
- UX 4b, Weekly Hours: een mislukte Save toont de melding twee keer (Notify + rode statusregel lblWeekLoadStatus; TP-WORKERS-01 o). Eddy's keuze 9-11-2026: eenmeldingsregel, alleen Notify; de statusregel toont alleen de laadstatus. Niet nu (layout-freeze). Bij die fix wijzigen ook: Test-SaveRegression.ps1 en Test-GeaColors.

## Open items
- Functionele Studio-tests van niet-geteste onderdelen (o.a. weekkiezer-dagwissel, fail-closed blokkades, Monitor-delegatie, wijziging door een andere gebruiker na Refresh met TEST-000); Discard Monitor-spoor en Failed-tak (TEST-000).
- Later, niet blokkerend: App checker-meldingen (toegankelijkheid, ongebruikte variabelen, WarnLiteralPredicate); Src en Check-WeeklySource uitlijnen op ModernDatePicker@1.0.2 (NEXT_COMMANDS.md 2b); opslagsnelheid Save week/team niet expliciet bevestigd.
- Jaargrens/week 53 in Hours Summary alleen lokaal getest; natuurlijk testmoment ISO-week 53 van 2026 (28-12-2026 t/m 03-01-2027). Geen testuren in gedeelde lijsten zetten.
- Open punt: komen medewerkers met periodetotaal 0 in de CSV-export voor? (CSV-regel E2/E8: totaal 0 vervalt.)
- TEST-exclusie: Week Report laat TEST-projecten kiesbaar, exportbestanden krijgen prefix TEST_, TEST Employer-regels vervallen bij echte projecten (DECISIONS.md E10, gebouwd bij fase A-C); Hours Summary-export en health check sluiten TEST-projecten/TEST Employer uit (niet geïmplementeerd).
- SECURITY.md aangemaakt (WAF SE-checklist); open: GitHub 2FA bevestigen, IT-vragen, MS-004/007/011 (gepland; MS-007 meldt ook: Workers.Title ongelijk aan First Name + Surname, lege Trade of Employer, lege Hours.Assignment-lookup op echte rijen: invullen of kolom laten vervallen, te beslissen), TP-SEC-01.
- Volgende UX-ronde Project / team (besloten, niet gebouwd; details NEXT_COMMANDS.md 4b): Screen1-kaarten tonen Title (H10); inline oranje kaartstatus; samenvattingspopup vóór Save team; migratiepopup en knoppen "Eenmalige omzetting: bekijken/uitvoeren"; optie B uitvinken (H11); live validatie; meldingen volgens H17; ddTeam-optie "Alle teams" (gedrag te beslissen bij de bouw); guard: medewerker met Title die met "Test " begint alleen aan TEST-000.
- Export (PDF + CSV, generieke flow): niet gebouwd; spec in AGENTS.md, plan WEEKREPORT_PLAN.md.
- Dataminimalisatie (DECISIONS.md D7): MS-012 deels gedaan (Worker Contacts bestaat, telefoons gemigreerd, Workers.Phone/Email verwijderd); open: groep Site Supervisors, unieke rechten, opschonen versiegeschiedenis; besluit Hours.Title = EntryKey (bij volgende Save-taak) en of bestaande rijen blijven staan.
- Geen lege ProjectKey in Project Workers: controle niet gemeld, blijft relevant (Save team-risico).
- Verwijderen van artifacts\Logo_download\20261026-Sitemanagment_logo.msapp (read-only SAS-token verlopen 27-10-2026; lokaal, gitignored) mag door Eddy.

## Open MS-items (MANUAL_STEPS.md)
- Open (Eddy, 9-11-2026): MS-027 (Employers Report Language), MS-028 (lijst Translations), MS-029 (flow "SiteManagement - Export file"), MS-030 (flow in de app). Bibliotheek Exports: gedaan 9-11-2026.
- MS-012 (Worker Contacts): deels gedaan; open: groep Site Supervisors + unieke rechten + opschonen versiegeschiedenis Workers. MS-021 (rechten Site Supervisors): uitgesteld tot go-live.
- Gedaan (details MANUAL_STEPS.md): MS-005/009/010/013-020/022/025/026. Employer Code: flow MS-019 vult "EMP-" + ID; Worker Code: flow MS-017 vult "WKR-" + ID.
