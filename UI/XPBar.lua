local _, ns = ...

-- Workout XP bars (XP and levels come from Core/Levels.lua). There's an always visible,
-- draggable bar (position saved in UGotTimeSettings.xpBarPos) and one at the bottom of the
-- Stats tab; ns.UpdateXPBar() updates all of them.

local bars = {}

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:AddLine("U Got Time")
	GameTooltip:AddLine(("Total reps: %d"):format(ns.GetTotalReps()), 1, 1, 1)
	GameTooltip:AddLine(("Total XP: %d"):format(ns.GetXP()), 1, 1, 1)
	if self:IsMovable() then
		GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
	end
	GameTooltip:Show()
end

-- Creates an XP bar; the caller positions and sizes it
function ns.CreateXPBar(parent, name)
	local bar = CreateFrame("StatusBar", name, parent)
	bar:SetHeight(16)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.58, 0.0, 0.55) -- same purple as the character XP bar

	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.6)

	local border = CreateFrame("Frame", nil, bar, BackdropTemplateMixin and "BackdropTemplate")
	border:SetPoint("TOPLEFT", -3, 3)
	border:SetPoint("BOTTOMRIGHT", 3, -3)
	border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
	border:SetBackdropBorderColor(0.6, 0.6, 0.6)

	-- On the border frame so it draws above the bar fill
	bar.label = border:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.label:SetPoint("CENTER", bar)

	bar:EnableMouse(true)
	bar:SetScript("OnEnter", ShowTooltip)
	bar:SetScript("OnLeave", GameTooltip_Hide)

	tinsert(bars, bar)
	return bar
end

-- The always visible one
local floating = ns.CreateXPBar(UIParent, "UGotTimeXPBar")
floating:SetWidth(250)
floating:SetPoint("TOP", UIParent, "TOP", 0, -20)
floating:SetClampedToScreen(true)
floating:SetMovable(true)
floating:RegisterForDrag("LeftButton")
floating:SetScript("OnDragStart", floating.StartMoving)
floating:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	ns.GetSettings().xpBarPos = { point = point, relPoint = relPoint, x = x, y = y }
end)

function ns.IsXPBarShown()
	return not ns.GetSettings().hideXPBar
end

function ns.SetXPBarShown(shown)
	ns.GetSettings().hideXPBar = (not shown) or nil
	floating:SetShown(shown)
end

local shownLevel

function ns.UpdateXPBar()
	local level, progress, needed = ns.GetLevelInfo()
	for _, bar in ipairs(bars) do
		bar:SetMinMaxValues(0, needed)
		bar:SetValue(progress)
		bar.label:SetText(("Level %d  -  %d / %d XP"):format(level, progress, needed))
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
loader:SetScript("OnEvent", function()
	local pos = ns.GetSettings().xpBarPos
	if pos then
		floating:ClearAllPoints()
		floating:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	end
	floating:SetShown(ns.IsXPBarShown())
	ns.UpdateXPBar()
end)
