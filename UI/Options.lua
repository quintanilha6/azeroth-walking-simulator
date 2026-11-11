local _, ns = ...
local L = ns.L

-- Entry in the game's Options -> AddOns list, showing the same settings as
-- the Settings tab of the main window.
local O = {}
ns.Options = O

local TITLE = "Azeroth Walking Simulator"

function O.Create()
  if O.panel then return end
  local panel = CreateFrame("Frame")
  panel.name = TITLE

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(TITLE)
  title:SetTextColor(unpack(ns.ORANGE))

  local open = ns.SmallButton(panel, L["Open main window"], 160, function()
    if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() and HideUIPanel then HideUIPanel(InterfaceOptionsFrame) end
    ns.ToggleWindow(1)
  end)
  open:SetPoint("TOPRIGHT", -16, -14)

  local page = CreateFrame("Frame", nil, panel)
  page:SetPoint("TOPLEFT", 16, -52)
  page:SetPoint("BOTTOMRIGHT", -16, 10)
  ns.BuildSettingsPage(page)
  panel:SetScript("OnShow", function() page:Refresh() end)
  O.page = page

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
    O.category = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
  O.panel = panel
end

function O.Open()
  if InCombatLockdown() then return ns.Print(L["Options can't be opened in combat."]) end
  if not O.panel then O.Create() end
  if O.category and Settings and Settings.OpenToCategory then
    local id = O.category.GetID and O.category:GetID() or O.category.ID
    Settings.OpenToCategory(id)
  elseif InterfaceOptionsFrame_OpenToCategory then
    -- called twice: the old options frame needs it the first time it opens
    InterfaceOptionsFrame_OpenToCategory(O.panel)
    InterfaceOptionsFrame_OpenToCategory(O.panel)
  end
end
