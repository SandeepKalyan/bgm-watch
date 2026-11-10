import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The list of clips under one emotion, drawn in the HUD style. CustomMenu
// supplies the scrolling and focus; the classes below only draw the rows, the
// title and the frame. ClipMenuDelegate handles the selection.
module ClipList {

    const ROW_HEIGHT = 92;
    const FOCUS_ROW_HEIGHT = 128;
    const TITLE_HEIGHT = 124;

    // Each row's id is the clip's index in `clips`.
    function build(title as String, clips as Array<Clip>) as WatchUi.CustomMenu {
        var menu = new WatchUi.CustomMenu(ROW_HEIGHT, Graphics.COLOR_BLACK, {
            :focusItemHeight => FOCUS_ROW_HEIGHT,
            :titleItemHeight => TITLE_HEIGHT,
            :title => new ClipListTitle(title, clips.size()),
            :foreground => new HudFrame()
        });
        for (var i = 0; i < clips.size(); i++) {
            menu.addItem(new ClipRow(i, clips[i]));
        }
        return menu;
    }
}

// One row: clip name over film name and length. The row in focus is larger,
// brighter and bracketed.
class ClipRow extends WatchUi.CustomMenuItem {

    private var _clip as Clip;

    function initialize(index as Number, clip as Clip) {
        CustomMenuItem.initialize(index, {});
        _clip = clip;
    }

    function draw(dc as Dc) as Void {
        var h = dc.getHeight();
        var focused = isFocused();

        // Lay the row out around the screen's centre line, not the row's own:
        // the band runs from the system's focus marker on the left to the
        // mirror-image point on the right.
        var cx = Hud.centerX(dc);
        var bandWidth = 2 * cx;

        dc.setAntiAlias(true);
        dc.setColor(Hud.BLACK, Hud.BLACK);
        dc.clear();

        if (focused) {
            dc.setColor(Hud.CYAN_DARK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, 6, bandWidth, h - 12);
            dc.setColor(Hud.CYAN, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bandWidth - 6, 6, 6, h - 12);
        }

        var titleFont = focused
            ? Hud.fitFont(dc, _clip.title, bandWidth * 86 / 100, [38, 33, 28])
            : Hud.font(28);
        dc.setColor(focused ? Hud.WHITE : Hud.GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 35 / 100, titleFont, _clip.title, Hud.CENTER);
        dc.setColor(focused ? Hud.CYAN : Hud.CYAN_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 72 / 100, Hud.font(focused ? 26 : 22), _clip.getSubLabel(), Hud.CENTER);
    }
}

// The list heading: the emotion's name and how many clips it holds.
class ClipListTitle extends WatchUi.Drawable {

    private var _title as String;
    private var _count as Number;

    function initialize(title as String, count as Number) {
        Drawable.initialize({});
        _title = title;
        _count = count;
    }

    function draw(dc as Dc) as Void {
        var cx = Hud.centerX(dc);
        var h = dc.getHeight();

        dc.setAntiAlias(true);
        dc.setColor(Hud.BLACK, Hud.BLACK);
        dc.clear();
        dc.setColor(Hud.CYAN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 50 / 100, Hud.font(42), _title, Hud.CENTER);
        dc.setColor(Hud.RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 82 / 100, Hud.font(22),
            _count.toString() + ((_count == 1) ? " CLIP" : " CLIPS"), Hud.CENTER);
    }
}
