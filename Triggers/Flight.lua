local _, ns = ...

local destination
local onFlight = false
local flightReps        -- reps saved during the current flight, announced on landing
local waitingForSave = false -- landed before the popup was saved

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

-- This client has no reliable events for taking off and landing (PLAYER_CONTROL_LOST/GAINED
-- are gone), so check UnitOnTaxi once a second and right after picking a flight path
local function CheckTaxi()
	local onTaxi = UnitOnTaxi("player") and true or false
	if onTaxi == onFlight then
		return
	end
	onFlight = onTaxi
	if onTaxi then -- took off
		flightReps = nil
		waitingForSave = false
		ns.ShowFlightPopup()
	elseif flightReps then -- landed
		Announce(flightReps, false)
		flightReps = nil
	else
		waitingForSave = true
	end
end

-- Remember where the player chose to fly, and look for the take-off right away
hooksecurefunc("TakeTaxiNode", function(index)
	destination = TaxiNodeName(index)
	C_Timer.After(0.5, CheckTaxi)
	C_Timer.After(1.5, CheckTaxi)
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	-- Already flying after a /reload: don't show the popup again for this flight
	onFlight = UnitOnTaxi("player") and true or false
	C_Timer.NewTicker(1, CheckTaxi)
end)
