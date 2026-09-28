local _, ns = ...

-- Account-wide settings (UGotTimeSettings is SavedVariables). Only disabled/deleted movements
-- are stored, so built-in movements added later start out enabled.
function ns.GetSettings()
	UGotTimeSettings = UGotTimeSettings or {}
	local s = UGotTimeSettings
	s.disabled = s.disabled or {}
	s.deleted = s.deleted or {}
	s.custom = s.custom or {}
	s.nextCustom = s.nextCustom or 0
	s.xp = s.xp or {} -- exercise key -> XP per rep, only when changed from the default
	return s
end

-- Quest turn-ins per workout popup; stored only when changed from ns.QUESTS_PER_WORKOUT
function ns.GetQuestsPerWorkout()
	return ns.GetSettings().questsPerWorkout or ns.QUESTS_PER_WORKOUT
end

function ns.SetQuestsPerWorkout(count)
	count = math.max(ns.MIN_QUESTS_PER_WORKOUT, math.min(ns.MAX_QUESTS_PER_WORKOUT, math.floor(count)))
	ns.GetSettings().questsPerWorkout = count ~= ns.QUESTS_PER_WORKOUT and count or nil
	return count
end
