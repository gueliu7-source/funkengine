package editor.panels;

import editor.ChartEditorState;
import editor.ui.EdUI;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

/** Aba SEÇÃO / NOTA: câmera, navegação e operações na seção; detalhes da nota selecionada. */
class SectionTab extends FlxSpriteGroup
{
	var ed:ChartEditorState;
	var secText:FlxText;
	var selText:FlxText;
	var last1:String = "";
	var last2:String = "";

	public function new(ed:ChartEditorState)
	{
		super();
		this.ed = ed;
		var x = EdTheme.SIDE_X + 20;
		var w = EdTheme.SIDE_W - 40;
		var half = Std.int((w - 8) / 2);
		var third = Std.int((w - 16) / 3);

		secText = EdTheme.text(x, 124, w, 16, "", EdTheme.TEXT);
		add(secText);
		add(new Toggle(x, 154, w, "Câmera no jogador nesta seção", function() return ed.doc.chart.sections[ed.curSection].mustHit, function(v) ed.doc.setMustHit(ed.curSection, v)));
		add(new Btn(x, 194, half, 30, "◀ ANTERIOR", function() ed.gotoSection(ed.curSection - 1)));
		add(new Btn(x + half + 8, 194, half, 30, "PRÓXIMA ▶", function() ed.gotoSection(ed.curSection + 1)));
		add(new Btn(x, 234, third, 30, "COPIAR", ed.copySection));
		add(new Btn(x + third + 8, 234, third, 30, "COLAR", function() ed.paste(true)));
		add(new Btn(x + (third + 8) * 2, 234, third, 30, "COLAR +", function() ed.paste(false)));
		add(new Btn(x, 272, third, 30, "DUPLICAR", ed.dupSection));
		add(new Btn(x + third + 8, 272, third, 30, "ESPELHAR", function() ed.doc.swapSides(ed.curSection)));
		add(new Btn(x + (third + 8) * 2, 272, third, 30, "LIMPAR", function() ed.doc.clearSection(ed.curSection)));
		add(EdTheme.text(x, 310, w, 12, "COLAR troca as notas da seção; COLAR + soma às que já existem.", EdTheme.DIM));

		add(EdTheme.rect(x, 346, w, 1, EdTheme.LINE));
		add(EdTheme.text(x, 362, w, 12, "NOTA SELECIONADA", EdTheme.DIM));
		selText = EdTheme.text(x, 384, w, 14, "", EdTheme.TEXT);
		add(selText);
		add(new Toggle(x, 418, w, "Animação alternativa (alt)", function() return ed.grid.sel != null && ed.grid.sel.alt, function(v) {
			if (ed.grid.sel != null)
				ed.doc.setNoteAlt(ed.grid.sel, v);
		}));
		add(new Selector(x, 458, w, "Tipo", function() return [""].concat(ed.noteTypes()), function() return ed.grid.sel != null ? ed.grid.sel.type : "", function(v) {
			if (ed.grid.sel != null)
				ed.doc.setNoteType(ed.grid.sel, v);
		}, 60));
		add(new Btn(x, 500, half, 30, "APAGAR NOTA", function() ed.grid.deleteSelected(), 0, function() return ed.grid.sel != null));
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var s = ed.doc.chart.sections[ed.curSection];
		var a = "SEÇÃO " + ed.curSection + "   " + s.steps + " steps   " + (s.mustHit ? "câmera: jogador" : "câmera: oponente");
		if (a != last1)
		{
			last1 = a;
			secText.text = a;
		}
		var n = ed.grid.sel;
		var b = n == null ? "clique numa nota para selecionar" : (n.player ? "jogador" : "oponente") + "  lane " + n.lane + "  beat " + Math.round(ed.doc.beatOf(n) * 1000) / 1000
			+ "  sustain " + Math.round(n.sustain) + " ms";
		if (b != last2)
		{
			last2 = b;
			selText.text = b;
		}
	}
}
