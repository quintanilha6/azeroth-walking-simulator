local _, ns = ...
local F = ns.F

-- Round minimap button (no libraries). Drag it around the minimap edge.
-- Left-click: main window. Right-click: route card. Shift-click: options.
local M = {}
ns.MinimapButton = M

local function Place(b)
  local angle = math.rad(ns.settings.minimapAngle or 200)
  local radius = (Minimap:GetWidth() / 2) + 5
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function DragUpdate(b)
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  px, py = px / scale, py / scale
  ns.settings.minimapAngle = math.deg(math.atan2(py - my, px - mx)) % 360
  Place(b)
end

local function ShowTooltip(b)
  GameTooltip:SetOwner(b, "ANCHOR_LEFT")
  GameTooltip:AddLine("Azeroth Walking Simulator", ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3])
  local today = ns.GetDay(date("%Y-%m-%d"))
  GameTooltip:AddDoubleLine("Today", F.Number(today.s) .. " steps", 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine("Rank", ns.Achievements.RankColored(ns.Achievements.MyRank()), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Click: open    Right-click: route    Shift-click: options", 0.5, 0.5, 0.5)
  GameTooltip:AddLine("Drag to move", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

function M.Create()
  if M.button or not Minimap then return end
  local b = CreateFrame("Button", "AWSMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon:SetPoint("TOPLEFT", 7, -6)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  b:SetScript("OnClick", function(_, button)
    if IsShiftKeyDown() then
      ns.Options.Open()
    elseif button == "RightButton" then
      local cur = ns.cdb.current
      ns.RouteViewer.Open(ns.Routes.Has(cur) and cur or ns.cdb.history[1])
    else
      ns.ToggleWindow()
    end
  end)
  b:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", DragUpdate)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", ShowTooltip)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  M.button = b
  M.Apply()
end

function M.Apply()
  local b = M.button
  if not b then return end
  Place(b)
  b:SetShown(ns.settings.minimapShown)
end
