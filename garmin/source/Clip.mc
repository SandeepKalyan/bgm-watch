import Toybox.Lang;

// One entry in the clip list. ClipLibrary.mc (generated) creates these.
class Clip {

    public var title as String;
    public var subtitle as String;
    public var resource as ResourceId;
    public var durationMs as Number;

    function initialize(title as String, subtitle as String, resource as ResourceId, durationMs as Number) {
        self.title = title;
        self.subtitle = subtitle;
        self.resource = resource;
        self.durationMs = durationMs;
    }

    // Second line of the list entry, for example "Dude  0:18".
    function getSubLabel() as String {
        var seconds = (durationMs + 500) / 1000;
        var length = (seconds / 60).toString() + ":" + (seconds % 60).format("%02d");
        return (subtitle.length() > 0) ? subtitle + "  " + length : length;
    }
}
