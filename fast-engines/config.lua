config = {
	getVehicleModel = function(vehicle)
		return getElementData(vehicle, "actualID") or getElementData(vehicle, "vehicleID") or getElementModel(vehicle)
	end,

	oneGearEVs = true,

	rpmKey = "vehicle:rpm", -- float between 0 and 1
	tunningKey = "vehicle:upgrades", -- table, uses the same structure as bengines
	--[[
	setElementData(vehicle, "vehicle:upgrades", {als=true, turbo=true, blowoff=true})
	setElementData(vehicle, "vehicle:upgrades", {als=true})
	]]

	engine = {
		distance = 60,
		volume = 0.2,
		smoother = { 0.055, -0.047 },

		rev = {
			frequency = 7,
			amplitude = 0.1,
		},

		launchRatio = {
			[1] = 1.7,
			[2] = 1.45,
			[3] = 1.0,
			[4] = 1.0,
			[5] = 1.0,
		},

		fixRatio = { -- hardcoded attempt to fix the engine revving too much with lower gears
			[1] = 0.2,
			[2] = 0.4,
			[3] = 0.6,
			[4] = 0.8,
			[5] = 1.0,
		},

		ratio = {
			[0] = 1.7,
			[1] = 1.12,
			[2] = 1.07,
			[3] = 1.0,
			[4] = 0.97,
			[5] = 0.95,
		},
	},

	als = {
		distance = 30,
		volume = 1.0,
		enable = 0.78, -- minimum rpm to backfire when changing gears
	},

	turbo = {
		distance = 40,
		volume = 0.5,
		enable = 0.73, -- minimum rpm to activate the turbo
	},

	blowoff = {
		distance = 40,
		volume = 0.1,
		enable = 0.78, -- minimum rpm to blowoff valve
	},
}

--[[

isDefault				= bool, if true the vehicle will use the default sounds
(optional) ratio		= number, from 0 to 1, 0.5 if not used
accel					= number, from 0 to 1000, value for acceleration
slide					= number, from 0 to 1000, value for drifting
decel					= number, from 0 to 1000, value for deceleration
max						= number, from 0 to 1, maximum vehicle rpm
min						= number, from 0 to 1, minimal vehicle rpm
(optional) smoother		= table, like 'smoother={0.067, -0.048}'
audio					= string, path to vehicle sound
(optional) idle			= string, path to vehicle sound
(optional) gearRatio	= table, same structure as config.engine.ratio, also works with incomplete tables: {[2] = 1.07, [5] = 0.82}
(optional) als			= bool
(optional) turbo		= bool
(optional) blowoff		= bool

[vehicleID] = {ratio, gearRatio, accel, decel, slide, max, min, audio, smoother, als, turbo, blowoff}
]]

info = {
	[836] = {
		isDefault = true,
		ratio = 0.53,
		accel = 1000,
		slide = 1150,
		decel = 870,
		max = 1.0,
		min = 0.03,
		smoother = { 0.07, -0.05 },
		audio = 93,
		rev = {
			frequency = 5,
			amplitude = 0.17,
		},
	},
	[838] = {
		isDefault = true,
		ratio = 0.53,
		accel = 1000,
		slide = 1150,
		decel = 870,
		max = 1.0,
		min = 0.03,
		smoother = { 0.07, -0.05 },
		audio = 18,
		rev = {
			frequency = 5,
			amplitude = 0.17,
		},
	},
	[839] = {
		isDefault = true,
		ratio = 0.53,
		accel = 1000,
		slide = 1150,
		decel = 870,
		max = 1.0,
		min = 0.03,
		mult = 0.8,
		smoother = { 0.07, -0.05 },
		audio = 38,
		rev = {
			frequency = 5,
			amplitude = 0.17,
		},
	},
	[840] = {
		isDefault = true,
		ratio = 0.53,
		accel = 1000,
		slide = 1150,
		decel = 870,
		max = 1.0,
		min = 0.03,
		mult = 0.8,
		smoother = { 0.07, -0.05 },
		audio = 38,
		rev = {
			frequency = 5,
			amplitude = 0.17,
		},
	},
}

function table.contains(table, element)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

defaultSounds = {
	[0] = {
		"Euros",
		"Elegy",
		"ZR-350",
		"Uranus",
		"Cadrona",
		"Bravura",
		"Merit",
		"Mesa",
		"Nebula",
		"Previon",
		"Primo",
		"Solair",
	},
	[9] = { "Bullet", "Glendale", "Glendale Damaged", "Oceanic", "Tornado" },
	[95] = { "Banshee", "Cheetah", "Comet", "Super GT", "Turismo" },
	[30] = { "Hotring Racer", "Hotring Racer 2", "Infernus", "Alpha", "Buffalo" },
	[93] = { "Phoenix", "Windsor", "Hotring Racer 3" },
	[79] = {
		"Admiral",
		"Elegant",
		"Emperor",
		"Premier",
		"Sentinel",
		"Stafford",
		"Stratum",
		"Stretch",
		"Sultan",
		"Taxi",
		"Police LS",
		"Police SF",
		"Police LV",
	},
	[85] = { "Blista Compact", "Club", "Jester", "Esperanto", "Feltzer", "Flash", "Majestic", "Tahoma" },
	[38] = { "Sabre", "Savanna", "Voodoo", "Clover", "Blade", "Buccaneer", "Stallion" },
	[27] = { "Hermes", "Remington", "Broadway" },
	[68] = { "Hustler", "Hotknife", "BF Injection", "Slamvan" },
	[18] = { "Yosemite", "Cabbie", "Fortune", "Intruder", "Picador", "Sunrise", "Vincent", "Willard" },
	[87] = {
		"Bobcat",
		"Greenwood",
		"Manana",
		"Moonbeam",
		"Perennial",
		"Regina",
		"Romero",
		"Sadler",
		"Tampa",
		"Virgo",
		"Washington",
	},
	[129] = {
		"Mule",
		"Ambulance",
		"Burrito",
		"Journey",
		"Newsvan",
		"Pony",
		"Securicar",
		"Towtruck",
		"Utility Van",
		"Berkley's RC Van",
		"Boxville",
	},
	[73] = { "Barracks", "Trashmaster", "Dune", "Enforcer", "FBI Truck", "Flatbed", "S.W.A.T." },
	[91] = { "FBI Rancher", "Huntley", "Landstalker", "Patriot", "Rancher", "Police Ranger", "Sandking" },
	[76] = {
		"Packer",
		"Tanker",
		"Benson",
		"Cement Truck",
		"Dumper",
		"Fire Truck",
		"Fire Truck Ladder",
		"Linerunner",
		"Roadtrain",
		"Rhino",
	},
	[25] = { "Bus", "Coach", "DFT-30" },
	[81] = { "Dozer", "Tractor", "Walton" },
	[50] = { "Forklift" },
	[119] = { "Sweeper" },
	[134] = { "Boxville Mission", "Camper", "Hotdog", "Mr. Whoopee", "Rumpo", "Yankee" },
	[3] = { "Tug", "Baggage" },
	[107] = { "Bandito", "FCR-900" },
	[63] = { "Bloodring Banger", "Monster 1", "Monster 2", "Monster 3" },
	[54] = { "Mower", "Kart" },
	[117] = { "PCJ-600", "BF-400", "NRG-500" },
	[111] = { "Faggio", "Pizzaboy" },
	[33] = { "HPV1000", "Wayfarer" },
	[40] = { "Quadbike", "Sanchez" },
	[132] = { "Freeway" },
}

for id = 400, 610 do
	local name = engineGetModelNameFromID(id)
	if name then
		for sound, data in pairs(defaultSounds) do
			if table.contains(data, name) then
				info[id] = {
					isDefault = true,
					ratio = 0.53,
					accel = 1000,
					slide = 1150,
					decel = 840,
					max = 1.1,
					min = 0.03,
					smoother = { 0.09, -0.07 },
					rev = {
						frequency = 8,
						amplitude = 0.2,
					},
					audio = sound,
					idle = sound,
				}
			end
		end
	end
end
