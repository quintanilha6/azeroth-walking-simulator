local _, ns = ...
local L = ns.L

-- Big center banner for your own wins, small top toast for friends/overtakes.
local B = {}
ns.Banner = B

local SOUND_BIG = 888     -- level-up fanfare
local SOUND_TOAST = 3081  -- whisper "tell" sound

local function MakeFrame(name, w, h, iconSize)
  local f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate")
  f:SetSize(w, h)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
  f:Hide()

  f.stripe = f:CreateTexture(nil, "ARTWORK")
  f.stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
  f.stripe:SetPoint("TOPLEFT", 5, -5)
  f.stripe:SetPoint("BOTTOMLEFT", 5, 5)
  f.stripe:SetWidth(4)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(iconSize, iconSize)
  f.icon:SetPoint("LEFT", 16, 0)
  f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  return f
end

-- fade in 0.3s, hold, fade out 0.6s
local function Play(f, hold, onDone)
  f.t, f.hold = 0, hold
  f:SetAlpha(0)
  f:Show()
  f:SetScript("OnUpdate", function(self, el)
    self.t = self.t + el
    local t, hd = self.t, self.hold
    if t < 0.3 then
      self:SetAlpha(t / 0.3)
    elseif t < 0.3 + hd then
      self:SetAlpha(1)
    elseif t < 0.9 + hd then
      self:SetAlpha(1 - (t - 0.3 - hd) / 0.6)
    else
      self:SetScript("OnUpdate", nil)
      self:Hide()
      onDone()
    end
  end)
end

local function SkipToFade(self)
  if self.t and self.t < 0.3 + self.hold then self.t = 0.3 + self.hold end
end

---------------------------------------------------------------------------
-- Big banner
---------------------------------------------------------------------------
local big = MakeFrame("AWSBanner", 460, 96, 60)
big:SetPoint("TOP", UIParent, "TOP", 0, -170)
big:EnableMouse(true)
big:SetScript("OnMouseUp", SkipToFade)

big.kicker = big:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
big.kicker:SetPoint("TOPLEFT", big.icon, "TOPRIGHT", 14, -2)
big.title = big:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
big.title:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
big.title:SetPoint("TOPLEFT", big.kicker, "BOTTOMLEFT", 0, -4)
big.sub = big:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
big.sub:SetPoint("TOPLEFT", big.title, "BOTTOMLEFT", 0, -5)
big.sub:SetWidth(360)
big.sub:SetJustifyH("LEFT")
big.sub:SetTextColor(0.8, 0.8, 0.8)

local bigQueue, bigBusy = {}, false
local function NextBig()
  local o = table.remove(bigQueue, 1)
  if not o then bigBusy = false; return end
  bigBusy = true
  local col = o.color or ns.GOLD
  big:SetBackdropBorderColor(col[1], col[2], col[3], 1)
  big.stripe:SetVertexColor(col[1], col[2], col[3], 1)
  big.kicker:SetTextColor(col[1], col[2], col[3])
  big.kicker:SetText(o.kicker or "")
  big.title:SetText(o.title or "")
  big.sub:SetText(o.sub or "")
  big.icon:SetTexture(o.icon or "Interface\\Icons\\Ability_Rogue_Sprint")
  ns.PlaySound(SOUND_BIG)
  Play(big, 4, NextBig)
end

function B.Show(o)
  if not ns.settings or not ns.settings.banners then return end
  table.insert(bigQueue, o)
  if not bigBusy then NextBig() end
end

---------------------------------------------------------------------------
-- Small toast
---------------------------------------------------------------------------
local toast = MakeFrame("AWSToast", 340, 50, 32)
toast:SetPoint("TOP", UIParent, "TOP", 0, -100)
toast:EnableMouse(true)
toast:SetScript("OnMouseUp", SkipToFade)
toast:SetBackdropBorderColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 0.9)
toast.stripe:SetVertexColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 1)
toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, 0)
toast.title:SetTextColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3])
toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -3)
toast.text:SetWidth(270)
toast.text:SetJustifyH("LEFT")
toast.text:SetWordWrap(false)

local toastQueue, toastBusy = {}, false
local function NextToast()
  local o = table.remove(toastQueue, 1)
  if not o then toastBusy = false; return end
  toastBusy = true
  toast.title:SetText(o.title or "")
  toast.text:SetText(o.text or "")
  toast.icon:SetTexture(o.icon or "Interface\\Icons\\Ability_Rogue_Sprint")
  ns.PlaySound(SOUND_TOAST)
  Play(toast, 3, NextToast)
end

function B.Toast(o)
  if not ns.settings or not ns.settings.banners then return end
  if #toastQueue >= 5 then return end -- don't pile up
  table.insert(toastQueue, o)
  if not toastBusy then NextToast() end
end

function B.Test()
  B.Show({ kicker = L["WEEKLY CHALLENGE COMPLETE"], title = L["Centurion"], sub = L["Gold  -  Walk 100,000 steps this week"],
    icon = ns.Challenges.TIERS.gold.icon, color = ns.Challenges.TIERS.gold.color })
  B.Toast({ title = L["Friend activity"], text = L["Bob completed the Silver challenge Road Warrior!"],
    icon = ns.Challenges.TIERS.silver.icon })
  if not ns.settings.banners then ns.Print(L["Banners are turned off in Settings."]) end
end
