package editor;

import editor.ui.EdUI;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText.FlxTextAlign;

/** Lista de atalhos, aberta por F1 ou pelo botão "?". Clique, ESC ou F1 fecham. */
class HelpOverlay extends FlxSpriteGroup
{
	public var open(default, null):Bool = false;

	var a:Float = 0;
	var skip:Bool = false;

	static final KEYS:String = "ESPAÇO\n↑ ↓  /  roda\nSHIFT + roda\n← →  /  PgUp PgDn\nHOME / END\n\nClique na grade\nArrastar para baixo\nBotão direito / DEL\nQ / E\nCtrl+Z / Ctrl+Y\nCtrl+S\nENTER\nTAB\nESC\n\nColuna da esquerda\nArrastar evento\nF1";
	static final DESC:String = "tocar / pausar\nmover pela música\nmover 4x mais rápido\nseção anterior / próxima\nir ao início / ao fim\n\ncolocar ou selecionar nota\ncriar sustain\napagar\ntrocar a divisão (1/16, 1/32...)\ndesfazer / refazer\nsalvar o chart\nsalvar e testar no jogo\ntrocar de aba\nsair (pede confirmação se não salvou)\n\ncolocar / selecionar evento\nmover o evento\nabrir/fechar esta ajuda";

	public function new()
	{
		super();
		add(EdTheme.rect(0, 0, 1280, 720, 0xFF000000));
		add(new Card(300, 100, 680, 520, "Atalhos"));
		add(EdTheme.text(332, 150, 230, 15, KEYS, EdTheme.ACCENT));
		add(EdTheme.text(570, 150, 400, 15, DESC, EdTheme.TEXT));
		add(EdTheme.text(300, 586, 680, 12, "clique em qualquer lugar para fechar", EdTheme.DIM, FlxTextAlign.CENTER));
		visible = false;
		active = false;
	}

	public function toggle():Void
	{
		open = !open;
		EdLock.locked = open;
		if (open)
		{
			skip = true;
			visible = true;
			active = true;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		a = EdTheme.lerpf(a, open ? 1 : 0, elapsed, 14);
		alpha = a;
		members[0].alpha = a * 0.78;
		if (!open && a < 0.02)
		{
			visible = false;
			active = false;
		}
		if (open && FlxG.mouse.justPressed && !skip)
			toggle();
		skip = false;
	}
}
