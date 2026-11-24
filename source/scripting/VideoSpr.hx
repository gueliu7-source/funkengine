package scripting;

#if FEATURE_VIDEO
import hxvlc.flixel.FlxVideoSprite;

/** Vídeo como sprite (makeVideoSprite/playVideoSprite do Psych), tocado pelo libVLC via hxvlc. */
class VideoSpr extends FlxVideoSprite
{
	public var file:String;
	public var loops:Bool;
	public var onEnd:Void->Void;

	var started:Bool = false;
	var lastW:Int = 0;

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
	}

	/** Começa a tocar (uma vez). */
	public function start():Void
	{
		if (started)
			return;
		started = true;
		var abs = sys.FileSystem.fullPath(file);
		if (load(abs, loops ? [":input-repeat=65535"] : []))
			play();
		else
			trace("[video] não abriu: " + abs);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		// o tamanho do quadro só é conhecido depois que o vídeo abre: refaz a hitbox (scaleObject já foi aplicado)
		if (frameWidth != lastW && frameWidth > 0)
		{
			lastW = frameWidth;
			updateHitbox();
		}
	}
}
#end
