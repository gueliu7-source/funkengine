// Made By Axel
// Only use this on Psych Engine 1.0.4 or a Custom Psych build with HXVLC or it wont work
import hxvlc.flixel.FlxVideoSprite;
import psychlua.LuaUtils;
import states.PlayState;

var videoSprites:Array<FlxVideoSprite> = [];

function getPlayState() {
    return PlayState.instance;
}

createGlobalCallback('makeVideoSprite', function(tag:String, videoName:String, ?x:Float, ?y:Float, ?camera:String, ?loop:Bool = false) {
    if (game.variables.exists(tag)) {
        debugPrint('Video sprite with tag "'+tag+'" already exists!', 0xFFFF0000);
        return;
    }

    x ??= 0;
    y ??= 0;
    camera ??= 'camHUD';

    var video = new FlxVideoSprite(x, y);
    video.antialiasing = ClientPrefs.data.antialiasing;
    video.camera = LuaUtils.cameraFromString(camera);

    var options:Array<String> = null;
    if (loop) options = ['input-repeat=65535'];

    video.load(Paths.video(videoName), options);

    if (!loop) {
        video.bitmap.onEndReached.add(() -> {
            remove(video);
            removeVar(tag);
            videoSprites.remove(video);
        });
    }

    videoSprites.push(video);
    game.variables.set(tag, video);
});

createGlobalCallback('playVideoSprite', function(tag:String) {
    if (!game.variables.exists(tag)) {
        debugPrint('Video sprite with tag "'+tag+'" doesn\'t exist!', 0xFFFF0000);
        return;
    }

    var video = game.variables.get(tag);
    video.play();
    add(video);
});

createGlobalCallback('seekVideoSprite', function(tag:String, timeMs:Int) {
    if (!game.variables.exists(tag)) {
        debugPrint('Video sprite with tag "'+tag+'" doesn\'t exist!', 0xFFFF0000);
        return;
    }

    var video = game.variables.get(tag);
    // HXVLC maneja el tiempo en milisegundos
    video.bitmap.time = timeMs;
});

createGlobalCallback('scaleVideoSprite', function(tag:String, scaleX:Float, scaleY:Float) {
    if (!game.variables.exists(tag)) {
        debugPrint('Video sprite with tag "'+tag+'" doesn\'t exist!', 0xFFFF0000);
        return;
    }

    var video = game.variables.get(tag);
    video.scale.set(scaleX, scaleY);
    video.updateHitbox();
});

function onPause() {
    for (video in videoSprites) video.pause();
}

function onResume() {
    var ps = getPlayState();
    if (ps != null && !ps.paused) {
        for (video in videoSprites) video.resume();
    }
}

function onCustomSubstateCreate(name:String) {
    if (name == 'iridaPauseMenu') {
        for (video in videoSprites) video.pause();
    }
}

function onCustomSubstateDestroy(name:String) {
    var ps = getPlayState();
    if (name == 'iridaPauseMenu' && ps != null && !ps.paused) {
        for (video in videoSprites) video.resume();
    }
}