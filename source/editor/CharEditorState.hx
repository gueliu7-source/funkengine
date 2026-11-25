package editor;

import core.ModManager;
import core.Paths;
import core.Settings;
import editor.character.AnimTab;
import editor.character.CharDoc;
import editor.character.CharTab;
import editor.character.CharView;
import editor.character.TestTab;
import editor.ui.EdUI;
import editor.ui.MenuBar;
import editor.ui.MenuBar.MenuDef;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxState;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import states.EditorsState;

using StringTools;

/**
 * Character Editor. Mesma estrutura dos outros editores: documento (CharDoc, com desfazer), palco (CharView),
 * abas no painel lateral. Salva em data/characters/<id>.json — o arquivo que o jogo, o Chart Editor e o Stage Editor leem.
 */
class CharEditorState extends FlxState
{
	public static var charId:String = "bf";
	public static var cloneFrom:String = ""; // não vazio: cria um personagem novo copiando este
	static var tabIndex:Int = 0;
	static var lastStage:String = "";
	static var lastSlot:String = "dad";

	static inline var BOTTOM_H:Int = 64;
	static inline var VX:Int = 16;
	static inline var VY:Int = EdTheme.TOP_H + 12;

	public var doc:CharDoc;
	public var view:CharView;
	public var dancing:Bool = false;
	public var bpm:Float = 100;

	var uiCam:FlxCamera;
	var tabs:Tabs;
	var side:flixel.group.FlxGroup;
	var sideOpen:Bool = true;
	var help:HelpOverlay;
	var toast:Toast;
	var titleText:FlxText;
	var hintText:FlxText;
	var infoText:FlxText;
	var exitArmed:Bool = false;
	var cache:Map<FlxText, String> = new Map();
	var savedMute:Array<FlxKey>;
	var savedUp:Array<FlxKey>;
	var savedDown:Array<FlxKey>;
	var dropCb:String->Void;
	var danceT:Float = 0;

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

		if (cloneFrom != "")
		{
			doc = CharDoc.copyOf(cloneFrom, charId);
			cloneFrom = "";
		}
		else
			doc = CharDoc.load(charId);
		add(EdTheme.rect(0, 0, FlxG.width, FlxG.height, EdTheme.BG));
		view = new CharView(doc, VX, VY, viewW(), viewH());
		view.slot = lastSlot;
		view.stageName = lastStage;
		add(view);
		uiCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		uiCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(uiCam, false);

		buildSidebar();
		buildBottomBar();
		buildTopBar();

		toast = new Toast(VX + viewW() / 2, FlxG.height - BOTTOM_H - 40);
		toast.cameras = [uiCam];
		add(toast);
		help = new HelpOverlay("Arrastar no palco\nSetas / SHIFT + setas\nRoda do mouse\nBotão do meio ou direito\nESPAÇO + arrastar\nENTER\n, e .\nCtrl+Z / Ctrl+Y\nCtrl+S\n\nTAB\nP\nF1\nESC",
			"ajusta o offset da animação atual\nmover o desenho 1 px / 10 px\nzoom no palco\nmover a visão\nmover a visão\npausar / tocar a animação\nquadro anterior / próximo\ndesfazer / refazer\nsalvar o personagem\n\ntrocar de aba\nrecolher / abrir o painel lateral\nabrir/fechar esta ajuda\nsair (pede confirmação se não salvou)",
			"Atalhos do Character Editor");
		help.cameras = [uiCam];
		add(help);
		#if (lime && !html5)
		dropCb = function(p:String) importAtlasFile(p);
		lime.app.Application.current.window.onDropFile.add(dropCb);
		#end
		say(doc.isNew ? "Personagem novo \"" + doc.id + "\". Troque o atlas e crie as animações." : "Personagem \"" + doc.id + "\" aberto. F1 = atalhos.");
	}

	// ------------------------------------------------------------------ montagem

	function buildTopBar():Void
	{
		add(EdTheme.rect(0, 0, FlxG.width, EdTheme.TOP_H, EdTheme.BG));
		add(EdTheme.rect(0, EdTheme.TOP_H - 1, FlxG.width, 1, EdTheme.LINE));
		titleText = EdTheme.text(EdTheme.LEFT_X, 8, 250, 16, "", EdTheme.TEXT);
		add(titleText);
		add(EdTheme.text(EdTheme.LEFT_X, 29, 250, 12, "CHARACTER EDITOR", EdTheme.DIM));
		add(new Selector(280, 10, 220, "Perso.", function() return charNames(), function() return doc.id, openChar, 56));
		add(new Btn(506, 10, 66, 32, "NOVO", newChar, 1));
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
					{label: "Novo personagem", fn: newChar},
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
					{label: "Stage Editor: " + StageEditorState.stageName, fn: function() go(function() EditorNav.toStage(StageEditorState.stageName))},
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
		tabs = new Tabs(EdTheme.SIDE_X + 16, EdTheme.TOP_H + 22, EdTheme.SIDE_W - 32, ["ANIMAÇÕES", "PERSONAGEM", "TESTE"]);
		var a = new AnimTab(this);
		var b = new CharTab(this);
		var c = new TestTab(this);
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
		var y = FlxG.height - BOTTOM_H;
		add(new Btn(VX, y + 8, 110, 34, "PAUSAR / TOCAR", function() view.togglePause(), 1, null, 12));
		add(new Btn(VX + 118, y + 8, 40, 34, "|<", function() view.stepFrame(-1), 0));
		add(new Btn(VX + 162, y + 8, 40, 34, ">|", function() view.stepFrame(1), 0));
		add(new Btn(VX + 210, y + 8, 100, 34, "REINICIAR", function() view.play(view.curAnim), 0, null, 12));
		add(new Btn(VX + 318, y + 8, 100, 34, "CENTRALIZAR", function() view.fit(), 0, null, 12));
		infoText = EdTheme.text(VX + 436, y + 16, 400, 13, "", EdTheme.CYAN);
		add(infoText);
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

	function charNames():Array<String>
	{
		var l = listJson("data/characters");
		if (l.indexOf(doc.id) < 0)
			l.push(doc.id);
		return l;
	}

	public function stages():Array<String>
		return listJson("data/stages");

	public function firstStage():String
	{
		var l = stages();
		return lastStage != "" && l.indexOf(lastStage) >= 0 ? lastStage : (l.length > 0 ? l[0] : "");
	}

	public function setStage(n:String):Void
	{
		lastStage = n;
		view.stageName = n;
		view.fit();
	}

	public function setSlot(s:String):Void
	{
		lastSlot = s;
		view.slot = s;
	}

	/** Atlas disponíveis (images/characters/<nome>.png com .xml ou .txt ao lado). */
	public function assets():Array<String>
	{
		var out:Array<String> = [];
		for (f in Paths.list("images/characters"))
			if (f.endsWith(".png"))
			{
				var b = f.substr(0, f.length - 4);
				if (Paths.exists("images/characters/" + b + ".xml") || Paths.exists("images/characters/" + b + ".txt"))
					out.push("characters/" + b);
			}
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		if (out.indexOf(doc.asset) < 0)
			out.push(doc.asset);
		return out;
	}

	public function icons():Array<String>
	{
		var out:Array<String> = [];
		for (f in Paths.list("images/icons"))
			if (f.startsWith("icon-") && f.endsWith(".png"))
				out.push(f.substr(5, f.length - 9));
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		if (out.indexOf(doc.icon) < 0)
			out.push(doc.icon);
		return out;
	}

	// ------------------------------------------------------------------ importar atlas

	/** Escolhe o .png do atlas; o .xml (ou .txt) de mesmo nome precisa estar na mesma pasta. */
	public function importAtlas():Void
	{
		#if (sys && lime)
		try
		{
			var fd = new lime.ui.FileDialog();
			fd.onSelect.add(function(p:String) importAtlasFile(p));
			fd.browse(lime.ui.FileDialogType.OPEN, "png", null, "Escolha o PNG do atlas (com o .xml ao lado)");
		}
		catch (e:Dynamic)
		{
			trace('[CharEditor] seletor de arquivos: $e');
			say("Não consegui abrir o seletor. Arraste o .png para a janela.", false);
		}
		#else
		say("Importar arquivos só funciona na versão para PC.", false);
		#end
	}

	public function importAtlasFile(path:String):Void
	{
		#if sys
		if (!path.toLowerCase().endsWith(".png"))
		{
			say("Escolha o arquivo .png do atlas (o .xml deve estar na mesma pasta).", false);
			return;
		}
		try
		{
			var norm = path.replace("\\", "/");
			var dirIn = norm.substr(0, norm.lastIndexOf("/"));
			var file = norm.substr(norm.lastIndexOf("/") + 1);
			var stem = file.substr(0, file.length - 4);
			var meta = "";
			var packer = false;
			if (sys.FileSystem.exists(dirIn + "/" + stem + ".xml"))
				meta = ".xml";
			else if (sys.FileSystem.exists(dirIn + "/" + stem + ".txt"))
			{
				meta = ".txt";
				packer = true;
			}
			if (meta == "")
			{
				say("Não achei " + stem + ".xml ao lado do PNG. Coloque os dois na mesma pasta.", false);
				return;
			}
			var base = stem.replace(" ", "_");
			var dir = ModManager.saveRoot() + "/images/characters";
			ModManager.mkdirs(dir);
			sys.io.File.copy(path, dir + "/" + base + ".png");
			sys.io.File.copy(dirIn + "/" + stem + meta, dir + "/" + base + meta);
			Paths.rebuild(Settings.d.enabledMods);
			doc.edit("importar atlas", function() {
				doc.asset = "characters/" + base;
				doc.packer = packer;
			});
			say("Atlas \"" + base + "\" importado. Crie as animações na aba ANIMAÇÕES.");
		}
		catch (e:Dynamic)
		{
			trace('[CharEditor] importar atlas: $e');
			say("Não consegui importar o atlas (veja o log).", false);
		}
		#end
	}

	// ------------------------------------------------------------------ ações

	function openChar(name:String):Void
	{
		if (name == doc.id)
			return;
		if (doc.dirty && !exitArmed)
		{
			exitArmed = true;
			say("Há alterações não salvas! Escolha de novo para trocar de personagem sem salvar.", false);
			return;
		}
		charId = name;
		tabIndex = tabs.index;
		FlxG.switchState(new CharEditorState());
	}

	/** Cria um personagem novo a partir de uma cópia do atual (id livre: personagem_novo, personagem_novo2...). */
	function newChar():Void
	{
		if (doc.dirty && !exitArmed)
		{
			exitArmed = true;
			say("Há alterações não salvas! Clique em NOVO de novo para continuar sem salvar.", false);
			return;
		}
		var have = charNames();
		var n = "personagem_novo";
		var i = 2;
		while (have.indexOf(n) >= 0)
			n = "personagem_novo" + (i++);
		cloneFrom = doc.id;
		charId = n;
		tabIndex = 0;
		FlxG.switchState(new CharEditorState());
	}

	function save():Void
	{
		var p = doc.save();
		if (p != null)
		{
			charId = doc.id;
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

		if (dancing && view.ch != null)
		{
			danceT += elapsed;
			if (danceT >= 60 / Math.max(1, bpm) * doc.danceEvery)
			{
				danceT = 0;
				view.ch.specialAnim = false;
				view.ch.dance();
				if (view.ch.animation.curAnim != null)
					view.curAnim = view.ch.animation.curAnim.name;
			}
		}

		var t = doc.id + (doc.dirty ? "  *" : "");
		if (cache.get(titleText) != t)
		{
			cache.set(titleText, t);
			titleText.text = t;
		}
		var h = view.missing != "" ? view.missing : "animação: " + view.curAnim;
		if (cache.get(hintText) != h)
		{
			cache.set(hintText, h);
			hintText.text = h;
		}
		var a = doc.animByName(view.curAnim);
		var info = (a != null ? view.curAnim + "   offset " + Std.int(a.ox) + ", " + Std.int(a.oy) + "   " : "") + "quadro " + view.frameInfo();
		if (cache.get(infoText) != info)
		{
			cache.set(infoText, info);
			infoText.text = info;
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
		if (k.justPressed.TAB && sideOpen)
			tabs.select((tabs.index + 1) % 3);
		if (k.justPressed.P)
			togglePanel();
		if (k.justPressed.ENTER)
			view.togglePause();
		if (k.justPressed.COMMA)
			view.stepFrame(-1);
		if (k.justPressed.PERIOD)
			view.stepFrame(1);
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
