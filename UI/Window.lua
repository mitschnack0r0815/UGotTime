local _, ns = ...
local Book = ns.Book

-- Main window, styled like the spellbook: an open book with one tab per panel (Stats,
-- Options) along the bottom edge. Each file adds its own tab via ns.AddTab and fills
-- the tab's two pages.
local window = CreateFrame("Frame", "UGotTimeMainFrame", UIParent,
	Book.TemplateExists("PortraitFrameTemplate") and "PortraitFrameTemplate" or "BasicFrameTemplate")
window:SetSize(880, 580)
window:SetPoint("TOP", UIParent, "TOP", 0, -100)
window:SetFrameStrata("HIGH") -- below DIALOG so the workout popup and confirm popups show on top
window:SetToplevel(true)
window:SetClampedToScreen(true)
window:EnableMouse(true)
window:SetMovable(true)
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", window.StartMoving)
window:SetScript("OnDragStop", window.StopMovingOrSizing)
window:Hide()
tinsert(UISpecialFrames, "UGotTimeMainFrame") -- close with Escape

if window.SetTitle then
	window:SetTitle("U Got Time")
elseif window.TitleText then
	window.TitleText:SetText("U Got Time")
end
if window.SetPortraitToAsset then
	window:SetPortraitToAsset(ns.ICON)
end

local book = CreateFrame("Frame", nil, window)
book:SetPoint("TOPLEFT", 2, -21)
book:SetPoint("BOTTOMRIGHT", -2, 2)
Book.CreateBookArt(book)

local startButton = CreateFrame("Button", nil, book, "UIPanelButtonTemplate")
startButton:SetSize(130, 24)
startButton:SetPoint("TOPRIGHT", -24, -14)
startButton:SetText("Start Workout")
startButton:SetScript("OnClick", function()
	ns.ShowPopup("Workout!", nil, "manual")
end)

window:SetScript("OnShow", function()
	PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
end)
window:SetScript("OnHide", function()
	PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
end)

-- Bottom tabs (as on the talents/spellbook window); plain buttons if the client doesn't have them
local hasTabTemplate = Book.TemplateExists("PanelTabButtonTemplate")

local tabs = {}
local panels = {}
local currentTab

local function SelectTab(index)
	currentTab = index
	for i, panel in ipairs(panels) do
		panel:SetShown(i == index)
	end
	if hasTabTemplate then
		PanelTemplates_SetTab(window, index)
	else
		for i, tab in ipairs(tabs) do
			tab:SetEnabled(i ~= index)
		end
	end
end

-- Adds a tab and returns its panel. panel.left and panel.right are the two pages to fill.
function ns.AddTab(text)
	local index = #panels + 1

	-- PanelTemplates expects tabs named <window>Tab<n>
	local tab = CreateFrame("Button", "UGotTimeMainFrameTab" .. index, window,
		hasTabTemplate and "PanelTabButtonTemplate" or "UIPanelButtonTemplate")
	tab:SetID(index)
	tab:SetText(text)
	if index == 1 then
		tab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 22, 2)
	else
		tab:SetPoint("LEFT", tabs[index - 1], "RIGHT", 3, 0)
	end
	if hasTabTemplate then
		PanelTemplates_TabResize(tab, 0)
	else
		tab:SetSize(100, 24)
	end
	tab:SetScript("OnClick", function()
		SelectTab(index)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	end)
	tabs[index] = tab

	local panel = CreateFrame("Frame", nil, book)
	panel:SetAllPoints()
	panel:Hide()
	panel.left = CreateFrame("Frame", nil, panel)
	panel.left:SetAllPoints(book.leftPage)
	panel.right = CreateFrame("Frame", nil, panel)
	panel.right:SetAllPoints(book.rightPage)
	panels[index] = panel

	if hasTabTemplate then
		PanelTemplates_SetNumTabs(window, index)
	end
	return panel, index
end

-- Opens the window on the given tab, or closes it if that tab is already showing
function ns.ToggleTab(index)
	if window:IsShown() and currentTab == index then
		window:Hide()
		return
	end
	window:Show()
	SelectTab(index)
end
