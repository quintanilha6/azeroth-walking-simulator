local _, ns = ...
local L = ns.L
local F = ns.F

local TILE_W, TILE_H = 284, 48

function ns.BuildTrophiesPage(page)
  local A = ns.Achievements

  -- Rank card
  local rank = CreateFrame("Frame", nil, page)
  rank:SetSize(580, 66)
  rank:SetPoint("TOPLEFT")
  local bg = rank:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 0.10)
  local icon = rank:CreateTexture(nil, "ARTWORK")
  icon:SetSize(46, 46)
  icon:SetPoint("LEFT", 10, 0)
  icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local kicker = rank:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  kicker:SetPoint("TOPLEFT", 66, -8)
  local name = rank:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  name:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
  name:SetPoint("TOPLEFT", kicker, "BOTTOMLEFT", 0, -2)
  local bar = CreateFrame("StatusBar", nil, rank)
  bar:SetPoint("TOPLEFT", 66, -44)
  bar:SetSize(500, 16)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(unpack(ns.ORANGE))
  bar:SetMinMaxValues(0, 1)
  local barBg = bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints()
  barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  barBg:SetVertexColor(0, 0, 0, 0.5)
  rank:SetHeight(70)
  local next = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  next:SetPoint("CENTER", 0, 0)
  local hint = rank:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPRIGHT", -12, -10)
  hint:SetText(L["Hover to see all ranks"])

  local counts = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  counts:SetPoint("TOPLEFT", 4, -78)

  rank:EnableMouse(true)
  rank:SetScript("OnEnter", function(self) A.ShowRankTooltip(self) end)
  rank:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Scrolling area: all-time totals, achievements grid, then personal records.
  -- (All nine ranks are in the rank card's tooltip.)
  local scroll, content = ns.MakeScroll(page, "AWSTrophyScroll", -98)
  local lowerTop = 70 -- where the achievements start in the scroll area (set in Refresh)

  local function SectionHeader(parent, y, text)
    local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 0, y)
    h:SetTextColor(unpack(ns.ORANGE))
    h:SetText(text)
    return h
  end

  -- All-time totals: this character, plus the account when you have alts
  local COL = { 0, 145, 290, 435 }
  local function TotalsRow(parent)
    local h = SectionHeader(parent, 0, "")
    return h, {
      ns.StatTile(parent, COL[1], -18, L["Steps"]),
      ns.StatTile(parent, COL[2], -18, L["Distance"]),
      ns.StatTile(parent, COL[3], -18, L["Moving time"]),
      ns.StatTile(parent, COL[4], -18, L["Activities"]),
    }
  end
  local charHeader, charVals = TotalsRow(content)
  local acct = CreateFrame("Frame", nil, content)
  acct:SetSize(570, 56)
  acct:SetPoint("TOPLEFT", 0, -62)
  local acctHeader, acctVals = TotalsRow(acct)

  -- Achievements and records sit in their own frame, moved up when the
  -- account row is hidden
  local lower = CreateFrame("Frame", nil, content)
  lower:SetSize(570, 1)
  SectionHeader(lower, 0, L["Achievements"])
  local GRID_TOP = -20

  local tiles = {}
  for i, a in ipairs(A.LIST) do
    local t = CreateFrame("Frame", nil, lower)
    t:SetSize(TILE_W - 4, TILE_H - 4)
    t:SetPoint("TOPLEFT", ((i - 1) % 2) * TILE_W, GRID_TOP - math.floor((i - 1) / 2) * TILE_H)
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints()
    t.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(36, 36)
    t.icon:SetPoint("LEFT", 4, 0)
    t.icon:SetTexture(a.icon)
    t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    t.name = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t.name:SetPoint("TOPLEFT", 46, -4)
    t.name:SetText(L[a.name])
    t.line1 = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.line1:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -2)
    t.line1:SetWidth(TILE_W - 56)
    t.line1:SetJustifyH("LEFT")
    t.line1:SetWordWrap(false)
    t.line2 = t:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t.line2:SetPoint("TOPLEFT", t.line1, "BOTTOMLEFT", 0, -1)
    t:EnableMouse(true)
    t:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L[a.name], 1, 0.82, 0)
      GameTooltip:AddLine(L[a.desc], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    t.a = a
    t.y = -GRID_TOP + math.floor((i - 1) / 2) * TILE_H -- offset inside `lower`
    tiles[i] = t
  end

  -- Banner click: scroll to the achievement (or the rank card) and flash it
  function page:Highlight(o)
    if o.rank then ns.Flash(rank) return end
    for _, t in ipairs(tiles) do
      if t.a.id == o.ach then
        local range = scroll:GetVerticalScrollRange() or 0
        scroll:SetVerticalScroll(math.max(0, math.min(range, lowerTop + t.y - 60)))
        ns.Flash(t)
        return
      end
    end
  end

  local gridH = -GRID_TOP + math.ceil(#A.LIST / 2) * TILE_H
  local recHeader = lower:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  recHeader:SetPoint("TOPLEFT", 0, -gridH - 10)
  recHeader:SetTextColor(unpack(ns.ORANGE))
  recHeader:SetText(L["Personal records"])
  local recLabels = { L["Most steps in one activity"], L["Longest distance"], L["Longest moving time"], L["Best day"],
                      L["Longest streak"], L["Zones walked in"] }
  local recValues = {}
  for i, label in ipairs(recLabels) do
    local y = -gridH - 30 - (i - 1) * 20
    local l = lower:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    l:SetPoint("TOPLEFT", 4, y)
    l:SetText(label)
    recValues[i] = lower:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    recValues[i]:SetPoint("TOPLEFT", 210, y)
  end
  local lowerH = gridH + 40 + #recLabels * 20

  local function SessionText(s, value)
    if not s then return "-" end
    return value .. "   |cff888888" .. F.Day(s.start) .. "|r"
  end

  function page:Refresh()
    local c = ns.cdb
    local steps = c.total.steps
    local idx = A.MyRank()
    kicker:SetText((L["RANK %d OF %d"]):format(idx, #A.RANKS))
    name:SetText(A.RankColored(idx))
    local nextRank = A.RANKS[idx + 1]
    if nextRank then
      local from = A.RANKS[idx][1]
      bar:SetValue((steps - from) / (nextRank[1] - from))
      next:SetText((L["%s / %s steps to %s"]):format(F.Number(steps), F.Number(nextRank[1]), L[nextRank[2]]))
    else
      bar:SetValue(1)
      next:SetText(L["Max rank. Legendary walker!"])
    end

    local t = c.total
    charHeader:SetText((L["All-time: %s (since %s)"]):format(UnitName("player"), F.Day(c.since)))
    charVals[1]:SetText(F.Number(t.steps))
    charVals[2]:SetText(F.Distance(t.distance))
    charVals[3]:SetText(F.Time(t.moving))
    charVals[4]:SetText(t.sessions)
    local a = ns.AccountTotals()
    local hasAlts = a.chars > 1
    acct:SetShown(hasAlts)
    if hasAlts then
      acctHeader:SetText((L["All-time: account (%d characters, since %s)"]):format(a.chars, F.Day(ns.db.since)))
      acctVals[1]:SetText(F.Number(a.steps))
      acctVals[2]:SetText(F.Distance(a.distance))
      acctVals[3]:SetText(F.Time(a.moving))
      acctVals[4]:SetText(a.sessions)
    end
    local top = hasAlts and 132 or 70
    lowerTop = top
    lower:ClearAllPoints()
    lower:SetPoint("TOPLEFT", 0, -top)
    content:SetHeight(top + lowerH)

    local w, m, champ = ns.Challenges.Counts()
    counts:SetText((L["|cffffd100Achievements|r %d/%d     |cffffd100Weekly challenges|r %d     "] ..
      L["|cffffd100Monthly|r %d     |cffffd100Weekly Champion|r x%d"]):format(A.Count(), #A.LIST, w, m, champ))

    for _, t in ipairs(tiles) do
      local earned = c.achievements[t.a.id]
      t.icon:SetDesaturated(not earned)
      t.icon:SetAlpha(earned and 1 or 0.5)
      if earned then
        t.bg:SetVertexColor(1, 0.82, 0, 0.10)
        t.name:SetTextColor(1, 0.82, 0)
        t.line1:SetText(L[t.a.desc])
        t.line2:SetText(L["Earned "] .. F.Day(earned))
      else
        t.bg:SetVertexColor(1, 1, 1, 0.03)
        t.name:SetTextColor(0.6, 0.6, 0.6)
        t.line1:SetText(L[t.a.desc])
        local value, goal = t.a.check(c)
        t.line2:SetText(A.ProgressText(t.a, value, goal))
      end
    end

    local r = ns.Records()
    recValues[1]:SetText(SessionText(r.steps, r.steps and F.Number(r.steps.steps)))
    recValues[2]:SetText(SessionText(r.distance, r.distance and F.Distance(r.distance.distance)))
    recValues[3]:SetText(SessionText(r.moving, r.moving and F.Time(r.moving.moving)))
    if r.dayKey and r.daySteps >= 1 then
      recValues[4]:SetText((L["%s steps   |cff888888%s|r"]):format(F.Number(r.daySteps), r.dayKey))
    else
      recValues[4]:SetText("-")
    end
    local _, best = ns.Streaks()
    recValues[5]:SetText(best .. L[" days"])
    local zones = 0
    for _ in pairs(c.zones) do zones = zones + 1 end
    recValues[6]:SetText(zones)
  end
end
