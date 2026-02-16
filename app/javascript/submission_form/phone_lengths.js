// Mapping van landcode (dial code) naar minimale en maximale lengte van het lokale nummer (zonder landcode)
// Gebaseerd op internationale telefoonnummer standaarden
export default {
  // Veelvoorkomende landen
  '1': { min: 10, max: 10 }, // VS/Canada (10 cijfers)
  '31': { min: 9, max: 9 }, // Nederland (9 cijfers)
  '32': { min: 9, max: 9 }, // België
  '33': { min: 9, max: 9 }, // Frankrijk
  '34': { min: 9, max: 9 }, // Spanje
  '39': { min: 9, max: 10 }, // Italië
  '44': { min: 10, max: 10 }, // Verenigd Koninkrijk
  '49': { min: 10, max: 11 }, // Duitsland
  '7': { min: 10, max: 10 }, // Rusland/Kazachstan
  '81': { min: 10, max: 10 }, // Japan
  '82': { min: 9, max: 10 }, // Zuid-Korea
  '86': { min: 11, max: 11 }, // China
  '91': { min: 10, max: 10 }, // India
  '212': { min: 9, max: 9 }, // Marokko
  '213': { min: 9, max: 9 }, // Algerije
  '216': { min: 8, max: 8 }, // Tunesië
  '218': { min: 9, max: 9 }, // Libië
  '220': { min: 7, max: 7 }, // Gambia
  '221': { min: 9, max: 9 }, // Senegal
  '222': { min: 8, max: 8 }, // Mauritanië
  '223': { min: 8, max: 8 }, // Mali
  '224': { min: 9, max: 9 }, // Guinee
  '225': { min: 10, max: 10 }, // Ivoorkust
  '226': { min: 8, max: 8 }, // Burkina Faso
  '227': { min: 8, max: 8 }, // Niger
  '228': { min: 8, max: 8 }, // Togo
  '229': { min: 8, max: 8 }, // Benin
  '230': { min: 7, max: 7 }, // Mauritius
  '231': { min: 8, max: 8 }, // Liberia
  '232': { min: 8, max: 8 }, // Sierra Leone
  '233': { min: 9, max: 9 }, // Ghana
  '234': { min: 10, max: 10 }, // Nigeria
  '235': { min: 8, max: 8 }, // Tsjaad
  '236': { min: 8, max: 8 }, // Centraal-Afrikaanse Republiek
  '237': { min: 9, max: 9 }, // Kameroen
  '238': { min: 7, max: 7 }, // Kaapverdië
  '239': { min: 7, max: 7 }, // Sao Tomé en Principe
  '240': { min: 9, max: 9 }, // Equatoriaal-Guinea
  '241': { min: 8, max: 8 }, // Gabon
  '242': { min: 9, max: 9 }, // Republiek Congo
  '243': { min: 9, max: 9 }, // Democratische Republiek Congo
  '244': { min: 9, max: 9 }, // Angola
  '245': { min: 7, max: 7 }, // Guinee-Bissau
  '246': { min: 7, max: 7 }, // Brits Indische Oceaanterritorium
  '248': { min: 7, max: 7 }, // Seychellen
  '249': { min: 9, max: 9 }, // Soedan
  '250': { min: 9, max: 9 }, // Rwanda
  '251': { min: 9, max: 9 }, // Ethiopië
  '252': { min: 8, max: 8 }, // Somalië
  '253': { min: 8, max: 8 }, // Djibouti
  '254': { min: 9, max: 9 }, // Kenia
  '255': { min: 9, max: 9 }, // Tanzania
  '256': { min: 9, max: 9 }, // Oeganda
  '257': { min: 8, max: 8 }, // Burundi
  '258': { min: 9, max: 9 }, // Mozambique
  '260': { min: 9, max: 9 }, // Zambia
  '261': { min: 9, max: 9 }, // Madagaskar
  '262': { min: 9, max: 9 }, // Réunion
  '263': { min: 9, max: 9 }, // Zimbabwe
  '264': { min: 9, max: 9 }, // Namibië
  '265': { min: 9, max: 9 }, // Malawi
  '266': { min: 8, max: 8 }, // Lesotho
  '267': { min: 8, max: 8 }, // Botswana
  '268': { min: 8, max: 8 }, // Swaziland
  '269': { min: 7, max: 7 }, // Comoren
  '27': { min: 9, max: 9 }, // Zuid-Afrika
  '290': { min: 4, max: 4 }, // Sint-Helena
  '291': { min: 7, max: 7 }, // Eritrea
  '297': { min: 7, max: 7 }, // Aruba
  '298': { min: 6, max: 6 }, // Faeröer
  '299': { min: 6, max: 6 }, // Groenland
  '30': { min: 10, max: 10 }, // Griekenland
  '351': { min: 9, max: 9 }, // Portugal
  '352': { min: 9, max: 9 }, // Luxemburg
  '353': { min: 9, max: 9 }, // Ierland
  '354': { min: 7, max: 7 }, // IJsland
  '355': { min: 9, max: 9 }, // Albanië
  '356': { min: 8, max: 8 }, // Malta
  '357': { min: 8, max: 8 }, // Cyprus
  '358': { min: 9, max: 10 }, // Finland
  '359': { min: 9, max: 9 }, // Bulgarije
  '36': { min: 9, max: 9 }, // Hongarije
  '370': { min: 8, max: 8 }, // Litouwen
  '371': { min: 8, max: 8 }, // Letland
  '372': { min: 7, max: 8 }, // Estland
  '373': { min: 8, max: 8 }, // Moldavië
  '374': { min: 8, max: 8 }, // Armenië
  '375': { min: 9, max: 9 }, // Wit-Rusland
  '376': { min: 6, max: 6 }, // Andorra
  '377': { min: 9, max: 9 }, // Monaco
  '378': { min: 6, max: 10 }, // San Marino
  '380': { min: 9, max: 9 }, // Oekraïne
  '381': { min: 9, max: 9 }, // Servië
  '382': { min: 8, max: 8 }, // Montenegro
  '383': { min: 8, max: 8 }, // Kosovo
  '385': { min: 8, max: 9 }, // Kroatië
  '386': { min: 8, max: 8 }, // Slovenië
  '387': { min: 8, max: 8 }, // Bosnië en Herzegovina
  '389': { min: 8, max: 8 }, // Noord-Macedonië
  '40': { min: 9, max: 9 }, // Roemenië
  '41': { min: 9, max: 9 }, // Zwitserland
  '420': { min: 9, max: 9 }, // Tsjechië
  '421': { min: 9, max: 9 }, // Slowakije
  '423': { min: 7, max: 7 }, // Liechtenstein
  '43': { min: 10, max: 13 }, // Oostenrijk
  '45': { min: 8, max: 8 }, // Denemarken
  '46': { min: 9, max: 9 }, // Zweden
  '47': { min: 8, max: 8 }, // Noorwegen
  '48': { min: 9, max: 9 }, // Polen
  '51': { min: 9, max: 9 }, // Peru
  '52': { min: 10, max: 10 }, // Mexico
  '53': { min: 8, max: 8 }, // Cuba
  '54': { min: 10, max: 10 }, // Argentinië
  '55': { min: 10, max: 11 }, // Brazilië
  '56': { min: 9, max: 9 }, // Chili
  '57': { min: 10, max: 10 }, // Colombia
  '58': { min: 10, max: 10 }, // Venezuela
  '60': { min: 9, max: 10 }, // Maleisië
  '61': { min: 9, max: 9 }, // Australië
  '62': { min: 9, max: 11 }, // Indonesië
  '63': { min: 10, max: 10 }, // Filipijnen
  '64': { min: 8, max: 10 }, // Nieuw-Zeeland
  '65': { min: 8, max: 8 }, // Singapore
  '66': { min: 9, max: 9 }, // Thailand
  '84': { min: 9, max: 10 }, // Vietnam
  '90': { min: 10, max: 10 }, // Turkije
  '92': { min: 10, max: 10 }, // Pakistan
  '93': { min: 9, max: 9 }, // Afghanistan
  '94': { min: 9, max: 9 }, // Sri Lanka
  '95': { min: 8, max: 10 }, // Myanmar
  '98': { min: 10, max: 10 }, // Iran
  '971': { min: 9, max: 9 }, // Verenigde Arabische Emiraten
  '972': { min: 9, max: 9 }, // Israël
  '973': { min: 8, max: 8 }, // Bahrein
  '974': { min: 8, max: 8 }, // Qatar
  '975': { min: 8, max: 8 }, // Bhutan
  '976': { min: 8, max: 8 }, // Mongolië
  '977': { min: 10, max: 10 }, // Nepal
  '992': { min: 9, max: 9 }, // Tadzjikistan
  '993': { min: 8, max: 8 }, // Turkmenistan
  '994': { min: 9, max: 9 }, // Azerbeidzjan
  '995': { min: 9, max: 9 }, // Georgië
  '996': { min: 9, max: 9 }, // Kirgizië
  '998': { min: 9, max: 9 } // Oezbekistan
}

// Fallback voor landcodes die niet in de mapping staan
// Gebruik een redelijke range voor onbekende landcodes
export const DEFAULT_PHONE_LENGTH = { min: 7, max: 15 }


