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

local function formatNumber(value, format)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return "--"
    end
    return string.format(format, value)
end

-- Draw the contents inside the black bezel supplied by hud.lua.
-- The shift-light strip uses part of these bounds rather than adding HUD height.
-- bounds uses the game's normalized screen coordinates; teleState is read-only here.
function CustomHudMod.drawHud(teleState, bounds)
    local cx = bounds.centerX
    local top = bounds.top
    local screen = {
        left = bounds.left + 0.009,
        right = bounds.right - 0.009,
        bottom = bounds.bottom + 0.010,
        top = top - 0.037
    }
    screen.width = screen.right - screen.left
    screen.height = screen.top - screen.bottom
    local borderThicknessX = 0.001
    local borderThicknessY = 0.001
    local borderR, borderG, borderB = 0.92, 0.92, 0.92

    -- Only the telemetry screen is lighter; the LED strip keeps the black bezel.
    drawFilledRect(screen.left, screen.bottom, screen.width, screen.height, 0.0, 0.0, 0.0, 1.0)

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

    -- Dense side panels around the narrower RPM / gear / speed column.
    local gapX = 0.002
    local gapY = gapX * screenAspectRatio
    local usableWidth = screen.width - gapX * 2
    local sideWidth = usableWidth * 0.36
    local centerWidth = usableWidth * 0.28
    local centerLeft = screen.left + sideWidth + gapX
    local rightLeft = centerLeft + centerWidth + gapX
    local sideRowHeight = (screen.height - gapY * 3) / 4

    local function cell(x, y, width, height)
        return {left = x, bottom = y, width = width, height = height}
    end

    local function sideCell(panelLeft, column, row)
        local width = (sideWidth - gapX) / 2
        return cell(panelLeft + column * (width + gapX),
            screen.top - sideRowHeight * (row + 1) - gapY * row,
            width, sideRowHeight)
    end

    local function fittedSize(text, size, width)
        -- Measure when supported; the estimate also keeps preview/older runtimes usable.
        if type(getTextWidth) == "function" then
            local ok, measured = pcall(getTextWidth, size, text)
            if ok and type(measured) == "number" and measured > 0 then
                return math.min(size, size * width / measured)
            end
        end
        return math.min(size, width * screenAspectRatio / (math.max(1, #text) * 0.70))
    end

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)

    local function drawCell(bounds, label, value, valueSize, r, g, b)
        drawOutlineRect(bounds.left, bounds.bottom, bounds.width, bounds.height,
            borderThicknessX, borderThicknessY, borderR, borderG, borderB, 1.0)
        local centerX = bounds.left + bounds.width / 2
        local labelSize = fittedSize(label, math.min(0.0105, bounds.height * 0.24), bounds.width * 0.88)
        local size = fittedSize(value, math.min(valueSize, bounds.height * 0.48), bounds.width * 0.86)
        setTextColor(0.65, 0.65, 0.65, 1.0)
        renderText(centerX, bounds.bottom + bounds.height * 0.84, labelSize, label)
        setTextColor(r or 1.0, g or 1.0, b or 1.0, 1.0)
        renderText(centerX, bounds.bottom + bounds.height * 0.34, size, value)
    end

    -- Left column: eight cells, two per row.
    local leftCells = {
        {"POS", formatNumber(teleState.position, "%.0f"), 0.022},
        {"LAP", formatNumber(teleState.lap, "%.0f"), 0.022},
        {"BEST LAP", teleState.bestLapStr, 0.014},
        {"ENG TEMP", formatNumber(teleState.engTemp, "%.0f"), 0.020},
        {"B BIAS", formatNumber(teleState.brakeBias, "%.1f"), 0.020},
        {"MAP", formatNumber(teleState.engineMap, "%.0f"), 0.020},
        {"TC", formatNumber(teleState.tcLevel, "%.0f"), 0.020},
        {"ABS", formatNumber(teleState.absLevel, "%.0f"), 0.020}
    }
    for index, field in ipairs(leftCells) do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        drawCell(sideCell(screen.left, column, row), field[1], field[2], field[3])
    end

    -- Use the side-panel row heights so the center borders align with the grid.
    -- The gear spans the two middle rows, including their internal gutter.
    local rpmCell = cell(centerLeft, screen.top - sideRowHeight, centerWidth, sideRowHeight)
    local speedCell = cell(centerLeft, screen.bottom, centerWidth, sideRowHeight)
    local gearBottom = speedCell.bottom + speedCell.height + gapY
    local gearTop = rpmCell.bottom - gapY
    local gearCell = cell(centerLeft, gearBottom, centerWidth, gearTop - gearBottom)
    drawCell(rpmCell, "RPM", formatNumber(teleState.rpm, "%.0f"), 0.030)
    drawOutlineRect(gearCell.left, gearCell.bottom, gearCell.width, gearCell.height,
        borderThicknessX, borderThicknessY, borderR, borderG, borderB, 1.0)
    setTextColor(1.0, 1.0, 1.0, 1.0)
    local gearSize = fittedSize(teleState.gear, math.min(0.110, gearCell.height * 0.80), gearCell.width * 0.88)
    renderText(gearCell.left + gearCell.width / 2, gearCell.bottom + gearCell.height / 2,
        gearSize, teleState.gear)
    drawCell(speedCell, "SPEED KM/H", formatNumber(teleState.speedKph, "%.0f"), 0.036)

    -- Right column: a full-width delta above six half-width cells.
    local deltaCell = cell(rightLeft, screen.top - sideRowHeight, sideWidth, sideRowHeight)
    local delta = tonumber(teleState.gainLossVal)
    local deltaR, deltaG, deltaB = 1.0, 1.0, 1.0
    -- Keep the near-zero band and unavailable readings neutral.
    if delta ~= nil and math.abs(delta) >= 0.1 then
        if delta < 0 then
            deltaR, deltaG, deltaB = 0.1, 0.9, 0.1
        else
            deltaR, deltaG, deltaB = 0.9, 0.1, 0.1
        end
    end
    drawCell(deltaCell, "GAIN / LOSS", teleState.gainLossVal, 0.030, deltaR, deltaG, deltaB)
    local tyres = teleState.tyreTemps or {}
    local rightCells = {
        {"TYRE 1", formatNumber(tyres[1], "%.0f")},
        {"TYRE 2", formatNumber(tyres[2], "%.0f")},
        {"TYRE 3", formatNumber(tyres[3], "%.0f")},
        {"TYRE 4", formatNumber(tyres[4], "%.0f")},
        {"FUEL L", formatNumber(teleState.fuelLitres, "%.1f")},
        {"FUEL %", formatNumber(teleState.fuelPercent, "%.0f")}
    }
    for index, field in ipairs(rightCells) do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2) + 1
        drawCell(sideCell(rightLeft, column, row), field[1], field[2], 0.020)
    end

    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
    setTextAlignment(RenderText.ALIGN_LEFT)
end
