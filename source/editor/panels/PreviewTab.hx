package editor.panels;

import editor.CharPreview;
import editor.ChartEditorState;
import editor.ui.EdUI;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

/** Aba PREVIEW: escolhe o personagem em teste, dispara animações e controla a exibição do preview. */
class PreviewTab extends FlxSpriteGroup
{
	static final SEL:Array<String> = ["Oponente", "Jogador", "GF"];
	static final FRAMING:Array<String> = ["Cena", "Foco", "Personagem"];

	var ed:ChartEditorState;
	var info:FlxText;
	var lastInfo:String = "\u0000";

	public function new(ed:ChartEditorState)
	{
		super();
		this.ed = ed;
		var x = EdTheme.SIDE_X + 20;
		var w = EdTheme.SIDE_W - 40;

		add(EdTheme.text(x, 124, w, 12, "PERSONAGEM EM TESTE", EdTheme.DIM));
		add(new Segments(x - 2, 146, w + 4, SEL, function() return SEL[CharPreview.optSel], function(v) CharPreview.optSel = SEL.indexOf(v)));
		add(new Btn(x, 184, w, 30, "INVERTER LADOS (oponente / jogador)", function() ed.preview.swapChars()));
		add(EdTheme.text(x, 222, w, 12, "Clique num personagem da prévia para escolhê-lo.", EdTheme.DIM));

		add(EdTheme.rect(x, 250, w, 1, EdTheme.LINE));
		add(EdTheme.text(x, 262, w, 12, "DISPARAR ANIMAÇÃO", EdTheme.DIM));

		var bw = Std.int((w - 4 * 6) / 5);
		var labels = ["IDLE", "ESQ", "BAIXO", "CIMA", "DIR"];
		for (i in 0...5)
		{
			var lane = i - 1;
			add(new Btn(x + i * (bw + 6), 286, bw, 30, labels[i], function() {
				if (lane < 0)
					ed.preview.manualIdle();
				else
					ed.preview.manualSing(lane);
			}));
		}
		var half = Std.int((w - 6) / 2);
		add(new Btn(x, 324, half, 30, "MISS (alterna a direção)", function() ed.preview.manualMiss()));
		add(new Btn(x + half + 6, 324, half, 30, "HEY!", function() ed.preview.manualHey()));

		add(new Selector(x, 366, w, "Animação", function() return ed.preview.animList(), function() return CharPreview.pickAnim, function(v) {
			CharPreview.pickAnim = v;
			ed.preview.playNamed(v);
		}, 80));
		add(new Btn(x, 404, w, 30, "TOCAR A ANIMAÇÃO ESCOLHIDA", function() ed.preview.playNamed(CharPreview.pickAnim)));

		info = EdTheme.text(x, 448, w, 14, "", EdTheme.TEXT);
		add(info);

		add(EdTheme.rect(x, 496, w, 1, EdTheme.LINE));
		add(EdTheme.text(x, 508, w, 12, "EXIBIÇÃO", EdTheme.DIM));
		add(new Segments(x - 2, 530, w + 4, FRAMING, function() return FRAMING[CharPreview.optFraming], function(v) CharPreview.optFraming = FRAMING.indexOf(v)));
		add(new Toggle(x, 570, w, "Mostrar o cenário", function() return CharPreview.optStage, function(v) {
			CharPreview.optStage = v;
			ed.preview.applyStageVisibility();
		}));
		add(new Toggle(x, 600, w, "Seguir o chart (notas e eventos)", function() return CharPreview.optFollow, function(v) {
			CharPreview.optFollow = v;
			if (v)
				ed.preview.repose();
		}));
		add(EdTheme.text(x, 640, w, 28, "Ao dar play, o preview canta as notas e roda os eventos\n(Play Animation, Hey!, flash, tremor, zoom e foco).", EdTheme.DIM));
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var s = ed.preview.infoLine();
		if (s != lastInfo)
		{
			lastInfo = s;
			info.text = s;
		}
	}
}
