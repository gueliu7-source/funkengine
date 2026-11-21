package;

import core.ModManager;
import core.Settings;
import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.Sprite;
import states.MenuState;

class Main extends Sprite
{
	public function new()
	{
		super();
		Settings.load();
		ModManager.init();

		var fps:Int = Settings.d.fps;
		addChild(new FlxGame(1280, 720, MenuState, fps, fps, true, false));

		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		FlxG.fixedTimestep = false;
	}
}
