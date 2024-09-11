local function clampAndSmooth(vehicle, rpm)
	local lastRPM = getData(vehicle, "turborpm") or rpm

	local newRPM
	if lastRPM < rpm then
		newRPM = lastRPM + 0.08
	else
		newRPM = lastRPM - 0.2
	end

	if lastRPM < rpm then
		lastRPM = math.min(newRPM, rpm)
	else
		lastRPM = math.max(newRPM, rpm)
	end

	return setData(vehicle, "turborpm", math.clamp(lastRPM, 0, 1))
end

function wait(theElement, timeToWait)
	local timeRemaining = getData(theElement, "wait") or setData(theElement, "wait", getTickCount() + timeToWait)
	if getTickCount() >= timeRemaining then
		setData(theElement, "wait", nil)
		return true
	end
	return false
end

function revEffect(vehicle, info, volume, realVelocity)
	local data = getElementData(vehicle, config.tunningKey) or {}

	local driver = getVehicleController(vehicle)
	local accel = driver and getPedControlState(driver, "accelerate")

	local engine = getData(vehicle, "engine")
	if getData(vehicle, "enginerpm") >= info.max and accel then
		local revAccumulation = getData(vehicle, "revAccumulation") or 0
		revAccumulation = math.min(revAccumulation + 0.05, info.rev.limit or 0.8)

		local alternate = setData(vehicle, "alternate", not getData(vehicle, "alternate"))
		alternate = alternate and 0.5 or 1.17

		setData(vehicle, "revAccumulation", revAccumulation)
		local revFrequency = volume
			+ math.sin(alternate * (info.rev.frequency or config.rev.frequency))
			* (info.rev.amplitude or config.rev.amplitude)
			* revAccumulation

		triggerEvent("onClientVehicleRev", vehicle, getData(vehicle, "enginerpm"), revAccumulation, revFrequency)
		setSoundVolume(engine, revFrequency)
	else
		setSoundVolume(engine, volume)
		setData(vehicle, "revAccumulation", nil)
	end
end

function doExtras(vehicle, accel, brake)
	local data = getElementData(vehicle, config.tunningKey) or {}

	local turbo = getData(vehicle, "turbo")
	if data.turbo then
		if not isElement(turbo) then
			local sound = playSound3D("audio/extras/turbo.wav", 0, 0, 0, true)
			attachElements(sound, vehicle, getVehicleDummyPosition(vehicle, "engine"))
			setSoundSpeed(sound, 1.4)
			setSoundVolume(sound, config.turbo.volume)
			setSoundMaxDistance(sound, config.turbo.distance)

			setData(vehicle, "turbo", sound)
			setData(vehicle, "turborpm", 0)
		end
	elseif isElement(turbo) then
		destroyElement(turbo)
		setData(vehicle, "turbo", nil)
	end

	local rpm = getData(vehicle, "turborpm") or 0
	if getData(vehicle, "enginerpm") >= config.turbo.enable and accel > config.turbo.enable then
		rpm = rpm + 2
	else
		rpm = rpm - 0.4
	end
	rpm = clampAndSmooth(vehicle, math.clamp(rpm, 0, 1))
	setData(vehicle, "turborpm", rpm)

	if data.turbo and isElement(turbo) then
		setSoundVolume(turbo, config.turbo.volume * rpm)
	end

	if data.blowoff then
		if getData(vehicle, "turborpm") > config.blowoff.enable and accel < config.blowoff.enable then
			triggerEvent("onClientVehicleBlowoff", vehicle, getData(vehicle, "turborpm"))
			setData(vehicle, "turborpm", 0)
		end
	end

	local currGear = getVehicleCurrentGear(vehicle)
	local lastGear = getData(vehicle, "gear")
	if not lastGear then
		lastGear = setData(vehicle, "gear", currGear)
	end
	if lastGear ~= currGear then
		triggerEvent("onClientVehicleGearChange", vehicle, lastGear, currGear)
		setData(vehicle, "gear", currGear)
		if getData(vehicle, "turborpm") > config.als.enable then
			setData(vehicle, "turborpm", 0)
		end
	end
end

addEvent("onClientVehicleRev", true)
addEvent("onClientVehicleBlowoff", true)
addEvent("onClientVehicleGearChange", true)

addEventHandler("onClientVehicleRev", root, function(engineRPM, revAccumulation, revFrequency)
	local data = getElementData(source, config.tunningKey)
	if not data then
		return
	end

	local x, y, z = getElementVelocity(source)
	local velocity = (x * x + y * y + z * z) ^ 0.5 * 180

	if data.als and velocity < 12 and revAccumulation > 0 and wait(source, math.random(50, 300)) then
		fxAddBackfire(source, true)
	end
end)

addEventHandler("onClientVehicleBlowoff", root, function(turboRPM)
	local data = getElementData(source, config.tunningKey)
	if not data then
		return
	end

	if data.turbo then
		local sound = playSound3D("audio/extras/turbo_shift1.wav", 0, 0, 0, false)
		attachElements(sound, source, getVehicleDummyPosition(source, "engine"))
		setSoundVolume(sound, config.blowoff.volume)
		setSoundMaxDistance(sound, config.blowoff.distance)
	end

	if data.als and not isVehicleNitroActivated(source) then
		for times = 1, math.random(1, 3) do
			setTimer(fxAddBackfire, times * math.random(75, 150), 1, source, true)
		end
	end
end)

addEventHandler("onClientVehicleGearChange", root, function(lastGear, currGear)
	local data = getElementData(source, config.tunningKey)
	if not data then
		return
	end

	local turboRPM = getData(source, "turborpm")
	if data.als and turboRPM > config.als.enable and not isVehicleNitroActivated(source) then
		if data.als then
			for times = 1, math.random(1, 3) do
				setTimer(fxAddBackfire, times * math.random(100, 200), 1, source, true)
			end
		end
	end
end)
