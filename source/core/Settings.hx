package core;

import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSave;

typedef SettingsData =
{
	var fps:Int;
	var downscroll:Bool;
	var middlescroll:Bool;
	var ghostTapping:Bool;
	var scrollSpeed:Float; // 0 = usa a velocidade do chart
	var offsetMs:Float;
	var botplay:Bool;
	var antialiasing:Bool;
	var hudJudgementCounter:Bool;
	var hudMsDisplay:Bool;
	var hudSongBar:Bool;
	var camBeatZoom:Bool;
	var sickMs:Float;
	var goodMs:Float;
	var badMs:Float;
	var shitMs:Float;
	var enabledMods:Array<String>; // mods ativos (pastas em mods/), do de maior prioridade ao de menor
	var keys:Array<Array<FlxKey>>; // 4 lanes: esquerda, baixo, cima, direita
}

/** Configurações persistentes. Acesse com Settings.d.campo */
@:keep
class Settings
{
	public static var d:SettingsData = defaults();

	static var save:FlxSave;

	static function defaults():SettingsData
	{
		return {
			fps: 120,
			downscroll: false,
			middlescroll: false,
			ghostTapping: true,
			scrollSpeed: 0,
			offsetMs: 0,
			botplay: false,
			antialiasing: true,
			hudJudgementCounter: true,
			hudMsDisplay: true,
			hudSongBar: true,
			camBeatZoom: true,
			sickMs: 45,
			goodMs: 90,
			badMs: 135,
			shitMs: 166,
			enabledMods: [],
			keys: [[FlxKey.A, FlxKey.LEFT], [FlxKey.S, FlxKey.DOWN], [FlxKey.W, FlxKey.UP], [FlxKey.D, FlxKey.RIGHT]]
		};
	}

	public static function load():Void
	{
		save = new FlxSave();
		save.bind("settings", "FunkForge");
		var saved:Dynamic = save.data.d;
		if (saved == null)
			return;
		// copia só os campos que existem (versões antigas do save não quebram)
		for (f in Reflect.fields(saved))
			if (Reflect.hasField(d, f))
				Reflect.setField(d, f, Reflect.field(saved, f));
	}

	public static function flush():Void
	{
		if (save == null)
			return;
		save.data.d = d;
		save.flush();
	}
}
