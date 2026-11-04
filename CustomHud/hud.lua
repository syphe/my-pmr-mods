CustomHudRoot = 'C:/Modding/PMR_Hud/'

source('dataS/s4sGame/scripts/main.lua')

CustomHudMod = CustomHudMod or {}

source(CustomHudRoot .. 'draw_hud.lua')

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
-- brakeBias (number)
-- currentLapDelta (number)
-- delta (number)
-- engineMap (number)
-- engTemp (number)
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
    engTemp = 101,
    brakeBias = 65.0,
    engineMap = 3,
    bestLapStr = "--:--.--",
    gainLossVal = "+0.00",
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

function update(dt)
    if CustomHudMod.stockUpdate ~= nil then
        CustomHudMod.stockUpdate(dt)
    end
    
    if g_pendingExit then return end

    local deltaSec = (dt ~= nil and dt > 0) and ((dt > 1) and (dt / 1000) or dt) or 0.016
    teleState.flashTimer = teleState.flashTimer + deltaSec
    if teleState.flashTimer >= 0.125 then
        teleState.flashTimer = 0
        teleState.flashOn = not teleState.flashOn
    end

    pcall(function()
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

        teleState.active = true
        teleState.position = pData.raceEventPosition or 1
        teleState.lap = pData.lap or teleState.lap
        teleState.engTemp = pData.engTemp -- Linking engTemp from pData to teleState

        if type(actor.getShiftLightsRange) == "function" then
            local maxRpm, startRpm, shiftRpm = actor:getShiftLightsRange()
            if type(maxRpm) == "number" and type(startRpm) == "number" and type(shiftRpm) == "number" then
                teleState.shiftLightsMaxRpm = maxRpm
                teleState.shiftLightsStartRpm = startRpm
                teleState.shiftLightsShiftRpm = shiftRpm
            end
        end

        local bestValidLapTime = pData.bestValidLapTime
        if bestValidLapTime and not bestValidLapTime.invalid and bestValidLapTime.timeSeconds and bestValidLapTime.timeSeconds > 0 then
            teleState.bestLapStr = formatLapTime(bestValidLapTime.timeSeconds)
        else
            -- Handled when sitting in the pits, on an out-lap, or after an off-track/penalty invalidation
            teleState.bestLapStr = "--:--.--"
        end

        -- DEBUG LOGGING FOR GAIN/LOSS USING STANDARD PRINT
        local dVal = pData.lastLapDelta or pData.lapDelta or pData.currentLapDelta or pData.delta
        if type(dVal) == "number" then
            teleState.gainLossVal = string.format("%+.2f", dVal)
        end

        local tMan = actor.telemetryManager
        local tItem = tMan.items and tMan.items[actor.telemetryIndex or 1]
        
        if tItem ~= nil then
            if tItem.drivetrain ~= nil then
                teleState.rpm = tItem.drivetrain[1] or 0
            end

            if tItem.input ~= nil then
                local rawGear = tItem.input[6] or 0
                if rawGear == 0 then
                    teleState.gear = "N"
                elseif rawGear < 0 then
                    teleState.gear = "R"
                else
                    teleState.gear = tostring(rawGear)
                end
            end
        end

        -- Debug logging to print the structure of g_racingManager.playerVehicleData
        -- for key, value in pairs(pData) do
        --     print('[DEBUG] playerVehicleData.' .. key, type(value))
        --     if type(value) == "table" then
        --         for subKey, subValue in pairs(value) do
        --             print('[DEBUG] playerVehicleData.' .. key .. '.' .. subKey, type(subValue))
        --         end
        --     end
        -- end
    end)
end

function draw()
    if CustomHudMod.stockDraw ~= nil then
        CustomHudMod.stockDraw()
    end

    if not teleState.active then return end

    pcall(function()
        -- Draw the whole HUD first, then let draw_hud.lua fill its bounds.
        local bounds = {
            centerX = 0.5,
            centerY = 0.13,
            width = 0.28
        }
        bounds.height = bounds.width * 3 / 5
        bounds.left = bounds.centerX - bounds.width / 2
        bounds.right = bounds.centerX + bounds.width / 2
        bounds.bottom = bounds.centerY - bounds.height / 2
        bounds.top = bounds.centerY + bounds.height / 2

        drawFilledRect(bounds.left, bounds.bottom, bounds.width, bounds.height, 0.025, 0.025, 0.025, 0.96)
        CustomHudMod.drawHud(teleState, bounds)
    end)
end

print('[CUSTOM_HUD] Debug Logger Loaded!')