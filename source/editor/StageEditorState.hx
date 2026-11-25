package editor;

import core.ModManager;
import core.Paths;
import core.Settings;
import editor.stage.CharsTab;
import editor.stage.LayersTab;
import editor.stage.PropsTab;
import editor.stage.SongTab;
import editor.stage.TimelineTab;
import editor.stage.StageDoc;
import editor.stage.StageSong;
import editor.stage.Transport;
import editor.stage.StageView;
import editor.ui.EdUI;
import editor.ui.MenuBar;
import editor.ui.MenuBar.MenuDef;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxColor;
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

	static inline var BOTTOM_H:Int = 112;
	static final FOCUS:Array<String> = ["Jogador", "Oponente", "GF"];
	static final FOCUS_SLOT:Array<String> = ["bf", "dad", "gf"];

	public var doc:StageDoc;
	public var view:StageView;
	public var song:StageSong = new StageSong();
	var uiCam:FlxCamera;

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
	var dropCb:String->Void;

	static inline var VX:Int = 16;
	static inline var VY:Int = EdTheme.TOP_H + 12;

	public function viewWidth():Float
		return viewW();

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
		song.onNote = view.noteHit;
		song.onBeat = view.beat;
		// o palco tem câmera própria (fica por cima da padrão), então toast e ajuda vão para uma câmera ainda mais acima
		uiCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		uiCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(uiCam, false);

		buildSidebar();
		buildBottomBar();
		buildTopBar();

		toast = new Toast(VX + viewW() / 2, FlxG.height - BOTTOM_H - 40);
		toast.cameras = [uiCam];
		add(toast);
		help = new HelpOverlay("Clique / arrastar\nCantos da peça\nSHIFT ao arrastar\nRoda do mouse\nBotão do meio ou direito\nESPAÇO + arrastar\nSetas / SHIFT + setas\nDEL\nCtrl+D\nCtrl+Z / Ctrl+Y\nCtrl+S\n\nENTER\nHOME / END\nPgUp / PgDn\n, e .\nL\nClique na barra\n\nTAB\nP\nF1\nESC",
			"selecionar e mover peças e personagens\nredimensionar (proporcional)\nencaixar em múltiplos de 10 px\nzoom no palco\nmover a visão\nmover a visão\nmover 1 px / 10 px\nexcluir a camada selecionada\nduplicar a camada\ndesfazer / refazer\nsalvar o stage\n\ntocar / pausar a música\nir ao início / ao fim\nseção anterior / próxima\nbeat anterior / próximo\nligar/desligar o loop do trecho\nir para aquele ponto da música\n\ntrocar de aba\nrecolher / abrir o painel lateral\nabrir/fechar esta ajuda\nsair (pede confirmação se não salvou)",
			"Atalhos do Stage Editor");
		help.cameras = [uiCam];
		add(help);
		#if (lime && !html5)
		dropCb = function(p:String) importFile(p); // arrastar um .png de uma pasta para a janela também importa
		lime.app.Application.current.window.onDropFile.add(dropCb);
		#end
		if (StageSong.lastId != "")
			loadSong(StageSong.lastId, StageSong.lastSuffix, true);
		say("Stage \"" + doc.name + "\" aberto. F1 = atalhos.");
	}

	// ------------------------------------------------------------------ montagem

	function buildTopBar():Void
	{
		add(EdTheme.rect(0, 0, FlxG.width, EdTheme.TOP_H, EdTheme.BG));
		add(EdTheme.rect(0, EdTheme.TOP_H - 1, FlxG.width, 1, EdTheme.LINE));
		titleText = EdTheme.text(EdTheme.LEFT_X, 8, 250, 16, "", EdTheme.TEXT);
		add(titleText);
		add(EdTheme.text(EdTheme.LEFT_X, 29, 250, 12, "STAGE EDITOR", EdTheme.DIM));

		add(new Selector(280, 10, 220, "Stage", function() return stageNames(), function() return doc.name, openStage, 56));
		add(new Btn(506, 10, 66, 32, "NOVO", newStage, 1));
		add(new Btn(946, 10, 70, 32, "SALVAR", save, 1));
		hintText = EdTheme.text(1024, 19, 150, 11, "", EdTheme.DIM);
		add(hintText);
		add(new Btn(1180, 10, 84, 32, "SAIR", leave, 2));
		add(new MenuBar(580, 10, 90, 32, menus()));
	}

	function menus():Array<MenuDef>
	{
		return [
			{
				title: "ARQUIVO",
				entries: [
					{label: "Novo stage", fn: newStage},
					{label: "Salvar", hint: "Ctrl+S", fn: save},
					{label: "Sair para o menu dos editores", hint: "Esc", fn: leave, sep: true}
				]
			},
			{
				title: "EDITAR",
				entries: [
					{label: "Desfazer", hint: "Ctrl+Z", fn: doUndo, enabled: function() return doc.canUndo},
					{label: "Refazer", hint: "Ctrl+Y", fn: doRedo, enabled: function() return doc.canRedo}
				]
			},
			{
				title: "VER",
				entries: [
					{label: "Atalhos e ajuda", hint: "F1", fn: function() help.toggle()},
					{label: "Mostrar/ocultar painel", fn: togglePanel}
				]
			},
			{
				title: "EDITORES",
				entries: [
					{label: "Chart Editor: " + ChartEditorState.songId, fn: function() go(function() EditorNav.toChart(ChartEditorState.songId, ChartEditorState.suffix))},
					{label: "Character Editor: " + CharEditorState.charId, fn: function() go(function() EditorNav.toChar(CharEditorState.charId))},
					{label: "Menu dos editores", fn: leave, sep: true}
				]
			}
		];
	}

	/** Vai para outro editor, avisando se há alterações não salvas (escolha de novo para confirmar). */
	function go(next:Void->Void):Void
	{
		if (doc.dirty && !exitArmed)
		{
			exitArmed = true;
			say("Há alterações não salvas! Escolha de novo para sair sem salvar.", false);
			return;
		}
		next();
	}

	function buildSidebar():Void
	{
		side = new flixel.group.FlxGroup();
		side.add(new Card(EdTheme.SIDE_X, EdTheme.TOP_H + 12, EdTheme.SIDE_W, FlxG.height - EdTheme.TOP_H - 26));
		tabs = new Tabs(EdTheme.SIDE_X + 16, EdTheme.TOP_H + 22, EdTheme.SIDE_W - 32, ["CAMADAS", "PROPRIED.", "PERSON.", "MÚSICA", "TIMELINE"]);
		var a = new LayersTab(this);
		var b = new PropsTab(this);
		var c = new CharsTab(this);
		side.add(a);
		side.add(b);
		var d = new SongTab(this);
		side.add(c);
		side.add(d);
		var e = new TimelineTab(this);
		side.add(e);
		tabs.setContents([a, b, c, d, e]);
		side.add(tabs);
		tabs.select(tabIndex);
		add(side);
	}

	function buildBottomBar():Void
	{
		var y = FlxG.height - BOTTOM_H;
		add(new Transport(this, VX, y));
		var cy = y + 62;
		add(new Toggle(VX + 4, cy + 10, 170, "Testar câmera", function() return view.testCam, function(v) view.testCam = v));
		add(EdTheme.text(VX + 214, cy + 14, 40, 11, "FOCO", EdTheme.DIM));
		add(new Segments(VX + 252, cy + 10, 250, FOCUS, function() return FOCUS[focusIdx], function(v) {
			focusIdx = FOCUS.indexOf(v);
			view.focus = FOCUS_SLOT[focusIdx];
		}));
		add(new Slider(VX + 530, cy + 2, 190, "Zoom do stage", function() return doc.zoom, function(v) {
			doc.begin();
			doc.zoom = v;
		}, 0.2, 2, 2, function(a, b) doc.end("zoom")));
		add(new Toggle(VX + 742, cy + 10, 110, "Moldura", function() return view.showFrame, function(v) view.showFrame = v));
	}

	/** Carrega música e chart; usa os personagens do chart se a opção estiver ligada. */
	public function loadSong(id:String, suffix:String, quiet:Bool = false):Void
	{
		var msg = song.load(id, suffix);
		if (!song.loaded)
		{
			say(msg != null ? msg : "Falha ao carregar " + id, false);
			return;
		}
		var c = song.doc.chart;
		if (SongTab.useChars)
		{
			StageView.idBf = c.player1;
			StageView.idDad = c.player2;
			StageView.idGf = c.gf;
		}
		if (quiet)
			return;
		var extra = c.stage != doc.name ? "  (o chart usa o stage \"" + c.stage + "\")" : "";
		say(msg != null ? msg : "Música \"" + id + "\" carregada." + extra, msg == null);
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

	// ------------------------------------------------------------------ beat atual (timeline)

	var manualBeat:Float = 0;

	/** Com música carregada, o beat vem do transporte; sem música, de um valor manual. */
	public function curBeat():Float
		return song.loaded && song.doc != null ? song.doc.tempo.beatAt(song.ms) : manualBeat;

	public function gotoBeat(b:Float):Void
	{
		b = Math.max(0, b);
		if (song.loaded && song.doc != null)
			song.seek(song.doc.tempo.msAt(b));
		else
			manualBeat = b;
	}

	// ------------------------------------------------------------------ importar imagens

	/** Abre o seletor de arquivos do sistema para escolher um PNG. */
	public function importImage(?then:String->Void):Void
	{
		#if (sys && lime)
		try
		{
			var fd = new lime.ui.FileDialog();
			fd.onSelect.add(function(p:String) importFile(p, then));
			fd.browse(lime.ui.FileDialogType.OPEN, "png", null, "Escolha uma imagem PNG");
		}
		catch (e:Dynamic)
		{
			trace('[StageEditor] seletor de arquivos: $e');
			say("Não consegui abrir o seletor de arquivos. Arraste o .png para a janela.", false);
		}
		#else
		say("Importar arquivos só funciona na versão para PC.", false);
		#end
	}

	/** Copia o PNG para mods/<mod>/images/stages/<stage>/ e cria a camada, que segue o mouse até o clique. */
	public function importFile(path:String, ?then:String->Void):Void
	{
		#if sys
		if (!path.toLowerCase().endsWith(".png"))
		{
			say("Por enquanto só PNG. Converta a imagem para .png e tente de novo.", false);
			return;
		}
		try
		{
			var norm = path.replace("\\", "/");
			var file = norm.substr(norm.lastIndexOf("/") + 1);
			var base = file.substr(0, file.length - 4).replace(" ", "_");
			var dir = ModManager.saveRoot() + "/images/stages/" + doc.name;
			ModManager.mkdirs(dir);
			sys.io.File.copy(path, dir + "/" + base + ".png");
			Paths.rebuild(Settings.d.enabledMods);
			imageCache = null;
			if (then != null)
			{
				then("stages/" + doc.name + "/" + base);
				say("Imagem importada e escolhida para o evento.");
				return;
			}
			var c = view.centerOfView();
			var o = doc.add("stages/" + doc.name + "/" + base, false, c[0], c[1], "front");
			tabs.select(0);
			view.startPlacing(o.id);
			say("Imagem importada! Mova o mouse sobre o palco e clique para posicionar (ESC cancela).");
		}
		catch (e:Dynamic)
		{
			trace('[StageEditor] importar: $e');
			say("Não consegui importar a imagem (veja o log).", false);
		}
		#end
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

	/** Cria um stage em branco com nome livre (stage_novo, stage_novo2...) em vez de alterar o atual. */
	function newStage():Void
	{
		if (doc.dirty && !exitArmed)
		{
			exitArmed = true;
			say("Há alterações não salvas! Clique em NOVO de novo para continuar sem salvar.", false);
			return;
		}
		var have = stageNames();
		var n = "stage_novo";
		var i = 2;
		while (have.indexOf(n) >= 0)
			n = "stage_novo" + (i++);
		stageName = n;
		tabIndex = 0;
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
		song.tick(elapsed);
		view.songPlaying = song.playing;
		view.tlBeat = curBeat();
		if (song.loaded && SongTab.autoFocus)
		{
			view.focus = song.focusSlot();
			focusIdx = Std.int(Math.max(0, FOCUS_SLOT.indexOf(view.focus)));
		}
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
			if (k.justPressed.ESCAPE && !MenuBar.isOpen())
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
			tabs.select((tabs.index + 1) % 5);
		if (k.justPressed.P)
			togglePanel();
		if (k.justPressed.ENTER)
			song.toggle();
		if (k.justPressed.HOME)
			song.seek(0);
		if (k.justPressed.END)
			song.seek(song.lengthMs - 1);
		if (k.justPressed.PAGEUP)
			song.gotoSection(song.sectionIndex() - 1);
		if (k.justPressed.PAGEDOWN)
			song.gotoSection(song.sectionIndex() + 1);
		if (k.justPressed.COMMA)
			song.stepBeats(-1);
		if (k.justPressed.PERIOD)
			song.stepBeats(1);
		if (k.justPressed.L && song.loaded)
			song.setLoop(!song.loopOn);
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
		song.destroy();
		#if (lime && !html5)
		if (dropCb != null)
			lime.app.Application.current.window.onDropFile.remove(dropCb);
		#end
		if (uiCam != null)
			FlxG.cameras.remove(uiCam);
		FlxG.sound.muteKeys = savedMute;
		FlxG.sound.volumeUpKeys = savedUp;
		FlxG.sound.volumeDownKeys = savedDown;
		super.destroy();
	}
}
