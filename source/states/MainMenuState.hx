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
@:keep
class MainMenuState extends FlxState
{
	var menuScripts:scripting.MenuScripts;

	static var lastSel:Int = 0;
	/** Itens padrão; um mod troca a lista em data/menus/mainmenu.json (ver mods/README.txt). */
	static final DEFAULT_ITEMS:String = '{"items":[{"id":"story","anim":"story mode","state":"story"},{"id":"freeplay","anim":"freeplay","state":"freeplay"},{"id":"options","anim":"options","state":"options"}]}';

	var defs:Array<Dynamic> = [];

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

		defs = loadDefs();
		var n = defs.length;
		var step:Float = n <= 3 ? 180 : 560 / n;
		var y0:Float = n <= 3 ? 90 : 50;
		var frames = Paths.sparrow("images/FNF_main_menu_assets");
		for (i in 0...n)
		{
			var d = defs[i];
			var it:FlxSprite;
			var anim:String = d.anim != null ? d.anim : "";
			var useAtlas = frames != null && anim != "" && d.image == null;
			if (d.image != null && Paths.graphic(d.image) != null)
			{
				it = new FlxSprite(0, y0 + i * step);
				it.loadGraphic(Paths.graphic(d.image));
			}
			else if (useAtlas)
			{
				it = new FlxSprite(0, y0 + i * step);
				it.frames = frames;
				it.animation.addByPrefix("idle", anim + " basic", 24);
				it.animation.addByPrefix("selected", anim + " white", 24);
				it.animation.play("idle");
			}
			else
			{
				var label:String = d.label != null ? d.label : (d.id != null ? d.id : "?");
				var tx = MenuUtil.text(0, y0 + i * step, FlxG.width, 64, FlxTextAlign.CENTER, label.toUpperCase());
				it = tx;
			}
			it.ID = i;
			it.scrollFactor.set();
			it.antialiasing = true;
			it.updateHitbox();
			it.screenCenter(X);
			items.add(it);
		}

		FlxG.camera.follow(camFollow, LOCKON, 0.06);

		var ver = MenuUtil.text(12, FlxG.height - 28, 0, 16, FlxTextAlign.LEFT, "FunkForge v0.1.0   |   7: Editores");
		ver.scrollFactor.set();
		add(ver);

		cur = lastSel;
		change(0, true);
	}

	function loadDefs():Array<Dynamic>
	{
		var txt = Paths.getText("data/menus/mainmenu.json");
		try
		{
			var j:Dynamic = haxe.Json.parse(txt != null ? txt : DEFAULT_ITEMS);
			var arr:Array<Dynamic> = j.items;
			if (arr != null && arr.length > 0)
				return arr;
		}
		catch (e:Dynamic)
			trace("[menu] mainmenu.json inválido: " + e);
		return haxe.Json.parse(DEFAULT_ITEMS).items;
	}

	function change(dir:Int, silent:Bool = false):Void
	{
		cur = (cur + dir + defs.length) % defs.length;
		lastSel = cur;
		if (!silent)
			MenuUtil.sfx("scrollMenu");

		items.forEach(function(spr:FlxSprite)
		{
			if (spr.animation.getByName("idle") != null)
				spr.animation.play("idle");
			if (Std.isOfType(spr, FlxText))
				cast(spr, FlxText).color = 0xFFFFFFFF;
			spr.updateHitbox();
			spr.screenCenter(X);

			if (spr.ID == cur)
			{
				if (spr.animation.getByName("selected") != null)
					spr.animation.play("selected");
				if (Std.isOfType(spr, FlxText))
					cast(spr, FlxText).color = 0xFFFFE066;
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
		if (menuScripts == null)
			menuScripts = scripting.MenuScripts.make(this, "mainmenu");
		menuScripts.update(elapsed);
		if (selected)
			return;

		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
			change(-1);
		if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
			change(1);

		if (FlxG.keys.justPressed.F5) // atalho para os mods (também em Opções > Mods)
		{
			MenuUtil.sfx("confirmMenu");
			FlxG.switchState(new ModsState());
			return;
		}

		if (FlxG.keys.justPressed.SEVEN)
		{
			MenuUtil.sfx("confirmMenu");
			FlxG.switchState(new EditorsState());
			return;
		}

		if (FlxG.keys.justPressed.ESCAPE)
		{
			MenuUtil.sfx("cancelMenu");
			FlxG.switchState(new TitleState());
			return;
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			if (menuScripts.call("onSelect", [defs[cur].id])) // o script tratou o item
				return;
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
		var d = defs[cur];
		core.Nav.go(d.state != null ? d.state : "mainmenu");
	}

	override public function destroy():Void
	{
		if (menuScripts != null)
			menuScripts.destroy();
		super.destroy();
	}
}
