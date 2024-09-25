vehicles = {}

local function clampAndSmooth(vehicle, rpm, min, max, tbl)
	local lastRPM = getData(vehicle, "enginerpm") or rpm

	local smooth = tbl or config.engine.smoother
	local newRPM
	if lastRPM < rpm then
		newRPM = lastRPM + smooth[1]
	else
		newRPM = lastRPM + smooth[2]
	end

	if lastRPM < rpm then
		lastRPM = math.min(newRPM, rpm)
	else
		lastRPM = math.max(newRPM, rpm)
	end

	return setData(vehicle, "enginerpm", math.clamp(lastRPM, min, max))
end

local exception = {
	[17] = true,
	[19] = true,
	[6] = true,
	[5] = true,

	[11] = {
		[2] = true,
	},
	[15] = {
		[2] = true,
	},
	[40] = {
		[3] = true,
	},
}

local blacklist = {
	[539] = true,
	Plane = true,
	Helicopter = true,
	Boat = true,
	Train = true,
	Trailer = true,
	BMX = true,
}

addEventHandler("onClientWorldSound", root, function(group, index)
	if getElementType(source) ~= "vehicle" or wasEventCancelled() then
		return
	end
	if type(exception[group]) == "table" and exception[group][index] then
		return
	end
	if type(exception[group]) ~= "table" and exception[group] then
		return
	end
	if blacklist[config.getVehicleModel(source)] or blacklist[getVehicleType(source)] then
		return
	end
	if vehicles[source] or info[config.getVehicleModel(source)] then
		return cancelEvent()
	end
end)

function calculateEngine(vehicle)
	local info = info[config.getVehicleModel(vehicle)]
	info.ratio = info.ratio or 0.5

	local engine = getData(vehicle, "engine")
	if not isElement(engine) then
		engine = info.isDefault and playSFX3D("genrl", info.audio, 0, 0, 0, 0, true)
			or playSound3D(info.audio, 0, 0, 0, true)
		setData(vehicle, "engine", engine)

		setElementDimension(engine, getElementDimension(vehicle))
		setElementInterior(engine, getElementInterior(vehicle))
		attachElements(engine, vehicle, getVehicleDummyPosition(vehicle, "engine"))
		setSoundSpeed(engine, 0.01)
		setSoundVolume(engine, config.engine.volume)
		setSoundMaxDistance(engine, config.engine.distance)
	end

	local idle = getData(vehicle, "idle")
	if info.idle and not isElement(idle) then
		idle = info.isDefault and playSFX3D("genrl", info.idle, 1, 0, 0, 0, true)
			or playSound3D(info.idle, 0, 0, 0, true)
		setData(vehicle, "idle", idle)

		setElementDimension(idle, getElementDimension(vehicle))
		setElementInterior(idle, getElementInterior(vehicle))
		attachElements(idle, vehicle, getVehicleDummyPosition(vehicle, "engine"))
		setSoundSpeed(idle, info.isDefault and 0.85 or 1)
		setSoundVolume(idle, config.engine.volume)
		setSoundMaxDistance(idle, 0.4 * config.engine.distance)
	end

	local driver = getVehicleController(vehicle)
	local accel = driver and getPedAnalogControlState(driver, "accelerate") or 0
	local brake = driver and getPedAnalogControlState(driver, "brake_reverse") or 0
	local handbrake = driver and getPedControlState(driver, "handbrake") or false

	local x, y, z = getElementVelocity(vehicle)
	local velocity = (x * x + y * y + z * z)

	local realVelocity = velocity ^ 0.5 * 180
	local realGear = getVehicleCurrentGear(vehicle)
	local maxGears = getVehicleHandling(vehicle, "numberOfGears")

	local _gearRatio = info.ratio
	local fakeGear = realGear
	if getVehicleHandling(vehicle, "engineType") == "electric" and config.oneGearEVs then
		fakeGear = 5
		_gearRatio = 0.2
	end

	local ratio = (info.gearRatio and info.gearRatio[fakeGear])
		or (config.engine.ratio and config.engine.ratio[fakeGear])
		or 1

	local gearRatio = fakeGear
	if realGear == 0 then
		fakeGear = config.engine.ratio[0]
	end

	local state = getVehicleEngineState(vehicle)
	local speed = 0
	if state then
		local isSliding = (driver and getPedControlState(driver, "accelerate")) and isVehicleSliding(vehicle)
		if
			(velocity <= 0.01 and realGear == 1) and (isSliding or handbrake or not isVehicleReallyOnGround(vehicle))
		then
			speed = accel * info.accel
		else
			local newAccel = math.lerp(
				math.lerp(info.decel, info.accel, accel),
				info.slide,
				isSliding and accel * getDrift(vehicle) or 0
			)
			if isSliding then
				velocity = velocity + accel * (1 - math.min(velocity, 0.06) / 0.06)
			end
			speed = newAccel * ratio * velocity ^ _gearRatio * (isSliding and config.engine.launchRatio[fakeGear] or 1)
		end
		speed = speed / fakeGear / getVehicleMaxVelocity(vehicle) * config.engine.fixRatio[maxGears]
	end

	local rpm = clampAndSmooth(vehicle, speed, state and info.min or 0.01, info.max, info.smoother)
	local relativeRPM = math.scale(rpm, info.min, info.max)

	if idle then
		if state then
			local idleVol = 0.7 * config.engine.volume * (1 - math.min(velocity * 100, 1)) * (1 - relativeRPM)
			setSoundVolume(idle, idleVol)
		else
			setSoundVolume(idle, 0)
		end
	end

	setSoundSpeed(engine, (info.mult or 1) * (info.isDefault and 1.5 or 1) * rpm)

	local vol = math.lerp(0.7 * config.engine.volume, config.engine.volume, accel)
	setSoundVolume(engine, vol)

	doExtras(vehicle, accel, brake)
	revEffect(vehicle, info, vol, realVelocity)
	setElementData(vehicle, config.rpmKey, relativeRPM, false)
end
