package;

import core.ModManager;
import core.Settings;
import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.Sprite;
import states.TitleState;

class Main extends Sprite
{
	public function new()
	{
		super();
		Settings.load();
		ModManager.init();

		var fps:Int = Settings.d.fps;
		addChild(new FlxGame(1280, 720, TitleState, fps, fps, true, false));

		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		FlxG.fixedTimestep = false;
	}
}
