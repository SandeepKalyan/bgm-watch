import Toybox.Lang;

// One clip. ClipLibrary.mc (generated) creates these.
class Clip {

    public var title as String;
    public var subtitle as String;
    public var resource as ResourceId;
    public var durationMs as Number;
    // Index into ClipLibrary.getEmotions(), or -1 when the clip has none.
    public var emotion as Number;

    function initialize(title as String, subtitle as String, resource as ResourceId,
            durationMs as Number, emotion as Number) {
        self.title = title;
        self.subtitle = subtitle;
        self.resource = resource;
        self.durationMs = durationMs;
        self.emotion = emotion;
    }

    // Second line of a list entry, for example "DUDE  0:18".
    function getSubLabel() as String {
        var seconds = (durationMs + 500) / 1000;
        var length = (seconds / 60).toString() + ":" + (seconds % 60).format("%02d");
        return (subtitle.length() > 0) ? subtitle.toUpper() + "  " + length : length;
    }
}
