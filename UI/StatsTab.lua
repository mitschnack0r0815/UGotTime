local _, ns = ...

-- Stats tab (/ugt stats)
local ROW_HEIGHT = 18
local TABLE_TOP = -146 -- y offset of the exercise table header

local panel, tabIndex = ns.AddTab("Stats")

local function Text(font, x, y, justify, width)
	local fs = panel:CreateFontString(nil, "OVERLAY", font)
	fs:SetPoint("TOPLEFT", x, y)
	if width then
		fs:SetWidth(width)
	end
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

local prompted = Text("GameFontNormalLarge", 16, -34)
local summary = Text("GameFontHighlight", 16, -58)
local flights = Text("GameFontHighlight", 16, -78)
local quests = Text("GameFontHighlight", 16, -96)
local manual = Text("GameFontHighlight", 16, -114)

-- Exercise table: name | times done | total reps
local COL_TIMES, COL_REPS = 170, 240
Text("GameFontNormal", 16, TABLE_TOP):SetText("Exercise")
Text("GameFontNormal", COL_TIMES, TABLE_TOP, "RIGHT", 60):SetText("Times")
Text("GameFontNormal", COL_REPS, TABLE_TOP, "RIGHT", 60):SetText("Reps")
local empty = Text("GameFontDisable", 16, TABLE_TOP - ROW_HEIGHT - 4)
empty:SetText("No workouts yet.")

-- "Recent workouts" section below the table, moved below the last table row on every refresh
local RECENT_COUNT = 10
local RECENT_GAP = 14
local SOURCE_NAMES = { flight = "Flight", quest = "Quest", manual = "Manual" }

local recent = CreateFrame("Frame", nil, panel)
local recentTitle = recent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
recentTitle:SetPoint("TOPLEFT", 16, 0)
recentTitle:SetText("Recent workouts")

local recentLines = {}
for i = 1, RECENT_COUNT do
	local y = -i * ROW_HEIGHT - 4
	local when = recent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	when:SetPoint("TOPLEFT", 16, y)
	when:SetWidth(76)
	when:SetJustifyH("LEFT")
	local what = recent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	what:SetPoint("TOPLEFT", 94, y)
	what:SetPoint("RIGHT", recent, "RIGHT", -16, 0)
	what:SetJustifyH("LEFT")
	what:SetWordWrap(false) -- long lines get cut off with "..."
	recentLines[i] = { when = when, what = what }
end

-- "Flight: 20 push-ups, 15 squats" / "Quest: skipped"
local function DescribeEntry(entry, names)
	local parts = {}
	if entry.result == "rejected" then
		parts[1] = "|cffff4040skipped|r"
	elseif entry.reps and next(entry.reps) then
		for key, count in pairs(entry.reps) do
			tinsert(parts, count .. " " .. (names[key] or key):lower())
		end
		table.sort(parts)
	else
		parts[1] = "done" -- entries from before reps were recorded
	end
	return (SOURCE_NAMES[entry.source] or entry.source or "?") .. ": " .. table.concat(parts, ", ")
end

-- Fills the section and returns its height
local function RefreshRecent(log)
	local names = {}
	for _, ex in ipairs(ns.GetAllExercises()) do
		names[ex.key] = ex.name
	end

	local shown = 0
	for i = #log, math.max(1, #log - RECENT_COUNT + 1), -1 do
		shown = shown + 1
		local entry, line = log[i], recentLines[shown]
		line.when:SetText(date("%d.%m. %H:%M", entry.time))
		line.what:SetText(DescribeEntry(entry, names))
	end
	for i = 1, RECENT_COUNT do
		recentLines[i].when:SetShown(i <= shown)
		recentLines[i].what:SetShown(i <= shown)
	end
	if shown == 0 then
		recentLines[1].what:SetText("|cff808080Nothing yet.|r")
		recentLines[1].what:Show()
	end
	return (math.max(shown, 1) + 1) * ROW_HEIGHT
end

-- XP bar at the bottom, below the recent workouts
local XP_BAR_GAP = 16
local xpBar = ns.CreateXPBar(panel)

local rows = {}

local function GetRow(i)
	if not rows[i] then
		local y = TABLE_TOP - i * ROW_HEIGHT - 4
		rows[i] = {
			name = Text("GameFontHighlight", 16, y),
			times = Text("GameFontHighlight", COL_TIMES, y, "RIGHT", 60),
			reps = Text("GameFontHighlight", COL_REPS, y, "RIGHT", 60),
		}
	end
	return rows[i]
end

local function SourceLine(label, s)
	s = s or { done = 0, rejected = 0 }
	return ("%s: %d prompts, |cff00ff00%d done|r, |cffff4040%d skipped|r"):format(label, s.done + s.rejected, s.done, s.rejected)
end

local function Refresh()
	local db = ns.GetStats()
	local total = db.done + db.rejected
	local rate = total > 0 and math.floor(db.done / total * 100) or 0
	prompted:SetText(("Prompted %d times"):format(total))
	summary:SetText(("|cff00ff00%d done|r, |cffff4040%d skipped|r (%d%% completion)"):format(db.done, db.rejected, rate))
	flights:SetText(SourceLine("Flights", db.bySource.flight))
	quests:SetText(SourceLine("Quests", db.bySource.quest))
	manual:SetText(SourceLine("Manual", db.bySource.manual))

	local n = 0
	for _, ex in ipairs(ns.GetAllExercises()) do
		if db.times[ex.key] then
			n = n + 1
			local row = GetRow(n)
			row.name:SetText(ex.name)
			row.times:SetText(db.times[ex.key])
			row.reps:SetText(db.reps[ex.key] or 0)
			for _, fs in pairs(row) do
				fs:Show()
			end
		end
	end
	for i = n + 1, #rows do
		for _, fs in pairs(rows[i]) do
			fs:Hide()
		end
	end
	empty:SetShown(n == 0)

	local y = TABLE_TOP - (math.max(n, 1) + 1) * ROW_HEIGHT - RECENT_GAP
	local recentHeight = RefreshRecent(db.log)
	recent:ClearAllPoints()
	recent:SetPoint("TOPLEFT", 0, y)
	recent:SetPoint("RIGHT", panel, "RIGHT")
	recent:SetHeight(recentHeight)

	y = y - recentHeight - XP_BAR_GAP
	xpBar:ClearAllPoints()
	xpBar:SetPoint("TOPLEFT", 16, y)
	xpBar:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
	ns.UpdateXPBar()

	ns.SetWindowHeight(-y + xpBar:GetHeight() + 16)
end

panel:SetScript("OnShow", Refresh)

-- Called after the stats change from outside the tab (e.g. reset from the minimap menu)
function ns.RefreshStatsTab()
	if panel:IsVisible() then
		Refresh()
	end
end

function ns.ToggleStats()
	ns.ToggleTab(tabIndex)
end
