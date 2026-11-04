CustomHudRoot = 'C:/Users/syphe/source/repos/my-pmr-mods/CustomHud/'

source('dataS/s4sGame/scripts/main.lua')

CustomHudMod = CustomHudMod or {}

source(CustomHudRoot .. 'draw_hud.lua')
source(CustomHudRoot .. 'hud_widget.lua')

if not CustomHudMod.installed then
    CustomHudMod.stockInit = init
    CustomHudMod.stockUpdate = update
    CustomHudMod.stockDraw = draw
    CustomHudMod.installed = true
end

function init(...)
    if CustomHudMod.stockInit ~= nil then
        CustomHudMod.stockInit(...)
    end
end

-- Properties available in g_racingManager.playerVehicleData
-- bestValidLapTime (table):
--   - invalid (boolean)
--   - timeSeconds (number)
-- brakeBias (optional number; prefer vehicleActor:getVehicleParamValue("brakebias"))
-- currentLapDelta (number)
-- delta (number)
-- engineMap (optional number; no verified vehicle getter)
-- engTemp (optional number; prefer vehicleActor:getVehicleParamValue("engine_temp"))
-- gear (string)
-- lastLapDelta (number)
-- lapDelta (number)
-- position (number)
-- raceEventPosition (number)
-- rpm (number)
-- vehicleActor (table):
--   - telemetryIndex (number)
--   - telemetryManager (table):
--     - items (table):
--       - (indexed by telemetryIndex) (table):
--         - drivetrain (table):
--           - (indexed by 1) (number) - RPM
--         - input (table):
--           - (indexed by 6) (number) - Gear

-- Shared state for telemetry and shift light animation
local teleState = {
    rpm = 0,
    gear = "N",
    position = 1,
    lap = 1,
    bestLapStr = "--:--.--",
    gainLossVal = "--",
    tyreTemps = {},
    active = false,
    shiftLightsStartRpm = 6000,
    shiftLightsMaxRpm = 7500,
    shiftLightsShiftRpm = 7350,
    
    -- Flashing Timer State
    flashTimer = 0,
    flashOn = true
}

-- Helper function to convert seconds into M:SS.ff format
local function formatLapTime(seconds)
    if type(seconds) ~= "number" or seconds <= 0 or seconds >= 3600 then
        return "--:--.--"
    end
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%d:%05.2f", mins, secs)
end

-- A missing or unsupported parameter must not interrupt the rest of the HUD.
local function isFiniteNumber(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function getVehicleNumber(actor, name, fallback)
    if type(actor.getVehicleParamValue) == "function" then
        local ok, found, value = pcall(actor.getVehicleParamValue, actor, name)
        if ok and found and isFiniteNumber(value) then
            return value
        end
    end
    if isFiniteNumber(fallback) then
        return fallback
    end
    return nil
end

local function getActorNumber(actor, methodName)
    local method = actor[methodName]
    if type(method) == "function" then
        local ok, value = pcall(method, actor)
        if ok and isFiniteNumber(value) then
            return value
        end
    end
    return nil
end

function update(dt)
    if CustomHudMod.stockUpdate ~= nil then
        CustomHudMod.stockUpdate(dt)
    end
    if g_pendingExit then return end

    -- Bootstrap recreated GUI controllers; the registered element owns telemetry.
    CustomHudMod.registerHudWidget()
end

function CustomHudMod.updateHud(dt)
    teleState.active = false
    if g_pendingExit then return end

    -- Native GuiElement:update supplies milliseconds, including sub-ms frames.
    local deltaSec = isFiniteNumber(dt) and math.max(dt, 0) / 1000 or 0
    teleState.flashTimer = teleState.flashTimer + deltaSec
    if teleState.flashTimer >= 0.125 then
        teleState.flashTimer = 0
        teleState.flashOn = not teleState.flashOn
    end

    if g_racingManager == nil or g_racingManager.playerVehicleData == nil then
        teleState.active = false
        return
    end

    local pData = g_racingManager.playerVehicleData
    local actor = pData.vehicleActor

    if actor == nil or actor.telemetryManager == nil then
        teleState.active = false
        return
    end

    teleState.position = pData.raceEventPosition or 1
    teleState.lap = pData.lap or teleState.lap
    teleState.engTemp = getVehicleNumber(actor, "engine_temp", pData.engTemp)
    teleState.brakeBias = getVehicleNumber(actor, "brakebias", pData.brakeBias)
    teleState.engineMap = isFiniteNumber(pData.engineMap) and pData.engineMap or nil
    local speedKph = getActorNumber(actor, "getForwardSpeedKPH")
    teleState.speedKph = speedKph and math.abs(speedKph) or nil
    teleState.tcLevel = getActorNumber(actor, "getTCLevel")
    teleState.absLevel = getActorNumber(actor, "getABSLevel")
    teleState.fuelLitres = getActorNumber(actor, "getCurrentFuelRemainingLitres")
    local maxFuelLitres = getActorNumber(actor, "getMaxFuelLitres")
    teleState.fuelPercent = nil
    if teleState.fuelLitres ~= nil and maxFuelLitres ~= nil and maxFuelLitres > 0 then
        teleState.fuelPercent = teleState.fuelLitres / maxFuelLitres * 100
    end
    -- Named wheel getters avoid assuming the raw wheel-array layout.
    for wheel = 1, 4 do
        teleState.tyreTemps[wheel] = getVehicleNumber(actor, "wheel" .. wheel .. ".tyre_temp_avg")
    end

    if type(actor.getShiftLightsRange) == "function" then
        local ok, maxRpm, startRpm, shiftRpm = pcall(actor.getShiftLightsRange, actor)
        if ok and isFiniteNumber(maxRpm) and isFiniteNumber(startRpm) and isFiniteNumber(shiftRpm) then
            teleState.shiftLightsMaxRpm = maxRpm
            teleState.shiftLightsStartRpm = startRpm
            teleState.shiftLightsShiftRpm = shiftRpm
        end
    end

    local bestValidLapTime = pData.bestValidLapTime
    local hasBestLap = type(bestValidLapTime) == "table" and not bestValidLapTime.invalid
        and isFiniteNumber(bestValidLapTime.timeSeconds) and bestValidLapTime.timeSeconds > 0
    if hasBestLap then
        teleState.bestLapStr = formatLapTime(bestValidLapTime.timeSeconds)
    else
        -- Handled when sitting in the pits, on an out-lap, or after an off-track/penalty invalidation
        teleState.bestLapStr = "--:--.--"
    end

    -- DeltaWidget's Player_Best mode uses this live getter, not lastLapDelta.
    -- Refresh in the stock GUI update cycle, clearing unavailable readings.
    local currentDelta = nil
    if hasBestLap and type(pData.getCurrentLapDelta) == "function" then
        local ok, value = pcall(pData.getCurrentLapDelta, pData)
        if ok and isFiniteNumber(value) then
            currentDelta = value
        end
    end
    teleState.gainLossVal = currentDelta ~= nil and string.format("%+.2f", currentDelta) or "--"

    local tMan = actor.telemetryManager
    local tItem = type(tMan.items) == "table" and tMan.items[actor.telemetryIndex or 1]
    teleState.rpm = 0
    teleState.gear = "N"
    if type(tItem) == "table" then
        if type(tItem.drivetrain) == "table" then
            local rpm = tItem.drivetrain[1]
            teleState.rpm = isFiniteNumber(rpm) and rpm or 0
        end

        if type(tItem.input) == "table" then
            local value = tItem.input[6]
            local rawGear = isFiniteNumber(value) and value or 0
            if rawGear == 0 then
                teleState.gear = "N"
            elseif rawGear < 0 then
                teleState.gear = "R"
            else
                teleState.gear = tostring(rawGear)
            end
        end
    end
    teleState.active = true
end

function CustomHudMod.shouldDrawHud()
    local manager = g_racingManager
    if g_pendingExit or manager == nil or manager.active ~= true then
        return false
    end
    local pData = manager.playerVehicleData
    -- The player can finish before the stock POST_RACE hide reason is set.
    if pData and (pData.sessionFinished == true or pData.mpSessionComplete == true) then
        return false
    end
    local actor = pData and pData.vehicleActor
    if actor == nil or actor.active ~= true or actor.timePaused == true then
        return false
    end

    if type(PauseManager) ~= "table" or type(PauseManager.isPaused) ~= "function" then
        return false
    end
    local ok, paused = pcall(PauseManager.isPaused, PauseManager)
    if not ok or paused ~= false then
        return false
    end

    -- Stock hide reasons also cover menus/pre-race, even if simulation is running.
    local gui = g_gui and g_gui.guis and g_gui.guis.HudOverlay
    local hud = gui and gui.target
    if hud == nil or type(hud.isHudVisibleReasonSet) ~= "function"
        or type(HudOverlay) ~= "table" or type(HudOverlay.HideReasons) ~= "table" then
        return false
    end
    for _, reason in pairs(HudOverlay.HideReasons) do
        local success, hidden = pcall(hud.isHudVisibleReasonSet, hud, reason)
        if not success or hidden ~= false then
            return false
        end
    end
    return true
end

function CustomHudMod.drawHudWidget()
    -- draw_hud.lua lays out the lights and telemetry inside these bounds.
    local bounds = CustomHudMod.getHudBounds()
    drawFilledRect(bounds.left, bounds.bottom, bounds.width, bounds.height, 0, 0, 0, 0.8)
    CustomHudMod.drawHud(teleState, bounds)
end

function draw()
    if CustomHudMod.stockDraw ~= nil then
        CustomHudMod.stockDraw()
    end

    -- In the editor, its registered GUI element draws the paused preview.
    if CustomHudMod.isHudLayoutEditorOpen() then return end
    if not teleState.active or not CustomHudMod.shouldDrawHud() then return end
    CustomHudMod.drawHudWidget()
end



print('[CUSTOM_HUD] Debug Logger Loaded!')
