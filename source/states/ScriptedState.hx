package states;

import core.Paths;
import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import scripting.MenuScripts;
import ui.MenuUtil;

/**
 * Tela inteira feita por mod: mods/<mod>/states/<nome>.hx (abra com go("mod:<nome>") ou Nav.go).
 * O script usa as mesmas funções dos scripts de menu e deve montar tudo em onCreate.
 * Sem o arquivo, mostra um aviso e ESC volta ao menu.
 */
class ScriptedState extends FlxState
{
	var stateName:String;
	var ms:MenuScripts;

	public function new(name:String)
	{
		super();
		stateName = name;
		ms = MenuScripts.makeFor(this, "mod:" + name, ["states/" + name + ".hx"]);
	}

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = true;
		MenuUtil.ensureMenuMusic();
		if (Paths.find("states/" + stateName + ".hx") == null)
			add(MenuUtil.text(0, 320, FlxG.width, 28, FlxTextAlign.CENTER, "tela '" + stateName + "' não encontrada (states/" + stateName + ".hx)"));
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		ms.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE && !ms.call("onBack"))
			core.Nav.go("mainmenu");
	}

	override public function destroy():Void
	{
		ms.destroy();
		super.destroy();
	}
}
