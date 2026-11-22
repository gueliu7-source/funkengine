package editor.stage;

import editor.StageEditorState;
import editor.ui.EdUI;
import flixel.group.FlxSpriteGroup;

/** Aba PERSONAGENS: quem ocupa cada slot (troca ao vivo), trocar lados e poses de teste. */
class CharsTab extends FlxSpriteGroup
{
	static final TARGETS:Array<String> = ["Jogador", "Oponente", "GF"];
	static final SLOTS:Array<String> = ["bf", "dad", "gf"];
	static var target:Int = 0;

	var ed:StageEditorState;

	public function new(ed:StageEditorState)
	{
		super();
		this.ed = ed;
		var x = EdTheme.SIDE_X + 20;
		var w = EdTheme.SIDE_W - 40;

		add(EdTheme.text(x, 124, w, 12, "QUEM ESTÁ NO PALCO", EdTheme.DIM));
		add(new Selector(x, 144, w, "Jogador", function() return ed.listJson("data/characters"), function() return StageView.idBf, function(v) StageView.idBf = v, 84));
		add(new Selector(x, 176, w, "Oponente", function() return ed.listJson("data/characters"), function() return StageView.idDad, function(v) StageView.idDad = v, 84));
		add(new Selector(x, 208, w, "GF", function() return ed.listJson("data/characters"), function() return StageView.idGf, function(v) StageView.idGf = v, 84));
		add(new Btn(x, 248, w, 30, "TROCAR LADOS (JOGADOR ↔ OPONENTE)", swap, 0));

		add(EdTheme.rect(x, 296, w, 1, EdTheme.LINE));
		add(EdTheme.text(x, 306, w, 12, "TESTAR POSES", EdTheme.DIM));
		add(new Segments(x - 2, 326, w + 4, TARGETS, function() return TARGETS[target], function(v) target = TARGETS.indexOf(v)));
		var names = ["IDLE", "ESQ", "BAI", "CIM", "DIR", "HEY"];
		var bw = Std.int((w - 5 * 6) / 6);
		for (i in 0...names.length)
		{
			var n = names[i];
			add(new Btn(x + i * (bw + 6), 364, bw, 28, n, function() pose(n), 2, null, 11));
		}
		add(new Toggle(x, 406, w, "Idle em loop (como no jogo)", function() return ed.view.animate, function(v) ed.view.animate = v));
		add(EdTheme.text(x, 446, w, 60, "Arraste os personagens direto no palco para posicionar. Use as poses para conferir se o enquadramento e os offsets ficam bons quando eles cantam.", EdTheme.DIM));
	}

	function swap():Void
	{
		var a = StageView.idBf;
		StageView.idBf = StageView.idDad;
		StageView.idDad = a;
		ed.say("Jogador: " + StageView.idBf + "  /  Oponente: " + StageView.idDad);
	}

	function pose(n:String):Void
	{
		var ok = ed.view.pose(SLOTS[target], n);
		if (!ok)
			ed.say(TARGETS[target] + " não tem a animação " + n, false);
	}
}
