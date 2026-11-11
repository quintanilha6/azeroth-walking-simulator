local _, ns = ...
local L = ns.L
local F = ns.F

-- "Quick Share": a small menu to post your progress straight to Say, Party,
-- Raid or Guild chat.
local Q = {}
ns.QuickShare = Q

local TAG = "[Azeroth Walking Simulator]"

local function RankName() return ns.Achievements.RankName(ns.Achievements.MyRank()) end

-- What to share: the running session, else the last activity, else today
function Q.DefaultText()
  local s = ns.cdb.current
  if s and s.steps >= 1 then
    return (L["%s Out walking: %s steps, %s in %s. Rank: %s"]):format(TAG, F.Number(s.steps), F.Distance(s.distance),
      F.Time(s.moving), RankName())
  end
  if ns.cdb.history[1] then return Q.ActivityText(ns.cdb.history[1]) end
  local day = ns.GetDay(date("%Y-%m-%d"))
  return (L["%s Today: %s steps, %s. Rank: %s"]):format(TAG, F.Number(day.s), F.Distance(day.d), RankName())
end

function Q.ActivityText(a)
  local zone = a.zones and a.zones[1]
  return (L["%s Just walked %s steps, %s in %s (pace %s)%s. Rank: %s"]):format(TAG, F.Number(a.steps),
    F.Distance(a.distance), F.Time(a.moving), F.Pace(a.moving, a.distance), zone and (L[" around "] .. zone) or "",
    RankName())
end

-- Shorten to at most maxBytes without cutting a letter in half (accented
-- letters take 2-3 bytes in UTF-8, and a broken one makes chat reject the line)
function Q.Cut(s, maxBytes)
  if #s <= maxBytes then return s end
  local i = maxBytes + 1
  while i > 1 do
    local b = s:byte(i)
    if b < 0x80 or b >= 0xC0 then break end -- start of a letter
    i = i - 1
  end
  return s:sub(1, i - 1)
end

local CHANNELS = {
  { "SAY", "Say", function() return true end },
  { "PARTY", "Party", function() return IsInGroup() end },
  { "RAID", "Raid", function() return IsInRaid() end },
  { "GUILD", "Guild", function() return IsInGuild() end },
}

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------
local menu = CreateFrame("Frame", "AWSQuickShareMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate")
menu:SetSize(220, 60)
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:SetClampedToScreen(true)
menu:EnableMouse(true)
menu:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
menu:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
menu:SetBackdropBorderColor(0.99, 0.30, 0.01, 0.9)
menu:Hide()
tinsert(UISpecialFrames, "AWSQuickShareMenu") -- Escape closes it

local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", 10, -9)
title:SetTextColor(0.99, 0.30, 0.01)

local preview = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
preview:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
preview:SetWidth(200)
preview:SetJustifyH("LEFT")
preview:SetTextColor(0.75, 0.75, 0.75)

local buttons = {}
for i, ch in ipairs(CHANNELS) do
  local b = CreateFrame("Button", nil, menu)
  b:SetSize(200, 18)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetTexture("Interface\\Buttons\\WHITE8X8")
  hl:SetVertexColor(1, 1, 1, 0.12)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.text:SetPoint("LEFT", 6, 0)
  b:SetScript("OnClick", function()
    SendChatMessage(menu.text, ch[1])
    menu:Hide()
  end)
  b.ch = ch
  buttons[i] = b
end

-- Close when the mouse has been away for a moment
local away = 0
menu:SetScript("OnUpdate", function(self, el)
  if self:IsMouseOver() or (self.anchor and self.anchor:IsMouseOver()) then away = 0 return end
  away = away + el
  if away > 2 then self:Hide() end
end)

-- anchor: the button that opened it. text: optional (defaults to Q.DefaultText)
function Q.Open(anchor, text)
  if menu:IsShown() and menu.anchor == anchor then menu:Hide() return end
  title:SetText(L["QUICK SHARE"])
  menu.anchor, menu.text = anchor, Q.Cut(text or Q.DefaultText(), 255)
  preview:SetText((menu.text:gsub("^%[Azeroth Walking Simulator%] ", "")))
  local y = -(20 + preview:GetStringHeight() + 6)
  for _, b in ipairs(buttons) do
    local ok = b.ch[3]()
    b:SetEnabled(ok)
    b.text:SetText(ok and L[b.ch[2]] or ("|cff666666" .. L[b.ch[2]] .. "|r"))
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 10, y)
    y = y - 18
  end
  menu:SetHeight(-y + 10)
  menu:ClearAllPoints()
  local _, ay = anchor:GetCenter()
  if ay and ay > UIParent:GetHeight() / 2 then
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  else
    menu:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
  end
  away = 0
  menu:Show()
end
