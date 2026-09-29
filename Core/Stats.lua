local _, ns = ...

-- Account-wide history (UGotTimeStats is SavedVariables, shared by all characters)
local MAX_LOG_ENTRIES = 1000

local function GetDB()
	UGotTimeStats = UGotTimeStats or {}
	local db = UGotTimeStats
	db.done = db.done or 0
	db.rejected = db.rejected or 0
	db.bySource = db.bySource or {}
	db.reps = db.reps or {} -- exercise key -> total reps ever
	db.log = db.log or {}
	if not db.times then
		-- exercise key -> number of popups it was done in; backfilled from the log the first time
		db.times = {}
		for _, entry in ipairs(db.log) do
			for key in pairs(entry.reps or {}) do
				db.times[key] = (db.times[key] or 0) + 1
			end
		end
	end
	return db
end

local function Bump(tbl, key, result)
	tbl[key] = tbl[key] or { done = 0, rejected = 0 }
	tbl[key][result] = tbl[key][result] + 1
end

-- source is "flight", "quest" or "manual"; reps is exercise key -> count.
-- A popup with no reps at all (Skip, or Save with everything at 0) counts as rejected.
function ns.RecordWorkout(source, reps)
	local db = GetDB()
	local levelBefore = ns.GetLevelInfo()
	local entry = {}
	local total = 0
	for key, count in pairs(reps) do
		if count > 0 then
			entry[key] = count
			db.reps[key] = (db.reps[key] or 0) + count
			db.times[key] = (db.times[key] or 0) + 1
			total = total + count
		end
	end

	local result = total > 0 and "done" or "rejected"
	db[result] = db[result] + 1
	Bump(db.bySource, source, result)

	tinsert(db.log, {
		time = time(),
		character = UnitName("player") .. "-" .. GetRealmName(),
		source = source,
		result = result,
		reps = entry,
	})
	while #db.log > MAX_LOG_ENTRIES do
		tremove(db.log, 1)
	end

	ns.UpdateXPBar()
	ns.RefreshStatsTab()
	ns.RefreshGraphTab()

	-- Only workouts announce level ups, not XP edits in the Options tab
	local levelAfter = ns.GetLevelInfo()
	if levelAfter > levelBefore then
		ns.AnnounceLevelUp(levelAfter)
	end
end

function ns.GetTotalReps()
	local total = 0
	for _, count in pairs(GetDB().reps) do
		total = total + count
	end
	return total
end

-- Wipes all stats (and with them the XP, which comes from the reps).
-- Workouts, settings and the quest counter are kept.
function ns.ResetStats()
	UGotTimeStats = nil
	ns.UpdateXPBar()
	ns.RefreshStatsTab()
	ns.RefreshGraphTab()
	print("U Got Time: stats reset.")
end

-- Raw stats table for the Stats tab
ns.GetStats = GetDB
