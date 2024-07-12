vehicles = {}

local function smoothRPM(vehicle, rpm, min, max, smoother)
	local currentRPM = getData(vehicle, "enginerpm") or 0
	local smoothValues = smoother or config.engine.smoother
	local nRPM = currentRPM + (currentRPM < rpm and smoothValues[1] or smoothValues[2])
	currentRPM = currentRPM < rpm and math.min(nRPM, rpm) or math.max(nRPM, rpm)
	return setData(vehicle, "enginerpm", math.clamp(currentRPM, min, max))
end

local exception = {
	[17] = true,
	[19] = true,
	[6] = true,
	[5] = true
}

addEventHandler("onClientWorldSound", root, function(group)
	if not exception[group] and info[config.getVehicleModel(source)] then
		cancelEvent()
	end
end)

function doEngineSound()
	for vehicle in pairs(vehicles) do
		calculateEngine(vehicle)
	end
end

function calculateEngine(vehicle)
	local driver = getVehicleController(vehicle)
	if not driver then
		return false
	end

	local info = info[config.getVehicleModel(vehicle)]
	if not info then
		return false
	end


	local engine = getData(vehicle, "engine")
	if not isElement(engine) then
		engine = info.isDefault and playSFX3D("genrl", info.audio, 0, 0, 0, 0, true) or playSound3D(info.audio, 0, 0, 0, true)
		setData(vehicle, "engine", engine)

		local enginePos = select(2, getVehicleDummyPosition(vehicle, "engine"))

		setElementDimension(engine, getElementDimension(vehicle))
		setElementInterior(engine, getElementInterior(vehicle))
		attachElements(engine, vehicle, 0, enginePos, 0)

		setSoundSpeed(engine, 0.01)
		setSoundVolume(engine, config.engine.volume)
		setSoundMaxDistance(engine, config.engine.distance)

		if not hasElementData(vehicle, config.tunningKey) then
			setElementData(vehicle, config.tunningKey, {als=info.als, turbo=info.turbo, blowoff=info.blowoff})
		end
	end

	local accel, brake, handbrake = getPedAnalogControlState(driver, "accelerate"), getPedAnalogControlState(driver, "brake_reverse"), getPedControlState(driver, "handbrake")
	
	local x, y, z = getElementVelocity(vehicle)
	local velocity = (x * x + y * y + z * z)
	
	local maxGears = getVehicleHandling(vehicle).numberOfGears
	local gear = getVehicleCurrentGear(vehicle)
	local gearRatio = gear
	
	local ratio = (info.gearRatio and info.gearRatio[gearRatio]) or (config.engine.ratio and config.engine.ratio[gearRatio]) or 1
	
	if gear == 0 then
		gearRatio = config.engine.ratio[0]
	end
	
	local state = getVehicleEngineState(vehicle)
	local speed = 0

	if state then
		local isSliding = isTractionState(vehicle, 1, 1)

		if ((velocity ^ 0.5 * 180) <= 12 and gear == 1) and (isSliding or handbrake or not isVehicleWheelsOnGround(vehicle)) then
			speed = accel * info.accel
		else
			local driftAngle = isSliding and accel * getDrift(vehicle) or 0 -- raw drift
			local driftRatio = isSliding and driftAngle / gearRatio or 0 	-- less agressive
			local accelRatio = velocity ^ (info.ratio or 0.5) * (isSliding and config.engine.launchRatio[gear] or 1)

			speed = math.lerp(info.decel, info.accel, accel) * (ratio - driftRatio) * accelRatio + (driftAngle * info.slide)
		end
	end

	speed = speed / gearRatio / getVehicleMaxVelocity(vehicle) * config.engine.customGearRatio[maxGears]

	local rpm = smoothRPM(vehicle, speed, state and info.min or 0.01, info.max, info.smoother)
	local vol = math.lerp(0.7 * config.engine.volume, config.engine.volume, accel)

	setSoundSpeed(engine, (info.mult or 1) * (info.isDefault and 1.5 or 1) * rpm)
	setSoundVolume(engine, vol)

	doExtras(vehicle, rpm, accel, brake)
	revEffect(vehicle, rpm, info, vol, (velocity ^ 0.5 * 180))
	setElementData(vehicle, config.rpmKey, math.scale(rpm, info.min, info.max), false)
end