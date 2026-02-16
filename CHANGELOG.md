# Changelog

Alle opvallende wijzigingen in dit project worden gedocumenteerd in dit bestand.

Het formaat is gebaseerd op [Keep a Changelog](https://keepachangelog.com/nl/1.0.0/),
en dit project volgt [Semantic Versioning](https://semver.org/lang/nl/).

## [v2.1.3]

### Verwijderd
- **Automatische reply-to van uitnodiging aanmaker**: Mails stellen niet langer automatisch de aanmaker van de uitnodiging in als reply-to adres. Reply-to wordt nu alleen ingesteld wanneer dit expliciet geconfigureerd is in de instellingen.

## [v2.1.2] - 2026-01-13

### Verwijderd
- **Database backup functionaliteit**: Verwijderd wegens niet-functioneel
  - Verwijderd: controllers, models, jobs, views en services voor database export/import
  - Verwijderd: routes en locale strings
  - Migratie om database_exports en database_imports tabellen te droppen

## [v2.1.1] - 2026-01-13

### Opgelost
- **Deployment migration lock conflict**: Fix voor `ActiveRecord::ConcurrentMigrationError` tijdens deployment
  - Deploy script stopt nu de applicatie voordat database migraties worden uitgevoerd
  - Voorkomt conflict met automatische migraties in `config/initializers/migrate.rb`
  - App wordt opnieuw gestart na succesvolle migratie

## [v2.1.0] - 2026-01-13

### Opgelost
- **URL generatie voor reverse proxy/tunnel setups**: Fix voor Cloudflare Tunnel, nginx, etc.
  - URLs bevatten niet langer de interne PORT wanneer FORCE_SSL is ingeschakeld
  - Dit lost broken images/assets op bij gebruik van een reverse proxy die SSL termineert

## [2.0.0] - 2026-01-13

### Gewijzigd - Deployment Migratie
- **Migratie van Docker naar bare-metal deployment**
  - Volledige verwijdering van Docker/Docker Compose afhankelijkheden
  - Native installatie op Ubuntu 22.04 LTS
  - Systemd service management voor applicatie lifecycle
  - PostgreSQL 15 native installatie (niet gecontainerized)
  - Embedded Redis + Sidekiq via Puma plugins (default mode)
  - PDFium en ONNX Runtime als system libraries

- **Nieuwe deployment strategie**
  - Capistrano-style release management met timestamped directories
  - Atomic symlink switching voor zero-downtime deployments
  - Automatische health check met fallback naar vorige versie bij failure
  - Behoud van laatste 5 releases voor snelle rollback
  - Graceful restart via Puma phased restart (SIGUSR1 signal)

- **Nieuwe scripts**
  - `scripts/prepare_server.sh`: First-time server setup met alle dependencies
    - Installeert Ruby 3.4.2 via rbenv
    - Installeert Node.js 20.x en Yarn
    - Installeert PostgreSQL 15
    - Installeert PDFium en ONNX Runtime libraries
    - Download en merge fonts (GoNotoKurrent, DancingScript, etc.)
    - Configureert PostgreSQL database met gegenereerde credentials
    - Installeert systemd service
    - Setup log rotation en cron-based backups
  - `scripts/deploy.sh`: Deployment met health check en auto-rollback
    - Capistrano-style release directories
    - Bundle install en asset precompilation
    - Database backup voor elke deployment
    - Database migrations met rollback bij failure
    - Health check op `/up` endpoint (30 retries)
    - Automatische rollback bij gefaalde health check
    - Cleanup van oude releases (keep 5)
  - `scripts/rollback.sh`: Handmatige rollback naar vorige release
    - Interactive bevestiging
    - Symlink switch naar previous release
    - Service restart met health check verificatie
    - Waarschuwing voor database migrations
  - `deploy/hgv-signing.service`: Systemd service definitie
    - Graceful restart support (ExecReload met SIGUSR1)
    - Security hardening (NoNewPrivileges, ProtectSystem)
    - Resource limits (LimitNOFILE, LimitNPROC)
    - Logging naar journalctl

- **CI/CD pipeline aanpassingen**
  - GitLab CI: verwijderd Docker build stage
  - Nieuwe test stage met native Ruby/PostgreSQL
    - PDFium en ONNX Runtime installatie in CI
    - RSpec tests met JUnit reporting
    - Rubocop code quality checks
  - Deployment via SSH + rsync naar productieserver
    - Code transfer naar `/tmp/hgv-signing-deploy-${CI_COMMIT_SHA}`
    - Remote execution van deploy.sh als hgv-signing user
    - Automatische cleanup van temp directories
  - Automatische rollback bij gefaalde deployment
  - Manual rollback job in pipeline (manual trigger)

- **Operationele verbeteringen**
  - Automatische dagelijkse database backups (02:00, 30 dagen retentie)
    - PostgreSQL pg_dump (custom format)
    - Backup van attachments en storage
    - Cron job: `/usr/local/bin/hgv-signing-backup`
  - Log rotation voor applicatie logs (30 dagen retentie)
  - Gestructureerde shared directories voor persistent data
    - `/opt/hgv-signing/shared/{log,tmp,storage,attachments,fonts,backups}`
  - Database backup voor elke deployment (safety net voor migrations)
  - Environment configuratie in `/etc/hgv-signing/hgv-signing.env`

### Verwijderd
- **Docker-gerelateerde bestanden**
  - `Dockerfile` (multi-stage build)
  - `Dockerfile.dev` (development image)
  - `docker-compose.yml` (production)
  - `docker-compose.dev.yml` (development)
  - `docker-compose.prod.local.yml` (local production testing)
  - `.dockerignore`
  - `scripts/test_registry.sh` (GitLab Container Registry testing)
  - `scripts/cleanup_registry.sh` (Registry cleanup)
  - Docker-specifieke logica uit `run_tests.sh`
  - Container-specific deployment logica uit `.gitlab-ci.yml`

### Documentatie
- **README.md**: Vervangen Docker instructies met bare-metal setup
  - Toegevoegd: Server requirements en preparation guide
  - Toegevoegd: Deployment en rollback procedures
  - Toegevoegd: Monitoring en backup instructies
  - Toegevoegd: Nginx reverse proxy configuratie voorbeeld
  - Toegevoegd: Directory structuur documentatie
  - Verwijderd: Docker Compose en Docker Standalone secties
- **CHANGELOG.md**: Deze entry met volledige migratie details

## [1.0.2] - 2026-01-10

### Toegevoegd
- **Database backup functionaliteit**: Automatische backup service toegevoegd voor database imports
  - Backup service (`lib/database/backup_service.rb`) voor het maken en herstellen van backups
  - Automatische backup vóór database imports om dataverlies te voorkomen
  - Backup bevat database dump (PostgreSQL custom format) en ActiveStorage attachments
  - Automatische cleanup: behoudt laatste 3 backups
  - Rollback functionaliteit: automatisch herstel naar backup bij gefaalde imports
  - Backup metadata met timestamp, database naam en attachments count
  - Database export/import functionaliteit met validatie en error handling
  - UI toegevoegd in database settings voor export en import beheer

### Verwijderd
- **Sentry error tracking**: Sentry SDK volledig verwijderd uit de applicatie
  - Gems verwijderd: `sentry-rails`, `sentry-ruby`
  - Configuratie bestand `config/initializers/sentry.rb` verwijderd
  - Sentry DSN verwijzingen verwijderd uit environment variabelen documentatie
  - WebMock allow regel voor Sentry verwijderd uit test configuratie

## [1.0.1] - 2025-12-14

### Toegevoegd
- **Sentry error tracking**: Sentry SDK toegevoegd voor error monitoring en performance tracking
  - Gems toegevoegd: `stackprof`, `sentry-ruby`, `sentry-rails`
  - Configuratie in `config/initializers/sentry.rb` met DSN
  - Breadcrumbs logging voor ActiveSupport en HTTP requests
  - Log forwarding naar Sentry ingeschakeld
  - Performance optimalisaties voor productie:
    - Sample rates ingesteld op 10% voor traces en profiles in productie (100% in development)
    - Automatische async verwerking via Sidekiq om requests niet te blokkeren
    - Filtering van health check endpoints om ruis te verminderen

## [1.0.0]
###Eerste stabiele versie van de app.
Bèta-label verwijderd en klaar voor productiegebruik.

### Toegevoegd
- **Sentry error tracking**: Sentry SDK toegevoegd voor error monitoring en performance tracking
  - Gems toegevoegd: `stackprof`, `sentry-ruby`, `sentry-rails`
  - Configuratie in `config/initializers/sentry.rb` met DSN
  - Breadcrumbs logging voor ActiveSupport en HTTP requests
  - Log forwarding naar Sentry ingeschakeld
  - Performance optimalisaties voor productie:
    - Sample rates ingesteld op 10% voor traces en profiles in productie (100% in development)
    - Automatische async verwerking via Sidekiq om requests niet te blokkeren
    - Filtering van health check endpoints om ruis te verminderen

## [0.2.12-beta] - 2025-12-08

### Toegevoegd
- **Telefoonnummer lengte validatie**: Validatie toegevoegd voor telefoonnummer velden op basis van landcode
  - Frontend validatie in `phone_step.vue` controleert aantal cijfers per geselecteerde landcode
  - Backend validatie in `submit_values.rb` voorkomt opslaan van ongeldige telefoonnummers
  - Mapping bestanden voor telefoonnummer lengtes per landcode (`phone_lengths.js` en `phone_lengths.rb`)
  - Dynamische foutmeldingen met landcode-specifieke lengte eisen
  - Validatie werkt voor veelvoorkomende landen met fallback naar ITU-T E.164 standaard (7-15 cijfers)

## [0.2.11-beta] - 2025-12-05

### Opgelost
- **Editor rol mappen zichtbaarheid**: Editor gebruikers kunnen nu mappen zien op het dashboard
- **Editor rol upload optie**: Upload dropzone wordt niet meer getoond voor editor gebruikers

### Gewijzigd
- **Editor rol permissies**: Editor rol heeft nu read rechten voor TemplateFolder toegevoegd

## [0.2.10-beta] - 2025-12-05

### Gewijzigd
- **Landingspagina taal**: Landingspagina gebruikt nu altijd Nederlands (nl-NL), ongeacht browser taalinstellingen

### Verwijderd
- **QR code functionaliteit**: QR code optie volledig verwijderd uit handtekening stap
  - QR code knop en overlay verwijderd
  - Alle QR code gerelateerde methodes verwijderd (showQr, hideQr, checkSignature, etc.)
  - IconQrcode import verwijderd

## [0.2.9-beta] - 2025-12-05

### Verwijderd
- **QR code functionaliteit**: QR code optie volledig verwijderd uit handtekening stap

## [0.2.8-beta] - 2025-12-05

### Opgelost
- **Handtekening synchronisatie**: Fix voor synchronisatie tussen mobiel en desktop browser
- **Opmerking veld formatting**: Behoud enters in opmerking veld bij uitnodigen extra partij

### Gewijzigd
- **QR code checkSignature**: Verbeterde error handling en correcte parameter encoding

## [0.2.7-beta] - 2025-12-05

### Opgelost
- **RuboCop offenses**: Alle code quality issues opgelost in submit_form_invite_controller
  - ABC size verlaagd door methodes op te splitsen
  - Naming conventions verbeterd (is_under_16_required? → under_16_required?)
  - Style improvements (modifier if statements, blank? in plaats van present?)

### Toegevoegd
- **Voorwaardelijke verplichting ouder email**: Email van ouder is nu verplicht wanneer iemand onder 16 is
  - Frontend: invite_form.vue controleert leeftijd en maakt email verplicht
  - Backend: submit_form_invite_controller.rb valideert leeftijd en vereist email
  - Automatische detectie van geboortedatum veld via conditions
- **Docker Chromium**: Chromium toegevoegd aan Dockerfile.dev voor volledige test coverage

## [0.2.6-beta] - 2025-12-04

### Opgelost
- **Conditional field evaluatie**: Volledig gefixed om overeen te komen met backend logica
  - OR-operaties worden nu correct geëvalueerd volgens backend implementatie (`acc.pop || result`)
  - Fix voor "Complete" button die disabled bleef bij conditional fields
  - Condition evaluatie voor untouched fields verbeterd
  - Explicit lege waarden worden nu correct behandeld
  - Condition grouping logica voor 'or' operaties verfijnd
- **2FA test**: Gefixed door te wachten op completed form message met CSS selector
- **RuboCop**: Array alignment offense opgelost in templates_controller
- **Ruby versie**: Teruggedraaid naar 3.4.2 voor CI compatibiliteit

### Gewijzigd
- **Logo**: HGV logo toegevoegd en DocuSeal logo's vervangen
  - Wit schild toegevoegd aan HGV logo
  - Logo wijzigingen later teruggedraaid naar originele versie
- **Documentatie**:
  - Uitgebreide gebruikersdocumentatie toegevoegd voor admin en editor rollen
  - SECURITY policy document verwijderd
  - DEVELOPMENT documentatie verwijderd
  - Embedding en wiki documentatie pagina's verwijderd
- **Postcode validatie**: Nederlandse postcode regex gebruikt voor ZIP validatie
- **Struct field mapping**: Fix voor description in recipients form
- **hasSignatureFields check**: Gebruikt nu fields in plaats van stepFields

### Commits
- `2ae17991` - Update CHANGELOG for 0.2.6-beta release (2025-12-04)
- `97976378` - Fix 2FA test - wait for completed form message (2025-12-04)
- `558fa0a8` - Fix conditional field evaluation to match backend logic (2025-12-04)
- `f4e584a8` - WIP: Debug conditional field visibility issue (2025-12-04)
- `e1bc1155` - Trigger CI pipeline (2025-12-04)
- `0a0207ed` - Fix condition evaluation for untouched fields (2025-12-04)
- `6dd2b80b` - Fix condition evaluation - only check this.values for touched fields (2025-12-04)
- `13fd18e2` - Fix condition evaluation for explicitly empty fields (2025-12-04)
- `166f2c91` - Refine conditional field grouping logic for 'or' operations (2025-12-04)
- `db3870d7` - Fix conditional field evaluation logic for 'or' operations (2025-12-04)
- `284bbcb1` - Revert Ruby version to 3.4.2 for CI compatibility (2025-12-04)
- `b31f4747` - Fix RuboCop alignment issue and update Ruby version to 3.4.7 (2025-12-04)
- `055a8f3e` - Fix conditie evaluatie en RuboCop array alignment (2025-12-03)
- `f90ef5de` - Vereenvoudig conditie evaluatie logica (2025-12-03)
- `1c4d4184` - Revert conditie evaluatie: evalueer lege waarden normaal (2025-12-03)
- `2a4c59da` - Fix conditie evaluatie: behandel lege waarden als niet-ingevuld (2025-12-03)
- `aec995db` - Fix conditie evaluatie: alleen return true voor niet-ingevulde velden (2025-12-03)
- `12ed24d7` - Verbeter emptyValueRequiredStep logica met duidelijke commentaar (2025-12-03)
- `3054bccc` - Fix RuboCop array alignment offense (2025-12-03)
- `4ef16810` - Fix RuboCop offenses en Struct field mapping (2025-12-03)
- `b843a66a` - Fix Struct field mapping en emptyValueRequiredStep voor conditional fields (2025-12-03)
- `bc84c493` - Fix Struct field mapping voor description in recipients form (2025-12-03)
- `72ca4c35` - Voeg beschrijving toe voor invite submitters en fix verschillende issues (2025-12-03)
- `7c393e5d` - Use Dutch postcode regex for ZIP validation (2025-12-03)
- `1309d73a` - Revert all logo changes to original version (2025-12-03)
- `8c4bb94f` - Change diagonal band to white in HGV logo (2025-12-03)
- `f0fef6bd` - Fix hasSignatureFields check to use fields instead of stepFields (2025-12-03)
- `1ccc0ebe` - Revert HGV logo to original light blue shield (2025-12-03)
- `84fc23e3` - Add white background to HGV logo shield (2025-12-03)
- `61aeecd4` - Replace DocuSeal logos with HGV logo (2025-12-03)
- `a5a470cf` - Remove SECURITY policy document as requested (2025-12-03)
- `873bedc7` - Remove DEVELOPMENT documentation as requested (2025-12-03)
- `3e258db9` - Sync Gemfile.lock after removing omniauth dependencies (2025-12-03)
- `b82cce1c` - Remove embedding documentation pages as requested (2025-12-03)
- `906b47c2` - Remove wiki documentation pages as requested (2025-12-03)
- `3e7042e8` - Add comprehensive user documentation for admin and editor roles (2025-12-03)
- `21aa309f` - Add comprehensive changelog with all commits per tag (2025-12-03)

---

## [0.2.5-beta] - 2025-12-03

### Toegevoegd
- **Leeftijdsvoorwaarden voor datumvelden**: Mogelijkheid om voorwaarden toe te voegen op basis van leeftijd (bijv. "als persoon onder 18 jaar is")
  - Nieuwe acties: `age_less_than` en `age_greater_than` voor datumvelden
  - Leeftijd wordt automatisch berekend op basis van geboortedatum
  - Ondersteuning voor meerdere talen (NL, EN, ES, IT, PT, FR, DE)

### Gewijzigd
- **Pro-vermelding verwijderd**: Conditions modal is nu volledig beschikbaar zonder pro-restricties
- **Downloadknop verwijderd**: Uit submit form tijdens en na het ondertekenen (weigerknop blijft staan)

### Opgelost
- **QR-code handtekening flow**: Gefixed voor mobiele apparaten - handtekeningen worden nu correct gedetecteerd na upload
- **RSpec test**: Dashboard template filtering test aangepast voor testing mode accounts
- **RuboCop offenses**: Alle style issues opgelost (method complexity, indentation, duplicate branches)

### Verbeterd
- **Code refactoring**: Controllers opgesplitst voor betere onderhoudbaarheid
  - `SubmissionsController#create` opgesplitst in kleinere helper methodes
  - `SubmittersController#update` opgesplitst in kleinere helper methodes
  - `ApplicationController#with_locale` duplicate branch opgelost

### Commits
- `c62e841e` - Add age-based conditions for date fields and various improvements (2025-12-03)

---

## [0.2.4-beta] - 2025-12-02

### Gewijzigd
- **Email input interface**: Hersteld naar oude stijl met plus button voor meerdere adressen
  - Dynamische lijst met individuele email input velden
  - Plus button om extra email velden toe te voegen
  - Ondersteuning voor zowel oude als nieuwe email parameter formaten

### Commits
- `945d363e` - Restore old email input interface with plus button for multiple addresses (2025-12-02)

---

## [0.2.3-beta] - 2025-12-02

### Opgelost
- **CI/CD**: Brakeman gem verplaatst van development naar test group

### Gewijzigd
- **Editor restricties**:
  - Account en Gebruiker instellingen verborgen voor editors
  - Email bewerken uitgeschakeld voor editors
  - Email verzenden altijd verplicht en niet uit te schakelen
  - Volgorde behouden altijd aan en niet uit te schakelen
  - "Gedetailleerd" en "Lijst uploaden" opties verborgen voor editors

### Commits
- `ef6621f7` - Fix CI: Move brakeman from development to test group (2025-12-02)
- `030b962a` - Editor restrictions: hide account/users settings, disable email editing, enforce email sending and preserve order (2025-12-02)

---

## [0.2.2-beta] - 2025-12-02

### Gewijzigd
- **Deploy job**: Alleen deployen op tags, niet op elke master push
- **SSO**: Enable/disable optie toegevoegd en error handling verbeterd
- **Taal selectie**: Verborgen op landingspagina, gebruikt alleen browser instellingen

### Opgelost
- **Redirect loop**: Voor editor gebruikers opgelost
- **Viewer rol**: Verwijderd

### Commits
- `75220381` - Revert deploy job: alleen deployen op tags, niet op elke master push (2025-12-02)
- `51d90304` - Pas deploy job aan om ook op master branch te draaien, niet alleen op tags (2025-12-02)
- `b27c30bb` - Voeg enable/disable optie toe voor SSO en verbeter error handling (2025-12-02)
- `a872f5be` - Verberg taal keuze op landingspagina, gebruik alleen browser instellingen (2025-12-02)
- `9ed930f8` - Fix redirect loop voor editor gebruikers en verwijder viewer rol (2025-12-02)

---

## [0.2.1-beta] - 2025-12-02

### Opgelost
- **RSpec test**: Overgebleven Download button assertion verwijderd
- **CI/CD errors**: RuboCop, ESLint en RSpec tests gefixed

### Gewijzigd
- **Bevestigpagina**: Download/kopie knoppen verwijderd en nieuwe tekst toegevoegd
- **Favicon**: Alle oude Docuseal favicon bestanden verwijderd en expliciete links toegevoegd
- **Completed pagina**: Nieuwe tekst, download/kopie knoppen verwijderd, footer aangepast
- **Favicon**: HGV-logo SVG gebruikt en oude Docuseal iconen verwijderd
- **Email footer**: 'Verzonden met HGV Signing' vervangen door automatische-no-reply melding
- **UI**: Toggle om auditlogboek-PDF aan e-mails toe te voegen verwijderd
- **URLs**: Poort verwijderd uit URLs bij HTTPS (standaard poort 443)
- **Parameters**: Originele parameter namen behouden voor fill_submitter_fields

### Commits
- `be1e6889` - Fix laatste RSpec test: verwijder overgebleven Download button assertion (2025-12-02)
- `edb4b3c6` - Fix CI/CD errors: RuboCop, ESLint en RSpec tests (2025-12-02)
- `ca894e1c` - Bevestigpagina: verwijder download/kopie knoppen en voeg nieuwe tekst toe (2025-12-02)
- `f811f67a` - Favicon: verwijder alle oude Docuseal favicon bestanden en voeg expliciete links toe (2025-12-02)
- `e5275a5a` - Completed pagina: nieuwe tekst, verwijder download/kopie knoppen, pas footer aan (2025-12-02)
- `9db9dcad` - Favicon: gebruik HGV-logo SVG en verwijder oude Docuseal iconen (2025-12-02)
- `83599129` - Email footer: vervang 'Verzonden met HGV Signing' door automatische-no-reply melding (2025-12-02)
- `24fd6846` - UI: verwijder toggle om auditlogboek-PDF aan e-mails toe te voegen (2025-12-02)
- `93958b6c` - Fix: verwijder poort uit URLs bij HTTPS (standaard poort 443) (2025-12-02)
- `df752737` - Fix: behoud originele parameter namen voor fill_submitter_fields (2025-12-02)
- `70b5c45b` - Fix ESLint en RuboCop fouten (2025-12-02)

---

## [0.2.0-beta] - 2025-12-02

### Gewijzigd
- **Taal selector**: Verwijderd onder inlog formulier
- **Taal selector**: Op landingspagina gefixed en vertalingen toegevoegd voor alle talen

### Opgelost
- **Tests**: Button disabled check in plaats van alert verwachting
- **CI/CD test failures**: Opgelost
- **Multi select encoding**: Alleen signature/initials toevoegen aan FormData
- **CI spec timeout**: Timeout en signature submit gefixed
- **Rubocop**: redirect_back_or_to gefixed

### Toegevoegd
- **Rollen**: Editor en admin rollen toegevoegd

### Commits
- `710f94f6` - Verwijder taal selector onder inlog formulier (2025-12-01)
- `e329ef62` - Fix test: check if button is disabled instead of expecting alert (2025-12-01)
- `c406d5e6` - Fix CI/CD test failures (2025-12-01)
- `d6176a45` - Fix taal selector op landingspagina en voeg vertalingen toe voor alle talen (2025-12-01)
- `7aa58452` - Fix CI/CD issues en voeg rollen toe (2025-12-01)
- `ae53a6aa` - Fix multi select encoding by only appending signature/initials to FormData (2025-12-01)
- `fdad9b27` - Fix CI spec timeout, signature submit and rubocop redirect_back_or_to (2025-12-01)

---

## [0.1.0-beta] - 2025-12-02

### Opgelost
- **Test timeout**: Verhoogd naar 60 seconden voor document upload
- **Rubocop**: Gemfile ordering gefixed (numo-narray, lograge)
- **PDF generatie en download**: Issues opgelost
- **Download functionaliteit**: APP_URL, HOST en poort configuratie toegevoegd
- **Ferrum monkey patch**: Variabele argumenten geaccepteerd
- **Rubocop lint errors**: Opgelost
- **Ferrum error**: Opgelost en CI performance geoptimaliseerd
- **Ferrum/Cuprite errors**: Browser opties toegevoegd en cleanup verbeterd
- **JavaScript en Ruby lint errors**: Opgelost
- **Database query**: Voorkomen tijdens asset precompilatie in omniauth_providers

### Gewijzigd
- **Logo**: DocuSeal logo vervangen door HGV logo in:
  - logo_new.png
  - Audit report
  - Stamp

### Commits
- `7806e3ac` - Verhoog timeout voor document upload test naar 60 seconden (2025-11-30)
- `31b03c58` - Fix rubocop: verplaats numo-narray naar juiste alfabetische positie (2025-11-30)
- `a9d81e43` - Fix rubocop: verplaats lograge naar juiste alfabetische positie (2025-11-30)
- `977b1fc1` - Fix rubocop Gemfile ordering en verhoog test timeout voor file upload (2025-11-30)
- `429b704c` - Fix Rubocop offenses and test timeout (2025-11-30)
- `40c94213` - Fix CI/CD pipeline errors (2025-11-30)
- `41e43714` - Replace DocuSeal logo with HGV logo in logo_new.png (2025-11-30)
- `2c6bab99` - Replace DocuSeal logo with HGV logo in audit report (2025-11-30)
- `ed73d676` - Replace DocuSeal logo with HGV logo in stamp (2025-11-30)
- `ab08cd52` - Fix PDF generation and download issues (2025-11-30)
- `90de32ed` - Fix download functionality: add APP_URL, HOST and port configuration (2025-11-30)
- `96f5ffc5` - Fix Ferrum monkey patch to accept variable arguments (2025-11-30)
- `77489b33` - Fix remaining Rubocop lint errors (2025-11-30)
- `2f2c2ae0` - Fix Rubocop lint errors (2025-11-30)
- `2e3ae809` - Fix Ferrum error and optimize CI performance (2025-11-30)
- `fe89f97e` - Fix Ferrum/Cuprite errors in CI: add browser options and improve cleanup (2025-11-30)
- `c39ca32e` - Fix: Los resterende Rubocop errors op (2025-11-30)
- `1940aab9` - Fix: Los Rubocop errors op en verwijder file output voor tests (2025-11-30)
- `ee7ade69` - Fix: Los resterende Rubocop errors op (2025-11-30)
- `197d2225` - Fix: Los JavaScript en Ruby lint errors op (2025-11-30)
- `50ac1695` - Fix: Voorkom database query tijdens asset precompilatie in omniauth_providers (2025-11-30)

---

## [0.0.1-beta] - 2025-11-28

### Toegevoegd
- **Rebrand naar HGV Signing**: Volledige rebrand van DocuSeal naar HGV Signing
- **Logo/Favicon**: HGV logo en favicon toegevoegd
- **UI cleanup**: Oude DocuSeal verwijzingen verwijderd
- **Vertalingen**: Nederlandse vertalingen toegevoegd
- **Development Docker setup**: Docker configuratie voor development

### Verwijderd
- **API/Webhook functionaliteit**: Volledig verwijderd
- **Storage settings**: Verwijderd
- **SSO**: Gewijzigd van originele implementatie naar OAuth
- **.github directory**: Verwijderd

### Gewijzigd
- **Account configs**: Aangepast voor nieuwe functionaliteit
- **CI/CD pipeline**: Volledig geconfigureerd voor GitLab CI
  - PDFium dependency handling
  - Postgres service configuratie
  - Asset compilation
  - Test environment setup
  - Chrome/Chromium voor Cuprite system specs

### Opgelost
- **CI/CD issues**:
  - YAML syntax errors
  - PDFium download en extractie
  - Postgres health checks
  - RSpec output beperking
  - Error extraction en output
  - Asset precompilatie zonder database
  - Webhook User-Agent in specs

### Commits
- `3e118700` - Rebrand HGV Signing, cleanup and CI updates (2025-11-27)
- `a8cda1c1` - Aanpassingen: logo/favicon, UI cleanup, vertalingen, en development Docker setup (2025-11-29)
- `2c809be5` - Verwijder .github directory (2025-11-29)
- `10c2c035` - Voeg pg_data_dev toe aan .gitignore (2025-11-28)
- `129e5682` - Verwijder API/Webhook functionaliteit, wijzig SSO naar OAuth, verwijder storage settings, pas account configs aan (2025-11-28)
- `aba4dfc8` - Fix YAML syntax error in .gitlab-ci.yml: correct script indentation (2025-11-28)
- `bed05b51` - Fix: gebruik bundler-audit direct zonder bundle exec (2025-11-28)
- `147455e9` - Fix: DOCKER_IMAGE_TAG variabele correct definiëren in script sectie (2025-11-28)
- `2a5bf7c2` - Fix: YAML syntax error - correcte indentatie voor script item (2025-11-28)
- `3cafe46b` - Fix: verwijder test mode toggle verwijzingen en zorg dat logo beschikbaar is in tests (2025-11-28)
- `8b4f0e62` - CI: verbeter error extraction om volledige failure details uit output log te halen (2025-11-28)
- `641ee247` - CI: fix error output om volledige failure details te tonen (2025-11-28)
- `b9bc72da` - CI: verbeter error output met volledige stack traces (2025-11-28)
- `2ffc8ca6` - CI: compile assets voor test environment en verbeter error output (2025-11-28)
- `18bbba2c` - CI: voeg Chrome/Chromium toe voor Cuprite system specs (2025-11-28)
- `76559f84` - Fix: update webhook User-Agent in specs naar 'HGV Signing Webhook' (2025-11-28)
- `64706a59` - CI: fix postgres health check en beperk rspec output verder (2025-11-28)
- `3663846c` - CI: rspec output volledig naar bestanden, alleen samenvatting tonen (2025-11-28)
- `a64d7e1b` - CI: beperk rspec output om log limit te voorkomen (2025-11-28)
- `589205e6` - Fix lint en docuseal load (2025-11-28)
- `4f2fac15` - CI: extract pdfium in temp dir (2025-11-28)
- `32f3af59` - CI: detect pdfium extraction dir (2025-11-28)
- `4643e647` - CI: fallback pdfium download (2025-11-28)
- `4d3c229d` - Fix: robustere pdfium-download in CI (2025-11-28)
- `c5101112` - Fix: gebruik POSIX script voor pdfium download (2025-11-28)
- `94ff33a0` - Fix: detecteer pad naar libpdfium dynamisch (2025-11-28)
- `e64739d1` - Fix: kopieer libpdfium vanuit juiste map (2025-11-28)
- `1e8b3eb2` - Fix: bundle pdfium binary via wget (2025-11-28)
- `9995fdd7` - Fix: haal libpdfium uit bookworm-backports (2025-11-28)
- `6e8d2ac9` - Fix: gebruik libpdfium3 tijdens CI (2025-11-28)
- `db6744d0` - Fix: voeg pdfium dependency toe en gebruik yarn eslint (2025-11-28)
- `d8959715` - Fix: hergebruik bestaande yarn in lint jobs (2025-11-28)
- `22789234` - Fix: rspec job gebruikt Postgres service (2025-11-28)
- `a647198b` - Fix: laad Docuseal module in routes (2025-11-28)
- `9fbaf641` - Fix: skip database migrations during asset precompilation (2025-11-27)
- `c7bfb235` - Fix: gebruik assets:clean in plaats van assets:clobber (2025-11-27)
- `c6c4ea3f` - Use rake for asset clobber/precompile (2025-11-27)
- `73d00a87` - Tag privileged jobs for Docker access (2025-11-27)
- `3b500422` - Install libvips dependencies in CI (2025-11-27)
- `b5574aa7` - Fix YAML merges by combining anchors (2025-11-27)
- `e3c86fc0` - Fix CI heredoc indentation (again) (2025-11-27)
- `a402b3c6` - Fix CI YAML heredoc indentation (2025-11-27)

---

[v2.1.0]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/v2.0.0...v2.1.0
[2.0.0]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/v1.0.2...v2.0.0
[1.0.2]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/v1.0.1...v1.0.2
[1.0.1]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/1.0.0...v1.0.1
[0.2.6-beta]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/0.2.5-beta...0.2.6-beta
[0.2.5-beta]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/0.2.4-beta...0.2.5-beta
[0.2.4-beta]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/0.2.3-beta...0.2.4-beta
[0.2.3-beta]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/0.2.2-beta...0.2.3-beta
[0.2.2-beta]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/0.2.1-beta...0.2.2-beta
[0.2.1-beta]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/0.2.0-beta...0.2.1-beta
[0.2.0-beta]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/0.1.0-beta...0.2.0-beta
[0.1.0-beta]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/compare/0.0.1-beta...0.1.0-beta
[0.0.1-beta]: https://git.rubenrikk.nl/hgv-hengelo/hgv-signing/releases/tag/0.0.1-beta
