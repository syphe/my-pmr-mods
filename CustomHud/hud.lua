CustomHudRoot = 'C:/Modding/PMR_Hud/'

source('dataS/s4sGame/scripts/main.lua')

CustomHudMod = CustomHudMod or {}

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

local shiftLightOverlays = nil

local function getShiftLightOverlays()
    if shiftLightOverlays ~= nil then
        return shiftLightOverlays
    end

    if g_overlayManager == nil or type(g_overlayManager.getSliceInfoById) ~= "function" or type(Overlay) ~= "table" or type(Overlay.new) ~= "function" then
        return nil
    end

    local inactiveSlice = g_overlayManager:getSliceInfoById("ui_elements.dotSmall")
    local activeSlice = g_overlayManager:getSliceInfoById("ui_elements.shiftLight")
    if inactiveSlice == nil or activeSlice == nil then
        return nil
    end

    local inactiveOverlay = Overlay.new(inactiveSlice.filename, 0, 0, 0, 0)
    local activeOverlay = Overlay.new(activeSlice.filename, 0, 0, 0, 0)
    inactiveOverlay:setSliceId(inactiveSlice.sliceId)
    activeOverlay:setSliceId(activeSlice.sliceId)
    shiftLightOverlays = {
        inactive = inactiveOverlay,
        active = activeOverlay
    }
    return shiftLightOverlays
end

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
        local cx = 0.5
        local cy = 0.13
        local w = 0.34
        local h = 0.19
        local left = cx - w/2
        local right = cx + w/2
        local bottom = cy - h/2
        local top = cy + h/2
        local borderThicknessX = 0.001
        local borderThicknessY = 0.001
        local borderR, borderG, borderB = 0.92, 0.92, 0.92

        drawFilledRect(left, bottom, w, h, 0.025, 0.025, 0.025, 0.96)

        -- 8-LED circular shift-light strip
        local minRpm = teleState.shiftLightsStartRpm
        local maxRpm = teleState.shiftLightsMaxRpm
        local shiftRpm = teleState.shiftLightsShiftRpm
        
        local rpmPct = 0.0
        if teleState.rpm > minRpm then
            rpmPct = math.min(1.0, (teleState.rpm - minRpm) / (maxRpm - minRpm))
        end
        
        local ledWidth = 0.012
        local ledSpacing = 0.018
        local startX = cx - (4 * ledSpacing) + (ledSpacing / 2)
        local ledY = top - 0.025
        local screenAspectRatio = g_screenAspectRatio or 1.7777777777777777
        local circleWidth = 0.010 / screenAspectRatio
        local circleHeight = 0.010
        local shiftLightCircleOverlays = getShiftLightOverlays()

        local activeStages = math.floor(rpmPct * 4)
        if teleState.rpm >= shiftRpm then
            activeStages = 4
        end
        local isRedline = (teleState.rpm >= shiftRpm)

        local ledStates = {false, false, false, false, false, false, false, false}
        if activeStages >= 1 then ledStates[1] = true; ledStates[8] = true end
        if activeStages >= 2 then ledStates[2] = true; ledStates[7] = true end
        if activeStages >= 3 then ledStates[3] = true; ledStates[6] = true end
        if activeStages >= 4 then ledStates[4] = true; ledStates[5] = true end

        for i = 1, 8 do
            local ledX = startX + (i - 1) * ledSpacing
            local r, g, b = 0.1, 0.1, 0.1
            
            if ledStates[i] then
                if isRedline then
                    if teleState.flashOn then r, g, b = 1.0, 0.1, 0.1 else r, g, b = 0.1, 0.0, 0.0 end
                else
                    if i == 4 or i == 5 then r, g, b = 1.0, 0.1, 0.1 else r, g, b = 0.1, 0.9, 0.2 end
                end
            end

            local circleX = ledX + (ledWidth - circleWidth) / 2
            local circleOverlay = nil
            if shiftLightCircleOverlays ~= nil then
                circleOverlay = ledStates[i] and shiftLightCircleOverlays.active or shiftLightCircleOverlays.inactive
            end

            if circleOverlay ~= nil then
                circleOverlay:setPosition(circleX, ledY)
                circleOverlay:setDimension(circleWidth, circleHeight)
                circleOverlay:setColor(r, g, b, 1.0)
                circleOverlay:render()
            else
                drawFilledRect(ledX, ledY, ledWidth, circleHeight, r, g, b, 1.0)
            end
        end

        -- Bordered instrument layout
        local upperTop = ledY - 0.012
        local upperBottom = bottom + 0.058
        local leftWidth = w * 0.29
        local bottomColumnWidth = (w - 0.018) / 3
        local centeredInstrumentLeft = left + 0.009 + bottomColumnWidth
        local rightLeft = centeredInstrumentLeft + bottomColumnWidth
        local bottomTop = upperBottom

        drawOutlineRect(left + 0.009, upperBottom, w - 0.018, upperTop - upperBottom, borderThicknessX, borderThicknessY, borderR, borderG, borderB, 1.0)
        drawFilledRect(left + 0.011, upperBottom + 0.002, leftWidth - 0.004, upperTop - upperBottom - 0.004, 0.02, 0.02, 0.02, 1.0)
        drawOutlineRect(centeredInstrumentLeft, upperBottom, bottomColumnWidth, upperTop - upperBottom, borderThicknessX, borderThicknessY, borderR, borderG, borderB, 1.0)
        drawOutlineRect(rightLeft, upperBottom, right - rightLeft - 0.009, upperTop - upperBottom, borderThicknessX, borderThicknessY, borderR, borderG, borderB, 1.0)

        local bottomHeight = upperBottom - bottom - 0.010
        for column = 0, 2 do
            local columnLeft = left + 0.009 + bottomColumnWidth * column
            drawOutlineRect(columnLeft, bottom + 0.008, bottomColumnWidth, bottomHeight, borderThicknessX, borderThicknessY, borderR, borderG, borderB, 1.0)
        end

        -- Upper left: race status, position and lap
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(0.95, 0.85, 0.1, 1.0)
        renderText(left + 0.019, upperTop - 0.016, 0.010, "RACE")
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(left + 0.019, upperTop - 0.034, 0.008, "POS")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(left + 0.019, upperTop - 0.054, 0.016, tostring(teleState.position))
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(left + 0.072, upperTop - 0.034, 0.008, "LAP")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(left + 0.072, upperTop - 0.054, 0.016, tostring(teleState.lap))

        -- Center: giant gear
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(1.0, 1.0, 1.0, 1.0)
        local gearCenterX = left + 0.009 + bottomColumnWidth * 1.5
        renderText(gearCenterX, upperTop - 0.057, 0.050, teleState.gear)

        -- Upper right: best lap and gain/loss
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(right - 0.019, upperTop - 0.016, 0.008, "BEST LAP")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(right - 0.019, upperTop - 0.034, 0.013, teleState.bestLapStr)
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(right - 0.019, upperTop - 0.046, 0.008, "GAIN / LOSS")
        setTextColor(0.1, 0.9, 0.1, 1.0)
        renderText(right - 0.019, upperTop - 0.060, 0.013, teleState.gainLossVal)

        -- Lower row: engine temperature, brake bias and engine map
        setTextAlignment(RenderText.ALIGN_CENTER)
        local col1X = left + 0.009 + bottomColumnWidth/2
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(col1X, bottomTop - 0.016, 0.008, "ENG TEMP")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(col1X, bottomTop - 0.042, 0.014, string.format("%d", teleState.engTemp))

        local col2X = left + 0.009 + bottomColumnWidth * 1.5
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(col2X, bottomTop - 0.016, 0.008, "B BIAS")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(col2X, bottomTop - 0.042, 0.014, string.format("%.1f", teleState.brakeBias))

        local col3X = left + 0.009 + bottomColumnWidth * 2.5
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(col3X, bottomTop - 0.016, 0.008, "MAP")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(col3X, bottomTop - 0.042, 0.014, tostring(teleState.engineMap))

        setTextAlignment(RenderText.ALIGN_LEFT)
    end)
end

print('[CUSTOM_HUD] Debug Logger Loaded!')