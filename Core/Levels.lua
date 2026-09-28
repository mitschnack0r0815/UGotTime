local _, ns = ...

-- Workout XP and levels. XP comes from the total reps in the stats times each movement's
-- XP per rep, so it's never stored itself (changing a movement's XP also changes past XP).
function ns.GetXP()
	local xp = 0
	for key, count in pairs(ns.GetStats().reps) do
		xp = xp + count * ns.GetExerciseXP(key)
	end
	return xp
end

-- XP needed to get from level to level + 1: 100, 200, ... up to the cap
local function XPToNext(level)
	return math.min(level * ns.XP_LEVEL_STEP, ns.XP_LEVEL_CAP)
end

-- Returns level, XP into that level, XP needed for the next one
local function GetLevel(xp)
	local level = 1
	while xp >= XPToNext(level) do
		xp = xp - XPToNext(level)
		level = level + 1
	end
	return level, xp, XPToNext(level)
end

-- Current level, XP into it and XP needed for the next one (used by the minimap tooltip)
function ns.GetLevelInfo()
	return GetLevel(ns.GetXP())
end
