local _, ns = ...
local L = ns.L
local F = ns.F

ns.BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

function ns.CreatePanel(name, parent)
  local f = CreateFrame("Frame", name, parent or UIParent, BackdropTemplateMixin and "BackdropTemplate")
  f:SetBackdrop(ns.BACKDROP)
  f:SetBackdropColor(0.05, 0.05, 0.07, 0.92)
  f:SetBackdropBorderColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 0.9)
  return f
end

-- The standard X button. It hides its window directly: the template's own
-- click goes through the game's panel manager, which is blocked in combat.
function ns.CloseButton(parent)
  local b = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
  b:SetPoint("TOPRIGHT", -2, -2)
  b:SetScript("OnClick", function() parent:Hide() end)
  return b
end

function ns.SmallButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 60, 20)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

-- A flat tab: grey text, white with an orange underline when selected.
-- Used for the window tabs and the leaderboard filters (the red buttons are
-- kept for actions).
function ns.TabButton(parent, text, onClick, font)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(24)
  local fs = b:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
  fs:SetPoint("CENTER", 0, 1)
  b:SetFontString(fs)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetTexture("Interface\\Buttons\\WHITE8X8")
  hl:SetVertexColor(1, 1, 1, 0.06)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  b.bg:SetVertexColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 0.14)
  b.line = b:CreateTexture(nil, "ARTWORK")
  b.line:SetTexture("Interface\\Buttons\\WHITE8X8")
  b.line:SetVertexColor(unpack(ns.ORANGE))
  b.line:SetPoint("BOTTOMLEFT")
  b.line:SetPoint("BOTTOMRIGHT")
  b.line:SetHeight(2)

  function b:SetLabel(t)
    self:SetText(t)
    self:SetWidth(math.max(40, fs:GetStringWidth() + 22))
  end
  function b:SetSelected(on)
    self.selected = on
    self.bg:SetShown(on)
    self.line:SetShown(on)
    if on then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(0.62, 0.62, 0.62) end
  end
  b:SetScript("OnEnter", function(self) if not self.selected then fs:SetTextColor(0.9, 0.9, 0.9) end end)
  b:SetScript("OnLeave", function(self) self:SetSelected(self.selected) end)
  b:SetScript("OnClick", onClick)
  b:SetLabel(text)
  b:SetSelected(false)
  return b
end

-- Pulse an orange glow around a frame for a few seconds ("this is what you
-- just unlocked"). One overlay per frame, reused.
function ns.Flash(frame)
  if not frame then return end
  local g = frame.awsFlash
  if not g then
    g = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
    g:SetPoint("TOPLEFT", -3, 3)
    g:SetPoint("BOTTOMRIGHT", 3, -3)
    g:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    g:SetBackdropBorderColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 1)
    local fill = g:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetVertexColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 0.15)
    g:EnableMouse(false)
    frame.awsFlash = g
  end
  g:SetFrameLevel(frame:GetFrameLevel() + 5)
  g.t = 0
  g:SetAlpha(1)
  g:Show()
  g:SetScript("OnUpdate", function(self, el)
    self.t = self.t + el
    if self.t > 3.5 then
      self:SetScript("OnUpdate", nil)
      self:Hide()
      return
    end
    local a = 0.55 + 0.45 * math.sin(self.t * 8)
    if self.t > 2.5 then a = a * (3.5 - self.t) end
    self:SetAlpha(a)
  end)
end

-- Right-click style menu. actions = { { label, func, disabled }, ... }
local menuFrame
function ns.ContextMenu(owner, title, actions)
  GameTooltip:Hide()
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(owner, function(_, root)
      if title then root:CreateTitle(title) end
      for _, a in ipairs(actions) do
        local b = root:CreateButton(a[1], a[2])
        if a[3] and b.SetEnabled then b:SetEnabled(false) end
      end
    end)
    return
  end
  if not (UIDropDownMenu_Initialize and ToggleDropDownMenu) then return end
  menuFrame = menuFrame or CreateFrame("Frame", "AWSContextMenu", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(menuFrame, function(_, level)
    local info
    if title then
      info = UIDropDownMenu_CreateInfo()
      info.text, info.isTitle, info.notCheckable = title, true, true
      UIDropDownMenu_AddButton(info, level)
    end
    for _, a in ipairs(actions) do
      info = UIDropDownMenu_CreateInfo()
      info.text, info.func, info.notCheckable, info.disabled = a[1], a[2], true, a[3]
      UIDropDownMenu_AddButton(info, level)
    end
    info = UIDropDownMenu_CreateInfo()
    info.text, info.notCheckable, info.func = CANCEL or L["Cancel"], true, function() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info, level)
  end, "MENU")
  ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
end

local STATUS_COLORS = {
  recording = { 0.2, 0.9, 0.3 },
  idle      = { 0.9, 0.8, 0.2 },
  paused    = { 1.0, 0.55, 0.1 },
  blocked   = { 0.9, 0.2, 0.2 },
  off       = { 0.5, 0.5, 0.5 },
}

-- Returns status key and label for the tracker / window
function ns.Status()
  local s, st = ns.cdb.current, ns.state
  if st.reason then return "blocked", L["Not counting: "] .. (L[ns.REASON_TEXT[st.reason] or st.reason]) end
  if not s then return "off", L["No session (today)"] end
  if s.paused then return "paused", L["Paused"] end
  if st.moving then return "recording", L["Recording"] end
  return "idle", L["Standing still"]
end

function ns.StatusColor(key) return STATUS_COLORS[key] end

function ns.ApplyTrackerSettings()
  local f, s = ns.Tracker, ns.settings
  if not f then return end
  f:SetScale(s.trackerScale)
  f:ClearAllPoints()
  local p = s.trackerPoint
  -- 2.6.0 made the tracker 28px shorter (112 -> 84). Keep its top edge where
  -- the player put it when it was saved by its bottom or center.
  if p and not s.trackerShort then
    if p[1]:find("BOTTOM") then p[4] = p[4] + 28
    elseif not p[1]:find("TOP") then p[4] = p[4] + 14 end
  end
  s.trackerShort = true
  if p then
    f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
  end
  f:SetShown(s.trackerShown)
end

function ns.CreateTracker()
  if ns.Tracker then return end
  local f = ns.CreatePanel("AWSTracker")
  f:SetSize(240, 84)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if not ns.settings.trackerLocked then self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.settings.trackerPoint = { p, rp, x, y }
  end)
  f:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ns.ToggleWindow() end
  end)

  local dot = f:CreateTexture(nil, "OVERLAY")
  dot:SetTexture("Interface\\Buttons\\WHITE8X8")
  dot:SetSize(8, 8)
  dot:SetPoint("TOPLEFT", 10, -10)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("LEFT", dot, "RIGHT", 5, 0)
  title:SetText("AWS")
  title:SetTextColor(unpack(ns.ORANGE))

  local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("TOPRIGHT", -10, -8)
  status:SetJustifyH("RIGHT")
  status:SetWidth(140)
  status:SetWordWrap(false)

  local steps = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  steps:SetFont(STANDARD_TEXT_FONT, 22, "OUTLINE")
  steps:SetPoint("TOPLEFT", 10, -24)

  local stepsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  stepsLabel:SetPoint("BOTTOMLEFT", steps, "BOTTOMRIGHT", 4, 3)

  local line = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  line:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", 0, -4)

  local rankLine = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rankLine:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -3)
  rankLine:SetWidth(220)
  rankLine:SetJustifyH("LEFT")
  rankLine:SetWordWrap(false)

  -- Hover the rank line to see what ranks are (still drags the tracker)
  local rankHit = CreateFrame("Frame", nil, f)
  rankHit:SetPoint("TOPLEFT", rankLine, "TOPLEFT", 0, 2)
  rankHit:SetPoint("BOTTOMRIGHT", rankLine, "BOTTOMRIGHT", 0, -2)
  rankHit:EnableMouse(true)
  rankHit:RegisterForDrag("LeftButton")
  rankHit:SetScript("OnEnter", function(self) ns.Achievements.ShowRankTooltip(self) end)
  rankHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
  rankHit:SetScript("OnDragStart", function() f:GetScript("OnDragStart")(f) end)
  rankHit:SetScript("OnDragStop", function() f:GetScript("OnDragStop")(f) end)
  rankHit:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ns.ToggleWindow() end
  end)

  -- The buttons sit in a strip under the tracker (above it when the tracker
  -- is near the bottom). While you're walking it only shows when the mouse
  -- is over the tracker; with no session or a paused one it always shows, so
  -- Start / Resume are never hidden.
  local bar = ns.CreatePanel(nil, f)
  bar:SetSize(240, 78)
  bar:EnableMouse(true)
  bar:Hide()
  local function PlaceBar()
    bar:ClearAllPoints()
    local bottom = f:GetBottom()
    if bottom and bottom * f:GetEffectiveScale() < 90 * UIParent:GetEffectiveScale() then
      bar:SetPoint("BOTTOM", f, "TOP", 0, -3)
    else
      bar:SetPoint("TOP", f, "BOTTOM", 0, 3)
    end
  end
  local hoverAcc = 0
  f:HookScript("OnUpdate", function(_, elapsed)
    hoverAcc = hoverAcc + elapsed
    if hoverAcc < 0.1 then return end
    hoverAcc = 0
    local cur = ns.cdb and ns.cdb.current
    local want = not cur or cur.paused or f:IsMouseOver() or (bar:IsShown() and bar:IsMouseOver())
    if want and not bar:IsShown() then PlaceBar(); bar:Show()
    elseif not want and bar:IsShown() then bar:Hide() end
  end)

  -- two columns: Pause/Finish, Share/Route, Social/Stats
  local BTN_W = 109
  local startBtn = ns.SmallButton(bar, L["Start"], BTN_W, function()
    local s = ns.cdb.current
    if not s then ns.StartSession(false)
    elseif s.paused then ns.ResumeSession()
    else ns.PauseSession() end
  end)
  startBtn:SetPoint("TOPLEFT", 8, -8)

  local stopBtn = ns.SmallButton(bar, L["Finish"], BTN_W, function() ns.StopSession() end)
  stopBtn:SetPoint("LEFT", startBtn, "RIGHT", 6, 0)

  local shareBtn
  shareBtn = ns.SmallButton(bar, L["Share"], BTN_W, function() ns.QuickShare.Open(shareBtn) end)
  shareBtn:SetPoint("TOPLEFT", startBtn, "BOTTOMLEFT", 0, -2)

  -- Route card for the walk in progress, or the last activity (same as /aws route)
  local routeBtn = ns.SmallButton(bar, L["Route"], BTN_W, function()
    local cur = ns.cdb.current
    ns.RouteViewer.Open(ns.Routes.Has(cur) and cur or ns.cdb.history[1])
  end)
  routeBtn:SetPoint("LEFT", shareBtn, "RIGHT", 6, 0)

  -- Leaderboard (the Social tab), like /aws social
  local socialBtn = ns.SmallButton(bar, L["Social"], BTN_W, function() ns.ToggleWindow(ns.SOCIAL_TAB) end)
  socialBtn:SetPoint("TOPLEFT", shareBtn, "BOTTOMLEFT", 0, -2)

  local openBtn = ns.SmallButton(bar, L["Stats"], BTN_W, function() ns.ToggleWindow() end)
  openBtn:SetPoint("LEFT", socialBtn, "RIGHT", 6, 0)

  function f:Refresh()
    local cur = ns.cdb.current
    local key, label = ns.Status()
    dot:SetVertexColor(unpack(STATUS_COLORS[key]))
    status:SetText(label)

    local stepCount, dist, moving
    if cur then
      stepCount, dist, moving = cur.steps, cur.distance, cur.moving
      stepsLabel:SetText(L["steps this session"])
    else
      local day = ns.GetDay(date("%Y-%m-%d"))
      stepCount, dist, moving = day.s, day.d, nil
      stepsLabel:SetText(L["steps today"])
    end
    steps:SetText(F.Number(stepCount))
    if moving then
      line:SetText(("%s  |  %s  |  %s"):format(F.Distance(dist), F.Time(moving), F.Pace(moving, dist)))
    else
      line:SetText(F.Distance(dist))
    end

    local left = ns.Challenges.cache.weeklyLeft
    rankLine:SetText(ns.Achievements.RankColored(ns.Achievements.MyRank()) .. "  |cff888888" ..
      (left == 1 and L["1 weekly challenge left"] or left > 1 and (L["%d weekly challenges left"]):format(left)
        or L["Weekly Champion!"]) .. "|r")

    if not cur then startBtn:SetText(L["Start"])
    elseif cur.paused then startBtn:SetText(L["Resume"])
    else startBtn:SetText(L["Pause"]) end
    stopBtn:SetEnabled(cur ~= nil)
  end

  ns.Tracker = f
  ns.ApplyTrackerSettings()
  f:Refresh()
end
