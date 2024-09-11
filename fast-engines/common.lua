local storage = {}

function getData(element, key)
	return storage[element] and storage[element][key] or false
end

function setData(element, key, value)
	storage[element] = storage[element] or {}
	storage[element][key] = value
	return getData(element, key)
end

function clearData(element)
	if not storage[element] then
		return false
	end
	for key, value in pairs(storage[element]) do
		if isElement(value) then
			destroyElement(value)
		end
		if isTimer(value) then
			killTimer(value)
		end
	end
	storage[element] = nil
	return true
end

function math.lerp(from, to, speed)
	return from + (to - from) * speed;
end

function math.clamp(number, min, max)
	if number < min then
		return min
	elseif number > max then
		return max
	end
	return number
end

function math.scale(number, min, max)
	return (number + min) / (max + min)
end

local function guessHex(byte, value)
	return "0x" .. string.reverse(string.format("%0" .. byte .. "x", value))
end

local function getVehicleHandlingFlags(vehicle, flags, byte, value)
	return bitAnd(getVehicleHandling(vehicle, flags), guessHex(byte, value)) ~= 0
end

function getVehicleMaxVelocity(vehicle)
	local maxSpeed = getVehicleHandling(vehicle, "maxVelocity")
	return getVehicleHandlingFlags(vehicle, "handlingFlags", 7, 1) and maxSpeed or (maxSpeed + 0.2 * maxSpeed)
end

function getPositionFromElementOffset(element, offX, offY, offZ)
	local m = getElementMatrix(element)
	local x = offX * m[1][1] + offY * m[2][1] + offZ * m[3][1] + m[4][1]
	local y = offX * m[1][2] + offY * m[2][2] + offZ * m[3][2] + m[4][2]
	local z = offX * m[1][3] + offY * m[2][3] + offZ * m[3][3] + m[4][3]
	return x, y, z
end

local attachedEffects = {}
function attachEffect(effect, element, x, y, z)
	attachedEffects[effect] = { element = element, x = x, y = y, z = z }
	addEventHandler("onClientElementDestroy", effect, function()
		attachedEffects[effect] = nil
	end)
	addEventHandler("onClientElementDestroy", element, function()
		attachedEffects[effect] = nil
	end)
	return true
end

addEventHandler("onClientPreRender", root, function()
	for fx, data in pairs(attachedEffects) do
		local px, py, pz = getPositionFromElementOffset(data.element, data.x, data.y, data.z)
		local rx, ry, rz = getElementRotation(data.element)
		setElementPosition(fx, px, py, pz)
		setElementRotation(fx, 270 + (360 - rx), 360 - ry, 360 - rz)
	end
end)

function fxAddBackfire(vehicle, sound)
	if not (vehicle and isElement(vehicle)) then
		return false
	end

	local x, y, z = getVehicleDummyPosition(vehicle, "exhaust")
	if getVehicleHandlingFlags(vehicle, "modelFlags", 4, 1) or not x then
		return false
	end

	local fx = createEffect("gunflash", x, y, z)
	attachEffect(fx, vehicle, x, y, z)

	if getVehicleHandlingFlags(vehicle, "modelFlags", 4, 2) then
		local fx = createEffect("gunflash", -x, y, z)
		attachEffect(fx, vehicle, -x, y, z)
	end

	if sound then
		local audio = playSound3D("audio/extras/als" .. math.random(3) .. ".ogg", 0, y, 0, false)
		attachElements(audio, vehicle, 0, y, 0)
		setSoundVolume(audio, config.als.volume)
		setSoundMaxDistance(audio, config.als.distance)
	end
	return true
end

local blacklist = {
	['Bike'] = true,
	['BMX'] = true,
	['Quad'] = true,
	['Monster Truck'] = true,
	['Helicopter'] = true,
	['Plane'] = true
}

function isVehicleReallyOnGround(vehicle)
	if getVehicleType(vehicle) == "Bike" then
		return isVehicleWheelOnGround(vehicle, 0) or isVehicleWheelOnGround(vehicle, 1)
	end

	local driveType = getVehicleHandling(vehicle, "driveType")
	local fwd = isVehicleWheelOnGround(vehicle, 0) or isVehicleWheelOnGround(vehicle, 1)
	local rwd = isVehicleWheelOnGround(vehicle, 2) or isVehicleWheelOnGround(vehicle, 3)
	local awd = fwd or rwd

	if driveType == "fwd" then return fwd end
	if driveType == "rwd" then return rwd end
	if driveType == "awd" then return awd end
end

function isVehicleSliding(vehicle)
	if blacklist[getVehicleType(vehicle)] then
		return false
	end

	local driveType = getVehicleHandling(vehicle, "driveType")
	local fwd = getVehicleWheelFrictionState(vehicle, 0) == 1 and getVehicleWheelFrictionState(vehicle, 2) == 1
	local rwd = getVehicleWheelFrictionState(vehicle, 1) == 1 and getVehicleWheelFrictionState(vehicle, 3) == 1
	local awd = fwd or rwd or
		(getVehicleWheelFrictionState(vehicle, 1) ~= 0 and getVehicleWheelFrictionState(vehicle, 3) ~= 0)

	if driveType == "fwd" then return fwd end
	if driveType == "rwd" then return rwd end
	if driveType == "awd" then return awd end
end

function getDrift(vehicle)
	if not isVehicleReallyOnGround(vehicle) then
		return 0
	end
	local x, y = getElementVelocity(vehicle)
	local rot = math.rad(select(3, getElementRotation(vehicle)))
	local sn, cs = math.sin(rot), math.cos(rot)
	local cosx = (-sn * x + cs * y) / math.sqrt(x ^ 2 + y ^ 2)
	local drift = math.deg(math.acos(cosx))
	if drift ~= drift then
		return 0
	end
	return math.clamp(drift / 20, 0, 1)
end

local function stopEngine(vehicle)
	clearData(vehicle)

	if isElement(vehicle) then
		setElementData(vehicle, config.rpmKey, nil, false)
	end
end

local function isElegible(vehicle)
	if not (isElement(vehicle) and getElementType(vehicle) == "vehicle") then
		return false
	end
	if not (isElementStreamedIn(vehicle) and not isVehicleBlown(vehicle)) then
		return false
	end
	if not info[config.getVehicleModel(vehicle)] then
		return false
	end
	return true
end

local function processVehicles()
	for vehicle in pairs(vehicles) do
		if not isElegible(vehicle) then
			stopEngine(vehicle)
			vehicles[vehicle] = nil
		end
	end

	local x, y, z = getElementPosition(localPlayer)
	local i, d = getElementInterior(localPlayer), getElementDimension(localPlayer)
	local newVehicles = getElementsWithinRange(x, y, z, config.engine.distance, "vehicle", i, d)
	for _, vehicle in ipairs(newVehicles) do
		if isElegible(vehicle) then
			vehicles[vehicle] = true
		end
	end

	for vehicle in pairs(vehicles) do
		calculateEngine(vehicle)
	end
end

addEventHandler("onClientResourceStop", resourceRoot, function()
	setWorldSoundEnabled(19, 37, true)
	--setWorldSoundEnabled(19, 19, true)
	--setWorldSoundEnabled(19, 20, true)
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
	setTimer(processVehicles, 30, 0)

	setWorldSoundEnabled(19, 37, false)
	--setWorldSoundEnabled(19, 19, false)
	--setWorldSoundEnabled(19, 20, false)
end)
