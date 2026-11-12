local _, ns = ...
local L = ns.L

-- Clickable chat links for challenges, trophies, ranks and players, like
-- item links: clicking one opens it in the window, where it flashes.
--   |Haws:c:<challengeId>|h[Long Haul]|h      challenge
--   |Haws:a:<achievementId>|h[Marathon]|h     trophy
--   |Haws:r:<rank>|h[Footpad]|h               walker rank
--   |Haws:w:champion|h[Weekly Champion]|h     weekly champion
--   |Haws:p:<guid>|h<name>|h                  player (opens their profile)

-- label is shown as-is (it may carry its own color codes)
function ns.Link(kind, id, label)
  return ("|Haws:%s:%s|h%s|h"):format(kind, tostring(id), label)
end

function ns.ChallengeLink(ch)
  return ns.Link("c", ch.id, "[" .. L[ch.name] .. "]")
end

function ns.AchievementLink(a)
  return ns.Link("a", a.id, "[" .. L[a.name] .. "]")
end

function ns.PlayerLink(guid)
  return ns.Link("p", guid, ns.Social.ColoredName(guid))
end

local function Open(kind, id)
  if not ns.cdb then return end
  if kind == "c" then ns.ShowUnlocked({ tab = ns.CHALLENGES_TAB, ch = id })
  elseif kind == "a" then ns.ShowUnlocked({ tab = ns.TROPHIES_TAB, ach = id })
  elseif kind == "r" then ns.ShowUnlocked({ tab = ns.TROPHIES_TAB, rank = true })
  elseif kind == "w" then ns.ShowUnlocked({ tab = ns.CHALLENGES_TAB, champion = true })
  elseif kind == "p" then ns.ShowUnlocked({ profile = id }) end
end

-- The chat frame hands every clicked link to SetItemRef. Ours are handled
-- here and never reach the default code (which doesn't know them).
local origSetItemRef = SetItemRef
if origSetItemRef then
  SetItemRef = function(link, text, button, chatFrame, ...)
    local kind, id = (link or ""):match("^aws:(%a):(.+)$")
    if kind then
      Open(kind, id)
      return
    end
    return origSetItemRef(link, text, button, chatFrame, ...)
  end
end
