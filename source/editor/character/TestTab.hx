package editor.character;

import editor.CharEditorState;
import editor.ui.EdUI;
import flixel.group.FlxSpriteGroup;
import game.Character;

using StringTools;

/** Aba TESTE: vê o personagem num stage de verdade, na posição certa, e dispara as animações como no jogo. */
class TestTab extends FlxSpriteGroup
{
	static final SLOTS:Array<String> = ["Jogador", "Oponente", "GF"];
	static final SLOT_ID:Array<String> = ["bf", "dad", "gf"];

	var ed:CharEditorState;
	var miss:Bool = false;

	public function new(ed:CharEditorState)
	{
		super();
		this.ed = ed;
		var x = EdTheme.SIDE_X + 16;
		var w = EdTheme.SIDE_W - 32;

		add(EdTheme.text(x, 124, w, 12, "VER NUM STAGE", EdTheme.DIM));
		add(new Toggle(x, 142, w, "Mostrar dentro de um stage", function() return ed.view.stageName != "", function(v) ed.setStage(v ? ed.firstStage() : "")));
		add(new Selector(x, 174, w, "Stage", function() return ed.stages(), function() return ed.view.stageName == "" ? "(nenhum)" : ed.view.stageName, function(v) ed.setStage(v), 52));
		add(EdTheme.text(x, 212, 80, 12, "Posição", EdTheme.DIM));
		add(new Segments(x + 64, 206, w - 64, SLOTS, function() return SLOTS[Std.int(Math.max(0, SLOT_ID.indexOf(ed.view.slot)))], function(v) ed.setSlot(SLOT_ID[SLOTS.indexOf(v)])));

		add(EdTheme.text(x, 252, w, 12, "COMO NO JOGO (dispara a animação)", EdTheme.DIM));
		var q = Std.int((w - 18) / 4);
		var names = ["← LEFT", "↓ DOWN", "↑ UP", "→ RIGHT"];
		for (i in 0...4)
			add(new Btn(x + i * (q + 6), 270, q, 30, names[i], function() sing(i), 0, null, 12));
		add(new Toggle(x, 308, w, "Versão de erro (miss)", function() return miss, function(v) miss = v));
		var h = Std.int((w - 8) / 2);
		add(new Btn(x, 344, h, 30, "IDLE", function() ed.view.play("idle"), 0));
		add(new Btn(x + h + 8, 344, h, 30, "HEY", function() ed.view.play("hey"), 0));

		add(EdTheme.text(x, 392, w, 12, "OPÇÕES DE VISUALIZAÇÃO", EdTheme.DIM));
		add(new Toggle(x, 410, w, "Fantasma do idle (para alinhar offsets)", function() return ed.view.showGhost, function(v) ed.view.showGhost = v));
		add(new Toggle(x, 438, w, "Repetir a animação em loop", function() return ed.view.loopPlay, function(v) ed.view.loopPlay = v));
		add(new Toggle(x, 466, w, "Mostrar ponto da câmera", function() return ed.view.showCam, function(v) ed.view.showCam = v));
		add(new Toggle(x, 494, w, "Dançar no ritmo (idle a cada beat)", function() return ed.dancing, function(v) ed.dancing = v));
		add(new Stepper(x, 526, w, "BPM", function() return ed.bpm, function(v) ed.bpm = v, 5, 40, 300, 0));
		add(EdTheme.text(x, 566, w, 12, "Os stages são os mesmos do Stage Editor: a posição do personagem vem do arquivo do stage.", EdTheme.DIM));
	}

	function sing(lane:Int):Void
	{
		var n = "sing" + Character.DIRS[lane] + (miss ? "miss" : "");
		if (ed.doc.animByName(n) == null)
		{
			ed.say("Este personagem não tem a animação \"" + n + "\" (crie na aba ANIMAÇÕES).", false);
			return;
		}
		ed.view.play(n);
	}
}
