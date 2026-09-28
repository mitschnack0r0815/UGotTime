local _, ns = ...

-- Built-in movements. key is saved (don't change it), name is shown everywhere.
-- Workouts added in game are stored in UGotTimeSettings.custom.
local DEFAULT_EXERCISES = {
	{ key = "pushups",  name = "Push-ups" },
	{ key = "squats",   name = "Squats" },
	{ key = "pullups",  name = "Pull-ups" },
	{ key = "plank",    name = "Plank" },
	{ key = "lunges",   name = "Lunges" },
	{ key = "calves",   name = "Calf raises" },
	{ key = "wallsit",  name = "Wall sit" },
	{ key = "glutes",   name = "Glute squeeze" },
	{ key = "posture",  name = "Posture check" },
	{ key = "hips",     name = "Hip stretch" },
	{ key = "water",    name = "Drink water" },
}

-- Every movement ever known, including deleted ones (stats still need their names)
function ns.GetAllExercises()
	local list = {}
	for _, ex in ipairs(DEFAULT_EXERCISES) do
		tinsert(list, ex)
	end
	for _, ex in ipairs(ns.GetSettings().custom) do
		tinsert(list, ex)
	end
	return list
end

-- Movements that haven't been deleted (shown in the Movements tab)
function ns.GetExercises()
	local list = {}
	local deleted = ns.GetSettings().deleted
	for _, ex in ipairs(ns.GetAllExercises()) do
		if not deleted[ex.key] then
			tinsert(list, ex)
		end
	end
	return list
end

-- Movements the popup can pick
function ns.GetEnabledExercises()
	local list = {}
	for _, ex in ipairs(ns.GetExercises()) do
		if ns.IsExerciseEnabled(ex.key) then
			tinsert(list, ex)
		end
	end
	return list
end

function ns.IsExerciseEnabled(key)
	return not ns.GetSettings().disabled[key]
end

function ns.SetExerciseEnabled(key, enabled)
	ns.GetSettings().disabled[key] = (not enabled) or nil
end

-- XP per rep for a movement (ns.XP_PER_REP unless changed in the Movements tab)
function ns.GetExerciseXP(key)
	return ns.GetSettings().xp[key] or ns.XP_PER_REP
end

function ns.SetExerciseXP(key, xp)
	ns.GetSettings().xp[key] = (xp ~= ns.XP_PER_REP) and xp or nil
end

-- Returns the new movement, or nil and a reason
function ns.AddExercise(name)
	name = strtrim(name or "")
	if name == "" then
		return nil, "enter a name"
	end
	for _, ex in ipairs(ns.GetExercises()) do
		if ex.name:lower() == name:lower() then
			return nil, name .. " already exists"
		end
	end
	local s = ns.GetSettings()
	s.nextCustom = s.nextCustom + 1
	local ex = {
		key = "custom" .. s.nextCustom, -- never reused, so stats of deleted workouts stay separate
		name = name,
	}
	tinsert(s.custom, ex)
	return ex
end

-- Deleted movements are only hidden, so their stats keep a name
function ns.DeleteExercise(key)
	ns.GetSettings().deleted[key] = true
end

-- Brings back deleted built-in movements (custom ones stay deleted)
function ns.RestoreDefaultExercises()
	local deleted = ns.GetSettings().deleted
	for _, ex in ipairs(DEFAULT_EXERCISES) do
		deleted[ex.key] = nil
	end
end
