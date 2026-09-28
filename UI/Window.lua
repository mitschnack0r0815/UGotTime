local _, ns = ...

local TAB_SPACE = 26 -- height of the tab row under the title bar; panels start below it
local PADDING = 14 -- extra space between the content and the window border (each side)

-- Main window with one tab per panel (Stats, Movements). Each file adds its own tab via ns.AddTab.
-- Anchored by its top edge at a fixed spot, so changing the height only grows it downwards.
local window = CreateFrame("Frame", "UGotTimeMainFrame", UIParent, "BasicFrameTemplateWithInset")
window:SetSize(320 + 2 * PADDING, 300)
window:SetPoint("TOP", UIParent, "TOP", 0, -120)
window:SetFrameStrata("HIGH") -- below DIALOG so confirm popups show on top
window:EnableMouse(true)
window:Hide()
tinsert(UISpecialFrames, "UGotTimeMainFrame") -- close with Escape

if window.TitleText then
	window.TitleText:SetText("U Got Time")
end

-- Top-style tabs (as on the Friends window); plain buttons if the client doesn't have them
local hasTabTemplate = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("TabButtonTemplate")
local TAB_TEMPLATE = hasTabTemplate and "TabButtonTemplate" or "UIPanelButtonTemplate"

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

-- Adds a tab and returns its content panel. Panels sit below the tab row and set the
-- window height themselves (ns.SetWindowHeight) when shown.
function ns.AddTab(text)
	local index = #panels + 1

	-- PanelTemplates expects tabs named <window>Tab<n>
	local tab = CreateFrame("Button", "UGotTimeMainFrameTab" .. index, window, TAB_TEMPLATE)
	tab:SetID(index)
	tab:SetText(text)
	if index == 1 then
		tab:SetPoint("TOPLEFT", window, "TOPLEFT", 10 + PADDING, -24 - PADDING / 2)
	else
		tab:SetPoint("LEFT", tabs[index - 1], "RIGHT", 0, 0)
	end
	if hasTabTemplate then
		PanelTemplates_TabResize(tab, 0)
	else
		tab:SetSize(90, 22)
	end
	tab:SetScript("OnClick", function()
		SelectTab(index)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	end)
	tabs[index] = tab

	local panel = CreateFrame("Frame", nil, window)
	panel:SetPoint("TOPLEFT", PADDING, -TAB_SPACE - PADDING / 2)
	panel:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
	panel:Hide()
	panels[index] = panel

	if hasTabTemplate then
		PanelTemplates_SetNumTabs(window, index)
	end
	return panel, index
end

-- height is the panel's own height; the tab row is added on top
function ns.SetWindowHeight(height)
	window:SetHeight(height + TAB_SPACE + PADDING * 1.5)
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
