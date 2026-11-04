class AppStrings {
  final String lang;
  const AppStrings(this.lang);

  bool get isRu => lang == 'ru';

  // Navigation
  String get home => isRu ? 'Главная' : 'Home';
  String get servers => isRu ? 'Серверы' : 'Servers';
  String get settings => isRu ? 'Настройки' : 'Settings';
  String get account => isRu ? 'Аккаунт' : 'Account';

  // Home Screen
  String get yourIp => isRu ? 'Ваш IP: ' : 'Your IP: ';
  String get connected => 'CONNECTED';
  String get connecting => 'CONNECTING';
  String get disconnected => 'DISCONNECTED';
  String get secureConnection => isRu ? 'Соединение защищено' : 'Your connection is secure';
  String get establishingTunnel => isRu ? 'Установка защищенного туннеля' : 'Establishing secure tunnel';
  String get tapToSecure => isRu ? 'Нажмите для защиты соединения' : 'Tap to secure your connection';
  String get testingConnection => isRu ? 'Проверка соединения...' : 'Testing connection...';
  String get connectionFailed => isRu ? 'Сбой подключения' : 'Connection failed';
  String get noServerTapAdd => isRu ? 'Нет сервера — нажмите + для добавления' : 'No server - tap + to add';
  String get pingLabel => 'Ping:';
  String get protocolLabel => isRu ? 'Протокол:' : 'Protocol:';
  String get serverLoad => isRu ? 'Нагрузка:' : 'Server Load:';
  String get speed => isRu ? 'Скорость:' : 'Speed:';

  // Add Subscription
  String get addSubscription => isRu ? 'Добавить подписку' : 'Add Subscription';
  String get importClipboard => isRu ? 'Вставить из буфера обмена' : 'Import from Clipboard';
  String get enterUrlManually => isRu ? 'Ввести ссылку вручную' : 'Enter URL Manually';
  String get cancel => isRu ? 'Отмена' : 'Cancel';
  String get enterSubUrl => isRu ? 'Введите ссылку на подписку' : 'Enter subscription URL';
  String get urlPlaceholder => 'https://... or vless://...';
  String get add => isRu ? 'Добавить' : 'Add';
  String get addingSubscription => isRu ? 'Добавление подписки...' : 'Adding subscription...';
  String get subAdded => isRu ? 'Подписка успешно добавлена' : 'Subscription added successfully';
  String get subError => isRu ? 'Ошибка добавления подписки' : 'Failed to add subscription';

  // Servers Screen
  String get selectLocation => isRu ? 'Выберите локацию' : 'Select a location';
  String get searchServers => isRu ? 'Поиск серверов' : 'Search servers';
  String get sortServers => isRu ? 'Сортировка' : 'Sort Servers';
  String get sortLabel => isRu ? 'Сортировка' : 'Sort';
  String get sortDefault => isRu ? 'По умолчанию' : 'Default';
  String get sortPing => isRu ? 'По пингу' : 'Lowest Ping';
  String get sortName => isRu ? 'По названию' : 'By Name';
  String get merge => isRu ? 'Объединить' : 'Merge';
  String get favorites => isRu ? 'Избранные' : 'Favorites';
  String get noFavorites => isRu ? 'В избранном пусто' : 'No favorites yet';
  String get noFavoritesSub => isRu ? 'Нажмите на звездочку ★ рядом с сервером, чтобы добавить его в избранное' : 'Tap ★ on any server to add it to favorites';
  String get noServersYet => isRu ? 'Серверов пока нет. Нажмите +, чтобы добавить подписку' : 'No servers yet. Tap + to add a subscription';
  String get pingingServers => isRu ? 'Проверка пинга...' : 'Testing ping...';
  String get rename => isRu ? 'Переименовать' : 'Rename';
  String get updateServers => isRu ? 'Обновить серверы' : 'Update servers';
  String get deleteSub => isRu ? 'Удалить подписку' : 'Delete subscription';
  String get deleteSubConfirm => isRu ? 'Вы уверены, что хотите удалить эту подписку и все её серверы?' : 'Are you sure you want to delete this subscription and all its servers?';
  String get delete => isRu ? 'Удалить' : 'Delete';
  String get save => isRu ? 'Сохранить' : 'Save';

  // Settings Screen
  String get appPreferences => isRu ? 'Параметры приложения' : 'Application preferences';
  String get connectionSection => isRu ? 'Подключение' : 'Connection';
  String get autoConnect => isRu ? 'Автоподключение' : 'Auto-Connect';
  String get autoConnectSub => isRu ? 'Подключаться при запуске' : 'Connect on app launch';
  String get autoSwitch => isRu ? 'Автопереключение сервера' : 'Auto-Switch Server';
  String get autoSwitchSub => isRu ? 'Переключать при высоком пинге или сбое' : 'Switch if ping is high or server drops';
  String get maxPingThreshold => isRu ? 'Порог пинга для переключения' : 'Failover Ping Threshold';
  String get scanScope => isRu ? 'Какие серверы сканировать' : 'Scan Scope';
  String get scanScopeSub => isRu ? 'Регион серверов для автосмены' : 'Region of servers for auto-switch';
  String get scopeAll => isRu ? 'Все серверы' : 'All servers';
  String get scopeAllSub => isRu ? 'Из всех подписок, любая страна' : 'From all subscriptions, any country';
  String get scopeNoRu => isRu ? 'Все кроме России' : 'All except Russia';
  String get scopeNoRuSub => isRu ? 'Исключить российские серверы' : 'Exclude Russian servers';
  String get scopeFavorites => isRu ? 'Только избранные' : 'Favorites only';
  String get scopeFavoritesSub => isRu ? 'Сканировать только ★ серверы' : 'Scan only ★ servers';
  String get scanSubSource => isRu ? 'Источник подписки' : 'Subscriptions Source';
  String get scanSubSourceSub => isRu ? 'Из какой подписки брать серверы' : 'Which subscription to scan';
  String get subsAll => isRu ? 'Все подписки' : 'All subscriptions';
  String get autoSwitchScanning => isRu ? 'Поиск лучшего сервера…' : 'Scanning for a better server…';
  String get killSwitch => 'Kill Switch';
  String get killSwitchSub => isRu ? 'Блокировать сеть при обрыве VPN' : 'Block internet if VPN drops';
  String get language => isRu ? 'Язык' : 'Language';
  String get languageSub => isRu ? 'Русский или English' : 'English or Russian';

  String get networkSection => isRu ? 'Туннель и сеть' : 'Tunnel & Network';
  String get bypassLan => isRu ? 'Обход локальной сети (LAN)' : 'Bypass Local Network';
  String get bypassLanSub => isRu ? 'Доступ к локальным устройствам' : 'Access local network devices';
  String get customDns => isRu ? 'Пользовательский DNS' : 'Custom DNS';
  String get customDnsSub => isRu ? 'DNS-сервер для туннеля' : 'DNS server for the tunnel';
  String get pingMethod => isRu ? 'Метод пинга' : 'Ping Method';
  String get pingMethodSub => isRu ? 'Как мерить пинг серверов' : 'How server pings are measured';
  String get pingTcp => isRu ? 'TCP (лёгкий)' : 'TCP (light)';
  String get pingTcpSub => isRu ? 'Быстрый SYN-замер' : 'Fast SYN measurement';
  String get pingCore => isRu ? 'Ядро (точный)' : 'Core (accurate)';
  String get pingCoreSub => isRu ? 'Через ядро, минуя туннель' : 'Via core, bypassing tunnel';
  String get version => isRu ? 'Версия' : 'Version';

  String get systemSection => isRu ? 'Система и данные' : 'System & Data';
  String get resetAllData => isRu ? 'Сбросить все данные' : 'Clear All Data & Subscriptions';
  String get resetAllDataSub => isRu ? 'Удалить все подписки и настройки' : 'Wipe all saved servers and settings';
  String get resetConfirm => isRu ? 'Сбросить все подписки и серверы? Это действие необратимо.' : 'Clear all subscriptions and servers? This cannot be undone.';

  // Tunnel settings (Happ-style)
  String get tunnelSection => isRu ? 'Настройки туннеля' : 'Tunnel Settings';
  String get fragmentation => isRu ? 'Включить фрагментацию' : 'TLS Fragmentation';
  String get fragmentationSub => isRu ? 'Дробит TLS-пакеты для обхода DPI' : 'Split TLS packets to defeat DPI';
  String get multiplexor => isRu ? 'Включить мультиплексор' : 'Multiplexor (Mux)';
  String get multiplexorSub => isRu ? 'Много соединений в одном потоке (не для Reality Vision)' : 'Many connections in one stream (not for Reality Vision)';
  String get preferredIp => isRu ? 'Предпочитаемый тип IP' : 'Preferred IP Type';
  String get routingRules => isRu ? 'Правила маршрутизации' : 'Routing Rules';
  String get routingRulesSub => isRu ? 'Что пускать через туннель' : 'What goes through the tunnel';
  String get routeAll => isRu ? 'Весь трафик' : 'All traffic';
  String get routeAllSub => isRu ? 'Проксировать всё' : 'Proxy everything';
  String get routeNoAds => isRu ? 'Блокировать рекламу' : 'Block ads';
  String get routeNoAdsSub => isRu ? 'Рекламные домены не открываются' : 'Ad domains are dropped';
  String get appProxy => isRu ? 'Прокси для приложений' : 'Per-App Proxy';
  String get appProxySub => isRu ? 'Какие приложения ходят через VPN' : 'Which apps use the VPN';
  String get allowLan => isRu ? 'Разрешить подключения из LAN' : 'Allow LAN Connections';
  String get allowLanSub => isRu ? 'Локальные адреса идут мимо туннеля' : 'Local addresses bypass the tunnel';
  String get pingService => isRu ? 'Сервис проверки пинга' : 'Ping Service';
  String get pingServiceSub => isRu ? 'Какой сайт замеряет задержку' : 'Which site measures the delay';
  String get custom => isRu ? 'Своя ссылка…' : 'Custom URL…';
  String get customPingHint => isRu ? 'https://ссылка-для-пинга' : 'https://ping-url';
  String get logs => isRu ? 'Логи' : 'Logs';
  String get logsSub => isRu ? 'Журнал ядра Xray' : 'Xray core log';
  String get logRefresh => isRu ? 'Обновить' : 'Refresh';
  String get logEmpty => isRu ? 'Логи пусты' : 'No log entries';

  // Grouping & search
  String get groupByCountry => isRu ? 'Группировать по странам' : 'Group by Country';
  String get groupByCountrySub => isRu ? 'Серверы собраны по флагам' : 'Servers grouped by flags';
  String get editServer => isRu ? 'Изменить сервер' : 'Edit Server';
  String get serverName => isRu ? 'Название' : 'Name';
  String get serverAddress => isRu ? 'Адрес' : 'Address';
  String get serverFlag => isRu ? 'Код флага (ru, us, nl…)' : 'Flag code (ru, us, nl…)';
  String get saveError => isRu ? 'Заполните название и адрес' : 'Name and address are required';
  String get refreshSubs => isRu ? 'Обновить подписки' : 'Refresh Subscriptions';
  String get refreshingSubs => isRu ? 'Обновляю подписки…' : 'Refreshing subscriptions…';
  String get subsUpdated => isRu ? 'Подписки обновлены' : 'Subscriptions updated';
  String get channel => isRu ? 'Наш канал' : 'Our Channel';
  String get channelSub => isRu ? 'Новости и обновления в Telegram' : 'News & updates on Telegram';

  // Ping service sheet
  String get customUrl => isRu ? 'Своя ссылка' : 'Custom URL';

  // Theme
  String get themeRow => isRu ? 'Светлая тема' : 'Light Theme';
  String get themeRowSub => isRu ? 'Белый интерфейс вместо тёмного' : 'Light interface instead of dark';
  String get ipTypeDesc => isRu ? 'Какие адреса предпочитать при подключении' : 'Which addresses to prefer when connecting';

  // Subscription info sheet
  String get infoTitle => isRu ? 'О подписке' : 'About subscription';
  String get infoTraffic => isRu ? 'Трафик' : 'Traffic';
  String get infoTrafficLeft => isRu ? 'Осталось' : 'Remaining';
  String get infoServers => isRu ? 'Серверов' : 'Servers';
  String get infoFavoriteServer => isRu ? 'Самый частый сервер' : 'Most used server';
  String get infoVpnTime => isRu ? 'Время с VPN' : 'Time with VPN';
  String get infoDescription => isRu ? 'Описание' : 'Description';

  // Background ping cache
  String get backgroundPing => isRu ? 'Фоновое обновление пинга' : 'Background Ping Refresh';
  String get backgroundPingSub => isRu ? 'Помнить пинги и обновлять в фоне' : 'Remember pings, refresh silently';
  String get pingCacheInterval => isRu ? 'Интервал обновления пинга' : 'Ping Refresh Interval';
  String get every5min => isRu ? 'Раз в 5 минут' : 'Every 5 minutes';
  String get every10min => isRu ? 'Раз в 10 минут' : 'Every 10 minutes';
  String get every30min => isRu ? 'Раз в 30 минут' : 'Every 30 minutes';
  String get everyHour => isRu ? 'Раз в час' : 'Every hour';

  // Add subscription variants
  String get addManual => isRu ? 'Вручную' : 'Manually';
  String get addManualSub => isRu ? 'Название и свои vless-ссылки' : 'Name and your vless links';
  String get addQr => isRu ? 'По QR-коду' : 'Scan QR Code';
  String get addQrSub => isRu ? 'Сканировать ссылку подписки' : 'Scan a subscription link';
  String get manualName => isRu ? 'Название подписки' : 'Subscription name';
  String get manualLinks => isRu ? 'Ссылки vless:// (по одной на строку)' : 'vless:// links (one per line)';
  String get manualEmpty => isRu ? 'Добавьте хотя бы одну рабочую ссылку' : 'Add at least one valid link';
  String get scanHint => isRu ? 'Наведите камеру на QR-код' : 'Point the camera at a QR code';

  // Emoji settings
  String get emojiDisplay => isRu ? 'Отображение эмодзи' : 'Emoji Display';
  String get emojiInApp => isRu ? 'Эмодзи в приложении' : 'In-App Emojis';
  String get emojiInAppSub => isRu ? 'Отображение флагов и значков в списках' : 'Flags & symbols in server lists';
  String get emojiNotification => isRu ? 'Эмодзи в уведомлении' : 'Notification Emojis';
  String get emojiNotificationSub => isRu ? 'Отображение значков в строке состояния' : 'Symbols in status notification';
  String get emojiShowAll => isRu ? 'Показывать все' : 'Show All';
  String get emojiHideFlags => isRu ? 'Скрывать только флаги' : 'Hide Flags Only';
  String get emojiHideAll => isRu ? 'Скрывать все эмодзи' : 'Hide All Emojis';
  String get notifPing => isRu ? 'Пинг в уведомлении' : 'Ping in Notification';
  String get notifPingSub => isRu ? 'Отображать актуальную задержку в строке состояния' : 'Show live server ping in status bar';
  String get enterManually => isRu ? 'Ввести вручную' : 'Enter manually';
  String get apply => isRu ? 'Применить' : 'Apply';

  // Profile
  String get nickHint => isRu ? 'Ваш ник' : 'Your nickname';
  String get statsTotalTraffic => isRu ? 'Всего трафика' : 'Total traffic';
  String get statsFavoriteServer => isRu ? 'Любимый сервер' : 'Favorite server';
  String get statsVpnTime => isRu ? 'Время с VPN' : 'Time with VPN';
  String get statsSubs => isRu ? 'Подписок' : 'Subscriptions';
  String get statsServers => isRu ? 'Серверов' : 'Servers';
}
