package editor.panels;

import editor.ChartEditorState;
import editor.ui.EdUI;
import flixel.group.FlxSpriteGroup;

/** Aba CHART: personagens, cenário, velocidade, BPM. */
class ChartTab extends FlxSpriteGroup
{
	public function new(ed:ChartEditorState)
	{
		super();
		var c = ed.doc.chart;
		var x = EdTheme.SIDE_X + 20;
		var w = EdTheme.SIDE_W - 40;

		add(EdTheme.text(x, 124, w, 12, "PERSONAGENS E CENÁRIO", EdTheme.DIM));
		add(new Selector(x, 148, w, "Oponente", function() return ed.listJson("data/characters"), function() return c.player2,
			function(v) ed.prop("oponente", c.player2, function(a) c.player2 = a, v)));
		add(new Selector(x, 186, w, "Jogador", function() return ed.listJson("data/characters"), function() return c.player1,
			function(v) ed.prop("jogador", c.player1, function(a) c.player1 = a, v)));
		add(new Selector(x, 224, w, "GF", function() return ed.listJson("data/characters"), function() return c.gf,
			function(v) ed.prop("gf", c.gf, function(a) c.gf = a, v)));
		add(new Selector(x, 262, w, "Cenário", function() return ed.listJson("data/stages"), function() return c.stage,
			function(v) ed.prop("cenário", c.stage, function(a) c.stage = a, v)));
		add(new Selector(x, 300, w, "Notas", function() return ["normal", "pixel"], function() return c.noteStyle,
			function(v) ed.prop("estilo das notas", c.noteStyle, function(a) c.noteStyle = a, v)));

		add(EdTheme.text(x, 358, w, 12, "ANDAMENTO", EdTheme.DIM));
		add(new Slider(x, 384, w, "Velocidade das notas", function() return c.speed, function(v) c.speed = v, 0.5, 5, 1, function(old, now) {
			c.speed = old;
			ed.prop("velocidade", old, function(a) c.speed = a, now);
		}));
		add(new Stepper(x, 438, w, "BPM desta seção", ed.currentBpm, ed.setCurrentBpm, 1, 10, 999, 2));
		add(new Toggle(x, 484, w, "Esta música usa voz (Voices.ogg)", function() return c.needsVoices, function(v) ed.prop("voz", c.needsVoices, function(a) c.needsVoices = a, v)));

		add(EdTheme.text(x, 548, w, 28, "O BPM vale a partir do início da seção atual.\nAs notas ficam no mesmo lugar da grade.", EdTheme.DIM));
	}
}
