package core;

import flixel.FlxG;
import states.*;

/** Troca de tela por nome (usado pelos menus e pelos scripts dos mods). */
class Nav
{
	/** title, mainmenu, story, freeplay, options, mods, controls, editors ou mod:<nome> (mods/<mod>/states/<nome>.hx). */
	public static function go(target:String):Void
	{
		var t = target.toLowerCase();
		if (StringTools.startsWith(t, "mod:"))
		{
			FlxG.switchState(new ScriptedState(target.substr(4)));
			return;
		}
		FlxG.switchState(switch (t)
		{
			case "title": new TitleState();
			case "story" | "storymenu": new StoryMenuState();
			case "freeplay": new FreeplayState();
			case "options": new OptionsState();
			case "mods": new ModsState();
			case "controls": new ControlsState();
			case "editors": new EditorsState();
			default: new MainMenuState();
		});
	}
}
