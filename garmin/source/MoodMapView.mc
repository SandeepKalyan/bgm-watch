import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Home screen: every emotion as a bubble on a map, with ALL in the centre.
// A bubble grows with the number of clips filed under it. One bubble is in
// focus (drawn solid, inside a reticle). Bubbles without clips are dimmed and
// cannot be opened.
class MoodMapView extends WatchUi.View {

    // Bubble radius, as a percentage of the screen radius.
    private const MIN_BUBBLE = 20;
    private const MAX_BUBBLE = 26;
    private const ALL_BUBBLE = 19;
    // Number of clips at which a bubble reaches its largest size.
    private const FULL_SIZE_AT = 4;
    // Extra pixels around a bubble that still count as touching it.
    private const TAP_SLACK = 10;

    private var _emotions as Array<Emotion>;
    private var _counts as Array<Number>;
    private var _total as Number;
    // Index into _emotions. _emotions.size() stands for the ALL bubble.
    private var _focus as Number;
    // The order the focus travels in: the emotions clockwise from twelve
    // o'clock, then ALL.
    private var _order as Array<Number>;

    // Centre and radius of each bubble in pixels, ALL last. Empty until the
    // screen size is known.
    private var _x as Array<Number> = [] as Array<Number>;
    private var _y as Array<Number> = [] as Array<Number>;
    private var _r as Array<Number> = [] as Array<Number>;

    function initialize(emotions as Array<Emotion>, clips as Array<Clip>) {
        View.initialize();
        _emotions = emotions;
        _total = clips.size();
        _focus = emotions.size();

        _counts = [] as Array<Number>;
        for (var i = 0; i < emotions.size(); i++) {
            _counts.add(0);
        }
        for (var i = 0; i < clips.size(); i++) {
            var emotion = clips[i].emotion;
            if (emotion >= 0 && emotion < _counts.size()) {
                _counts[emotion] += 1;
            }
        }

        _order = [] as Array<Number>;
        for (var i = 0; i < emotions.size(); i++) {
            _order.add(i);
        }
        for (var a = 0; a < _order.size(); a++) {
            for (var b = a + 1; b < _order.size(); b++) {
                if (clockAngle(emotions[_order[b]]) < clockAngle(emotions[_order[a]])) {
                    var swap = _order[a];
                    _order[a] = _order[b];
                    _order[b] = swap;
                }
            }
        }
        _order.add(emotions.size());
    }

    // A bubble's direction from the centre, in radians clockwise from twelve
    // o'clock (0 up to 2 pi).
    private function clockAngle(emotion as Emotion) as Float {
        var angle = Math.atan2(emotion.x, -emotion.y).toFloat();
        return (angle < 0) ? angle + 2 * Math.PI.toFloat() : angle;
    }

    function onLayout(dc as Dc) as Void {
        var radius = dc.getWidth() / 2;
        var cx = radius;
        var cy = dc.getHeight() / 2;

        _x = [] as Array<Number>;
        _y = [] as Array<Number>;
        _r = [] as Array<Number>;
        for (var i = 0; i < _emotions.size(); i++) {
            var emotion = _emotions[i];
            var filled = (_counts[i] > FULL_SIZE_AT) ? FULL_SIZE_AT : _counts[i];
            var percent = MIN_BUBBLE + (MAX_BUBBLE - MIN_BUBBLE) * filled / FULL_SIZE_AT;
            _x.add(cx + emotion.x * radius / 100);
            _y.add(cy + emotion.y * radius / 100);
            _r.add(percent * radius / 100);
        }
        _x.add(cx);
        _y.add(cy);
        _r.add(ALL_BUBBLE * radius / 100);
    }

    function onUpdate(dc as Dc) as Void {
        Hud.begin(dc);
        Hud.drawTickRing(dc);
        if (_x.size() == 0) {
            return;
        }

        var count = _emotions.size();
        var cx = _x[count];
        var cy = _y[count];

        var caption = Hud.font(22);
        if (caption instanceof Graphics.VectorFont) {
            dc.setColor(Hud.RED, Graphics.COLOR_TRANSPARENT);
            dc.drawRadialText(cx, cy, caption, "SELECT MOOD", Graphics.TEXT_JUSTIFY_CENTER,
                90, cx - 36, Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
        }

        // Links: the centre to every bubble, and a loop through the bubbles.
        dc.setPenWidth(2);
        dc.setColor(Hud.CYAN_DIM, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < count; i++) {
            var next = (i + 1) % count;
            dc.drawLine(cx, cy, _x[i], _y[i]);
            dc.drawLine(_x[i], _y[i], _x[next], _y[next]);
        }
        dc.setPenWidth(1);

        for (var i = 0; i <= count; i++) {
            var label = (i < count) ? _emotions[i].label : "ALL";
            var clips = (i < count) ? _counts[i] : _total;
            drawBubble(dc, _x[i], _y[i], _r[i], label, clips, i == _focus);
        }
    }

    private function drawBubble(dc as Dc, x as Number, y as Number, r as Number,
            label as String, clips as Number, focused as Boolean) as Void {
        var empty = (clips == 0);
        if (focused) {
            dc.setColor(Hud.CYAN, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r);
            Hud.drawReticle(dc, x, y, r + 8);
        } else {
            // The black disc hides the links that run behind the bubble.
            dc.setColor(Hud.BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, r);
            dc.setPenWidth(3);
            dc.setColor(empty ? Hud.CYAN_DARK : Hud.CYAN, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, r);
            dc.setPenWidth(1);
        }

        var labelColor = focused ? Hud.BLACK : (empty ? Hud.CYAN_DIM : Hud.WHITE);
        var countColor = focused ? Hud.BLACK : (empty ? Hud.CYAN_DIM : Hud.CYAN);
        dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y - r * 18 / 100, Hud.fitFont(dc, label, r * 172 / 100, [30, 26, 22]), label, Hud.CENTER);
        dc.setColor(countColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + r * 44 / 100, Hud.font(22), clips.toString(), Hud.CENTER);
    }

    function getFocus() as Number {
        return _focus;
    }

    function setFocus(node as Number) as Void {
        _focus = node;
        WatchUi.requestUpdate();
    }

    // Moves the focus clockwise (+1) or counter-clockwise (-1) to the next
    // bubble that has clips. ALL sits between the last and first emotion.
    function moveFocus(step as Number) as Void {
        var nodes = _order.size();
        var at = _order.indexOf(_focus);
        for (var tries = 0; tries < nodes; tries++) {
            at = (at + step + nodes) % nodes;
            if (hasClips(_order[at])) {
                _focus = _order[at];
                break;
            }
        }
        WatchUi.requestUpdate();
    }

    // The bubble under a screen point, or -1. Bubbles without clips do not
    // count.
    function hitTest(x as Number, y as Number) as Number {
        var best = -1;
        var bestDistance = 0;
        for (var i = 0; i < _x.size(); i++) {
            var dx = x - _x[i];
            var dy = y - _y[i];
            var reach = _r[i] + TAP_SLACK;
            var distance = dx * dx + dy * dy;
            if (distance <= reach * reach && hasClips(i) && (best < 0 || distance < bestDistance)) {
                best = i;
                bestDistance = distance;
            }
        }
        return best;
    }

    private function hasClips(node as Number) as Boolean {
        return (node < _counts.size()) ? _counts[node] > 0 : _total > 0;
    }
}
