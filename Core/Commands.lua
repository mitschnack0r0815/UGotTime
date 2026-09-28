local _, ns = ...

SLASH_UGOTTIME1 = "/ugt"
SlashCmdList["UGOTTIME"] = function(msg)
	if msg == "quest" then
		ns.ShowQuestPopup("manual")
	elseif msg == "count" then
		print("U Got Time: " .. ns.GetQuestCount() .. "/" .. ns.GetQuestsPerWorkout() .. " quests toward next workout")
	elseif msg:match("^quests") then
		-- /ugt quests 3 sets how many quests trigger a workout
		local count = tonumber(msg:match("^quests%s+(%d+)$"))
		if count then
			count = ns.SetQuestsPerWorkout(count)
			ns.RefreshOptionsTab()
		end
		print(("U Got Time: a workout pops up after every %d quests. Change it with /ugt quests <%d-%d>."):format(
			ns.GetQuestsPerWorkout(), ns.MIN_QUESTS_PER_WORKOUT, ns.MAX_QUESTS_PER_WORKOUT))
	elseif msg == "stats" then
		ns.ToggleStats()
	elseif msg == "config" then
		ns.ToggleOptions()
	elseif msg == "minimap" then
		ns.ToggleMinimapButton()
	else
		ns.ShowFlightPopup("manual")
	end
end
