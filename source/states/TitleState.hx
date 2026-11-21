package states;

import core.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import ui.MenuUtil;

/**
 * Tela de título no estilo do FNF original: intro com créditos no ritmo da música,
 * flash branco, logo pulsando, GF dançando e "Press Enter to Begin".
 * A intro só toca uma vez por execução (ao voltar do menu vai direto para o título).
 */
class TitleState extends FlxState
{
	static var introDone:Bool = false;
	static inline var BPM:Float = 102;

	var logo:FlxSprite;
	var gf:FlxSprite;
	var titleText:FlxSprite;
	var ngLogo:FlxSprite;
	var lines:Array<FlxText> = [];
	var skipped:Bool = false;
	var transitioning:Bool = false;
	var lastBeat:Int = -1;
	var danceLeft:Bool = false;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = false;

		var bg = new FlxSprite();
		bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		var f = Paths.sparrow("images/gfDanceTitle");
		gf = new FlxSprite(FlxG.width * 0.4, FlxG.height * 0.07);
		if (f != null)
		{
			gf.frames = f;
			gf.animation.addByIndices("danceLeft", "gfDance", [for (i in 0...15) i], "", 24, false);
			gf.animation.addByIndices("danceRight", "gfDance", [for (i in 15...30) i], "", 24, false);
			gf.animation.play("danceRight");
		}
		gf.antialiasing = true;
		add(gf);

		logo = new FlxSprite(-150, -100);
		f = Paths.sparrow("images/logoBumpin");
		if (f != null)
		{
			logo.frames = f;
			logo.animation.addByPrefix("bump", "logo bumpin", 24, false);
			logo.animation.play("bump");
		}
		logo.antialiasing = true;
		add(logo);

		titleText = new FlxSprite(100, FlxG.height * 0.8);
		f = Paths.sparrow("images/titleEnter");
		if (f != null)
		{
			titleText.frames = f;
			titleText.animation.addByPrefix("idle", "Press Enter to Begin", 24);
			titleText.animation.addByPrefix("press", "ENTER PRESSED", 24);
			titleText.animation.play("idle");
			titleText.updateHitbox();
			if (titleText.width > 1180)
			{
				var k = 1180 / titleText.width;
				titleText.scale.set(k, k);
				titleText.updateHitbox();
			}
			titleText.screenCenter(X);
		}
		titleText.antialiasing = true;
		add(titleText);

		ngLogo = new FlxSprite(0, FlxG.height * 0.52);
		var g = Paths.graphic("images/newgrounds_logo.png");
		if (g != null)
		{
			ngLogo.loadGraphic(g);
			ngLogo.setGraphicSize(Std.int(ngLogo.width * 0.8));
			ngLogo.updateHitbox();
			ngLogo.screenCenter(X);
		}
		ngLogo.antialiasing = true;
		ngLogo.visible = false;
		add(ngLogo);

		logo.visible = gf.visible = titleText.visible = false;

		if (FlxG.sound.music == null || !FlxG.sound.music.playing)
		{
			var m = Paths.loadSound("music/freakyMenu.ogg");
			if (m != null)
			{
				FlxG.sound.playMusic(m, 0);
				FlxG.sound.music.fadeIn(4, 0, 0.7);
			}
		}

		if (introDone)
			skipIntro(false);
	}

	function say(s:String):Void
	{
		var t = MenuUtil.text(0, 200 + lines.length * 64, FlxG.width, 52, FlxTextAlign.CENTER, s);
		lines.push(t);
		add(t);
	}

	function clearText():Void
	{
		for (t in lines)
		{
			remove(t, true);
			t.destroy();
		}
		lines = [];
	}

	function skipIntro(flash:Bool = true):Void
	{
		if (skipped)
			return;
		skipped = true;
		introDone = true;
		clearText();
		ngLogo.visible = false;
		logo.visible = gf.visible = titleText.visible = true;
		if (flash)
			FlxG.camera.flash(FlxColor.WHITE, 3);
	}

	function onBeat(beat:Int):Void
	{
		if (skipped)
		{
			logo.animation.play("bump", true);
			danceLeft = !danceLeft;
			gf.animation.play(danceLeft ? "danceRight" : "danceLeft");
			return;
		}
		switch (beat)
		{
			case 1:
				say("ninjamuffin99");
				say("phantomArcade");
				say("kawaisprite");
				say("evilsk8er");
			case 3:
				say("present");
			case 4:
				clearText();
			case 5:
				say("In association");
				say("with");
			case 7:
				say("newgrounds");
				ngLogo.visible = true;
			case 8:
				clearText();
				ngLogo.visible = false;
			case 9:
				say("Made with");
			case 10:
				say("HaxeFlixel");
			case 11:
				clearText();
			case 12:
				say("Friday");
			case 13:
				say("Night");
			case 14:
				say("Funkin'");
			case 16:
				skipIntro();
			default:
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			var beat = Std.int(FlxG.sound.music.time / (60000 / BPM));
			if (beat != lastBeat)
			{
				lastBeat = beat;
				onBeat(beat);
			}
		}

		if (FlxG.keys.justPressed.ENTER && !transitioning)
		{
			if (!skipped)
				skipIntro();
			else
			{
				transitioning = true;
				titleText.animation.play("press");
				FlxG.camera.flash(FlxColor.WHITE, 1);
				MenuUtil.sfx("confirmMenu");
				new FlxTimer().start(2, function(_) FlxG.switchState(new MainMenuState()));
			}
		}
	}
}
