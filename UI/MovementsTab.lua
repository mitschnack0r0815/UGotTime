local _, ns = ...

-- Movements tab (/ugt config): XP bar toggle, enable/disable, delete and add workouts
local ROW_HEIGHT = 24
local ROWS_TOP = -76 -- y offset of the first workout row
local ADD_HEIGHT = 80 -- height of the "Add workout" section below the list

local panel, tabIndex = ns.AddTab("Movements")

-- Show/hide the always visible XP bar (the one in the Stats tab always shows)
local xpBarCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
xpBarCheck:SetSize(24, 24)
xpBarCheck:SetPoint("TOPLEFT", 14, -24)
xpBarCheck:SetScript("OnClick", function(self)
	ns.SetXPBarShown(self:GetChecked() and true or false)
end)

local xpBarLabel = xpBarCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
xpBarLabel:SetPoint("LEFT", xpBarCheck, "RIGHT", 4, 0)
xpBarLabel:SetText("Show XP bar")

local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("TOPLEFT", 16, -58)
hint:SetText("Which movements can the popup pick?")

local Refresh -- defined below, rows and buttons call it after changes

StaticPopupDialogs["UGOTTIME_DELETE_WORKOUT"] = {
	text = "Delete workout \"%s\"?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, key)
		ns.DeleteExercise(key)
		Refresh()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local MAX_XP_PER_REP = 1000

-- Asks for a movement's XP per rep; data is the movement's key
local function AcceptXP(dialog, key)
	local editBox = dialog.editBox or dialog.EditBox
	local xp = tonumber(editBox:GetText())
	if not xp or xp < 0 or xp > MAX_XP_PER_REP or xp ~= math.floor(xp) then
		print(("U Got Time: XP per rep has to be a whole number from 0 to %d."):format(MAX_XP_PER_REP))
		return
	end
	ns.SetExerciseXP(key, xp)
	Refresh()
	ns.UpdateXPBar()
	ns.RefreshStatsTab()
end

StaticPopupDialogs["UGOTTIME_EDIT_XP"] = {
	text = "XP per rep for \"%s\":",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 4,
	OnAccept = AcceptXP,
	EditBoxOnEnterPressed = function(editBox, key)
		local dialog = editBox:GetParent()
		AcceptXP(dialog, key)
		dialog:Hide()
	end,
	EditBoxOnEscapePressed = function(editBox)
		editBox:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- Keep at least one movement enabled, otherwise the popup has nothing to show
local function IsLastEnabled(key)
	return ns.IsExerciseEnabled(key) and #ns.GetEnabledExercises() <= 1
end

-- One row per workout: checkbox, name, XP per rep, edit XP and delete buttons.
-- Rows are reused between refreshes.
local rows = {}

local function GetRow(i)
	if rows[i] then
		return rows[i]
	end
	local row = CreateFrame("Frame", nil, panel)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 14, ROWS_TOP - (i - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT", panel, "RIGHT", -14, 0)

	row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.check:SetSize(24, 24)
	row.check:SetPoint("LEFT")
	row.check:SetScript("OnClick", function(self)
		local checked = self:GetChecked() and true or false
		if not checked and IsLastEnabled(row.ex.key) then
			self:SetChecked(true)
			print("U Got Time: at least one movement has to stay enabled.")
			return
		end
		ns.SetExerciseEnabled(row.ex.key, checked)
	end)

	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.label:SetPoint("LEFT", row.check, "RIGHT", 4, 0)

	row.delete = CreateFrame("Button", nil, row, "UIPanelCloseButton")
	row.delete:SetSize(24, 24)
	row.delete:SetPoint("RIGHT")
	row.delete:SetScript("OnClick", function()
		if IsLastEnabled(row.ex.key) then
			print("U Got Time: at least one movement has to stay enabled.")
			return
		end
		StaticPopup_Show("UGOTTIME_DELETE_WORKOUT", row.ex.name, nil, row.ex.key)
	end)

	-- Pencil/note icon (same as the guild roster's note button)
	row.editXP = CreateFrame("Button", nil, row)
	row.editXP:SetSize(16, 16)
	row.editXP:SetPoint("RIGHT", row.delete, "LEFT", -4, 0)
	row.editXP:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
	row.editXP:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up", "ADD")
	row.editXP:SetScript("OnClick", function()
		local dialog = StaticPopup_Show("UGOTTIME_EDIT_XP", row.ex.name, nil, row.ex.key)
		if dialog then
			-- Prefill with the current value
			local editBox = dialog.editBox or dialog.EditBox
			editBox:SetText(ns.GetExerciseXP(row.ex.key))
			editBox:HighlightText()
			editBox:SetFocus()
		end
	end)
	row.editXP:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Edit XP per rep")
		GameTooltip:Show()
	end)
	row.editXP:SetScript("OnLeave", GameTooltip_Hide)

	row.xp = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.xp:SetPoint("RIGHT", row.editXP, "LEFT", -4, 0)

	rows[i] = row
	return row
end

-- "Add workout" section, moved below the last row on every refresh
local addSection = CreateFrame("Frame", nil, panel)
addSection:SetHeight(ADD_HEIGHT)

local addTitle = addSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
addTitle:SetPoint("TOPLEFT", 16, 0)
addTitle:SetText("Add workout")

local function InputRow(label, y)
	local text = addSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("TOPLEFT", 16, y - 4)
	text:SetText(label)

	local box = CreateFrame("EditBox", nil, addSection, "InputBoxTemplate")
	box:SetSize(210, 20)
	box:SetPoint("TOPLEFT", 80, y)
	box:SetAutoFocus(false)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	return box
end

local nameBox = InputRow("Name", -20)
nameBox:SetMaxLetters(30)

local function AddFromInput()
	local ex, err = ns.AddExercise(nameBox:GetText())
	if not ex then
		print("U Got Time: " .. err .. ".")
		return
	end
	nameBox:SetText("")
	nameBox:ClearFocus()
	Refresh()
end

nameBox:SetScript("OnEnterPressed", AddFromInput)

local addButton = CreateFrame("Button", nil, addSection, "UIPanelButtonTemplate")
addButton:SetSize(90, 22)
addButton:SetPoint("TOPLEFT", 76, -48)
addButton:SetText("Add")
addButton:SetScript("OnClick", AddFromInput)

local restoreButton = CreateFrame("Button", nil, addSection, "UIPanelButtonTemplate")
restoreButton:SetSize(120, 22)
restoreButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
restoreButton:SetText("Restore defaults")
restoreButton:SetScript("OnClick", function()
	ns.RestoreDefaultExercises()
	Refresh()
end)

function Refresh()
	xpBarCheck:SetChecked(ns.IsXPBarShown())

	local list = ns.GetExercises()
	for i, ex in ipairs(list) do
		local row = GetRow(i)
		row.ex = ex
		row.label:SetText(ex.name)
		row.xp:SetText(ns.GetExerciseXP(ex.key) .. " XP")
		row.check:SetChecked(ns.IsExerciseEnabled(ex.key))
		row:Show()
	end
	for i = #list + 1, #rows do
		rows[i]:Hide()
	end

	local y = ROWS_TOP - #list * ROW_HEIGHT - 12
	addSection:ClearAllPoints()
	addSection:SetPoint("TOPLEFT", 0, y)
	addSection:SetPoint("RIGHT", panel, "RIGHT")
	ns.SetWindowHeight(-y + ADD_HEIGHT)
end

panel:SetScript("OnShow", Refresh)

function ns.ToggleOptions()
	ns.ToggleTab(tabIndex)
end
