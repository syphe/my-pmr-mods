import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from lupa import LuaRuntime


WIDTH = 1920
HEIGHT = 1080
DEFAULT_OUTPUT = Path(__file__).with_name("hud-preview.png")
HUD_FILE = Path(__file__).with_name("hud.lua")


def font(size, bold=False):
    candidates = [
        r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf",
        r"C:\Windows\Fonts\segoeuib.ttf" if bold else r"C:\Windows\Fonts\segoeui.ttf",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def sx(value):
    return int(value * WIDTH)


def sy(value):
    return HEIGHT - int(value * HEIGHT)


def rgba(r, g, b, a=1.0):
    del a
    return tuple(int(channel * 255) for channel in (r, g, b))


class HudPreview:
    def __init__(self, args):
        self.args = args
        self.image = Image.new("RGB", (WIDTH, HEIGHT), (12, 15, 18))
        self.draw = ImageDraw.Draw(self.image)
        self.text_alignment = "left"
        self.text_color = (1, 1, 1, 1)

    def execute(self):
        lua = LuaRuntime(unpack_returned_tuples=True)

        render_text = lua.globals().renderText
        lua.globals()["source"] = lambda *_: None
        lua.globals()["print"] = lambda *values: print(*values) if False else None
        lua.globals()["g_screenAspectRatio"] = WIDTH / HEIGHT
        lua.globals()["g_screenWidth"] = WIDTH
        lua.globals()["g_screenHeight"] = HEIGHT

        render_text_align = lua.table_from({
            "ALIGN_LEFT": 1,
            "ALIGN_CENTER": 2,
            "ALIGN_RIGHT": 3,
        })
        lua.globals()["RenderText"] = lua.table_from({"ALIGN_LEFT": 1, "ALIGN_CENTER": 2, "ALIGN_RIGHT": 3})

        lua.globals()["drawFilledRect"] = self.draw_filled_rect
        lua.globals()["drawOutlineRect"] = self.draw_outline_rect
        lua.globals()["drawLine2D"] = self.draw_line
        lua.globals()["setTextAlignment"] = lambda alignment: setattr(
            self, "text_alignment", {1: "left", 2: "center", 3: "right"}.get(alignment, "left")
        )
        lua.globals()["setTextColor"] = self.set_text_color
        lua.globals()["renderText"] = self.render_text

        lua.execute(self.args.lua_file.read_text(encoding="utf-8"))

        telemetry = lua.table_from({
            "drivetrain": lua.table_from({1: self.args.rpm}),
            "input": lua.table_from({6: int(self.args.gear) if str(self.args.gear).isdigit() else 0}),
        })
        actor = lua.table_from({
            "telemetryManager": lua.table_from({"items": lua.table_from({1: telemetry})}),
            "telemetryIndex": 1,
        })

        def get_shift_lights_range(_actor):
            return self.args.max_rpm, self.args.start_rpm, self.args.shift_rpm

        actor["getShiftLightsRange"] = get_shift_lights_range
        player_data = lua.table_from({
            "vehicleActor": actor,
            "raceEventPosition": self.args.position,
            "lap": self.args.lap,
            "engTemp": self.args.engine_temp,
            "bestValidLapTime": lua.table_from({"invalid": False, "timeSeconds": 102.86}),
            "lapDelta": float(self.args.delta),
        })
        lua.globals()["g_racingManager"] = lua.table_from({"playerVehicleData": player_data})
        lua.globals()["g_pendingExit"] = False

        lua.globals()["update"](0.016)
        lua.globals()["draw"]()

    def draw_filled_rect(self, x, y, width, height, r, g, b, a=1.0):
        self.draw.rectangle(
            (sx(x), sy(y + height), sx(x + width), sy(y)),
            fill=rgba(r, g, b, a),
        )

    def draw_outline_rect(self, x, y, width, height, thickness_x, thickness_y, r, g, b, a=1.0):
        fill = rgba(r, g, b, a)
        line_x = max(1, int(thickness_x * WIDTH))
        line_y = max(1, int(thickness_y * HEIGHT))
        left, top, right, bottom = sx(x), sy(y + height), sx(x + width), sy(y)
        self.draw.rectangle((left, top, right, top + line_y), fill=fill)
        self.draw.rectangle((left, bottom - line_y, right, bottom), fill=fill)
        self.draw.rectangle((left, top, left + line_x, bottom), fill=fill)
        self.draw.rectangle((right - line_x, top, right, bottom), fill=fill)

    def draw_line(self, x1, y1, x2, y2, width, r, g, b, a=1.0):
        self.draw.line(
            (sx(x1), sy(y1), sx(x2), sy(y2)),
            fill=rgba(r, g, b, a),
            width=max(1, int(width * HEIGHT)),
        )

    def set_text_color(self, r, g, b, a=1.0):
        self.text_color = (r, g, b, a)

    def render_text(self, x, y, size, text):
        text = str(text)
        pixel_size = max(8, int(size * HEIGHT))
        text_font = font(pixel_size, bold=len(text) <= 2)
        pixel_x = sx(x)
        pixel_y = sy(y)
        bbox = self.draw.textbbox((0, 0), text, font=text_font)
        text_height = bbox[3] - bbox[1]
        if self.text_alignment == "center":
            anchor_x = pixel_x
        elif self.text_alignment == "right":
            anchor_x = pixel_x
        else:
            anchor_x = pixel_x
        text_width = self.draw.textlength(text, font=text_font)
        if self.text_alignment == "center":
            pixel_x -= text_width / 2
        elif self.text_alignment == "right":
            pixel_x -= text_width
        self.draw.text(
            (pixel_x, pixel_y - text_height / 2),
            text,
            font=text_font,
            fill=rgba(*self.text_color),
        )

    def save(self):
        self.image.convert("RGBA").save(self.args.output)
        print(self.args.output.resolve())


def parse_args():
    parser = argparse.ArgumentParser(description="Render the current HUD Lua file with representative telemetry.")
    parser.add_argument("--output", "-o", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--rpm", type=float, default=7200)
    parser.add_argument("--start-rpm", type=float, default=6000)
    parser.add_argument("--max-rpm", type=float, default=7500)
    parser.add_argument("--shift-rpm", type=float, default=7350)
    parser.add_argument("--gear", default="4")
    parser.add_argument("--position", type=int, default=3)
    parser.add_argument("--lap", type=int, default=7)
    parser.add_argument("--delta", default="+0.24")
    parser.add_argument("--engine-temp", type=int, default=101)
    parser.add_argument("--engine-map", type=int, default=3)
    parser.add_argument("--brake-bias", type=float, default=65.0)
    parser.add_argument("--lua-file", type=Path, default=HUD_FILE)
    return parser.parse_args()


if __name__ == "__main__":
    arguments = parse_args()
    arguments.lua_file = arguments.lua_file.resolve()
    preview = HudPreview(arguments)
    preview.execute()
    preview.save()
