# Projectstatus (huidige stand, 27-10-2026)

Geschiedenis en eerdere builds: PROJECT_STATUS_ARCHIVE.md (niet lezen tenzij gevraagd). Volgorde van open punten: NEXT_COMMANDS.md. Open beslissingen: ROADMAP.md. Handmatige stappen: MANUAL_STEPS.md. "Gebouwd" = aantoonbaar in Src; dat zegt niets over Studio-import of functionele test.

Er is nog geen productieapp; er zijn alleen testimports, bewust, tot de functies compleet zijn.

## Goedgekeurde baseline
- Approved by Eddy 27-10-2026: build pickerfix-20261027_132738 (Studio-test geslaagd), tag approved-20261027-pickerfix op commit d7da488. Src in de build bytegelijk aan d7da488. Pad: C:\Users\vandergoot.ed\Dev\Sitemanagment\artifacts\pickerfix-20261027_132738\SiteManagement_PickerFix_20261027_132738.msapp, 120737 bytes, SHA-256 99A66DFE2B56CE7B089BE909E423FBDC20B091123A7A6266BEF534093CD9CC52. Bevat Home, Discard, inzetperiodes, migratieactie, Hours Summary-kiezerbereik (bug 6.1 gesloten) en rapportinvalidatie bij Confirm migratie. De periodes-build (periods-20261026_222325) is vervangen. Gedrag: AGENTS.md; test: TESTPLAN.md.
- Eerdere goedgekeurde: approved-20261026-home (commit f33f360), approved-20261026-discard (commit 7c7a46a), approved-20261026-savefix (commit 01af074), baseline-footer-row-20261020_215936 (archief).
- Testprojecten: TEST-000 (MS-005, opslaan toegestaan) en TEST-001 (bestaat, Active = Nee; alleen test, alleen-lezen gebruikt voor "geen periodes en geen uren": kiezers uitgeschakeld). TEST-prefix-regel geldt (uitgesloten van Week Report/exports bij bouw).

## Huidige build
- Er is geen nieuwe testbuild; de goedgekeurde baseline is de huidige build.
- Open na pickerfix: 6.4 (Confirm migratie, daarna Hours Summary ververst) uitgesteld tot de migratie van een echt project; TP-MIGR-01 op een echt project open.
- Beperkingen pickerfix: varReportCurrentMonday staat vast per load (sessie die in een nieuwe week openstaat houdt het oude maximum tot Refresh/projectwissel); een periode met lege From telt niet mee voor het minimum en blokkeert het laden niet (kan in het nulrij-filter als overlappend tellen; voorgesteld: aparte logicataak, laden blokkeren bij periode zonder From); fallbacks Date(1900,1,1)/Date(2200,12,31) voor StartDate/EndDate zijn inerte plaatshouders (kiezers dan uitgeschakeld). Alleen in Studio te zien: gedrag van ModernDatePicker als StartDate/EndDate wijzigen tijdens de Reset bij laden.
- Inhoud: lijst Assignment Periods (MS-010: AssignmentKey, ProjectKey, From, Until; alleen datum); de metadata uit Studio is door de orchestrator in de .msapr samengevoegd (Assignment Periods plus vernieuwde schema's Workers/Employers/Hours; app-Id, lijst-ID's en verbindingen ongewijzigd). Workers-kolommen Employer Code/Name, Phone en Email zijn door Eddy verwijderd; de app vult het cacheveld 'Employer Name' uit Employer.Value. Regels: AGENTS.md (punt 3); besluit: DECISIONS.md H9.
- Bekende beperkingen (reviewer, niet blokkerend): een project met alleen inactieve PW krijgt nooit een migratieaanbod (inactief-met-uren-historie wordt niet aangemaakt); Confirm ziet verwijderde uren alleen als de preview niet gepagineerd was (<500 uren); een teamwissel verplaatst de hele PW (oude weken tonen onder het nieuwe team); Test-PerformanceFix (historisch) stopt vroeg bij zijn checkpoint-diff.
- Alleen in Studio te controleren: Patch {Until: Blank()} wist de datum; JSON() van projecties; Sort op ID/Modified (delegatie); ModernDatePicker 1.0.0 versus template 1.0.2.
- TP-DD-01, TP-SAVE-01, TP-LOGO-01: geslaagd (Eddy, 26-10-2026, zonder detailrapport). TP-DISCARD-01: stappen 1-5 en 7 geslaagd (Eddy, 26-10-2026; footer past, geen overlap); stap 6 (Monitor) overgeslagen; stap 8 (Failed) open tot TEST-000. De oude Studio-testlijst staat in het archief.
- Bevestigd door Eddy in Studio op 26-10-2026: weeklabel van dpHoursWeek toont voor 01-01-2027 `2026 KW53` (TP-WEEK-01); Hours Summary-restyle (zebra, "–" bij 0, totaalrij, Period total-kolom, scrollbarruimte, GEA-tabelkop) is visueel ok (TP-SUM-01); hergebruik van geladen selecties, scenario 1-7 via Monitor (TP-REUSE-01, op Eddy's melding "alles werkt"; Monitor-regels niet afzonderlijk gemeld); weekkiezer: een andere week laadt automatisch en onopgeslagen invoer blokkeert wisselen (kiezer uitgeschakeld, Refresh grijs, alleen Save actief). Verder niets bevestigd.
- Nog niet functioneel getest in Studio: weekkiezer dpHoursWeek: andere dag in dezelfde week bewaart de dag zonder herlaad; overige GEA-kleuren; fail-closed blokkades (rest); Monitor-delegatie; wijziging van een andere gebruiker verschijnt pas na Refresh (vereist TEST-000).

## Studio-bewijs
- Studio-bewijs 26-10-2026 (importcontrole, App checker 141 meldingen, ModernDatePicker 1.0.0 versus Studio 1.0.2): PROJECT_STATUS_ARCHIVE.md.

## Open items
- Functionele Studio-tests van de hierboven genoemde niet-geteste onderdelen.
- Discard: Monitor-spoor DIAG|Week|Discard niet gecontroleerd (stap 6 overgeslagen); Failed-tak (stap 8) pas testbaar met TEST-000.
- Later, niet blokkerend: App checker-meldingen doorlopen (toegankelijkheid, ongebruikte variabelen, WarnLiteralPredicate).
- Src en Check-WeeklySource uitlijnen op ModernDatePicker@1.0.2 (NEXT_COMMANDS.md 2b).
- Opslagsnelheid Save week / Save team niet expliciet bevestigd (laden is door Eddy getest: snel, geen fouten).
- Jaargrens/week 53 in Hours Summary (periode/rapport over de jaarwisseling) alleen lokaal getest; het Weekly Hours-weeklabel is wel bevestigd in Studio (zie Huidige build); natuurlijk testmoment ISO-week 53 van 2026 (28-12-2026 t/m 03-01-2027). Geen testuren in gedeelde lijsten zetten.
- Open punt: komen medewerkers met periodetotaal 0 in de CSV-export voor?
- SECURITY.md aangemaakt (WAF SE-checklist); open: GitHub 2FA bevestigen, IT-vragen, MS-004/007/011 (gepland; MS-007 moet ook melden: Workers.Title ongelijk aan First Name + Surname, lege Trade of Employer), TP-SEC-01.
- Volgende werk (volgorde: NEXT_COMMANDS.md): UX-ronde Project / team, daarna Week Report, export, roadmap-merge.
- TP-PERIOD-01: PASS 27-10-2026 (Eddy; 6.1 a-e, 6.2 op ~900 px, 6.3 TEST-001); TP-MIGR-01: PASS op TEST-000; details: TESTPLAN.md. Bug 6.1 (Hours Summary-kiezers) gesloten; besluit: DECISIONS.md H12.
- Verwachte regelwijziging in de UX-ronde: Subtitle4-voorwaardelijk gewicht (+ Test-Fonts.ps1).
- Uitsluiting van TEST-projecten/TEST Employer in Week Report, Hours Summary-export en health check: gepland bij de Week Report-taak, niet geïmplementeerd (regel in AGENTS.md).
- Volgende UX-ronde Project / team (TP-PERIOD-01 goedgekeurd; besloten, niet gebouwd): Screen1-kaarten tonen Title (H10); inline oranje kaartstatus; samenvattingspopup vóór Save team; migratie-previewpopup en knoppen hernoemen naar "Eenmalige omzetting: bekijken" / "Eenmalige omzetting: uitvoeren"; optie B uitvinken (H11) in regels/tests/TESTPLAN. Aanvullend besloten 27-10 (details NEXT_COMMANDS.md 4b): live validatie met rode kaart en Save team uit; zichtbare ontgrendeltekst bij vergrendelde kiezers; één melding (statusregel rood/zwart, gecentreerd, geen Notify); heropen-melding in de popup; Weekly Hours zonder blauwe selectiebalk en zonder "Trade onbekend"-chip; Subtitle4 niet meer vet bij selectie.
- Export (PDF + CSV, generieke flow): niet gebouwd; spec in AGENTS.md.
- Dataminimalisatie (DECISIONS.md D7): MS-012 deels gedaan (Worker Contacts bestaat, telefoons gemigreerd, Workers.Phone en Workers.Email verwijderd); open: groep Site Supervisors, unieke rechten, opschonen versiegeschiedenis (status onbekend, Eddy vragen); besluit Hours.Title = EntryKey (bij volgende Save-taak) en of bestaande rijen blijven staan.

## GEA-logo
- Goedgekeurd in Studio (TP-LOGO-01, Eddy 26-10-2026); regel en maten: AGENTS.md; bron Assets/GEA_logo_white.svg (1130 bytes, SHA-256 5D460376D030AF075E004E50191C8BE0C8DB05C5E0A9E593F53612DA52606087, bytegelijk aan het officiële logobankbestand). Technisch gecontroleerd met artifacts/Test-Logo.ps1. Geen MS-item.

## Open MS-items (MANUAL_STEPS.md)
- MS-010 (lijst Assignment Periods): gedaan 26-10-2026 (Eddy; From/Until alleen datum, weergavenaam "Until"). Migratie bestaande koppelingen = app-actie (TP-MIGR-01).
- MS-012 (Worker Contacts): deels gedaan; open: groep Site Supervisors + unieke rechten + opschonen versiegeschiedenis Workers (Eddy bevestigen).
- MS-018 (Assignment Periods, From verplicht): open sinds 27-10-2026; Eddy controleert de lijstinstelling (metadata meldt al verplicht; dan sluiten).
- Open testgevallen: TP-PERIOD-01 stap 6.4 en TP-MIGR-01 op een echt project (TESTPLAN.md).
- MS-005 uitbreiding (3 extra testmedewerkers Test Fitter 2 / Test Welder 2 / Test Unknown 2): gedaan 26-10-2026 (Eddy: bestaan in Workers; nog niet aan TEST-000 gekoppeld, dat gebeurt in TP-PERIOD-01).
- TEST-000 beschikbaar (MS-005) — open testgevallen met opslaan nu uitvoerbaar: TP-DISCARD-01 stap 8 (Failed), TP-REUSE-01 cross-user.
- MS-017 (flow "Workers - Worker Name sync"): gedaan 27-10-2026 (Eddy, getest, geen lus). Workers.Title is niet meer verplicht, verborgen in het formulier en wordt door de flow = First Name + Surname gehouden, nooit getypt. Interne namen Workers: First Name = field_2, Surname = field_3, Trade = field_6.
- SharePoint dwingt nu een verplichte, unieke Employer Code af (MS-009, Eddy 26-10-2026).
- MS-001 (25-10-2026), MS-005 en MS-009 (26-10-2026) en MS-008 (Workers.Trade 25-10, Hours.Trade 26-10-2026) zijn gedaan.
- De aparte controle "geen lege ProjectKey in Project Workers" is niet gemeld en blijft relevant (Save team-risico).

## Bekende beperkingen
Savefix (goedgekeurd):
1. Na aanvullen van Trade/Employer in SharePoint: eerst onopgeslagen invoer terugdraaien, dan Refresh op Project / team, dan opnieuw invoeren.
2. Employer/Trade-validatie blokkeert ook correcties van bestaande Hours-regels (bewust, fail-closed).
3. Screen1: naam kan de rode waarschuwing overlappen bij zeer smalle galleries (scherm < ~604 px).
4. lblWeekLoadStatus (2 regels) kan zeer lange meldingen op smalle schermen afkappen.
5. Rode tekst in galleryrijen voor blokkerende stamgegevenswaarschuwingen (toegestaan in AGENTS.md).
6. Logica en presentatie zitten in één build (op verzoek).
7. Historische Hours-regels kunnen F/W bevatten, nieuwe Fitter/Welder/Unknown: relevant voor groepering in rapport/export.

Discard (goedgekeurd):
8. Na Discard in Failed met mislukte geforceerde herlaad meldt de loader "Vorige invoer behouden" terwijl de invoer is verwijderd; het grid toont colWeekOriginal (deels geverifieerde waarden), de gedetailleerde opslagfout is gewist; opslaan blijft geblokkeerd.
9. Na geslaagde Discard-herlaad in Failed: controleer SharePoint-versies (Modified/Modified By) van de betrokken rijen; de eerdere deelopslag is dan alleen nog in Notify/Trace zichtbaar.
10. Getypte waarde waarvan OnChange nog niet is afgegaan is niet dirty: de eerste klik op de nog uitgeschakelde Discard laat alleen het veld los; daarna wordt de knop actief.
11. Screen1: na mislukte/deels bevestigde Save team is de staat Failed maar blijft varTeamDirty true; checkboxes vereisen Loaded en niet dirty, Refresh en dropdowns zijn geblokkeerd: alleen herstart helpt. Besluit Eddy 26-10-2026: Discard alleen op Weekly Hours; selectiefouten in Loaded worden met een nieuwe Save team gecorrigeerd. Bekende uitzondering: Failed, uitweg = app herstarten (NEXT_COMMANDS.md).

Algemeen:
- Smalle vensters: Hours Summary-tabel heeft onder ~666 px geen weekkolom, footer scrolt horizontaal; zes bekende tekstoverschrijdingen; geen telefoonlayout voor de rapporttabel. Door het logo (lblReportProjectDetails 120 px smaller) knipt de projectregel onder ~810 px (was ~690), titels op Screen1/scrHours knippen onder ~430 px en de Hours Summary-titelbalk past onder ~440 px niet.
- Historische scripts falen ook op HEAD en zijn geen acceptatietests: Test-NavigationLayout, Test-Performance, Test-ReadExisting, Test-PerformanceFix, Test-SummaryFields (vergelijken met oude checkpoints).
- Save week/team zijn geen SharePoint-transactie; gedeeltelijke opslag blijft mogelijk (invoer behouden, opslag geblokkeerd).
- Bekende delegatie-uitzondering: maand-/dagpaginering van Hours Summary binnen ForAll(Sequence(monthCount)).
- Home (niet-blokkerend, reviewer): (a) btnWeeklyProjectTeam (scrHours), btnSummaryProjectTeam (Summary) en btnGotoHoursSummary (Screen1) hebben hun guard alleen in DisplayMode, niet als eerste OnSelect-voorwaarde (bestaand; later logicataak); (b) Studio: uren typen en direct op Home klikken (OnChange-on-blur versus OnSelect), de OnSelect-guard beperkt het risico; (c) de Weekly Hours-tegel leest ddProject/ddTeam van Screen1 (app-CrossScreenEventDependencies); (d) Notify op Home is Engels, de meeste meldingen Nederlands; (e) "Component library" past krap (173/176 px bij tegel 200 px); (f) geen schermovergang op Home-navigatie (cosmetisch). Placeholder-tegels zijn bewust zonder logica.
- Logo: 13 px vrije ruimte boven/onder in de balk van 56 px (de regel ≥15 px geldt horizontaal).
- ModernDatePicker: Src 1.0.0 versus Studio 1.0.2 (zie Studio-bewijs).
- artifacts\Logo_download\20261026-Sitemanagment_logo.msapp bevat een read-only SAS-token, geldig tot 27-10-2026 10:57 UTC; lokaal en gitignored; Eddy mag het verwijderen.
