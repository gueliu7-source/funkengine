package states;

import core.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/** Menu de pausa. Desenha na câmera do HUD para escurecer a tela inteira. */
class PauseSubState extends FlxSubState
{
	static final OPTIONS:Array<String> = ["Continuar", "Reiniciar música", "Sair para o menu"];

	var items:Array<FlxText> = [];
	var cur:Int = 0;

	override public function create():Void
	{
		super.create();
		var cam = PlayState.instance.camHUD;

		var dim = new FlxSprite();
		dim.makeGraphic(FlxG.width, FlxG.height, 0xAA000000);
		dim.scrollFactor.set();
		dim.cameras = [cam];
		add(dim);

		for (i in 0...OPTIONS.length)
		{
			var t = new FlxText(0, 260 + i * 56, FlxG.width, OPTIONS[i], 36);
			t.setFormat(Paths.FONT, 36, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.borderSize = 2;
			t.scrollFactor.set();
			t.cameras = [cam];
			items.push(t);
			add(t);
		}
		paint();
	}

	function paint():Void
	{
		for (i in 0...items.length)
		{
			items[i].alpha = i == cur ? 1 : 0.5;
			items[i].color = i == cur ? 0xFFFFE066 : FlxColor.WHITE;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (FlxG.keys.justPressed.UP)
		{
			cur = (cur - 1 + items.length) % items.length;
			paint();
		}
		if (FlxG.keys.justPressed.DOWN)
		{
			cur = (cur + 1) % items.length;
			paint();
		}
		if (FlxG.keys.justPressed.ESCAPE)
			close();
		if (FlxG.keys.justPressed.ENTER)
		{
			switch (cur)
			{
				case 0:
					close();
				case 1:
					FlxG.resetState();
				default:
					FlxG.switchState(PlayState.leave());
			}
		}
	}
}
