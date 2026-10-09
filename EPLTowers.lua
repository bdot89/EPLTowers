-- EPL Towers 2.2 (vanilla 1.12 / Lua 5.0)
-- Live tracker for the four Eastern Plaguelands PvP towers.
-- This file: tower state, reading your capture bar, timers and sync.
-- EPLTowersUI.lua: the window, map, options, help and minimap button.
--
-- Data sources:
--   1. Your own capture bar, when you stand in range of a tower.
--   2. Other players running this addon (raid/party/guild addon messages).
--   3. LocalDefense / system messages naming a tower and a faction.
--
-- Checked on OctoWoW (EPLTowerProbe log of 9 Oct 2026 and the client's own
-- Interface\FrameXML\WorldStateFrame.lua):
--   * GetWorldStateUIInfo: state, text, icon, dynamicIcon, tooltip,
--     dynamicTooltip, extendedUI ("CAPTUREPOINT"), value, neutral width, 0
--   * value 100 = full Alliance, 1 = full Horde; the game draws the bar
--     40 / 20 / 40 (Alliance above 60, Horde below 40)
--   * one player alone moves the bar exactly 1 point every 24 seconds
--     (100 -> neutral in ~16 min, 100 -> Horde in ~24 min, end to end ~40 min)
--   * the values 60 and 40 are never shown (61 -> 59 and 41 -> 39 take 48 s)
--   * when the bar appears it shows a stale value for a moment
--   * the "Towers Controlled" counters and world map icons never change,
--     so the capture bar is the only reliable signal

EPLTowers = {}
local E = EPLTowers
E.VERSION = "2.2"

local ZONE      = "Eastern Plaguelands"
local PREFIX    = "EPLT"
local HEARTBEAT = 10    -- seconds between repeat broadcasts while you are at a tower
local LIVE_FOR  = 35    -- a tower counts as LIVE this long after the last bar reading
local SETTLE    = 1.5   -- ignore the bar for this long after it appears (stale value)
local SOLO_SECS = 24    -- one player alone: one bar point every 24 seconds
local FULL_A, FULL_H = 100, 1
E.LIVE_FOR, E.SOLO_SECS, E.FULL_A, E.FULL_H = LIVE_FOR, SOLO_SECS, FULL_A, FULL_H

-- x / y are the world map landmark positions read in game (EPLTowerProbe)
E.TOWERS = {
  { key = "PW", name = "Plaguewood Tower",  short = "Plaguewood",  x = 0.219, y = 0.323 },
  { key = "NP", name = "Northpass Tower",   short = "Northpass",   x = 0.566, y = 0.244 },
  { key = "EW", name = "Eastwall Tower",    short = "Eastwall",    x = 0.675, y = 0.479 },
  { key = "CG", name = "Crown Guard Tower", short = "Crown Guard", x = 0.397, y = 0.754 },
}
local TOWERS = E.TOWERS
local NT = table.getn(TOWERS)
E.byKey = {}
for i = 1, NT do E.byKey[TOWERS[i].key] = TOWERS[i] end

E.COLORS = {
  Alliance = { 0.30, 0.65, 1.00, "|cff4da6ff" },
  Horde    = { 1.00, 0.30, 0.30, "|cffff4d4d" },
  Neutral  = { 0.80, 0.80, 0.80, "|cffcccccc" },
  Unknown  = { 0.50, 0.50, 0.50, "|cff808080" },
}
local COLORS = E.COLORS

local DEFAULTS = {
  lock = false, minimap = true, autoShow = true, alerts = true,
  warn = true, sound = true, guild = true, scale = 1, showMap = true,
  localDefense = true, showGroup = true,
}

local f = CreateFrame("Frame", "EPLTowersEventFrame")
local db, state
E.peers = {}
local scan = { shownGT = nil, key = nil, last = nil, sentGT = 0, sentV = nil, jitter = 0 }
local lastB = {}   -- [key] = { v, t }: the last bar message anyone sent for a tower
local othersAt
local sync = { lastQueryGT = -1000, lastReplyGT = -1000, pending = nil, loginAt = nil, oPending = {} }
E.sync = sync

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

-- chat uses Arial Narrow, which has Cyrillic, so Russian prints fine here
function E.print(t)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. E.T("title") .. ":|r " .. t)
end

-- big message in the middle of the screen; fac picks the crest ("Alliance", "Horde", nil)
function E.alert(t, r, g, b, fac)
  E.print(t)
  if E.ShowBanner then
    E.ShowBanner(t, r or 1, g or 0.82, b or 0, fac)
  else
    UIErrorsFrame:AddMessage(t, r or 1, g or 0.82, b or 0, 1, 6)
  end
  if db.opts.sound then PlaySound("RaidWarning") end
end

function E.log(t)
  if not db then return end
  table.insert(db.log, date("%H:%M:%S") .. " " .. t)
  while table.getn(db.log) > 300 do table.remove(db.log, 1) end
end

function E.inZone()
  return GetRealZoneText() == ZONE
end

function E.fmt(sec)
  if not sec then return "?" end
  if sec < 0 then sec = 0 end
  sec = math.floor(sec + 0.5)
  if sec >= 3600 then
    return string.format("%d:%02d:%02d", math.floor(sec / 3600),
      math.floor(math.mod(sec, 3600) / 60), math.mod(sec, 60))
  end
  return string.format("%d:%02d", math.floor(sec / 60), math.mod(sec, 60))
end

function E.ago(sec)
  if not sec then return "?" end
  if sec < 0 then sec = 0 end
  if sec < 60 then return E.T("agoS", math.floor(sec)) end
  if sec < 3600 then return E.T("agoM", math.floor(sec / 60)) end
  if sec < 86400 then return E.T("agoH", math.floor(sec / 3600)) end
  return E.T("agoD", math.floor(sec / 86400))
end

-- split "a:b::d" into { "a", "b", "", "d" }
local function split(str, sep)
  local out = {}
  local pos = 1
  while true do
    local a, b = string.find(str, sep, pos, true)
    if not a then
      table.insert(out, string.sub(str, pos))
      return out
    end
    table.insert(out, string.sub(str, pos, a - 1))
    pos = b + 1
  end
end

function E.bounds(n)
  n = n or 20
  return 50 - n / 2, 50 + n / 2
end

function E.ownerFromValue(v, n)
  local lo, hi = E.bounds(n)
  if v > hi then return "Alliance" end
  if v < lo then return "Horde" end
  return "Neutral"
end

-- "pw", "plague", "crown guard" ... -> tower
function E.findTower(text)
  text = string.lower(text or "")
  if text == "" then return nil end
  for i = 1, NT do
    local t = TOWERS[i]
    if string.lower(t.key) == text then return t end
  end
  for i = 1, NT do
    local t = TOWERS[i]
    if string.find(string.lower(t.name), text, 1, true) == 1 then return t end
  end
  return nil
end

-------------------------------------------------------------------------------
-- Tower state
--
-- Saved (time() based): owner, ownerAt, ownerSrc, value, neutral, valueAt
-- Session (GetTime() based):
--   heardGT   last bar reading (LIVE while recent)
--   sinceGT   when the current value appeared, if someone saw it change
--   watchGT   since when the current value has been watched without a gap
--   trans     bar changes with known times, current direction only
--   dir       last known direction (1 = toward Alliance, -1 = toward Horde)
--   remoteRate / remoteRateGT   speed sent by the player at the tower
-------------------------------------------------------------------------------

local function newTower()
  return { trans = {} }
end

local function isLive(s, now)
  return s.heardGT and (now or GetTime()) - s.heardGT <= LIVE_FOR
end
E.isLive = isLive

local function addTransition(s, t, v, prev)
  local d
  if prev and prev ~= v then
    if v > prev then d = 1 else d = -1 end
  end
  local tr = s.trans
  local n = table.getn(tr)
  if n > 0 and t <= tr[n].t then return end
  -- the bar turned around: the old speed means nothing now
  if d and s.runDir and d ~= s.runDir then
    tr = {}
    s.trans = tr
  end
  if d then
    s.runDir = d
    s.dir = d
  end
  table.insert(tr, { t = t, v = v })
  local n2 = table.getn(tr)
  if n2 >= 3 then
    -- seconds per point of the newest step against the steps before it
    local dvNew = math.abs(tr[n2].v - tr[n2 - 1].v)
    local dvOld = math.abs(tr[n2 - 1].v - tr[1].v)
    if dvNew > 0 and dvOld > 0 then
      local newPer = (tr[n2].t - tr[n2 - 1].t) / dvNew
      local oldPer = (tr[n2 - 1].t - tr[1].t) / dvOld
      if newPer < oldPer * 0.55 or newPer > oldPer * 1.8 then
        -- big speed change (players arrived, left or died): only the newest step counts
        s.trans = { tr[n2 - 1], tr[n2] }
        return
      end
    end
  end
  while table.getn(tr) > 6 do table.remove(tr, 1) end
end

-- points per second (negative = toward Horde), 0 if standing still, nil if unknown
local function measuredRate(s, now)
  local tr = s.trans
  local n = table.getn(tr)
  if n >= 2 then
    local span = tr[n].t - tr[1].t
    if span > 0 then
      local r = (tr[n].v - tr[1].v) / span
      if r ~= 0 and now - tr[n].t > 2.5 / math.abs(r) + 5 then return 0 end
      return r
    end
  end
  -- unchanged for longer than even one player needs: nobody is moving it
  if s.watchGT and now - s.watchGT > SOLO_SECS * 2.5 + 5 then return 0 end
  return nil
end

function E.rateOf(s, now)
  now = now or GetTime()
  if s.remoteRate and s.remoteRateGT and now - s.remoteRateGT <= 15 then
    return s.remoteRate
  end
  return measuredRate(s, now)
end

-- 1 / -1 while the bar is moving, nil otherwise
function E.dirOf(s, now)
  if not isLive(s, now) then return nil end
  local r = E.rateOf(s, now)
  if r == nil then return s.dir end
  if r > 0 then return 1 end
  if r < 0 then return -1 end
  return nil
end

function E.setOwner(key, faction, src, when)
  local s = state[key]
  when = when or time()
  if s.ownerAt and when < s.ownerAt then return end -- older news
  local old = s.owner
  s.owner = faction
  s.ownerAt = when
  s.ownerSrc = src
  if old == faction then return end
  E.log("OWNER " .. key .. " " .. tostring(old) .. " -> " .. tostring(faction) .. " (" .. tostring(src) .. ")")
  if old and db.opts.alerts and time() - when < 120 then
    local c = COLORS[faction] or COLORS.Unknown
    if faction == "Neutral" then
      E.alert(E.T("alertNeutral", E.TN(key)), c[1], c[2], c[3])
    else
      E.alert(E.T("alertCaptured", E.TN(key), E.T("by_" .. faction)), c[1], c[2], c[3], faction)
    end
  end
end

-- One capture bar reading.
--   startGT     GetTime() when this value appeared, nil if unknown
--   continuous  the previous reading came from the same unbroken watch
-- Returns true if the reading was used.
function E.applyBar(key, v, n, src, startGT, continuous)
  local s = state[key]
  local now = GetTime()
  local wasLive = isLive(s, now)
  if s.value ~= v then
    -- a reporter who is behind someone else: keep the newer value
    if startGT and s.sinceGT and wasLive and startGT < s.sinceGT - 0.25 then return false end
    local prev = s.value
    if not (continuous and wasLive) then
      s.trans = {}
      s.runDir = nil
      s.dir = nil
      prev = nil
    end
    s.prevValue = s.value
    s.value = v
    s.sinceGT = startGT
    s.watchGT = startGT or now
    if startGT then addTransition(s, startGT, v, prev) end
  elseif not wasLive then
    -- same value after a gap: nothing about the old speed can be trusted
    s.trans = {}
    s.runDir = nil
    s.dir = nil
    s.sinceGT = startGT
    s.watchGT = startGT or now
  elseif startGT and not s.sinceGT then
    s.sinceGT = startGT
    if not s.watchGT or startGT < s.watchGT then s.watchGT = startGT end
  end
  s.neutral = n or s.neutral or 20
  s.heardGT = now
  s.valueAt = time()
  s.src = src
  local o = E.ownerFromValue(v, s.neutral)
  if o ~= s.owner then E.setOwner(key, o, src) end
  return true
end

-- Everything the UI needs to show timers for one tower.
--   live, value, neutral, rate (pts/s), approx (speed assumed = one player),
--   dir, per (seconds per point), speed (x one player), milestones = {
--   { label, fac, target, eta } ... } in the order they will happen.
function E.estimate(key, now)
  local s = state[key]
  now = now or GetTime()
  local e = { value = s.value, neutral = s.neutral or 20 }
  e.live = isLive(s, now)
  if not e.live or not s.value then return e end
  local r = E.rateOf(s, now)
  if r == nil and s.dir then
    -- direction known, speed not yet: one player alone is the slowest case
    r = s.dir / SOLO_SECS
    e.approx = true
  end
  e.rate = r
  if not r or r == 0 then return e end
  if r > 0 then e.dir = 1 else e.dir = -1 end
  e.per = 1 / math.abs(r)
  local elapsed = 0
  if s.sinceGT then elapsed = now - s.sinceGT end
  local v = s.value
  local lo, hi = E.bounds(e.neutral)
  if s.sinceGT and not e.approx then
    -- Overdue for the next point: the bar has slowed down (cappers left or
    -- died). It can't be faster than the time already waited, so stretch the
    -- speed to that. The game skips 60 and 40, so those steps take two points.
    local steps = 1
    if v + e.dir == hi or v + e.dir == lo then steps = 2 end
    local need = steps * e.per
    local grace = math.max(1, need * 0.5)
    if elapsed > need + grace then
      e.per = (elapsed - grace) / steps
      e.slowing = true
    end
  end
  e.speed = SOLO_SECS / e.per
  local m = {}
  if e.dir < 0 then
    if v > hi then table.insert(m, { label = "Neutral", fac = "Neutral", target = math.floor(hi) }) end
    if v >= lo then table.insert(m, { label = "Horde", fac = "Horde", target = math.ceil(lo) - 1 }) end
    if v > FULL_H then table.insert(m, { label = "Full Horde", fac = "Horde", target = FULL_H, full = true }) end
  else
    if v < lo then table.insert(m, { label = "Neutral", fac = "Neutral", target = math.ceil(lo) }) end
    if v <= hi then table.insert(m, { label = "Alliance", fac = "Alliance", target = math.floor(hi) + 1 }) end
    if v < FULL_A then table.insert(m, { label = "Full Alliance", fac = "Alliance", target = FULL_A, full = true }) end
  end
  for i = 1, table.getn(m) do
    local eta = math.abs(v - m[i].target) * e.per - elapsed
    if eta < 0 then eta = 0 end
    m[i].eta = eta
  end
  e.milestones = m
  return e
end

-- "Horde", "Full Horde", "Neutral" ... in the chosen language
local function mLabel(m)
  if m.full then return E.T("full_" .. m.fac) end
  return E.FN(m.fac)
end

local function etaText(e, m)
  if m.eta < 1 then return E.T("etaNow", mLabel(m)) end -- e.g. the skipped 60 / 40 step
  if e.approx then return E.T("etaWithin", mLabel(m), E.fmt(m.eta)) end
  return E.T("etaIn", mLabel(m), E.fmt(m.eta))
end

-- Text for one tower: line1, line2 (window), compact (map), plain (chat)
function E.describe(key)
  local s = state[key]
  local e = E.estimate(key)
  local d = { e = e, line2 = "", compact = "" }
  local name = E.TS(key)
  local owner = s.owner and E.FN(s.owner) or E.T("plainUnknown")
  if not s.value then
    if s.owner then d.line1 = E.T("noBar") else d.line1 = E.T("noInfo") end
    d.line2 = E.T("visitOrSync")
    d.plain = E.T("plainOwner", name, owner)
    return d
  end
  if not e.live then
    d.line1 = E.T("lastSeenBar", s.value)
    d.line2 = E.T("nobodyThere")
    d.plain = E.T("plainAgo", name, owner, E.ago(time() - (s.valueAt or time())))
    return d
  end
  if not e.rate then
    d.line1 = E.T("measuring", s.value)
    d.line2 = E.T("needsMove")
    d.compact = "..."
    d.plain = E.T("plainBar", name, owner, s.value)
  elseif e.rate == 0 then
    if s.value >= FULL_A or s.value <= FULL_H then
      local c = COLORS[s.owner or "Unknown"]
      d.line1 = c[4] .. E.T("fullySecure", owner) .. "|r"
      d.line2 = E.T("nobodyCapping")
      d.compact = E.T("cSecure")
      d.plain = E.T("plainFull", name, owner)
    else
      d.line1 = E.T("notMoving", s.value)
      d.line2 = E.T("evenOrNobody")
      d.compact = E.T("cHolding")
      d.plain = E.T("plainStill", name, owner, s.value)
    end
  else
    local m = e.milestones
    local first = m[1]
    local capper
    if e.dir > 0 then capper = E.FN("Alliance") else capper = E.FN("Horde") end
    if first then
      d.line1 = COLORS[first.fac][4] .. etaText(e, first) .. "|r"
      local rest = {}
      for i = 2, table.getn(m) do
        local lab = m[i].full and E.T("fullS_" .. m[i].fac) or mLabel(m[i])
        table.insert(rest, lab .. " " .. E.fmt(m[i].eta))
      end
      local speed
      if e.approx then
        speed = E.T("speedUnknown")
      elseif e.slowing then
        speed = E.T("slowing")
      elseif e.per < 10 then
        speed = E.T("perPoint", string.format("%.1f", e.per))
      else
        speed = E.T("perPoint", math.floor(e.per + 0.5))
      end
      if table.getn(rest) > 0 then
        d.line2 = E.T("thenList", table.concat(rest, ", ")) .. "  |cff888888" .. speed .. "|r"
      else
        d.line2 = "|cff888888" .. speed .. "|r"
      end
      local short
      if first.full then short = E.T("short_full") else short = E.T("short_" .. first.fac) end
      local when = (e.approx and "<" or "") .. E.fmt(first.eta)
      if first.eta < 1 then when = E.T("cNow") end
      d.compact = COLORS[first.fac][4] .. short .. " " .. when .. "|r"
      local plain = {}
      for i = 1, table.getn(m) do
        table.insert(plain, etaText(e, m[i]))
      end
      d.plain = E.T("plainCapping", name, owner, capper, table.concat(plain, ", "))
      d.plainShort = E.T("plainCappingShort", name, owner, capper, etaText(e, first))
    else
      d.line1 = E.T("plainBar", name, owner, s.value)
      d.plain = d.line1
    end
  end
  return d
end

local function checkWarn(key, s, now)
  local my = E.myFaction
  local d = E.dirOf(s, now)
  local against = d and my and ((my == "Horde" and d > 0) or (my == "Alliance" and d < 0))
  if against and s.owner == my then
    if not s.warned then
      s.warned = true
      if db.opts.warn then
        local e = E.estimate(key, now)
        local m = e.milestones and e.milestones[1]
        local enemy
        if my == "Horde" then enemy = "Alliance" else enemy = "Horde" end
        if m then
          E.alert(E.T("alertAttackEta", E.TN(key), etaText(e, m)), 1, 0.55, 0.1, enemy)
        else
          E.alert(E.T("alertAttack", E.TN(key)), 1, 0.55, 0.1, enemy)
        end
      end
    end
  elseif not against then
    s.warned = nil
  end
end

function E.forget(key)
  state[key] = newTower()
  if scan.key == key then scan.last = nil end
end

function E.resetTowers()
  for i = 1, NT do state[TOWERS[i].key] = newTower() end
  scan.last = nil
  E.print(E.T("cleared"))
end

-------------------------------------------------------------------------------
-- Sync
--
-- B:KEY:value:neutral:since:secsPerPoint:dir  live bar from someone at the tower
--   (1.x sends only B:KEY:value:neutral; extra fields are ignored by it)
-- O:KEY:Faction:ageSecs                       owner news (LocalDefense / by hand)
-- Q: or Q:2                                   "what do you know?" (1.x / 2.x)
-- S:KEY,o,oAge,v,n,vAge,since,spp,dir;...      everything one player knows
-------------------------------------------------------------------------------

local LETTER = { Alliance = "A", Horde = "H", Neutral = "N" }
local FROM_LETTER = { A = "Alliance", H = "Horde", N = "Neutral" }

function E.canSync()
  return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 or (db.opts.guild and IsInGuild())
end

function E.send(msg)
  local sent = false
  if GetNumRaidMembers() > 0 then
    SendAddonMessage(PREFIX, msg, "RAID")
    sent = true
  elseif GetNumPartyMembers() > 0 then
    SendAddonMessage(PREFIX, msg, "PARTY")
    sent = true
  end
  if db.opts.guild and IsInGuild() then
    SendAddonMessage(PREFIX, msg, "GUILD")
    sent = true
  end
  return sent
end

local function rateField(s, now)
  local r = E.rateOf(s, now)
  if not r then return "" end
  if r == 0 then return "0" end
  return string.format("%.2f", 1 / r)
end

-- seconds since the current value appeared, to 0.1 s so fast bars stay exact
local function sinceField(s, now)
  if not s.sinceGT then return "" end
  return string.format("%.1f", math.max(0, now - s.sinceGT))
end

local function sendBar(key, s, now)
  local since = sinceField(s, now)
  local dir = ""
  if s.dir then dir = s.dir end
  E.send("B:" .. key .. ":" .. s.value .. ":" .. (s.neutral or 20) .. ":" .. since
    .. ":" .. rateField(s, now) .. ":" .. dir)
end

function E.requestSync(manual)
  local now = GetTime()
  if not manual and now - sync.lastQueryGT < 20 then return false end
  if manual and now - sync.lastQueryGT < 5 then
    E.print(E.T("syncWait"))
    return false
  end
  sync.lastQueryGT = now
  local ok = E.send("Q:2")
  if manual then
    if ok then
      if db.opts.guild and IsInGuild() then E.print(E.T("askingGuild")) else E.print(E.T("asking")) end
    else
      E.print(E.T("noOne"))
    end
  end
  return ok
end

local function snapshot()
  local now, nowT = GetTime(), time()
  local parts = {}
  for i = 1, NT do
    local k = TOWERS[i].key
    local s = state[k]
    if s.owner or s.value then
      local since, spp, dir = "", "", ""
      if isLive(s, now) then
        since = sinceField(s, now)
        spp = rateField(s, now)
        if s.dir then dir = s.dir end
      end
      local oAge, vAge = "", ""
      if s.ownerAt then oAge = math.max(0, nowT - s.ownerAt) end
      if s.valueAt then vAge = math.max(0, nowT - s.valueAt) end
      table.insert(parts, k .. "," .. (LETTER[s.owner] or "") .. "," .. oAge .. ","
        .. (s.value or "") .. "," .. (s.neutral or "") .. "," .. vAge .. ","
        .. since .. "," .. spp .. "," .. dir)
    end
  end
  if table.getn(parts) == 0 then return nil end
  return "S:" .. table.concat(parts, ";")
end

local function sendSnapshot(legacy)
  local msg = snapshot()
  if not msg then return end
  E.send(msg)
  if legacy then
    -- 1.x only understands owner lines
    local nowT = time()
    for i = 1, NT do
      local k = TOWERS[i].key
      local s = state[k]
      if s.owner and s.ownerAt then
        E.send("O:" .. k .. ":" .. s.owner .. ":" .. math.max(0, nowT - s.ownerAt))
      end
    end
  end
  sync.lastReplyGT = GetTime()
end

local function onQuery(legacy)
  if not snapshot() then return end
  local now = GetTime()
  if now - sync.lastReplyGT < 8 then return end
  if sync.pending then
    if legacy then sync.pending.legacy = true end
    return
  end
  -- wait a moment so one player answers instead of the whole raid
  sync.pending = { fire = now + 0.4 + math.random() * 2.2, legacy = legacy }
end

local function onRemoteBar(key, v, n, sender, legacy, since, spp, dir)
  if scan.key == key and scan.last then return end -- you can see that bar yourself
  local s = state[key]
  local now = GetTime()
  local wasLive = isLive(s, now)
  local startGT
  if since then
    startGT = now - since
  elseif legacy and wasLive and s.value ~= v then
    -- 1.x reporters only send changes as they happen, so "now" is close
    if v == s.prevValue and s.sinceGT and now - s.sinceGT < 3 then return end
    startGT = now
  end
  if not E.applyBar(key, v, n, sender, startGT, true) then return end
  if not legacy then
    if spp == 0 then
      s.remoteRate = 0
    elseif spp then
      s.remoteRate = 1 / spp
    else
      s.remoteRate = nil
    end
    s.remoteRateGT = now
    if dir == 1 or dir == -1 then s.dir = dir end
  end
end

local function mergeSnapshot(body, sender)
  local nowT = time()
  local seen = {}
  local covered = true
  for part in string.gfind(body, "[^;]+") do
    local a = split(part, ",")
    local key = a[1]
    local s = state[key]
    if s then
      seen[key] = true
      local o, oAge = FROM_LETTER[a[2] or ""], tonumber(a[3] or "")
      local v, n, vAge = tonumber(a[4] or ""), tonumber(a[5] or ""), tonumber(a[6] or "")
      local since, spp, dir = tonumber(a[7] or ""), tonumber(a[8] or ""), tonumber(a[9] or "")
      local theirOwnerAt = oAge and (nowT - oAge) or 0
      local theirValueAt = vAge and (nowT - vAge) or 0
      if o and oAge then E.setOwner(key, o, sender, theirOwnerAt) end
      local mine = scan.key == key and scan.last
      if v and vAge and not mine and (not s.valueAt or theirValueAt > s.valueAt) then
        if vAge <= LIVE_FOR then
          -- they are hearing that bar live right now
          local now = GetTime()
          local startGT
          if since then startGT = now - since end
          if E.applyBar(key, v, n, sender, startGT, true) then
            s.heardGT = now - vAge
            s.valueAt = theirValueAt
            if spp == 0 then s.remoteRate = 0 elseif spp then s.remoteRate = 1 / spp else s.remoteRate = nil end
            s.remoteRateGT = now
            if dir == 1 or dir == -1 then s.dir = dir end
          end
        elseif not isLive(s) then
          -- an older reading that is still newer than ours
          if s.value ~= v then
            s.trans = {}
            s.runDir = nil
            s.dir = nil
            s.sinceGT = nil
          end
          s.value = v
          s.neutral = n or s.neutral
          s.valueAt = theirValueAt
          s.src = sender
        end
      end
      if (s.ownerAt or 0) > theirOwnerAt + 2 or (s.valueAt or 0) > theirValueAt + 2 then covered = false end
    end
  end
  for i = 1, NT do
    local s = state[TOWERS[i].key]
    if not seen[TOWERS[i].key] and (s.owner or s.value) then covered = false end
  end
  -- someone already answered with everything we know: no need to repeat it
  if covered and sync.pending and not sync.pending.legacy then sync.pending = nil end
end

-------------------------------------------------------------------------------
-- Announcements: one post per thing per group, however many people have the
-- addon. Every client remembers each announcement it sees (its own, other
-- players' "A" claims, and the chat lines themselves, which also catches
-- older versions) and won't post the same one again for ANN_COOLDOWN seconds.
-- If two people click at the same moment, both send a claim and wait ANN_HOLD.
-- The first name in byte order posts and the other stops.
--   A:<KEY or ALL>:<RAID|PARTY|GUILD>
-------------------------------------------------------------------------------

local ANN_COOLDOWN = 30
local ANN_HOLD = 0.8
local annSeen = {}  -- ["RAID:CG"], ["RAID:ALL"] = { t = GetTime(), by = name }
local annPending    -- { chan, scope, msg, due }

-- byte order, so every client agrees whatever its system language
local function nameBefore(a, b)
  local la, lb = string.len(a), string.len(b)
  for i = 1, math.min(la, lb) do
    local x, y = string.byte(a, i), string.byte(b, i)
    if x ~= y then return x < y end
  end
  return la < lb
end

local function annRecent(chan, scope, now)
  local a = annSeen[chan .. ":" .. scope]
  if a and now - a.t < ANN_COOLDOWN then return a end
  if scope ~= "ALL" then
    -- a post about every tower covers each single tower too
    a = annSeen[chan .. ":ALL"]
    if a and now - a.t < ANN_COOLDOWN then return a end
  end
  return nil
end

-- someone else claimed (claim = true) or already posted chan / scope
local function annHeard(chan, scope, by, claim)
  local p = annPending
  if p and p.chan == chan and (p.scope == scope or scope == "ALL") then
    if claim and nameBefore(UnitName("player") or "", by) then
      return -- we both clicked at once and our name goes first: we post, they stop
    end
    annPending = nil
    E.print(E.T("annBeaten", by))
  end
  annSeen[chan .. ":" .. scope] = { t = GetTime(), by = by }
end

-- called by the Announce button / tower menu / slash command
function E.tryAnnounce(chan, scope, msg)
  local now = GetTime()
  local a = annRecent(chan, scope, now)
  if a then
    local ago = math.floor(now - a.t)
    if a.by == "you" then
      E.print(E.T("annSelf", ago, ANN_COOLDOWN - ago))
    else
      E.print(E.T("annBlocked", a.by, ago))
    end
    E.print(msg)
    return
  end
  if annPending then return end -- a post is already on its way
  annPending = { chan = chan, scope = scope, msg = msg, due = now + ANN_HOLD }
  SendAddonMessage(PREFIX, "A:" .. scope .. ":" .. chan, chan)
end

local function annFire(now)
  local p = annPending
  if not p or now < p.due then return end
  annPending = nil
  annSeen[p.chan .. ":" .. p.scope] = { t = now, by = "you" }
  SendChatMessage(p.msg, p.chan)
end

-- an announcement line in raid / party / guild chat from another player
local ANN_CHAT = {
  CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
  CHAT_MSG_PARTY = "PARTY", CHAT_MSG_GUILD = "GUILD",
}

local function onGroupChat(msg, chan, sender)
  if not msg or not sender or sender == UnitName("player") then return end
  local prefixes = E.AllT("annPrefix")
  for i = 1, table.getn(prefixes) do
    local pre = prefixes[i]
    if string.sub(msg, 1, string.len(pre)) == pre then
      local scope = "ALL"
      if not string.find(msg, " / ", 1, true) then
        -- a single tower: "<prefix><tower>: ..." in either language
        for j = 1, NT do
          local names = E.AllTowerShorts(TOWERS[j].key)
          for n = 1, table.getn(names) do
            if string.find(msg, names[n] .. ":", 1, true) then scope = TOWERS[j].key end
          end
        end
      end
      annHeard(chan, scope, sender, false)
      return
    end
  end
end

local function onAddon(msg, sender)
  if not msg or not sender or sender == "" then return end
  local kind = string.sub(msg, 1, 1)
  local body = string.sub(msg, 3)
  local now = GetTime()
  local p = E.peers[sender]
  if not p then
    p = {}
    E.peers[sender] = p
  end
  p.seen = time()
  sync.lastNewsGT = now
  sync.lastNewsFrom = sender
  if kind == "B" then
    local a = split(body, ":")
    local key, v, n = a[1], tonumber(a[2] or ""), tonumber(a[3] or "")
    if not E.byKey[key] or not v then return end
    local legacy = table.getn(a) < 4
    if not legacy then p.v2 = true end
    p.at = key
    p.atGT = now
    lastB[key] = { v = v, t = now }
    onRemoteBar(key, v, n, sender, legacy, tonumber(a[4] or ""), tonumber(a[5] or ""), tonumber(a[6] or ""))
  elseif kind == "O" then
    local a = split(body, ":")
    if E.byKey[a[1]] and (a[2] == "Alliance" or a[2] == "Horde" or a[2] == "Neutral") then
      E.setOwner(a[1], a[2], sender, time() - (tonumber(a[3] or "") or 0))
      -- someone already passed this news on: no need for us to repeat it
      local op = sync.oPending[a[1]]
      if op and op.fac == a[2] then sync.oPending[a[1]] = nil end
    end
  elseif kind == "A" then
    local a = split(body, ":")
    local scope, chan = a[1], a[2]
    if (scope == "ALL" or E.byKey[scope]) and (chan == "RAID" or chan == "PARTY" or chan == "GUILD") then
      annHeard(chan, scope, sender, true)
    end
  elseif kind == "Q" then
    if body == "2" then p.v2 = true end
    onQuery(body ~= "2")
  elseif kind == "S" then
    p.v2 = true
    sync.lastSyncGT = now
    sync.lastSyncFrom = sender
    mergeSnapshot(body, sender)
  end
end

function E.peerCount()
  local n, nowT = 0, time()
  for _, p in pairs(E.peers) do
    if nowT - p.seen < 900 then n = n + 1 end
  end
  return n
end

-- Hand-set owner, shared with the group. A live capture bar still wins.
function E.manualOwner(key, fac)
  E.setOwner(key, fac, "@hand", time())
  E.send("O:" .. key .. ":" .. fac .. ":0")
  E.print(E.T("setTo", E.TN(key), COLORS[fac][4] .. E.FN(fac) .. "|r"))
end

-------------------------------------------------------------------------------
-- Reading your own capture bar
-------------------------------------------------------------------------------

local function readBar()
  local n = GetNumWorldStateUI() or 0
  for i = 1, n do
    local st, _, _, _, _, _, ext, v, nw = GetWorldStateUIInfo(i)
    if ext == "CAPTUREPOINT" and st and st > 0 and v then return v, nw end
  end
  return nil
end

-- your position on the Eastern Plaguelands map, or nil
-- true when the map API shows Eastern Plaguelands, so GetPlayerMapPosition works for
-- you and your group. Switches the map there only while the world map is closed and
-- you are in EPL (the game's own map does the same with SetMapToCurrentZone).
function E.mapIsEPL()
  if GetMapInfo() == "EasternPlaguelands" then return true end
  if WorldMapFrame and WorldMapFrame:IsVisible() then return false end
  if not E.inZone() then return false end
  SetMapToCurrentZone()
  return GetMapInfo() == "EasternPlaguelands"
end

function E.playerPos()
  if not E.mapIsEPL() then return nil end
  local x, y = GetPlayerMapPosition("player")
  if not x or (x == 0 and y == 0) then return nil end
  return x, y
end

local function currentTower()
  local sub = GetSubZoneText()
  for i = 1, NT do
    if TOWERS[i].name == sub then return TOWERS[i] end
  end
  local x, y = E.playerPos()
  if not x then return scan.key and E.byKey[scan.key] end
  local best, bestD
  for i = 1, NT do
    local t = TOWERS[i]
    local dx, dy = (x - t.x) * 1.5, y - t.y -- the map is 1.5 times wider than tall
    local d = dx * dx + dy * dy
    if not bestD or d < bestD then best, bestD = t, d end
  end
  if bestD and bestD < 0.06 * 0.06 then return best end
  return nil
end

-- another addon user has sent this tower's bar lately (so they are there too)
function othersAt(key, now)
  for _, p in pairs(E.peers) do
    if p.at == key and p.atGT and now - p.atGT < 15 then return true end
  end
  return false
end

function E.localKey()
  if scan.last then return scan.key end
  return nil
end

function E.scanLocal()
  local now = GetTime()
  local v, n
  if E.inZone() then v, n = readBar() end
  if not v then
    scan.shownGT = nil
    scan.last = nil
    return
  end
  if not scan.shownGT then
    scan.shownGT = now
    return
  end
  if now - scan.shownGT < SETTLE then return end
  local t = currentTower()
  if not t then return end
  if scan.key ~= t.key then
    scan.key = t.key
    scan.last = nil
  end
  local s = state[t.key]
  local changed = scan.last and v ~= scan.last
  s.remoteRate = nil -- your own eyes beat anyone's report
  if changed then
    E.applyBar(t.key, v, n, "you", now, true)
  else
    E.applyBar(t.key, v, n, "you", nil, scan.last ~= nil)
  end
  scan.last = v

  -- Sharing. With 10 addon users at one tower, only one of them should send
  -- each point. Alone you send at once; with others there you wait a random
  -- moment and stay quiet if one of them already sent it. The message carries
  -- when the point changed, so a short wait doesn't make anyone's timer late.
  local heard = lastB[t.key]
  if changed or scan.sentV ~= v then
    scan.sentV = v
    if othersAt(t.key, now) then
      scan.pend = { key = t.key, v = v, at = now, due = now + 0.2 + math.random() * 1.3 }
    else
      scan.pend = nil
      sendBar(t.key, s, now)
      scan.sentGT = now
    end
  end
  local p = scan.pend
  if p and now >= p.due then
    scan.pend = nil
    if p.key == t.key and p.v == v and not (heard and heard.v == v and heard.t >= p.at - 0.5) then
      sendBar(t.key, s, now)
      scan.sentGT = now
    end
  end
  -- keep-alive: only when nobody at this tower has sent anything for a while
  local lastAny = scan.sentGT
  if heard and heard.t > lastAny then lastAny = heard.t end
  if now - lastAny >= HEARTBEAT + scan.jitter then
    sendBar(t.key, s, now)
    scan.sentGT = now
    scan.jitter = math.random() * 3
  end
end

-------------------------------------------------------------------------------
-- Chat messages naming a tower
-------------------------------------------------------------------------------

local function factionIn(msg)
  local m = string.lower(msg)
  local a = string.find(m, "alliance", 1, true)
  local h = string.find(m, "horde", 1, true)
  if not (string.find(m, "taken", 1, true) or string.find(m, "captur", 1, true)
      or string.find(m, "control", 1, true) or string.find(m, "claimed", 1, true)) then
    return nil
  end
  if a and not h then return "Alliance" end
  if h and not a then return "Horde" end
  if a and h then
    -- "taken by the Horde from the Alliance": the faction after "by the" wins
    local _, _, by = string.find(m, "by the (%a+)")
    if by == "alliance" then return "Alliance" end
    if by == "horde" then return "Horde" end
  end
  return nil
end

local function onChat(msg, chan, ev, sender)
  if not msg or not E.inZone() then return end
  -- channel messages only count from LocalDefense and only from the server
  -- (no player name), so nobody can fake a capture by typing it in chat
  if ev == "CHAT_MSG_CHANNEL" then
    if not chan or not string.find(chan, "LocalDefense", 1, true) then return end
    if sender and sender ~= "" then return end
  end
  for i = 1, NT do
    local t = TOWERS[i]
    if string.find(msg, t.name, 1, true) then
      E.log("CHAT " .. ev .. " [" .. tostring(chan) .. "] " .. msg)
      local fac = factionIn(msg)
      if fac then
        E.setOwner(t.key, fac, "LocalDefense")
        -- everyone in the zone hears this line: wait a random moment and pass it
        -- on only if nobody else has (for group/guild members outside EPL)
        sync.oPending[t.key] = { fac = fac, due = GetTime() + 0.3 + math.random() * 2.5 }
      end
      return
    end
  end
end

-------------------------------------------------------------------------------
-- LocalDefense: the server's capture news goes there, so keep players in it
-- while they are in Eastern Plaguelands (option "Join LocalDefense").
-------------------------------------------------------------------------------

local function inLocalDefense()
  for i = 1, 10 do
    local _, name = GetChannelName(i)
    if name and string.find(name, "^LocalDefense") then return true end
  end
  return false
end

function E.checkLocalDefense(manual)
  if inLocalDefense() then
    if manual then E.print(E.T("ldAlready")) end
    return
  end
  -- exactly what the game's own /join does: join, then list it in the main chat window
  local frame = DEFAULT_CHAT_FRAME
  local zoneChannel, channelName = JoinChannelByName("LocalDefense", "", frame:GetID())
  if zoneChannel and frame.channelList then
    local name = channelName or "LocalDefense"
    local i = 1
    while frame.channelList[i] do
      if string.upper(frame.channelList[i]) == string.upper(name) then i = nil; break end
      i = i + 1
    end
    if i then
      frame.channelList[i] = name
      frame.zoneChannelList[i] = zoneChannel
    end
  end
  if manual or not sync.ldTold then
    sync.ldTold = true
    E.print(E.T("ldJoined"))
  end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local chatEvents = {
  "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM", "CHAT_MSG_MONSTER_YELL",
  "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_RAID_BOSS_EMOTE",
  "CHAT_MSG_BG_SYSTEM_NEUTRAL", "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE",
}

f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("UPDATE_WORLD_STATES")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")
for i = 1, table.getn(chatEvents) do pcall(f.RegisterEvent, f, chatEvents[i]) end
for ev in pairs(ANN_CHAT) do pcall(f.RegisterEvent, f, ev) end

local function init()
  if not EPLTowersDB then EPLTowersDB = {} end
  db = EPLTowersDB
  E.db = db
  if not db.towers then db.towers = {} end
  if not db.log then db.log = {} end
  if not db.opts then db.opts = {} end
  if db.showMap ~= nil then
    -- settings from version 1.x
    db.opts.showMap = db.showMap
    db.showMap = nil
  end
  for k, v in pairs(DEFAULTS) do
    if db.opts[k] == nil then db.opts[k] = v end
  end
  state = db.towers
  E.state = state
  for i = 1, NT do
    local k = TOWERS[i].key
    local s = state[k]
    if not s then
      s = {}
      state[k] = s
    end
    if s.heard and not s.valueAt then s.valueAt = s.heard end -- 1.x name
    s.heard = nil
    s.hist = nil
    -- GetTime() based fields don't survive a reload
    s.trans = {}
    s.runDir, s.dir, s.heardGT, s.sinceGT, s.watchGT = nil, nil, nil, nil, nil
    s.remoteRate, s.remoteRateGT, s.warned, s.prevValue = nil, nil, nil, nil
  end
  -- language: saved choice, else Russian on a Russian client, else English
  if not db.opts.lang then
    if GetLocale() == "ruRU" then db.opts.lang = "ru" else db.opts.lang = "en" end
  end
  E.SetLanguage(db.opts.lang)
  E.myFaction = UnitFactionGroup("player")
  E.BuildUI()
  E.print(E.T("loaded", E.VERSION))
end

local wasInZone, wasGrouped

local function zoneCheck()
  local inz = E.inZone()
  if inz ~= wasInZone then
    wasInZone = inz
    if inz then
      E.requestSync(false)
      sync.ldAt = GetTime() + 6 -- the game joins zone channels itself first
    end
    E.OnZoneChanged(inz)
  end
end

local function groupCheck()
  local grouped
  if GetNumRaidMembers() > 0 then grouped = "raid"
  elseif GetNumPartyMembers() > 0 then grouped = "party" end
  if grouped and grouped ~= wasGrouped then
    -- you just joined a group (or it became a raid): ask what they know
    sync.joinAt = GetTime() + 2
  end
  wasGrouped = grouped
end

f:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    init()
  elseif not db then
    return
  elseif event == "UPDATE_WORLD_STATES" then
    E.scanLocal()
  elseif event == "CHAT_MSG_ADDON" then
    if arg1 == PREFIX and arg4 ~= UnitName("player") then onAddon(arg2, arg4) end
  elseif event == "PLAYER_ENTERING_WORLD" then
    E.myFaction = UnitFactionGroup("player")
    E.FactionChanged()
    sync.loginAt = GetTime() + 5 -- channels need a moment after a loading screen
    groupCheck()
    zoneCheck()
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    zoneCheck()
  elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
    groupCheck()
  elseif ANN_CHAT[event] then
    onGroupChat(arg1, ANN_CHAT[event], arg2)
  else
    onChat(arg1, arg9 or arg4, event, arg2)
  end
end)

local acc, slow = 0, 0
f:SetScript("OnUpdate", function()
  if not db then return end
  acc = acc + arg1
  if acc < 0.25 then return end
  local now = GetTime()
  if sync.pending and now >= sync.pending.fire then
    local legacy = sync.pending.legacy
    sync.pending = nil
    sendSnapshot(legacy)
  end
  annFire(now)
  for key, op in pairs(sync.oPending) do
    if now >= op.due then
      sync.oPending[key] = nil
      E.send("O:" .. key .. ":" .. op.fac .. ":0")
    end
  end
  if sync.loginAt and now >= sync.loginAt then
    sync.loginAt = false
    E.requestSync(false)
  end
  if sync.joinAt and now >= sync.joinAt then
    sync.joinAt = nil
    E.requestSync(false)
  end
  slow = slow + acc
  acc = 0
  if slow < 0.5 then return end
  slow = 0
  E.scanLocal()
  for i = 1, NT do
    local k = TOWERS[i].key
    checkWarn(k, state[k], now)
  end
  -- in EPL: make sure you are in LocalDefense (checked again every minute)
  if wasInZone and db.opts.localDefense and sync.ldAt and now >= sync.ldAt then
    sync.ldAt = now + 60
    E.checkLocalDefense(false)
  end
  -- in EPL and nothing heard for 5 minutes: ask again by itself
  if wasInZone and now - sync.lastQueryGT > 300 and (not sync.lastNewsGT or now - sync.lastNewsGT > 300) then
    E.requestSync(false)
  end
  E.UpdateUI()
end)
