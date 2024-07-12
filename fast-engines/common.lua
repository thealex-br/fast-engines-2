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

local smooths = {}
function smooth(value, speed, name)
	if not smooths[name] then
		smooths[name] = value
	end
	smooths[name] = math.lerp(smooths[name], value, speed)
	return smooths[name]
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

function guessHex(byte, value)
	return "0x" .. string.reverse(string.format("%0" .. byte .. "x", value))
end

function getVehicleHandlingFlags(vehicle, flags, byte, value)
	local hnd = getVehicleHandling(vehicle)[flags]
	return bitAnd(hnd, guessHex(byte, value)) ~= 0
end

function getVehicleMaxVelocity(vehicle)
	local maxSpeed = getVehicleHandling(vehicle).maxVelocity
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
function attachEffect(effect, element, pos)
	attachedEffects[effect] = { effect = effect, element = element, pos = pos }
	addEventHandler("onClientElementDestroy", effect, function()
		attachedEffects[effect] = nil
	end)
	addEventHandler("onClientElementDestroy", element, function()
		attachedEffects[effect] = nil
	end)
	return true
end

addEventHandler("onClientPreRender", root, function()
	for fx, info in pairs(attachedEffects) do
		local px, py, pz = getPositionFromElementOffset(info.element, info.pos.x, info.pos.y, info.pos.z)
		local rx, ry, rz = getElementRotation(info.element)
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

	local fx = createEffect("gunflash", 0, 0, 0, 0, 0, 0, 8191)
	attachEffect(fx, vehicle, Vector3(x, y, z))

	if getVehicleHandlingFlags(vehicle, "modelFlags", 4, 2) then
		local fx = createEffect("gunflash", 0, 0, 0, 0, 0, 0, 8191)
		attachEffect(fx, vehicle, Vector3(-x, y, z))
	end

	if sound then
		local audio = playSound3D("audio/extras/als" .. math.random(3) .. ".ogg", 0, 0, 0, false)
		attachElements(audio, vehicle, 0, y, 0)
		setSoundVolume(audio, config.als.volume)
		setSoundMaxDistance(audio, config.als.distance)
	end
	return true
end

function isVehicleWheelsOnGround(vehicle)
	if getVehicleType(vehicle) == "Bike" then
		return isVehicleWheelOnGround(vehicle, 0) or isVehicleWheelOnGround(vehicle, 1)
	end

	local states = {
		fl = isVehicleWheelOnGround(vehicle, 0),
		fr = isVehicleWheelOnGround(vehicle, 2),
		rl = isVehicleWheelOnGround(vehicle, 1),
		rr = isVehicleWheelOnGround(vehicle, 3)
	}
	local lockup = {
		['rwd'] = states.fr or states.rr,
		['awd'] = (states.fr or states.rr) or (states.fl or states.rl),
		['fwd'] = states.fl or states.rl
	}
	return lockup[getVehicleHandling(vehicle).driveType]
end

local blacklist = {
	['Bike'] = true,
	['BMX'] = true,
	['Quad'] = true,
	['Monster Truck'] = true,
	['Helicopter'] = true,
	['Plane'] = true
}

function isTractionState(vehicle, rear, front)
	if blacklist[getVehicleType(vehicle)] then
		return false
	end
	local states = {
		fl = getVehicleWheelFrictionState(vehicle, 0),
		fr = getVehicleWheelFrictionState(vehicle, 2),
		rl = getVehicleWheelFrictionState(vehicle, 1),
		rr = getVehicleWheelFrictionState(vehicle, 3)
	}
	local lockup = {
		rwd = states.rl == rear and states.rr == rear,
		awd = (states.rl == rear and states.rr == rear) or (states.fl == front and states.fr == front),
		fwd = states.fl == front and states.fr == front
	}
	return lockup[getVehicleHandling(vehicle).driveType]
end

function getDrift(vehicle)
	if not isVehicleWheelsOnGround(vehicle) then
		return 0
	end
	local x, y = getElementVelocity(vehicle)
	local radRot = math.rad(select(3, getElementRotation(vehicle)))
	local sn, cs = -math.sin(radRot), math.cos(radRot)
	local cosx = (sn * x + cs * y) / math.sqrt(x * x + y * y)
	local acos = math.acos(cosx)
	return math.min(math.deg(acos) / 15, 1) -- Use math.min() to clamp the result
end

local function stopEngine(vehicle)
	clearData(vehicle)

	if isElement(vehicle) then
		setElementData(vehicle, config.rpmKey, nil, false)
	end

	smooths[vehicle] = nil
	vehicles[vehicle] = nil
end

local function isElegible(vehicle)
	if not (isElement(vehicle) and getElementType(vehicle) == "vehicle") then
		return false
	end
	if not (getVehicleController(vehicle) and isElementStreamedIn(vehicle) and not isVehicleBlown(vehicle)) then
		return false
	end
	return true
end

local function findVehicles()
	local x, y, z = getElementPosition(localPlayer)
	local int, dim = getElementInterior(localPlayer), getElementDimension(localPlayer)

	for vehicle in pairs(vehicles) do
		if not isElegible(vehicle) then
			stopEngine(vehicle)
		end
	end

	local newVehicles = getElementsWithinRange(x, y, z, config.engine.distance, "vehicle", int, dim)
	for _, vehicle in ipairs(newVehicles) do
		if isElegible(vehicle) then
			vehicles[vehicle] = true
		end
	end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
	findVehicles()
	setTimer(findVehicles, config.wait, 0)
	setTimer(doEngineSound, config.wait, 0)
end)
