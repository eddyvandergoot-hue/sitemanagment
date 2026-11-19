# Team tussen projecten (Eddy 19-11-2026)

Deel 1 beschrijft hoe het nu werkt (v1.0.2, gecontroleerd in de code, geen build). Deel 2 is het ontwerp voor v1.1 "Temporary assignment / Move team". Status: **ontwerp, wacht op akkoord van Eddy**; niets gebouwd.

## Deel 1 — Huidig gedrag (v1.0.2)

Vaste regels in de code:
- **Een periode is altijd een hele week.** Aanvinken op Project / team maakt `From = maandag` van de gekozen week (of heropent de laatste periode als die de zondag ervoor eindigde). Uitvinken zet `Until = zondag` van de gekozen week: die week telt nog mee.
- **Meerdere projecten in dezelfde week mag.** Er is geen blokkade en geen waarschuwing als een medewerker op een ander project actief is (functionele afspraak 2). Elk project heeft een eigen koppeling (Project Workers), eigen periodes en een eigen team.
- **Uren zijn per project per dag onafhankelijk.** De sleutel is `project|medewerker|datum`, dus "A woensdag" en "B woensdag" zijn twee aparte regels. Er is geen controle over projecten heen: dubbel invullen of meer dan 24 uur op één dag (A + B samen) wordt niet gezien. Per cel geldt 0-24.
- **Weekly Hours toont een medewerker** als hij een periode in die week heeft of uren heeft. Binnen een periodeweek mag op elke dag worden ingevuld.
- **Fill week** vult ma-vr op elk project waar de medewerker die week een periode heeft. In een week met twee projecten vult hij dus beide.
- **Hours Summary en Week report** zijn per project (en contractor). Binnen een project telt niets dubbel; tussen projecten telt elk rapport alleen zijn eigen uren. Een medewerker met een periode maar zonder uren staat er als lege rij ("–") in.

### a) Eén dag elders: team 1 op A ma/di/do/vr, woensdag op B

| Stap | Klikpad | Resultaat |
|---|---|---|
| 1 | Home > Project / team > Project **B**, team (bv. 1), Week = week X > vink de medewerkers aan > **Save team** | B-periode van ma t/m (open) |
| 2 | Direct daarna, zelfde scherm en week X: vink dezelfde medewerkers **uit** > **Save team** | B-periode = ma X t/m zo X. Niet pas volgende week uitvinken: dan loopt B door tot en met zondag X+1 en staan ze die week leeg op B (ook in het Week report). |
| 3 | Weekly Hours > project **A**, team 1, week X: ma/di/do/vr invullen, woensdag leeg. Fill week vult ook woensdag: maak die cel daarna leeg. > Save | |
| 4 | Weekly Hours > project **B**, het team uit stap 1, week X: **alleen woensdag** invullen. **Geen Fill week** (die vult ma-vr op B). > Save | |
| 5 | Controle: Week report A week X zonder woensdag; Week report B week X alleen woensdag | |

### b) Halverwege de week naar B voor 3 weken (vanaf woensdag week X)

| Stap | Klikpad | Resultaat |
|---|---|---|
| 1 | Project / team > **B**, team, Week = X > aanvinken > Save team | B: From = **maandag** X (niet woensdag; periodes zijn hele weken) |
| 2 | Project / team > **A**, team, Week = X > uitvinken > Save team | A: Until = **zondag** X. Ze blijven in week X zichtbaar op A (ma/di invullen). |
| 3 | Week X: Weekly Hours A ma/di; Weekly Hours B wo-vr. Fill week in week X op allebei niet gebruiken, of daarna de verkeerde dagen leegmaken. Week X+1 en X+2: alleen B (Fill week mag). | Beide projecten actief in week X: toegestaan, geen waarschuwing |
| 4 | Terugkeer woensdag week X+3: **A** week X+3 aanvinken (nieuwe A-periode vanaf ma X+3) > Save team; **B** week X+3 uitvinken (B tot en met zo X+3) > Save team. Uren: B ma/di, A wo-vr. | Spiegelbeeld van stap 1-3 |
| 5 | Hours Summary en Week report: elk project alleen zijn eigen dagen, niets dubbel zolang een dag niet op beide projecten is ingevuld | |

**Knelpunten nu:** (1) periodes niet per dag, dus overgangsweken staan op beide projecten volledig open; (2) Fill week vult in overgangsweken op beide projecten; (3) geen controle "zelfde dag op twee projecten" en "meer dan 24 uur per dag over projecten"; (4) voor één dag elders twee keer Save team (aan- en uitvinken).

## Deel 2 — Ontwerp v1.1 "Temporary assignment / Move team"

### Doel
Team of medewerkers per **dag** naar een ander project zetten, met optionele einddatum, zonder volgende week handmatig uit te vinken.

### Scherm
Op Project / team een knop **Move / assign** (alleen bij een geladen, opgeslagen team; dezelfde guard als Save team). Dialoogkaart (beheerpatroon, cmpField):
- Medewerkers: de aangevinkte medewerkers van het huidige team (vooraf geselecteerd, uit te vinken).
- **Doelproject** en **doelteam** (1-10).
- **Startdag** (datumkiezer, elke dag).
- **Einddag** (optioneel; leeg = open einde).
- Soort: **Temporary** (A blijft ongewijzigd) of **Move** (A stopt op startdag - 1).
- Bij Move met einddag: optie **Return to <A> after end day** (nieuwe A-periode vanaf einddag + 1, open).
- Knop **Save move** (groen) met overzicht vooraf: per medewerker welke periodes worden gemaakt of gesloten.

### Wat de app schrijft (per medewerker)
| Soort | Bronproject A | Doelproject B |
|---|---|---|
| Temporary | niets | koppeling (Project Workers) maken of heractiveren + periode From = startdag, Until = einddag (of open) |
| Move | open periode Until = startdag - 1 | idem |
| Move + Return | Until = startdag - 1 én nieuwe periode From = einddag + 1 (open) | periode From = startdag, Until = einddag |

Regels zoals nu: periodes worden nooit verwijderd, Until ≥ From, geen overlap binnen één project (overlap tussen projecten mag). Een latere periode op A of B blokkeert met een melding. Zelfde veiligheidsvolgorde als Save team: lokale validatie, pre-read (Project Workers + Assignment Periods van A en B op ProjectKey), table Patches, verify, fail-closed. **Dit is een derde opslagroute** naast Save week en Save team (AGENTS: nu de enige twee): akkoord van Eddy nodig.

### Weekly Hours en Fill week per dag
- Een cel is voor een **nieuwe** dag alleen invulbaar als de dag binnen een periode van dit project valt (nu: de hele week). Bestaande uren blijven corrigeerbaar. Save week controleert hetzelfde per dag (nu per week).
- Fill week vult alleen dagen binnen de periode (dat doet hij al per dag) en **slaat een dag over als de medewerker die dag uren op een ander project heeft**.

### Controles over projecten heen
- **Amber** (opslaan mag): dezelfde medewerker heeft dezelfde dag uren op twee projecten. Op Weekly Hours bij laden en bij Save, met de naam van het andere project.
- **Rood** (niets opslaan): dagtotaal over alle projecten > 24.
- Hiervoor moet de app per week de uren van de medewerker op **andere** projecten kunnen lezen. Hours is nu alleen per project te filteren (EntryKey begint met het project-ID). Twee opties (beslispunt B2):
  - **B2a (aanbevolen):** nieuwe tekstkolom `WorkerKey` (= worker-ID) op Hours, geïndexeerd, door Save week gevuld bij nieuwe en gewijzigde regels; één gedelegeerde read `WorkerKey in de week-medewerkers && 'Work Date' in de week` (per medewerker of per batch). Oude regels hebben hem niet; voor controles op lopende weken is dat genoeg (eventueel later een eenmalige vulflow).
  - **B2b:** zonder nieuwe kolom: alle Hours van de week (alle projecten) op datumbereik lezen. Simpel, maar valt bij meer dan 500 regels per week onder de 500-grens: dan blokkeren (fail-closed) of overslaan met amber.

### Rapporten
Geen wijziging: Hours Summary en Week report blijven per project. Lege rijen van medewerkers met een periode verdwijnen in de overgangsweken, omdat periodes nu per dag kloppen (overlap per dag in plaats van per week; kleine aanpassing in de rijselectie).

### Beslispunten voor Eddy
| # | Vraag | Voorstel |
|---|---|---|
| B1 | Derde opslagroute "Save move" toestaan? | Ja, met hetzelfde patroon als Save team |
| B2 | Uren over projecten lezen: nieuwe kolom WorkerKey (B2a) of datumbereik (B2b)? | B2a |
| B3 | Aanvinken op Project / team blijft per week (maandag-zondag)? | Ja; per dag alleen via Move / assign |
| B4 | Amber bij dezelfde dag op twee projecten: alleen melden, of Save blokkeren tot bevestigd? | Alleen melden |
| B5 | Moet de terugkeer na de einddag ook bij Temporary kunnen (A blijft dan toch open)? | Niet nodig: bij Temporary blijft A open |

### Tests (bij de bouw)
Test-SaveRegression (nieuwe opslagroute, beslissingen per dag, fail-closed), Test-WeeklyCalculations (overlap per dag), TP-MOVE-01 in TESTPLAN op TEST-000: één dag elders, verhuizing midweek 3 weken met terugkeer, amber dubbele dag, rood > 24.
