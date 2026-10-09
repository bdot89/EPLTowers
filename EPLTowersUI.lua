-- EPL Towers 2.2 - window, map, options, help, alerts, minimap button, slash commands
--
-- Everything here is drawn with the bundled Fira Sans Condensed: the game's own
-- Friz Quadrata has no Cyrillic letters, so Russian would show as blanks. That
-- is also why the addon has its own buttons (the game's button template swaps
-- to its own font on mouse-over) and its own tooltip frame.
local E = EPLTowers
local TOWERS = E.TOWERS
local NT = table.getn(TOWERS)
local COLORS = E.COLORS

local DIR = "Interface\\AddOns\\EPLTowers\\"
local FONT = DIR .. "fonts\\FiraSansCondensed-Regular.ttf"
local FONTB = DIR .. "fonts\\FiraSansCondensed-SemiBold.ttf"
local FLAGS = { en = DIR .. "media\\flag-en", ru = DIR .. "media\\flag-ru" }
local BAR_TEX = "Interface\\WorldStateFrame\\WorldState-CaptureBar"
local POI_TEX = "Interface\\Minimap\\POIIcons"
local PIP = DIR .. "media\\pip"   -- round map dot: white centre takes the colour, black rim
-- faction crests from the game's PvP icons, cropped to the art (measured from the textures)
local CREST = {
  Alliance = { "Interface\\TargetingFrame\\UI-PVP-Alliance", 0.008, 0.617, 0.031, 0.641 },
  Horde = { "Interface\\TargetingFrame\\UI-PVP-Horde", 0.016, 0.609, 0.016, 0.609 },
}
local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0.25

local MAP_W, MAP_H = 420, 280   -- the game's map is 1002 x 668
local W = MAP_W + 24
local ROW_H = 54
local TOP = 70                  -- title plaque, language / score row, sync line
local BOTTOM = 46               -- button bar
local BAR_SCALE = 0.8           -- capture bar size in the tower rows

local main, mapFrame, listFrame, playerDot, syncDot, syncText, mapButton
local markers, rows, pills, scores = {}, {}, {}, {}
local optionsFrame, helpFrame, menu, mmButton, banner, tip
local autoOpened
local labels = {}               -- font strings that follow the language switch

-------------------------------------------------------------------------------
-- Fonts, text, tooltip
-------------------------------------------------------------------------------

local function font(f, size, bold, flags)
  if bold then f:SetFont(FONTB, size, flags or "") else f:SetFont(FONT, size, flags or "") end
end

local function text(parent, size, bold, layer, flags)
  local f = parent:CreateFontString(nil, layer or "OVERLAY")
  font(f, size, bold, flags)
  f:SetShadowColor(0, 0, 0, 1)
  f:SetShadowOffset(1, -1)
  return f
end

-- a text that changes with the language
local function ltext(f, key)
  f.lkey = key
  table.insert(labels, f)
  f:SetText(E.T(key))
  return f
end

local function tipOpen(owner, anchor)
  tip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
end

-- our tooltip uses our font; lines are made as they are added, so set them all here
local function tipShow()
  for i = 1, tip:NumLines() do
    local l = getglobal("EPLTowersTipTextLeft" .. i)
    local r = getglobal("EPLTowersTipTextRight" .. i)
    if i == 1 then
      if l then font(l, 14, true) end
    else
      if l then font(l, 12) end
      if r then font(r, 12) end
    end
  end
  tip:Show()
end

local function tipHide()
  tip:Hide()
end

local function showTip()
  tipOpen(this, this.tipAnchor)
  tip:SetText(E.T(this.tipTitle, this.tipArg), GOLD_R, GOLD_G, GOLD_B)
  if this.tipText then tip:AddLine(E.T(this.tipText), 1, 1, 1, 1) end
  tipShow()
end

local function setTip(frame, titleKey, textKey)
  frame.tipTitle = titleKey
  frame.tipText = textKey
  frame:SetScript("OnEnter", showTip)
  frame:SetScript("OnLeave", tipHide)
end

-------------------------------------------------------------------------------
-- Frame chrome: gold dialog border, stone title plaque, buttons
-------------------------------------------------------------------------------

local function goldFrame(f)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  f:SetBackdropColor(1, 1, 1, 0.97)
end

local function thinBorder(f, edge)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = edge or 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
end

-- the stone plaque the game uses on its own dialogs (Game Menu, etc.)
local function plaque(f, key)
  local h = f:CreateTexture(nil, "ARTWORK")
  h:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  h:SetWidth(256)
  h:SetHeight(64)
  h:SetPoint("TOP", f, "TOP", 0, 12)
  local t = text(f, 15, true)
  t:SetPoint("TOP", h, "TOP", 0, -14)
  t:SetTextColor(1, 0.82, 0)
  ltext(t, key)
  return h
end

local function closeButton(f, onClick)
  local c = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  c:SetWidth(28)
  c:SetHeight(28)
  c:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
  c:SetScript("OnClick", onClick)
  return c
end

local function btnDown() this.label:SetPoint("CENTER", this, "CENTER", 1, -1) end
local function btnUp() this.label:SetPoint("CENTER", this, "CENTER", 0, 0) end
local function btnEnter()
  this.label:SetTextColor(1, 1, 1)
  if this.tipTitle then showTip() end
end
local function btnLeave()
  this.label:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
  tipHide()
end

-- shrink a button's text until it fits (Russian words are longer)
local function fitLabel(b)
  local size = 12.5
  font(b.label, size, true)
  while size > 9.5 and b.label:GetStringWidth() > b:GetWidth() - 8 do
    size = size - 0.5
    font(b.label, size, true)
  end
end

local function newButton(parent, w, h, key, onClick, tipKey)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(w)
  b:SetHeight(h)
  thinBorder(b, 12)
  b:SetBackdropColor(0.16, 0.12, 0.05, 1)
  b:SetBackdropBorderColor(0.85, 0.68, 0.3, 1)
  local shine = b:CreateTexture(nil, "BORDER")
  shine:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  shine:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  shine:SetTexture(1, 1, 1, 1)
  shine:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.35, 1, 0.9, 0.6, 0.14)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  hl:SetTexture(1, 0.85, 0.4, 0.16)
  b.label = text(b, 12.5, true)
  b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.label:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
  b.label.button = b
  if key then
    ltext(b.label, key)
    fitLabel(b)
  end
  b:SetScript("OnMouseDown", btnDown)
  b:SetScript("OnMouseUp", btnUp)
  b:SetScript("OnEnter", btnEnter)
  b:SetScript("OnLeave", btnLeave)
  b:SetScript("OnClick", onClick)
  b.tipTitle = key
  b.tipText = tipKey
  return b
end

-- game POI icons: 5 grey tower, 8 Alliance under attack, 9 Horde, 10 Alliance, 11 Horde under attack
local function setPoi(tex, index)
  local x = math.mod(index, 8) * 0.125
  local y = math.floor(index / 8) * 0.125
  tex:SetTexCoord(x, x + 0.125, y, y + 0.125)
end

local function iconIndex(owner, dir)
  if owner == "Alliance" then
    if dir == -1 then return 8 end
    return 10
  elseif owner == "Horde" then
    if dir == 1 then return 11 end
    return 9
  end
  return 5
end

local function setCrest(tex, fac)
  local c = CREST[fac]
  if c then
    tex:SetTexture(c[1])
    tex:SetTexCoord(c[2], c[3], c[4], c[5])
  else
    tex:SetTexture(POI_TEX)
    setPoi(tex, 5)
  end
end

-------------------------------------------------------------------------------
-- Capture bar: a copy of the game's own bar (WorldStateCaptureBarTemplate),
-- same texture, layout and position formula, so it matches what you see in game.
-------------------------------------------------------------------------------

local function barTex(b, layer, w, h, l, r, t, bt)
  local x = b:CreateTexture(nil, layer)
  x:SetTexture(BAR_TEX)
  x:SetWidth(w)
  x:SetHeight(h)
  x:SetTexCoord(l, r, t, bt)
  return x
end

local function newCaptureBar(parent, scale)
  local b = CreateFrame("Frame", nil, parent)
  b:SetWidth(173)
  b:SetHeight(26)
  b:SetScale(scale)
  local left = barTex(b, "BACKGROUND", 48, 9, 0.8203125, 1.0, 0, 0.140625)
  left:SetPoint("LEFT", b, "LEFT", 26, 0)
  local right = barTex(b, "BACKGROUND", 48, 9, 0.8203125, 1.0, 0.171875, 0.3125)
  right:SetPoint("RIGHT", b, "RIGHT", -26, 0)
  local mid = barTex(b, "BACKGROUND", 48, 9, 0.8203125, 1.0, 0.34375, 0.484375)
  mid:SetPoint("LEFT", left, "RIGHT", 0, 0)
  mid:SetPoint("RIGHT", right, "LEFT", 0, 0)
  local art = barTex(b, "ARTWORK", 173, 26, 0, 0.67578125, 0, 0.40625)
  art:SetPoint("TOP", b, "TOP", 0, 0)
  local d1 = barTex(b, "ARTWORK", 3, 8, 0.74609375, 0.7578125, 0, 0.125)
  d1:SetPoint("LEFT", left, "RIGHT", -1, 0)
  local d2 = barTex(b, "ARTWORK", 3, 8, 0.74609375, 0.7578125, 0, 0.125)
  d2:SetPoint("RIGHT", right, "LEFT", 1, 0)
  b.hlLeft = barTex(b, "OVERLAY", 27, 28, 0, 0.10546875, 0.4375, 0.875)
  b.hlLeft:SetBlendMode("ADD")
  b.hlLeft:SetPoint("LEFT", b, "LEFT", -1, 0)
  b.hlRight = barTex(b, "OVERLAY", 27, 28, 0, 0.10546875, 0.4375, 0.875)
  b.hlRight:SetBlendMode("ADD")
  b.hlRight:SetPoint("RIGHT", b, "RIGHT", 1, 0)

  local ind = CreateFrame("Frame", nil, b)
  ind:SetWidth(5)
  ind:SetHeight(18)
  local it = ind:CreateTexture(nil, "ARTWORK")
  it:SetTexture(BAR_TEX)
  it:SetAllPoints(ind)
  it:SetTexCoord(0.77734375, 0.796875, 0, 0.28125)
  ind.left = barTex(ind, "BACKGROUND", 8, 15, 0.7265625, 0.76171875, 0.140625, 0.375)
  ind.left:SetPoint("RIGHT", ind, "LEFT", 1, 0)
  ind.right = barTex(ind, "BACKGROUND", 8, 15, 0.76171875, 0.7265625, 0.140625, 0.375)
  ind.right:SetPoint("LEFT", ind, "RIGHT", -1, 0)
  b.ind = ind
  return b
end

-- dir: 1 moving toward Alliance (arrow points left), -1 toward Horde (right)
local function drawBar(b, v, n, dir, faded)
  if not v then
    b.ind:Hide()
    b.hlLeft:Hide()
    b.hlRight:Hide()
    b:SetAlpha(0.35)
    return
  end
  b.ind:ClearAllPoints()
  b.ind:SetPoint("CENTER", b, "LEFT", 25 + 124 * (1 - v / 100), 0) -- CaptureBar_Update
  b.ind:Show()
  if dir == 1 then b.ind.left:Show() else b.ind.left:Hide() end
  if dir == -1 then b.ind.right:Show() else b.ind.right:Hide() end
  local lo, hi = E.bounds(n)
  if v > hi then b.hlLeft:Show() else b.hlLeft:Hide() end
  if v < lo then b.hlRight:Show() else b.hlRight:Hide() end
  if faded then b:SetAlpha(0.45) else b:SetAlpha(1) end
end

-------------------------------------------------------------------------------
-- Tooltips for towers and sync
-------------------------------------------------------------------------------

local function towerTooltip(frame, key)
  local s = E.state[key]
  local d = E.describe(key)
  local e = d.e
  local nowT = time()
  tipOpen(frame, "ANCHOR_RIGHT")
  tip:SetText(E.TN(key), GOLD_R, GOLD_G, GOLD_B)
  local c = COLORS[s.owner or "Unknown"]
  tip:AddLine(E.T("tOwner", E.FN(s.owner)), c[1], c[2], c[3])
  if s.ownerAt then
    local from = ""
    if s.ownerSrc then from = E.T("tFrom", E.SrcName(s.ownerSrc)) end
    tip:AddLine(E.T("tOwnerInfo", E.ago(nowT - s.ownerAt)) .. from, 0.6, 0.6, 0.6)
  end
  if s.value then
    tip:AddLine(" ")
    if e.live then
      if s.src == "you" then
        tip:AddLine(E.T("tLiveYou"), 0.25, 1, 0.25)
      else
        tip:AddLine(E.T("tLiveOther", E.SrcName(s.src)), 0.25, 1, 0.25)
      end
    else
      local from = ""
      if s.src then from = E.T("tFrom", E.SrcName(s.src)) end
      tip:AddLine(E.T("tLastReading", E.ago(nowT - (s.valueAt or nowT))) .. from, 0.6, 0.6, 0.6)
    end
    tip:AddLine(E.T("tBar", s.value), 1, 1, 1)
    if e.live and e.rate and e.rate ~= 0 then
      for i = 1, table.getn(e.milestones) do
        local m = e.milestones[i]
        local mc = COLORS[m.fac]
        local label
        if m.full then label = E.T("full_" .. m.fac) else label = E.FN(m.fac) end
        tip:AddDoubleLine(label, (e.approx and "< " or "") .. E.fmt(m.eta), mc[1], mc[2], mc[3], 1, 1, 1)
      end
      if e.approx then
        tip:AddLine(E.T("tApprox"), 0.6, 0.6, 0.6, 1)
      elseif e.slowing then
        tip:AddLine(E.T("tSlow"), 0.6, 0.6, 0.6, 1)
      else
        tip:AddLine(E.T("tSpeed", e.per, e.speed), 0.6, 0.6, 0.6)
      end
    elseif e.live then
      tip:AddLine(d.line1, 1, 1, 1)
      tip:AddLine(d.line2, 0.6, 0.6, 0.6, 1)
    end
  end
  tip:AddLine(" ")
  tip:AddLine(E.T("tClick"), 0.5, 0.8, 1)
  tipShow()
end

local function towerEnter()
  towerTooltip(this, this.key)
end

local function syncTooltip()
  tipOpen(this, "ANCHOR_BOTTOM")
  tip:SetText(E.T("syncTitle"), GOLD_R, GOLD_G, GOLD_B)
  tip:AddLine(E.T("syncBody"), 1, 1, 1, 1)
  local nowT, now = time(), GetTime()
  local any
  for name, p in pairs(E.peers) do
    if nowT - p.seen < 3600 then
      if not any then
        tip:AddLine(" ")
        tip:AddLine(E.T("peersTitle"), GOLD_R, GOLD_G, GOLD_B)
        any = true
      end
      local where = E.ago(nowT - p.seen)
      if p.at and p.atGT and now - p.atGT <= E.LIVE_FOR then
        where = "|cff40ff40" .. E.T("atTower", E.TS(p.at)) .. "|r"
      end
      local who = name
      if not p.v2 then who = who .. "|cff888888" .. E.T("oldVersion") .. "|r" end
      tip:AddDoubleLine(who, where, 1, 1, 1, 0.8, 0.8, 0.8)
    end
  end
  if not any then
    tip:AddLine(" ")
    tip:AddLine(E.T("noPeers"), 0.6, 0.6, 0.6, 1)
  end
  tipShow()
end

-------------------------------------------------------------------------------
-- Alert banner (instead of the raid warning frame, whose font has no Cyrillic)
-------------------------------------------------------------------------------

local function bannerUpdate()
  local b = banner
  if b.anchoring then return end -- stays up while you place it
  b.t = b.t + arg1
  if b.t < 0.25 then
    b:SetAlpha(b.t / 0.25)
  elseif b.t < 5 then
    b:SetAlpha(1)
  elseif b.t < 6 then
    b:SetAlpha(6 - b.t)
  else
    b:Hide()
  end
end

-- saved as the top centre, so a longer or shorter message stays centred on that spot
local function applyBannerPos()
  banner:ClearAllPoints()
  local p = E.db.bannerPos
  if p then
    banner:SetPoint("TOP", UIParent, "BOTTOMLEFT", p.x, p.y)
  else
    banner:SetPoint("TOP", UIParent, "TOP", 0, -140)
  end
end

local function bannerDragStop()
  banner:StopMovingOrSizing()
  local l, t = banner:GetLeft(), banner:GetTop()
  if l and t then E.db.bannerPos = { x = l + banner:GetWidth() / 2, y = t } end
  applyBannerPos()
end

local function buildBanner()
  banner = CreateFrame("Frame", "EPLTowersBanner", UIParent)
  banner:SetFrameStrata("HIGH")
  banner:SetHeight(58)
  banner:SetWidth(420)
  -- click-through except while you are placing it (anchor mode)
  banner:SetMovable(true)
  banner:SetClampedToScreen(true)
  banner:EnableMouse(false)
  banner:RegisterForDrag("LeftButton")
  banner:SetScript("OnDragStart", function() this:StartMoving() end)
  banner:SetScript("OnDragStop", bannerDragStop)
  applyBannerPos()
  goldFrame(banner)
  banner.done = newButton(banner, 110, 22, "oMoveDone", function() E.ToggleAnchor() end, "oMoveD")
  banner.done:SetPoint("TOP", banner, "BOTTOM", 0, -4)
  banner.done:Hide()
  banner.crest = banner:CreateTexture(nil, "ARTWORK")
  banner.crest:SetWidth(36)
  banner.crest:SetHeight(36)
  banner.crest:SetPoint("LEFT", banner, "LEFT", 14, 0)
  banner.text = text(banner, 17, true)
  banner.text:SetPoint("LEFT", banner.crest, "RIGHT", 10, 0)
  banner.text:SetJustifyH("LEFT")
  banner:SetScript("OnUpdate", bannerUpdate)
  banner:Hide()
end

function E.ShowBanner(msg, r, g, b, fac)
  if not banner then buildBanner() end
  setCrest(banner.crest, fac)
  banner.text:SetText(msg)
  banner.text:SetTextColor(r, g, b)
  banner:SetWidth(math.max(300, banner.text:GetStringWidth() + 84))
  banner.t = 0
  if not banner.anchoring then banner:SetAlpha(0) end
  banner:Show()
end

local function updateMoveButton()
  if not optionsFrame then return end
  local b = optionsFrame.moveBtn
  if banner and banner.anchoring then b.label.lkey = "oMoveDone" else b.label.lkey = "oMove" end
  b.label:SetText(E.T(b.label.lkey))
  fitLabel(b)
end

-- anchor mode: show the alert banner so it can be dragged anywhere
function E.ToggleAnchor()
  if not banner then buildBanner() end
  if banner.anchoring then
    banner.anchoring = nil
    banner:EnableMouse(false)
    banner:SetBackdropBorderColor(1, 1, 1, 1)
    banner.done:Hide()
    banner:Hide()
    E.print(E.T("anchorSaved"))
  else
    banner.anchoring = true
    setCrest(banner.crest, E.myFaction)
    banner.text:SetText(E.T("anchorSample"))
    banner.text:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
    banner:SetWidth(math.max(300, banner.text:GetStringWidth() + 84))
    banner:SetAlpha(1)
    banner:EnableMouse(true)
    banner:SetBackdropBorderColor(0.3, 1, 0.3, 1)
    banner.done:Show()
    banner:Show()
    E.print(E.T("anchorStart"))
  end
  updateMoveButton()
end

-------------------------------------------------------------------------------
-- Popup menu for one tower
-------------------------------------------------------------------------------

local MENU = {
  { key = "mAnnounce", desc = "mAnnounceD", fn = function(k) E.announce(k) end },
  { key = "mSet", fac = "Alliance", desc = "mSetD", fn = function(k) E.manualOwner(k, "Alliance") end },
  { key = "mSet", fac = "Horde", desc = "mSetD", fn = function(k) E.manualOwner(k, "Horde") end },
  { key = "mSet", fac = "Neutral", desc = "mSetD", fn = function(k) E.manualOwner(k, "Neutral") end },
  { key = "mForget", desc = "mForgetD", fn = function(k) E.forget(k); E.print(E.T("forgotten", E.TN(k))) end },
  { key = "mClose", desc = "mCloseD" },
}

local function menuClick()
  local item = MENU[this.index]
  local key = menu.key
  menu:Hide()
  if item.fn then item.fn(key) end
  E.UpdateUI()
end

local function menuTexts()
  for i = 1, table.getn(MENU) do
    local item = MENU[i]
    local b = menu.items[i]
    if item.fac then
      b.label:SetText(E.T("mSet", COLORS[item.fac][4] .. E.FN(item.fac) .. "|r"))
      b.tipArg = E.FN(item.fac)
    else
      b.label:SetText(E.T(item.key))
    end
  end
end

local function buildMenu()
  menu = CreateFrame("Frame", "EPLTowersMenu", UIParent)
  thinBorder(menu, 14)
  menu:SetBackdropColor(0.06, 0.05, 0.04, 0.97)
  menu:SetBackdropBorderColor(0.85, 0.68, 0.3, 1)
  menu:SetFrameStrata("FULLSCREEN_DIALOG") -- above the options and help panels
  menu:SetWidth(210)
  menu:SetHeight(36 + table.getn(MENU) * 19)
  menu:EnableMouse(true)
  menu.title = text(menu, 13, true)
  menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -10)
  menu.title:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
  menu.items = {}
  for i = 1, table.getn(MENU) do
    local b = CreateFrame("Button", nil, menu)
    b:SetWidth(194)
    b:SetHeight(19)
    b:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -28 - (i - 1) * 19)
    b.index = i
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetTexture(1, 0.85, 0.4, 0.14)
    b.label = text(b, 12.5)
    b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
    b:SetScript("OnClick", menuClick)
    setTip(b, MENU[i].key, MENU[i].desc)
    menu.items[i] = b
  end
  menu:SetScript("OnUpdate", function()
    if MouseIsOver(menu) then
      menu.away = 0
    else
      menu.away = (menu.away or 0) + arg1
      if menu.away > 1.5 then menu:Hide() end
    end
  end)
  menu:Hide()
end

function E.OpenMenu(key)
  if not menu then buildMenu() end
  menu.key = key
  menu.away = 0
  menu.title:SetText(E.TN(key))
  menuTexts()
  local x, y = GetCursorPosition()
  local sc = UIParent:GetEffectiveScale()
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / sc - 10, y / sc + 10)
  menu:Show()
end

local function towerClick()
  E.OpenMenu(this.key)
end

-------------------------------------------------------------------------------
-- Announce (in the chosen language; chat fonts have Cyrillic)
-------------------------------------------------------------------------------

-- cut to maxBytes without splitting a UTF-8 letter
local function utf8cut(s, maxBytes)
  if string.len(s) <= maxBytes then return s end
  local cut = maxBytes
  while cut > 0 do
    local b = string.byte(s, cut + 1)
    if not b or b < 128 or b >= 192 then break end
    cut = cut - 1
  end
  return string.sub(s, 1, cut) .. "..."
end

function E.announce(key, guild)
  local msg
  if key then
    msg = E.T("annPrefix") .. E.describe(key).plain
  else
    local parts = {}
    for i = 1, NT do
      local d = E.describe(TOWERS[i].key)
      table.insert(parts, d.plainShort or d.plain)
    end
    msg = E.T("annPrefix") .. table.concat(parts, " / ")
  end
  -- no colour codes or stray pipes in chat: the client rejects bad escapes
  msg = string.gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
  msg = string.gsub(msg, "|r", "")
  msg = string.gsub(msg, "|", "/")
  msg = utf8cut(msg, 250)
  local chan
  if guild then
    if IsInGuild() then chan = "GUILD" end
  elseif GetNumRaidMembers() > 0 then
    chan = "RAID"
  elseif GetNumPartyMembers() > 0 then
    chan = "PARTY"
  end
  if chan then
    -- shared 30 s cooldown across everyone with the addon (see E.tryAnnounce)
    E.tryAnnounce(chan, key or "ALL", msg)
  else
    if guild then E.print(E.T("onlyYouGuild")) else E.print(E.T("onlyYouGroup")) end
    E.print(msg)
  end
end

-------------------------------------------------------------------------------
-- Main window
-------------------------------------------------------------------------------

local function savePos()
  local x, y = main:GetLeft(), main:GetTop()
  if x and y then E.db.pos = { x = x, y = y } end
end

local function applyPos()
  main:ClearAllPoints()
  local p = E.db.pos
  if p then
    main:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
  else
    main:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  end
end

function E.setScale(v)
  local old = main:GetScale()
  local x, y = main:GetLeft(), main:GetTop()
  main:SetScale(v)
  E.db.opts.scale = v
  if x and y then
    -- keep the top left corner where it is on screen
    E.db.pos = { x = x * old / v, y = y * old / v }
    applyPos()
  end
end

function E.Layout()
  listFrame:ClearAllPoints()
  if E.db.opts.showMap then
    mapFrame:Show()
    listFrame:SetPoint("TOPLEFT", main, "TOPLEFT", 12, -(TOP + MAP_H + 8))
    main:SetHeight(TOP + MAP_H + 8 + NT * ROW_H + BOTTOM)
    mapButton.label.lkey = "bMapHide"
  else
    mapFrame:Hide()
    listFrame:SetPoint("TOPLEFT", main, "TOPLEFT", 12, -TOP)
    main:SetHeight(TOP + NT * ROW_H + BOTTOM)
    mapButton.label.lkey = "bMapShow"
  end
  mapButton.label:SetText(E.T(mapButton.label.lkey))
  fitLabel(mapButton)
  mapButton.tipTitle = mapButton.label.lkey
end

local function toggleMap()
  E.db.opts.showMap = not E.db.opts.showMap
  E.Layout()
  E.RefreshOptions()
  E.UpdateUI()
end

local function startMove()
  if E.db.opts.lock then return end
  main:StartMoving()
end

local function stopMove()
  main:StopMovingOrSizing()
  savePos()
end

local function pillClick()
  E.ApplyLanguage(this.lang)
end

local function updatePills()
  for _, p in pairs(pills) do
    if p.lang == E.lang then
      p:SetBackdropColor(0.28, 0.21, 0.07, 1)
      p:SetBackdropBorderColor(1, 0.82, 0.3, 1)
      p.label:SetTextColor(1, 1, 1)
      p.flag:SetAlpha(1)
    else
      p:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
      p:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
      p.label:SetTextColor(0.6, 0.6, 0.6)
      p.flag:SetAlpha(0.45)
    end
  end
end

local function newPill(lang)
  local b = CreateFrame("Button", nil, main)
  b:SetWidth(86)
  b:SetHeight(20)
  thinBorder(b, 10)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
  hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  hl:SetTexture(1, 0.85, 0.4, 0.16)
  local edge = b:CreateTexture(nil, "ARTWORK")
  edge:SetWidth(24)
  edge:SetHeight(14)
  edge:SetPoint("LEFT", b, "LEFT", 5, 0)
  edge:SetTexture(0, 0, 0, 1)
  b.flag = b:CreateTexture(nil, "OVERLAY")
  b.flag:SetWidth(22)
  b.flag:SetHeight(12)
  b.flag:SetPoint("CENTER", edge, "CENTER", 0, 0)
  b.flag:SetTexture(FLAGS[lang])
  b.label = text(b, 12, true)
  b.label:SetPoint("LEFT", edge, "RIGHT", 6, 0)
  b.label:SetText(E.LANG_NAMES[lang]) -- each language in its own spelling
  b.lang = lang
  b:SetScript("OnClick", pillClick)
  setTip(b, "langTip", "langBody")
  return b
end

local function newScore(fac, x)
  local g = CreateFrame("Frame", nil, main)
  g:SetWidth(44)
  g:SetHeight(20)
  g:SetPoint("TOPRIGHT", main, "TOPRIGHT", x, -30)
  g.icon = g:CreateTexture(nil, "ARTWORK")
  g.icon:SetWidth(20)
  g.icon:SetHeight(20)
  g.icon:SetPoint("LEFT", g, "LEFT", 0, 0)
  setCrest(g.icon, fac)
  g.num = text(g, 15, true)
  g.num:SetPoint("LEFT", g.icon, "RIGHT", 4, 0)
  local c = COLORS[fac or "Neutral"]
  g.num:SetTextColor(c[1], c[2], c[3])
  scores[fac or "Neutral"] = g
end

local function buildMain()
  main = CreateFrame("Frame", "EPLTowersFrame", UIParent)
  main:SetWidth(W)
  main:SetFrameStrata("MEDIUM")
  goldFrame(main)
  main:SetMovable(true)
  main:EnableMouse(true)
  main:SetClampedToScreen(true)
  main:RegisterForDrag("LeftButton")
  main:SetScript("OnDragStart", startMove)
  main:SetScript("OnDragStop", stopMove)
  main:SetScript("OnShow", function() E.UpdateUI() end)
  main:SetScript("OnHide", function()
    autoOpened = nil
    if optionsFrame then optionsFrame:Hide() end
    if helpFrame then helpFrame:Hide() end
    if menu then menu:Hide() end
  end)

  plaque(main, "title")
  -- the plaque sticks out above the frame: give it its own drag handle
  local grab = CreateFrame("Frame", nil, main)
  grab:SetWidth(150)
  grab:SetHeight(30)
  grab:SetPoint("TOP", main, "TOP", 0, 8)
  grab:EnableMouse(true)
  grab:RegisterForDrag("LeftButton")
  grab:SetScript("OnDragStart", startMove)
  grab:SetScript("OnDragStop", stopMove)
  setTip(grab, "title", "dragTip")

  local close = closeButton(main, function() main:Hide(); E.db.shown = false end)
  setTip(close, "tClose", "dClose")

  for i = 1, table.getn(E.LANGS) do
    local p = newPill(E.LANGS[i])
    p:SetPoint("TOPLEFT", main, "TOPLEFT", 14 + (i - 1) * 90, -30)
    table.insert(pills, p)
  end

  newScore(nil, -14)
  newScore("Horde", -62)
  newScore("Alliance", -110)

  -- sync line
  local sb = CreateFrame("Button", nil, main)
  sb:SetPoint("TOPLEFT", main, "TOPLEFT", 12, -53)
  sb:SetWidth(MAP_W)
  sb:SetHeight(14)
  sb:SetScript("OnEnter", syncTooltip)
  sb:SetScript("OnLeave", tipHide)
  syncDot = sb:CreateTexture(nil, "ARTWORK")
  syncDot:SetWidth(8)
  syncDot:SetHeight(8)
  syncDot:SetPoint("LEFT", sb, "LEFT", 3, 0)
  syncText = text(sb, 12)
  syncText:SetPoint("LEFT", syncDot, "RIGHT", 6, 0)
  syncText:SetJustifyH("LEFT")
end

-------------------------------------------------------------------------------
-- You and your group on the map. Same data as the game's world map:
-- GetPlayerMapPosition on raid1..40 (or party1..4), 0,0 = not on this map.
-------------------------------------------------------------------------------

-- standard class colours (RAID_CLASS_COLORS is not always loaded on this client)
local CLASS_COLORS = {
  WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 },
  ROGUE = { 1.00, 0.96, 0.41 }, PRIEST = { 1.00, 1.00, 1.00 }, SHAMAN = { 0.00, 0.44, 0.87 },
  MAGE = { 0.41, 0.80, 0.94 }, WARLOCK = { 0.58, 0.51, 0.79 }, DRUID = { 1.00, 0.49, 0.04 },
}
local groupDots = {}

local function classColor(unit)
  local _, class = UnitClass(unit)
  local c = class and CLASS_COLORS[class]
  if c then return c[1], c[2], c[3] end
  return 0.6, 0.8, 1
end

-- lists everyone under the mouse, like the game's map does
local function unitsEnter()
  tipOpen(this, "ANCHOR_RIGHT")
  tip:SetText(E.T("groupTitle"), GOLD_R, GOLD_G, GOLD_B)
  if playerDot:IsVisible() and MouseIsOver(playerDot) then
    tip:AddDoubleLine(UnitName("player") or "?", E.T("you"), 1, 0.85, 0.1, 0.8, 0.8, 0.8)
  end
  for i = 1, table.getn(groupDots) do
    local d = groupDots[i]
    if d:IsVisible() and MouseIsOver(d) then
      local u = d.unit
      local status = ""
      if UnitIsDeadOrGhost(u) then
        status = "|cffff5050" .. E.T("dead") .. "|r"
      else
        local hp, mx = UnitHealth(u), UnitHealthMax(u)
        if mx and mx > 0 then status = math.floor(hp / mx * 100 + 0.5) .. "%" end
      end
      if d.sub then status = status .. "   " .. E.T("grp", d.sub) end
      local r, g, b = classColor(u)
      tip:AddDoubleLine(UnitName(u) or "?", status, r, g, b, 0.8, 0.8, 0.8)
    end
  end
  tipShow()
end

local function newDot(level, size)
  local d = CreateFrame("Button", nil, mapFrame)
  d:SetWidth(size)
  d:SetHeight(size)
  d:SetFrameLevel(mapFrame:GetFrameLevel() + level)
  d.tex = d:CreateTexture(nil, "ARTWORK")
  d.tex:SetAllPoints(d)
  d.tex:SetTexture(PIP)
  d:SetScript("OnEnter", unitsEnter)
  d:SetScript("OnLeave", tipHide)
  d:Hide()
  return d
end

local function placeUnit(unit, n, sub)
  if not UnitExists(unit) or UnitIsUnit(unit, "player") then return n end
  local x, y = GetPlayerMapPosition(unit)
  if not x or (x == 0 and y == 0) then return n end
  n = n + 1
  local d = groupDots[n]
  if not d then
    d = newDot(6, 11)
    groupDots[n] = d
  end
  d.unit = unit
  d.sub = sub
  d:ClearAllPoints()
  d:SetPoint("CENTER", mapFrame, "TOPLEFT", x * MAP_W, -y * MAP_H)
  d.tex:SetVertexColor(classColor(unit))
  if UnitIsDeadOrGhost(unit) then d:SetAlpha(0.45) else d:SetAlpha(1) end
  d:Show()
  return n
end

local function updateMapUnits()
  local n = 0
  if E.inZone() and E.mapIsEPL() then
    local x, y = GetPlayerMapPosition("player")
    if x and (x > 0 or y > 0) then
      playerDot:ClearAllPoints()
      playerDot:SetPoint("CENTER", mapFrame, "TOPLEFT", x * MAP_W, -y * MAP_H)
      playerDot:Show()
    else
      playerDot:Hide()
    end
    if E.db.opts.showGroup then
      local raid = GetNumRaidMembers()
      if raid > 0 then
        for i = 1, raid do
          local _, _, sub = GetRaidRosterInfo(i)
          n = placeUnit("raid" .. i, n, sub)
        end
      else
        for i = 1, GetNumPartyMembers() do n = placeUnit("party" .. i, n) end
      end
    end
  else
    playerDot:Hide()
  end
  for i = n + 1, table.getn(groupDots) do groupDots[i]:Hide() end
end

-- the dots move smoothly: updated about 7 times a second while the map is on screen
local function mapTick()
  this.acc = (this.acc or 0) + arg1
  if this.acc < 0.15 then return end
  this.acc = 0
  updateMapUnits()
end

local function buildMap()
  mapFrame = CreateFrame("Frame", nil, main)
  mapFrame:SetWidth(MAP_W)
  mapFrame:SetHeight(MAP_H)
  mapFrame:SetPoint("TOPLEFT", main, "TOPLEFT", 12, -TOP)
  -- the game's own EPL map: 4 x 3 tiles of 256 px, visible area 1002 x 668
  local sc = MAP_W / 1002
  for i = 1, 12 do
    local row = math.floor((i - 1) / 4)
    local col = math.mod(i - 1, 4)
    local w, h, r, b = 256, 256, 1, 1
    if col == 3 then w = 234; r = 234 / 256 end
    if row == 2 then h = 156; b = 156 / 256 end
    local tex = mapFrame:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture("Interface\\WorldMap\\EasternPlaguelands\\EasternPlaguelands" .. i)
    tex:SetTexCoord(0, r, 0, b)
    tex:SetWidth(w * sc)
    tex:SetHeight(h * sc)
    tex:SetPoint("TOPLEFT", mapFrame, "TOPLEFT", col * 256 * sc, -row * 256 * sc)
  end
  local shade = mapFrame:CreateTexture(nil, "BORDER")
  shade:SetAllPoints(mapFrame)
  shade:SetTexture(0, 0, 0, 0.2)
  -- gold frame around the map (its own frame so it never hides the markers)
  local edge = CreateFrame("Frame", nil, mapFrame)
  edge:SetPoint("TOPLEFT", mapFrame, "TOPLEFT", -4, 4)
  edge:SetPoint("BOTTOMRIGHT", mapFrame, "BOTTOMRIGHT", 4, -4)
  edge:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  edge:SetBackdropBorderColor(0.85, 0.68, 0.3, 1)
  edge:SetFrameLevel(mapFrame:GetFrameLevel() + 1)

  for i = 1, NT do
    local t = TOWERS[i]
    local m = CreateFrame("Button", nil, mapFrame)
    m:SetFrameLevel(mapFrame:GetFrameLevel() + 3)
    m:SetWidth(22)
    m:SetHeight(22)
    m:SetPoint("CENTER", mapFrame, "TOPLEFT", t.x * MAP_W, -t.y * MAP_H)
    m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    m.key = t.key
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetAllPoints(m)
    m.icon:SetTexture(POI_TEX)
    m:SetScript("OnEnter", towerEnter)
    m:SetScript("OnLeave", tipHide)
    m:SetScript("OnClick", towerClick)
    m.name = text(m, 12, true, "OVERLAY", "OUTLINE")
    m.name:SetPoint("BOTTOM", m, "TOP", 0, 1)
    m.name:SetTextColor(1, 0.86, 0.4)
    m.bar = newCaptureBar(m, 0.55)
    m.bar:SetPoint("TOP", m, "BOTTOM", 0, -1 / 0.55) -- offsets use the bar's own scale
    m.info = text(m, 12, true, "OVERLAY", "OUTLINE")
    m.info:SetPoint("TOP", m, "BOTTOM", 0, -(2 + 26 * 0.55))
    markers[t.key] = m
  end

  -- you: a bigger gold dot drawn above your group
  playerDot = newDot(8, 13)
  playerDot.tex:SetVertexColor(1, 0.85, 0.1)
  mapFrame:SetScript("OnUpdate", mapTick)
end

local function buildRows()
  listFrame = CreateFrame("Frame", nil, main)
  listFrame:SetWidth(MAP_W)
  listFrame:SetHeight(NT * ROW_H)
  local textX = 26 + 173 * BAR_SCALE + 8
  for i = 1, NT do
    local t = TOWERS[i]
    local r = CreateFrame("Button", nil, listFrame)
    r:SetWidth(MAP_W)
    r:SetHeight(ROW_H - 3)
    r:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -(i - 1) * ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.key = t.key
    r:SetScript("OnEnter", towerEnter)
    r:SetScript("OnLeave", tipHide)
    r:SetScript("OnClick", towerClick)
    -- card: dark base, the owner's colour fading in from the left, a thin edge
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(r)
    bg:SetTexture(0.05, 0.05, 0.07, 0.9)
    r.tint = r:CreateTexture(nil, "BORDER")
    r.tint:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.tint:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    r.tint:SetWidth(MAP_W * 0.7)
    r.tint:SetTexture(1, 1, 1, 1)
    r.accent = r:CreateTexture(nil, "ARTWORK")
    r.accent:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.accent:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    r.accent:SetWidth(3)
    local line = r:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
    line:SetHeight(1)
    line:SetTexture(0.85, 0.68, 0.3, 0.25)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(r)
    hl:SetTexture(1, 0.85, 0.4, 0.07)

    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetTexture(POI_TEX)
    r.icon:SetWidth(22)
    r.icon:SetHeight(22)
    r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 6, -2)
    r.name = text(r, 14, true)
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 32, -5)
    r.name:SetTextColor(1, 0.86, 0.45)
    r.owner = text(r, 13.5, true)
    r.owner:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
    r.right = text(r, 12)
    r.right:SetPoint("TOPRIGHT", r, "TOPRIGHT", -6, -6)
    r.right:SetWidth(125) -- long player names get cut off before they reach the owner text
    r.right:SetHeight(14)
    r.right:SetJustifyH("RIGHT")
    r.bar = newCaptureBar(r, BAR_SCALE)
    r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 26 / BAR_SCALE, -24 / BAR_SCALE)
    r.line1 = text(r, 13)
    r.line1:SetPoint("TOPLEFT", r, "TOPLEFT", textX, -24)
    r.line1:SetWidth(MAP_W - textX - 4)
    r.line1:SetHeight(15)
    r.line1:SetJustifyH("LEFT")
    r.line2 = text(r, 11.5)
    r.line2:SetPoint("TOPLEFT", r, "TOPLEFT", textX, -38)
    r.line2:SetWidth(MAP_W - textX - 4)
    r.line2:SetHeight(13)
    r.line2:SetJustifyH("LEFT")
    r.line2:SetTextColor(0.78, 0.78, 0.78)
    rows[t.key] = r
  end
end

local function buildButtons()
  local bw = math.floor((MAP_W - 4 * 6) / 5)
  local defs = {
    { "bMapHide", "dMap", toggleMap },
    { "bSync", "dSync", function() E.requestSync(true) end },
    { "bAnnounce", "dAnnounce", function() E.announce(nil, IsShiftKeyDown()) end },
    { "bOptions", "dOptions", function() E.ToggleOptions() end },
    { "bHelp", "dHelp", function() E.ToggleHelp() end },
  }
  for i = 1, table.getn(defs) do
    local d = defs[i]
    local b = newButton(main, bw, 24, d[1], d[3], d[2])
    b:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 12 + (i - 1) * (bw + 6), 13)
    if i == 1 then mapButton = b end
  end
end

-------------------------------------------------------------------------------
-- Side panels (options, help) open next to the window
-------------------------------------------------------------------------------

local function placeBeside(panel)
  panel:ClearAllPoints()
  local right = (main:GetRight() or 0) * main:GetScale()
  if right + panel:GetWidth() + 4 > UIParent:GetRight() then
    panel:SetPoint("TOPRIGHT", main, "TOPLEFT", -2, 0)
  else
    panel:SetPoint("TOPLEFT", main, "TOPRIGHT", 2, 0)
  end
end

-- make a panel tall enough for its wrapped text (runs once the text is laid out)
local function fitUpdate()
  local p = this
  p.fitFrames = (p.fitFrames or 0) - 1
  local top, bottom = p:GetTop(), p.last:GetBottom()
  if top and bottom and top - bottom > 40 then p:SetHeight(top - bottom + p.pad) end
  if p.fitFrames <= 0 then p:SetScript("OnUpdate", nil) end
end

local function refit(p)
  p.fitFrames = 3
  p:SetScript("OnUpdate", fitUpdate)
end

local OPTS = { "lock", "minimap", "autoShow", "showMap", "showGroup", "alerts", "warn", "sound", "guild", "localDefense" }

local function optionClicked()
  local key = OPTS[this.index]
  E.db.opts[key] = this:GetChecked() and true or false
  if this:GetChecked() then PlaySound("igMainMenuOptionCheckBoxOn") else PlaySound("igMainMenuOptionCheckBoxOff") end
  if key == "showMap" then E.Layout(); E.UpdateUI() end
  if key == "minimap" then E.UpdateMinimapButton() end
  if key == "localDefense" and E.db.opts.localDefense and E.inZone() then E.checkLocalDefense(true) end
end

function E.RefreshOptions()
  if not optionsFrame then return end
  for i = 1, table.getn(OPTS) do
    optionsFrame.checks[i]:SetChecked(E.db.opts[OPTS[i]] and 1 or nil)
  end
  optionsFrame.slider:SetValue(E.db.opts.scale or 1)
  updateMoveButton()
  getglobal("EPLTowersScaleText"):SetText(E.T("oSize", math.floor((E.db.opts.scale or 1) * 100 + 0.5)))
end

local function clearClick()
  local b = this
  if b.armed and GetTime() - b.armed < 4 then
    b.armed = nil
    b.label:SetText(E.T("oClear"))
    fitLabel(b)
    E.resetTowers()
    E.UpdateUI()
  else
    b.armed = GetTime()
    b.label:SetText("|cffff5050" .. E.T("oClearConfirm") .. "|r")
    fitLabel(b)
  end
end

local function clearUpdate()
  if this.armed and GetTime() - this.armed >= 4 then
    this.armed = nil
    this.label:SetText(E.T("oClear"))
    fitLabel(this)
  end
end

local function buildOptions()
  local p = CreateFrame("Frame", "EPLTowersOptions", UIParent)
  optionsFrame = p
  goldFrame(p)
  p:SetFrameStrata("DIALOG") -- above HUD frames from other addons
  p:SetWidth(340)
  p:SetHeight(560)
  p:EnableMouse(true)
  plaque(p, "oTitle")
  closeButton(p, function() p:Hide() end)

  p.checks = {}
  local prev
  for i = 1, table.getn(OPTS) do
    local key = OPTS[i]
    local cb = CreateFrame("CheckButton", "EPLTowersOpt" .. i, p, "UICheckButtonTemplate")
    cb:SetWidth(24)
    cb:SetHeight(24)
    if prev then
      cb:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", -26, -5)
    else
      cb:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -30)
    end
    cb.index = i
    cb:SetScript("OnClick", optionClicked)
    local label = getglobal("EPLTowersOpt" .. i .. "Text")
    font(label, 13.5, true)
    label:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
    ltext(label, "o_" .. key)
    local desc = text(p, 12, false, "ARTWORK")
    desc:SetPoint("TOPLEFT", cb, "TOPLEFT", 26, -21)
    desc:SetWidth(290)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.78, 0.78, 0.78)
    ltext(desc, "o_" .. key .. "_d")
    p.checks[i] = cb
    prev = desc
  end

  local sl = CreateFrame("Slider", "EPLTowersScale", p, "OptionsSliderTemplate")
  sl:SetWidth(250)
  sl:SetHeight(16)
  sl:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 4, -26)
  sl:SetMinMaxValues(0.6, 1.5)
  sl:SetValueStep(0.05)
  local st = getglobal("EPLTowersScaleText")
  font(st, 12.5, true)
  st:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
  font(getglobal("EPLTowersScaleLow"), 11)
  font(getglobal("EPLTowersScaleHigh"), 11)
  getglobal("EPLTowersScaleLow"):SetText("60%")
  getglobal("EPLTowersScaleHigh"):SetText("150%")
  sl:SetScript("OnValueChanged", function()
    local v = math.floor(this:GetValue() * 20 + 0.5) / 20
    getglobal("EPLTowersScaleText"):SetText(E.T("oSize", math.floor(v * 100 + 0.5)))
    if math.abs(v - (E.db.opts.scale or 1)) > 0.001 then E.setScale(v) end
  end)
  setTip(sl, "oSize", "oSizeD")
  sl.tipArg = 100
  p.slider = sl

  -- three buttons centred under the slider (the slider sits in the middle of the panel)
  local reset = newButton(p, 150, 24, "oResetPos", function()
    E.db.pos = nil
    E.db.mm = nil
    E.db.bannerPos = nil
    applyPos()
    E.PlaceMinimapButton()
    if banner then applyBannerPos() end
  end, "oResetPosD")
  reset:SetPoint("TOPRIGHT", sl, "BOTTOM", -4, -26)
  local clear = newButton(p, 150, 24, "oClear", clearClick, "oClearD")
  clear:SetPoint("TOPLEFT", sl, "BOTTOM", 4, -26)
  clear:SetScript("OnUpdate", clearUpdate)
  local move = newButton(p, 308, 24, "oMove", function() E.ToggleAnchor() end, "oMoveD")
  move:SetPoint("TOP", sl, "BOTTOM", 0, -56)
  p.moveBtn = move
  p.last = move
  p.pad = 16
  p:Hide()
end

function E.ToggleOptions(forceShow)
  if not main:IsVisible() then main:Show() end
  if not optionsFrame then buildOptions() end
  if optionsFrame:IsVisible() and not forceShow then
    optionsFrame:Hide()
    return
  end
  if helpFrame then helpFrame:Hide() end
  E.RefreshOptions()
  placeBeside(optionsFrame)
  optionsFrame:Show()
  refit(optionsFrame)
end

local function helpTexts()
  local h = E.L.help
  for i = 1, table.getn(helpFrame.heads) do
    helpFrame.heads[i]:SetText(h[i] and h[i][1] or "")
    helpFrame.bodies[i]:SetText(h[i] and h[i][2] or "")
  end
end

local function buildHelp()
  local p = CreateFrame("Frame", "EPLTowersHelp", UIParent)
  helpFrame = p
  goldFrame(p)
  p:SetFrameStrata("DIALOG")
  p:SetWidth(360)
  p:SetHeight(560)
  p:EnableMouse(true)
  plaque(p, "hTitle")
  closeButton(p, function() p:Hide() end)
  p.heads, p.bodies = {}, {}
  local anchor
  for i = 1, table.getn(E.L.help) do
    local h = text(p, 13.5, true, "ARTWORK")
    if anchor then
      h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    else
      h:SetPoint("TOPLEFT", p, "TOPLEFT", 18, -32)
    end
    h:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
    local b = text(p, 12, false, "ARTWORK")
    b:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -3)
    b:SetWidth(324)
    b:SetJustifyH("LEFT")
    b:SetTextColor(0.88, 0.88, 0.88)
    p.heads[i] = h
    p.bodies[i] = b
    anchor = b
  end
  helpTexts()
  p.last = anchor
  p.pad = 18
  p:Hide()
end

function E.ToggleHelp(forceShow)
  if not main:IsVisible() then main:Show() end
  if not helpFrame then buildHelp() end
  if helpFrame:IsVisible() and not forceShow then
    helpFrame:Hide()
    return
  end
  if optionsFrame then optionsFrame:Hide() end
  placeBeside(helpFrame)
  helpFrame:Show()
  refit(helpFrame)
end

-------------------------------------------------------------------------------
-- Language switch
-------------------------------------------------------------------------------

function E.ApplyLanguage(lang)
  E.SetLanguage(lang)
  E.db.opts.lang = E.lang
  for i = 1, table.getn(labels) do
    local f = labels[i]
    f:SetText(E.T(f.lkey))
    if f.button then fitLabel(f.button) end
  end
  updatePills()
  if helpFrame then
    helpTexts()
    if helpFrame:IsVisible() then refit(helpFrame) end
  end
  if optionsFrame then
    E.RefreshOptions()
    if optionsFrame:IsVisible() then refit(optionsFrame) end
  end
  if menu and menu:IsVisible() then menu:Hide() end
  tipHide()
  E.UpdateUI()
end

-------------------------------------------------------------------------------
-- Minimap button (drag it anywhere)
-------------------------------------------------------------------------------

function E.PlaceMinimapButton()
  mmButton:ClearAllPoints()
  local p = E.db.mm
  if p then
    mmButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
  elseif Minimap then
    mmButton:SetPoint("CENTER", Minimap, "CENTER", -56, -56)
  else
    mmButton:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -200)
  end
end

-- your faction's PvP banner (INV_BannerPVP_01 is the Horde one)
function E.FactionChanged()
  if not mmButton or not mmButton.icon then return end
  if E.myFaction == "Horde" then
    mmButton.icon:SetTexture("Interface\\Icons\\INV_BannerPVP_01")
  else
    mmButton.icon:SetTexture("Interface\\Icons\\INV_BannerPVP_02")
  end
end

function E.UpdateMinimapButton()
  if E.db.opts.minimap then mmButton:Show() else mmButton:Hide() end
end

local function minimapTooltip()
  tipOpen(this, "ANCHOR_LEFT")
  tip:SetText(E.T("title"), GOLD_R, GOLD_G, GOLD_B)
  for i = 1, NT do
    local key = TOWERS[i].key
    local s = E.state[key]
    local d = E.describe(key)
    local c = COLORS[s.owner or "Unknown"]
    local right = E.FN(s.owner)
    if d.compact ~= "" then right = right .. "  " .. d.compact end
    tip:AddDoubleLine(E.TS(key), right, 1, 1, 1, c[1], c[2], c[3])
  end
  tip:AddLine(" ")
  tip:AddLine(E.T("mmLeft"), 0.5, 0.8, 1)
  tip:AddLine(E.T("mmRight"), 0.5, 0.8, 1)
  if not E.db.opts.lock then tip:AddLine(E.T("mmDrag"), 0.5, 0.8, 1) end
  tipShow()
end

local function buildMinimapButton()
  local b = CreateFrame("Button", "EPLTowersMinimapButton", UIParent)
  mmButton = b
  b:SetWidth(33)
  b:SetHeight(33)
  b:SetFrameStrata("MEDIUM")
  b:SetMovable(true)
  b:SetClampedToScreen(true)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -6)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.icon = icon
  E.FactionChanged()
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetWidth(52)
  border:SetHeight(52)
  border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(b)
  hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  hl:SetBlendMode("ADD")
  b:SetScript("OnClick", function()
    if arg1 == "RightButton" then E.ToggleOptions() else E.Toggle() end
  end)
  b:SetScript("OnDragStart", function()
    if E.db.opts.lock then return end
    tipHide()
    this:StartMoving()
  end)
  b:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    E.db.mm = { x = this:GetLeft(), y = this:GetBottom() }
  end)
  b:SetScript("OnEnter", minimapTooltip)
  b:SetScript("OnLeave", tipHide)
  E.PlaceMinimapButton()
  E.UpdateMinimapButton()
end

function E.UpdateLock()
  -- nothing to redraw: dragging checks the option itself
end

-------------------------------------------------------------------------------
-- Refresh (twice a second while the window is open)
-------------------------------------------------------------------------------

local function updateSync()
  local now = GetTime()
  local lk = E.localKey()
  local liveFrom
  for i = 1, NT do
    local s = E.state[TOWERS[i].key]
    if E.isLive(s, now) and s.src ~= "you" then liveFrom = TOWERS[i].key end
  end
  local sy = E.sync
  local peers = E.peerCount()
  local r, g, b, msg
  if lk then
    r, g, b = 0.25, 1, 0.25
    if E.canSync() then msg = E.T("youAtShare", E.TS(lk)) else msg = E.T("youAtNoShare", E.TS(lk)) end
  elseif liveFrom then
    r, g, b = 0.25, 1, 0.25
    msg = E.T("liveFrom", E.SrcName(E.state[liveFrom].src), E.TS(liveFrom))
  elseif not E.canSync() then
    r, g, b = 0.5, 0.5, 0.5
    msg = E.T("noSync")
  elseif peers > 0 then
    r, g, b = 1, 0.82, 0
    msg = E.T("synced", E.players(peers), E.ago(now - sy.lastNewsGT))
  else
    r, g, b = 0.5, 0.5, 0.5
    msg = E.T("waiting")
  end
  syncDot:SetTexture(r, g, b, 1)
  syncText:SetText(msg)
end

local function updateRow(key, s, d, idx)
  local r = rows[key]
  local e = d.e
  local c = COLORS[s.owner or "Unknown"]
  setPoi(r.icon, idx)
  if s.owner then r.icon:SetAlpha(1) else r.icon:SetAlpha(0.45) end
  r.name:SetText(E.TN(key))
  r.owner:SetText(c[4] .. E.FN(s.owner) .. "|r")
  r.tint:SetGradientAlpha("HORIZONTAL", c[1], c[2], c[3], 0.30, c[1], c[2], c[3], 0)
  r.accent:SetTexture(c[1], c[2], c[3], 1)
  local nowT = time()
  if e.live then
    local who
    if s.src == "you" then who = E.T("youHere") else who = E.SrcName(s.src) end
    r.right:SetText("|cff40ff40" .. E.T("live") .. "|r  " .. who)
  elseif s.valueAt then
    r.right:SetText("|cff999999" .. E.T("seenAgo", E.ago(nowT - s.valueAt)) .. "|r")
  elseif s.ownerAt then
    r.right:SetText("|cff999999" .. E.T("ownerInfoAgo", E.ago(nowT - s.ownerAt)) .. "|r")
  else
    r.right:SetText("")
  end
  drawBar(r.bar, s.value, s.neutral, e.dir, not e.live)
  r.line1:SetText(d.line1 or "")
  r.line2:SetText(d.line2 or "")
end

function E.UpdateUI()
  if not main or not main:IsVisible() then return end
  local count = { Alliance = 0, Horde = 0, Neutral = 0 }
  local showMap = E.db.opts.showMap
  for i = 1, NT do
    local key = TOWERS[i].key
    local s = E.state[key]
    local d = E.describe(key)
    local e = d.e
    if s.owner then count[s.owner] = count[s.owner] + 1 end
    local idx = iconIndex(s.owner, e.dir)
    updateRow(key, s, d, idx)
    if showMap then
      local m = markers[key]
      setPoi(m.icon, idx)
      if s.owner then m.icon:SetAlpha(1) else m.icon:SetAlpha(0.5) end
      m.name:SetText(E.TS(key))
      drawBar(m.bar, s.value, s.neutral, e.dir, not e.live)
      m.info:SetText(d.compact)
    end
  end
  scores.Alliance.num:SetText(count.Alliance)
  scores.Horde.num:SetText(count.Horde)
  scores.Neutral.num:SetText(count.Neutral)
  updateSync()
end

-------------------------------------------------------------------------------
-- Show / hide
-------------------------------------------------------------------------------

function E.Toggle()
  if main:IsVisible() then
    main:Hide()
    E.db.shown = false
  else
    main:Show()
    E.db.shown = true
  end
end

function E.OnZoneChanged(inZone)
  if not main then return end
  if inZone then
    if E.db.opts.autoShow and not main:IsVisible() then
      main:Show()
      autoOpened = true
    end
  elseif autoOpened then
    main:Hide()
    autoOpened = nil
  end
end

function E.BuildUI()
  tip = CreateFrame("GameTooltip", "EPLTowersTip", UIParent, "GameTooltipTemplate")
  buildMain()
  buildMap()
  buildRows()
  buildButtons()
  buildMinimapButton()
  updatePills()
  main:SetScale(E.db.opts.scale or 1)
  applyPos()
  E.Layout()
  if E.db.shown then main:Show() else main:Hide() end
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

local resetAsked

local function printHelp()
  for i = 1, 10 do E.print(E.T("s" .. i)) end
end

SLASH_EPLTOWERS1 = "/eplt"
SLASH_EPLTOWERS2 = "/epltowers"
SlashCmdList["EPLTOWERS"] = function(msg)
  local _, _, cmd, rest = string.find(msg or "", "^%s*(%S*)%s*(.-)%s*$")
  cmd = string.lower(cmd or "")
  rest = rest or ""
  if cmd == "" or cmd == "show" or cmd == "toggle" then
    E.Toggle()
  elseif cmd == "hide" then
    main:Hide()
    E.db.shown = false
  elseif cmd == "map" then
    toggleMap()
  elseif cmd == "sync" then
    E.requestSync(true)
  elseif cmd == "announce" or cmd == "report" then
    E.announce(nil, string.lower(rest) == "guild")
  elseif cmd == "options" or cmd == "config" or cmd == "opt" then
    E.ToggleOptions(true)
  elseif cmd == "help" then
    E.ToggleHelp(true)
    printHelp()
  elseif cmd == "en" or cmd == "ru" then
    E.ApplyLanguage(cmd)
    E.print(E.T("langSet"))
  elseif cmd == "lock" then
    E.db.opts.lock = not E.db.opts.lock
    E.RefreshOptions()
    if E.db.opts.lock then E.print(E.T("locked")) else E.print(E.T("unlocked")) end
  elseif cmd == "minimap" then
    E.db.opts.minimap = not E.db.opts.minimap
    E.UpdateMinimapButton()
    E.RefreshOptions()
  elseif cmd == "set" then
    local _, _, which, fac = string.find(rest, "^(.-)%s+(%a+)$")
    local t = E.findTower(which)
    if fac then fac = string.upper(string.sub(fac, 1, 1)) .. string.lower(string.sub(fac, 2)) end
    if t and (fac == "Alliance" or fac == "Horde" or fac == "Neutral") then
      E.manualOwner(t.key, fac)
    else
      E.print(E.T("usageSet"))
    end
  elseif cmd == "anchor" or cmd == "move" then
    E.ToggleAnchor()
  elseif cmd == "defense" or cmd == "defence" or cmd == "ld" then
    E.checkLocalDefense(true)
  elseif cmd == "reset" then
    if resetAsked and GetTime() - resetAsked < 5 then
      resetAsked = nil
      E.resetTowers()
      E.UpdateUI()
    else
      resetAsked = GetTime()
      E.print(E.T("resetAgain"))
    end
  elseif cmd == "log" then
    local log = E.db.log
    local n = table.getn(log)
    for i = math.max(1, n - 14), n do E.print(log[i]) end
  else
    printHelp()
  end
end
