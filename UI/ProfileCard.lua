local _, ns = ...
local L = ns.L
local F = ns.F

-- A friend's profile: rank, stats, this week's challenges and their trophies.
-- Opened from the leaderboard, the feed and "Friend news" toasts.
local W, H = 372, 500
local ICON, GAP, PER_ROW = 32, 6, 8

local card, guid

local function Header(parent, y, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", 16, y)
  fs:SetTextColor(unpack(ns.ORANGE))
  fs:SetText(text)
  local right = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  right:SetPoint("TOPRIGHT", -16, y - 1)
  return fs, right
end

local function Create()
  local f = ns.CreatePanel("AWSProfile")
  f:SetSize(W, H)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:Hide()
  tinsert(UISpecialFrames, "AWSProfile") -- close with Escape

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)

  -- Name and status
  f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.name:SetPoint("TOPLEFT", 16, -16)
  f.name:SetWidth(W - 60)
  f.name:SetJustifyH("LEFT")
  f.name:SetWordWrap(false)
  f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.status:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
  f.status:SetWidth(W - 32)
  f.status:SetJustifyH("LEFT")

  -- Rank and the bar to the next one
  f.rank = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  f.rank:SetPoint("TOPLEFT", 16, -60)
  f.bar = CreateFrame("StatusBar", nil, f)
  f.bar:SetPoint("TOPLEFT", 16, -84)
  f.bar:SetSize(W - 32, 14)
  f.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  f.bar:SetStatusBarColor(unpack(ns.ORANGE))
  f.bar:SetMinMaxValues(0, 1)
  local barBg = f.bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints()
  barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  barBg:SetVertexColor(0, 0, 0, 0.5)
  f.next = f.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.next:SetPoint("CENTER")

  -- Stats: two rows of three
  local COLS = { 16, 130, 244 }
  f.tiles = {
    ns.StatTile(f, COLS[1], -110, L["Today"]),
    ns.StatTile(f, COLS[2], -110, L["This week"]),
    ns.StatTile(f, COLS[3], -110, L["This month"]),
    ns.StatTile(f, COLS[1], -150, L["All-time"]),
    ns.StatTile(f, COLS[2], -150, L["Streak"]),
    ns.StatTile(f, COLS[3], -150, L["Activities"]),
  }

  -- This week's challenges: one medal per challenge, lit when they finished it
  local _, weekRight = Header(f, -196, L["This week's challenges"])
  f.weekRight = weekRight
  f.medals = {}
  for i = 1, 3 do
    local m = CreateFrame("Frame", nil, f)
    m:SetSize(30, 30)
    m:SetPoint("TOPLEFT", 16 + (i - 1) * 36, -214)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetAllPoints()
    m.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    m:EnableMouse(true)
    m:SetScript("OnEnter", function(self)
      if not self.ch then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(ns.Challenges.TierName(self.ch) .. "  " .. L[self.ch.name], 1, 0.82, 0)
      GameTooltip:AddLine(L[self.ch.desc], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.medals[i] = m
  end
  f.champ = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.champ:SetPoint("LEFT", f.medals[3], "RIGHT", 12, 0)

  -- Achievements grid
  local _, achRight = Header(f, -258, L["Achievements"])
  f.achRight = achRight
  f.ach = {}
  for i, a in ipairs(ns.Achievements.LIST) do
    local b = CreateFrame("Frame", nil, f)
    b:SetSize(ICON, ICON)
    b:SetPoint("TOPLEFT", 16 + ((i - 1) % PER_ROW) * (ICON + GAP), -278 - math.floor((i - 1) / PER_ROW) * (ICON + GAP))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(a.icon)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L[a.name], 1, 0.82, 0)
      GameTooltip:AddLine(L[a.desc], 1, 1, 1, true)
      if self.earned then GameTooltip:AddLine(ns.Achievements.CHECK .. " " .. strtrim(L["Earned "]), 0.2, 0.9, 0.3) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.ach[i] = b
  end
  f.old = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.old:SetPoint("BOTTOMLEFT", 16, 14)
  f.old:SetWidth(W - 32)
  f.old:SetJustifyH("LEFT")

  function f:Refresh()
    local e = guid and ns.db.social.people[guid]
    if not e then self:Hide() return end
    local S, A, Ch = ns.Social, ns.Achievements, ns.Challenges

    self.name:SetText(S.ColoredName(guid))
    local status
    if S.IsOnline(e) and e.active then
      status = ("|cff33e64d" .. L["Walking now: %s steps this session"] .. "|r"):format(F.Number(e.sessionSteps or 0))
    elseif S.IsOnline(e) then
      status = "|cffe6cc33" .. L["Online"] .. "|r"
    elseif e.updated then
      status = "|cff999999" .. L["Last seen "] .. F.Date(e.updated) .. "|r"
    else
      status = ""
    end
    if e.since and e.since > 0 then
      status = status .. "   |cff888888" .. L["Walking since"] .. " " .. F.Day(e.since) .. "|r"
    end
    self.status:SetText(status)

    -- rank from their all-time steps
    local all, rank = e.all or 0, math.max(1, math.min(e.rank or 1, #A.RANKS))
    self.rank:SetText(A.RankColored(rank))
    local nextRank = A.RANKS[rank + 1]
    if nextRank then
      local from = A.RANKS[rank][1]
      self.bar:SetValue(math.max(0, math.min(1, (all - from) / (nextRank[1] - from))))
      self.next:SetText((L["%s / %s steps to %s"]):format(F.Number(all), F.Number(nextRank[1]), L[nextRank[2]]))
    else
      self.bar:SetValue(1)
      self.next:SetText(L["Max rank. Legendary walker!"])
    end

    -- numbers from an old day / week / month don't count anymore
    local week = Ch.WeekPeriod()
    local today = e.todayKey == date("%Y-%m-%d") and e.today or 0
    local thisWeek = e.weekKey == week.key and e.week or 0
    local thisMonth = e.monthKey == ("M" .. date("%Y-%m")) and e.month or 0
    local t = self.tiles
    t[1]:SetText(F.Number(today))
    t[2]:SetText(F.Number(thisWeek))
    t[3]:SetText(F.Number(thisMonth))
    t[4]:SetText(F.Number(all))
    t[5]:SetText((e.streak or 0) .. ((e.streak == 1) and L[" day"] or L[" days"]))
    t[6]:SetText(e.sessions or 0)

    -- this week's challenges
    local picks = Ch.WeeklyPicks(week)
    for i, m in ipairs(self.medals) do
      local ch = picks[i]
      m.ch = ch
      m:SetShown(ch ~= nil)
      if ch then
        local done = Ch.FriendsDone(week.key, ch.id)
        local got = done and done[guid]
        m.icon:SetTexture(Ch.TIERS[ch.tier].icon)
        m.icon:SetDesaturated(not got)
        m.icon:SetAlpha(got and 1 or 0.4)
      end
    end
    local weekDone = e.weekKey == week.key and e.weekDone or 0
    self.weekRight:SetText((L["%d / 3 done"]):format(weekDone))
    local champs = Ch.FriendsDone(week.key, "champion")
    self.champ:SetText((champs and champs[guid]) and ("|cffffd100" .. L["Weekly Champion!"] .. "|r") or "")

    -- achievements: from the bitmask (2.6.0+), or just the count from older versions
    local mask = e.achMask
    for i, b in ipairs(self.ach) do
      local earned = A.MaskHas(mask, e.achMask2, i)
      b.earned = earned
      b.icon:SetDesaturated(not earned)
      b.icon:SetAlpha(earned and 1 or 0.3)
    end
    self.achRight:SetText((L["%d / %d achievements"]):format(e.ach or 0, #A.LIST))
    self.old:SetText(mask and "" or L["Ask them to update the addon to see their trophies."])
  end

  return f
end

-- Open someone's profile. Your own opens the Trophies tab instead.
function ns.ShowProfile(g)
  if not g or not ns.cdb then return end
  if g == ns.Social.MyGUID() then
    ns.ToggleWindow(ns.TROPHIES_TAB)
    return
  end
  if not ns.db.social.people[g] then return end
  card = card or Create()
  guid = g
  card:ClearAllPoints()
  local w = ns.Window
  if w and w:IsShown() and w:GetLeft() and w:GetLeft() > W + 8 then
    card:SetPoint("TOPRIGHT", w, "TOPLEFT", -4, 0)
  elseif w and w:IsShown() then
    card:SetPoint("TOPLEFT", w, "TOPRIGHT", 4, 0)
  else
    card:SetPoint("CENTER")
  end
  card:Show()
  card:Refresh()
end

-- Keep an open profile up to date when new data arrives
function ns.RefreshProfile()
  if card and card:IsShown() then card:Refresh() end
end
