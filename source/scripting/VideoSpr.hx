package scripting;

#if FEATURE_VIDEO
import hxvlc.flixel.FlxVideoSprite;

/** Vídeo como sprite (makeVideoSprite/playVideoSprite do Psych), tocado pelo libVLC via hxvlc. */
class VideoSpr extends FlxVideoSprite
{
	public var file:String;
	public var loops:Bool;
	public var onEnd:Void->Void;

	/** Vídeos vivos (para pausar junto com o jogo). */
	public static var all:Array<VideoSpr> = [];

	var started:Bool = false;
	var loaded:Bool = false;

	public function new(x:Float, y:Float, file:String, loops:Bool)
	{
		super(x, y);
		this.file = file;
		this.loops = loops;
		antialiasing = false;
		bitmap.onEndReached.add(function() {
			if (!this.loops && onEnd != null)
				onEnd();
		});
		all.push(this);
	}

	/** Abre o arquivo já na criação (sem tocar), para o play() depois não atrasar. */
	public function preload():Void
	{
		if (loaded)
			return;
		var abs = sys.FileSystem.fullPath(file);
		loaded = load(abs, loops ? [":input-repeat=65535"] : []);
		if (!loaded)
			trace("[video] não abriu: " + abs);
	}

	/** Começa a tocar (uma vez). */
	public function start():Void
	{
		if (started)
			return;
		started = true;
		preload();
		if (loaded)
			play();
	}

	public static function pauseAll():Void
	{
		for (v in all)
			if (v.started && v.alive)
				v.pause();
	}

	public static function resumeAll():Void
	{
		for (v in all)
			if (v.started && v.alive)
				v.resume();
	}

	override public function destroy():Void
	{
		all.remove(this);
		super.destroy();
	}
}
#end
