package game;

import core.Conductor;
import core.Settings;
import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;

/**
 * Lê o teclado por eventos (não por polling) e carimba cada toque com a posição da música
 * no instante exato, estimada entre frames. O timing não depende do FPS.
 */
class InputManager
{
	public var held:Array<Bool> = [false, false, false, false];
	public var pressLane:Array<Int> = [];
	public var pressTime:Array<Float> = [];
	public var enabled:Bool = true;

	public function new()
	{
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onDown);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onUp);
		FlxG.signals.focusLost.add(releaseAll);
	}

	public function destroy():Void
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onDown);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onUp);
		FlxG.signals.focusLost.remove(releaseAll);
	}

	public inline function anyHeld():Bool
		return held[0] || held[1] || held[2] || held[3];

	public function clearQueue():Void
	{
		pressLane.resize(0);
		pressTime.resize(0);
	}

	public function releaseAll():Void
	{
		for (i in 0...4)
			held[i] = false;
	}

	function laneOf(key:FlxKey):Int
	{
		if (key == FlxKey.NONE)
			return -1;
		var keys = Settings.d.keys;
		for (i in 0...keys.length)
			for (k in keys[i])
				if (k == key)
					return i;
		return -1;
	}

	function onDown(e:KeyboardEvent):Void
	{
		if (!enabled)
			return;
		var lane = laneOf(e.keyCode);
		if (lane < 0 || held[lane])
			return; // ignora o auto-repeat do sistema
		held[lane] = true;
		pressLane.push(lane);
		pressTime.push(Conductor.positionNow());
	}

	function onUp(e:KeyboardEvent):Void
	{
		var lane = laneOf(e.keyCode);
		if (lane >= 0)
			held[lane] = false;
	}
}
