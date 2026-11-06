# Saved PMR runtime inspection

Start with [../RUNTIME_NOTES.md](../RUNTIME_NOTES.md) and [../DRAWING_API.md](../DRAWING_API.md).

`delta-runtime.txt` captures the later live best-lap delta inspection and the
rendered-frame verification after fixing the historical-delta lookup.
`delta-probe.lua` is the corresponding bounded read-only console probe.

`runtime-catalog.txt` is a filtered copy of our read-only debugger reflection output, captured on 4 November 2026 while driving and paused in `hud.lua:122`. It contains only the prefixed inspection output, not the full game log.

Record format:

```text
GLOBAL globalName|type
API graphicsRelatedGlobalName|type
TABLE GraphicsClass.member|type[|scalarValue]
VALUE screenGlobal|type|value
CATALOG objectOrClass.member|type[|scalarValue]
```

`actor` means `g_racingManager.playerVehicleData.vehicleActor`; `playerData` means `g_racingManager.playerVehicleData`; `racingManager` means `g_racingManager`. Suffix `Class` means that object's direct `getmetatable(...)`. `overlayManager` means `g_overlayManager`. Dot-separated member paths are descriptive, not necessarily Lua syntax: a key such as `wheel1.tyre_pressure` must be indexed with `["wheel1.tyre_pressure"]`.

Presence does not prove a calling convention. Entries omit most string values deliberately. Captured gameplay scalar values are one snapshot, not units or bounds. Nested tables are only partially expanded. `CATALOG_END` in the source log confirmed the survey finished; the game exited afterward, before the next getter survey ran.

Useful searches from this workspace:

```powershell
rg '^TABLE (Overlay|RenderText|GuiUtils)\.' inspection/runtime-catalog.txt
rg '^CATALOG actorClass.get' inspection/runtime-catalog.txt
rg '^CATALOG playerDataClass.get' inspection/runtime-catalog.txt
rg '^CATALOG racingManagerClass.get' inspection/runtime-catalog.txt
rg '^CATALOG VehicleParameters\.' inspection/runtime-catalog.txt
rg '^GLOBAL .*Telemetry' inspection/runtime-catalog.txt
```

After the user restarted and reattached, `telemetry-enums.txt` captured seven selected enum/helper tables, and `telemetry-enums.csv` expanded their records into `Table,Name,Value` rows. These cover drivetrain, inputs, wheels, chassis, general telemetry, layout constants and unit-modifier method names. Channel identifiers are verified names and numbers; physical units and flat wheel-buffer indexing still need validation.

`drawing-followup.txt` contains 470 additional prefixed records from the next pause: ImGui binding members, texture configuration/slice names, selected slice details, all UI atlas entries, geometry traces, and seven successful vehicle getter checks. It supersedes the earlier probe that produced no results. A bare function-name watch caused Lua compiler dialogs and was replaced with a valid `type(...)` expression.

`ui-atlas.json` preserves all 253 slices from `g_overlayManager.textureConfigs.ui_elements`, sorted by name. Each entry includes filename, default normalized width/height, source pixel rectangle and eight UV coordinates. Texture pixels have not been visually checked. Use this catalog for icons, lights, bars and gradients before attaching again.

`drawOutlineCircle2D(cx,cy,radiusX,lineWidth,segments,r,g,b,a)` was verified through intercepted perimeter calls. It also draws a hardcoded blue center point. `drawPoint` itself is a centered rectangle. Outline rectangles require separate X/Y thicknesses. Full details and the rounded-rectangle minimum-size behavior are in the drawing reference. Temporary substitutions were restored in the same debugger queries.

Further focused inspection could cover unit-modifier registrations, collision enums, font IDs, masks, custom texture loading and completed-lap values. Actual render tests belong in `draw()`, not the paused `update()` call. The engine logged that restriction explicitly. The broad survey produced several thousand console lines; its relationship to the earlier game exit is unknown.
