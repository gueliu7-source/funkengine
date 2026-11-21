package states;

import core.Paths;
import core.Settings;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.Json;

typedef SongEntry =
{
	var id:String;
	var name:String;
	var week:Int;
}

/** Lista de músicas (data/songs.json) + atalhos para as opções principais. */
class MenuState extends FlxState
{
	static inline var VISIBLE:Int = 11;
	static var lastSong:Int = 0;
	static var lastDiff:Int = 1;

	static final DIFF_SUFFIX:Array<String> = ["-easy", "", "-hard"];
	static final DIFF_NAME:Array<String> = ["EASY", "NORMAL", "HARD"];

	var songs:Array<SongEntry> = [];
	var items:Array<FlxText> = [];
	var cur:Int = 0;
	var diff:Int = 1;
	var diffText:FlxText;
	var optionsText:FlxText;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = false;

		var bg = new FlxSprite();
		bg.makeGraphic(FlxG.width, FlxG.height, 0xFF14141F);
		add(bg);

		var title = label(0, 28, FlxG.width, 44, FlxTextAlign.CENTER);
		title.text = "FUNKFORGE";
		add(title);

		var text = Paths.getText("data/songs.json");
		if (text != null)
		{
			var arr:Array<SongEntry> = Json.parse(text).songs;
			for (s in arr)
				if (Paths.exists('data/songs/${s.id}/${s.id}.json'))
					songs.push(s);
		}

		for (i in 0...VISIBLE)
		{
			var t = label(0, 0, FlxG.width, 32, FlxTextAlign.CENTER);
			items.push(t);
			add(t);
		}

		diffText = label(0, 100, FlxG.width, 22, FlxTextAlign.CENTER);
		add(diffText);

		optionsText = label(20, FlxG.height - 70, FlxG.width - 40, 16, FlxTextAlign.LEFT);
		add(optionsText);

		cur = Std.int(Math.min(lastSong, Math.max(0, songs.length - 1)));
		diff = lastDiff;
		fixDiff(0);
		refresh();

		if ((FlxG.sound.music == null || !FlxG.sound.music.playing) && Paths.exists("music/freakyMenu.ogg"))
		{
			var m = Paths.loadSound("music/freakyMenu.ogg");
			if (m != null)
				FlxG.sound.playMusic(m, 0.7);
		}
	}

	function label(x:Float, y:Float, w:Float, size:Int, align:FlxTextAlign):FlxText
	{
		var t = new FlxText(x, y, w, "", size);
		t.setFormat(Paths.FONT, size, FlxColor.WHITE, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.borderSize = 2;
		return t;
	}

	function hasDiff(i:Int):Bool
	{
		if (songs.length == 0)
			return false;
		var id = songs[cur].id;
		return Paths.exists('data/songs/$id/$id${DIFF_SUFFIX[i]}.json');
	}

	/** Anda pelas dificuldades que existem (dir = -1, 0 ou 1). */
	function fixDiff(dir:Int):Void
	{
		for (_ in 0...3)
		{
			diff = (diff + dir + 3) % 3;
			if (hasDiff(diff))
				return;
			if (dir == 0)
				dir = 1;
		}
	}

	function refresh():Void
	{
		for (i in 0...VISIBLE)
		{
			var idx = cur + i - Std.int(VISIBLE / 2);
			var t = items[i];
			t.y = 150 + i * 42;
			if (idx < 0 || idx >= songs.length)
			{
				t.text = "";
				continue;
			}
			t.text = songs[idx].name;
			var d = Math.abs(i - Std.int(VISIBLE / 2));
			t.alpha = d == 0 ? 1 : Math.max(0.25, 0.75 - d * 0.12);
			t.color = d == 0 ? 0xFFFFE066 : FlxColor.WHITE;
		}
		diffText.text = songs.length == 0 ? "Nenhuma música encontrada (rode tools/import_assets.py)" : "< " + DIFF_NAME[diff] + " >";

		var d = Settings.d;
		optionsText.text = "F1 Downscroll: " + onOff(d.downscroll) + "   F2 Middlescroll: " + onOff(d.middlescroll) + "   F3 Botplay: " + onOff(d.botplay)
			+ "   F4 Ghost tapping: " + onOff(d.ghostTapping) + "\n[ ] Velocidade: " + (d.scrollSpeed <= 0 ? "do chart" : Std.string(d.scrollSpeed))
			+ "   ; ' Offset: " + d.offsetMs + "ms   F5 Mod: " + (d.mod == "" ? "nenhum" : d.mod) + "   ENTER jogar";
	}

	inline function onOff(b:Bool):String
		return b ? "ON" : "OFF";

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var d = Settings.d;
		var changed = false;

		if (songs.length > 0)
		{
			if (FlxG.keys.justPressed.UP)
			{
				cur = (cur - 1 + songs.length) % songs.length;
				fixDiff(0);
				changed = true;
			}
			if (FlxG.keys.justPressed.DOWN)
			{
				cur = (cur + 1) % songs.length;
				fixDiff(0);
				changed = true;
			}
			if (FlxG.keys.justPressed.LEFT)
			{
				fixDiff(-1);
				changed = true;
			}
			if (FlxG.keys.justPressed.RIGHT)
			{
				fixDiff(1);
				changed = true;
			}
			if (FlxG.keys.justPressed.ENTER)
				play();
		}

		if (FlxG.keys.justPressed.F1)
		{
			d.downscroll = !d.downscroll;
			changed = true;
		}
		if (FlxG.keys.justPressed.F2)
		{
			d.middlescroll = !d.middlescroll;
			changed = true;
		}
		if (FlxG.keys.justPressed.F3)
		{
			d.botplay = !d.botplay;
			changed = true;
		}
		if (FlxG.keys.justPressed.F4)
		{
			d.ghostTapping = !d.ghostTapping;
			changed = true;
		}
		if (FlxG.keys.justPressed.F5)
		{
			var mods = [""].concat(Paths.listMods());
			var i = mods.indexOf(d.mod);
			d.mod = mods[(i + 1) % mods.length];
			Paths.mod = d.mod;
			Settings.flush();
			FlxG.resetState();
			return;
		}
		if (FlxG.keys.justPressed.LBRACKET)
		{
			d.scrollSpeed = Math.max(0, Math.round((d.scrollSpeed - 0.1) * 10) / 10);
			changed = true;
		}
		if (FlxG.keys.justPressed.RBRACKET)
		{
			d.scrollSpeed = Math.min(5, Math.round((d.scrollSpeed + 0.1) * 10) / 10);
			changed = true;
		}
		if (FlxG.keys.justPressed.SEMICOLON)
		{
			d.offsetMs -= 5;
			changed = true;
		}
		if (FlxG.keys.justPressed.QUOTE)
		{
			d.offsetMs += 5;
			changed = true;
		}

		if (changed)
		{
			Settings.flush();
			refresh();
		}
	}

	function play():Void
	{
		lastSong = cur;
		lastDiff = diff;
		PlayState.songId = songs[cur].id;
		PlayState.week = songs[cur].week;
		PlayState.difficulty = DIFF_SUFFIX[diff];
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		FlxG.switchState(new PlayState());
	}
}
