local _, ns = ...
local Book = ns.Book

-- Stats tab (/ugt stats). Left page: level, XP, prompts per trigger and the latest workouts.
-- Right page: reps per exercise.
local ROW_HEIGHT = 20
local CONTENT_X = Book.PAGE_MARGIN + 12 -- left edge of page content, lined up with the headers
local COL_WIDTH = 70 -- width of each number column
local RECENT_COUNT = 5
local SOURCE_NAMES = { flight = "Flight", quest = "Quest", manual = "Manual" }

local panel, tabIndex = ns.AddTab("Stats")
local left, right = panel.left, panel.right

local function Text(page, font, y, x)
	local text = Book.CreateText(page, font or Book.SMALL_FONT)
	text:SetPoint("TOPLEFT", x or CONTENT_X, y)
	return text
end

-- Right-aligned number column; col 1 is the rightmost
local function Number(page, font, y, col)
	local text = Book.CreateText(page, font or Book.SMALL_FONT)
	text:SetWidth(COL_WIDTH)
	text:SetJustifyH("RIGHT")
	text:SetPoint("TOPRIGHT", -Book.PAGE_MARGIN - (col - 1) * COL_WIDTH, y)
	return text
end

local function SubHeader(page, text, y)
	local header = Book.CreateSubHeader(page, text)
	header:SetPoint("TOPLEFT", CONTENT_X, y)
	header:SetPoint("RIGHT", -Book.PAGE_MARGIN, 0)
	return header
end

-- Faint stripe behind every other table row
local function Stripe(page, y)
	local stripe = page:CreateTexture(nil, "BACKGROUND", nil, 3)
	stripe:SetPoint("TOPLEFT", CONTENT_X - 6, y + 3)
	stripe:SetPoint("RIGHT", -Book.PAGE_MARGIN + 6, 0)
	stripe:SetHeight(ROW_HEIGHT)
	stripe:SetColorTexture(Book.FONT_COLOR.r, Book.FONT_COLOR.g, Book.FONT_COLOR.b, 0.07)
	return stripe
end

---------------------------------------------------------------------------
-- Left page
---------------------------------------------------------------------------

local levelHeader = Book.CreateHeader(left)

local xpBar = ns.CreateXPBar(left, nil, 10)
xpBar.alwaysShowText = true
xpBar:SetPoint("TOPLEFT", CONTENT_X, -100)
xpBar:SetPoint("RIGHT", -Book.PAGE_MARGIN, 0)

local totals = Text(left, nil, -128)

SubHeader(left, "Prompts", -156)
local summary = Text(left, nil, -192)

-- Per trigger: name | done | skipped
local SOURCE_ROWS = { { "flight", "Flights" }, { "quest", "Quests" }, { "manual", "Manual" } }
local SOURCE_TOP = -216
Number(left, Book.SMALL_FONT, SOURCE_TOP, 2):SetText("Done")
Number(left, Book.SMALL_FONT, SOURCE_TOP, 1):SetText("Skipped")
local sourceRows = {}
for i, source in ipairs(SOURCE_ROWS) do
	local y = SOURCE_TOP - i * ROW_HEIGHT
	if i % 2 == 1 then
		Stripe(left, y)
	end
	Text(left, Book.TEXT_FONT, y):SetText(source[2])
	sourceRows[source[1]] = {
		done = Number(left, Book.TEXT_FONT, y, 2),
		skipped = Number(left, Book.TEXT_FONT, y, 1),
	}
end

local RECENT_TOP = SOURCE_TOP - #SOURCE_ROWS * ROW_HEIGHT - 26
SubHeader(left, "Recent workouts", RECENT_TOP)
local recentLines = {}
for i = 1, RECENT_COUNT do
	local y = RECENT_TOP - 16 - i * ROW_HEIGHT
	local when = Text(left, Book.SMALL_FONT, y)
	when:SetAlpha(0.7)
	local what = Text(left, Book.TEXT_FONT, y, CONTENT_X + 90)
	what:SetPoint("RIGHT", -Book.PAGE_MARGIN, 0)
	what:SetWordWrap(false) -- long lines get cut off with "..."
	recentLines[i] = { when = when, what = what }
end

-- "Flight: 20 push-ups, 15 squats" / "Quest: skipped"
local function DescribeEntry(entry, names)
	local parts = {}
	if entry.result == "rejected" then
		parts[1] = Book.BAD .. "skipped|r"
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

local function RefreshRecent(log, names)
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
		recentLines[1].when:SetText("Nothing yet.")
		recentLines[1].when:Show()
	end
end

---------------------------------------------------------------------------
-- Right page: exercise table
---------------------------------------------------------------------------

Book.CreateHeader(right, "Exercises")

local TABLE_TOP = -100
local TABLE_BOTTOM = -470 -- rows stop above the page's bottom edge
local MAX_ROWS = floor((TABLE_TOP - TABLE_BOTTOM) / ROW_HEIGHT) - 1

Text(right, Book.SMALL_FONT, TABLE_TOP):SetText("Movement")
Number(right, Book.SMALL_FONT, TABLE_TOP, 2):SetText("Times")
Number(right, Book.SMALL_FONT, TABLE_TOP, 1):SetText("Reps")
local empty = Text(right, Book.TEXT_FONT, TABLE_TOP - ROW_HEIGHT - 4)
empty:SetAlpha(0.7)
empty:SetText("No workouts yet.")

local rows = {}

local function GetRow(i)
	if not rows[i] then
		local y = TABLE_TOP - i * ROW_HEIGHT - 4
		rows[i] = {
			name = Text(right, Book.TEXT_FONT, y),
			times = Number(right, Book.TEXT_FONT, y, 2),
			reps = Number(right, Book.TEXT_FONT, y, 1),
			stripe = i % 2 == 1 and Stripe(right, y) or nil,
		}
	end
	return rows[i]
end

local function ShowRow(row, shown)
	for _, region in pairs(row) do
		region:SetShown(shown)
	end
end

---------------------------------------------------------------------------

local function Refresh()
	local db = ns.GetStats()
	local names = {}
	for _, ex in ipairs(ns.GetAllExercises()) do
		names[ex.key] = ex.name
	end

	local level = ns.GetLevelInfo()
	levelHeader.Text:SetText("Level " .. level)
	ns.UpdateXPBar()
	totals:SetText(("Total reps: %d     Total XP: %d"):format(ns.GetTotalReps(), ns.GetXP()))

	local total = db.done + db.rejected
	local rate = total > 0 and math.floor(db.done / total * 100) or 0
	summary:SetText(("Prompted %d times, %s%d done|r, %s%d skipped|r (%d%%)"):format(
		total, Book.GOOD, db.done, Book.BAD, db.rejected, rate))
	for key, row in pairs(sourceRows) do
		local s = db.bySource[key] or { done = 0, rejected = 0 }
		row.done:SetText(s.done)
		row.skipped:SetText(s.rejected)
	end
	RefreshRecent(db.log, names)

	-- Exercises that were done at least once; the last row sums up any that don't fit
	local done = {}
	for _, ex in ipairs(ns.GetAllExercises()) do
		if db.times[ex.key] then
			tinsert(done, ex)
		end
	end
	local n = math.min(#done, MAX_ROWS)
	for i = 1, n do
		local ex, row = done[i], GetRow(i)
		if i == MAX_ROWS and #done > MAX_ROWS then
			row.name:SetText(("and %d more..."):format(#done - MAX_ROWS + 1))
			row.times:SetText("")
			row.reps:SetText("")
		else
			row.name:SetText(ex.name)
			row.times:SetText(db.times[ex.key])
			row.reps:SetText(db.reps[ex.key] or 0)
		end
		ShowRow(row, true)
	end
	for i = n + 1, #rows do
		ShowRow(rows[i], false)
	end
	empty:SetShown(n == 0)
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
