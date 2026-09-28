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
