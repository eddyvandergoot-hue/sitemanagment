# Gedeelde opgeslagen gegevens

SharePoint-site: https://geacloud.sharepoint.com/sites/GEASiteManagment

| Appbron | Bestaande SharePoint-lijst-ID |
| --- | --- |
| Projects | ec185c2d-a0e4-4a88-8fdb-b5ce129acfb5 |
| Employers | ef915905-0718-4dd6-bbc9-1b242e4ec9c4 |
| Workers | f19b7215-4e7a-48d7-a887-7829f809a814 |
| Project Workers | 930aa510-0fd7-428a-b349-1560e1db9d22 |
| Hours | 96afab9c-9b0a-4a36-99e9-46a2eed98b81 |

Deze verwijzingen zijn lokaal vergeleken met de oorspronkelijke .msapr, de export Site Managment_VS.msapp en de nieuwste testbuild. De volledige DataSources.json van de oorspronkelijke .msapr is exact behouden. Dit bewijst de bronverwijzingen, niet de runtime-authenticatie of gebruikersrechten na import.

SharePoint bewaart stamgegevens, project-/teamkoppelingen en uren. colSelectedWorkers en colCurrentTeamAssignments zijn tijdelijke selectiecaches; colWeekStored, colWeekRows en colWeekOriginal zijn tijdelijke werkweekcaches; colReportFacts en colReportRows zijn tijdelijke rapportcaches. Deze caches worden per app/sessie opgebouwd. Project, team, ISO-jaar, KW en rapportfilters zijn schermselecties, geen vervanging van opgeslagen gegevens. Een nieuwe build hoeft de vorige schermselectie niet te onthouden: kies dezelfde waarden om dezelfde opgeslagen gegevens terug te lezen.

De testapp gebruikt bestaande lijsten en dezelfde expliciete Save-/Save team-acties. Wie daarin opslaat, wijzigt dus dezelfde SharePoint-gegevens. De nieuwe laadacties maken geen gegevens aan en repareren geen sleutels. Afwijkende of ontbrekende sleutels worden gemeld; opslaan wordt zo nodig geblokkeerd.

# Korte controle zonder gegevens te wijzigen

1. Importeer de nieuwste testbuild als aparte app. Gebruik/toestaan de bestaande SharePoint-verbinding met een account dat toegang tot bovenstaande site/lijsten heeft. Maak geen nieuwe lijsten of vervangende records aan. Controleer App checker en start de app opnieuw vanaf Screen1.
2. Kies een bekend project en team. Bestaande medewerkers moeten verschijnen en eerder opgeslagen teamleden moeten automatisch aangevinkt worden. De status meldt hoeveel opgeslagen koppelingen zijn teruggelezen. Klik niet op Save team.
3. Open Weekly Hours, kies een ISO-jaar/KW waarvoor je de opgeslagen uren kent. De dagvelden moeten de bestaande waarden tonen; de status meldt het aantal teruggelezen dagregels. Wijzig niets en klik niet op Save.
4. Ga terug naar project/team en open Hours Summary. Kies hetzelfde project en dezelfde week; vergelijk de weektotalen met de opgeslagen dagregels en controleer de juiste werkgever.
5. Sluit en start de testapp opnieuw. Kies dezelfde project-/team-/jaar-/weekwaarden: de gegevens moeten weer verschijnen zonder invoer of opslaan. Bij fouten: geef de exacte status-/Notify-melding, de gekozen waarden en eventuele App Checker-/Monitor-fout door. Voer geen vervangende gegevens in.

Studio-import, authenticatie, echte broninhoud, delegatie en deze runtime-test zijn nog niet uitgevoerd. De lokale terugleesvoorbeelden gebruiken synthetische waarden uitsluitend in geheugen; er is niets naar SharePoint geschreven.
