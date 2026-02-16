# HGV Signing

Een platform voor het digitaal ondertekenen en verwerken van documenten, ingericht voor HGV Hengelo. Maak PDF-formulieren aan, voeg velden toe via een visuele editor, en laat ze online invullen en ondertekenen op elk apparaat.

## Gebaseerd op DocuSeal

Dit project is een aangepaste versie van [DocuSeal](https://github.com/docusealco/docuseal), een open-source platform voor digitale handtekeningen.

**Origineel project:** https://github.com/docusealco/docuseal
**Licentie:** GNU Affero General Public License v3 (AGPLv3)
**Oorspronkelijke auteur:** DocuSeal contributors

Zie [LICENSE](LICENSE) voor de volledige licentietekst. Omdat dit een afgeleide versie (fork) is van software onder de AGPLv3, valt ook dit project onder dezelfde licentie.

## Aanpassingen ten opzichte van DocuSeal

- Volledige rebrand naar HGV Signing (logo, favicon, branding)
- Nederlandse taal als standaard voor de landingspagina en ondertekeningsflow
- Vereenvoudigde gebruikersrollen: Admin en Editor (Viewer-rol verwijderd)
- Editor-rol beperkingen: account-/gebruikersinstellingen verborgen, e-mailverzending verplicht
- API- en webhookfunctionaliteit verwijderd
- QR-code handtekeningoptie verwijderd
- Download- en kopieerknoppen verwijderd van de bevestigingspagina
- Auditlogboek-PDF-bijlage in e-mails verwijderd
- Leeftijdsvalidatie op basis van geboortedatum (voorwaardelijke velden)
- Landcode-specifieke telefoonnummervalidatie
- Nederlandse postcodevalidatie
- Migratie van Docker-deployment naar native bare-metal installatie (Ubuntu 22.04 + systemd)
- Capistrano-stijl releasebeheer met zero-downtime deployments en automatische rollback

## Tech stack

- **Backend:** Ruby on Rails 8.0
- **Frontend:** Vue.js 3, TailwindCSS, DaisyUI
- **Database:** PostgreSQL 15 (aanbevolen) of SQLite
- **Achtergrondtaken:** Sidekiq (embedded via Puma plugin)
- **Webserver:** Puma
- **PDF-verwerking:** HexaPDF, PDFium
- **AI/ML:** ONNX Runtime (handtekeningverwerking)

## Vereisten

- Ruby 3.4.2
- Node.js 20.x en Yarn
- PostgreSQL 15+ of SQLite

## Aan de slag

### 1. Repository klonen

```sh
git clone <repository-url>
cd hgv-signing
```

### 2. Dependencies installeren

```sh
bundle install
yarn install
```

### 3. Database configureren

```sh
cp config/database.yml.example config/database.yml
# Pas database.yml aan met je databaseinstellingen
rails db:create db:migrate
```

### 4. Development server starten

```sh
bin/dev
```

De applicatie is beschikbaar op `http://localhost:3000`.

### Environment variabelen

| Variabele      | Omschrijving                                  |
|----------------|-----------------------------------------------|
| `DATABASE_URL` | Database connection string                    |
| `APP_URL`      | Volledige URL van de applicatie               |
| `HOST`         | Hostname van de applicatie                    |
| `FORCE_SSL`    | Zet op `true` om HTTPS af te dwingen         |
| `SMTP_*`       | SMTP-configuratie voor e-mailverzending       |

Zie `.env.example` voor een volledige lijst van beschikbare variabelen.

## Tests uitvoeren

```sh
bundle exec rspec
```

Code quality:

```sh
bundle exec rubocop
yarn eslint
```

## Licentie

Dit project is een afgeleide versie van [DocuSeal](https://github.com/docusealco/docuseal) en valt daarmee onder de **GNU Affero General Public License v3.0 (AGPLv3)**.

Dit betekent dat eventuele verdere aanpassingen die via een netwerk beschikbaar worden gesteld, eveneens als open source gepubliceerd moeten worden onder dezelfde licentie.

Zie [LICENSE](LICENSE) voor de volledige licentietekst.

## Changelog

Zie [CHANGELOG.md](CHANGELOG.md) voor een overzicht van alle wijzigingen.
