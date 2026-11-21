package states;

import core.ModManager;
import core.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/** Tela de mods: ENTER liga/desliga, SHIFT+↑/↓ muda a prioridade (de cima para baixo), ESC aplica e volta. */
class ModsState extends FlxState
{
	static inline var VISIBLE:Int = 9;

	var cur:Int = 0;
	var rows:Array<FlxText> = [];
	var info:FlxText;
	var help:FlxText;

	override public function create():Void
	{
		super.create();
		var bg = new FlxSprite();
		bg.makeGraphic(FlxG.width, FlxG.height, 0xFF14141F);
		add(bg);

		add(text(0, 28, FlxG.width, 40, FlxTextAlign.CENTER, "MODS"));

		for (i in 0...VISIBLE)
		{
			var t = text(0, 110 + i * 46, FlxG.width, 30, FlxTextAlign.CENTER, "");
			rows.push(t);
			add(t);
		}
		info = text(60, FlxG.height - 190, FlxG.width - 120, 20, FlxTextAlign.CENTER, "");
		add(info);
		help = text(20, FlxG.height - 60, FlxG.width - 40, 16, FlxTextAlign.CENTER,
			"↑↓ escolher   ENTER ligar/desligar   SHIFT+↑↓ prioridade (o de cima vence)   ESC aplicar e voltar");
		add(help);
		refresh();
	}

	function text(x:Float, y:Float, w:Float, size:Int, align:FlxTextAlign, s:String):FlxText
	{
		var t = new FlxText(x, y, w, s, size);
		t.setFormat(Paths.FONT, size, FlxColor.WHITE, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.borderSize = 2;
		return t;
	}

	function refresh():Void
	{
		var mods = ModManager.mods;
		if (mods.length == 0)
		{
			rows[0].text = "Nenhum mod encontrado";
			info.text = "Crie uma pasta em mods/<nome>/ (veja mods/README.txt e mods/example).";
			return;
		}
		var first = Std.int(Math.max(0, Math.min(cur - Std.int(VISIBLE / 2), mods.length - VISIBLE)));
		for (i in 0...VISIBLE)
		{
			var idx = first + i;
			var t = rows[i];
			if (idx >= mods.length)
			{
				t.text = "";
				continue;
			}
			var m = mods[idx];
			t.text = (m.enabled ? "[ON]  " : "[off] ") + m.name + (m.version != "" ? "  v" + m.version : "");
			t.color = idx == cur ? 0xFFFFE066 : (m.enabled ? m.color : 0xFF888888);
		}
		var c = mods[cur];
		info.text = (c.description != "" ? c.description : "(sem descrição)") + (c.author != "" ? "\npor " + c.author : "") + "\nmods/" + c.id;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var n = ModManager.mods.length;
		if (n > 0)
		{
			if (FlxG.keys.justPressed.UP)
			{
				if (FlxG.keys.pressed.SHIFT && ModManager.mods[cur].enabled)
					cur = ModManager.move(cur, -1);
				else
					cur = (cur - 1 + n) % n;
				refresh();
			}
			if (FlxG.keys.justPressed.DOWN)
			{
				if (FlxG.keys.pressed.SHIFT && ModManager.mods[cur].enabled && cur + 1 < n && ModManager.mods[cur + 1].enabled)
					cur = ModManager.move(cur, 1);
				else
					cur = (cur + 1) % n;
				refresh();
			}
			if (FlxG.keys.justPressed.ENTER)
			{
				var m = ModManager.mods[cur];
				m.enabled = !m.enabled;
				ModManager.normalize();
				cur = ModManager.mods.indexOf(m);
				refresh();
			}
		}
		if (FlxG.keys.justPressed.ESCAPE)
		{
			ModManager.apply();
			FlxG.switchState(new OptionsState());
		}
	}
}
