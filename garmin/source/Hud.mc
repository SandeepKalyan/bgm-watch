import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// The shared look of every screen: a tactical head-up display. Black
// background, cyan line work, a ring of ticks around the bezel, and gauges
// built from blocks.
module Hud {

    const CYAN = 0x35C8F5;
    const CYAN_DIM = 0x17647F;
    const CYAN_DARK = 0x0A2A36;
    const WHITE = 0xFFFFFF;
    const GREY = 0x9AA7AB;
    const RED = 0xFF4438;
    const BLACK = 0x000000;

    const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    var _fonts as Dictionary<Number, Graphics.FontType> = {} as Dictionary<Number, Graphics.FontType>;
    var _screenWidth as Number = 0;

    // Where the screen's centre line falls inside a list row or title.
    // The system keeps a strip at the left of a list for its own focus
    // marker, so the area handed to a row can be narrower than the screen and
    // sit to the right of centre.
    function centerX(dc as Dc) as Number {
        if (_screenWidth == 0) {
            _screenWidth = System.getDeviceSettings().screenWidth;
        }
        var w = dc.getWidth();
        return (w >= _screenWidth) ? w / 2 : w - _screenWidth / 2;
    }

    // Condensed bold face at an exact pixel height. Falls back to the nearest
    // system font if the watch cannot supply the vector face.
    function font(size as Number) as Graphics.FontType {
        var cached = _fonts[size];
        if (cached != null) {
            return cached;
        }
        var found = Graphics.getVectorFont({
            :face => ["RobotoCondensedBold", "RobotoRegular"] as Array<String>,
            :size => size
        }) as Graphics.FontType or Null;
        if (found == null) {
            found = (size >= 36) ? Graphics.FONT_SMALL
                : ((size >= 28) ? Graphics.FONT_TINY : Graphics.FONT_XTINY);
        }
        _fonts[size] = found;
        return found;
    }

    // The largest of the given sizes at which the text fits the width.
    function fitFont(dc as Dc, text as String, maxWidth as Number, sizes as Array<Number>) as Graphics.FontType {
        for (var i = 0; i < sizes.size(); i++) {
            var candidate = font(sizes[i]);
            if (dc.getTextWidthInPixels(text, candidate) <= maxWidth) {
                return candidate;
            }
        }
        return font(sizes[sizes.size() - 1]);
    }

    // Start of every frame: smooth lines, black screen.
    function begin(dc as Dc) as Void {
        dc.setAntiAlias(true);
        dc.setColor(BLACK, BLACK);
        dc.clear();
    }

    // Ring of ticks around the bezel, with a longer tick every 30 degrees.
    function drawTickRing(dc as Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var outer = cx - 3;
        dc.setColor(CYAN_DIM, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 60; i++) {
            var major = (i % 5 == 0);
            var angle = Math.toRadians(i * 6);
            var c = Math.cos(angle);
            var s = Math.sin(angle);
            var inner = outer - (major ? 13 : 6);
            dc.setPenWidth(major ? 3 : 2);
            dc.drawLine(cx + inner * c, cy + inner * s, cx + outer * c, cy + outer * s);
        }
        dc.setPenWidth(1);
    }

    // Circular gauge made of `count` blocks, clockwise from twelve o'clock.
    // The first `lit` blocks are bright and the rest dark.
    function drawBlockArc(dc as Dc, radius as Number, width as Number, count as Number, lit as Number) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var step = 360.0 / count;
        var sweep = step * 0.66;
        dc.setPenWidth(width);
        for (var i = 0; i < count; i++) {
            dc.setColor((i < lit) ? CYAN : CYAN_DARK, Graphics.COLOR_TRANSPARENT);
            // drawArc measures counter-clockwise from three o'clock, so
            // twelve o'clock is 90 and clockwise means a falling angle.
            var start = 90 - i * step;
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, wrap(start), wrap(start - sweep));
        }
        dc.setPenWidth(1);
    }

    // Four brackets around a circle, like a targeting reticle.
    function drawReticle(dc as Dc, x as Number, y as Number, radius as Number) as Void {
        dc.setPenWidth(4);
        dc.setColor(CYAN, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var start = 75 + i * 90;
            dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, start, start - 60);
        }
        dc.setPenWidth(1);
    }

    // Row of blocks, the first `lit` of them bright. Centred on (cx, y).
    function drawBlockBar(dc as Dc, cx as Number, y as Number, count as Number, lit as Number) as Void {
        var blockWidth = 18;
        var blockHeight = 12;
        var gap = 5;
        var x = cx - (count * blockWidth + (count - 1) * gap) / 2;
        for (var i = 0; i < count; i++) {
            dc.setColor((i < lit) ? CYAN : CYAN_DARK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + i * (blockWidth + gap), y - blockHeight / 2, blockWidth, blockHeight);
        }
    }

    // Brings an angle into the 0 to 360 range drawArc expects.
    function wrap(degrees as Float) as Float {
        while (degrees < 0) {
            degrees += 360;
        }
        while (degrees >= 360) {
            degrees -= 360;
        }
        return degrees;
    }
}

// Draws the bezel ticks over a list, so lists share the frame of the other
// screens.
class HudFrame extends WatchUi.Drawable {

    function initialize() {
        Drawable.initialize({});
    }

    function draw(dc as Dc) as Void {
        dc.setAntiAlias(true);
        Hud.drawTickRing(dc);
    }
}
