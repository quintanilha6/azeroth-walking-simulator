local _, ns = ...
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

function ns.SmallButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 60, 20)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
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
  if st.reason then return "blocked", "Not counting: " .. (ns.REASON_TEXT[st.reason] or st.reason) end
  if not s then return "off", "No session (today)" end
  if s.paused then return "paused", "Paused" end
  if st.moving then return "recording", "Recording" end
  return "idle", "Standing still"
end

function ns.StatusColor(key) return STATUS_COLORS[key] end

function ns.ApplyTrackerSettings()
  local f, s = ns.Tracker, ns.settings
  if not f then return end
  f:SetScale(s.trackerScale)
  f:ClearAllPoints()
  local p = s.trackerPoint
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
  f:SetSize(252, 112)
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
  rankLine:SetWidth(210)
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

  local startBtn = ns.SmallButton(f, "Start", 58, function()
    local s = ns.cdb.current
    if not s then ns.StartSession(false)
    elseif s.paused then ns.ResumeSession()
    else ns.PauseSession() end
  end)
  startBtn:SetPoint("BOTTOMLEFT", 8, 7)

  local stopBtn = ns.SmallButton(f, "Finish", 58, function() ns.StopSession() end)
  stopBtn:SetPoint("LEFT", startBtn, "RIGHT", 2, 0)

  local shareBtn
  shareBtn = ns.SmallButton(f, "Share", 58, function() ns.QuickShare.Open(shareBtn) end)
  shareBtn:SetPoint("LEFT", stopBtn, "RIGHT", 2, 0)

  local openBtn = ns.SmallButton(f, "Stats", 58, function() ns.ToggleWindow() end)
  openBtn:SetPoint("LEFT", shareBtn, "RIGHT", 2, 0)

  function f:Refresh()
    local cur = ns.cdb.current
    local key, label = ns.Status()
    dot:SetVertexColor(unpack(STATUS_COLORS[key]))
    status:SetText(label)

    local stepCount, dist, moving
    if cur then
      stepCount, dist, moving = cur.steps, cur.distance, cur.moving
      stepsLabel:SetText("steps this session")
    else
      local day = ns.GetDay(date("%Y-%m-%d"))
      stepCount, dist, moving = day.s, day.d, nil
      stepsLabel:SetText("steps today")
    end
    steps:SetText(F.Number(stepCount))
    if moving then
      line:SetText(("%s  |  %s  |  %s"):format(F.Distance(dist), F.Time(moving), F.Pace(moving, dist)))
    else
      line:SetText(F.Distance(dist))
    end

    local left = ns.Challenges.cache.weeklyLeft
    rankLine:SetText(ns.Achievements.RankColored(ns.Achievements.MyRank()) .. "  |cff888888" ..
      (left > 0 and (left .. " weekly challenge" .. (left == 1 and "" or "s") .. " left") or "Weekly Champion!") .. "|r")

    if not cur then startBtn:SetText("Start")
    elseif cur.paused then startBtn:SetText("Resume")
    else startBtn:SetText("Pause") end
    stopBtn:SetEnabled(cur ~= nil)
  end

  ns.Tracker = f
  ns.ApplyTrackerSettings()
  f:Refresh()
end
