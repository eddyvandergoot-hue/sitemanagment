# Testplan (handmatige Studio-/browsertests)

Handmatige testcases voor Studio en browser; pack en lokale scripts vervangen deze niet. Status per case: open / geslaagd / mislukt, met datum en wie. Huidige testbuild: PROJECT_STATUS.md.

## Testgegevens

- Functionele tests met opslaan uitsluitend op project TEST-000 (MS-005); echte projecten alleen leescontroles. Alle testcases met opslaan draaien op TEST-000.
- Projecten met Project Number-prefix "TEST-" en de werkgever TEST Employer horen niet in Week Report, Hours Summary-exports en een toekomstige health check (uitsluiting nog niet gebouwd; zie AGENTS.md).
- MS-005 (testgegevens): gedaan 26-10-2026 (Eddy). TEST-000 is beschikbaar met Test Fitter / Test Welder / Test Unknown (team 1, werkgever TEST Employer).

| Case | Onderwerp | Status | Datum | Wie |
|---|---|---|---|---|
| TP-DD-01 | Dropdown hover zichtbaar | geslaagd | 26-10-2026 | Eddy |
| TP-SAVE-01 | Savefix-controles | geslaagd | 26-10-2026 | Eddy |
| TP-LOGO-01 | Logo zichtbaar | geslaagd | 26-10-2026 | Eddy |
| TP-WEEK-01 | Weeklabel 01-01-2027 = 2026 KW53 (Weekly Hours) | geslaagd | 26-10-2026 | Eddy |
| TP-SUM-01 | Hours Summary restyle | geslaagd | 26-10-2026 | Eddy |
| TP-REUSE-01 | Hergebruik geladen selecties | geslaagd | 26-10-2026 | Eddy |
| TP-SEC-01 | Permissietest met niet-eigenaar account | OPEN | - | Eddy |
| TP-PERIOD-01 | Inzetperiodes (Screen1, Weekly Hours, Hours Summary) | PASS | 27-10-2026 | Eddy |
| TP-MIGR-01 | Migratieactie per project (Screen1) | PASS op TEST-000 en Friesland Campina | 27-10-2026 | Eddy |
| TP-CONTRACTORS-01 | Contractors-scherm (beheer) | PASS (build 232612, I-S allemaal ok; kort hertest op de Admin pattern-build in TP-STYLE-01) | 29-10-2026 | Eddy |
| TP-STYLE-01 | Admin screen pattern: Contractors visueel + kort regressie | OPEN (build adminpattern-20261030_071949) | - | Eddy |
| TP-PROJECTS-01 | Projects-scherm (beheer) + Home-tegels | OPEN (build adminpattern-20261030_071949) | - | Eddy |
| TP-WH-CLEAN-01 | Weekly Hours: geen blauwe balk, geen Trade onbekend-chip | OPEN | - | Eddy |
| TP-COMP-01 | Stap 2: import met componenten + logicafixes Contractors/Projects | FAIL import build 132104 (PA2231, opgelost); hertest OPEN op build components-20261030_135641 | 30-10-2026 | Eddy |

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

Geslaagd (Eddy, 26-10-2026, Studio, goedgekeurde build logo-20261026_120726), scenario 1-7 via Monitor. Op Eddy's melding "alles werkt"; de Monitor-regels (CacheHit versus AfterHoursQueries) zijn niet afzonderlijk gemeld.
Interpretatie: alle scenario's gedragen zich zoals verwacht. Bij uren typen zonder opslaan is de weekkiezer uitgeschakeld, Refresh grijs en alleen Save actief (Eddy): dat is het ontwerp (AGENTS.md); het blokkeren gaat via uitgeschakelde controls, de melding "Niet geladen: onopgeslagen uren behouden..." is alleen een vangnet.

Setup: Studio > Advanced tools > Open monitor > Play; zoek op DIAG.

| # | Stap | Verwacht |
|---|---|---|
| 1 | Project + Team kiezen, naar Weekly Hours | laadt |
| 2 | Terug en weer naar Weekly Hours, zonder wijziging | Week\|CacheHit, geen nieuwe Hours-aanroep |
| 3 | Andere week kiezen | laadt |
| 4 | Terug naar de eerste week | laadt (cache onthoudt alleen de laatste selectie; geen fout) |
| 5 | Refresh | laadt, geen CacheHit |
| 6 | Refresh op Project / team, daarna Weekly Hours | laadt (teamversie gewijzigd) |
| 7 | Uren typen zonder opslaan | weekkiezer, Refresh en navigatie uitgeschakeld; alleen Save actief |

Niet getest: "wijziging van een andere gebruiker verschijnt pas na Refresh" (testen met TEST-000 zodra MS-005 klaar is; geen echte uren wijzigen).

## TP-DISCARD-01 Discard changes (geslaagd met 2 open stappen)

Build: discard-20261026_151949 (PROJECT_STATUS.md). Eddy, 26-10-2026: stappen 1-5 en 7 geslaagd; stap 6 (Monitor) overgeslagen; stap 8 open tot TEST-000.

| # | Stap | Verwacht |
|---|---|---|
| 1 | Loaded + uren wijzigen (ook leeg maken en 0), Discard | waarden terug naar laatst geladen/opgeslagen, incl. leeg en 0; melding "Wijzigingen ongedaan gemaakt." |
| 2 | Direct daarna | weekkiezer, Refresh en navigatie weer actief; Save toont geen wijzigingen |
| 3 | Validatiefout in invoer, Discard | foutmelding verdwenen |
| 4 | Tijdens laden/opslaan, en zonder wijziging | Discard uitgeschakeld |
| 5 | Waarde typen zonder het veld te verlaten | eerste klik blurt alleen het veld; daarna wordt Discard actief |
| 6 | Monitor, zoek DIAG | DIAG\|Week\|Discard zichtbaar (OVERGESLAGEN, niet getest) |
| 7 | Tekst "Discard changes" en footerrij op uw vensterbreedte | tekst past, rij Refresh / Discard changes / Save zonder overlap (min. 734 px) |
| 8 | State Failed (na deels/onzeker opslaan) | lokaal verwijderd en geforceerd opnieuw gelezen; alleen testbaar met TEST-000 zodra MS-005 klaar is (lastig na te bootsen) (OPEN) |

## TP-HOME-01 Home-scherm en Home-knop (geslaagd 26-10-2026, Eddy)

Build: home-20261026_165630 (PROJECT_STATUS.md). Geslaagd in Studio 26-10-2026 (Eddy, zonder detailrapport). Opslaan alleen op TEST-000.

| # | Stap | Verwacht |
|---|---|---|
| 1 | App openen | start op Home; titelbalk "Site Management" met logo; drie kolommen Administration / CAD tools / Inventory met kop en blauwe lijn |
| 2 | Tegel Project / team | Screen1 opent en laadt via OnVisible |
| 3 | Tegel Hours Summary, project kiezen | Hours Summary opent; rapport laadt |
| 4 | Tegel Weekly Hours zonder geladen project/team | Screen1 + melding "Choose project and team first" |
| 5 | Project/team laden, Home, tegel Weekly Hours | Weekly Hours laadt; invoer bewerkbaar |
| 6 | Placeholder-tegels | grijs, "Coming soon", niet klikbaar |
| 7 | Home-knop in de footer van elk scherm | staat links; Weekly Hours uitgeschakeld met onopgeslagen uren of tijdens opslaan; Screen1 met onopgeslagen selectie; Hours Summary terwijl het rapport laadt |
| 8 | Screen1 na mislukte/lege load | Home werkt |
| 9 | Uren typen en direct op Home klikken | geen navigatie met onopgeslagen invoer |
| 10 | Venster >= 728 px en smal | 3 kolommen naast elkaar; smal 1 kolom met scrollen; geen overlap of afsnijden |
| 11 | Logo op alle vier schermen | zichtbaar in de titelbalk |

## TP-PERIOD-01 Inzetperiodes (PASS 27-10-2026, Eddy)

Build: PROJECT_STATUS.md (Assignment periods). Uitsluitend op TEST-000 met 6 medewerkers: Test Fitter / Welder / Unknown en de "2"-varianten (MS-005). Regels: AGENTS.md, Functionele afspraken punt 3. Gebruik KW40 t/m KW46 van 2026 (of een andere reeks; noteer de weken). Eerst TP-MIGR-01 als TEST-000 nog actieve koppelingen zonder periode heeft.

Let op: stap 3 en 4 testen de huidige (gebouwde) uitvink-regel en veranderen met optie B (DECISIONS.md H11).

| # | Stap | Verwacht |
|---|---|---|
| 1 | Screen1, TEST-000, team 1, week KW40; vink alle 6 aan; Save team | opgeslagen; per medewerker één open periode, From = maandag KW40 |
| 2 | Weekly Hours KW40 en KW41 | 6 rijen in beide weken |
| 3 | Screen1 KW42: vink 2 medewerkers uit; Save team | Until = zondag KW42 |
| 4 | Weekly Hours KW42 en KW43 | die 2 staan nog in KW42, niet in KW43 (zonder opgeslagen uren) |
| 5 | Screen1 KW44: vink die 2 weer aan; Save team | NIEUWE periodes From = maandag KW44 (niet heropend: ze eindigden KW42, niet KW43) |
| 6 | Heropenen: KW45 1 medewerker uitvinken, Save team; KW46 weer aanvinken, Save team | de periode van KW45 wordt HEROPEND (Until leeg, geen nieuwe periode) |
| 7 | Later-periode-blokkade: kies KW39 en vink een medewerker aan die vanaf KW40 een periode heeft; Save team | geblokkeerd met melding; nul writes |
| 8 | Verkorten: gesloten periode met latere Until in een eerdere week uitvinken | alleen toegestaan als dit de laatste periode is, anders geblokkeerd |
| 9 | Alle medewerkers expliciet uitvinken; Save team | toegestaan; zonder expliciet uitvinken (lege selectie) blijft Save geblokkeerd |
| 10 | Weekly Hours: rij zonder periode in die week, nieuwe dag invullen; Save week | geblokkeerd (nul writes); bestaande dag corrigeren lukt |
| 11 | Gedeelde week: wissel week op Screen1 en open Weekly Hours, en andersom | beide tonen dezelfde week |
| 12 | Weekwissel met onopgeslagen selectie of uren | geblokkeerd met melding |
| 13 | Hours Summary over de periode | nulrijen = medewerkers met een periode die het bereik overlapt |
| 14 | Studio-only: Patch {Until: Blank()} wist de datum; Monitor-queries op Assignment Periods (ProjectKey-filter, geen $top=500 zonder filter) | datum gewist; gedelegeerde query |

Uitkomst per stap noteren met datum. Een mislukte stap: meld de melding en het resultaat in SharePoint (Assignment Periods en Project Workers).

Uitkomst 27-10-2026 (Eddy, mondeling gemeld). Let op: Eddy gebruikt zijn eigen stapnummering; die kan afwijken van de tabelnummering hierboven.
- Eddy 0.1-0.2: geslaagd. Migratie: geslaagd (zie TP-MIGR-01). 3.1-3.4: geslaagd. 4.1-4.4: geslaagd. 5.1-5.3: geslaagd.
- Eddy 6.1: MISLUKT. Hours Summary: de kiezers From en Till zijn beide beperkt tot 19-10 t/m 25-10-2026 (alleen KW43); vandaag 27-10 (KW44) is niet kiesbaar; de TEST-000-periodes starten 28-9-2026, dus KW40 t/m KW44 zijn niet kiesbaar. Oorzaak gevonden (onderzoek): StartDate/EndDate van dpReportFrom/dpReportUntil in Src/scrWeeklyHours.pa.yaml komen uit colReportPeriods = ISO-weken MET opgeslagen uren (huidige AGENTS.md-regel "Selecteerbare datums en standaardperiode komen uit beschikbare uren"). Bestaand gedrag, niet veroorzaakt door de periodes-build (760cc94). Fixvoorstel wacht op Eddy's akkoord; niet gebouwd.
- Eddy 6.2: open.
- Nieuwe build 27-10-2026: pickerfix (PROJECT_STATUS.md, Huidige build; niet in Studio getest). Eddy herhaalt 6.1 en 6.2.
- Verwacht 6.1 (Hours Summary op TEST-000): kiezers From en Till laten KW40 t/m KW44 toe, inclusief 27-10-2026; standaardperiode = weken met uren (KW43); From na Till geeft een foutmelding.
- Extra stap (a): een project zonder inzetperiodes en zonder uren: kiezers uitgeschakeld, status "Geen inzetperiodes of uren voor dit project", geen tabel. Bestaat zo'n project niet, dan alleen-lezen testen op een willekeurig project met geen van beide (geen opslag op echte projecten).
- Extra stap (b): Confirm migratie op Screen1 (TEST-000, zie TP-MIGR-01) en daarna Hours Summary openen: het rapport laadt opnieuw (vernieuwde periodes en nulrijen).
- Resultaat build pickerfix-20261027_132738 (Eddy, 27-10-2026, Studio): TP-PERIOD-01 volledig PASS: 6.1 a-e (kiezers From/Till laten alle weken van de periodes toe), 6.2 op ~900 px venster, 6.3 TEST-001 (project zonder periodes en uren: kiezers uitgeschakeld). Bug 6.1 gesloten. 6.4 (Confirm migratie, daarna Hours Summary ververst): PASS 27-10-2026 (Eddy) op het echte project Friesland Campina (15 periodes gemigreerd). Tag approved-20261027-pickerfix.

## TP-MIGR-01 Migratieactie (PASS op TEST-000 en Friesland Campina, 27-10-2026, Eddy)

Uitsluitend op TEST-000: maak eerst een toestand met een actieve Project Workers-koppeling zonder periode (anders is de knop niet zichtbaar).

| # | Stap | Verwacht |
|---|---|---|
| 1 | Screen1, TEST-000 laden | migratieknoppen zichtbaar; Save team geblokkeerd |
| 2 | Preview | aantallen per categorie; geen writes |
| 3 | Confirm | één Patch + verify; periodes aangemaakt; migratieknoppen verdwijnen; Save team weer mogelijk |
| 4 | Preview opnieuw na een gedeeltelijke migratie (alleen de overgebleven koppelingen) | alleen koppelingen zonder periode in de telling |
| 5 | Na Preview: uren wijzigen (andere sessie/SharePoint), dan Confirm | geblokkeerd; opnieuw Preview nodig |
| 6 | Confirm voor een ander project dan de Preview | geblokkeerd |

Uitkomst 27-10-2026: migratie geslaagd volgens Eddy (als onderdeel van de TP-PERIOD-01-run; geen resultaten per stap gemeld). Eddy bevestigde 27-10-2026 PASS op TEST-000 (build pickerfix). Ook PASS op het echte project Friesland Campina (27-10-2026, Eddy; 15 periodes, Hours Summary ververst na Confirm = 6.4 van TP-PERIOD-01).

## TP-SEC-01 Permissietest met niet-eigenaar account (OPEN)

Doel: aantonen dat een gebruiker zonder eigenaarsrechten alleen kan wat de bedoelde rol toestaat (zie SECURITY.md, SE:05/SE:08). Opslaan-stappen uitsluitend op TEST-000; op echte projecten alleen lezen.

| # | Stap | Verwacht |
|---|---|---|
| 1 | Aanmelden met een account dat geen eigenaar is (collega- of testaccount met de bedoelde rol) | aanmelden lukt (MFA zoals GEA-beleid) |
| 2 | App openen | opent; noteer welke schermen bereikbaar zijn (volgens de bedoelde rol) |
| 3 | Lijsten lezen (Projects, Workers, Project Workers, Hours) in de app en in SharePoint | alleen wat de rol toestaat |
| 4 | Een Hours- of Project Workers-item verwijderen in SharePoint (alleen TEST-000-gegevens) | moet mislukken zodra MS-004 (gepland) is uitgevoerd |
| 5 | Site-instellingen / lijstinstellingen openen | moet mislukken |
| 6 | Proberen te exporteren zonder de flow (rechtstreeks bestanden of lijsten downloaden/delen) | niet mogelijk buiten de gecontroleerde flow (export nog niet gebouwd) |
| 7 | Opslaan (Save week) als TEST-000 met dit account | alleen toegestaan als de rol dat omvat |

Uitkomst per stap noteren met datum en account/rol. Stap 4 is pas bindend na MS-004.

## TP-CONTRACTORS-01 Contractors-scherm (PASS 29-10-2026, Eddy, build contractors-20261029_232612; tag approved-20261029-contractors; UI sindsdien herbouwd volgens het Admin screen pattern, kort hertest in TP-STYLE-01)

Resultaat 28-10-2026 (Eddy, build 203334): stap 8 en 9 FAIL (elke Save toonde "Save not confirmed ... Saving is blocked" terwijl de data wel was geschreven; daarna alles behalve Discard uit; zoekvak-rand verborgen, paneel niet uitgelijnd); de overige stappen niet gemeld. Oorzaak en fix: PROJECT_STATUS.md. Hertest door Eddy op build 232612 (vervangt 174723; 221757 overgeslagen), plus de extra controles onder de tabel.
Resultaat 29-10-2026 (Eddy, build 174723): PASS: stap 8, 9, 9b, 10, 11, 12a (verse gegevens na Refresh), 12b (conflict geblokkeerd, SharePoint-waarde "Stad B" intact, Discard + Refresh toont Stad B) en uitlijning brede layout. Het doel van build 174723 (connectorcache toont nooit waarden van vóór een directe SharePoint-wijziging) is daarmee bevestigd. Let op: de labels 9b, 12a en 12b staan niet in de tabel hieronder (Eddy's nummering); koppeling aan tabelstappen niet vastgelegd. Stappen 1-7, 13-18 en controles A-H: niet gemeld. Hertest op build 232612 (meldingenbesluit H17, rood/oranje/groen en spinner): controles I-S, en de tabelverwachtingen van stap 6, 7, 16, 17 zijn bijgewerkt naar de meldingsbalk.

Testdata uitsluitend met prefix TEST (bv. "TEST Contractor 2"); echte contractors alleen lezen, nooit wijzigen. Nooit verwijderen, alleen deactiveren.

| # | Stap | Verwacht |
|---|---|---|
| 1 | Home openen, tegel Contractors kiezen | scrContractors opent; logo en titelbalk correct; lijst laadt |
| 2 | Show inactive uit | inactieve contractors verborgen |
| 3 | Zoeken op naam, code en plaats | lijst filtert lokaal op alle drie |
| 4 | Een contractor selecteren | formulier gevuld; Contractor Code in grijs alleen-lezen vak txtEmpCode |
| 5 | New | leeg formulier; Active aangevinkt; geen melding (zie Q) |
| 6 | Save met lege naam | rode balk "Fix: Contractor Name empty", rode rand op het veld; nul writes |
| 7 | Save met ongeldig e-mailadres | rode balk met reden, rode rand op het veld; nul writes |
| 8 | Dubbele naam in andere hoofdletters of met extra spaties (bv. "test employer") | geblokkeerd |
| 9 | "TEST Contractor 2" aanmaken en Save | opgeslagen, verify-melding, staat in de lijst |
| 10 | Refresh | code EMP-xxx (flow MS-019) verschijnt |
| 11 | Plaats van TEST Contractor 2 wijzigen en Save | opgeslagen |
| 12 | Wijziging maken (niet opslaan), dan Home, New of een gallery-klik | geblokkeerd |
| 13 | Discard changes | waarden hersteld |
| 14 | TEST Contractor 2 deactiveren en Save | verborgen bij Show inactive uit, zichtbaar bij aan |
| 15 | TEST Employer deactiveren (heeft actieve testmedewerkers) | oranje balk direct bij uitvinken, vóór Save; opslaan toegestaan; na Save oranje "Saved. n active worker(s)..." (zie P); sla over als Eddy dit niet wil deactiveren |
| 16 | Conflict: dezelfde contractor na het laden in SharePoint wijzigen, daarna Save | rode balk "Changed in SharePoint by someone else. Nothing saved. Click Discard, then Refresh." (zie K); SharePoint-waarde intact |
| 17 | Smal venster | geen statusregel; footer past; "Last changed in SharePoint" onder Active zonder overlap (zie M) |
| 18 | Monitor | queries op Employers (ID=, Title=) gedelegeerd |

Extra controles hertest (A-E sinds build 222247, F-H nieuw op build 174723):
- A. Stap 8-9 opnieuw: New met lege optionele velden, en Edit van City: Save slaagt met verify-melding, geen "Save not confirmed".
- B. Een contractor met lege velden selecteren maakt het formulier niet dirty (Home, New en gallery blijven actief).
- C. Layout op ~900, 1000 en 1280 px: zoekvak-bovenrand zichtbaar; lijst en formulier bovenaan uitgelijnd in de brede layout (>=1000 px); smal: formulier onder de lijst zonder overlap.
- D. Faalt een Save weer: noteer de tekst van de rode balk (veldnamen of SharePoint-reden), en de Monitor-events DIAG|Contractors|VerifyMismatch en DIAG|Contractors|Refresh.
- E. Na een mislukte Save laadt Refresh opnieuw (invoer verworpen).
- F. Een TEST-contractor direct in SharePoint wijzigen, dan Refresh (of het scherm opnieuw openen): de nieuwe waarden zijn zichtbaar, "Last changed in SharePoint" klopt met SharePoint (let op browsertijdzone versus versiegeschiedenis), de groene balk toont "{n} contractors loaded at hh:mm:ss" (zie I).
- G. Na Save toont het formulier de opgeslagen waarden en is het niet dirty (Home, New en gallery blijven actief; btnEmpFormReset).
- H. Brede layout (>=1000 px): formulier bovenkant gelijk met de lijst; label "Last changed" niet afgekapt (onder ~430 px kan het op twee regels afknippen: bekend, niet blokkerend).
- Bekende Studio-controles (historisch, build 232612 PASS): geneste Select (Refresh/OnVisible -> btnEmpLoad -> btnEmpFormReset), Reset pikt de nieuwe Default op, Modified komt mee in de kolomselectie, extra roundtrip per load. Sinds de Admin pattern-build staan de meldingen in de eigen meldingsbalk (geen Notify; stappen met "oranje/rode balk" gelden voor die balk, zie TP-STYLE-01).
- Nieuw op build 232612 (H17, I-O herzien, P-S nieuw; 221757 is niet getest):
- I. Geen statusregel en geen foutlijst in het scherm; laden toont de spinner rechts in de titelbalk en daarna een groene balk met aantal en tijd ("<n> contractors loaded at hh:mm:ss"); geen laadmelding.
- J. Save met lege naam en ongeldig e-mailadres: rode randen op beide velden, rode balk "Fix: Contractor Name empty (+1 more)".
- K. Conflict (zoals 12b): rode balk met exact "Changed in SharePoint by someone else. Nothing saved. Click Discard, then Refresh."
- L. Contractor Code is een grijs alleen-lezen vak (txtEmpCode); niet te bewerken.
- M. "Last changed in SharePoint" klein en grijs onderaan onder Active, smal en breed zonder overlap met de footer.
- N. (indien te forceren) mislukte load of save: rode melding blijft staan tot sluiten.
- O. Geslaagde Save (zonder waarschuwingen): groene balk.
- P. Active uitvinken bij een contractor met actieve (test)medewerkers (alleen TEST-records): direct een oranje balk vóór Save; Save blijft mogelijk; na Save oranje "Saved. n active worker(s)...".
- Q. New: geen melding (geen groene of andere balk).
- R. Selectie van een inactieve contractor, Discard en de reset na Save: geen oranje melding.
- S. De spinner draait rechts in de titelbalk tijdens laden en opslaan en verdwijnt daarna; geen overlap met de titel bij normale breedte (onder ~400 px bekend mogelijk). Noteer of de animatie draait of de boog statisch blijft.

## TP-WH-CLEAN-01 Weekly Hours opgeschoond (OPEN)

| # | Stap | Verwacht |
|---|---|---|
| 1 | Weekly Hours, een rij selecteren | geen blauwe balk op de geselecteerde rij |
| 2 | Medewerker met Trade Unknown | geen chip "Trade onbekend" op Weekly Hours; wel de badge op Screen1 |
| 3 | Blokkerende waarschuwing (bv. ontbrekende Employer) | blijft rood op Weekly Hours |

## TP-STYLE-01 Admin screen pattern, Contractors visueel + kort regressie (OPEN; build adminpattern-20261030_071949, PROJECT_STATUS.md)

Voorwaarde: Studio-import van de build; alleen TEST-records (TEST Contractor 2, TEST Employer). Regels: AGENTS.md "Admin screen pattern", ADMIN_PLAN.md par. 10.

| # | Stap | Verwacht |
|---|---|---|
| 1 | Home, tegel Contractors | titelbalk blauw h60 met logo en titel (22 Semibold); spinner rechts tijdens laden; pagina lichtgrijs #F5F6F8 |
| 2 | Meldingsbalk (laden, fout, waarschuwing, succes forceren via de stappen hieronder) | direct onder de titelbalk, volle breedte; rood / amber / groen; vet kopwoord (Not saved. / Attention. / Saved. enz.); sluit-X sluit; één melding tegelijk; blijft tot sluiten of vervangen |
| 3 | Kaarten | twee witte kaarten met schaduw (DropShadow zichtbaar?), gelijke bovenkant, geen overlap |
| 4 | Lijstkaart | zoekveld met vergrootglas; telling links, Show inactive-switch rechts (tooltip noemt de stand); rijen: naam, subregel "CODE · City", hover grijs, geselecteerd lichtblauw + blauwe balk, inactief grijs + chip "Inactive" |
| 5 | Formulierkaart | kop recordnaam + statuschip (Active groen / Inactive grijs); secties GENERAL/ADDRESS/CONTACT in blauwe hoofdletters; verplicht-veld met rode * |
| 6 | Raster bij ~1366, ~1000 en ~700 px | 3 / 2 / 1 kolommen; bij >=1000 lijst links, formulier rechts; smaller gestapeld; geen overlap |
| 7 | Veldstijlen | wit met grijze rand; hover donkerder grijs; focus 2 px blauw; ongeldig (lege naam, Save) 2 px rood; alleen-lezen grijs zonder rand |
| 8 | Footer | wit, Home links met huisicoon (werkt), rechts New, Refresh, Discard changes (wit, blauwe rand), Save (groen); geen overlap, geen tweede rij |
| 9 | Regressie TP-CONTRACTORS-01 kort | laden; TEST Contractor 2 bewerken + Save (groene balk, verify); conflict (in SharePoint wijzigen tijdens bewerken) rode balk; Active uitvinken bij TEST Employer: direct amber balk; Save met waarschuwing: amber "Attention. Saved. ..." |
| 10 | Guards | onopgeslagen wijziging blokkeert Home/New/gallery; Discard herstelt |

## TP-PROJECTS-01 Projects-scherm en Home (OPEN; build adminpattern-20261030_071949)

Alleen TEST-projecten (TEST-000, TEST-001, nieuw TEST-002); echte projecten alleen lezen, nooit wijzigen. Nooit verwijderen, alleen Status.

| # | Stap | Verwacht |
|---|---|---|
| 1 | Home, tegel Projects | scrProjects opent; lijst laadt (Closed verborgen) |
| 2 | Zoeken op nummer, naam en plaats | lijst filtert lokaal op alle drie |
| 3 | Show inactive aan | Closed projecten zichtbaar (chip); On hold telt als actief (grijze chip) |
| 4 | Project selecteren | formulier gevuld; People (Project Leader, Site Managers) alleen-lezen |
| 5 | New | leeg formulier; Country standaard Netherlands; Status kiesbaar |
| 6 | Save met lege naam / lege Project Number / ongeldige URL | rode randen op de velden + rode balk met reden; nul writes |
| 7 | Dubbel Project Number | geblokkeerd (rode balk) |
| 8 | TEST-002 aanmaken en Save | groene balk, verify, staat in de lijst |
| 9 | Project Number van TEST-002 wijzigen en Save | opgeslagen met melding over Hours Summary/rapporten |
| 10 | Status Closed op een TEST-project met open periodes (TEST-000) | amber waarschuwing; opslaan toegestaan; project daarna onder Show inactive |
| 11 | Conflict: in SharePoint wijzigen tijdens bewerken, dan Save | rode balk, SharePoint-waarde intact; Discard + Refresh toont de SharePoint-waarde |
| 12 | Onopgeslagen wijziging, dan Home / New / gallery | geblokkeerd; Discard herstelt; Refresh werkt |
| 13 | Punten ADMIN_PLAN.md par. 8 punt 8: (a) Country/Status buiten Choices maakt het formulier dirty? (b) wist Patch met Blank() Country/ProjectHomeSite? (op TEST-000) | resultaat noteren |
| 14 | Smal venster (~700 px) | gestapeld, geen overlap, footer past |
| 15 | Cache na Save (Screen1, Hours Summary) | nieuwe naam/nummer zichtbaar na het openen |
| 16 | Home: Projects-tegel actief; Knowledge-kolom met grijze placeholder "Knowledge Base" (Coming soon, geen actie); ~900 px = vier kolommen; smaller = één kolom | zoals beschreven; noteer het kleine verschil titel X 40 / content X 24 |

## TP-COMP-01 Stap 2: componenten en logicafixes (hertest OPEN op build components-20261030_135641, PROJECT_STATUS.md)

Resultaat 30-10-2026 (Eddy, build 132104): import FAIL met PA2231 (Event-/Input-properties zonder Default in cmpField, cmpFooter, cmpListCard, cmpMessageBar, cmpTitleBar); Studio parste de componenten wel. Waarschuwing PA2105: ModernDatePicker 1.0.0 -> 1.0.2. Beide opgelost in build 135641.

Doel: bevestigen dat Studio de handgeschreven componenten accepteert vóór de migratie (stap 3), en de logicafixes op Contractors/Projects. Alleen TEST-records. De layout van Contractors/Projects is nog die van adminpattern (layoutfixes komen in stap 3).

| # | Stap | Verwacht |
|---|---|---|
| 1 | Import (Apps > Import > From file); als Studio erom vraagt: Settings > Updates > New > "Enhanced component properties" aan | import zonder fout; meld een fout exact (tekst) |
| 2 | Tree view > Components | cmpTitleBar, cmpMessageBar, cmpFooter, cmpField, cmpListCard aanwezig, zonder rode foutmarkering |
| 3 | Elke component openen | geen formulefouten; spinner (cmpTitleBar) en HTML-tekst (cmpMessageBar, cmpField-label met rood sterretje) renderen in de componentweergave |
| 4 | Projects openen | alle velden zichtbaar (wit/grijs kader), ook vóór een selectie; eerste project automatisch geselecteerd |
| 5 | Contractors openen | eerste contractor automatisch geselecteerd; velden zichtbaar |
| 6 | Projects: project met Status/Country buiten de keuzelijst (alleen als er al zo een is; geen testdata maken) | waarde zichtbaar, formulier niet gewijzigd (Home/New niet geblokkeerd) |
| 7 | Projects: dubbel Project Number opslaan (TEST-project) | rode melding, invoer blijft staan, opnieuw opslaan kan (scherm niet vergrendeld) |
| 8 | Regressie: Home, Project / team, Weekly Hours, Hours Summary laden | als voorheen |
| 9 | Datumkiezers (nu ModernDatePicker 1.0.2): Project / team "Week", Weekly Hours "Week", Hours Summary From/Till; kies een dag midden in een week en 01-01-2027 | gekozen dag blijft zichtbaar (geen sprong), labels "YYYY KWxx" kloppen (01-01-2027 = 2026 KW53), From/Till-bereik en Till-voor-From-blokkade werken als voorheen; geen PA2105-waarschuwing meer bij import |

Mislukt: noteer stap, foutmelding (exact) en scherm.
