local _, ns = ...

local ROW_HEIGHT = 24
local ROWS_TOP = -70 -- y offset of the first workout row

-- Standard Blizzard window (portrait + title bar), falling back to a simpler one if missing
local created, popup = pcall(CreateFrame, "Frame", "UGotTimeFrame", UIParent, "ButtonFrameTemplate")
if not created then
	popup = CreateFrame("Frame", "UGotTimeFrame", UIParent, "BasicFrameTemplateWithInset")
end
popup:SetSize(380, 190)
popup:SetPoint("CENTER")
popup:SetFrameStrata("DIALOG")

local function SetPopupTitle(text)
	if popup.SetTitle then
		popup:SetTitle(text)
	elseif popup.TitleText then
		popup.TitleText:SetText(text)
	end
end

local hasPortrait = true
if popup.SetPortraitToAsset then
	popup:SetPortraitToAsset(ns.ICON)
elseif popup.portrait then
	SetPortraitToTexture(popup.portrait, ns.ICON)
else
	hasPortrait = false
end

popup:EnableMouse(true)
popup:SetMovable(true)
popup:RegisterForDrag("LeftButton")
popup:SetScript("OnDragStart", popup.StartMoving)
popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
popup:Hide()
tinsert(UISpecialFrames, "UGotTimeFrame") -- close with Escape

local subtitle = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
subtitle:SetPoint("TOPLEFT", hasPortrait and 70 or 16, -36)

-- What the currently shown popup is about, so the buttons know what to record
local currentSource
local reps = {} -- exercise key -> reps entered in this popup

local function SmallButton(parent, text, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 20)
	b:SetText(text)
	return b
end

-- One row per workout: name, count, and - / + / ++ buttons. Rows are reused between popups.
local rows = {}

local function GetRow(i)
	if rows[i] then
		return rows[i]
	end
	local row = CreateFrame("Frame", nil, popup)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 20, ROWS_TOP - (i - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT", popup, "RIGHT", -20, 0)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("LEFT")

	row.plus10 = SmallButton(row, "++", 36)
	row.plus10:SetPoint("RIGHT")
	row.plus1 = SmallButton(row, "+", 28)
	row.plus1:SetPoint("RIGHT", row.plus10, "LEFT", -2, 0)
	row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.count:SetWidth(36)
	row.count:SetPoint("RIGHT", row.plus1, "LEFT", -4, 0)
	row.minus = SmallButton(row, "-", 28)
	row.minus:SetPoint("RIGHT", row.count, "LEFT", -4, 0)

	local function Add(amount)
		reps[row.key] = math.max(0, (reps[row.key] or 0) + amount)
		row.count:SetText(reps[row.key])
	end
	row.plus10:SetScript("OnClick", function() Add(10) end)
	row.plus1:SetScript("OnClick", function() Add(1) end)
	row.minus:SetScript("OnClick", function() Add(-1) end)

	rows[i] = row
	return row
end

local function Finish(save)
	local done = {}
	for key, count in pairs(reps) do
		if count > 0 then
			done[key] = count
		end
	end
	-- Manual popups (from /ugt) are recorded but not announced
	if save and next(done) then
		if currentSource == "flight" then
			ns.FlightWorkoutSaved(done)
		elseif currentSource == "quest" then
			ns.SayWorkout(done, "after " .. ns.QUESTS_PER_WORKOUT .. " quests", true)
		end
	end
	-- Recorded after the workout message, so a level up is announced after it
	ns.RecordWorkout(currentSource, save and reps or {})
	popup:Hide()
end

local saveButton = SmallButton(popup, "Save", 120)
saveButton:SetHeight(22)
saveButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -4, 6)
saveButton:SetScript("OnClick", function() Finish(true) end)

local skipButton = SmallButton(popup, "Skip", 120)
skipButton:SetHeight(22)
skipButton:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 4, 6)
skipButton:SetScript("OnClick", function() Finish(false) end)

-- source: "flight", "quest", or "manual"
function ns.ShowPopup(title, info, source)
	currentSource = source
	wipe(reps)

	local enabled = ns.GetEnabledExercises()
	for i, ex in ipairs(enabled) do
		local row = GetRow(i)
		row.key = ex.key
		row.name:SetText(ex.name)
		row.count:SetText(0)
		row:Show()
	end
	for i = #enabled + 1, #rows do
		rows[i]:Hide()
	end

	SetPopupTitle(title)
	subtitle:SetText(info or "")
	popup:SetHeight(-ROWS_TOP + #enabled * ROW_HEIGHT + 40)
	popup:ClearAllPoints()
	popup:SetPoint("CENTER")
	popup:Show()
	UIFrameFadeIn(popup, 0.3, 0, 1)
	PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
end
