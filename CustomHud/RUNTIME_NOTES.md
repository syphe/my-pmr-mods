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

The speed values agree with the expected KPH/MPH conversion. `getShiftLightsRange` is a better lead for car-specific RPM thresholds than the HUD's fixed 5500â€“7500 range. Its three return values plausibly represent a maximum, illumination start and upper illumination/shift threshold, but the semantic ordering was not established from stock source. Do not assign those meanings solely from numerical order. TC/ABS zero does not by itself establish whether an assist is disabled, unsupported, or at its lowest setting.

Drawing follow-up also confirmed circle, outline, line and point argument conventions by tracing their lower-level drawing calls, and captured all 253 UI atlas slices. See [DRAWING_API.md](DRAWING_API.md). The game remains paused at the original breakpoint; temporary drawing substitutions were restored, and no drawing callback was installed.

`hud.lua` remained unchanged (SHA-256 `B03A39B504E5ED58C6675BFB322E0D19222312C9B6BA41FDC93A7A8A7583731E`).

## Live delta against the player's best lap: verified and fixed

Inspected later on 4 November 2026 through the connected Debug Console while the
game was not stopped at a breakpoint. Evidence is in
[inspection/delta-runtime.txt](inspection/delta-runtime.txt); the bounded probe is
[inspection/delta-probe.lua](inspection/delta-probe.lua).

`DeltaWidget.ComparisonMode` contains `Player_Best = 1`, `Car_Best = 2`, and
`Class_Best = 3`. A controlled call to the actual `DeltaWidget.getCurrentDelta`
function using local mock objects confirmed that **Player_Best calls
`self.playerData:getCurrentLapDelta()` with no additional arguments**, forwarding
the returned number. No stock widget mode or vehicle data was modified by that
trace.

`debug.info` located the functions at:

- `DeltaWidget.getCurrentDelta`: `dataS/s4sGame/scripts/hud/DeltaWidget.lua:155`;
  one parameter (`self`).
- `playerData.getCurrentLapDelta`: `dataS/s4sGame/scripts/racingManager/vehicleData.lua:1479`;
  one parameter (`self`).
- `playerData.getLastLapDelta`: the same vehicle-data file, line 1475.

In the live snapshot, `pData.lastLapDelta` was `0.7205801327020964`, while
`pData:getCurrentLapDelta()` returned `0`. The verified named lookup
`actor:getVehicleParamValue("lapDelta")` also returned `true, 0`. Direct fields
`pData.lapDelta`, `pData.currentLapDelta`, and `pData.delta` were nil. The reference
best lap was valid at `82.93333333297505` seconds.

The earlier `lastLapDelta or ...` lookup therefore selected a completed-lap
result permanently. `hud.lua` now reads `getCurrentLapDelta()` after the stock
update on each frame, formats it to two decimal places, and displays `--` if
there is no valid best lap or the getter fails/returns a nonfinite value. It does
not fall back to historical lap fields. The preview now models the same getter.

After reloading the corrected `hud.lua`, a one-frame renderer wrapper recorded
`displayed=+0.00 live=0 lastLap=0.7205801327020964`, then restored itself before
rendering the HUD. Local regression checks verified changing values across
updates, stock-update ordering, zero/sign formatting, invalid/missing readings,
getter failures, and best-lap resets. Continued visual comparison during a
driving lap was not performed during this inspection.

Do not read `g_gui.frames.DeltaWidget.target.deltaText.text` as live telemetry:
the template in this session still contained `-0.123`, and its `playerData` was
nil. Calling that unbound template's getter failed. Reading vehicle data directly
avoids reliance on a particular stock widget's visibility or initialization.

## Pause and gameplay HUD visibility

Later read-only console inspection confirmed `PauseManager:isPaused()` takes
`self` and returns a boolean. Calling it without `self` fails. Stock HUD hide
reasons are queried through
`g_gui.guis.HudOverlay.target:isHudVisibleReasonSet(reason)`; a true result means
that hide reason is set. `HudOverlay.HideReasons` contains `GAME=0`, `PAUSE=1`,
`PRE_RACE=2`, `PRERACE_FLYTHROUGH=3`, `POST_RACE=4`, `PHOTO_MODE=5`, `DMCC=6`, and
`DEBUG=7`.

The inspected menu state was `g_gui.currentGuiName = "DMCCMenu"`, with
`PauseManager:isPaused() == false`, `actor.timePaused == false`, and the stock
`PRE_RACE` hide reason true. Simulation pause alone therefore does not cover all
non-driving screens. The stock HUD wrapper's alpha was zero in that snapshot.

`hud.lua` now checks `CustomHudMod.shouldDrawHud()` at draw time, after drawing the
stock UI. It requires an active racing manager/player actor, no actor/simulation
pause, and no stock HUD hide reason. Missing or failing visibility accessors hide
the custom HUD. The guard suppresses both the bezel and all custom contents and
does not rely on another telemetry update after a pause transition.

After live reload, the console recorded
`custom HUD visible=false currentGui=DMCCMenu`. Regression checks exercised
pause/resume without intervening updates, all eight hide reasons, session exit,
missing/failed accessors, and preservation of stock UI drawing. The game was not
unpaused to perform those checks. Raw evidence is in
[inspection/pause-runtime.txt](inspection/pause-runtime.txt).
## Custom HUD registration: implemented and tested, 4 November 2026

`hud_widget.lua` creates separate `GuiElement` containers with ID `customHudBox`
on `HudOverlay.target` and `MovableWidgetsPage.target`, and appends only the editor
copy to `movableWidgets`. It was selected successfully as widget 19 in this game
session. Registration runs after the stock update and tolerates controller/list
recreation without adding duplicates. Script reload retains the registration state.

Dynamic elements must assign `id` directly: `setId` expects XML identity metadata
and failed with a nil concatenation. XML loading also normally supplies
`frameThickness`, `focusedOffset` and `frameOverlayVisible`; these need defaults
for stock `selectWidget` / `updateFramePosition` to work.

The editor copy draws the paused preview through its own GUI `draw` callback.
Gameplay continues to draw after the stock HUD, using the live element's absolute
position. This preserves pause/menu hiding and lets stock dialogs dim and cover
the editor preview correctly. The user's whole-HUD aspect calculation and colours
are preserved.

Mouse dragging updates `MovableWidgetsPage.loadedPositions.customHudBox`. The
stock Save action serialized this entry to `savegame1/widgetPlacements.xml`:
the test move produced `{0.250625, 0.18761110448837282}` and survived closing and
reopening the editor. The HUD was then dragged back and saved at approximately
`{0.36, 0.014}`. The game does not reapply placements to the live custom container
on editor exit, so registration synchronizes that container from the saved entry
when its coordinates change. Editor dragging is never overwritten by that sync.

Stock placement loading explicitly enumerates stock controls. A single wrapper
extends `applyWidgetPlacements` for our ID. The custom default is also added to
`originalPositions` for the stock reset path. A full game restart and the complete
Reset UI action have not been exercised; mocked controller recreation/reload and
saved-position loading passed.

An exploratory placement call on a shallow controller copy also moved its shared
stock children. The later native Save exposed the difference against the pre-test
placement-file backup. All 18 stock GUI positions and `loadedPositions` entries
were restored, and the file's 18 stock entries were restored exactly from the
backup while retaining `customHudBox`. The unsafe exploratory probe was removed.
Do not invoke stock placement methods on shallow copies of real GUI controllers.

## Finished-session visibility: fixed, 4 November 2026

The completed race still had an active manager and actor, with all stock HUD hide
reasons (including `POST_RACE`) false. Player data had `sessionFinished=true` and
`chequeredFlagTriggered=true`; the actor had `chequeredFlag=true`.
`playerData:getSessionFinished()` returned true. A read-only local mock trace
confirmed this getter reads `sessionFinished`; `getMPSessionComplete()` reads
`mpSessionComplete` (false in this session).

`shouldDrawHud` now checks either completion field directly at draw time before
the pause and stock hide checks. It does not latch completion across sessions.
The layout editor keeps its intentional paused preview. Lua regressions passed
for session completion, multiplayer completion, a new unfinished session, all
eight stock hide reasons, pause and missing/inactive player data. The predicate
was reloaded in the running game and reported `sessionFinished=true` with
`customVisible=false`. See [inspection/finish-runtime.txt](inspection/finish-runtime.txt).

## Native widget updates: implemented and verified, 4 November 2026

The registered `customHudBox` element can supply its own `update(self, dt)`.
A bounded live probe received 60 calls through `GuiElement.update`,
`FrameElement.update`, `ScreenElement.update`, `HudOverlay.update`, `Gui.update`
and the race phase's `threaded_update`. Native GUI `dt` is in milliseconds.
The game must be focused and resumed to exercise this path; alt-tab pauses it.

Each custom element now delegates to `GuiElement.update` and calls
`CustomHudMod.updateHud(dt)`. The editor copy owns telemetry while the layout
editor is open; otherwise the live copy owns it, avoiding duplicate updates.
The live callback also synchronizes saved placement and aspect-dependent size.
Global `update` retains the stock update and bootstraps recreated GUI controllers.
Registration work runs only when the custom element or editor list needs it.

Removed the broad telemetry and drawing `pcall` wrappers. Narrow guards remain
around optional native getters and initial widget registration. Missing raw
telemetry clears RPM/gear, and a failed optional getter cannot suppress the rest
of the HUD. Flash timing converts all native `dt` values from milliseconds,
including values below one millisecond.

After live reload, the focused game drew current telemetry and completed another
60 native telemetry callbacks (`dt=8.343999862670898` on the final call). Both
bounded verification wrappers restored themselves. Alt-tab then showed the pause
menu with the custom HUD hidden. Evidence is in
[inspection/update-runtime.txt](inspection/update-runtime.txt).

Lua regression checks passed for callback ownership, telemetry and optional getter
failures, millisecond timing, pause/finish visibility, registration idempotency,
module reload/controller recreation, saved placement and aspect synchronization,
and drawing error propagation. The Python preview also rendered successfully.
