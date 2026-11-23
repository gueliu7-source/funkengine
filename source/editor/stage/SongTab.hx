package editor.stage;

import core.Paths;
import editor.StageEditorState;
import editor.ui.EdUI;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

/** Aba MÚSICA: escolhe música e dificuldade, carrega o chart e decide como o preview o usa. */
class SongTab extends FlxSpriteGroup
{
	static final DIFFS:Array<String> = ["normal", "easy", "hard"];
	static final SUFFIX:Array<String> = ["", "-easy", "-hard"];
	static var pick:String = "";
	static var diff:Int = 0;
	public static var useChars:Bool = true;
	public static var autoFocus:Bool = true;

	var ed:StageEditorState;
	var info:FlxText;
	var shown:String = "";

	public function new(ed:StageEditorState)
	{
		super();
		this.ed = ed;
		var x = EdTheme.SIDE_X + 20;
		var w = EdTheme.SIDE_W - 40;

		add(EdTheme.text(x, 124, w, 12, "MÚSICA E CHART", EdTheme.DIM));
		add(new Selector(x, 144, w, "Música", songs, function() {
			var l = songs();
			if ((pick == "" || l.indexOf(pick) < 0) && l.length > 0)
				pick = StageSong.lastId != "" && l.indexOf(StageSong.lastId) >= 0 ? StageSong.lastId : l[0];
			return pick == "" ? "(nenhuma)" : pick;
		}, function(v) pick = v, 70));
		add(EdTheme.text(x, 188, w, 12, "DIFICULDADE", EdTheme.DIM));
		add(new Segments(x - 2, 206, w + 4, DIFFS, function() return DIFFS[diff], function(v) diff = DIFFS.indexOf(v)));
		add(new Btn(x, 246, w, 32, "CARREGAR MÚSICA", loadIt, 1));
		info = EdTheme.text(x, 290, w, 12, "Escolha uma música com songs/<id>/Inst.ogg e carregue. Depois use ENTER (ou o botão PLAY) para tocar.", EdTheme.DIM);
		add(info);

		add(EdTheme.rect(x, 372, w, 1, EdTheme.LINE));
		add(EdTheme.text(x, 382, w, 12, "COMO O PREVIEW USA O CHART", EdTheme.DIM));
		add(new Toggle(x, 402, w, "Usar os personagens do chart", function() return useChars, function(v) useChars = v));
		add(new Toggle(x, 430, w, "Câmera segue a seção (Jogador/Oponente)", function() return autoFocus, function(v) autoFocus = v));
		add(EdTheme.text(x, 470, w, 90, "Ligue \"Testar câmera\" na barra de baixo para ver o parallax e o zoom do jogo enquanto a música toca. As notas fazem os personagens cantarem, o beat faz eles dançarem e o loop (A/B ou SEÇÃO) repete o trecho que você quer conferir.", EdTheme.DIM));
	}

	static function songs():Array<String>
	{
		var l = [for (n in Paths.list("songs")) if (Paths.exists('songs/$n/Inst.ogg')) n];
		l.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return l;
	}

	function loadIt():Void
	{
		if (pick == "")
		{
			ed.say("Nenhuma música encontrada em songs/.", false);
			return;
		}
		ed.loadSong(pick, SUFFIX[diff]);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var s = ed.song;
		var t = s.loaded ? s.id + " [" + DIFFS[SUFFIX.indexOf(s.suffix) < 0 ? 0 : SUFFIX.indexOf(s.suffix)] + "]\n" + s.doc.chart.notes.length + " notas, " + s.doc.chart.sections.length
			+ " seções, " + Std.int(s.doc.tempo.bpmAt(0)) + " BPM\npersonagens: " + s.doc.chart.player1 + " (jogador), " + s.doc.chart.player2 + " (oponente)\nstage do chart: "
			+ s.doc.chart.stage : "Escolha uma música com songs/<id>/Inst.ogg e carregue. Depois use ENTER (ou o botão PLAY) para tocar.";
		if (t != shown)
		{
			shown = t;
			info.text = t;
		}
	}
}
