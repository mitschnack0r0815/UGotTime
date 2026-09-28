local _, ns = ...

local destination
local onFlight = false
local flightReps        -- reps saved during the current flight, announced on landing
local waitingForSave = false -- landed before the popup was saved

-- Remember where the player chose to fly
hooksecurefunc("TakeTaxiNode", function(index)
	destination = TaxiNodeName(index)
end)

function ns.ShowFlightPopup(source)
	ns.ShowPopup("Flight Workout!", destination and ("Heading to " .. destination), source or "flight")
end

-- "... on my flight to Orgrimmar"; the landing event can't send SAY itself, a Save click can
local function Announce(reps, fromClick)
	ns.SayWorkout(reps, "on my flight" .. (destination and (" to " .. destination) or ""), fromClick)
end

-- Called by the popup when a flight workout is saved with at least one rep (always from a click)
function ns.FlightWorkoutSaved(reps)
	if onFlight then
		flightReps = reps
	elseif waitingForSave then
		waitingForSave = false
		Announce(reps, true)
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_CONTROL_LOST")
frame:RegisterEvent("PLAYER_CONTROL_GAINED")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_CONTROL_LOST" then
		if UnitOnTaxi("player") then
			onFlight = true
			flightReps = nil
			waitingForSave = false
			ns.ShowFlightPopup()
		end
	elseif onFlight then -- landed
		onFlight = false
		if flightReps then
			Announce(flightReps, false)
			flightReps = nil
		else
			waitingForSave = true
		end
	end
end)
