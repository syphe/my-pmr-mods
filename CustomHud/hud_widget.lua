-- Bridge the immediate-mode drawing to the stock HUD layout editor.
-- Keep this state across script reloads so registration stays idempotent.
CustomHudMod.widgetState = CustomHudMod.widgetState or {}
local state = CustomHudMod.widgetState
state.failedTargets = {}
local widgetId = 'customHudBox'

local function controller(name)
    local gui = g_gui and g_gui.guis and g_gui.guis[name]
    return gui and gui.target
end

local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < math.huge
end

function CustomHudMod.defaultHudBounds()
    local width = 0.28
    local height = width * (g_screenAspectRatio or 16 / 9) * 9 / 16
    return {left = 0.5 - width / 2, bottom = 0.014, width = width, height = height}
end

local function applySavedPosition(widget)
    local positions = MovableWidgetsPage and MovableWidgetsPage.loadedPositions
    local position = positions and positions[widgetId]
    if widget and type(position) == 'table' and finite(position[1]) and finite(position[2]) then
        if widget.absPosition[1] ~= position[1] or widget.absPosition[2] ~= position[2] then
            widget:setAbsolutePosition(position[1], position[2])
        end
    end
end

function CustomHudMod.isHudLayoutEditorOpen()
    return g_gui ~= nil and g_gui.currentGuiName == 'MovableWidgetsPage'
end

local function addWidget(target, editor)
    local widget = target[widgetId]
    if widget == nil then
        local bounds = CustomHudMod.defaultHudBounds()
        widget = GuiElement.new(target)
        -- setId expects XML-created identity metadata; this element is dynamic.
        widget.id = widgetId
        widget:setAnchor(0, 0)
        widget:setPivot(0, 0)
        widget:setSize(bounds.width, bounds.height)
        widget:setAbsolutePosition(bounds.left, bounds.bottom)
        widget.handleFocus = false
        target:addElement(widget)
        target[widgetId] = widget
        applySavedPosition(widget)
    end

    -- Resolution/aspect changes affect height, never the user's placement.
    local bounds = CustomHudMod.defaultHudBounds()
    -- XML loading normally supplies these arrays. Stock keyboard selection
    -- calls updateFramePosition even for elements without a visible frame.
    widget.frameThickness = widget.frameThickness or {0, 0, 0, 0}
    widget.focusedOffset = widget.focusedOffset or {0, 0}
    widget.frameOverlayVisible = widget.frameOverlayVisible or {true, true, true, true}
    if widget.size[1] ~= bounds.width or widget.size[2] ~= bounds.height then
        widget:setSize(bounds.width, bounds.height)
    end
    if editor and not widget.customHudDrawInstalled then
        -- Draw within the GUI tree so selection outlines, menu buttons and
        -- dialogs are composited above the preview by the stock renderer.
        widget.draw = function(self, ...)
            GuiElement.draw(self, ...)
            if CustomHudMod.isHudLayoutEditorOpen() and CustomHudMod.drawHudWidget then
                CustomHudMod.drawHudWidget()
            end
        end
        widget.customHudDrawInstalled = true
    end
    if editor then
        local widgets = target.movableWidgets
        if type(widgets) ~= 'table' then return end
        local found = false
        for _, entry in ipairs(widgets) do
            if entry == widget then found = true break end
        end
        if not found then widgets[#widgets + 1] = widget end
        -- Stock reset indexes this table by ID for every movable widget.
        local originals = MovableWidgetsPage.originalPositions
        if type(originals) == 'table' and originals[widgetId] == nil then
            originals[widgetId] = {bounds.left, bounds.bottom}
        end
    end
    return widget
end

function CustomHudMod.registerHudWidget()
    if type(GuiElement) ~= 'table' or type(GuiElement.new) ~= 'function'
        or type(MovableWidgetsPage) ~= 'table' then return end

    -- Stock placement loading enumerates stock controls explicitly. Extend it
    -- for our ID while leaving the stock load/save/reset implementation intact.
    if state.placementClass ~= MovableWidgetsPage then
        local stockApply = MovableWidgetsPage.applyWidgetPlacements
        if type(stockApply) ~= 'function' then return end
        MovableWidgetsPage.applyWidgetPlacements = function(target, ...)
            stockApply(target, ...)
            applySavedPosition(target and target[widgetId])
        end
        state.placementClass = MovableWidgetsPage
    end

    local hud, editor = controller('HudOverlay'), controller('MovableWidgetsPage')
    for _, entry in ipairs({{hud, false}, {editor, true}}) do
        local target, isEditor = entry[1], entry[2]
        if target and not state.failedTargets[target]
            and (not isEditor or type(target.movableWidgets) == 'table') then
            local ok, err = pcall(addWidget, target, isEditor)
            if not ok then
                state.failedTargets[target] = true
                print('[CUSTOM_HUD] Widget registration failed: ' .. tostring(err))
            elseif not isEditor then
                -- Save updates loadedPositions immediately, but the game does
                -- not re-run applyWidgetPlacements on the live HUD on exit.
                applySavedPosition(target[widgetId])
            end
        end
    end
end

function CustomHudMod.getHudBounds()
    local target = controller(CustomHudMod.isHudLayoutEditorOpen() and 'MovableWidgetsPage' or 'HudOverlay')
    local widget = target and target[widgetId]
    local bounds = CustomHudMod.defaultHudBounds()
    local position = widget and widget.absPosition
    if position and finite(position[1]) and finite(position[2]) then
        bounds.left, bounds.bottom = position[1], position[2]
    end
    bounds.centerX = bounds.left + bounds.width / 2
    bounds.right = bounds.left + bounds.width
    bounds.top = bounds.bottom + bounds.height
    return bounds
end
