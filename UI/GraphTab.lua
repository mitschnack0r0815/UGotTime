local _, ns = ...
local Book = ns.Book

-- Graph tab: bar charts of the last two weeks, built from the workout log.
-- Left page: workouts done per day, with skipped ones stacked on top in red.
-- Right page: reps per day. The pager goes back in time.
local DAYS = 14 -- bars per chart
local CONTENT_X = Book.PAGE_MARGIN + 12
local CHART_TOP = -150 -- highest a bar can reach (room for two lines of numbers above it)
local CHART_BOTTOM = -430 -- baseline
local BAR_GAP = 4
local SKIPPED_COLOR = CreateColor(0.56, 0.12, 0.12) -- same red as Book.BAD

local panel, tabIndex = ns.AddTab("Graph")
local left, right = panel.left, panel.right

local function DayKey(t)
	return date("%Y-%m-%d", t)
end

-- Noon of the day `offset` days before today; noon keeps DST changes from skipping a day
local function DayTime(offset)
	local now = date("*t")
	return time({ year = now.year, month = now.month, day = now.day - offset, hour = 12 })
end

local function CreateChart(page, title)
	local chart = {}
	Book.CreateHeader(page, title)

	chart.summary = Book.CreateText(page, Book.SMALL_FONT)
	chart.summary:SetPoint("TOPLEFT", CONTENT_X, -100)
	chart.summary:SetPoint("RIGHT", -Book.PAGE_MARGIN, 0)

	local baseline = page:CreateTexture(nil, "ARTWORK")
	baseline:SetPoint("TOPLEFT", CONTENT_X - 4, CHART_BOTTOM)
	baseline:SetPoint("RIGHT", -Book.PAGE_MARGIN + 4, 0)
	baseline:SetHeight(1)
	baseline:SetColorTexture(Book.FONT_COLOR.r, Book.FONT_COLOR.g, Book.FONT_COLOR.b, 0.5)

	chart.bars = {}
	for i = 1, DAYS do
		local bar = {}
		bar.fill = page:CreateTexture(nil, "ARTWORK")
		bar.skipped = page:CreateTexture(nil, "ARTWORK")
		bar.value = Book.CreateText(page, Book.SMALL_FONT)
		bar.value:SetJustifyH("CENTER")
		bar.day = Book.CreateText(page, Book.SMALL_FONT)
		bar.day:SetJustifyH("CENTER")
		chart.bars[i] = bar
	end

	-- values[i] is the number for day i (1 = oldest); today is highlighted when shown.
	-- skipped (optional) is stacked on top of values in red, its number above the bar's.
	function chart:Update(values, days, todayIndex, skipped)
		local slot = (page:GetWidth() - CONTENT_X - Book.PAGE_MARGIN) / DAYS
		local maxValue = 0
		for i = 1, DAYS do
			maxValue = math.max(maxValue, values[i] + (skipped and skipped[i] or 0))
		end
		local height = CHART_TOP - CHART_BOTTOM
		for i, bar in ipairs(self.bars) do
			local x = CONTENT_X + (i - 1) * slot
			local value = values[i]
			local skip = skipped and skipped[i] or 0
			local alpha = i == todayIndex and 0.9 or 0.55
			local fillHeight = maxValue > 0 and value / maxValue * height or 0
			local skipHeight = maxValue > 0 and skip / maxValue * height or 0

			bar.fill:ClearAllPoints()
			bar.fill:SetPoint("BOTTOMLEFT", page, "TOPLEFT", x + BAR_GAP / 2, CHART_BOTTOM)
			bar.fill:SetWidth(slot - BAR_GAP)
			bar.fill:SetHeight(math.max(1, fillHeight))
			bar.fill:SetColorTexture(Book.FONT_COLOR.r, Book.FONT_COLOR.g, Book.FONT_COLOR.b, alpha)
			bar.fill:SetShown(value > 0)

			bar.skipped:ClearAllPoints()
			bar.skipped:SetPoint("BOTTOMLEFT", page, "TOPLEFT", x + BAR_GAP / 2, CHART_BOTTOM + fillHeight)
			bar.skipped:SetWidth(slot - BAR_GAP)
			bar.skipped:SetHeight(math.max(1, skipHeight))
			bar.skipped:SetColorTexture(SKIPPED_COLOR.r, SKIPPED_COLOR.g, SKIPPED_COLOR.b, alpha)
			bar.skipped:SetShown(skip > 0)

			local label = value > 0 and tostring(value) or ""
			if skip > 0 then
				label = Book.BAD .. skip .. "|r" .. (label ~= "" and "\n" .. label or "")
			end
			bar.value:ClearAllPoints()
			bar.value:SetPoint("BOTTOM", page, "TOPLEFT", x + slot / 2, CHART_BOTTOM + fillHeight + skipHeight + 2)
			bar.value:SetText(label)

			bar.day:ClearAllPoints()
			bar.day:SetPoint("TOP", page, "TOPLEFT", x + slot / 2, CHART_BOTTOM - 4)
			bar.day:SetText(date("%d", days[i]))
			bar.day:SetAlpha(i == todayIndex and 1 or 0.7)
		end
	end

	return chart
end

local timesChart = CreateChart(left, "Workouts per day")
local repsChart = CreateChart(right, "Reps per day")

-- How many DAYS-long pages back from today we are (0 = the latest two weeks)
local pagesBack = 0
local Refresh, pager

pager = Book.CreatePager(right, function(delta)
	pagesBack = pagesBack - delta
	Refresh()
end)
pager:EnableWheel(panel)

function Refresh()
	local log = ns.GetStats().log

	-- Done and skipped workouts and reps per day
	local times, skips, reps = {}, {}, {}
	for _, entry in ipairs(log) do
		if entry.result == "rejected" then
			local day = DayKey(entry.time)
			skips[day] = (skips[day] or 0) + 1
		elseif entry.result == "done" then
			local day = DayKey(entry.time)
			times[day] = (times[day] or 0) + 1
			local total = 0
			for _, count in pairs(entry.reps or {}) do
				total = total + count
			end
			reps[day] = (reps[day] or 0) + total
		end
	end

	-- Enough pages to reach the oldest logged day; the newest page is the last one
	local daysLogged = 1
	if log[1] then
		daysLogged = math.floor((DayTime(0) - log[1].time) / 86400) + 2
	end
	local totalPages = math.max(1, math.ceil(daysLogged / DAYS))
	pagesBack = math.max(0, math.min(totalPages - 1, pagesBack))
	pager:Update(totalPages - pagesBack, totalPages)

	local days, timeValues, skipValues, repValues = {}, {}, {}, {}
	local timeSum, skipSum, repSum = 0, 0, 0
	for i = 1, DAYS do
		local t = DayTime((DAYS - i) + pagesBack * DAYS)
		local day = DayKey(t)
		days[i] = t
		timeValues[i] = times[day] or 0
		skipValues[i] = skips[day] or 0
		repValues[i] = reps[day] or 0
		timeSum = timeSum + timeValues[i]
		skipSum = skipSum + skipValues[i]
		repSum = repSum + repValues[i]
	end
	local todayIndex = pagesBack == 0 and DAYS or nil

	local range = date("%d.%m.", days[1]) .. " - " .. date("%d.%m.", days[DAYS])
	timesChart.summary:SetText(("%s     %d workouts, %s%d skipped|r"):format(range, timeSum, Book.BAD, skipSum))
	repsChart.summary:SetText(("%s     %d reps"):format(range, repSum))
	timesChart:Update(timeValues, days, todayIndex, skipValues)
	repsChart:Update(repValues, days, todayIndex)
end

panel:SetScript("OnShow", function()
	pagesBack = 0
	Refresh()
end)

-- Called after a workout is saved or the stats are reset
function ns.RefreshGraphTab()
	if panel:IsVisible() then
		Refresh()
	end
end

function ns.ToggleGraph()
	ns.ToggleTab(tabIndex)
end
