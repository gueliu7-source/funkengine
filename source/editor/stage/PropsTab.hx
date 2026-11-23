package editor.stage;

import editor.StageEditorState;
import editor.stage.StageDoc.SObj;
import editor.ui.EdUI;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

using StringTools;

/** Aba PROPRIEDADES: muda conforme a seleção (camada, personagem ou o stage inteiro). */
class PropsTab extends FlxSpriteGroup
{
	var ed:StageEditorState;
	var objG:FlxSpriteGroup = new FlxSpriteGroup();
	var charG:FlxSpriteGroup = new FlxSpriteGroup();
	var stageG:FlxSpriteGroup = new FlxSpriteGroup();
	var objInfo:FlxText;
	var charTitle:FlxText;
	var charInfo:FlxText;
	var mode:Int = -1;

	function cur():Null<SObj>
		return ed.doc.byId(ed.view.sel);

	function slot():String
		return ed.view.sel.startsWith("@") ? ed.view.sel.substr(1) : "dad";

	function slotCharId():String
	{
		return switch (slot())
		{
			case "bf": StageView.idBf;
			case "gf": StageView.idGf;
			default: StageView.idDad;
		}
	}

	public function new(ed:StageEditorState)
	{
		super();
		this.ed = ed;
		var x = EdTheme.SIDE_X + 20;
		var w = EdTheme.SIDE_W - 40;

		// ---- camada
		objG.add(EdTheme.text(x, 124, w, 12, "NOME (ID)", EdTheme.DIM));
		objG.add(new TextInput(x, 140, w, function() return cur() != null ? cur().id : "", function(v) {
			var o = cur();
			var nv = v.trim();
			if (o == null || nv == "" || nv == o.id || nv.startsWith("@") || ed.doc.byId(nv) != null)
				return;
			ed.doc.edit("renomear camada", function() o.id = nv);
			ed.view.sel = nv;
		}));
		objG.add(new Stepper(x, 184, w, "X", function() return cur() != null ? cur().x : 0, function(v) edit("posição", function(o) o.x = v), 10, -5000, 5000, 0));
		objG.add(new Stepper(x, 212, w, "Y", function() return cur() != null ? cur().y : 0, function(v) edit("posição", function(o) o.y = v), 10, -5000, 5000, 0));
		objG.add(new Stepper(x, 240, w, "Escala", function() return cur() != null ? cur().scale : 1, function(v) edit("escala", function(o) o.scale = v), 0.05, 0.02, 10, 2));
		objG.add(new Stepper(x, 268, w, "Parallax X", function() return cur() != null ? cur().sx : 1, function(v) edit("parallax", function(o) o.sx = v), 0.05, 0, 3, 2));
		objG.add(new Stepper(x, 296, w, "Parallax Y", function() return cur() != null ? cur().sy : 1, function(v) edit("parallax", function(o) o.sy = v), 0.05, 0, 3, 2));
		objG.add(new Slider(x, 330, w, "Opacidade", function() return cur() != null ? cur().alpha : 1, function(v) {
			var o = cur();
			if (o != null)
			{
				ed.doc.begin();
				o.alpha = v;
			}
		}, 0, 1, 2, function(a, b) ed.doc.end("opacidade")));
		objG.add(new Stepper(x, 376, w, "Ângulo", function() return cur() != null ? cur().angle : 0, function(v) edit("ângulo", function(o) o.angle = v), 5, -360, 360, 0));
		objG.add(EdTheme.text(x, 412, w, 12, "COR / TINT (hex, ex.: 6A5ACD — vazio = nenhuma)", EdTheme.DIM));
		objG.add(new TextInput(x, 428, w, function() return cur() != null ? cur().color : "", function(v) edit("cor", function(o) o.color = v.trim().replace("#", "").toUpperCase())));
		objG.add(new Toggle(x, 472, w, "Espelhar (flipX)", function() return cur() != null && cur().flipX, function(v) edit("espelhar", function(o) o.flipX = v)));
		objG.add(new Toggle(x, 500, w, "Suavizar (antialiasing)", function() return cur() != null && cur().aa, function(v) edit("antialiasing", function(o) o.aa = v)));
		objG.add(EdTheme.text(x, 536, w, 12, "PREFIXO DA ANIMAÇÃO (peças animadas)", EdTheme.DIM));
		objG.add(new TextInput(x, 552, w, function() return cur() != null ? cur().idle : "", function(v) edit("animação", function(o) o.idle = v.trim())));
		objInfo = EdTheme.text(x, 598, w, 12, "", EdTheme.DIM);
		objG.add(objInfo);

		// ---- personagem
		charTitle = EdTheme.text(x, 124, w, 16, "", EdTheme.CYAN);
		charG.add(charTitle);
		charG.add(new Stepper(x, 156, w, "X", function() return pos(0), function(v) setPos(v, pos(1)), 10, -5000, 5000, 0));
		charG.add(new Stepper(x, 184, w, "Y", function() return pos(1), function(v) setPos(pos(0), v), 10, -5000, 5000, 0));
		charG.add(new Toggle(x, 222, w, "Posição própria deste personagem", function() return ed.doc.hasOverride(slotCharId()), function(v) ed.doc.setOverride(slot(), slotCharId(), v)));
		charInfo = EdTheme.text(x, 256, w, 12, "", EdTheme.DIM);
		charG.add(charInfo);

		// ---- stage
		stageG.add(EdTheme.text(x, 124, w, 12, "NOME DO ARQUIVO (data/stages/<nome>.json)", EdTheme.DIM));
		stageG.add(new TextInput(x, 140, w, function() return ed.doc.name, function(v) {
			var nv = v.trim().replace(" ", "_");
			if (nv != "" && nv != ed.doc.name)
			{
				ed.doc.name = nv;
				ed.doc.dirty = true;
			}
		}));
		stageG.add(new Stepper(x, 184, w, "Zoom da câmera", function() return ed.doc.zoom, function(v) ed.doc.edit("zoom", function() ed.doc.zoom = v), 0.05, 0.2, 3, 2));
		stageG.add(EdTheme.text(x, 236, w, 12, "Clique numa peça no palco ou na aba Camadas para editar. Arraste para mover, cantos para redimensionar (SHIFT = encaixa), roda do mouse = zoom, botão do meio/direito (ou ESPAÇO + arrastar) = mover a visão.", EdTheme.DIM));

		add(objG);
		add(charG);
		add(stageG);
		setMode(2);
	}

	function edit(label:String, fn:SObj->Void):Void
	{
		var o = cur();
		if (o != null)
			ed.doc.edit(label, function() fn(o));
	}

	function pos(i:Int):Float
	{
		var p = ed.doc.positionOf(slot(), slotCharId());
		return p[i];
	}

	function setPos(x:Float, y:Float):Void
		ed.doc.edit("posição", function() ed.doc.setPosition(slot(), slotCharId(), x, y));

	function setMode(m:Int):Void
	{
		if (m == mode)
			return;
		mode = m;
		objG.active = (m == 0);
		charG.active = (m == 1);
		stageG.active = (m == 2);
	}

	/** O grupo pai propaga "visible" a todos os filhos; por isso a escolha de qual subgrupo aparece é refeita a cada desenho. */
	override public function draw():Void
	{
		objG.visible = (mode == 0);
		charG.visible = (mode == 1);
		stageG.visible = (mode == 2);
		super.draw();
	}

	override public function update(elapsed:Float):Void
	{
		var s = ed.view.sel;
		setMode(s == "" ? 2 : (s.startsWith("@") ? 1 : 0));
		if (mode == 0)
		{
			var o = cur();
			if (o == null)
				setMode(2);
			else
			{
				var t = "imagem: " + o.image + (o.animated ? " (animada)" : "") + "   grupo: " + o.group;
				if (objInfo.text != t)
					objInfo.text = t;
			}
		}
		else if (mode == 1)
		{
			var t = (slot() == "bf" ? "Jogador" : (slot() == "gf" ? "GF" : "Oponente")) + "  —  " + slotCharId();
			if (charTitle.text != t)
				charTitle.text = t;
			var i = ed.doc.hasOverride(slotCharId()) ? "A posição vale só para " + slotCharId() + " neste stage." : "A posição vale para qualquer personagem neste slot.";
			if (charInfo.text != i)
				charInfo.text = i;
		}
		super.update(elapsed);
	}
}
