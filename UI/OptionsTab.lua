local _, ns = ...
local Book = ns.Book

-- Options tab (/ugt config). Left page: the movements as spellbook entries; click one to
-- enable or disable it, with buttons to edit its XP or delete it. Right page: XP bar toggle
-- and adding workouts.
local CONTENT_X = Book.PAGE_MARGIN + 12 -- left edge of page content, lined up with the headers

local panel, tabIndex = ns.AddTab("Options")
local left, right = panel.left, panel.right

local Refresh -- defined below, entries and buttons call it after changes
local page = 1

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

---------------------------------------------------------------------------
-- Left page: movement entries
---------------------------------------------------------------------------

Book.CreateHeader(left, "Movements")

local hint = Book.CreateText(left, Book.SMALL_FONT)
hint:SetPoint("TOPLEFT", CONTENT_X, -94)
hint:SetAlpha(0.8)
hint:SetText("Click a movement to turn it on or off for the popup.")

local listArea = CreateFrame("Frame", nil, left)
listArea:SetPoint("TOPLEFT", CONTENT_X, -122)
listArea:SetPoint("BOTTOMRIGHT", -Book.PAGE_MARGIN, 70)

local pager = Book.CreatePager(left, function(delta)
	page = page + delta
	Refresh()
end)
pager:EnableWheel(listArea)

local function ShowEntryTooltip(entry)
	GameTooltip:SetOwner(entry, "ANCHOR_RIGHT")
	GameTooltip:AddLine(entry.ex.name)
	GameTooltip:AddLine(entry.isDisabled and "Click to turn on" or "Click to turn off", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end

-- Entries are reused between refreshes
local entries = {}

local function GetEntry(i)
	if entries[i] then
		return entries[i]
	end
	local entry = Book.CreateEntry(listArea, ns.ICON)
	entry:SetPoint("TOPLEFT", 0, -(i - 1) * Book.ENTRY_HEIGHT)
	entry:SetPoint("RIGHT")

	entry.delete = CreateFrame("Button", nil, entry, "UIPanelCloseButton")
	entry.delete:SetSize(24, 24)
	entry.delete:SetPoint("RIGHT")
	entry.delete:SetScript("OnClick", function()
		if IsLastEnabled(entry.ex.key) then
			print("U Got Time: at least one movement has to stay enabled.")
			return
		end
		StaticPopup_Show("UGOTTIME_DELETE_WORKOUT", entry.ex.name, nil, entry.ex.key)
	end)

	-- Pencil/note icon (same as the guild roster's note button)
	entry.editXP = CreateFrame("Button", nil, entry)
	entry.editXP:SetSize(16, 16)
	entry.editXP:SetPoint("RIGHT", entry.delete, "LEFT", -4, 0)
	entry.editXP:SetNormalTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
	entry.editXP:SetHighlightTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up", "ADD")
	entry.editXP:SetScript("OnClick", function()
		local dialog = StaticPopup_Show("UGOTTIME_EDIT_XP", entry.ex.name, nil, entry.ex.key)
		if dialog then
			-- Prefill with the current value
			local editBox = dialog.editBox or dialog.EditBox
			editBox:SetText(ns.GetExerciseXP(entry.ex.key))
			editBox:HighlightText()
			editBox:SetFocus()
		end
	end)
	entry.editXP:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Edit XP per rep")
		GameTooltip:Show()
	end)
	entry.editXP:SetScript("OnLeave", GameTooltip_Hide)

	-- Keep the text clear of the buttons
	entry.name:SetPoint("RIGHT", entry.editXP, "LEFT", -6, 0)
	entry.sub:SetPoint("RIGHT", entry.editXP, "LEFT", -6, 0)

	entry:HookScript("OnEnter", ShowEntryTooltip)
	entry:HookScript("OnLeave", GameTooltip_Hide)
	entry:SetScript("OnClick", function(self)
		local enable = not ns.IsExerciseEnabled(self.ex.key)
		if not enable and IsLastEnabled(self.ex.key) then
			print("U Got Time: at least one movement has to stay enabled.")
			return
		end
		ns.SetExerciseEnabled(self.ex.key, enable)
		PlaySound(enable and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		Refresh()
		ShowEntryTooltip(self)
	end)

	entries[i] = entry
	return entry
end

---------------------------------------------------------------------------
-- Right page: options and adding workouts
---------------------------------------------------------------------------

Book.CreateHeader(right, "Settings")

-- Checkbox with a label; onClick gets the new checked state
local function Checkbox(label, y, onClick)
	local check = CreateFrame("CheckButton", nil, right, "UICheckButtonTemplate")
	check:SetSize(26, 26)
	check:SetPoint("TOPLEFT", CONTENT_X - 4, y)
	check:SetScript("OnClick", function(self)
		onClick(self:GetChecked() and true or false)
	end)
	local text = Book.CreateText(check, Book.TEXT_FONT)
	text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	text:SetText(label)
	return check
end

-- Show/hide the always visible XP bar (the one in the Stats tab always shows)
local xpBarCheck = Checkbox("Show XP bar on screen", -98, ns.SetXPBarShown)
local sayCheck = Checkbox("Announce workouts in /say", -126, function(on)
	ns.SetAnnounceOn("SAY", on)
end)
local partyCheck = Checkbox("Announce workouts in party chat", -154, function(on)
	ns.SetAnnounceOn("PARTY", on)
end)

-- "Workout after every [-] 5 [+] quests"
local questLabel = Book.CreateText(right, Book.TEXT_FONT)
questLabel:SetPoint("TOPLEFT", CONTENT_X, -196)
questLabel:SetText("Workout after every")

local questMinus = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
questMinus:SetSize(24, 22)
questMinus:SetPoint("LEFT", questLabel, "RIGHT", 8, 0)
questMinus:SetText("-")

local questCount = Book.CreateText(right, Book.NAME_FONT)
questCount:SetWidth(32)
questCount:SetJustifyH("CENTER")
questCount:SetPoint("LEFT", questMinus, "RIGHT", 2, 0)

local questPlus = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
questPlus:SetSize(24, 22)
questPlus:SetPoint("LEFT", questCount, "RIGHT", 2, 0)
questPlus:SetText("+")

local questsText = Book.CreateText(right, Book.TEXT_FONT)
questsText:SetPoint("LEFT", questPlus, "RIGHT", 8, 0)
questsText:SetText("quests")

local function UpdateQuestSetting()
	local count = ns.GetQuestsPerWorkout()
	questCount:SetText(count)
	questMinus:SetEnabled(count > ns.MIN_QUESTS_PER_WORKOUT)
	questPlus:SetEnabled(count < ns.MAX_QUESTS_PER_WORKOUT)
end

local function ChangeQuests(delta)
	ns.SetQuestsPerWorkout(ns.GetQuestsPerWorkout() + delta)
	UpdateQuestSetting()
end
questMinus:SetScript("OnClick", function() ChangeQuests(-1) end)
questPlus:SetScript("OnClick", function() ChangeQuests(1) end)

local info = Book.CreateText(right, Book.SMALL_FONT)
info:SetPoint("TOPLEFT", CONTENT_X, -224)
info:SetPoint("RIGHT", -Book.PAGE_MARGIN, 0)
info:SetAlpha(0.8)
info:SetText("A workout also pops up whenever you take a flight.")

local addHeader = Book.CreateSubHeader(right, "Add workout")
addHeader:SetPoint("TOPLEFT", CONTENT_X, -256)
addHeader:SetPoint("RIGHT", -Book.PAGE_MARGIN, 0)

local nameLabel = Book.CreateText(right, Book.TEXT_FONT)
nameLabel:SetPoint("TOPLEFT", CONTENT_X, -304)
nameLabel:SetText("Name")

local nameBox = CreateFrame("EditBox", nil, right, "InputBoxTemplate")
nameBox:SetSize(220, 22)
nameBox:SetPoint("LEFT", nameLabel, "LEFT", 60, 0)
nameBox:SetAutoFocus(false)
nameBox:SetMaxLetters(30)
nameBox:SetScript("OnEscapePressed", nameBox.ClearFocus)

local function AddFromInput()
	local ex, err = ns.AddExercise(nameBox:GetText())
	if not ex then
		print("U Got Time: " .. err .. ".")
		return
	end
	nameBox:SetText("")
	nameBox:ClearFocus()
	page = math.huge -- jump to the new movement at the end of the list
	Refresh()
end

nameBox:SetScript("OnEnterPressed", AddFromInput)

local addButton = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
addButton:SetSize(100, 24)
addButton:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", -6, -10)
addButton:SetText("Add")
addButton:SetScript("OnClick", AddFromInput)

local restoreButton = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
restoreButton:SetSize(130, 24)
restoreButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
restoreButton:SetText("Restore defaults")
restoreButton:SetScript("OnClick", function()
	ns.RestoreDefaultExercises()
	Refresh()
end)

---------------------------------------------------------------------------

function Refresh()
	xpBarCheck:SetChecked(ns.IsXPBarShown())
	sayCheck:SetChecked(ns.IsAnnounceOn("SAY"))
	partyCheck:SetChecked(ns.IsAnnounceOn("PARTY"))
	UpdateQuestSetting()

	local list = ns.GetExercises()
	local perPage = math.max(1, floor(listArea:GetHeight() / Book.ENTRY_HEIGHT))
	local numPages = math.max(1, ceil(#list / perPage))
	page = math.min(math.max(page, 1), numPages)

	local first = (page - 1) * perPage
	for i = 1, perPage do
		local ex = list[first + i]
		local entry = GetEntry(i)
		if ex then
			local enabled = ns.IsExerciseEnabled(ex.key)
			entry.ex = ex
			entry.isDisabled = not enabled
			entry.name:SetText(ex.name)
			entry.sub:SetText(enabled and (ns.GetExerciseXP(ex.key) .. " XP per rep") or "Turned off")
			Book.UpdateEntry(entry)
			entry:Show()
		else
			entry:Hide()
		end
	end
	for i = perPage + 1, #entries do
		entries[i]:Hide()
	end
	pager:Update(page, numPages)
end

panel:SetScript("OnShow", Refresh)

-- Called after a setting changes from outside the tab (e.g. /ugt quests)
function ns.RefreshOptionsTab()
	if panel:IsVisible() then
		Refresh()
	end
end

function ns.ToggleOptions()
	ns.ToggleTab(tabIndex)
end
