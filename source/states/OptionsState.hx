package states;

import core.Settings;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import hud.HudStyles;
import ui.MenuUtil;

/** Opções: tudo que antes ficava nos atalhos F1–F5 do menu. ESC salva e volta. */
@:keep
class OptionsState extends FlxState
{
	var menuScripts:scripting.MenuScripts;

	static final NAMES:Array<String> = [
		"Downscroll", "Middlescroll", "Ghost tapping", "Botplay", "Antialiasing", "Zoom da câmera na batida", "Barra da música",
		"Contador de julgamentos", "Ms nos acertos", "Velocidade das notas", "Offset", "Estilo do HUD", "Precisão", "Splashes das notas", "Controles", "Mods"
	];

	var rows:Array<FlxText> = [];
	var cur:Int = 0;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = false;
		MenuUtil.ensureMenuMusic();

		add(MenuUtil.bg("images/menuDesat.png", 0xFF2A2A3F));
		var shade = new FlxSprite();
		shade.makeGraphic(FlxG.width, FlxG.height, 0x99000000);
		add(shade);

		add(MenuUtil.text(0, 20, FlxG.width, 44, FlxTextAlign.CENTER, "OPÇÕES"));

		for (i in 0...NAMES.length)
		{
			var t = MenuUtil.text(0, 80 + i * 40, FlxG.width, 28, FlxTextAlign.CENTER);
			rows.push(t);
			add(t);
		}
		add(MenuUtil.text(20, FlxG.height - 36, FlxG.width - 40, 16, FlxTextAlign.CENTER,
			"↑↓ escolher   ←→ ou ENTER mudar   ESC voltar"));
		paint();
	}

	inline function onOff(b:Bool):String
		return b ? "ON" : "OFF";

	function valueOf(i:Int):String
	{
		var d = Settings.d;
		return switch (i)
		{
			case 0: onOff(d.downscroll);
			case 1: onOff(d.middlescroll);
			case 2: onOff(d.ghostTapping);
			case 3: onOff(d.botplay);
			case 4: onOff(d.antialiasing);
			case 5: onOff(d.camBeatZoom);
			case 6: onOff(d.hudSongBar);
			case 7: onOff(d.hudJudgementCounter);
			case 8: onOff(d.hudMsDisplay);
			case 9: core.Scroll.describe() + "   (ENTER troca o modo, ←→ valor)";
			case 10: d.offsetMs + " ms";
			case 11: HudStyles.get(d.hudStyle).name;
			case 12: d.accuracyMode == "wife3" ? "Wife3 (Kade, rígida)" : "Simples (sick 100%, good 75%)";
			case 13: onOff(d.noteSplashes);
			case 14: "ENTER para trocar teclas";
			default: "(" + d.enabledMods.length + " ativos)";
		}
	}

	function change(i:Int, dir:Int):Void
	{
		var d = Settings.d;
		switch (i)
		{
			case 0: d.downscroll = !d.downscroll;
			case 1: d.middlescroll = !d.middlescroll;
			case 2: d.ghostTapping = !d.ghostTapping;
			case 3: d.botplay = !d.botplay;
			case 4: d.antialiasing = !d.antialiasing;
			case 5: d.camBeatZoom = !d.camBeatZoom;
			case 6: d.hudSongBar = !d.hudSongBar;
			case 7: d.hudJudgementCounter = !d.hudJudgementCounter;
			case 8: d.hudMsDisplay = !d.hudMsDisplay;
			case 9:
				if (d.scrollMode == 0 && dir != 0 && (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.A || FlxG.keys.justPressed.D))
					d.scrollMode = 1; // ←→ no modo "do chart" não fazia nada: agora passa para velocidade fixa
				if (d.scrollMode == 1)
					d.scrollSpeed = Math.min(10, Math.max(0.5, Math.round((d.scrollSpeed + 0.1 * dir) * 10) / 10));
				else if (d.scrollMode == 2)
					d.scrollMult = Math.min(4, Math.max(0.25, Math.round((d.scrollMult + 0.05 * dir) * 100) / 100));
			case 10: d.offsetMs += 5 * dir;
			case 11: d.hudStyle = HudStyles.next(d.hudStyle, dir);
			case 12: d.accuracyMode = d.accuracyMode == "wife3" ? "simple" : "wife3";
			case 13: d.noteSplashes = !d.noteSplashes;
			case 14:
				Settings.flush();
				FlxG.switchState(new ControlsState());
			default:
				Settings.flush();
				FlxG.switchState(new ModsState());
		}
	}

	function paint():Void
	{
		for (i in 0...rows.length)
		{
			rows[i].text = NAMES[i] + ": " + valueOf(i);
			rows[i].alpha = i == cur ? 1 : 0.55;
			rows[i].color = i == cur ? 0xFFFFE066 : FlxColor.WHITE;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (menuScripts == null)
			menuScripts = scripting.MenuScripts.make(this, "options");
		menuScripts.update(elapsed);

		if (FlxG.keys.justPressed.ESCAPE)
		{
			Settings.flush();
			MenuUtil.sfx("cancelMenu");
			FlxG.switchState(new MainMenuState());
			return;
		}
		if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W)
		{
			cur = (cur - 1 + rows.length) % rows.length;
			MenuUtil.sfx("scrollMenu");
			paint();
		}
		if (FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S)
		{
			cur = (cur + 1) % rows.length;
			MenuUtil.sfx("scrollMenu");
			paint();
		}
		var dir = 0;
		if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A)
			dir = -1;
		if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
			dir = 1;
		if (FlxG.keys.justPressed.ENTER)
		{
			if (cur == 9) // troca o modo de velocidade: chart → fixa → multiplicador
			{
				Settings.d.scrollMode = (Settings.d.scrollMode + 1) % 3;
				MenuUtil.sfx("scrollMenu");
				paint();
			}
			else
				dir = 1;
		}
		if (dir != 0)
		{
			change(cur, dir);
			MenuUtil.sfx("scrollMenu");
			paint();
		}
	}

	override public function destroy():Void
	{
		if (menuScripts != null)
			menuScripts.destroy();
		super.destroy();
	}
}
