local _, ns = ...

function ns.GetQuestCount()
	return UGotTimeDB and UGotTimeDB.questCount or 0
end

function ns.ShowQuestPopup(source)
	ns.ShowPopup("Quest Workout!", ns.GetQuestsPerWorkout() .. " quests done!", source or "quest")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:SetScript("OnEvent", function()
	-- Counter is saved per character so it survives reloads and logouts
	UGotTimeDB = UGotTimeDB or {}
	UGotTimeDB.questCount = (UGotTimeDB.questCount or 0) + 1
	if UGotTimeDB.questCount >= ns.GetQuestsPerWorkout() then
		UGotTimeDB.questCount = 0
		ns.ShowQuestPopup()
	end
end)
