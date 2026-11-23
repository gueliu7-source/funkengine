package editor.character;

import core.Paths;
import editor.CharEditorState;
import editor.ui.EdUI;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;

using StringTools;

/** Aba PERSONAGEM: atlas, escala, espelhamento, ritmo de dança, cor da barra, ícone e câmera. */
class CharTab extends FlxSpriteGroup
{
	var ed:CharEditorState;

	public function new(ed:CharEditorState)
	{
		super();
		this.ed = ed;
		var x = EdTheme.SIDE_X + 16;
		var w = EdTheme.SIDE_W - 32;
		var d = ed.doc;

		add(EdTheme.text(x, 124, w, 12, "ID (nome do arquivo data/characters/<id>.json)", EdTheme.DIM));
		add(new TextInput(x, 140, w, function() return ed.doc.id, function(v) {
			var nv = v.trim().replace(" ", "_");
			if (nv != "" && nv != ed.doc.id)
			{
				ed.doc.id = nv;
				ed.doc.dirty = true;
				ed.doc.version++;
			}
		}));
		add(new Selector(x, 176, w, "Atlas", function() return ed.assets(), function() return ed.doc.asset, function(v) ed.doc.edit("atlas", function() {
			ed.doc.asset = v;
			ed.doc.packer = !Paths.exists("images/" + v + ".xml") && Paths.exists("images/" + v + ".txt");
		}), 52));
		add(new Btn(x, 210, w, 28, "IMPORTAR ATLAS (PNG + XML) DO COMPUTADOR...", function() ed.importAtlas(), 1, null, 12));
		add(new Stepper(x, 250, w, "Escala", function() return ed.doc.scale, function(v) ed.doc.edit("escala", function() ed.doc.scale = v), 0.05, 0.1, 10, 2));
		add(new Toggle(x, 280, w, "Espelhar (flipX)", function() return ed.doc.flipX, function(v) ed.doc.edit("flipX", function() ed.doc.flipX = v)));
		add(new Toggle(x, 308, w, "Trocar ← → quando é o jogador", function() return ed.doc.swapSides, function(v) ed.doc.edit("swapSides", function() ed.doc.swapSides = v)));
		add(new Toggle(x, 336, w, "Suavizar (antialiasing)", function() return ed.doc.aa, function(v) ed.doc.edit("antialiasing", function() ed.doc.aa = v)));
		add(new Toggle(x, 364, w, "Dança esquerda/direita (danceLeft/Right)", function() return ed.doc.danceLR, function(v) ed.doc.edit("danceLR", function() ed.doc.danceLR = v)));
		add(new Stepper(x, 396, w, "Duração do canto (steps)", function() return ed.doc.singDuration, function(v) ed.doc.edit("singDuration", function() ed.doc.singDuration = v), 0.5, 0.5, 20, 1));
		add(new Stepper(x, 424, w, "Dança a cada (beats)", function() return ed.doc.danceEvery, function(v) ed.doc.edit("danceEvery", function() ed.doc.danceEvery = Std.int(v)), 1, 1, 8, 0));
		add(EdTheme.text(x, 458, w, 12, "COR DA BARRA DE VIDA (hex, ex.: #31B0D1)", EdTheme.DIM));
		add(new TextInput(x, 474, w - 40, function() return ed.doc.barColor, function(v) ed.doc.edit("cor da barra", function() ed.doc.barColor = v.trim())));
		var sw = EdTheme.round(x + w - 30, 474, 30, 26, 8);
		sw.active = true;
		add(sw);
		swatch = sw;
		add(new Selector(x, 512, w, "Ícone", function() return ed.icons(), function() return ed.doc.icon, function(v) ed.doc.edit("ícone", function() ed.doc.icon = v), 52));
		add(new Stepper(x, 546, w, "Câmera X", function() return ed.doc.camX, function(v) ed.doc.edit("câmera", function() ed.doc.camX = v), 10, -2000, 2000, 0));
		add(new Stepper(x, 574, w, "Câmera Y", function() return ed.doc.camY, function(v) ed.doc.edit("câmera", function() ed.doc.camY = v), 10, -2000, 2000, 0));
		add(EdTheme.text(x, 610, w, 12, "Câmera = deslocamento do foco a partir do meio do personagem (a cruz laranja no palco).", EdTheme.DIM));
	}

	var swatch:flixel.FlxSprite;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var c = FlxColor.fromString(ed.doc.barColor);
		swatch.color = c != null ? c : EdTheme.LINE;
	}
}
