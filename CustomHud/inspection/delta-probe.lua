-- Read-only inspection of the stock live delta and its vehicle-data accessors.
local function emit(name, value)
    print("[HUD_DELTA] " .. name .. "=" .. tostring(value))
end

local pData = g_racingManager and g_racingManager.playerVehicleData
local widget = g_gui and g_gui.frames and g_gui.frames.DeltaWidget and g_gui.frames.DeltaWidget.target
if type(DeltaWidget) == "table" and type(DeltaWidget.ComparisonMode) == "table" then
    for key, value in pairs(DeltaWidget.ComparisonMode) do emit("ComparisonMode." .. tostring(key), value) end
end
if type(widget) == "table" then
    for _, key in ipairs({"selectedComparisonMode", "deltaDiff", "lastDeltaTime", "lastLapTime"}) do
        emit("widget." .. key, widget[key])
    end
    if type(widget.deltaText) == "table" then emit("widget.deltaText.text", widget.deltaText.text) end
end
if type(pData) == "table" then
    for _, key in ipairs({"lastLapDelta", "lapDelta", "currentLapDelta", "delta", "currentDeltaTimesInvalid", "lastLapDeltaTimesInvalid", "lapDeltaTrackedSegment", "lapDeltaTrackedSegmentProgress"}) do
        emit("pData." .. key, pData[key])
    end
    if type(pData.bestValidLapTime) == "table" then
        emit("bestLap.timeSeconds", pData.bestValidLapTime.timeSeconds)
        emit("bestLap.invalid", pData.bestValidLapTime.invalid)
    end
end
if type(debug) == "table" and type(debug.info) == "function" then
    for _, entry in ipairs({
        {"DeltaWidget.getCurrentDelta", DeltaWidget and DeltaWidget.getCurrentDelta},
        {"playerData.getCurrentLapDelta", pData and pData.getCurrentLapDelta},
        {"playerData.getLastLapDelta", pData and pData.getLastLapDelta},
        {"DeltaWidget.update", DeltaWidget and DeltaWidget.update}
    }) do
        if type(entry[2]) == "function" then
            local ok, count, variadic = pcall(debug.info, entry[2], "a")
            emit(entry[1] .. ".arity", tostring(ok) .. " " .. tostring(count) .. " " .. tostring(variadic))
            local sourceOk, source = pcall(debug.info, entry[2], "s")
            local lineOk, line = pcall(debug.info, entry[2], "l")
            emit(entry[1] .. ".source", tostring(source) .. ":" .. tostring(line))
        end
    end
end
if pData and type(pData.getCurrentLapDelta) == "function" then
    local ok, value, second = pcall(pData.getCurrentLapDelta, pData)
    emit("getCurrentLapDelta()", tostring(ok) .. " " .. tostring(value) .. " " .. tostring(second))
end
local actor = pData and pData.vehicleActor
if actor and type(actor.getVehicleParamValue) == "function" then
    local ok, found, value = pcall(actor.getVehicleParamValue, actor, "lapDelta")
    emit("getVehicleParamValue(lapDelta)", tostring(ok) .. " " .. tostring(found) .. " " .. tostring(value))
end
local hud = g_gui and g_gui.guis and g_gui.guis.HudOverlay and g_gui.guis.HudOverlay.target
local liveWidget = hud and hud.deltaWidget
for _, entry in ipairs({{"HudOverlay.deltaWidget", liveWidget}, {"HudOverlay.deltaWidget.target", liveWidget and liveWidget.target}, {"template", widget}}) do
    local object = entry[2]
    if type(object) == "table" then
        emit(entry[1] .. ".mode", object.selectedComparisonMode)
        emit(entry[1] .. ".text", type(object.deltaText) == "table" and object.deltaText.text)
        if type(object.getCurrentDelta) == "function" and object.playerData ~= nil then
            local ok, first, second, third = pcall(object.getCurrentDelta, object)
            emit(entry[1] .. ".getCurrentDelta()", tostring(ok) .. " " .. tostring(first) .. " " .. tostring(second) .. " " .. tostring(third))
        end
    end
end
if DeltaWidget and DeltaWidget.ComparisonMode and type(DeltaWidget.getCurrentDelta) == "function" then
    local data = {
        getCurrentLapDelta = function(self, ...)
            emit("Player_Best calls getCurrentLapDelta args", select("#", ...))
            return 12.345
        end
    }
    local dummy = {selectedComparisonMode = DeltaWidget.ComparisonMode.Player_Best, playerData = data}
    local ok, value = pcall(DeltaWidget.getCurrentDelta, dummy)
    emit("Player_Best trace", tostring(ok) .. " " .. tostring(value))
end
emit("PROBE_END", true)
