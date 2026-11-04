import 'package:circle_flags/circle_flags.dart' as cf;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Subscription {
  String id, name, desc;
  String? description; // long description from the Announce header
  String? link;
  int uploadBytes;
  int downloadBytes;
  int totalBytes;

  Subscription({
    required this.id,
    required this.name,
    this.desc = '',
    this.description,
    this.link,
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.totalBytes = 0,
  });

  int get usedBytes => uploadBytes + downloadBytes;

  String get trafficLeftStr {
    final left = totalBytes - usedBytes;
    if (left <= 0) return '0 GB';
    if (totalBytes <= 0) return '∞';
    if (left >= 1024 * 1024 * 1024) {
      return '${(left / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(left / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  String get trafficUsedStr {
    if (usedBytes <= 0) return '0 GB';
    final gb = usedBytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.round()} GB';
    final mb = usedBytes / (1024 * 1024);
    return '${mb.round()} MB';
  }

  String get trafficTotalStr {
    if (totalBytes <= 0) return '∞';
    final gb = totalBytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.round()} GB';
    final mb = totalBytes / (1024 * 1024);
    return '${mb.round()} MB';
  }

  double get trafficFill {
    if (totalBytes <= 0) return 0.0;
    return (usedBytes / totalBytes).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desc': desc,
        'description': description,
        'link': link,
        'uploadBytes': uploadBytes,
        'downloadBytes': downloadBytes,
        'totalBytes': totalBytes,
      };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String,
        name: j['name'] as String,
        desc: (j['desc'] ?? '') as String,
        description: j['description'] as String?,
        link: j['link'] as String?,
        uploadBytes: (j['uploadBytes'] ?? 0) as int,
        downloadBytes: (j['downloadBytes'] ?? 0) as int,
        totalBytes: (j['totalBytes'] ?? 0) as int,
      );
}

/* ---------------- Emoji & Flag Utilities ---------------- */

// Unicode Regional Indicator Symbols (0x1F1E6 to 0x1F1FF) - two consecutive form a country flag
final _flagEmojiRegex = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true);

// Match all emoji characters including symbols, flags, pictographs, dingbats, stars, lightning
final _allEmojiRegex = RegExp(
  r'[\u{1F000}-\u{1FAFF}]|[\u{2000}-\u{32FF}]|[\u{FE00}-\u{FE0F}]|[\u{E0020}-\u{E007F}]|[\u{1F1E6}-\u{1F1FF}]{2}',
  unicode: true,
);

enum EmojiFilterMode {
  none,
  hideFlags,
  hideAll;

  static EmojiFilterMode fromString(String? val, EmojiFilterMode fallback) {
    if (val == null) return fallback;
    for (final e in values) {
      if (e.name == val) return e;
    }
    return fallback;
  }
}

String formatEmojis(String str, EmojiFilterMode mode) {
  switch (mode) {
    case EmojiFilterMode.none:
      return str;
    case EmojiFilterMode.hideFlags:
      return stripFlagEmojis(str);
    case EmojiFilterMode.hideAll:
      return stripAllEmojis(str);
  }
}

String stripFlagEmojis(String str) {
  return str.replaceAll(_flagEmojiRegex, '').trim().replaceAll(RegExp(r'\s+'), ' ');
}

String stripAllEmojis(String str) {
  var s = str.replaceAll(_allEmojiRegex, '').trim().replaceAll(RegExp(r'\s+'), ' ');
  s = s.replaceAll(RegExp(r'^[\s|\-–—:•*#|<>\[\]{}()]+|[\s|\-–—:•*#|<>\[\]{}()]+$'), '').trim();
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s.isEmpty ? str : s;
}

String? extractFlagCode(String str) {
  final m = _flagEmojiRegex.firstMatch(str);
  if (m != null) {
    final emoji = m.group(0)!;
    final runes = emoji.runes.toList();
    if (runes.length >= 2) {
      final c1 = String.fromCharCode(runes[0] - 0x1F1E6 + 97);
      final c2 = String.fromCharCode(runes[1] - 0x1F1E6 + 97);
      return '$c1$c2'.toLowerCase();
    }
  }
  return null;
}

bool isTechnicalOrAuto(String? name) {
  if (name == null || name.isEmpty) return false;
  final n = name.toLowerCase();
  return n.contains('самый быстрый') ||
      n.contains('fastest') ||
      n.contains('авто |') ||
      n.contains('auto |') ||
      n.contains('авто|') ||
      n.contains('auto|') ||
      n.contains('техническ') ||
      n.contains('technical') ||
      n.contains('special') ||
      n.contains('all location');
}

String? detectCountryFlag(String name) {
  if (isTechnicalOrAuto(name)) return null;
  // 1. Direct flag emoji converted to 2-letter ISO code
  final code = extractFlagCode(name);
  if (code != null) return code;

  // 2. Comprehensive keyword dictionary for all worldwide countries
  final n = name.toLowerCase();
  if (n.contains('азербайдж') || n.contains('azerbaijan') || n.contains('баку')) return 'az';
  if (n.contains('албани') || n.contains('albania') || n.contains('тирана')) return 'al';
  if (n.contains('алжир') || n.contains('algeria')) return 'dz';
  if (n.contains('ангол') || n.contains('angola')) return 'ao';
  if (n.contains('андорр') || n.contains('andorra')) return 'ad';
  if (n.contains('аргентин') || n.contains('argentina') || n.contains('буэнос')) return 'ar';
  if (n.contains('армени') || n.contains('armenia') || n.contains('ереван')) return 'am';
  if (n.contains('аруб') || n.contains('aruba')) return 'aw';
  if (n.contains('афганистан') || n.contains('afghanistan')) return 'af';
  if (n.contains('багам') || n.contains('bahamas')) return 'bs';
  if (n.contains('бангладеш') || n.contains('bangladesh') || n.contains('дакка')) return 'bd';
  if (n.contains('барбадос') || n.contains('barbados')) return 'bb';
  if (n.contains('бахрейн') || n.contains('bahrain')) return 'bh';
  if (n.contains('беларус') || n.contains('белорусс') || n.contains('belarus') || n.contains('минск')) return 'by';
  if (n.contains('белиз') || n.contains('belize')) return 'bz';
  if (n.contains('бермуд') || n.contains('bermuda')) return 'bm';
  if (n.contains('болгари') || n.contains('bulgaria') || n.contains('софия')) return 'bg';
  if (n.contains('боливи') || n.contains('bolivia')) return 'bo';
  if (n.contains('бразили') || n.contains('brazil') || n.contains('сан-паулу')) return 'br';
  if (n.contains('австрали') || n.contains('australia') || n.contains('сидней')) return 'au';
  if (n.contains('австри') || n.contains('austria') || n.contains('вена')) return 'at';
  if (n.contains('бельги') || n.contains('belgium') || n.contains('брюссель')) return 'be';
  if (n.contains('британи') || n.contains('англ') || n.contains('london') || n.contains('united kingdom') || n.contains('uk')) return 'gb';
  if (n.contains('венгри') || n.contains('hungary') || n.contains('будапешт')) return 'hu';
  if (n.contains('вьетнам') || n.contains('vietnam') || n.contains('ханой')) return 'vn';
  if (n.contains('германи') || n.contains('germany') || n.contains('франкфурт') || n.contains('берлин')) return 'de';
  if (n.contains('гонконг') || n.contains('hong kong')) return 'hk';
  if (n.contains('греци') || n.contains('greece') || n.contains('афины')) return 'gr';
  if (n.contains('грузи') || n.contains('georgia') || n.contains('тбилиси')) return 'ge';
  if (n.contains('дани') || n.contains('denmark') || n.contains('копенгаген')) return 'dk';
  if (n.contains('египет') || n.contains('egypt') || n.contains('каир')) return 'eg';
  if (n.contains('израиль') || n.contains('israel') || n.contains('тель-авив')) return 'il';
  if (n.contains('инди') || n.contains('india') || n.contains('мумбаи')) return 'in';
  if (n.contains('индонези') || n.contains('indonesia') || n.contains('джакарта')) return 'id';
  if (n.contains('ирланди') || n.contains('ireland') || n.contains('дублин')) return 'ie';
  if (n.contains('испан') || n.contains('spain') || n.contains('мадрид') || n.contains('барселон')) return 'es';
  if (n.contains('итали') || n.contains('italy') || n.contains('рим') || n.contains('милан')) return 'it';
  if (n.contains('казахстан') || n.contains('kazakhstan') || n.contains('алматы') || n.contains('астана')) return 'kz';
  if (n.contains('канад') || n.contains('canada') || n.contains('торонто') || n.contains('ванкувер')) return 'ca';
  if (n.contains('кипр') || n.contains('cyprus') || n.contains('никосия')) return 'cy';
  if (n.contains('китай') || n.contains('china') || n.contains('пекин')) return 'cn';
  if (n.contains('колумби') || n.contains('colombia')) return 'co';
  if (n.contains('коре') || n.contains('korea') || n.contains('сеул')) return 'kr';
  if (n.contains('кыргыз') || n.contains('киргиз') || n.contains('kyrgyzstan') || n.contains('бишкек')) return 'kg';
  if (n.contains('латви') || n.contains('latvia') || n.contains('рига')) return 'lv';
  if (n.contains('литв') || n.contains('lithuania') || n.contains('вильнюс')) return 'lt';
  if (n.contains('люксембург') || n.contains('luxembourg')) return 'lu';
  if (n.contains('малайзи') || n.contains('malaysia') || n.contains('куала-лумпур')) return 'my';
  if (n.contains('мексик') || n.contains('mexico')) return 'mx';
  if (n.contains('молдов') || n.contains('молдави') || n.contains('moldova') || n.contains('кишинев')) return 'md';
  if (n.contains('нидерланд') || n.contains('netherland') || n.contains('амстердам') || n.contains('голланди')) return 'nl';
  if (n.contains('норвеги') || n.contains('norway') || n.contains('осло')) return 'no';
  if (n.contains('оаэ') || n.contains('uae') || n.contains('дубай') || n.contains('эмират')) return 'ae';
  if (n.contains('польш') || n.contains('poland') || n.contains('варшава')) return 'pl';
  if (n.contains('португали') || n.contains('portugal') || n.contains('лиссабон')) return 'pt';
  if (n.contains('росси') || n.contains('russia') || n.contains('москва') || n.contains('питер') || n.contains('санкт')) return 'ru';
  if (n.contains('румыни') || n.contains('romania') || n.contains('бухарест')) return 'ro';
  if (n.contains('серби') || n.contains('serbia') || n.contains('белград')) return 'rs';
  if (n.contains('сингапур') || n.contains('singapore')) return 'sg';
  if (n.contains('словаки') || n.contains('slovakia') || n.contains('братислава')) return 'sk';
  if (n.contains('словени') || n.contains('slovenia') || n.contains('люблян')) return 'si';
  if (n.contains('сша') || n.contains('usa') || n.contains('united states') || n.contains('америк')) return 'us';
  if (n.contains('таиланд') || n.contains('тайланд') || n.contains('thailand') || n.contains('бангкок')) return 'th';
  if (n.contains('тайван') || n.contains('taiwan')) return 'tw';
  if (n.contains('турци') || n.contains('turkey') || n.contains('стамбул')) return 'tr';
  if (n.contains('узбекистан') || n.contains('uzbekistan') || n.contains('ташкент')) return 'uz';
  if (n.contains('украин') || n.contains('ukraine') || n.contains('киев')) return 'ua';
  if (n.contains('филиппин') || n.contains('philippines') || n.contains('манила')) return 'ph';
  if (n.contains('финлянд') || n.contains('finland') || n.contains('хельсинки')) return 'fi';
  if (n.contains('франци') || n.contains('france') || n.contains('париж')) return 'fr';
  if (n.contains('хорвати') || n.contains('croatia') || n.contains('загреб')) return 'hr';
  if (n.contains('черногори') || n.contains('montenegro') || n.contains('подгорица')) return 'me';
  if (n.contains('чехи') || n.contains('czech') || n.contains('прага')) return 'cz';
  if (n.contains('швейцари') || n.contains('switzerland') || n.contains('цюрих') || n.contains('женева')) return 'ch';
  if (n.contains('швеци') || n.contains('sweden') || n.contains('стокгольм')) return 'se';
  if (n.contains('эстони') || n.contains('estonia') || n.contains('таллин')) return 'ee';
  if (n.contains('юар') || n.contains('south africa')) return 'za';
  if (n.contains('косово') || n.contains('kosovo')) return 'xk';
  if (n.contains('япони') || n.contains('japan') || n.contains('токио')) return 'jp';

  return null;
}

/// Human-readable country names for the "Group by country" mode.
const Map<String, String> _countryNamesEn = {
  'ad': 'Andorra',
  'ae': 'United Arab Emirates',
  'af': 'Afghanistan',
  'ag': 'Antigua and Barbuda',
  'ai': 'Anguilla',
  'al': 'Albania',
  'am': 'Armenia',
  'ao': 'Angola',
  'aq': 'Antarctica',
  'ar': 'Argentina',
  'as': 'American Samoa',
  'at': 'Austria',
  'au': 'Australia',
  'aw': 'Aruba',
  'ax': 'Aland Islands',
  'az': 'Azerbaijan',
  'ba': 'Bosnia and Herzegovina',
  'bb': 'Barbados',
  'bd': 'Bangladesh',
  'be': 'Belgium',
  'bf': 'Burkina Faso',
  'bg': 'Bulgaria',
  'bh': 'Bahrain',
  'bi': 'Burundi',
  'bj': 'Benin',
  'bl': 'Saint Barthelemy',
  'bm': 'Bermuda',
  'bn': 'Brunei',
  'bo': 'Bolivia',
  'bq': 'Caribbean Netherlands',
  'br': 'Brazil',
  'bs': 'Bahamas',
  'bt': 'Bhutan',
  'bv': 'Bouvet Island',
  'bw': 'Botswana',
  'by': 'Belarus',
  'bz': 'Belize',
  'ca': 'Canada',
  'cc': 'Cocos Islands',
  'cd': 'DR Congo',
  'cf': 'Central African Republic',
  'cg': 'Congo',
  'ch': 'Switzerland',
  'ci': 'Ivory Coast',
  'ck': 'Cook Islands',
  'cl': 'Chile',
  'cm': 'Cameroon',
  'cn': 'China',
  'co': 'Colombia',
  'cr': 'Costa Rica',
  'cu': 'Cuba',
  'cv': 'Cape Verde',
  'cw': 'Curacao',
  'cx': 'Christmas Island',
  'cy': 'Cyprus',
  'cz': 'Czech Republic',
  'de': 'Germany',
  'dj': 'Djibouti',
  'dk': 'Denmark',
  'dm': 'Dominica',
  'do': 'Dominican Republic',
  'dz': 'Algeria',
  'ec': 'Ecuador',
  'ee': 'Estonia',
  'eg': 'Egypt',
  'eh': 'Western Sahara',
  'er': 'Eritrea',
  'es': 'Spain',
  'et': 'Ethiopia',
  'eu': 'Europe',
  'fi': 'Finland',
  'fj': 'Fiji',
  'fk': 'Falkland Islands',
  'fm': 'Micronesia',
  'fo': 'Faroe Islands',
  'fr': 'France',
  'ga': 'Gabon',
  'gb': 'United Kingdom',
  'gd': 'Grenada',
  'ge': 'Georgia',
  'gf': 'French Guiana',
  'gg': 'Guernsey',
  'gh': 'Ghana',
  'gi': 'Gibraltar',
  'gl': 'Greenland',
  'gm': 'Gambia',
  'gn': 'Guinea',
  'gp': 'Guadeloupe',
  'gq': 'Equatorial Guinea',
  'gr': 'Greece',
  'gs': 'South Georgia',
  'gt': 'Guatemala',
  'gu': 'Guam',
  'gw': 'Guinea-Bissau',
  'gy': 'Guyana',
  'hk': 'Hong Kong',
  'hm': 'Heard Island',
  'hn': 'Honduras',
  'hr': 'Croatia',
  'ht': 'Haiti',
  'hu': 'Hungary',
  'id': 'Indonesia',
  'ie': 'Ireland',
  'il': 'Israel',
  'im': 'Isle of Man',
  'in': 'India',
  'io': 'British Indian Ocean Territory',
  'iq': 'Iraq',
  'ir': 'Iran',
  'is': 'Iceland',
  'it': 'Italy',
  'je': 'Jersey',
  'jm': 'Jamaica',
  'jo': 'Jordan',
  'jp': 'Japan',
  'ke': 'Kenya',
  'kg': 'Kyrgyzstan',
  'kh': 'Cambodia',
  'ki': 'Kiribati',
  'km': 'Comoros',
  'kn': 'Saint Kitts and Nevis',
  'kp': 'North Korea',
  'kr': 'South Korea',
  'kw': 'Kuwait',
  'ky': 'Cayman Islands',
  'kz': 'Kazakhstan',
  'la': 'Laos',
  'lb': 'Lebanon',
  'lc': 'Saint Lucia',
  'li': 'Liechtenstein',
  'lk': 'Sri Lanka',
  'lr': 'Liberia',
  'ls': 'Lesotho',
  'lt': 'Lithuania',
  'lu': 'Luxembourg',
  'lv': 'Latvia',
  'ly': 'Libya',
  'ma': 'Morocco',
  'mc': 'Monaco',
  'md': 'Moldova',
  'me': 'Montenegro',
  'mf': 'Saint Martin',
  'mg': 'Madagascar',
  'mh': 'Marshall Islands',
  'mk': 'North Macedonia',
  'ml': 'Mali',
  'mm': 'Myanmar',
  'mn': 'Mongolia',
  'mo': 'Macau',
  'mp': 'Northern Mariana Islands',
  'mq': 'Martinique',
  'mr': 'Mauritania',
  'ms': 'Montserrat',
  'mt': 'Malta',
  'mu': 'Mauritius',
  'mv': 'Maldives',
  'mw': 'Malawi',
  'mx': 'Mexico',
  'my': 'Malaysia',
  'mz': 'Mozambique',
  'na': 'Namibia',
  'nc': 'New Caledonia',
  'ne': 'Niger',
  'nf': 'Norfolk Island',
  'ng': 'Nigeria',
  'ni': 'Nicaragua',
  'nl': 'Netherlands',
  'no': 'Norway',
  'np': 'Nepal',
  'nr': 'Nauru',
  'nu': 'Niue',
  'nz': 'New Zealand',
  'om': 'Oman',
  'pa': 'Panama',
  'pe': 'Peru',
  'pf': 'French Polynesia',
  'pg': 'Papua New Guinea',
  'ph': 'Philippines',
  'pk': 'Pakistan',
  'pl': 'Poland',
  'pm': 'Saint Pierre and Miquelon',
  'pn': 'Pitcairn Islands',
  'pr': 'Puerto Rico',
  'ps': 'Palestine',
  'pt': 'Portugal',
  'pw': 'Palau',
  'py': 'Paraguay',
  'qa': 'Qatar',
  're': 'Reunion',
  'ro': 'Romania',
  'rs': 'Serbia',
  'ru': 'Russia',
  'rw': 'Rwanda',
  'sa': 'Saudi Arabia',
  'sb': 'Solomon Islands',
  'sc': 'Seychelles',
  'sd': 'Sudan',
  'se': 'Sweden',
  'sg': 'Singapore',
  'sh': 'Saint Helena',
  'si': 'Slovenia',
  'sj': 'Svalbard',
  'sk': 'Slovakia',
  'sl': 'Sierra Leone',
  'sm': 'San Marino',
  'sn': 'Senegal',
  'so': 'Somalia',
  'sr': 'Suriname',
  'ss': 'South Sudan',
  'st': 'Sao Tome and Principe',
  'sv': 'El Salvador',
  'sx': 'Sint Maarten',
  'sy': 'Syria',
  'sz': 'Eswatini',
  'tc': 'Turks and Caicos Islands',
  'td': 'Chad',
  'tf': 'French Southern Territories',
  'tg': 'Togo',
  'th': 'Thailand',
  'tj': 'Tajikistan',
  'tk': 'Tokelau',
  'tl': 'Timor-Leste',
  'tm': 'Turkmenistan',
  'tn': 'Tunisia',
  'to': 'Tonga',
  'tr': 'Turkey',
  'tt': 'Trinidad and Tobago',
  'tv': 'Tuvalu',
  'tw': 'Taiwan',
  'tz': 'Tanzania',
  'ua': 'Ukraine',
  'ug': 'Uganda',
  'um': 'U.S. Outlying Islands',
  'us': 'USA',
  'uy': 'Uruguay',
  'uz': 'Uzbekistan',
  'va': 'Vatican City',
  'vc': 'Saint Vincent and the Grenadines',
  've': 'Venezuela',
  'vg': 'British Virgin Islands',
  'vi': 'U.S. Virgin Islands',
  'vn': 'Vietnam',
  'vu': 'Vanuatu',
  'wf': 'Wallis and Futuna',
  'ws': 'Samoa',
  'ye': 'Yemen',
  'yt': 'Mayotte',
  'za': 'South Africa', 'xk': 'Kosovo',
  'zm': 'Zambia',
  'zw': 'Zimbabwe',
};

const Map<String, String> _countryNamesRu = {
  'ad': 'Андорра',
  'ae': 'ОАЭ',
  'af': 'Афганистан',
  'ag': 'Антигуа и Барбуда',
  'ai': 'Ангилья',
  'al': 'Албания',
  'am': 'Армения',
  'ao': 'Ангола',
  'aq': 'Антарктида',
  'ar': 'Аргентина',
  'as': 'Американское Самоа',
  'at': 'Австрия',
  'au': 'Австралия',
  'aw': 'Аруба',
  'ax': 'Аландские острова',
  'az': 'Азербайджан',
  'ba': 'Босния и Герцеговина',
  'bb': 'Барбадос',
  'bd': 'Бангладеш',
  'be': 'Бельгия',
  'bf': 'Буркина-Фасо',
  'bg': 'Болгария',
  'bh': 'Бахрейн',
  'bi': 'Бурунди',
  'bj': 'Бенин',
  'bl': 'Сен-Бартелеми',
  'bm': 'Бермуды',
  'bn': 'Бруней',
  'bo': 'Боливия',
  'bq': 'Бонэйр',
  'br': 'Бразилия',
  'bs': 'Багамы',
  'bt': 'Бутан',
  'bv': 'Остров Буве',
  'bw': 'Ботсвана',
  'by': 'Беларусь',
  'bz': 'Белиз',
  'ca': 'Канада',
  'cc': 'Кокосовые острова',
  'cd': 'ДР Конго',
  'cf': 'ЦАР',
  'cg': 'Конго',
  'ch': 'Швейцария',
  'ci': 'Кот-д’Ивуар',
  'ck': 'Острова Кука',
  'cl': 'Чили',
  'cm': 'Камерун',
  'cn': 'Китай',
  'co': 'Колумбия',
  'cr': 'Коста-Рика',
  'cu': 'Куба',
  'cv': 'Кабо-Верде',
  'cw': 'Кюрасао',
  'cx': 'Остров Рождества',
  'cy': 'Кипр',
  'cz': 'Чехия',
  'de': 'Германия',
  'dj': 'Джибути',
  'dk': 'Дания',
  'dm': 'Доминика',
  'do': 'Доминикана',
  'dz': 'Алжир',
  'ec': 'Эквадор',
  'ee': 'Эстония',
  'eg': 'Египет',
  'eh': 'Западная Сахара',
  'er': 'Эритрея',
  'es': 'Испания',
  'et': 'Эфиопия',
  'eu': 'Европа',
  'fi': 'Финляндия',
  'fj': 'Фиджи',
  'fk': 'Фолклендские острова',
  'fm': 'Микронезия',
  'fo': 'Фарерские острова',
  'fr': 'Франция',
  'ga': 'Габон',
  'gb': 'Великобритания',
  'gd': 'Гренада',
  'ge': 'Грузия',
  'gf': 'Французская Гвиана',
  'gg': 'Гернси',
  'gh': 'Гана',
  'gi': 'Гибралтар',
  'gl': 'Гренландия',
  'gm': 'Гамбия',
  'gn': 'Гвинея',
  'gp': 'Гваделупа',
  'gq': 'Экваториальная Гвинея',
  'gr': 'Греция',
  'gs': 'Южная Георгия',
  'gt': 'Гватемала',
  'gu': 'Гуам',
  'gw': 'Гвинея-Бисау',
  'gy': 'Гайана',
  'hk': 'Гонконг',
  'hm': 'Остров Херд',
  'hn': 'Гондурас',
  'hr': 'Хорватия',
  'ht': 'Гаити',
  'hu': 'Венгрия',
  'id': 'Индонезия',
  'ie': 'Ирландия',
  'il': 'Израиль',
  'im': 'Остров Мэн',
  'in': 'Индия',
  'io': 'Британская территория в Индийском океане',
  'iq': 'Ирак',
  'ir': 'Иран',
  'is': 'Исландия',
  'it': 'Италия',
  'je': 'Джерси',
  'jm': 'Ямайка',
  'jo': 'Иордания',
  'jp': 'Япония',
  'ke': 'Кения',
  'kg': 'Кыргызстан',
  'kh': 'Камбоджа',
  'ki': 'Кирибати',
  'km': 'Коморы',
  'kn': 'Сент-Китс и Невис',
  'kp': 'Северная Корея',
  'kr': 'Южная Корея',
  'kw': 'Кувейт',
  'ky': 'Каймановы острова',
  'kz': 'Казахстан',
  'la': 'Лаос',
  'lb': 'Ливан',
  'lc': 'Сент-Люсия',
  'li': 'Лихтенштейн',
  'lk': 'Шри-Ланка',
  'lr': 'Либерия',
  'ls': 'Лесото',
  'lt': 'Литва',
  'lu': 'Люксембург',
  'lv': 'Латвия',
  'ly': 'Ливия',
  'ma': 'Марокко',
  'mc': 'Монако',
  'md': 'Молдова',
  'me': 'Черногория',
  'mf': 'Сен-Мартен',
  'mg': 'Мадагаскар',
  'mh': 'Маршалловы острова',
  'mk': 'Северная Македония',
  'ml': 'Мали',
  'mm': 'Мьянма',
  'mn': 'Монголия',
  'mo': 'Макао',
  'mp': 'Северные Марианские острова',
  'mq': 'Мартиника',
  'mr': 'Мавритания',
  'ms': 'Монтсеррат',
  'mt': 'Мальта',
  'mu': 'Маврикий',
  'mv': 'Мальдивы',
  'mw': 'Малави',
  'mx': 'Мексика',
  'my': 'Малайзия',
  'mz': 'Мозамбик',
  'na': 'Намибия',
  'nc': 'Новая Каледония',
  'ne': 'Нигер',
  'nf': 'Норфолк',
  'ng': 'Нигерия',
  'ni': 'Никарагуа',
  'nl': 'Нидерланды',
  'no': 'Норвегия',
  'np': 'Непал',
  'nr': 'Науру',
  'nu': 'Ниуэ',
  'nz': 'Новая Зеландия',
  'om': 'Оман',
  'pa': 'Панама',
  'pe': 'Перу',
  'pf': 'Французская Полинезия',
  'pg': 'Папуа — Новая Гвинея',
  'ph': 'Филиппины',
  'pk': 'Пакистан',
  'pl': 'Польша',
  'pm': 'Сен-Пьер и Микелон',
  'pn': 'Острова Питкэрн',
  'pr': 'Пуэрто-Рико',
  'ps': 'Палестина',
  'pt': 'Португалия',
  'pw': 'Палау',
  'py': 'Парагвай',
  'qa': 'Катар',
  're': 'Реюньон',
  'ro': 'Румыния',
  'rs': 'Сербия',
  'ru': 'Россия',
  'rw': 'Руанда',
  'sa': 'Саудовская Аравия',
  'sb': 'Соломоновы острова',
  'sc': 'Сейшелы',
  'sd': 'Судан',
  'se': 'Швеция',
  'sg': 'Сингапур',
  'sh': 'Остров Святой Елены',
  'si': 'Словения',
  'sj': 'Шпицберген',
  'sk': 'Словакия',
  'sl': 'Сьерра-Леоне',
  'sm': 'Сан-Марино',
  'sn': 'Сенегал',
  'so': 'Сомали',
  'sr': 'Суринам',
  'ss': 'Южный Судан',
  'st': 'Сан-Томе и Принсипи',
  'sv': 'Сальвадор',
  'sx': 'Синт-Мартен',
  'sy': 'Сирия',
  'sz': 'Эсватини',
  'tc': 'Теркс и Кайкос',
  'td': 'Чад',
  'tf': 'Французские Южные территории',
  'tg': 'Того',
  'th': 'Таиланд',
  'tj': 'Таджикистан',
  'tk': 'Токелау',
  'tl': 'Восточный Тимор',
  'tm': 'Туркменистан',
  'tn': 'Тунис',
  'to': 'Тонга',
  'tr': 'Турция',
  'tt': 'Тринидад и Тобаго',
  'tv': 'Тувалу',
  'tw': 'Тайвань',
  'tz': 'Танзания',
  'ua': 'Украина',
  'ug': 'Уганда',
  'um': 'Внешние малые острова США',
  'us': 'США',
  'uy': 'Уругвай',
  'uz': 'Узбекистан',
  'va': 'Ватикан',
  'vc': 'Сент-Винсент и Гренадины',
  've': 'Венесуэла',
  'vg': 'Британские Виргинские острова',
  'vi': 'Виргинские острова США',
  'vn': 'Вьетнам',
  'vu': 'Вануату',
  'wf': 'Уоллис и Футуна',
  'ws': 'Самоа',
  'ye': 'Йемен',
  'yt': 'Майотта',
  'za': 'ЮАР', 'xk': 'Косово',
  'zm': 'Замбия',
  'zw': 'Зимбабве',
};

String countryDisplayName(String? code, bool isRu) {
  if (code == null || code.isEmpty) return isRu ? 'Другие' : 'Other';
  final map = isRu ? _countryNamesRu : _countryNamesEn;
  return map[code.toLowerCase()] ?? code.toUpperCase();
}

class ServerData {
  String id, subId, name, plateName, city;
  String? flag;      // 2-letter ISO code or 'eu'. null -> origami logo
  bool mode;         // fastest / auto pseudo-entry
  int pingMs;        // REAL ping in ms (-1 if not yet tested)
  int load;
  String? vlessUrl;
  bool isFavorite;
  int? pingAt; // epoch ms of the last ping measurement (ping cache)
  String? rawName;

  late String searchKey;

  void refreshSearchKey() {
    final ru = countryDisplayName(flag, true);
    final en = countryDisplayName(flag, false);
    searchKey = '$name $city $ru $en'.toLowerCase();
  }

  String displayName(EmojiFilterMode mode) {
    final base = (rawName != null && rawName!.isNotEmpty) ? rawName! : name;
    return formatEmojis(base, mode);
  }

  String notificationName(EmojiFilterMode mode) {
    final base = (rawName != null && rawName!.isNotEmpty) ? rawName! : plateName;
    return formatEmojis(base, mode);
  }

  String get protocolDisplay {
    if (vlessUrl == null) return 'VLESS';
    final u = vlessUrl!.toLowerCase();
    if (u.contains('security=reality')) return 'VLESS Reality';
    if (u.contains('type=grpc')) return 'VLESS gRPC';
    if (u.contains('security=tls')) return 'VLESS TLS';
    if (u.startsWith('hysteria2') || u.startsWith('hy2')) return 'Hysteria2';
    if (u.startsWith('vmess')) return 'VMess';
    if (u.startsWith('trojan')) return 'Trojan';
    if (u.startsWith('ss')) return 'Shadowsocks';
    return 'VLESS';
  }

  ServerData({
    required this.id,
    required this.subId,
    required this.name,
    required this.plateName,
    required this.city,
    this.rawName,
    this.flag,
    this.mode = false,
    this.pingMs = -1,
    this.load = 18,
    this.vlessUrl,
    this.isFavorite = false,
    this.pingAt,
  }) {
    refreshSearchKey();
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'subId': subId, 'name': name, 'plateName': plateName, 'city': city,
        'flag': flag, 'mode': mode, 'pingMs': pingMs, 'load': load, 'vlessUrl': vlessUrl, 'pingAt': pingAt,
        'isFavorite': isFavorite, 'rawName': rawName ?? name,
      };

  factory ServerData.fromJson(Map<String, dynamic> j) => ServerData(
        id: j['id'],
        subId: j['subId'],
        name: j['name'],
        plateName: j['plateName'] ?? stripAllEmojis(j['name']),
        city: j['city'] ?? '',
        rawName: j['rawName'] ?? j['name'],
        flag: j['flag'],
        mode: (j['mode'] ?? false) as bool,
        pingMs: (j['pingMs'] ?? -1) as int,
        load: (j['load'] ?? 18) as int,
        vlessUrl: j['vlessUrl'],
        isFavorite: (j['isFavorite'] ?? false) as bool,
        pingAt: (j['pingAt'] as num?)?.toInt(),
      );
}

// Custom vector for European Union
const String _kEuSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><defs><clipPath id="c"><circle cx="12" cy="12" r="12"/></clipPath></defs><g clip-path="url(#c)"><rect width="24" height="24" fill="#003399"/><circle cx="12" cy="5.2" r="1" fill="#ffcc00"/><circle cx="15.4" cy="6.1" r="1" fill="#ffcc00"/><circle cx="17.9" cy="8.6" r="1" fill="#ffcc00"/><circle cx="18.8" cy="12" r="1" fill="#ffcc00"/><circle cx="17.9" cy="15.4" r="1" fill="#ffcc00"/><circle cx="15.4" cy="17.9" r="1" fill="#ffcc00"/><circle cx="12" cy="18.8" r="1" fill="#ffcc00"/><circle cx="8.6" cy="17.9" r="1" fill="#ffcc00"/><circle cx="6.1" cy="15.4" r="1" fill="#ffcc00"/><circle cx="5.2" cy="12" r="1" fill="#ffcc00"/><circle cx="6.1" cy="8.6" r="1" fill="#ffcc00"/><circle cx="8.6" cy="6.1" r="1" fill="#ffcc00"/></g></svg>''';

class CircleFlag extends StatelessWidget {
  final String? flag;
  final String? serverName;
  final double size;
  const CircleFlag(this.flag, {super.key, this.serverName, this.size = 24});

  @override
  Widget build(BuildContext context) {
    // 0) If explicitly technical or auto/fastest card: render OUR white origami logo!
    if (serverName != null && isTechnicalOrAuto(serverName)) {
      return _buildLogoBadge();
    }
    // 1) If no flag or unknown/technical/auto/fastest: render OUR white origami logo!
    if (flag == null || flag!.isEmpty || flag == 'fastest' || flag == 'auto' || flag == 'zz' || flag == 'other') {
      return _buildLogoBadge();
    }

    final code = flag!.toLowerCase();

    // 2) European Union custom SVG
    if (code == 'eu') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3C3C42), width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: SvgPicture.string(_kEuSvg, fit: BoxFit.cover),
      );
    }

    // 3) If not a known country in our world dictionary, render our logo badge
    if (!_countryNamesEn.containsKey(code)) {
      return _buildLogoBadge();
    }

    // 4) Official circle flag
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF3C3C42), width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: cf.CircleFlag(code, size: size),
    );
  }

  Widget _buildLogoBadge() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF26262B),
        border: Border.all(color: const Color(0xFF3C3C42), width: 1.0),
      ),
      padding: EdgeInsets.all(size * 0.18),
      child: Image.asset('assets/logo-white.png', fit: BoxFit.contain),
    );
  }
}
