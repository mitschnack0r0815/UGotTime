local _, ns = ...

SLASH_UGOTTIME1 = "/ugt"
SlashCmdList["UGOTTIME"] = function(msg)
	if msg == "quest" then
		ns.ShowQuestPopup("manual")
	elseif msg == "count" then
		print("U Got Time: " .. ns.GetQuestCount() .. "/" .. ns.QUESTS_PER_WORKOUT .. " quests toward next workout")
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
