# Project Motor Racing HUD runtime inspection

See also [DRAWING_API.md](DRAWING_API.md) for circles and graphics capabilities, and [inspection/runtime-catalog.txt](inspection/runtime-catalog.txt) for the broader searchable API/member inventory captured later in this session.

Observed on 4 November 2026, paused at `hud.lua:122` using the GIANTS Engine debugger in VS Code. These are observations from this build and snapshot, not a documented stable API.

## Driving snapshot: working named accessor

A second breakpoint was inspected after entering and driving the car. The actor reported `active = true`, `firstupdate = false`, `isPossessed = true`, and `time = 23.54995004442243`.

**The working named accessor is `getVehicleParamValue`, not `getVehicleParameter`.** Its observed return convention is `found, value`:

```lua
local actor = g_racingManager.playerVehicleData.vehicleActor
local found, brakeBias = actor:getVehicleParamValue("brakebias")
if found and type(brakeBias) == "number" then
    -- Approximately 65.0 in the driving snapshot; already percentage-like.
end

local tempFound, engineTemp = actor:getVehicleParamValue("engine_temp")
local rpmFound, rpm = actor:getVehicleParamValue("revs")
local gearFound, gear = actor:getVehicleParamValue("gear")
local lapFound, lap = actor:getVehicleParamValue("lap")
local bestFound, bestLap = actor:getVehicleParamValue("bestLap")
-- bestFound indicates the lookup succeeded, not that a valid lap exists.
-- Check bestLap.invalid and bestLap.timeSeconds separately.
```

All ten calls below completed without a Lua exception and returned `true` as their first result, followed by the value. No third result was observed.

| Parameter | Value in driving snapshot |
| --- | --- |
| `brakebias` | `64.99999854713678` |
| `engine_temp` | `107.01951599121094` |
| `revs` | `2892.536865234375` |
| `gear` | `1` |
| `speed` | `13.195846557617188` (units not verified) |
| `pos` | `17` |
| `remainingLaps` | `10` |
| `lap` | `0` |
| `lapDelta` | `0` |
| `bestLap` | Table: `timeSeconds = 0`, `invalid = true`, `penaltySeconds = 0`, `penaltyApplied = false` |

Direct definition calls also succeeded for `lastLapDelta`, `lapTime`, and `lastLap`. `lastLapDelta` was zero. `lapTime` and `lastLap` were tables with zero seconds, `invalid = false`, zero penalty seconds, and `penaltyApplied = false`. The timing data had `isFlyingLap = false`, `lastStartedLap = 0`, empty `lapTimes`, and no valid best lap. This snapshot establishes the return structures, but not lap-number display conventions, delta sign, or behavior after a completed lap.

The named accessor matched direct definition calls for the overlapping samples. In contrast, cached `tItem.drivetrain[1]` was `2798.30810546875` while `revs` was `2892.536865234375`. The cause is unresolved; the two sources must not be assumed identical. Cached `tItem.input[6]` and the named `gear` getter both returned `1`.

`pData.engTemp`, `pData.brakeBias`, and `pData.engineMap` were still `nil` while driving. Use the verified named accessor for the available values. Engine-map access remains unresolved.

### Additional getters on the actor metatable

`getmetatable(actor)` directly exposes methods and a `paramGetters` table; looking only for `__index` missed these earlier. `paramGetters` contains:

- `gear`, `speed`
- For each wheel `1` through `4`: `wheelN.brake_temp`, `wheelN.tyre_avg_wear`, `wheelN.tyre_pressure`, `wheelN.tyre_temp_avg`, `wheelN.tyre_temp_imo`

Gear and speed were tested through `getVehicleParamValue`; the additional tyre/brake getters were discovered but not invoked. Their units and shapes remain unverified.

Other exposed methods include `getVehicleParameterFromTelemetry`, `getVehicleParameterLocal`, and `getWheelParameterFromTelemetry`. Their signatures remain unknown. Native `VehicleParameters` also exposes `getDriveTrainFuelRemaining`, `getDriveTrainGearboxLoadIn`, `getDriveTrainGearboxLoadOut`, and `getInputGear`; these were not invoked. The filtered native-function names contained no `map` or `bias` matches.

The runtime has a `debug` table, but `debug.getinfo` and `debug.getlocal` are both `nil`, preventing function-signature inspection through those standard Lua functions.

## Initial snapshot and limitations

- `g_racingManager.playerVehicleData`: table, 31 fields shown.
- `playerVehicleData.vehicleActor`: table, 131 fields shown.
- Actor flags: `firstupdate = true`, `active = false`, `isPossessed = false`, `userReadyToDrive = false`, `time = 0`.
- This appears to be before normal driving updates. Zero values here do not establish live values, units, or scaling.
- `pData.bestValidLapTime` and the HUD's combined delta lookup were `nil`.
- The player record's displayed fields did not include `engTemp`, `brakeBias`, or `engineMap`. Their absence at initialization does not prove they cannot appear later.
- The game remains paused. No changes were made to `hud.lua`.

## Objects reachable from the HUD

```lua
local pData = g_racingManager.playerVehicleData
local actor = pData.vehicleActor
local tMan = actor.telemetryManager
local tItem = tMan.items[actor.telemetryIndex]
```

`actor.telemetryIndex` was `1`. The telemetry manager had one item and was marked inactive. The item exposed these groups:

| Group | Fields/items shown |
| --- | ---: |
| `axle` | Empty table shown |
| `chassis` | 18 |
| `collision` | Empty table shown |
| `collisionFloats` | 216 |
| `collisionInts` | 144 |
| `constant` | 30 |
| `drivetrain` | 27 |
| `general` | 11 |
| `input` | 8 |
| `wheel` | Empty table shown |

Array channel meanings were not established in this inspection. The existing HUD assumes `drivetrain[1]` is RPM and `input[6]` is gear; those assumptions still need live validation.

The actor also exposes `damage`, `hadron`, `playerAssists`, `pitServiceRequirements`, `setupData`, `wheelData`, and component references. `setupData` contained only an apparently empty `sceneSetupFlat` table in this snapshot.

The player record contains race position, flag booleans, driver/vehicle identity, `driverActor`, and `statTracking`. The statistics object contains `trackedStats`; its contents were not explored further.

## Named parameter definitions

The most useful discovery is **`actor.VehicleParamFuncTable`**, with a capital `V`. It contains 63 named definitions. It is not a table of current values.

Selected definitions and direct calls were inspected and evaluated:

| Name | Definition `[2]` | Definition `[3]` | Source of function `[1]` | Result |
| --- | --- | --- | --- | --- |
| `brakebias` | `"self"` | absent | `vehicleActor.lua:5521` | `0` |
| `engine_temp` | `"self"` | `24` | `vehicleActor.lua:5574` | `0` |
| `revs` | `"self"` | `9` | Not recorded | `0` |
| `lap` | `"VehicleData"` | absent | `vehicleData.lua:496` | `0` |
| `lapDelta` | `"VehicleData"` | absent | Not recorded | `0` |
| `bestLap` | `"VehicleData"` | `true` | Not recorded | `nil` |

All six direct calls completed without a Lua exception. The observed calling pattern is:

```lua
-- Tested pattern for the six definitions listed above.
local definition = actor.VehicleParamFuncTable.engine_temp
local value = definition[1](actor, definition[3])

local lapDefinition = actor.VehicleParamFuncTable.lap
local lap = lapDefinition[1](pData, lapDefinition[3])
```

For these samples, `"self"` selected the actor and `"VehicleData"` selected the player record. Other definitions and receiver tags have not been validated. The numeric third entries are arguments to the getter; their relationship to raw telemetry indexes is not established.

Full catalog, sorted from the live table:

```text
absTriggered
ambientTemp
averageFuel
bestLap
blueFlag
brakebias
cell_temp
chequeredFlag
combinedLock
deploy_limit
diff_temp
engine_temp
exhaust_temp
front.brake_temp
frontLocked
front_arb
fuelDelta
fuelTargetNeg
fuelTargetPos
gearbox_temp
hybridMode
hybridStrat
hybrid_charge
lap
lapDelta
lapTime
lastLap
lastLapDelta
lights
measuringUnit
mguRPM
odometerJourney
odometerTotal
odometerTrip
oil_pressure
oil_temp
pitLimitEnabled
pitLimitTime
pitTime
pos
potentialLap
predictedLap
previousFuelDelta
rear.brake_temp
rearLocked
rear_arb
regen_limit
remainingLaps
revs
sectors
targetSpeed
tcsTriggered
timeOfDay
totalSessionTime
turbo_boost_pressure
water_temp
wheel1.tyre_temp_avg
wheel2.tyre_temp_avg
wheel3.tyre_temp_avg
wheel4.tyre_temp_avg
whiteFlag
wiper
yellowFlag
```

No engine-map entry appears in this catalog. That does not establish whether engine map is accessible through other runtime objects.

## Other API discoveries and unsuccessful probes

- `actor.getVehicleParameter` exists as a function. Calling it with the string names `brakebias`, `engine_temp`, `revs`, `lap`, `lapDelta`, `bestLap`, `lastLap`, `pos`, and `remainingLaps` logged `Unknown vehicle parameter` and returned `nil`. `pcall` still returned success: logged errors here are not necessarily Lua exceptions. Its argument convention remains unresolved. Error stacks referenced `dataS/s4sGame/scripts/actors/vehicleActor.lua:3736`.
- `actor.getVehicleParameterValue` was `nil`.
- Global `VehicleParameters` is a table exposing native functions including `getParameter`, `getDriveTrainEngineRPM`, `getDriveTrainEngineLoad`, `getDriveTrainEngineRevRatio`, `getInputBrake`, `getInputHandbrake`, `getWheelBrakeTemperature`, and `getWheelBrakePadThickness`. These were discovered by reflection, not invoked; signatures remain unknown.
- Global `VehicleScriptParameterIds` contained `BACK_FIRE = "back_fire"`, `BACK_FIRE_INTENSITY = "back_fire_intensity"`, and `ENGINE_DAMAGE = "engine_damage"`.

## Debug console behavior

The console did not resolve the paused frame's local `actor`. Use the full global path or define locals inside an immediately invoked function:

```lua
(function()
    local actor = g_racingManager.playerVehicleData.vehicleActor
    local names = {}
    for name in pairs(actor.VehicleParamFuncTable) do
        names[#names + 1] = name
    end
    table.sort(names)
    print(table.concat(names, ", "))
end)()
```

Explicit `print` was needed to display the result from this statement-style expression. The engine displayed separate arguments to `print` on separate lines, so concatenate labels and values for compact output.

## Remaining validation

The driving-session check confirmed live values and the named accessor above. Compare values with the in-game displays before assigning units, particularly speed and temperatures. Cross the start line and complete a valid lap to verify lap numbering, advancing lap time, best-lap behavior, and delta sign.

The HUD can use the verified `getVehicleParamValue` convention for its available fields, with checks for lookup success and value type. Check engine-map access separately. The HUD currently assigns missing `pData.engTemp` to its display state and later formats it as a number inside a silent `pcall`, which can interrupt drawing without a visible error. No HUD implementation changes were made during these inspections.

## Broader catalog captured during drawing inspection

The saved inventory now includes the actor class, player-data class, racing-manager class, native `VehicleParameters`, current actor/player/manager field names, and graphics classes. Most newly discovered methods were not invoked; search the catalog before repeating discovery.

Useful newly recorded actor methods include `getShiftLightsRange`, `getForwardSpeedKPH`, `getForwardSpeedMPH`, `getCurrentFuelRemainingLitres`, `getMaxFuelLitres`, `getFuelRemainingAsPercentage`, `getEstimatedRemainingLapsForFuel`, `getTCLevel`, `getABSLevel`, damage percentages and tyre/brake state accessors. Several were subsequently tested successfully; see the follow-up table below. Explicit KPH/MPH method names avoid assuming the units of `getVehicleParamValue("speed")`.

The full later player-data inventory showed `bestValidLapTime`, `currentLapTime`, sector and delta-tracking tables, fuel tracking, penalties, pit state and race/class identifiers. These expand the earlier abbreviated debugger views; their presence alone does not validate displayed lap timing or deltas.

Globals named `VehicleTelemetryDrivetrain`, `VehicleTelemetryInput`, `VehicleTelemetryWheel`, `VehicleTelemetryGeneral`, `VehicleTelemetryChassis`, `VehicleTelemetryCollisionFloats`, `VehicleTelemetryCollisionInts`, `VehicleTelemetryLayout`, and `VehicleParameterUnitModifier` were discovered. Selected contents were subsequently captured below; the collision enums remain unexpanded. Engine-map access remains unresolved; the actor method-name survey contained no obvious engine-map getter.

The game exited after the broader catalog completed and the debugger disconnected. The log did not establish a cause. The user subsequently restarted and reattached at the breakpoint. A survey of all named parameter values was not executed. The original readings and the later targeted getter table are the validated getter results.

## Captured telemetry channel constants after reattachment

Full mappings are preserved in [inspection/telemetry-enums.csv](inspection/telemetry-enums.csv) and [inspection/telemetry-enums.txt](inspection/telemetry-enums.txt). These are enum values observed directly in PMR, not guessed channel labels.

| Group | Selected confirmed channel identifiers |
| --- | --- |
| `VehicleTelemetryDrivetrain` | `ICE_RPM=1`, `ICE_REV_RATIO=2`, `ICE_LOAD=3`, `SPEEDOMETER=8`, `TACHOMETER=9`, `FUEL_REMAINING=13`, `OIL_TEMPERATURE=21`, `COOLANT_TEMPERATURE=22`, `BLOCK_TEMPERATURE=24`, `OIL_PRESSURE=25`, `GEARBOX_TEMPERATURE=26` |
| `VehicleTelemetryInput` | `STEERING=1`, `ACCELERATOR=2`, `BRAKE=3`, `CLUTCH=4`, `HANDBRAKE=5`, `GEAR=6`, `FFB_PHYSICS=7`, `FFB_FINAL=8` |
| `VehicleTelemetryWheel` | `TYRE_PRESSURE=13`, inner/middle/outer temperature `14/15/16`, average temperature `17`, `BRAKE_TEMPERATURE=18`, `LOAD=25`, `TYRE_SLIP_ANGLE=11`, `TYRE_SLIP_RATIO=12`, `PUNCTURED=36` |
| `VehicleTelemetryChassis` | `FORWARD_SPEED=8`, `OVERALL_SPEED=9`, linear velocity `10/11/12` |
| `VehicleTelemetryGeneral` | `STEERING_WHEEL_ANGLE=1`, `ABS_ACTIVE=2`, `TOTAL_MASS=6`, `REAR_WING_ANGLE=11` |

This confirms that the HUD's cached RPM index `1` is named `ICE_RPM` and cached gear index `6` is named `GEAR`. The earlier `revs` definition had third argument `9`, matching the separate `TACHOMETER` channel number. That is a plausible explanation for the earlier differing RPM values; the getter's implementation was not read, so the relationship is not proven solely by matching numbers.

`VehicleTelemetryLayout` reports drivetrain count 27, input count 8, chassis count 18, general count 11, wheel stride 38, maximum wheels 8, maximum axles 4, maximum collisions 24, collision float stride 9 and integer stride 6. It exposes `getWheelDataOffset`, `getWheelFlatIndex`, `getCollisionFloatOffset` and `getCollisionIntOffset`; their base-index conventions were not tested. In particular, do not assume the wheel table uses the same direct-index convention as drivetrain/input arrays.

`VehicleParameterUnitModifier` exposes conversion helpers for distance, speed, fluid volume, pressure, temperature, weight, size, percentages, springs, stiffness and steering damping. Its registration table was not expanded, and function presence does not identify the raw telemetry units.

An earlier combined probe produced no output. At the next pause, the console responded and a bare `drawOutlineCircle2D` watch was found to cause repeated Lua compiler dialogs. That watch was changed to `type(drawOutlineCircle2D)`, and fresh targeted queries completed. The earlier missing output does not demonstrate that `getShiftLightsRange` blocks.

## Additional getters verified at the next pause

These were called as `actor:method()` with no extra arguments. Values are a single snapshot, not bounds or defaults. Original output is in [inspection/drawing-followup.txt](inspection/drawing-followup.txt).

| Method | Returned values |
| --- | --- |
| `getShiftLightsRange()` | `7500, 6000, 7350` (first three returns captured) |
| `getForwardSpeedKPH()` | `0.8270828604698182` |
| `getForwardSpeedMPH()` | `0.5139263149720431` |
| `getCurrentFuelRemainingLitres()` | `53.67643356323242` |
| `getMaxFuelLitres()` | `134.10595703125` |
| `getTCLevel()` | `0` |
| `getABSLevel()` | `0` |

The speed values agree with the expected KPH/MPH conversion. `getShiftLightsRange` is a better lead for car-specific RPM thresholds than the HUD's fixed 5500–7500 range. Its three return values plausibly represent a maximum, illumination start and upper illumination/shift threshold, but the semantic ordering was not established from stock source. Do not assign those meanings solely from numerical order. TC/ABS zero does not by itself establish whether an assist is disabled, unsupported, or at its lowest setting.

Drawing follow-up also confirmed circle, outline, line and point argument conventions by tracing their lower-level drawing calls, and captured all 253 UI atlas slices. See [DRAWING_API.md](DRAWING_API.md). The game remains paused at the original breakpoint; temporary drawing substitutions were restored, and no drawing callback was installed.

`hud.lua` remained unchanged (SHA-256 `B03A39B504E5ED58C6675BFB322E0D19222312C9B6BA41FDC93A7A8A7583731E`).
