package states;

import core.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import ui.MenuUtil;
import ui.SongList;

typedef WeekEntry =
{
	var week:Int;
	var title:String;
	var ids:Array<String>;
	var names:Array<String>;
}

/**
 * Story Mode no estilo do original: faixa amarela, lista de semanas embaixo à direita,
 * "TRACKS" à esquerda e escolha de dificuldade. As músicas da semana tocam em sequência.
 */
@:keep
class StoryMenuState extends FlxState
{
	var menuScripts:scripting.MenuScripts = scripting.MenuScripts.make(this, "story");

	static var lastWeek:Int = 0;
	static var lastDiff:Int = 1;

	static final TITLES:Array<String> = [
		"Tutorial", "Daddy Dearest", "Spooky Month", "PICO", "Mommy Must Murder", "Red Snow", "Hating Simulator ft. Moawling"
	];

	var weeks:Array<WeekEntry> = [];
	var cur:Int = 0;
	var diff:Int = 1;
	var starting:Bool = false;

	var weekSprites:Array<FlxSprite> = [];
	var tracksText:FlxText;
	var titleText:FlxText;
	var diffText:FlxText;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = false;
		MenuUtil.ensureMenuMusic();

		buildWeeks();

		var base = new FlxSprite();
		base.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(base);

		var banner = new FlxSprite(0, 56);
		banner.makeGraphic(FlxG.width, 400, 0xFFF9CF51);
		add(banner);

		titleText = MenuUtil.text(0, 10, FlxG.width - 20, 32, FlxTextAlign.RIGHT);
		titleText.alpha = 0.7;
		add(titleText);

		diffText = MenuUtil.text(20, 10, 400, 32, FlxTextAlign.LEFT);
		add(diffText);

		var tracksHeader = MenuUtil.text(20, 480, 400, 28, FlxTextAlign.LEFT, "TRACKS");
		tracksHeader.color = 0xFFE55777;
		add(tracksHeader);

		tracksText = MenuUtil.text(20, 520, 420, 26, FlxTextAlign.LEFT);
		tracksText.color = 0xFFE55777;
		add(tracksText);

		for (w in weeks)
		{
			var g = Paths.graphic('images/storymenu/week${w.week}.png');
			var s = new FlxSprite();
			if (g != null)
				s.loadGraphic(g);
			else
				s.makeGraphic(360, 80, 0xFF333333);
			s.antialiasing = true;
			weekSprites.push(s);
			add(s);
		}

		if (weeks.length == 0)
			titleText.text = "Nenhuma semana encontrada";

		cur = Std.int(Math.min(lastWeek, Math.max(0, weeks.length - 1)));
		diff = lastDiff;
		fixDiff(0);
		refresh();
	}

	function buildWeeks():Void
	{
		var byWeek:Map<Int, WeekEntry> = new Map();
		var order:Array<Int> = [];
		for (s in SongList.load())
		{
			var w = byWeek.get(s.week);
			if (w == null)
			{
				w = {week: s.week, title: s.week < TITLES.length ? TITLES[s.week] : 'Week ${s.week}', ids: [], names: []};
				byWeek.set(s.week, w);
				order.push(s.week);
			}
			w.ids.push(s.id);
			w.names.push(s.name);
		}
		order.sort(function(a, b) return a - b);
		for (k in order)
			weeks.push(byWeek.get(k));
	}

	function hasDiff(i:Int):Bool
	{
		if (weeks.length == 0)
			return false;
		for (id in weeks[cur].ids)
			if (!SongList.hasDiff(id, i))
				return false;
		return true;
	}

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
		for (i in 0...weekSprites.length)
		{
			var s = weekSprites[i];
			var off = i - cur;
			s.x = FlxG.width - s.width - 60;
			s.y = 480 + off * 100;
			s.visible = s.y >= 470 && s.y < FlxG.height - 10;
			s.alpha = off == 0 ? 1 : 0.5;
		}
		if (weeks.length == 0)
			return;
		titleText.text = weeks[cur].title;
		diffText.text = "< " + SongList.DIFF_NAME[diff] + " >";
		var lines:Array<String> = [];
		for (n in weeks[cur].names)
			lines.push(n.toUpperCase());
		tracksText.text = lines.join("\n");
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		menuScripts.update(elapsed);
		if (starting)
			return;

		if (FlxG.keys.justPressed.ESCAPE)
		{
			MenuUtil.sfx("cancelMenu");
			FlxG.switchState(new MainMenuState());
			return;
		}
		if (weeks.length == 0)
			return;

		var changed = false;
		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
		{
			cur = (cur - 1 + weeks.length) % weeks.length;
			fixDiff(0);
			changed = true;
		}
		if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
		{
			cur = (cur + 1) % weeks.length;
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
			start();
	}

	function start():Void
	{
		starting = true;
		lastWeek = cur;
		lastDiff = diff;
		MenuUtil.sfx("confirmMenu");
		FlxG.camera.flash(FlxColor.WHITE, 0.6);
		weekSprites[cur].color = 0xFF33FFFF;

		var w = weeks[cur];
		PlayState.isStory = true;
		PlayState.songId = w.ids[0];
		PlayState.storyPlaylist = w.ids.slice(1);
		PlayState.week = w.week;
		PlayState.difficulty = SongList.DIFF_SUFFIX[diff];
		if (FlxG.sound.music != null)
			FlxG.sound.music.fadeOut(0.9, 0);
		new FlxTimer().start(1, function(_) FlxG.switchState(new PlayState()));
	}

	override public function destroy():Void
	{
		menuScripts.destroy();
		super.destroy();
	}
}
