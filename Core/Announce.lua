local _, ns = ...

-- "since u asked, I did 20 push-ups and 15 squats <context>"
local PREFIX = "{circle} UGotTime: "

local function BuildMessage(reps, context)
	local parts = {}
	for _, ex in ipairs(ns.GetAllExercises()) do
		if reps[ex.key] then
			tinsert(parts, reps[ex.key] .. " " .. ex.name:lower())
		end
	end
	local list = parts[#parts]
	if #parts > 1 then
		list = table.concat(parts, ", ", 1, #parts - 1) .. " and " .. list
	end
	return PREFIX .. "since u asked, I did " .. list .. " " .. context
end

-- Each channel can be turned off in the options; stored as UGotTimeSettings.noSay / noParty
-- so both start out on
local SETTING_KEYS = { SAY = "noSay", PARTY = "noParty" }

function ns.IsAnnounceOn(channel)
	return not ns.GetSettings()[SETTING_KEYS[channel]]
end

function ns.SetAnnounceOn(channel, on)
	ns.GetSettings()[SETTING_KEYS[channel]] = (not on) or nil
end

-- Posts to party (if grouped) and say, unless turned off. SAY outside instances needs a click
-- or key press: from a click we send directly, from an event we put the text in the chat box
-- so Enter sends it. PARTY has no such restriction.
local function Post(msg, fromClick)
	if IsInGroup() and ns.IsAnnounceOn("PARTY") then
		SendChatMessage(msg, "PARTY")
	end
	if not ns.IsAnnounceOn("SAY") then
		return
	end
	if fromClick then
		SendChatMessage(msg, "SAY")
	else
		ChatFrame_OpenChat("/s " .. msg)
	end
end

function ns.SayWorkout(reps, context, fromClick)
	Post(BuildMessage(reps, context), fromClick)
end

-- Level ups only happen when a workout is saved, which is always a click
function ns.AnnounceLevelUp(level)
	Post(PREFIX .. ("reached level %d!"):format(level), true)
	RaidNotice_AddMessage(RaidWarningFrame, ("U Got Time: Level %d!"):format(level), ChatTypeInfo["RAID_WARNING"])
end
