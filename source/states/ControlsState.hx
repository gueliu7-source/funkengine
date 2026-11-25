package states;

import core.Settings;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import ui.MenuUtil;

/**
 * Controles: cada uma das 4 setas tem 2 teclas. ENTER escolhe a tecla a trocar, depois aperte a nova
 * (ESC cancela, BACKSPACE apaga). Se a tecla já estiver em outro lugar, ela troca de lugar.
 */
@:keep
class ControlsState extends FlxState
{
	var menuScripts:scripting.MenuScripts;

	static final LANES:Array<String> = ["ESQUERDA", "BAIXO", "CIMA", "DIREITA"];
	static final RESERVED:Array<FlxKey> = [FlxKey.ENTER, FlxKey.ESCAPE, FlxKey.BACKSPACE, FlxKey.NONE];

	var rows:Array<FlxText> = [];
	var cur:Int = 0; // 0..7 = teclas, 8 = restaurar padrão
	var waiting:Bool = false;
	var hint:FlxText;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = false;
		MenuUtil.ensureMenuMusic();
		normalize();

		add(MenuUtil.bg("images/menuDesat.png", 0xFF2A2A3F));
		var shade = new FlxSprite();
		shade.makeGraphic(FlxG.width, FlxG.height, 0x99000000);
		add(shade);
		add(MenuUtil.text(0, 20, FlxG.width, 44, FlxTextAlign.CENTER, "CONTROLES"));

		for (i in 0...9)
		{
			var t = MenuUtil.text(0, 110 + i * 48, FlxG.width, 30, FlxTextAlign.CENTER);
			rows.push(t);
			add(t);
		}
		hint = MenuUtil.text(20, FlxG.height - 36, FlxG.width - 40, 16, FlxTextAlign.CENTER, "");
		add(hint);
		paint();
	}

	/** Garante 4 lanes com 2 espaços cada (saves antigos podem ter só 1). */
	function normalize():Void
	{
		var k = Settings.d.keys;
		while (k.length < 4)
			k.push([FlxKey.NONE, FlxKey.NONE]);
		for (l in k)
			while (l.length < 2)
				l.push(FlxKey.NONE);
	}

	function keyName(k:FlxKey):String
		return k == FlxKey.NONE ? "---" : k.toString();

	function paint():Void
	{
		for (i in 0...8)
		{
			var lane = Std.int(i / 2);
			var slot = i % 2;
			var k = Settings.d.keys[lane][slot];
			var label = (slot == 0 ? LANES[lane] + "   tecla 1: " : "           tecla 2: ");
			rows[i].text = label + (waiting && i == cur ? "< aperte uma tecla >" : keyName(k));
			rows[i].alpha = i == cur ? 1 : 0.55;
			rows[i].color = i == cur ? (waiting ? 0xFF66FF99 : 0xFFFFE066) : FlxColor.WHITE;
		}
		rows[8].text = "Restaurar padrão";
		rows[8].alpha = cur == 8 ? 1 : 0.55;
		rows[8].color = cur == 8 ? 0xFFFFE066 : FlxColor.WHITE;
		hint.text = waiting ? "Aperte a nova tecla   ESC cancela   BACKSPACE apaga" : "↑↓ escolher   ENTER trocar tecla   ESC salvar e voltar";
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (menuScripts == null)
			menuScripts = scripting.MenuScripts.make(this, "controls");
		menuScripts.update(elapsed);

		if (waiting)
		{
			if (FlxG.keys.justPressed.ESCAPE)
			{
				waiting = false;
				paint();
				return;
			}
			if (FlxG.keys.justPressed.BACKSPACE)
			{
				bind(cur, FlxKey.NONE);
				return;
			}
			var k:FlxKey = FlxG.keys.firstJustPressed();
			if (k != FlxKey.NONE && RESERVED.indexOf(k) < 0)
				bind(cur, k);
			return;
		}

		if (FlxG.keys.justPressed.ESCAPE)
		{
			Settings.flush();
			MenuUtil.sfx("cancelMenu");
			FlxG.switchState(new OptionsState());
			return;
		}
		if (FlxG.keys.justPressed.UP)
		{
			cur = (cur - 1 + 9) % 9;
			MenuUtil.sfx("scrollMenu");
			paint();
		}
		if (FlxG.keys.justPressed.DOWN)
		{
			cur = (cur + 1) % 9;
			MenuUtil.sfx("scrollMenu");
			paint();
		}
		if (FlxG.keys.justPressed.ENTER)
		{
			if (cur == 8)
			{
				Settings.d.keys = [
					[FlxKey.A, FlxKey.LEFT],
					[FlxKey.S, FlxKey.DOWN],
					[FlxKey.W, FlxKey.UP],
					[FlxKey.D, FlxKey.RIGHT]
				];
				Settings.flush();
			}
			else
				waiting = true;
			MenuUtil.sfx("confirmMenu");
			paint();
		}
	}

	function bind(i:Int, k:FlxKey):Void
	{
		var keys = Settings.d.keys;
		if (k != FlxKey.NONE)
			for (l in keys) // a mesma tecla não pode ficar em dois lugares
				for (s in 0...l.length)
					if (l[s] == k)
						l[s] = FlxKey.NONE;
		keys[Std.int(i / 2)][i % 2] = k;
		waiting = false;
		Settings.flush();
		MenuUtil.sfx("scrollMenu");
		paint();
	}

	override public function destroy():Void
	{
		if (menuScripts != null)
			menuScripts.destroy();
		super.destroy();
	}
}
