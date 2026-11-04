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

-- Draw the contents after hud.lua has drawn the 5:3 background.
-- bounds uses the game's normalized screen coordinates; teleState is read-only here.
function CustomHudMod.drawHud(teleState, bounds)
    local cx = bounds.centerX
    local w = bounds.width
    local left = bounds.left
    local right = bounds.right
    local bottom = bounds.bottom
    local top = bounds.top
    local borderThicknessX = 0.001
    local borderThicknessY = 0.001
    local borderR, borderG, borderB = 0.92, 0.92, 0.92

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
    local upperBottom = bottom + 0.05
    local leftWidth = w * 0.29
    local bottomColumnWidth = (w - 0.018) / 3
    local centeredInstrumentLeft = left + 0.009 + bottomColumnWidth
    local rightLeft = centeredInstrumentLeft + bottomColumnWidth
    local bottomTop = upperBottom

    drawOutlineRect(left + 0.009, upperBottom, w - 0.018, upperTop - upperBottom, borderThicknessX, borderThicknessY, borderR, borderG, borderB, 1.0)
    drawFilledRect(left + 0.011, upperBottom + 0.002, leftWidth - 0.004, upperTop - upperBottom - 0.004, 0.02, 0.02, 0.02, 1.0)
    drawOutlineRect(centeredInstrumentLeft, upperBottom, bottomColumnWidth, upperTop - upperBottom, borderThicknessX, borderThicknessY, borderR, borderG, borderB, 1.0)
    drawOutlineRect(rightLeft, upperBottom, right - rightLeft - 0.009, upperTop - upperBottom, borderThicknessX, borderThicknessY, borderR, borderG, borderB, 1.0)

    local bottomHeight = upperBottom - bottom - 0.012
    for column = 0, 2 do
        local columnLeft = left + 0.009 + bottomColumnWidth * column
        drawOutlineRect(columnLeft, bottom + 0.010, bottomColumnWidth, bottomHeight, borderThicknessX, borderThicknessY, borderR, borderG, borderB, 1.0)
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
    renderText(gearCenterX, upperTop - 0.03, 0.050, teleState.gear)

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
end
