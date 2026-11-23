package states;

import core.Paths;
import editor.CharEditorState;
import editor.ChartEditorState;
import editor.StageEditorState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import ui.MenuUtil;

/** Menu dos editores (tecla 7 no menu principal). Por enquanto: Chart Editor. */
class EditorsState extends FlxState
{
	static final ITEMS:Array<String> = ["Chart Editor", "Character Editor", "Stage Editor"];
	static final DIFFS:Array<String> = ["", "-easy", "-hard"];
	static final DIFF_NAMES:Array<String> = ["normal", "easy", "hard"];
	static var lastSong:Int = 0;
	static var lastDiff:Int = 0;

	var rows:Array<FlxText> = [];
	var title:FlxText;
	var hint:FlxText;
	var picking:Bool = false;
	var cur:Int = 0;
	var songs:Array<String> = [];
	var diff:Int = 0;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = false;
		MenuUtil.ensureMenuMusic();

		add(MenuUtil.bg("images/menuDesat.png", 0xFF2A2A3F));
		var shade = new FlxSprite();
		shade.makeGraphic(FlxG.width, FlxG.height, 0xBB000000);
		add(shade);

		title = MenuUtil.text(0, 20, FlxG.width, 44, FlxTextAlign.CENTER, "EDITORES");
		add(title);
		for (i in 0...14)
		{
			var t = MenuUtil.text(0, 100 + i * 36, FlxG.width, 26, FlxTextAlign.CENTER);
			rows.push(t);
			add(t);
		}
		hint = MenuUtil.text(20, FlxG.height - 36, FlxG.width - 40, 16, FlxTextAlign.CENTER, "");
		add(hint);

		songs = [for (n in Paths.list("songs")) if (Paths.exists('songs/$n/Inst.ogg')) n];
		songs.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		paint();
	}

	function paint():Void
	{
		for (r in rows)
			r.text = "";
		if (!picking)
		{
			title.text = "EDITORES";
			for (i in 0...ITEMS.length)
				style(rows[i], ITEMS[i], i == cur, i <= 2);
			hint.text = "↑↓ escolher   ENTER abrir   ESC voltar";
			return;
		}
		title.text = "ESCOLHA A MÚSICA";
		if (songs.length == 0)
		{
			rows[0].text = "Nenhuma música com songs/<id>/Inst.ogg encontrada";
			hint.text = "ESC voltar";
			return;
		}
		var first = Std.int(Math.max(0, Math.min(cur - 7, songs.length - rows.length)));
		for (i in 0...rows.length)
		{
			var idx = first + i;
			if (idx >= songs.length)
				break;
			var id = songs[idx];
			var has = Paths.exists('data/songs/$id/$id${DIFFS[diff]}.json');
			style(rows[i], id + (has ? "" : "   (novo chart)"), idx == cur, has);
		}
		hint.text = "↑↓ música   ←→ dificuldade: " + DIFF_NAMES[diff].toUpperCase() + "   ENTER abrir   ESC voltar";
	}

	function style(t:FlxText, s:String, selected:Bool, enabled:Bool):Void
	{
		t.text = s;
		t.alpha = selected ? 1 : 0.55;
		t.color = selected ? 0xFFFFE066 : (enabled ? FlxColor.WHITE : 0xFF999999);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var n = picking ? songs.length : ITEMS.length;
		if (n > 0 && FlxG.keys.justPressed.UP)
		{
			cur = (cur - 1 + n) % n;
			MenuUtil.sfx("scrollMenu");
			paint();
		}
		if (n > 0 && FlxG.keys.justPressed.DOWN)
		{
			cur = (cur + 1) % n;
			MenuUtil.sfx("scrollMenu");
			paint();
		}
		if (picking && FlxG.keys.justPressed.LEFT)
		{
			diff = (diff + 2) % 3;
			paint();
		}
		if (picking && FlxG.keys.justPressed.RIGHT)
		{
			diff = (diff + 1) % 3;
			paint();
		}
		if (FlxG.keys.justPressed.ESCAPE)
		{
			MenuUtil.sfx("cancelMenu");
			if (picking)
			{
				picking = false;
				cur = 0;
				paint();
			}
			else
				FlxG.switchState(new MainMenuState());
			return;
		}
		if (FlxG.keys.justPressed.ENTER)
		{
			if (!picking)
			{
				if (cur == 0)
				{
					picking = true;
					cur = Std.int(Math.min(lastSong, Math.max(0, songs.length - 1)));
					diff = lastDiff;
					paint();
				}
				else if (cur == 1)
				{
					MenuUtil.sfx("confirmMenu");
					FlxG.switchState(new CharEditorState());
				}
				else if (cur == 2)
				{
					MenuUtil.sfx("confirmMenu");
					FlxG.switchState(new StageEditorState());
				}
				else
					MenuUtil.sfx("cancelMenu");
			}
			else if (songs.length > 0)
			{
				lastSong = cur;
				lastDiff = diff;
				ChartEditorState.songId = songs[cur];
				ChartEditorState.suffix = DIFFS[diff];
				MenuUtil.sfx("confirmMenu");
				FlxG.switchState(new ChartEditorState());
			}
		}
	}
}
