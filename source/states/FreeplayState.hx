package states;

import core.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import ui.MenuUtil;
import ui.SongList;

/** Freeplay: lista de músicas (assets + mods) com escolha de dificuldade. ESC volta ao menu principal. */
class FreeplayState extends FlxState
{
	static inline var VISIBLE:Int = 11;
	static var lastSong:Int = 0;
	static var lastDiff:Int = 1;

	var songs:Array<SongEntry> = [];
	var items:Array<FlxText> = [];
	var cur:Int = 0;
	var diff:Int = 1;
	var diffText:FlxText;
	var starting:Bool = false;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = false;
		MenuUtil.ensureMenuMusic();

		add(MenuUtil.bg("images/menuBGBlue.png", 0xFF3B5BA5));

		var shade = new FlxSprite();
		shade.makeGraphic(FlxG.width, FlxG.height, 0x66000000);
		add(shade);

		var title = MenuUtil.text(0, 24, FlxG.width, 44, FlxTextAlign.CENTER, "FREEPLAY");
		add(title);

		songs = SongList.load();

		for (i in 0...VISIBLE)
		{
			var t = MenuUtil.text(0, 0, FlxG.width, 32, FlxTextAlign.CENTER);
			items.push(t);
			add(t);
		}

		diffText = MenuUtil.text(0, 100, FlxG.width, 22, FlxTextAlign.CENTER);
		add(diffText);

		var help = MenuUtil.text(20, FlxG.height - 40, FlxG.width - 40, 16, FlxTextAlign.CENTER,
			"↑↓ música   ←→ dificuldade   ENTER jogar   ESC voltar");
		add(help);

		cur = Std.int(Math.min(lastSong, Math.max(0, songs.length - 1)));
		diff = lastDiff;
		fixDiff(0);
		refresh();
	}

	function hasDiff(i:Int):Bool
		return songs.length > 0 && SongList.hasDiff(songs[cur].id, i);

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
		diffText.text = songs.length == 0 ? "Nenhuma música encontrada (rode tools/import_assets.py)" : "< " + SongList.DIFF_NAME[diff] + " >";
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (starting)
			return;

		if (FlxG.keys.justPressed.ESCAPE)
		{
			MenuUtil.sfx("cancelMenu");
			FlxG.switchState(new MainMenuState());
			return;
		}
		if (songs.length == 0)
			return;

		var changed = false;
		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
		{
			cur = (cur - 1 + songs.length) % songs.length;
			fixDiff(0);
			changed = true;
		}
		if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
		{
			cur = (cur + 1) % songs.length;
			fixDiff(0);
			changed = true;
		}
		if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A)
		{
			fixDiff(-1);
			changed = true;
		}
		if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
		{
			fixDiff(1);
			changed = true;
		}
		if (changed)
		{
			MenuUtil.sfx("scrollMenu");
			refresh();
		}
		if (FlxG.keys.justPressed.ENTER)
			play();
	}

	function play():Void
	{
		starting = true;
		lastSong = cur;
		lastDiff = diff;
		MenuUtil.sfx("confirmMenu");
		PlayState.isStory = false;
		PlayState.storyPlaylist = [];
		PlayState.songId = songs[cur].id;
		PlayState.week = songs[cur].week;
		PlayState.difficulty = SongList.DIFF_SUFFIX[diff];
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		FlxG.switchState(new PlayState());
	}
}
