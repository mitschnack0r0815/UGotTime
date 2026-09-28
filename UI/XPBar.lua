local _, ns = ...
local Book = ns.Book

-- Workout XP bars (XP and levels come from Core/Levels.lua), drawn like the game's XP bar.
-- The always visible one sits on top of the game's XP/reputation bars. There's also one in
-- the Stats tab; ns.UpdateXPBar() updates all of them.

local FILL_ATLAS = "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Orange" -- orange, to tell it apart from the purple XP bar
local BAR_HEIGHT = 17 -- same as the game's status bars (STATUS_BAR_CONTAINER_HEIGHT)
local DEFAULT_WIDTH = 1192 -- STATUS_BAR_CONTAINER_WIDTH, used when the game's bar isn't there

local hasHudArt = Book.GetAtlas("UI-HUD-ExperienceBar-Frame") ~= nil

local bars = {}

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine("U Got Time")
	GameTooltip:AddLine(self.label:GetText(), 1, 1, 1)
	GameTooltip:AddLine(("Total reps: %d"):format(ns.GetTotalReps()), 1, 1, 1)
	GameTooltip:AddLine(("Total XP: %d"):format(ns.GetXP()), 1, 1, 1)
	GameTooltip:Show()
end

-- Text shows on hover, or always when alwaysShowText is set or the game's
-- "always show XP text" option is on
local function UpdateText(self)
	local show = self.alwaysShowText or self:IsMouseOver() or GetCVarBool("xpBarText")
	self.label:SetShown(show and true or false)
end

-- Evenly spaced segment lines, like the game's XP bar
local function UpdateDividers(self)
	local segmentWidth = self:GetWidth() / self.segments
	for i, divider in ipairs(self.dividers) do
		divider:ClearAllPoints()
		divider:SetPoint("CENTER", self, "LEFT", segmentWidth * i, 0)
	end
end

-- Creates an XP bar; the caller positions it and sets the width. segments is the number
-- of divider sections (the game's bar has 20).
function ns.CreateXPBar(parent, name, segments)
	local bar = CreateFrame("Frame", name, parent)
	bar:SetHeight(BAR_HEIGHT)
	bar.segments = segments or 20

	bar.status = CreateFrame("StatusBar", nil, bar)
	bar.status:SetPoint("TOPLEFT", 1, -1)
	bar.status:SetPoint("BOTTOMRIGHT", -2, 2)

	local background = bar.status:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()

	-- Frame and dividers above the fill
	local overlay = CreateFrame("Frame", nil, bar)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(bar.status:GetFrameLevel() + 2)

	bar.dividers = {}
	if hasHudArt then
		bar.status:SetStatusBarTexture(FILL_ATLAS)
		background:SetAtlas("UI-HUD-ExperienceBar-Background")
		local frameArt = overlay:CreateTexture(nil, "OVERLAY")
		frameArt:SetAtlas("UI-HUD-ExperienceBar-Frame")
		frameArt:SetAllPoints()
		for i = 1, bar.segments - 1 do
			local divider = overlay:CreateTexture(nil, "ARTWORK")
			divider:SetAtlas("ui-hud-experiencebar-divider")
			divider:SetSize(3, 10)
			bar.dividers[i] = divider
		end
		bar:SetScript("OnSizeChanged", UpdateDividers)
	else
		-- Older clients: plain bar with a tooltip border
		bar.status:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		bar.status:SetStatusBarColor(0.9, 0.5, 0.1)
		background:SetColorTexture(0, 0, 0, 0.6)
		local border = CreateFrame("Frame", nil, overlay, BackdropTemplateMixin and "BackdropTemplate")
		border:SetPoint("TOPLEFT", -2, 2)
		border:SetPoint("BOTTOMRIGHT", 2, -2)
		border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
		border:SetBackdropBorderColor(0.6, 0.6, 0.6)
	end

	bar.label = overlay:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	bar.label:SetPoint("CENTER", 0, 1)

	bar:EnableMouse(true)
	bar:SetScript("OnEnter", function(self)
		UpdateText(self)
		ShowTooltip(self)
	end)
	bar:SetScript("OnLeave", function(self)
		UpdateText(self)
		GameTooltip:Hide()
	end)

	tinsert(bars, bar)
	return bar
end

---------------------------------------------------------------------------
-- The always visible bar, docked above the game's status bars
---------------------------------------------------------------------------

local docked = ns.CreateXPBar(UIParent, "UGotTimeXPBar")
docked:SetFrameStrata("MEDIUM")
docked:SetWidth(MainStatusTrackingBarContainer and MainStatusTrackingBarContainer:GetWidth() or DEFAULT_WIDTH)
docked:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 60) -- until the first layout below
docked:Hide()

-- Only our own bar is ever moved. Moving Blizzard's action bars from addon code taints them
-- (their cooldowns then fail with "secret values" errors), so the bars above aren't touched.
local canDock = MainStatusTrackingBarContainer and SecondaryStatusTrackingBarContainer and MainActionBar

-- Sits on the topmost of the game's bottom bars: the upper status bar if one shows,
-- otherwise the main action bar
local function Dock()
	if not canDock then
		return
	end
	local anchorBar, gap = MainActionBar, BOTTOM_ACTION_BARS_SPACER_Y or 4
	for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
		if container:IsShown() then
			anchorBar, gap = container, PRIMARY_AND_SECONDARY_STATUS_TRACKING_BAR_SPACER_Y or -1
			break
		end
	end
	docked:ClearAllPoints()
	docked:SetPoint("BOTTOMLEFT", anchorBar, "TOPLEFT", 0, gap)
end

if canDock then
	-- Re-dock when the game shows or hides its XP/reputation bars
	for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
		container:HookScript("OnShow", Dock)
		container:HookScript("OnHide", Dock)
	end
else
	-- No Edit Mode layout to join: draggable bar at the top of the screen instead
	docked:SetWidth(250)
	docked:ClearAllPoints()
	docked:SetPoint("TOP", UIParent, "TOP", 0, -20)
	docked:SetClampedToScreen(true)
	docked:SetMovable(true)
	docked:RegisterForDrag("LeftButton")
	docked:SetScript("OnDragStart", docked.StartMoving)
	docked:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		ns.GetSettings().xpBarPos = { point = point, relPoint = relPoint, x = x, y = y }
	end)
end

function ns.IsXPBarShown()
	return not ns.GetSettings().hideXPBar
end

function ns.SetXPBarShown(shown)
	ns.GetSettings().hideXPBar = (not shown) or nil
	docked:SetShown(shown)
end

local shownLevel

function ns.UpdateXPBar()
	local level, progress, needed = ns.GetLevelInfo()
	for _, bar in ipairs(bars) do
		bar.status:SetMinMaxValues(0, needed)
		bar.status:SetValue(progress)
		bar.label:SetText(("Workout level %d  -  %d / %d XP"):format(level, progress, needed))
		UpdateText(bar)
	end

	if shownLevel and level > shownLevel then
		print(("U Got Time: |cffffd100Level up! You are now level %d.|r"):format(level))
		if SOUNDKIT.IG_QUEST_LIST_COMPLETE then
			PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
		end
	end
	shownLevel = level
end

-- SavedVariables are only available after login
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("CVAR_UPDATE")
loader:SetScript("OnEvent", function(_, event)
	if event == "CVAR_UPDATE" then
		for _, bar in ipairs(bars) do
			UpdateText(bar)
		end
		return
	end
	local pos = ns.GetSettings().xpBarPos
	if pos and not canDock then
		docked:ClearAllPoints()
		docked:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	end
	docked:SetShown(ns.IsXPBarShown())
	if canDock then
		Dock()
	end
	ns.UpdateXPBar()
end)
