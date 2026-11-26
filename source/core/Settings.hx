package core;

import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSave;

typedef SettingsData =
{
	var fps:Int;
	var debugOverlay:Int; // F3: 0 = oculto, 1 = FPS e memória, 2 = completo
	var downscroll:Bool;
	var middlescroll:Bool;
	var ghostTapping:Bool;
	var scrollMode:Int; // 0 = velocidade do chart, 1 = fixa (scrollSpeed, ignora chart e eventos), 2 = chart × scrollMult
	var scrollSpeed:Float; // velocidade do modo fixo
	var scrollMult:Float; // multiplicador do modo 2
	var offsetMs:Float;
	var botplay:Bool;
	var antialiasing:Bool;
	var hudJudgementCounter:Bool;
	var hudMsDisplay:Bool;
	var hudSongBar:Bool;
	var noteSplashes:Bool; // brilho ao acertar Sick
	var camBeatZoom:Bool;
	var sickMs:Float;
	var goodMs:Float;
	var badMs:Float;
	var shitMs:Float;
	var accuracyMode:String; // "simple" (sick 100%, good 75%...) ou "wife3" (Kade, mais rígido)
	var hudStyle:String; // funkforge, kade, psych, codename, leather, forever
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
			debugOverlay: 1,
			downscroll: false,
			middlescroll: false,
			ghostTapping: true,
			scrollMode: 0,
			scrollSpeed: 2,
			scrollMult: 1,
			offsetMs: 0,
			botplay: false,
			antialiasing: true,
			hudJudgementCounter: true,
			hudMsDisplay: true,
			hudSongBar: true,
			noteSplashes: true,
			camBeatZoom: true,
			sickMs: 45,
			goodMs: 90,
			badMs: 135,
			shitMs: 166,
			accuracyMode: "simple",
			hudStyle: "funk",
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
		d.scrollMode = 0; // a velocidade das notas é sempre a do chart
		if (d.hudStyle == "clean" || d.hudStyle == "funkforge")
			d.hudStyle = "funk"; // o HUD antigo foi substituído
		// save antigo: scrollSpeed > 0 significava velocidade fixa
		if (!Reflect.hasField(saved, "scrollMode"))
		{
			var old:Float = Reflect.hasField(saved, "scrollSpeed") ? Reflect.field(saved, "scrollSpeed") : 0;
			d.scrollMode = old > 0 ? 1 : 0;
			if (old <= 0)
				d.scrollSpeed = 2;
		}
	}

	public static function flush():Void
	{
		if (save == null)
			return;
		save.data.d = d;
		save.flush();
	}
}
