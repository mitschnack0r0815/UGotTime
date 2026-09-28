local _, ns = ...

-- Round button on the minimap edge. Drag to move it around the minimap; the angle and
-- hidden state are saved in UGotTimeSettings.minimap.
local DEFAULT_ANGLE = 200

local button = CreateFrame("Button", "UGotTimeMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Same textures and offsets as standard minimap buttons
local background = button:CreateTexture(nil, "BACKGROUND")
background:SetSize(20, 20)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetPoint("TOPLEFT", 7, -5)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(17, 17)
icon:SetTexture(ns.ICON)
icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
icon:SetPoint("TOPLEFT", 7, -6)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT")

local function GetMinimapSettings()
	local s = ns.GetSettings()
	s.minimap = s.minimap or { angle = DEFAULT_ANGLE }
	return s.minimap
end

local function UpdatePosition()
	local angle = math.rad(GetMinimapSettings().angle)
	local radius = Minimap:GetWidth() / 2 + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- While dragging, follow the cursor around the minimap edge
local function FollowCursor()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	GetMinimapSettings().angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	UpdatePosition()
end

button:SetScript("OnDragStart", function(self)
	self:SetScript("OnUpdate", FollowCursor)
	GameTooltip:Hide()
end)
button:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
end)

StaticPopupDialogs["UGOTTIME_RESET_STATS"] = {
	text = "Reset all U Got Time stats?\n\nThis clears every prompt, rep and your XP level. It can't be undone.",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		ns.ResetStats()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	showAlert = true,
	preferredIndex = 3,
}

-- Right-click menu entries, shared by both menu implementations below
local MENU = {
	{ title = "U Got Time" },
	{ text = "Start workout", func = function() ns.ShowPopup("Workout!", nil, "manual") end },
	{ text = "Stats", func = function() ns.ToggleStats() end },
	{ text = "Options", func = function() ns.ToggleOptions() end },
	{ text = "Show XP bar", checked = function() return ns.IsXPBarShown() end,
		func = function() ns.SetXPBarShown(not ns.IsXPBarShown()) end },
	{ text = "Announce in /say", checked = function() return ns.IsAnnounceOn("SAY") end,
		func = function() ns.SetAnnounceOn("SAY", not ns.IsAnnounceOn("SAY")) end },
	{ text = "Announce in party", checked = function() return ns.IsAnnounceOn("PARTY") end,
		func = function() ns.SetAnnounceOn("PARTY", not ns.IsAnnounceOn("PARTY")) end },
	{ divider = true },
	{ text = "|cffff4040Reset stats...|r", func = function() StaticPopup_Show("UGOTTIME_RESET_STATS") end },
	{ text = "Hide minimap button", func = function() ns.ToggleMinimapButton() end },
}

local ShowMenu
if MenuUtil and MenuUtil.CreateContextMenu then
	-- Newer clients
	ShowMenu = function(owner)
		MenuUtil.CreateContextMenu(owner, function(_, root)
			for _, item in ipairs(MENU) do
				if item.title then
					root:CreateTitle(item.title)
				elseif item.divider then
					root:CreateDivider()
				elseif item.checked then
					root:CreateCheckbox(item.text, item.checked, item.func)
				else
					root:CreateButton(item.text, item.func)
				end
			end
		end)
	end
else
	-- Older clients: classic dropdown menu at the cursor
	local dropdown = CreateFrame("Frame", "UGotTimeMinimapMenu", UIParent, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(dropdown, function(_, level)
		for _, item in ipairs(MENU) do
			if item.divider then
				if UIDropDownMenu_AddSeparator then
					UIDropDownMenu_AddSeparator(level)
				end
			else
				local info = UIDropDownMenu_CreateInfo()
				info.text = item.title or item.text
				info.isTitle = item.title and true or nil
				info.notCheckable = not item.checked
				if item.checked then
					info.checked = item.checked()
					info.isNotRadio = true
					info.keepShownOnClick = true
				end
				info.func = item.func
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end, "MENU")
	ShowMenu = function()
		ToggleDropDownMenu(1, nil, dropdown, "cursor", 0, 0)
	end
end

button:SetScript("OnClick", function(self, mouseButton)
	if mouseButton == "RightButton" then
		GameTooltip:Hide()
		ShowMenu(self)
	else
		ns.ToggleStats()
	end
end)

button:SetScript("OnEnter", function(self)
	local level, progress, needed = ns.GetLevelInfo()
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("U Got Time")
	GameTooltip:AddLine(("Level %d  -  %d / %d XP"):format(level, progress, needed), 1, 1, 1)
	GameTooltip:AddLine("Left-click: Stats", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Right-click: Menu", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Drag: move", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", GameTooltip_Hide)

function ns.ToggleMinimapButton()
	local settings = GetMinimapSettings()
	settings.hide = not settings.hide
	button:SetShown(not settings.hide)
	if settings.hide then
		print("U Got Time: minimap button hidden. Type /ugt minimap to show it again.")
	end
end

-- SavedVariables are only available after login
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	UpdatePosition()
	button:SetShown(not GetMinimapSettings().hide)
end)
