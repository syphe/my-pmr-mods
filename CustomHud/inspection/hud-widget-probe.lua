-- Read-only, bounded inspection. Run through the connected GIANTS debug console:
-- source(CustomHudRoot .. 'inspection/hud-widget-probe.lua')
-- Repeated source() calls produced no new output in this session, even with true
-- as a second argument. Revisions were evaluated directly as a local-function
-- expression in the console. No stock widgets/settings are modified by this file.
local function describe(name, object)
    if type(object) ~= "table" then
        print("[HUD_WIDGET] " .. name .. "=" .. type(object))
        return
    end
    local entries = {}
    for key, value in pairs(object) do
        local entry = tostring(key) .. "=" .. type(value)
        if type(value) == "number" or type(value) == "boolean" then
            entry = entry .. ":" .. tostring(value)
        end
        entries[#entries + 1] = entry
    end
    table.sort(entries)
    local count = #entries
    while #entries > 70 do
        entries[#entries] = nil
    end
    print("[HUD_WIDGET] " .. name .. " (" .. count .. ") " .. table.concat(entries, "; "))
end

describe("HUDElement", HUDElement)
describe("MovableWidgetsPage", MovableWidgetsPage)
describe("HudSettingsFrame", HudSettingsFrame)
describe("DeltaWidget", DeltaWidget)
describe("g_gui", g_gui)
for _, name in ipairs({"HudOverlay", "MovableWidgetsPage"}) do
    local gui = g_gui and g_gui.guis and g_gui.guis[name]
    describe(name .. ".target", gui and gui.target)
    describe(name .. ".target metatable", gui and type(gui.target) == "table" and getmetatable(gui.target))
    local target = gui and gui.target
    if type(target) == "table" then
        local fields = {}
        for key, value in pairs(target) do
            local field = string.lower(tostring(key))
            if string.find(field, "widget") or string.find(field, "mov") or string.find(field, "selected") or string.find(field, "register") then
                fields[#fields + 1] = tostring(key) .. "=" .. type(value)
                if type(value) == "table" and (string.find(field, "widgets") or string.find(field, "movable")) then
                    describe(name .. ".target." .. tostring(key), value)
                end
            end
        end
        table.sort(fields)
        print("[HUD_WIDGET] " .. name .. ".target widget fields " .. table.concat(fields, "; "))
    end
end
local delta = g_gui and g_gui.frames and g_gui.frames.DeltaWidget
describe("DeltaWidget.target", delta and delta.target)
local page = g_gui and g_gui.guis and g_gui.guis.MovableWidgetsPage and g_gui.guis.MovableWidgetsPage.target
if page and type(page.movableWidgets) == "table" then
    describe("movableWidgets[1]", page.movableWidgets[1])
    for index, widget in ipairs(page.movableWidgets) do
        if type(widget) == "table" then
            print("[HUD_WIDGET] movableWidget " .. index .. " id=" .. tostring(widget.id) .. " name=" .. tostring(widget.name) .. " typeName=" .. tostring(widget.typeName))
        end
    end
end
for _, name in ipairs({"HudOverlay", "MovableWidgetsPage"}) do
    local gui = g_gui and g_gui.guis and g_gui.guis[name]
    local element = gui and gui.target and gui.target.deltaWidgetBox
    if type(element) == "table" then
        print("[HUD_WIDGET] " .. name .. ".deltaWidgetBox id=" .. tostring(element.id))
        describe(name .. ".deltaWidgetBox.position", element.position)
        describe(name .. ".deltaWidgetBox.absPosition", element.absPosition)
        describe(name .. ".deltaWidgetBox.size", element.size)
    end
end
local liveHud = g_gui and g_gui.guis and g_gui.guis.HudOverlay and g_gui.guis.HudOverlay.target
print("[HUD_WIDGET] editor/live delta same object=" .. tostring(page and liveHud and page.deltaWidgetBox == liveHud.deltaWidgetBox))
describe("io", io)
if type(io) == "table" and type(io.open) == "function" then
    local ok, file, reason = pcall(io.open, "dataS/s4sGame/scripts/hud/MovableWidgetsPage.lua", "r")
    print("[HUD_WIDGET] stock source readable=" .. tostring(ok and file ~= nil) .. " reason=" .. tostring(reason))
    if ok and file then file:close() end
end
describe("MovableWidgetsPage.loadedPositions", MovableWidgetsPage and MovableWidgetsPage.loadedPositions)
describe("MovableWidgetsPage.loadedPositions.deltaWidgetBox", MovableWidgetsPage and MovableWidgetsPage.loadedPositions.deltaWidgetBox)
print("[HUD_WIDGET] saveFileName=" .. tostring(MovableWidgetsPage and MovableWidgetsPage.saveFileName))
describe("debug", debug)
if type(debug) == "table" and type(debug.info) == "function" then
    for _, entry in ipairs({
        {"HudOverlay.registerHudWidgets", HudOverlay.registerHudWidgets},
        {"MovableWidgetsPage.register", MovableWidgetsPage.register},
        {"MovableWidgetsPage.applyWidgetPlacements", MovableWidgetsPage.applyWidgetPlacements},
        {"MovableWidgetsPage.mouseEvent", MovableWidgetsPage.mouseEvent},
        {"MovableWidgetsPage.writeSaveData", MovableWidgetsPage.writeSaveData},
        {"GuiElement.new", GuiElement.new},
        {"GuiElement.setPosition", GuiElement.setPosition}
    }) do
        for _, option in ipairs({"a", "s", "l", "n"}) do
            local ok, first, second = pcall(debug.info, entry[2], option)
            print("[HUD_WIDGET] debug.info " .. entry[1] .. " " .. option .. " " .. tostring(ok) .. " " .. tostring(first) .. " " .. tostring(second))
        end
    end
end
print("[HUD_WIDGET] PROBE_END")
