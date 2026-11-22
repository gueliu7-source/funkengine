package editor;

import core.Paths;
import editor.stage.CharsTab;
import editor.stage.LayersTab;
import editor.stage.PropsTab;
import editor.stage.StageDoc;
import editor.stage.StageView;
import editor.ui.EdUI;
import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import states.EditorsState;

using StringTools;

/**
 * Stage Editor. Orquestra: documento (editor/stage/StageDoc), palco (StageView), abas do painel lateral e barras.
 * Etapa 1: palco interativo, camadas e personagens. (Música, chart e timeline de eventos entram nas próximas etapas.)
 */
class StageEditorState extends FlxState
{
	public static var stageName:String = "stage";
	static var tabIndex:Int = 0;
	static var focusIdx:Int = 0;

	static inline var BOTTOM_H:Int = 62;
	static final FOCUS:Array<String> = ["Jogador", "Oponente", "GF"];
	static final FOCUS_SLOT:Array<String> = ["bf", "dad", "gf"];

	public var doc:StageDoc;
	public var view:StageView;

	var tabs:Tabs;
	var side:flixel.group.FlxGroup;
	var sideOpen:Bool = true;
	var help:HelpOverlay;
	var toast:Toast;
	var titleText:FlxText;
	var hintText:FlxText;
	var exitArmed:Bool = false;
	var cache:Map<FlxText, String> = new Map();
	var savedMute:Array<FlxKey>;
	var savedUp:Array<FlxKey>;
	var savedDown:Array<FlxKey>;
	var imageCache:Array<String>;

	static inline var VX:Int = 16;
	static inline var VY:Int = EdTheme.TOP_H + 12;

	function viewW():Float
		return sideOpen ? EdTheme.SIDE_X - 12 - VX : FlxG.width - 2 * VX;

	function viewH():Float
		return FlxG.height - VY - BOTTOM_H - 12;

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = true;
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		savedMute = FlxG.sound.muteKeys;
		savedUp = FlxG.sound.volumeUpKeys;
		savedDown = FlxG.sound.volumeDownKeys;
		FlxG.sound.muteKeys = null;
		FlxG.sound.volumeUpKeys = null;
		FlxG.sound.volumeDownKeys = null;
		EdLock.locked = false;

		doc = StageDoc.load(stageName);
		add(EdTheme.rect(0, 0, FlxG.width, FlxG.height, EdTheme.BG));
		view = new StageView(doc, VX, VY, viewW(), viewH());
		view.focus = FOCUS_SLOT[focusIdx];
		add(view);

		buildSidebar();
		buildBottomBar();
		buildTopBar();

		toast = new Toast(VX + viewW() / 2, FlxG.height - BOTTOM_H - 40);
		add(toast);
		help = new HelpOverlay("Clique / arrastar\nCantos da peça\nSHIFT ao arrastar\nRoda do mouse\nBotão do meio ou direito\nESPAÇO + arrastar\nSetas / SHIFT + setas\nDEL\nCtrl+D\nCtrl+Z / Ctrl+Y\nCtrl+S\nTAB\nP\nF1\nESC",
			"selecionar e mover peças e personagens\nredimensionar (proporcional)\nencaixar em múltiplos de 10 px\nzoom no palco\nmover a visão\nmover a visão\nmover 1 px / 10 px\nexcluir a camada selecionada\nduplicar a camada\ndesfazer / refazer\nsalvar o stage\ntrocar de aba\nrecolher / abrir o painel lateral\nabrir/fechar esta ajuda\nsair (pede confirmação se não salvou)",
			"Atalhos do Stage Editor");
		add(help);
		say("Stage \"" + doc.name + "\" aberto. Clique numa peça para editar. F1 = atalhos.");
	}

	// ------------------------------------------------------------------ montagem

	function buildTopBar():Void
	{
		add(EdTheme.rect(0, 0, FlxG.width, EdTheme.TOP_H, EdTheme.BG));
		add(EdTheme.rect(0, EdTheme.TOP_H - 1, FlxG.width, 1, EdTheme.LINE));
		titleText = EdTheme.text(EdTheme.LEFT_X, 8, 250, 16, "", EdTheme.TEXT);
		add(titleText);
		add(EdTheme.text(EdTheme.LEFT_X, 29, 250, 12, "STAGE EDITOR", EdTheme.DIM));

		add(new Selector(280, 10, 280, "Stage", function() return stageNames(), function() return doc.name, openStage, 56));
		add(new Btn(580, 10, 80, 32, "DESFAZER", doUndo, 2, function() return doc.canUndo));
		add(new Btn(666, 10, 80, 32, "REFAZER", doRedo, 2, function() return doc.canRedo));
		add(new Btn(766, 10, 84, 32, "SALVAR", save, 1));
		add(new Btn(856, 10, 34, 32, "?", function() help.toggle(), 2));
		add(new Btn(900, 10, 90, 32, "PAINEL", togglePanel, 2));
		add(new Btn(1180, 10, 84, 32, "SAIR", leave, 2));
	}

	function buildSidebar():Void
	{
		side = new flixel.group.FlxGroup();
		side.add(new Card(EdTheme.SIDE_X, EdTheme.TOP_H + 12, EdTheme.SIDE_W, FlxG.height - EdTheme.TOP_H - 26));
		tabs = new Tabs(EdTheme.SIDE_X + 16, EdTheme.TOP_H + 22, EdTheme.SIDE_W - 32, ["CAMADAS", "PROPRIEDADES", "PERSONAGENS"]);
		var a = new LayersTab(this);
		var b = new PropsTab(this);
		var c = new CharsTab(this);
		side.add(a);
		side.add(b);
		side.add(c);
		tabs.setContents([a, b, c]);
		side.add(tabs);
		tabs.select(tabIndex);
		add(side);
	}

	function buildBottomBar():Void
	{
		var y = FlxG.height - BOTTOM_H - 4;
		add(new Toggle(VX + 4, y + 16, 214, "Testar câmera (parallax)", function() return view.testCam, function(v) view.testCam = v));
		add(EdTheme.text(VX + 240, y + 4, 60, 11, "FOCO", EdTheme.DIM));
		add(new Segments(VX + 236, y + 22, 250, FOCUS, function() return FOCUS[focusIdx], function(v) {
			focusIdx = FOCUS.indexOf(v);
			view.focus = FOCUS_SLOT[focusIdx];
		}));
		add(new Slider(VX + 510, y + 6, 200, "Zoom do stage", function() return doc.zoom, function(v) {
			doc.begin();
			doc.zoom = v;
		}, 0.2, 2, 2, function(a, b) doc.end("zoom")));
		add(new Toggle(VX + 730, y + 16, 120, "Moldura", function() return view.showFrame, function(v) view.showFrame = v));
		hintText = EdTheme.text(VX + 8, y - 2, 400, 11, "", EdTheme.DIM);
		add(hintText);
	}

	// ------------------------------------------------------------------ API para as abas

	public function say(s:String, good:Bool = true):Void
		toast.show(s, good);

	public function listJson(dir:String):Array<String>
	{
		var out:Array<String> = [];
		for (n in Paths.list(dir))
			if (n.endsWith(".json"))
				out.push(n.substr(0, n.length - 5));
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}

	function stageNames():Array<String>
	{
		var l = listJson("data/stages");
		if (l.indexOf(doc.name) < 0)
			l.push(doc.name);
		return l;
	}

	/** Imagens disponíveis para novas camadas (images/stages/<pasta>/<arquivo>.png). */
	public function images():Array<String>
	{
		if (imageCache != null)
			return imageCache;
		var out:Array<String> = [];
		for (d in Paths.list("images/stages"))
			for (f in Paths.list("images/stages/" + d))
				if (f.endsWith(".png"))
					out.push("stages/" + d + "/" + f.substr(0, f.length - 4));
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		imageCache = out;
		return out;
	}

	// ------------------------------------------------------------------ ações

	function openStage(name:String):Void
	{
		if (name == doc.name)
			return;
		if (doc.dirty && !exitArmed)
		{
			exitArmed = true;
			say("Há alterações não salvas! Escolha de novo para trocar de stage sem salvar.", false);
			return;
		}
		stageName = name;
		tabIndex = tabs.index;
		FlxG.switchState(new StageEditorState());
	}

	function save():Void
	{
		var p = doc.save();
		if (p != null)
		{
			stageName = doc.name;
			say("Salvo em " + p);
		}
		else
			say("Erro ao salvar (veja o log).", false);
	}

	function doUndo():Void
	{
		var n = doc.undo();
		if (n != null)
			say("Desfeito: " + n);
	}

	function doRedo():Void
	{
		var n = doc.redo();
		if (n != null)
			say("Refeito: " + n);
	}

	function togglePanel():Void
	{
		sideOpen = !sideOpen;
		side.visible = side.active = sideOpen;
		view.resize(viewW(), viewH());
	}

	function leave():Void
	{
		if (doc.dirty && !exitArmed)
		{
			exitArmed = true;
			say("Há alterações não salvas! Clique em SAIR / ESC de novo para sair sem salvar.", false);
			return;
		}
		FlxG.switchState(new EditorsState());
	}

	// ------------------------------------------------------------------ loop

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (!TextInput.typing() && !TextInput.swallow)
			keys();
		TextInput.swallow = false;

		var t = doc.name + (doc.dirty ? "  *" : "");
		if (cache.get(titleText) != t)
		{
			cache.set(titleText, t);
			titleText.text = t;
		}
		var h = view.testCam ? "Câmera de teste: parallax e zoom reais do jogo" : (view.sel == "" ? "nada selecionado" : "selecionado: " + view.sel);
		if (cache.get(hintText) != h)
		{
			cache.set(hintText, h);
			hintText.text = h;
		}
	}

	function keys():Void
	{
		var k = FlxG.keys;
		var ctrl = k.pressed.CONTROL;
		if (k.justPressed.F1)
			help.toggle();
		if (EdLock.locked)
		{
			if (k.justPressed.ESCAPE)
				help.toggle();
			return;
		}
		if (k.justPressed.ESCAPE)
			leave();
		if (ctrl && k.justPressed.S)
			save();
		if (ctrl && k.justPressed.Z)
			doUndo();
		if (ctrl && k.justPressed.Y)
			doRedo();
		if (ctrl && k.justPressed.D && view.sel != "" && !view.sel.startsWith("@"))
		{
			var o = doc.duplicate(view.sel);
			if (o != null)
				view.sel = o.id;
		}
		if (k.justPressed.TAB && sideOpen)
			tabs.select((tabs.index + 1) % 3);
		if (k.justPressed.P)
			togglePanel();
		if (k.justPressed.DELETE && view.sel != "" && !view.sel.startsWith("@"))
		{
			doc.remove(view.sel);
			view.sel = "";
		}
		var step = k.pressed.SHIFT ? 10 : 1;
		if (!ctrl)
		{
			if (k.justPressed.LEFT)
				view.nudge(-step, 0);
			if (k.justPressed.RIGHT)
				view.nudge(step, 0);
			if (k.justPressed.UP)
				view.nudge(0, -step);
			if (k.justPressed.DOWN)
				view.nudge(0, step);
		}
	}

	override public function destroy():Void
	{
		tabIndex = tabs != null ? tabs.index : 0;
		EdLock.locked = false;
		TextInput.current = null;
		FlxG.sound.muteKeys = savedMute;
		FlxG.sound.volumeUpKeys = savedUp;
		FlxG.sound.volumeDownKeys = savedDown;
		super.destroy();
	}
}
