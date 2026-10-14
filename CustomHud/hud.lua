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

-- Shared state for telemetry and shift light animation
local teleState = {
    rpm = 0,
    gear = "N",
    position = 1,
    lap = 1,
    engTemp = 101,
    brakeBias = 65.0,
    engineMap = 3,
    bestLapStr = "0:00.0",
    gainLossVal = "0.00",
    active = false,
    
    -- Flashing Timer State
    flashTimer = 0,
    flashOn = true
}

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

        local tMan = actor.telemetryManager
        local tItem = tMan.items and tMan.items[actor.telemetryIndex or 1]
        
        if tItem ~= nil then
            -- RPM from Drivetrain table
            if tItem.drivetrain ~= nil then
                teleState.rpm = tItem.drivetrain[1] or 0
            end

            -- Gear from Input table (0 = N, <0 = R, >0 = Gear)
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
    end)
end

function draw()
    if CustomHudMod.stockDraw ~= nil then
        CustomHudMod.stockDraw()
    end

    if not teleState.active then return end

    pcall(function()
        -- Narrower Width, Preserved Height Layout
        local cx = 0.5
        local cy = 0.13
        local w = 0.22
        local h = 0.17

        -- 1. Darker MoTeC Bezel & Screen Panels (Matched Uniform Dark)
        drawFilledRect(cx - w/2, cy - h/2, w, h, 0.01, 0.01, 0.01, 0.95)
        drawFilledRect(cx - w/2 + 0.008, cy - h/2 + 0.008, w - 0.016, h - 0.016, 0.01, 0.01, 0.01, 0.95)

        -- 2. 8-LED Progressive Shift Lights (5500 to 7500 RPM)
        local minRpm = 5500
        local maxRpm = 7500
        
        local rpmPct = 0.0
        if teleState.rpm > minRpm then
            rpmPct = math.min(1.0, (teleState.rpm - minRpm) / (maxRpm - minRpm))
        end
        
        local ledWidth = 0.012
        local ledSpacing = 0.018
        local startX = cx - (4 * ledSpacing) + (ledSpacing / 2) + 0.001
        local ledY = cy + h/2 - 0.018

        local activeStages = math.floor(rpmPct * 4)
        if teleState.rpm >= maxRpm - 150 then
            activeStages = 4
        end
        local isRedline = (teleState.rpm >= maxRpm - 150)

        local ledStates = {false, false, false, false, false, false, false, false}
        if activeStages >= 1 then
            ledStates[1] = true
            ledStates[8] = true
        end
        if activeStages >= 2 then
            ledStates[2] = true
            ledStates[7] = true
        end
        if activeStages >= 3 then
            ledStates[3] = true
            ledStates[6] = true
        end
        if activeStages >= 4 then
            ledStates[4] = true
            ledStates[5] = true
        end

        for i = 1, 8 do
            local ledX = startX + (i - 1) * ledSpacing
            local r, g, b = 0.1, 0.1, 0.1
            
            if ledStates[i] then
                if isRedline then
                    if teleState.flashOn then
                        r, g, b = 1.0, 0.1, 0.1
                    else
                        r, g, b = 0.1, 0.0, 0.0
                    end
                else
                    if i == 4 or i == 5 then
                        r, g, b = 1.0, 0.1, 0.1
                    else
                        r, g, b = 0.1, 0.9, 0.2
                    end
                end
            end
            drawFilledRect(ledX, ledY, ledWidth, 0.010, r, g, b, 1.0)
        end

        -- 3. Top-Left: Session Status ("RACE") - Small Label
        setTextAlignment(RenderText.ALIGN_LEFT)
        setTextColor(0.95, 0.85, 0.1, 1.0)
        renderText(cx - w/2 + 0.018, cy + 0.046, 0.014, "RACE")

        -- 4. Middle-Left: Position & Lap
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(cx - w/2 + 0.018, cy + 0.012, 0.011, "POS")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(cx - w/2 + 0.018, cy - 0.010, 0.022, tostring(teleState.position))

        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(cx - w/2 + 0.065, cy + 0.012, 0.011, "LAP")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(cx - w/2 + 0.065, cy - 0.010, 0.022, tostring(teleState.lap))

        -- 5. Center: Giant Gear Indicator
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(cx, cy - 0.030, 0.082, teleState.gear)

        -- 6. Top-Right: Best Lap & Gain/Loss
        setTextAlignment(RenderText.ALIGN_RIGHT)
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(cx + w/2 - 0.018, cy + 0.052, 0.011, "BEST LAP")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(cx + w/2 - 0.018, cy + 0.030, 0.022, teleState.bestLapStr)

        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(cx + w/2 - 0.018, cy + 0.008, 0.011, "GAIN / LOSS")
        setTextColor(0.1, 0.9, 0.1, 1.0)
        renderText(cx + w/2 - 0.018, cy - 0.014, 0.022, teleState.gainLossVal)

        -- 7. Bottom Row: ENG TEMP | B BIAS | MAP
        setTextAlignment(RenderText.ALIGN_CENTER)
        
        local col1X = cx - 0.062
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(col1X, cy - 0.042, 0.011, "ENG TEMP")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(col1X, cy - 0.068, 0.024, string.format("%d", teleState.engTemp))

        local col2X = cx
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(col2X, cy - 0.042, 0.011, "B BIAS")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(col2X, cy - 0.068, 0.024, string.format("%.1f", teleState.brakeBias))

        local col3X = cx + 0.062
        setTextColor(0.5, 0.5, 0.5, 1.0)
        renderText(col3X, cy - 0.042, 0.011, "MAP")
        setTextColor(1.0, 1.0, 1.0, 1.0)
        renderText(col3X, cy - 0.068, 0.024, tostring(teleState.engineMap))

        setTextAlignment(RenderText.ALIGN_LEFT)
    end)
end

print('[CUSTOM_HUD] Synchronized Shift Light Dash loaded!')