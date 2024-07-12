local function smoothRPM(vehicle, rpm)
	local currentRPM = getData(vehicle, "turborpm") or 0
	local nRPM = currentRPM + (currentRPM < rpm and 0.08 or -0.2)
	currentRPM = currentRPM < rpm and math.min(nRPM, rpm) or math.max(nRPM, rpm)
	local final = math.clamp(currentRPM, 0, 1)
	setData(vehicle, "turborpm", final)
	return final
end

function wait(element, time)
	local waited = getData(element, "wait") or setData(element, "wait", getTickCount() + time)
    if getTickCount() >= waited then
        setData(element, "wait", nil)
		return true
    end
    return false
end

function revEffect(vehicle, rpm, info, volume, speed)
	if not info.rev then
		return
	end

	local data = getElementData(vehicle, config.tunningKey)

	local engine = getData(vehicle, "engine")
	if rpm >= info.max then
		local currentTime = (getData(vehicle, "currentTime") or 0) + 0.5

		local trembleAccumulation = (getData(vehicle, "trembleAccumulation") or 0) + 0.05
		trembleAccumulation = math.min(trembleAccumulation, 1)

		
		setData(vehicle, "currentTime", currentTime)
		setData(vehicle, "trembleAccumulation", trembleAccumulation)

		if data and data.als and speed < 12 and trembleAccumulation > 0.8 and wait(vehicle, math.random(300)) then
			fxAddBackfire(vehicle, true)
		end

		local newVolume = volume + math.sin(currentTime * (info.rev.frequency or config.rev.frequency)) * (info.rev.amplitude or config.rev.amplitude) * trembleAccumulation
		setSoundVolume(engine, newVolume)
	else
		setSoundVolume(engine, volume)
		setData(vehicle, "trembleAccumulation", nil)
	end
end

function doExtras(vehicle, eRpm, accel, brake)
	local data = getElementData(vehicle, config.tunningKey)
	if not data then
		return
	end

	local turbo = getData(vehicle, "turbo")
	if data.turbo then
		if not isElement(turbo) then
			local enginePos = select(2, getVehicleDummyPosition(vehicle, "engine"))
			local sound = playSound3D("audio/extras/turbo.wav", 0, 0, 0, true)
			setSoundSpeed(sound, 1.4)
			attachElements(sound, vehicle, 0, enginePos, 0)
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
	if eRpm >= config.turbo.enable and accel > config.turbo.enable then
		rpm = rpm + 2
	else
		rpm = rpm - 0.4
	end
	rpm = smoothRPM(vehicle, math.clamp(rpm, 0, 1))
	setData(vehicle, "turborpm", rpm)

	if data.turbo and isElement(turbo) then
		setSoundVolume(turbo, config.turbo.volume * rpm)
	end

	if data.blowoff then
		if getData(vehicle, "turborpm") > config.blowoff.enable and accel < config.blowoff.enable then
			setData(vehicle, "turborpm", 0)

			if data.turbo then
				local enginePos = select(2, getVehicleDummyPosition(vehicle, "engine"))
				local sound = playSound3D("audio/extras/turbo_shift1.wav", 0, 0, 0, false)
				attachElements(sound, vehicle, 0, enginePos, 0)
				setSoundVolume(sound, config.blowoff.volume)
				setSoundMaxDistance(sound, config.blowoff.distance)
			end

			for times = 1, math.random(3) do
				setTimer(fxAddBackfire, times * math.random(120), 1, vehicle, true)
			end
		end
	end

	local gear = getVehicleCurrentGear(vehicle)

	setData(vehicle, "gear", getData(vehicle, "gear") or gear)
	if eRpm > config.als.enable and getData(vehicle, "gear") ~= gear then
		setData(vehicle, "gear", gear)
		if getData(vehicle, "turbo") then
			setData(vehicle, "turborpm", 0)
		end

		if data.als then
			for times = 1, math.random(3) do
				setTimer(fxAddBackfire, times * math.random(170), 1, vehicle, true)
			end
		end
	end
end