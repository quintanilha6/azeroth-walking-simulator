local _, ns = ...
local L = ns.L

-- Clickable chat links for challenges, trophies, ranks and players, like
-- item links: clicking one opens it in the window, where it flashes.
--   |Hgarrmission:aws:c:<challengeId>|h[Long Haul]|h   challenge
--   |Hgarrmission:aws:a:<achievementId>|h[Marathon]|h  trophy
--   |Hgarrmission:aws:r:<rank>|h[Footpad]|h            walker rank
--   |Hgarrmission:aws:w:champion|h[Weekly Champion]|h  weekly champion
--   |Hgarrmission:aws:p:<guid>|h<name>|h               player (opens their profile)
-- "garrmission" is a link type the game already accepts and ignores in
-- Classic, so the default click code leaves it alone; we only hook
-- SetItemRef (no globals replaced), the same way WeakAuras does.

-- label is shown as-is (it may carry its own color codes).
-- from: optional GUID of the friend it's about ("...:c:<id>:<guid>"); the
-- window then offers kudos next to the item.
function ns.Link(kind, id, label, from)
  local ref = tostring(id) .. (from and (":" .. from) or "")
  return ("|Hgarrmission:aws:%s:%s|h%s|h"):format(kind, ref, label)
end

function ns.ChallengeLink(ch, from)
  return ns.Link("c", ch.id, "[" .. L[ch.name] .. "]", from)
end

function ns.AchievementLink(a, from)
  return ns.Link("a", a.id, "[" .. L[a.name] .. "]", from)
end

function ns.PlayerLink(guid)
  return ns.Link("p", guid, ns.Social.ColoredName(guid))
end

local function Open(kind, id, from)
  if not ns.cdb then return end
  if kind == "p" then return ns.ShowUnlocked({ profile = id }) end
  local o
  if kind == "c" then o = { tab = ns.CHALLENGES_TAB, ch = id }
  elseif kind == "a" then o = { tab = ns.TROPHIES_TAB, ach = id }
  elseif kind == "r" then o = { tab = ns.TROPHIES_TAB, rank = true }
  elseif kind == "w" then o = { tab = ns.CHALLENGES_TAB, champion = true } end
  if not o then return end
  -- a friend's news: offer kudos next to it
  o.kudos = from and ns.Social.FindEvent(from, kind, id)
  ns.ShowUnlocked(o)
end

-- The chat frame hands every clicked link to SetItemRef; we look at ours
-- after the game is done with it
if SetItemRef then
  hooksecurefunc("SetItemRef", function(link)
    local kind, ref = (link or ""):match("^garrmission:aws:(%a):(.+)$")
    if not kind then return end
    local id, from = ref, nil
    if kind ~= "p" then id, from = ref:match("^([^:]+):?(.*)$") end
    Open(kind, id, from ~= "" and from or nil)
  end)
end
