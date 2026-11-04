# Project Motor Racing HUD drawing reference

Inspected 4 November 2026 in the running game, paused in `hud.lua:122` during driving. See [RUNTIME_NOTES.md](RUNTIME_NOTES.md) for tested telemetry reads and [inspection/runtime-catalog.txt](inspection/runtime-catalog.txt) for the searchable runtime inventory.

## Evidence levels

- **Present:** the running PMR Lua environment exposed this name and type. This does not establish its signature or behavior.
- **Existing HUD:** the call convention is already used in `hud.lua`.
- **Runtime trace:** the PMR Lua helper ran while its lower-level drawing calls were intercepted and recorded, then restored. This verifies arguments and generated geometry, not final pixels.
- **GIANTS reference:** a convention documented for Farming Simulator 25, whose engine shares these names. This is a useful implementation lead, not proof that PMR behaves identically.
- **Proposed:** an implementation built from known primitives; still needs an in-game visual check.

Rendering must be done in `draw()`; PMR logged an explicit error for `renderOverlay` from the paused `update()` frame. The latest pause supplied successful geometry traces, stock texture metadata and vehicle getters. See [inspection/drawing-followup.txt](inspection/drawing-followup.txt) for the evidence. Final circle appearance has not been rendered and checked. The HUD itself was not changed.

## Circles for the shift lights

Runtime tracing confirmed this PMR helper:

```lua
drawOutlineCircle2D(cx, cy, radiusX, lineWidth, segments, r, g, b, a)
```

It generates `segments` calls to `drawLine2D`, with X radius `radiusX` and Y radius `radiusX * g_screenAspectRatio`. A 16-segment test generated 16 lines and forwarded the requested width and RGBA correctly. **It also calls `drawPoint` at the center with hardcoded blue `(0,0,1,1)` and a 4-by-4-pixel size at 2560x1440.** Avoid this helper for clean HUD LEDs unless that debug marker is acceptable. For an outline, a custom line loop can reproduce the perimeter without the marker. It is an outline, not a filled disk.

No global filled-circle, ellipse, or filled 2D triangle function was found. `drawDebugTriangle` and `drawDebugPolygon` exist, but should not be assumed to be screen-space HUD primitives.

Three ways to make solid circular LEDs:

1. A white circle texture with a transparent exterior, loaded once and tinted for each light. The native overlay functions and the `Overlay` class are present. Stock slices `ui_elements.shiftLight` and `ui_elements.dotSmall` are now confirmed candidates, with UVs captured below. Check their actual silhouette and tinting before choosing one. This is the most promising route for smooth edges and a small number of draw calls.
2. Horizontal strips drawn with the existing `drawFilledRect`. This needs no asset or unknown circle signature. An example is included below. It is sufficient for small LEDs, with more draw calls and potentially visible edge steps.
3. `drawFilledRectRound` uses a scale argument and four textured corners plus a center rectangle. A runtime trace at scale `1` generated 27-by-27-pixel corners and expanded a requested height of `0.020` to `0.0375` at 1440p. Its fifth argument is **not** a corner-radius fraction. It is unsuitable as a drop-in circle call without accounting for its minimum dimensions.

### Coordinate and aspect rules

The HUD uses normalized X/Y coordinates and sizes. In the captured session:

| Global | Value |
| --- | ---: |
| `g_screenWidth`, `g_screenHeight` | 2560, 1440 |
| `g_screenAspectRatio` | 1.7777777777777777 |
| `g_presentedScreenAspectRatio` | 1.7777777910232544 |
| `g_aspectScaleX`, `g_aspectScaleY` | approximately 1, 1 |
| `g_referenceScreenWidth`, `g_referenceScreenHeight` | 1920, 1080 |

For a physical circle of diameter `d` pixels, use `width = d / g_screenWidth`, `height = d / g_screenHeight`. For a diameter specified in normalized screen height, use `width = height / g_screenAspectRatio`. Equal normalized width and height produce an ellipse on a nonsquare viewport. Triple-screen, VR and UI-resolution scaling still need separate visual validation; the two aspect ratios happened to agree in this session.

The existing LEDs are `0.012` wide by `0.010` high: about 30.72 by 14.4 pixels at the captured resolution. To keep their current height, use diameter `0.010`, width `0.005625`, and preserve the centers at `ledX + ledWidth/2`, `ledY + 0.005`. Keeping their current width instead would require height `0.0213333`, which may need layout changes.

GIANTS documents the screen origin as bottom-left for [renderText](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=30&function=845&version=engine), and independent normalized width/height for [renderOverlay](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=17&function=383&version=engine).

### Asset-free filled circle example (proposed)

This example uses only the rectangle convention already in the HUD. `diameterY` is in normalized screen height; `cx,cy` are the center. Call only from `draw()`. It has not been rendered in PMR.

```lua
local function drawLedCircle(cx, cy, diameterY, r, g, b, a)
    local screenW, screenH = g_screenWidth, g_screenHeight
    if diameterY <= 0 or screenW == nil or screenH == nil
        or screenW <= 0 or screenH <= 0 then
        return
    end
    local radiusY = diameterY * 0.5
    local radiusX = radiusY * screenH / screenW
    local rows = math.max(1, math.ceil(diameterY * screenH))
    local rowHeight = diameterY / rows
    for row = 0, rows - 1 do
        local unitY = 2 * (row + 0.5) / rows - 1
        local halfWidth = radiusX * math.sqrt(math.max(0, 1 - unitY * unitY))
        drawFilledRect(cx - halfWidth, cy - radiusY + row * rowHeight,
            halfWidth * 2, rowHeight, r, g, b, a)
    end
end

-- Replace the existing per-LED rectangle inside the LED loop with:
drawLedCircle(ledX + ledWidth * 0.5, ledY + 0.005, 0.010, r, g, b, 1.0)
```

At 1440p this uses 15 strips per LED, or 120 rectangle calls for eight lights. It approximates the disk at strip midpoints. Prefer the texture route if edge quality or draw-call cost matters. A dark outer disk and a smaller colored inner disk can form a bezel; the existing RPM and flashing logic can be retained.

## Immediate drawing primitives

| Name | Evidence and known convention |
| --- | --- |
| `drawFilledRect(x,y,w,h,r,g,b,a)` | Present; existing HUD convention. GIANTS GUI examples also pass optional clip bounds after RGBA, not tested here. |
| `drawFilledRectRound(x,y,w,h,scale,r,g,b,a)` | Runtime trace: five overlay draws; corners/minimum dimensions depend on scale. |
| `drawLine2D(x1,y1,x2,y2,width,r,g,b,a)` | Runtime trace: rotates a rectangle about the start point, draws it with height `width`, then resets rotation. Width is normalized screen height; line length/angle account for aspect. |
| `drawOutlineRect(x,y,w,h,thicknessX,thicknessY,r,g,b,a)` | Runtime trace: four rectangles inside the specified bounds. Separate normalized X/Y thicknesses; use `thicknessX = thicknessY / aspect` for equal pixel thickness. |
| `drawOutlineCircle2D(cx,cy,radiusX,lineWidth,segments,r,g,b,a)` | Runtime trace; aspect-correct perimeter plus hardcoded blue center marker. |
| `drawPoint(cx,cy,w,h,r,g,b,a)` | Runtime trace: centered rectangle at `(cx-w/2,cy-h/2)`. It does not generate a circular point. |
| `new2DLayer` | Present; layer ordering behavior untested. |
| `clearOverlayArea`, `set2DMaskFromOverlay`, `set2DMaskFromTexture` | Present; clipping/masking leads, not tested. |

Call examples for rounded rectangles and lines appear in GIANTS' [IngameMessage](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=47&class=531&version=script). GIANTS' [POIInfoDisplay](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=1&class=100&version=script) passes `self.uiScale` as the fifth rounded-rectangle argument. [InputGlyphElement](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=465&version=script) contains the `drawPoint` example. These are FS25 examples, not extracted PMR stock scripts.

## Text

All names below were present. Only alignment, color and `renderText` are already used by this HUD.

| Purpose | Functions/conventions |
| --- | --- |
| Draw | `renderText(x,y,size,text)`; `renderText3D` also exists |
| Layout | `setTextAlignment`, `setTextVerticalAlignment`, `setTextWrapWidth`, `setTextLineHeightScale`, `setTextFirstLineIndentation`, `setTextLineBounds` |
| Appearance | `setTextColor`, `setTextBold`, `setTextWidthScale`, `setTextFont`, `setTextRotation` |
| Measure | `getTextWidth(size,text)`; `getTextHeight(size,text)` returns height and line count in GIANTS reference; `getTextLength`, `getTextLineLength` also present |
| Clip | `setTextClipArea(minX,minY,maxX,maxY)`; GIANTS reference resets with `(0,0,1,1)` |
| Advanced | `setTextDepthTestEnabled`, `setTextRenderOverlay`, 3D measurement functions |
| Unicode | `getCanRenderUnicode`, `replaceUnrenderableCharacters` |

Font identifiers and font loading remain unresolved. Do not assume a string font family or that arbitrary TTF files can be loaded.

Runtime-confirmed `RenderText` constants:

```lua
ALIGN_LEFT = 0
ALIGN_CENTER = 1
ALIGN_RIGHT = 2
VERTICAL_ALIGN_BASELINE = 0
VERTICAL_ALIGN_TOP = 1
VERTICAL_ALIGN_MIDDLE = 2
VERTICAL_ALIGN_BOTTOM = 3
DEFAULT_LINE_HEIGHT_SCALE = 1.100000023841858
```

Text settings are shared drawing state. Set required values explicitly, and restore any wrapping, clipping, rotation or scaling introduced by a custom element so later text is not affected. The HUD currently resets only horizontal alignment.

Useful GIANTS signatures: [getTextWidth](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=30&function=844&version=engine), [getTextHeight](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=30&function=841&version=engine), [setTextClipArea](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=30&function=848&version=engine), [setTextRotation](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=30&function=854&version=engine).

## Images, icons, textures and gradients

Present native functions include:

```text
createImageOverlay, createImageOverlayWithTexture
createOverlayTextureFromFile, createWebImageOverlay
renderOverlay, getImageOverlayFromId
setOverlayColor, setOverlayCornerColor
setOverlayUVs, setOverlayRotation, setOverlayLayer
setOverlaySignedDistanceFieldWidth
createRenderOverlay, beginRenderTargetOverlay, endRenderTargetOverlay
setRenderOverlayCamera, setRenderOverlayAspectRatio, updateRenderOverlay
createVideoOverlay, updateVideoOverlay, playVideoOverlay, stopVideoOverlay
isVideoOverlayPlaying, isVideoOverlayReadyToPlay, setVideoOverlayPosition
```

GIANTS documents [createImageOverlay(filename[,deferredActivation])](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=17&function=380&version=engine) and [renderOverlay(id,x,y,w,h)](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=17&function=383&version=engine). Its [setOverlayCornerColor(id,corner,r,g,b,a)](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=17&function=387&version=engine) supports interpolated corner colors (0 bottom-left, 1 top-left, 2 bottom-right, 3 top-right). PMR presence is verified; rendering and gradient behavior are not.

The runtime `Overlay` class exposes `new`, `render`, `renderCustom`, `draw`, `setPosition`, `setDimension`, `setScale`, `setColor`, `setImage`, `setUVs`, `setSliceId`, `setRotation`, `setAlignment`, visibility accessors and cleanup methods. GIANTS' [Overlay class](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=474&version=script) gives this starting convention:

```lua
-- Reference convention; not executed in PMR.
local icon = Overlay.new(filename, x, y, width, height)
icon:setColor(r, g, b, a)
icon:render() -- inside draw()
-- Release the owned overlay when the mod unloads.
```

Create reusable textures outside the per-frame draw loop. White texture pixels permit color tinting; transparent exterior pixels provide the circular silhouette. Supported custom PMR file formats and the appropriate reload/unload hook are still unverified.

### Stock atlas captured from PMR

`g_overlayManager.textureConfigs` contains `flags`, `controllerSymbols`, and `ui_elements`. The UI texture is `dataS/menu/newUI/ui_elements.png`, 4096 by 4096 pixels. All **253 UI slices**, their default normalized sizes, pixel rectangles and eight UV coordinates are saved in [inspection/ui-atlas.json](inspection/ui-atlas.json). These include fuel, temperatures, tyre icons, flags, radar, gradients, bars and buttons.

| Slice ID suffix (`ui_elements.` prefix) | Atlas rectangle: X Y width height, pixels |
| --- | --- |
| `shiftLight` | 4080 1484 15 15 |
| `dotSmall` | 4085 562 10 10 |
| `digidashDot` | 4085 534 10 10 |
| `digidashDotSelected` | 4085 548 10 10 |
| `greenLight` | 2216 1940 65 65 |
| `redLight` | 3519 551 66 65 |
| `yellowLight` | 1847 3413 65 65 |

This lookup was executed successfully and returns the slice table:

```lua
local slice = g_overlayManager:getSliceInfoById("ui_elements.shiftLight")
-- slice.filename, slice.uvs (8 numbers), slice.width, slice.height,
-- slice.size, slice.imageSize, slice.uvsStr, slice.sliceId
```

The atlas pixel rectangle is source-image metadata. Use the captured `uvs` array instead of manually flipping the vertical coordinate. Default slice sizes use the 1920-by-1080 reference scale: the 15-pixel `shiftLight` has width about `0.0078125`, height `0.0138889`. Override display dimensions to preserve the custom HUD's intended LED size. The texture pixels themselves have not been visually inspected, so the names and square bounds do not prove a white circular silhouette.

Runtime overlay alignment values differ from text values:

```text
Vertical: BOTTOM=1, MIDDLE=2, TOP=3
Horizontal: LEFT=4, CENTER=5, RIGHT=6
```

## Higher-level GUI and other useful leads

Captured member catalogs include `GuiElement`, `TextElement`, `RenderElement`, `GuiOverlay`, `GuiUtils`, `OverlayManager`, `HudOverlay` and `DebugDrawingLua`.

- `GuiUtils`: screen normalization, text normalization, pixel alignment, UV creation/rotation and color arrays.
- `GuiElement`: anchoring, pivots, positions, sizes, alpha, clipping, child elements, profiles, fade-in/out and draw callbacks.
- `TextElement`: formatted text, layout, scrolling and state colors.
- `OverlayManager`: texture configurations, slice lookup and named overlay creation.
- `HudOverlay`: `updateShiftLightsColors`, `updateDigiDashInfo`, HUD visibility and widgets. Flags `USE_CPP_FFB`, `USE_CPP_LEADERBOARD`, `USE_CPP_MINIMAP`, `USE_CPP_PHYSICS`, `USE_CPP_RADAR`, `USE_CPP_TIRES_INFO` were all true. These flags suggest stock widgets partly use native implementations; they do not prevent custom Lua rendering.
- `DebugDrawingLua`: circle/sphere/box/line/point and timed text helpers; signatures and coordinate spaces unresolved.
- Global `ImGuiLua` and the metatable of `ImGui` were captured in the follow-up. They expose debug-window registration, text, buttons, sliders, tables, combos, tabs and style colors. No `GetWindowDrawList`, `AddCircle`, or `AddCircleFilled` member appeared. These bindings do not provide a discovered route to arbitrary filled HUD circles.

## Reuse and remaining limits

### Native HUD layout editor: live inspection, 4 November 2026

Read-only queries worked in VS Code's connected Debug Console while the game was
running, without a breakpoint. Evidence is saved in
[inspection/hud-widgets-runtime.txt](inspection/hud-widgets-runtime.txt); the
bounded inspection code is [inspection/hud-widget-probe.lua](inspection/hud-widget-probe.lua).
No stock widget or saved position was changed.

The editor controller is `g_gui.guis.MovableWidgetsPage.target`, and the live HUD
controller is `g_gui.guis.HudOverlay.target`. `g_gui.guis[name]` itself is a GUI
wrapper; inspect `.target` for controller fields and its metatable for methods.

The editor's `.movableWidgets` is an array of 18 GUI elements in this session.
Entries expose `id`, `position`, `absPosition`, `size`, `parent`, and `target`.
Their `typeName` values include `GuiElement`, `BoxLayout`, and `Bitmap`. The
`HUDElement` class also exists, but it is not the type of the inspected editor
entries. There is not yet evidence that constructing a `HUDElement` alone adds
anything to the layout editor.

Editor and live-HUD widgets are separate objects with matching IDs. For example,
both `.deltaWidgetBox` elements had `id = "deltaWidgetBox"`, absolute position
`{0.41927083393481246, 0.8814814814814815}`, and size
`{0.16145833213037503, 0.044444444444444446}`. Their local position was instead
`{0, -0.07407407407407407}`: drawing must account for parent transforms rather
than interpreting local `position` directly as screen coordinates.

`MovableWidgetsPage.loadedPositions` maps widget IDs to two-number coordinate
arrays. Its `deltaWidgetBox` entry matched the absolute position above. The
read-only check of `savegame1/widgetPlacements.xml` confirmed matching persisted
IDs and coordinates. `MovableWidgetsPage.saveFileName` is `widgetPlacements.xml`.
The controller exposes dragging, gamepad movement, snap-to-grid, selection, reset,
placement application, and save/load methods.

This runtime exposes **`debug.info`**, although `debug.getinfo` and
`debug.getlocal` were absent in the earlier inspection. Guarded calls with a
function and options `"a"`, `"s"`, `"l"`, and `"n"` returned arity/variadic flag,
source path, line, and name. Observed definitions:

| Function | Parameter count, including self when applicable | Source / line |
| --- | ---: | --- |
| `HudOverlay.registerHudWidgets` | 1 | `dataS/s4sGame/scripts/hud/HudOverlay.lua:254` |
| `MovableWidgetsPage.register` | 0 | `dataS/s4sGame/scripts/hud/MovableWidgetsPage.lua:226` |
| `MovableWidgetsPage.applyWidgetPlacements` | 1 | Same file, line 100 |
| `MovableWidgetsPage.mouseEvent` | 7 | Same file, line 259 |
| `MovableWidgetsPage.writeSaveData` | 3 | Same file, line 473 |
| `GuiElement.new` | 2 | `dataS/scripts/gui/elements/GuiElement.lua:150` |
| `GuiElement.setPosition` | 3 | Same file, line 1248 |

None were variadic. Arity does not identify argument semantics.
`MovableWidgetsPage.register()` takes no parameters; do not assume it is a
per-widget registration call. The body of `registerHudWidgets` remains unread.
Opening the stock Lua file through `io.open` did not yield a readable file.

**Implementation inference, not yet tested:** create corresponding custom GUI
containers with the same stable ID in the editor and live HUD, make the editor
container participate in `.movableWidgets`, and drive the custom renderer from
the applicable container's absolute bounds. Editor selection, save/reset, live
placement application, screen lifecycle, and reload handling still need actual
custom-widget validation. No custom registration or drag behavior was installed
during this inspection.

The saved catalog records 3,231 global name/type pairs, 432 graphics class members, 8 screen values and 1,369 selected gameplay object/class entries. It includes discovered setters and lifecycle methods as names only; these were not called. Search it before attaching again.

Ordinary changes to HUD layout, colors, labels, RPM thresholds, flashing, bars, text alignment, outlines, stock icon selection and circles built from rectangles can be planned from these notes. New native signatures, font selection, custom asset loading, masks, VR/triple-screen behavior, final visual appearance and values after completing laps may still require a focused runtime check.

The local install exposed no loose Lua stock scripts in the file search; the principal script archive is `dataS.gar`. No archive extraction or decompilation was attempted. Runtime `string.dump`, `debug.getinfo`, and `debug.getlocal` were unavailable. The circle helper's source path was identified by a guarded error and its argument mapping was established by intercepted drawing calls. All temporary function substitutions were restored in the same queries. A bare function-name watch caused repeated compiler dialogs; it was replaced with `type(drawOutlineCircle2D)`.

The reattached session also supplied [telemetry-enums.csv](inspection/telemetry-enums.csv) and [the original enum output](inspection/telemetry-enums.txt), covering drivetrain, inputs, wheels, chassis, general telemetry, buffer layout and unit-modifier method names.
