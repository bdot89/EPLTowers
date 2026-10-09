-- EPL Towers - English and Russian text.
-- E.T(key, ...) returns the text in the chosen language (string.format with the
-- extra arguments). The game's own fonts have no Cyrillic, so everything the
-- addon draws uses the bundled Fira Sans Condensed (see EPLTowersUI.lua).
-- Chat uses Arial Narrow, which does have Cyrillic, so chat lines work too.
local E = EPLTowers
local LOCALES = {}

LOCALES.en = {
  title = "EPL Towers",
  fac_Alliance = "Alliance", fac_Horde = "Horde", fac_Neutral = "Neutral", fac_Unknown = "Unknown",
  full_Alliance = "Full Alliance", full_Horde = "Full Horde",
  fullS_Alliance = "Full Alliance", fullS_Horde = "Full Horde",
  short_Alliance = "A", short_Horde = "H", short_Neutral = "N", short_full = "full",
  by_Alliance = "the Alliance", by_Horde = "the Horde",

  noBar = "No bar reading yet",
  noInfo = "No info yet",
  visitOrSync = "Visit the tower, or wait for a sync",
  lastSeenBar = "Bar %d when last seen",
  nobodyThere = "Nobody with the addon is there now",
  measuring = "Bar %d, measuring speed...",
  needsMove = "Needs the bar to move once (24s max)",
  fullySecure = "Fully %s, secure",
  nobodyCapping = "Nobody is capturing it",
  notMoving = "Bar %d, not moving",
  evenOrNobody = "Nobody capping, or even numbers",
  etaIn = "%s in %s",
  etaWithin = "%s within %s",
  etaNow = "%s any moment",
  thenList = "then %s",
  perPoint = "%ss/pt",
  speedUnknown = "speed not measured yet",
  slowing = "slowing down",
  cSecure = "secure", cHolding = "holding", cNow = "now",
  plainUnknown = "unknown",
  plainAgo = "%s: %s (%s)",
  plainBar = "%s: %s, bar %d",
  plainFull = "%s: %s (full)",
  plainStill = "%s: %s, bar %d not moving",
  plainCapping = "%s: %s, %s capping (%s)",
  plainCappingShort = "%s: %s, %s capping, %s",
  plainOwner = "%s: %s",
  annPrefix = "[EPL Towers] ",

  agoS = "%ds ago", agoM = "%dm ago", agoH = "%dh ago", agoD = "%dd ago",

  alertCaptured = "%s was captured by %s!",
  alertNeutral = "%s is now neutral",
  alertAttack = "%s is being captured by the enemy!",
  alertAttackEta = "%s is being captured by the enemy! %s",

  loaded = "v%s loaded. Type /eplt or click the minimap button.",
  asking = "asking your group for tower info...",
  askingGuild = "asking your group and guild for tower info...",
  noOne = "you are not in a group or guild, so there is nobody to sync with",
  setTo = "%s set to %s",
  forgotten = "%s forgotten",
  cleared = "all tower info cleared",
  resetAgain = "type /eplt reset again within 5 seconds to clear all tower info",
  ldAlready = "you are already in the LocalDefense channel",
  ldJoined = "joined the LocalDefense channel so you get tower capture news (turn off in Options)",
  onlyYouGroup = "not in a group, so only you see this:",
  onlyYouGuild = "not in a guild, so only you see this:",
  locked = "window locked",
  unlocked = "window unlocked, drag the title to move it",
  usageSet = "usage: /eplt set <pw|np|ew|cg> <alliance|horde|neutral>",
  annBlocked = "%s already posted that %ds ago, so it was not sent again. Here it is just for you:",
  annSelf = "You posted that %ds ago; you can post it again in %ds. Here it is just for you:",
  annBeaten = "%s is posting that already, so yours was not sent.",
  syncWait = "you just asked, give it a few seconds",
  langSet = "language: English",
  s1 = "/eplt - show or hide the window (or click the minimap button)",
  s2 = "/eplt sync - ask your group and guild for tower info now",
  s3 = "/eplt announce - post all towers in raid/party chat (/eplt announce guild)",
  s4 = "/eplt options - options    /eplt help - how it works",
  s5 = "/eplt map - show or hide the map    /eplt lock - lock or unlock moving",
  s6 = "/eplt set <pw|np|ew|cg> <alliance|horde|neutral> - set an owner by hand",
  s7 = "/eplt defense - join the LocalDefense channel now",
  s8 = "/eplt reset - clear all tower info",
  s9 = "/eplt en  or  /eplt ru - language",
  s10 = "/eplt anchor - move the capture alert banner",
  anchorSample = "Capture alerts appear here: drag me",
  anchorStart = "drag the alert banner where you want it, then click Done",
  anchorSaved = "alert position saved",

  live = "LIVE",
  youHere = "you are here",
  seenAgo = "seen %s",
  ownerInfoAgo = "owner info %s",
  you = "you",
  byHand = "you (by hand)",

  tOwner = "Owner: %s",
  tOwnerInfo = "Owner info %s",
  tFrom = ", from %s",
  tLiveYou = "LIVE: you are at the tower",
  tLiveOther = "LIVE: %s is at the tower",
  tLastReading = "Last bar reading %s",
  tBar = "Bar %d   (Alliance above 60, Horde below 40)",
  tApprox = "Speed not measured yet, so these times assume one player capping (the slowest case).",
  tSlow = "The bar is late for its next point, so it has slowed down (cappers left or died). Times are stretched to match.",
  tSpeed = "Speed: %.1f s per point, about %.1fx one player",
  tClick = "Click: announce it, or set the owner by hand",

  syncTitle = "Sync",
  syncBody = "Runs by itself: when you log in, enter Eastern Plaguelands or join a group, the addon asks your party/raid and guild what they know. Anyone standing at a tower shares its bar every 10 seconds.",
  peersTitle = "Players with the addon:",
  oldVersion = " (old version)",
  atTower = "at %s",
  noPeers = "No other players with this addon heard yet. Only players who have it installed can share.",
  youAtShare = "You are at %s, sharing its bar live",
  youAtNoShare = "You are at %s (not in a group or guild, so not shared)",
  liveFrom = "LIVE from %s at %s",
  noSync = "Not in a group or guild: nobody to sync with",
  synced = "Synced with %s, last news %s",
  player1 = "%d player", player2 = "%d players", player5 = "%d players",
  waiting = "Waiting for other players with this addon...",

  bMapShow = "Show map", bMapHide = "Hide map", bSync = "Sync now",
  bAnnounce = "Announce", bOptions = "Options", bHelp = "Help",
  dMap = "Shows or hides the map of Eastern Plaguelands with all four towers and where you are.",
  dSync = "Asks your party/raid and guild for their tower info right now. This also happens by itself when you log in, enter EPL or join a group.",
  dAnnounce = "Posts every tower's owner and timer in raid or party chat. Shift-click to post in guild chat instead. The same post goes out at most once every 30 seconds for the whole group, so several people with the addon can't spam chat.",
  dOptions = "Lock the window, minimap button, alerts, sounds, window size and more.",
  dHelp = "What everything in this window means and how sync works.",
  tClose = "Close",
  dClose = "Hides the window. Open it again with the minimap button or /eplt.",
  dragTip = "Drag the title to move the window.",
  langTip = "Language",
  langBody = "Switches the addon between English and Russian.",

  mAnnounce = "Announce this tower",
  mAnnounceD = "Posts this tower's owner and timers in raid or party chat (at most once every 30 seconds for the whole group).",
  mSet = "Set owner: %s",
  mSetD = "Use this if you know better than the addon. It is shared with your group. A live capture bar always wins.",
  mForget = "Forget this tower",
  mForgetD = "Clears what you know about this tower. Only affects you.",
  mClose = "Close",
  mCloseD = "Close this menu.",

  oTitle = "Options",
  o_lock = "Lock window",
  o_lock_d = "Stops the window and the minimap button from being dragged by accident.",
  o_minimap = "Minimap button",
  o_minimap_d = "Left-click opens this window, right-click opens Options. Drag it anywhere on screen.",
  o_autoShow = "Open in Eastern Plaguelands",
  o_autoShow_d = "Opens this window when you arrive in EPL and closes it again when you leave.",
  o_showMap = "Show the map",
  o_showMap_d = "The zone map with the four towers, their bars and where you are.",
  o_showGroup = "Show my group on the map",
  o_showGroup_d = "Party and raid members as dots in their class colour, the same positions the game's map shows (while you are in EPL).",
  groupTitle = "Group",
  dead = "dead",
  grp = "group %d",
  o_alerts = "Capture alerts",
  o_alerts_d = "Big message in the middle of the screen when any tower changes owner.",
  o_warn = "Under attack warning",
  o_warn_d = "Warns you when a tower your faction owns starts being captured.",
  o_sound = "Sounds",
  o_sound_d = "Plays the raid warning sound with alerts and warnings.",
  o_guild = "Share with guild",
  o_guild_d = "Also syncs with guild members anywhere, not only your party or raid.",
  o_localDefense = "Join LocalDefense",
  o_localDefense_d = "Keeps you in the LocalDefense channel while in EPL (rejoins if you leave), so you get the server's capture news.",
  oSize = "Window size: %d%%",
  oSizeD = "Makes the tower window bigger or smaller. The options panel stays the same size.",
  oResetPos = "Reset positions",
  oResetPosD = "Puts the window back in the middle of the screen and the minimap button back next to the minimap.",
  oClear = "Clear tower info",
  oClearD = "Forgets every tower's owner and bar (only for you). Click twice to confirm.",
  oClearConfirm = "Click again to clear",
  oMove = "Move alerts",
  oMoveDone = "Done",
  oMoveD = "Shows where capture alerts appear so you can drag them anywhere on screen. Click Done when it is in place.",

  hTitle = "How it works",
  help = {
    { "The window", "Each tower shows its owner and a copy of the in-game capture bar: blue side Alliance, grey middle neutral, red side Horde. The small arrow shows which way the bar is moving. On the map the gold dot is you and the coloured dots are your group (class colours); hover them for names and health." },
    { "LIVE", "Someone with this addon (maybe you) is standing at that tower right now, so the bar and timers are exact. Without LIVE you see the last reading and how old it is." },
    { "Timers", "Measured from the real bar. One player alone moves it one point every 24 seconds: from full to neutral takes about 16 minutes, end to end about 40. More players capture faster. \"within\" means the speed is still being measured and the time shown is the slowest case." },
    { "Sync runs by itself", "When you log in, enter Eastern Plaguelands or join a group, the addon asks your party/raid and guild what they know. Anyone at a tower shares its bar every 10 seconds. Only players with this addon can share, so give it to your friends." },
    { "Buttons", "Map shows or hides the map. Sync now asks for an update. Announce posts every tower in raid/party chat (Shift-click for guild); the same post goes out at most once every 30 seconds for the whole group. Click a tower for more: announce just that one, or set its owner by hand." },
    { "Moving things", "Drag the title to move the window. Drag the minimap button anywhere. Options > Move alerts shows the alert banner so you can drag it too. Lock the window and button in Options." },
    { "Language", "The flags at the top switch between English and Russian." },
    { "Typed commands", "/eplt   /eplt sync   /eplt announce   /eplt options   /eplt set cg horde   /eplt ru" },
  },

  mmLeft = "Left-click: show / hide the window",
  mmRight = "Right-click: options",
  mmDrag = "Drag: move this button",

  towers = {
    PW = { "Plaguewood Tower", "Plaguewood" },
    NP = { "Northpass Tower", "Northpass" },
    EW = { "Eastwall Tower", "Eastwall" },
    CG = { "Crown Guard Tower", "Crown Guard" },
  },
}

LOCALES.ru = {
  title = "Башни ВЧЗ",
  fac_Alliance = "Альянс", fac_Horde = "Орда", fac_Neutral = "Нейтральная", fac_Unknown = "Неизвестно",
  full_Alliance = "Полностью Альянс", full_Horde = "Полностью Орда",
  fullS_Alliance = "Полн. Альянс", fullS_Horde = "Полн. Орда",
  short_Alliance = "А", short_Horde = "О", short_Neutral = "Н", short_full = "полн.",
  by_Alliance = "Альянсом", by_Horde = "Ордой",

  noBar = "Полоса ещё не видна",
  noInfo = "Пока нет данных",
  visitOrSync = "Подойдите к башне или дождитесь синхронизации",
  lastSeenBar = "Полоса %d (последние данные)",
  nobodyThere = "Сейчас там нет никого с аддоном",
  measuring = "Полоса %d, измеряю скорость...",
  needsMove = "Нужно одно движение полосы (до 24 с)",
  fullySecure = "Полностью %s, удержана",
  nobodyCapping = "Никто не захватывает",
  notMoving = "Полоса %d, не движется",
  evenOrNobody = "Никто не захватывает или силы равны",
  etaIn = "%s через %s",
  etaWithin = "%s в течение %s",
  etaNow = "%s вот-вот",
  thenList = "затем %s",
  perPoint = "%s с/дел.",
  speedUnknown = "скорость ещё не измерена",
  slowing = "замедляется",
  cSecure = "удерж.", cHolding = "стоит", cNow = "сейчас",
  plainUnknown = "неизвестно",
  plainAgo = "%s: %s (%s)",
  plainBar = "%s: %s, полоса %d",
  plainFull = "%s: %s (полностью)",
  plainStill = "%s: %s, полоса %d не движется",
  plainCapping = "%s: %s, захватывает %s (%s)",
  plainCappingShort = "%s: %s, захватывает %s, %s",
  plainOwner = "%s: %s",
  annPrefix = "[Башни ВЧЗ] ",

  agoS = "%d с назад", agoM = "%d мин назад", agoH = "%d ч назад", agoD = "%d д назад",

  alertCaptured = "%s захвачена %s!",
  alertNeutral = "%s теперь нейтральна",
  alertAttack = "%s: враг начал захват!",
  alertAttackEta = "%s: враг начал захват! %s",

  loaded = "v%s загружен. Введите /eplt или нажмите кнопку у миникарты.",
  asking = "запрашиваю данные о башнях у группы...",
  askingGuild = "запрашиваю данные о башнях у группы и гильдии...",
  noOne = "вы не в группе и не в гильдии — не с кем синхронизироваться",
  setTo = "%s: владелец — %s",
  forgotten = "%s: данные стёрты",
  cleared = "все данные о башнях стёрты",
  resetAgain = "введите /eplt reset ещё раз в течение 5 секунд, чтобы стереть все данные",
  ldAlready = "вы уже в канале LocalDefense",
  ldJoined = "вы подключены к каналу LocalDefense — там новости о захвате башен (отключается в настройках)",
  onlyYouGroup = "вы не в группе — это видите только вы:",
  onlyYouGuild = "вы не в гильдии — это видите только вы:",
  locked = "окно закреплено",
  unlocked = "окно откреплено, перетаскивайте за заголовок",
  usageSet = "формат: /eplt set <pw|np|ew|cg> <alliance|horde|neutral>",
  annBlocked = "Это уже отправлено игроком %s %d с назад, повтора не будет. Только для вас:",
  annSelf = "Вы уже отправили это %d с назад; повторить можно через %d с. Только для вас:",
  annBeaten = "Игрок %s уже отправляет это, ваше сообщение не отправлено.",
  syncWait = "запрос только что отправлен, подождите несколько секунд",
  langSet = "язык: русский",
  s1 = "/eplt — показать или скрыть окно (или кнопка у миникарты)",
  s2 = "/eplt sync — запросить данные у группы и гильдии",
  s3 = "/eplt announce — все башни в чат рейда/группы (/eplt announce guild — в гильдию)",
  s4 = "/eplt options — настройки    /eplt help — справка",
  s5 = "/eplt map — карта    /eplt lock — закрепить или открепить окно",
  s6 = "/eplt set <pw|np|ew|cg> <alliance|horde|neutral> — указать владельца вручную",
  s7 = "/eplt defense — войти в канал LocalDefense",
  s8 = "/eplt reset — стереть все данные о башнях",
  s9 = "/eplt en  или  /eplt ru — язык",
  s10 = "/eplt anchor — передвинуть баннер оповещений",
  anchorSample = "Здесь появляются оповещения: перетащите",
  anchorStart = "перетащите баннер оповещений куда нужно и нажмите «Готово»",
  anchorSaved = "положение оповещений сохранено",

  live = "ВЖИВУЮ",
  youHere = "вы здесь",
  seenAgo = "данные %s",
  ownerInfoAgo = "владелец: %s",
  you = "вы",
  byHand = "вы (вручную)",

  tOwner = "Владелец: %s",
  tOwnerInfo = "Данные о владельце: %s",
  tFrom = ", от %s",
  tLiveYou = "ВЖИВУЮ: вы у башни",
  tLiveOther = "ВЖИВУЮ: %s у башни",
  tLastReading = "Последние данные полосы: %s",
  tBar = "Полоса %d   (Альянс выше 60, Орда ниже 40)",
  tApprox = "Скорость ещё не измерена: время рассчитано на одного захватчика (самый медленный случай).",
  tSlow = "Полоса запаздывает со следующим делением: захват замедлился (игроки ушли или погибли). Время пересчитано.",
  tSpeed = "Скорость: %.1f с за деление, примерно %.1fx от одного игрока",
  tClick = "Щелчок: объявить или указать владельца вручную",

  syncTitle = "Синхронизация",
  syncBody = "Работает сама: когда вы входите в игру, приходите в Восточные Чумные земли или вступаете в группу, аддон спрашивает группу/рейд и гильдию, что им известно. Любой у башни передаёт её полосу каждые 10 секунд.",
  peersTitle = "Игроки с аддоном:",
  oldVersion = " (старая версия)",
  atTower = "на месте: %s",
  noPeers = "Пока не слышно других игроков с аддоном. Делиться данными могут только те, у кого он установлен.",
  youAtShare = "Вы у башни «%s», полоса передаётся вживую",
  youAtNoShare = "Вы у башни «%s» (нет группы или гильдии, не передаётся)",
  liveFrom = "ВЖИВУЮ: %s у башни «%s»",
  noSync = "Нет группы или гильдии: не с кем синхронизироваться",
  synced = "Синхронизировано: %s, последние данные %s",
  player1 = "%d игрок", player2 = "%d игрока", player5 = "%d игроков",
  waiting = "Ждём других игроков с аддоном...",

  bMapShow = "Показать карту", bMapHide = "Скрыть карту", bSync = "Обновить",
  bAnnounce = "Объявить", bOptions = "Настройки", bHelp = "Справка",
  dMap = "Показывает или скрывает карту Восточных Чумных земель с четырьмя башнями и вашим положением.",
  dSync = "Сразу запрашивает данные о башнях у группы/рейда и гильдии. Это также происходит само при входе в игру, в ВЧЗ или в группу.",
  dAnnounce = "Пишет владельца и таймер каждой башни в чат рейда или группы. С Shift — в чат гильдии. Одно и то же сообщение уходит от всей группы не чаще раза в 30 секунд, так что несколько игроков с аддоном не заспамят чат.",
  dOptions = "Закрепить окно, кнопка у миникарты, оповещения, звуки, размер окна и другое.",
  dHelp = "Что означает всё в этом окне и как работает синхронизация.",
  tClose = "Закрыть",
  dClose = "Скрывает окно. Открыть снова можно кнопкой у миникарты или командой /eplt.",
  dragTip = "Перетащите заголовок, чтобы сдвинуть окно.",
  langTip = "Язык",
  langBody = "Переключает аддон между английским и русским.",

  mAnnounce = "Объявить эту башню",
  mAnnounceD = "Пишет владельца и таймеры этой башни в чат рейда или группы (от всей группы не чаще раза в 30 секунд).",
  mSet = "Владелец: %s",
  mSetD = "Если вы знаете лучше аддона. Передаётся вашей группе. Живая полоса захвата всегда важнее.",
  mForget = "Забыть эту башню",
  mForgetD = "Стирает данные об этой башне. Только у вас.",
  mClose = "Закрыть",
  mCloseD = "Закрыть меню.",

  oTitle = "Настройки",
  o_lock = "Закрепить окно",
  o_lock_d = "Окно и кнопка у миникарты не сдвинутся случайно.",
  o_minimap = "Кнопка у миникарты",
  o_minimap_d = "Левый щелчок открывает окно, правый — настройки. Кнопку можно перетащить куда угодно.",
  o_autoShow = "Открывать в ВЧЗ",
  o_autoShow_d = "Окно открывается, когда вы приходите в Восточные Чумные земли, и закрывается, когда уходите.",
  o_showMap = "Показывать карту",
  o_showMap_d = "Карта зоны с четырьмя башнями, их полосами и вашим положением.",
  o_showGroup = "Группа на карте",
  o_showGroup_d = "Участники группы и рейда — точки цвета их класса, там же, где на игровой карте (пока вы в ВЧЗ).",
  groupTitle = "Группа",
  dead = "мёртв",
  grp = "гр. %d",
  o_alerts = "Оповещения о захвате",
  o_alerts_d = "Крупное сообщение в центре экрана, когда любая башня меняет владельца.",
  o_warn = "Предупреждение об атаке",
  o_warn_d = "Предупреждает, когда башню вашей фракции начинают захватывать.",
  o_sound = "Звуки",
  o_sound_d = "Звук рейдового предупреждения вместе с оповещениями.",
  o_guild = "Делиться с гильдией",
  o_guild_d = "Синхронизация и с гильдией, где бы она ни была, а не только с группой или рейдом.",
  o_localDefense = "Канал LocalDefense",
  o_localDefense_d = "Держит вас в канале LocalDefense, пока вы в ВЧЗ (возвращает, если вы вышли), чтобы получать новости сервера о захвате.",
  oSize = "Размер окна: %d%%",
  oSizeD = "Делает окно башен больше или меньше. Панель настроек не меняется.",
  oResetPos = "Сбросить позиции",
  oResetPosD = "Возвращает окно в центр экрана, а кнопку — к миникарте.",
  oClear = "Очистить данные",
  oClearD = "Стирает владельцев и полосы всех башен (только у вас). Нужно нажать дважды.",
  oClearConfirm = "Ещё раз — стереть",
  oMove = "Двигать оповещения",
  oMoveDone = "Готово",
  oMoveD = "Показывает, где появляются оповещения о захвате, чтобы их можно было перетащить куда угодно. Нажмите «Готово», когда закончите.",

  hTitle = "Как это работает",
  help = {
    { "Окно", "Для каждой башни показан владелец и копия игровой полосы захвата: синяя сторона — Альянс, серая середина — нейтральная, красная — Орда. Стрелка показывает, куда движется полоса. На карте золотая точка — это вы, цветные точки — ваша группа (цвета классов); наведите на них, чтобы увидеть имена и здоровье." },
    { "ВЖИВУЮ", "Кто-то с аддоном (может быть, вы) стоит у этой башни прямо сейчас, поэтому полоса и таймеры точные. Без этой пометки видны последние данные и их возраст." },
    { "Таймеры", "Измеряются по настоящей полосе. Один игрок двигает её на одно деление за 24 секунды: от полной до нейтральной около 16 минут, от края до края около 40. Чем больше игроков, тем быстрее. «В течение» значит, что скорость ещё измеряется и показан самый медленный случай." },
    { "Синхронизация работает сама", "При входе в игру, в Восточные Чумные земли или в группу аддон спрашивает группу/рейд и гильдию, что им известно. Любой у башни передаёт её полосу каждые 10 секунд. Делиться могут только игроки с этим аддоном, так что дайте его друзьям." },
    { "Кнопки", "«Карта» показывает или скрывает карту. «Обновить» запрашивает свежие данные. «Объявить» пишет все башни в чат рейда/группы (с Shift — в гильдию); одно и то же сообщение уходит от всей группы не чаще раза в 30 секунд. Щелчок по башне: объявить только её или указать владельца вручную." },
    { "Перемещение", "Перетащите заголовок, чтобы сдвинуть окно. Кнопку у миникарты можно перетащить куда угодно. «Настройки» > «Двигать оповещения» показывает баннер оповещений, чтобы перетащить и его. Закрепить окно и кнопку можно в настройках." },
    { "Язык", "Флажки вверху переключают английский и русский." },
    { "Команды", "/eplt   /eplt sync   /eplt announce   /eplt options   /eplt set cg horde   /eplt en" },
  },

  mmLeft = "Левый щелчок: показать / скрыть окно",
  mmRight = "Правый щелчок: настройки",
  mmDrag = "Перетаскивание: сдвинуть кнопку",

  towers = {
    PW = { "Башня Чумного леса", "Чумной лес" },
    NP = { "Башня Северного перевала", "Северный перевал" },
    EW = { "Башня Восточной стены", "Восточная стена" },
    CG = { "Башня Королевской стражи", "Королевская стража" },
  },
}

E.LANGS = { "en", "ru" }
E.LANG_NAMES = { en = "English", ru = "Русский" }

function E.SetLanguage(lang)
  if not LOCALES[lang] then lang = "en" end
  E.lang = lang
  E.L = LOCALES[lang]
end
E.SetLanguage("en")

function E.T(key, a, b, c, d)
  local s = E.L[key] or LOCALES.en[key] or key
  if a == nil then return s end
  return string.format(s, a, b, c, d)
end

-- tower names in the chosen language (the game still matches the English ones)
function E.TN(key) return E.L.towers[key][1] end
function E.TS(key) return E.L.towers[key][2] end

-- owner / faction name; nil means unknown
function E.FN(fac) return E.T("fac_" .. (fac or "Unknown")) end

-- "3 players" / "3 игрока" (Russian has three plural forms)
function E.players(n)
  local m10, m100 = math.mod(n, 10), math.mod(n, 100)
  if m10 == 1 and m100 ~= 11 then return E.T("player1", n) end
  if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14) then return E.T("player2", n) end
  return E.T("player5", n)
end

-- who reported something: internal tokens shown in the chosen language
function E.SrcName(src)
  if src == "you" then return E.T("you") end
  if src == "@hand" then return E.T("byHand") end
  return tostring(src)
end

-- the same text in every language, to recognise other players' chat lines
function E.AllT(key)
  local out = {}
  for _, l in pairs(LOCALES) do
    if l[key] then table.insert(out, l[key]) end
  end
  return out
end

function E.AllTowerShorts(key)
  local out = {}
  for _, l in pairs(LOCALES) do table.insert(out, l.towers[key][2]) end
  return out
end
