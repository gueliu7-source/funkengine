package states;

import core.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import hud.HealthIcon;
import ui.Alphabet;
import ui.MenuUtil;
import ui.SongInfo;
import ui.SongList;

/** Freeplay: lista de músicas (assets + mods) com escolha de dificuldade. ESC volta ao menu principal. */
@:keep
class FreeplayState extends FlxState
{
	var menuScripts:scripting.MenuScripts;

	static inline var VISIBLE:Int = 11;
	static var lastSong:Int = 0;
	static var lastDiff:Int = 1;

	var songs:Array<SongEntry> = [];
	var names:Array<Alphabet> = [];
	var icons:Array<HealthIcon> = [];
	var panel:FlxText;
	var panelBox:FlxSprite;
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

		songs = SongList.load();

		panelBox = new FlxSprite(FlxG.width - 380, 12);
		panelBox.makeGraphic(368, 300, 0xAA000000);
		add(panelBox);
		panel = MenuUtil.text(FlxG.width - 368, 20, 346, 20, FlxTextAlign.LEFT);
		add(panel);
		diffText = MenuUtil.text(FlxG.width - 380, 20, 368, 26, FlxTextAlign.CENTER);
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
		for (n in names)
		{
			remove(n, true);
			n.destroy();
		}
		for (i in icons)
		{
			remove(i, true);
			i.destroy();
		}
		names = [];
		icons = [];
		var mid = Std.int(VISIBLE / 2);
		for (i in 0...VISIBLE)
		{
			var idx = cur + i - mid;
			if (idx < 0 || idx >= songs.length)
				continue;
			var d = Math.abs(i - mid);
			var a = new Alphabet(d == 0 ? 80 : 50, 18 + i * 62, songs[idx].name, 0.7);
			var al = d == 0 ? 1 : Math.max(0.25, 0.7 - d * 0.1);
			for (m in a.members)
				m.alpha = al;
			add(a);
			names.push(a);
			var ic = new HealthIcon(SongInfo.opponentIcon(songs[idx].id), false);
			ic.setGraphicSize(Std.int(ic.frameWidth * 0.6));
			ic.updateHitbox();
			ic.setPosition(a.x + a.width + 12, 18 + i * 62 + 25 - ic.height / 2);
			ic.alpha = al;
			add(ic);
			icons.push(ic);
		}
		if (songs.length == 0)
		{
			diffText.text = "";
			panel.text = "Nenhuma música encontrada";
			return;
		}
		diffText.text = "< " + SongList.DIFF_NAME[diff] + " >";
		var b = core.Scores.best(songs[cur].id, SongList.DIFF_SUFFIX[diff]);
		if (b == null)
			panel.text = "\n\n" + songs[cur].name + "\n\nainda não jogada nesta dificuldade";
		else
			panel.text = "\n\n" + songs[cur].name + "\n\nMELHOR RESULTADO\nPontos:  " + b.score + "\nPrecisão:  " + (Math.round(b.accuracy * 100) / 100) + "%\nRank:  " + b.rank
				+ "\nCombo máximo:  " + b.maxCombo + "\nSick " + b.sicks + "  Good " + b.goods + "  Bad " + b.bads + "  Shit " + b.shits + "\nErros:  " + b.misses;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (menuScripts == null)
			menuScripts = scripting.MenuScripts.make(this, "freeplay");
		menuScripts.update(elapsed);
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

	override public function destroy():Void
	{
		if (menuScripts != null)
			menuScripts.destroy();
		super.destroy();
	}
}
