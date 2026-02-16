# Deployment Pipeline Fix

## Probleem

De GitLab CI deployment pipeline faalde zonder duidelijke error message met `ERROR: Job failed: exit code 1`.

### Root Cause

Het deployment script ([scripts/deploy.sh](scripts/deploy.sh)) probeert `sudo systemctl` commando's uit te voeren op regels 329 en 338 om de applicatie te herstarten:

```bash
sudo systemctl reload hgv-signing.service  # regel 329
sudo systemctl start hgv-signing.service   # regel 338
```

Echter:
1. Het script wordt uitgevoerd als de `hgv-signing` user via GitLab CI
2. De `hgv-signing` user had geen sudo rechten voor systemctl commando's
3. Het script heeft `set -euo pipefail` (regel 19), dus het stopt direct bij de eerste fout
4. Omdat het via SSH draait, wordt de error niet getoond in de GitLab CI logs

## Oplossing

Er zijn twee onderdelen aan de fix:

### 1. Sudoers Configuratie (Server-side)

De server heeft nu een sudoers configuratie nodig die:
- De `hgv-signing` user toestaat systemctl commando's uit te voeren
- De SSH/deployment user toestaat scripts uit te voeren als de `hgv-signing` user

**Voor nieuwe servers:** Dit is nu ingebouwd in [scripts/prepare_server.sh](scripts/prepare_server.sh) (Phase 17).

**Voor bestaande servers:** Draai het fix script:

```bash
sudo bash scripts/fix_sudoers.sh
```

Dit script vraagt om je SSH username (de `SSH_USER` uit GitLab CI variabelen) en configureert de juiste permissies.

### 2. Pipeline Update (GitLab CI)

De [.gitlab-ci.yml](.gitlab-ci.yml) is aangepast om het deployment script als de `hgv-signing` user uit te voeren:

**Voorheen:**
```yaml
- ssh "${SSH_USER}@${SSH_SERVER_HOST}" "cd /opt/hgv-signing && CI_COMMIT_SHA=${CI_COMMIT_SHA} CI_PROJECT_DIR=/tmp/hgv-signing-deploy-${CI_COMMIT_SHA} bash /tmp/hgv-signing-deploy-${CI_COMMIT_SHA}/scripts/deploy.sh"
```

**Nu:**
```yaml
- ssh "${SSH_USER}@${SSH_SERVER_HOST}" "cd /opt/hgv-signing && sudo -u hgv-signing CI_COMMIT_SHA=${CI_COMMIT_SHA} CI_PROJECT_DIR=/tmp/hgv-signing-deploy-${CI_COMMIT_SHA} bash /tmp/hgv-signing-deploy-${CI_COMMIT_SHA}/scripts/deploy.sh"
```

## Stappen om te fixen

### Voor bestaande deployments:

1. **Op de server:**
   ```bash
   cd /pad/naar/repo
   sudo bash scripts/fix_sudoers.sh
   ```

   Het script zal vragen naar je SSH username. Dit is de waarde van `SSH_USER` in je GitLab CI variabelen.

2. **In je repository:**
   - De wijzigingen in `.gitlab-ci.yml` zijn al doorgevoerd
   - Push een nieuwe tag om een deployment te triggeren
   - De deployment zou nu moeten werken!

### Voor nieuwe deployments:

Gewoon de normale deployment procedure volgen:
1. Run `sudo bash scripts/prepare_server.sh` (bevat nu de sudoers configuratie)
2. Voeg de deployment user toe (zie output van prepare_server.sh)
3. Deploy via GitLab CI

## Verificatie

Na het draaien van het fix script, check of de configuratie correct is:

```bash
# Check sudoers file
sudo cat /etc/sudoers.d/hgv-signing

# Test of de deployment user kan sudo als hgv-signing
sudo -u JOUW_SSH_USER sudo -u hgv-signing whoami
# Zou "hgv-signing" moeten printen

# Test of hgv-signing systemctl kan draaien
sudo -u hgv-signing sudo systemctl status hgv-signing.service
# Zou de service status moeten tonen
```

## Bestanden gewijzigd

- [scripts/prepare_server.sh](scripts/prepare_server.sh) - Toegevoegd Phase 17 voor sudoers configuratie
- [.gitlab-ci.yml](.gitlab-ci.yml) - Deployment script draait nu met `sudo -u hgv-signing`
- [scripts/fix_sudoers.sh](scripts/fix_sudoers.sh) - Nieuw quick-fix script voor bestaande servers
- [DEPLOYMENT_FIX.md](DEPLOYMENT_FIX.md) - Deze documentatie

## Security Overwegingen

De sudoers configuratie is veilig omdat:
1. Alleen specifieke systemctl commando's zijn toegestaan voor de service
2. De deployment user kan alleen als `hgv-signing` user runnen (niet als root)
3. Het sudoers bestand heeft de juiste permissies (440) en wordt gesyntax-checked
4. De configuratie is geïsoleerd in een apart bestand (`/etc/sudoers.d/hgv-signing`)

## Troubleshooting

Als de deployment nog steeds faalt:

1. **Check sudoers configuratie:**
   ```bash
   sudo cat /etc/sudoers.d/hgv-signing
   sudo visudo -c -f /etc/sudoers.d/hgv-signing
   ```

2. **Check SSH user:**
   Zorg dat de juiste username is gebruikt. Check je GitLab CI variabelen:
   - Settings → CI/CD → Variables → `SSH_USER`

3. **Test handmatig:**
   ```bash
   # SSH naar de server als je deployment user
   ssh SSH_USER@SERVER

   # Test of je als hgv-signing kunt runnen
   sudo -u hgv-signing whoami

   # Test systemctl permissies
   sudo -u hgv-signing sudo systemctl status hgv-signing.service
   ```

4. **Check logs:**
   Als het script nu wel errors toont, check:
   ```bash
   sudo journalctl -u hgv-signing.service -n 50
   ```
