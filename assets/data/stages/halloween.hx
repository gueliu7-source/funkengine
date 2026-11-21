// Relâmpago do cenário de Halloween (HScript)
var lightningBeat = 0;
var lightningOffset = 8;

function onBeatHit(beat) {
    if (FlxG.random.bool(10) && beat > lightningBeat + lightningOffset) {
        playSound("sounds/thunder_" + FlxG.random.int(1, 2) + ".ogg");
        var bg = tagged.get("bg");
        if (bg != null) {
            bg.animation.addByPrefix("light", "halloweem bg lightning strike", 24, false);
            bg.animation.play("light");
        }
        lightningBeat = beat;
        lightningOffset = FlxG.random.int(8, 24);
        cameraFlash("FFFFFF", 0.3);
    }
}
