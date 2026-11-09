local _, ns = ...
local F = ns.F

local CARD_W, CARD_H = 580, 62
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"

local function Hex(c)
  return ("%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

local function Header(parent, y, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", 0, y)
  fs:SetTextColor(unpack(ns.ORANGE))
  fs:SetText(text)
  local right = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  right:SetPoint("TOPRIGHT", -10, y - 2)
  return fs, right
end

local function FriendNames(set)
  if not set then return nil end
  local names, n = {}, 0
  for guid in pairs(set) do
    n = n + 1
    if n <= 3 then table.insert(names, ns.Social.ColoredName(guid)) end
  end
  if n == 0 then return nil end
  local s = table.concat(names, ", ")
  if n > 3 then s = s .. (" +%d"):format(n - 3) end
  return s
end

local function Card(parent, y)
  local c = CreateFrame("Frame", nil, parent)
  c:SetSize(CARD_W, CARD_H)
  c:SetPoint("TOPLEFT", 0, y)
  local bg = c:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(1, 1, 1, 0.04)
  c.edge = c:CreateTexture(nil, "ARTWORK")
  c.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
  c.edge:SetPoint("TOPLEFT")
  c.edge:SetPoint("BOTTOMLEFT")
  c.edge:SetWidth(3)

  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(40, 40)
  c.icon:SetPoint("LEFT", 12, 0)
  c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  c.title = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  c.title:SetPoint("TOPLEFT", 62, -8)
  c.desc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  c.desc:SetPoint("TOPLEFT", 62, -25)
  c.desc:SetTextColor(0.75, 0.75, 0.75)

  c.bar = CreateFrame("StatusBar", nil, c)
  c.bar:SetPoint("TOPLEFT", 62, -43)
  c.bar:SetSize(300, 10)
  c.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  c.bar:SetMinMaxValues(0, 1)
  local barBg = c.bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints()
  barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  barBg:SetVertexColor(0, 0, 0, 0.5)

  c.prog = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  c.prog:SetPoint("LEFT", c.bar, "RIGHT", 8, 0)

  c.status = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  c.status:SetPoint("TOPRIGHT", -10, -8)
  c.friends = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  c.friends:SetPoint("TOPRIGHT", -10, -25)
  c.friends:SetWidth(200)
  c.friends:SetJustifyH("RIGHT")
  c.friends:SetWordWrap(false)

  function c:Set(e)
    local ch, tier = e.ch, ns.Challenges.TIERS[e.ch.tier]
    self.edge:SetVertexColor(unpack(tier.color))
    self.icon:SetTexture(tier.icon)
    self.icon:SetDesaturated(false)
    self.title:SetText(("|cff%s%s|r   %s"):format(Hex(tier.color), tier.name:upper(), ch.name))
    self.desc:SetText(ch.desc)
    self.bar:SetValue(math.min(1, e.value / ch.goal))
    self.prog:SetText(ns.Challenges.ProgressText(ch, e.value))
    if e.done then
      self.bar:SetStatusBarColor(0.2, 0.85, 0.3)
      self.status:SetText(CHECK .. " |cff33dd55Done " .. date("%b %d", e.done) .. "|r")
    else
      self.bar:SetStatusBarColor(unpack(tier.color))
      self.status:SetText(("|cffaaaaaa%d%%|r"):format(math.floor(math.min(1, e.value / ch.goal) * 100)))
    end
    local names = FriendNames(ns.Challenges.FriendsDone(e.period.key, ch.id))
    self.friends:SetText(names and ("|cff888888Done by|r " .. names) or "")
  end
  return c
end

function ns.BuildChallengesPage(page)
  local _, weekReset = Header(page, 0, "This week's challenges")
  local cards = {}
  for i = 1, 3 do cards[i] = Card(page, -20 - (i - 1) * (CARD_H + 4)) end

  local champ = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  champ:SetPoint("TOPLEFT", 4, -222)

  local _, monthReset = Header(page, -248, "This month's challenges")
  for i = 4, 5 do cards[i] = Card(page, -268 - (i - 4) * (CARD_H + 4)) end

  local footer = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("TOPLEFT", 4, -404)
  footer:SetWidth(CARD_W)
  footer:SetJustifyH("LEFT")

  function page:Refresh()
    local list, week, month = ns.Challenges.Active()
    for i, e in ipairs(list) do
      if cards[i] then cards[i]:Set(e) end
    end
    local now = time()
    weekReset:SetText("New challenges in " .. F.Countdown(week.endTs - now))
    monthReset:SetText("Resets in " .. F.Countdown(month.endTs - now))

    local done = ns.cdb.completed[week.key]
    if done and done.champion then
      champ:SetText(CHECK .. " |cffffd100You are this week's Weekly Champion!|r")
    else
      local left = 3 - ns.Challenges.WeekChallengesDone(week.key)
      champ:SetText(("|cffaaaaaaFinish %d more to become |r|cffffd100Weekly Champion|r"):format(left))
    end
    local champs = FriendNames(ns.Challenges.FriendsDone(week.key, "champion"))
    if champs then champ:SetText(champ:GetText() .. "   |cff888888Champions:|r " .. champs) end

    local last = ns.Challenges.WeekPeriod(week.startTs - 3 * 86400)
    local lastSteps = ns.Challenges.Gather(last).steps
    local w, m, c = ns.Challenges.Counts()
    footer:SetText(("Last week: %s steps, %d/3 challenges.     Lifetime: %d weekly, %d monthly, Weekly Champion x%d")
      :format(F.Number(lastSteps), ns.Challenges.WeekChallengesDone(last.key), w, m, c))
  end
end
