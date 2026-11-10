import Toybox.Lang;

// One bubble on the mood map. ClipLibrary.mc (generated) creates these.
class Emotion {

    public var label as String;
    // Position as a percentage of the screen radius from the centre:
    // x to the right, y downwards.
    public var x as Number;
    public var y as Number;

    function initialize(label as String, x as Number, y as Number) {
        self.label = label;
        self.x = x;
        self.y = y;
    }
}
