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

-- Posts to party (if grouped) and say. SAY outside instances needs a click or key press:
-- from a click we send directly, from an event we put the text in the chat box so Enter sends it.
-- PARTY has no such restriction.
local function Post(msg, fromClick)
	if IsInGroup() then
		SendChatMessage(msg, "PARTY")
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
	Post(PREFIX .. ("reached UGotTime level %d!"):format(level), true)
	RaidNotice_AddMessage(RaidWarningFrame, ("U Got Time: Level %d!"):format(level), ChatTypeInfo["RAID_WARNING"])
end
