package states;

import core.Paths;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import game.Character;

/** Tela de game over: toca a animação de morte do bf; ENTER reinicia, ESC volta ao menu. */
class GameOverSubState extends FlxSubState
{
	var bf:Character;
	var cam:FlxCamera;
	var confirmed:Bool = false;
	var looping:Bool = false;

	public function new(x:Float, y:Float, hudCam:FlxCamera)
	{
		super(0xFF000000);
		cam = hudCam;
		var id = PlayState.instance.boyfriend.id;
		if (Paths.exists('data/characters/$id-dead.json'))
			id = id + "-dead";
		bf = new Character(x, y, id, true);
		add(bf);
	}

	override public function create():Void
	{
		super.create();
		var s = Paths.sound("sounds/fnf_loss_sfx.ogg");
		if (s != null)
			FlxG.sound.play(s);
		bf.playAnim("firstDeath", true);

		var t = new FlxText(0, FlxG.height - 90, FlxG.width, "ENTER: tentar de novo     ESC: menu", 24);
		t.setFormat(Paths.FONT, 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.scrollFactor.set();
		t.cameras = [cam];
		add(t);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var a = bf.animation.curAnim;
		if (!looping && !confirmed && a != null && a.name == "firstDeath" && a.finished)
		{
			looping = true;
			bf.playAnim("deathLoop", true);
			var m = Paths.loadSound("music/gameOver.ogg");
			if (m != null)
				FlxG.sound.playMusic(m);
		}

		if (!confirmed && FlxG.keys.justPressed.ENTER)
		{
			confirmed = true;
			bf.playAnim("deathConfirm", true);
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();
			var m = Paths.sound("music/gameOverEnd.ogg");
			if (m != null)
				FlxG.sound.play(m);
			new FlxTimer().start(0.7, function(_) {
				FlxG.camera.fade(FlxColor.BLACK, 1.5, false, function() {
					FlxG.resetState();
				});
			});
		}
		else if (FlxG.keys.justPressed.ESCAPE)
		{
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();
			FlxG.switchState(new MenuState());
		}
	}
}
