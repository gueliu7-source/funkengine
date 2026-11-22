package editor;

import editor.ui.EdUI;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

/**
 * Área reservada para o preview de personagens (Etapa 3). Por enquanto mostra os dois lados
 * e quem está em cada um, já lendo o chart; na Etapa 3 os personagens reais entram aqui.
 */
class PreviewArea extends FlxSpriteGroup
{
	public static inline var PX:Int = EdTheme.LEFT_X;
	public static inline var PY:Int = EdTheme.TOP_H + 12;
	public static inline var PW:Int = EdTheme.LEFT_W;
	public static inline var PH:Int = 236;

	var doc:ChartDoc;
	var oppName:FlxText;
	var plrName:FlxText;
	var lastKey:String = "";

	public function new(doc:ChartDoc)
	{
		super();
		this.doc = doc;
		add(new Card(PX, PY, PW, PH, "Preview"));
		var stage = EdTheme.round(PX + 12, PY + 34, PW - 24, PH - 46, 8);
		stage.color = 0xFF0E1218;
		add(stage);
		add(EdTheme.rect(PX + 24, PY + PH - 44, PW - 48, 1, EdTheme.LINE));
		var o = EdTheme.circle(PX + 64, PY + 96, 70);
		o.color = 0xFF171E29;
		add(o);
		var p = EdTheme.circle(PX + PW - 134, PY + 96, 70);
		p.color = 0xFF171E29;
		add(p);
		add(EdTheme.text(PX + 12, PY + 46, 140, 12, "OPONENTE", EdTheme.DIM));
		add(EdTheme.text(PX + PW - 152, PY + 46, 140, 12, "JOGADOR", EdTheme.DIM, FlxTextAlign.RIGHT));
		oppName = EdTheme.text(PX + 12, PY + PH - 36, 150, 14, "", EdTheme.TEXT);
		plrName = EdTheme.text(PX + PW - 162, PY + PH - 36, 150, 14, "", EdTheme.TEXT, FlxTextAlign.RIGHT);
		add(oppName);
		add(plrName);
		add(EdTheme.text(PX + 12, PY + 100, PW - 24, 12, "personagens ao vivo na Etapa 3", 0xFF3C4757, FlxTextAlign.CENTER));
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var s = doc.chart.player2 + "|" + doc.chart.player1;
		if (s != lastKey)
		{
			lastKey = s;
			oppName.text = doc.chart.player2;
			plrName.text = doc.chart.player1;
		}
	}
}
