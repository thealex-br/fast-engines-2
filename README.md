## Fast Engines 2: Definitively Experimental

### good news! :D
- all default vehicles uses their original idle sounds

### bad news! :'(
 - changed how `slide` parameter works, now it should be bigger than `accel`, otherwise rpm will decrease when drifting

### new parameters
- new global parameter `oneGearEVs`, fake gears to make electric cars uses 1 gear
- new parameter `idle` (optional)
- new parameter `limit` added to `rev` (optional)
- better drifting detection/transition
- added basic support for electric cars (uses vehicle handling)
- even less cpu usage (0.49/0.58 5s CPU usage)

### new events
`onClientVehicleGearChange` | parameters: `lastGear`, `currentGear`

`onClientVehicleBlowoff` | parameters: `turboRpm`

`onClientVehicleRev` | parameters: `engineRpm`, `revAccumulation`, `revFrequency`
