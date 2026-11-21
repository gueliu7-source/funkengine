package states;

import core.Paths;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import ui.MenuUtil;

/**
 * Menu principal no estilo do FNF original: fundo amarelo com parallax, botões do atlas
 * FNF_main_menu_assets, câmera que segue o item selecionado e piscada magenta ao confirmar.
 */
class MainMenuState extends FlxState
{
	static var lastSel:Int = 0;
	static final NAMES:Array<String> = ["story mode", "freeplay", "options"];

	var items:FlxTypedGroup<FlxSprite>;
	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var cur:Int = 0;
	var selected:Bool = false;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = false;
		MenuUtil.ensureMenuMusic();

		var bg = MenuUtil.bg("images/menuBG.png", 0xFFFDE871);
		bg.scrollFactor.set(0, 0.18);
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = MenuUtil.bg("images/menuBGMagenta.png", 0xFFFD719B);
		magenta.scrollFactor.set(0, 0.18);
		magenta.setGraphicSize(Std.int(magenta.width * 1.1));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		add(magenta);

		items = new FlxTypedGroup<FlxSprite>();
		add(items);

		var frames = Paths.sparrow("images/FNF_main_menu_assets");
		for (i in 0...NAMES.length)
		{
			var it = new FlxSprite(0, 90 + i * 180);
			if (frames != null)
			{
				it.frames = frames;
				it.animation.addByPrefix("idle", NAMES[i] + " basic", 24);
				it.animation.addByPrefix("selected", NAMES[i] + " white", 24);
				it.animation.play("idle");
			}
			else
				it.makeGraphic(400, 100, 0xFFFFFFFF);
			it.ID = i;
			it.scrollFactor.set();
			it.antialiasing = true;
			it.updateHitbox();
			it.screenCenter(X);
			items.add(it);
		}

		FlxG.camera.follow(camFollow, LOCKON, 0.06);

		var ver = MenuUtil.text(12, FlxG.height - 28, 0, 16, FlxTextAlign.LEFT, "FunkForge v0.1.0");
		ver.scrollFactor.set();
		add(ver);

		cur = lastSel;
		change(0, true);
	}

	function change(dir:Int, silent:Bool = false):Void
	{
		cur = (cur + dir + NAMES.length) % NAMES.length;
		lastSel = cur;
		if (!silent)
			MenuUtil.sfx("scrollMenu");

		items.forEach(function(spr:FlxSprite)
		{
			if (spr.animation.getByName("idle") != null)
				spr.animation.play("idle");
			spr.updateHitbox();
			spr.screenCenter(X);

			if (spr.ID == cur)
			{
				if (spr.animation.getByName("selected") != null)
					spr.animation.play("selected");
				var mp = spr.getGraphicMidpoint();
				camFollow.setPosition(mp.x, mp.y);
				mp.put();
				spr.updateHitbox();
				spr.screenCenter(X);
			}
		});
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (selected)
			return;

		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
			change(-1);
		if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
			change(1);

		if (FlxG.keys.justPressed.ESCAPE)
		{
			MenuUtil.sfx("cancelMenu");
			FlxG.switchState(new TitleState());
			return;
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			selected = true;
			MenuUtil.sfx("confirmMenu");
			FlxFlicker.flicker(magenta, 1.1, 0.15, false);

			items.forEach(function(spr:FlxSprite)
			{
				if (spr.ID != cur)
					FlxTween.tween(spr, {alpha: 0}, 0.4, {
						ease: FlxEase.quadOut,
						onComplete: function(_) spr.kill()
					});
				else
					FlxFlicker.flicker(spr, 1, 0.06, false, false, function(_) openSelected());
			});
		}
	}

	function openSelected():Void
	{
		switch (cur)
		{
			case 0:
				FlxG.switchState(new StoryMenuState());
			case 1:
				FlxG.switchState(new FreeplayState());
			default:
				FlxG.switchState(new OptionsState());
		}
	}
}
