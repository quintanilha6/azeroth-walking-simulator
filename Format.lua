local _, ns = ...

local F = {}
ns.F = F

local floor, format = math.floor, string.format
local YARD_TO_M = 0.9144

-- 1234567 -> "1,234,567"
function F.Number(n)
  local s = tostring(floor((n or 0) + 0.5))
  local left, num = s:match("^(%-?)(%d+)$")
  if not num then return s end
  num = num:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  return left .. num
end

-- Length of one display unit (km or mile) in yards
local function UnitYards()
  if ns.settings and ns.settings.units == "mi" then return 1760 end
  return 1000 / YARD_TO_M
end

function F.UnitName()
  return (ns.settings and ns.settings.units == "mi") and "mi" or "km"
end

function F.Distance(yards)
  return format("%.2f %s", (yards or 0) / UnitYards(), F.UnitName())
end

function F.Time(sec)
  sec = floor(sec or 0)
  local h, m, s = floor(sec / 3600), floor(sec % 3600 / 60), sec % 60
  if h > 0 then return format("%d:%02d:%02d", h, m, s) end
  return format("%d:%02d", m, s)
end

-- Average pace, e.g. "5:12 /km"
function F.Pace(movingSec, yards)
  if not yards or yards < 20 or not movingSec or movingSec <= 0 then return "--" end
  local units = yards / UnitYards()
  return F.Time(movingSec / units) .. " /" .. F.UnitName()
end

-- "3d 4h", "5h 12m", "8m"
function F.Countdown(sec)
  sec = math.max(0, floor(sec or 0))
  local d, h, m = floor(sec / 86400), floor(sec % 86400 / 3600), floor(sec % 3600 / 60)
  if d > 0 then return format("%dd %dh", d, h) end
  if h > 0 then return format("%dh %dm", h, m) end
  return format("%dm", m)
end

function F.Date(ts) return ts and date("%Y-%m-%d %H:%M", ts) or "?" end
function F.Day(ts) return ts and date("%Y-%m-%d", ts) or "?" end
