package editor.character;

import editor.character.CharDoc.EAnim;
import editor.ui.EdUI;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import game.Character;
import game.Stage;

using StringTools;

/**
 * Palco do Character Editor. Mostra o MESMO Character do jogo, montado a partir do documento (mesmo sem salvar),
 * opcionalmente dentro de um stage de verdade, na posição de jogador, oponente ou GF.
 * Arrastar com o mouse (ou setas) move o offset da animação atual.
 */
class CharView extends FlxGroup
{
	public var doc:CharDoc;
	public var cam:FlxCamera;
	public var ch:Null<Character>;
	public var curAnim:String = "idle";
	public var slot:String = "dad"; // "bf", "dad" ou "gf" (decide posição no stage e espelhamento do jogador)
	public var stageName(default, set):String = "";
	public var showGhost:Bool = true;
	public var loopPlay:Bool = true;
	public var showCam:Bool = true;
	public var missing:String = ""; // aviso quando o atlas não existe

	var world:FlxGroup;
	var overlay:FlxGroup;
	var stage:Null<Stage>;
	var ghost:Null<Character>;
	var ver:Int = -1;
	var builtKey:String = "";
	var vx:Float;
	var vy:Float;
	var vw:Float;
	var vh:Float;
	var panX:Float = 0;
	var panY:Float = 0;
	var zoomV:Float = 0.6;
	var curCx:Float = 0;
	var curCy:Float = 0;
	var curZoom:Float = 0.6;
	var lastMx:Float = 0;
	var lastMy:Float = 0;
	var panning:Bool = false;
	var dragging:Bool = false;
	var gx:Float = 0;
	var gy:Float = 0;
	var startOx:Float = 0;
	var startOy:Float = 0;
	var axes:Array<FlxSprite> = [];
	var box:Array<FlxSprite> = [];
	var camMark:Array<FlxSprite> = [];
	var originMark:Array<FlxSprite> = [];

	public function new(doc:CharDoc, x:Float, y:Float, w:Float, h:Float)
	{
		super();
		this.doc = doc;
		vx = x;
		vy = y;
		vw = w;
		vh = h;
		cam = new FlxCamera(Std.int(x), Std.int(y), Std.int(w), Std.int(h));
		cam.bgColor = 0xFF0F131A;
		FlxG.cameras.add(cam, false);
		world = new FlxGroup();
		overlay = new FlxGroup();
		for (_ in 0...2)
			axes.push(mk());
		for (_ in 0...4)
			box.push(mk());
		for (_ in 0...2)
			camMark.push(mk());
		for (_ in 0...2)
			originMark.push(mk());
		add(world);
		add(overlay);
		world.cameras = [cam];
		overlay.cameras = [cam];
		var first = doc.animByName("idle");
		curAnim = first != null ? "idle" : (doc.anims.length > 0 ? doc.anims[0].name : "idle");
		fit();
		curCx = panX;
		curCy = panY;
		curZoom = zoomV;
	}

	function mk():FlxSprite
	{
		var s = new FlxSprite();
		s.makeGraphic(1, 1, FlxColor.WHITE);
		s.origin.set(0, 0);
		overlay.add(s);
		return s;
	}

	function set_stageName(v:String):String
	{
		if (v != stageName)
			builtKey = ""; // força remontar
		return stageName = v;
	}

	public function resize(w:Float, h:Float):Void
	{
		vw = w;
		vh = h;
		cam.setSize(Std.int(w), Std.int(h));
	}

	public function fit():Void
	{
		var p = origin();
		if (stage != null)
		{
			panX = p[0] + 100;
			panY = p[1] + 150;
			zoomV = Math.min(vw / 1100, vh / 800);
		}
		else
		{
			panX = p[0] + 150;
			panY = p[1] + 200;
			zoomV = Math.min(vw / 700, vh / 600);
		}
	}

	inline function toWx(mx:Float):Float
		return (mx - vx - vw / 2) / cam.zoom + cam.scroll.x + vw / 2;

	inline function toWy(my:Float):Float
		return (my - vy - vh / 2) / cam.zoom + cam.scroll.y + vh / 2;

	public function inside(mx:Float, my:Float):Bool
		return mx >= vx && mx < vx + vw && my >= vy && my < vy + vh;

	function origin():Array<Float>
		return stage != null ? stage.positionFor(slot, doc.id) : [0.0, 0.0];

	// ------------------------------------------------------------------ montagem

	function remount():Void
	{
		for (m in world.members.copy())
			if (m != null)
			{
				world.remove(m);
				m.destroy();
			}
		ch = null;
		ghost = null;
		stage = null;
		missing = "";
		if (stageName != "")
		{
			try
			{
				stage = new Stage(stageName);
				for (o in stage.objects)
					o.scrollFactor.set(1, 1); // sem parallax: o editor não tem câmera de jogo
				world.add(stage.back);
				world.add(stage.gfLayer);
				world.add(stage.dadLayer);
			}
			catch (e:Dynamic)
			{
				trace('[CharView] stage "$stageName": $e');
				stage = null;
			}
		}
		var p = origin();
		var def = doc.toDef();
		if (core.Paths.sparrow("images/" + doc.asset) == null && !doc.packer)
			missing = "Atlas não encontrado: images/" + doc.asset + ".png/.xml";
		else if (doc.packer && core.Paths.packer("images/" + doc.asset) == null)
			missing = "Atlas não encontrado: images/" + doc.asset + ".png/.txt";
		if (missing == "")
		{
			ghost = new Character(p[0], p[1], doc.id, slot == "bf", def);
			ghost.holdingKeys = true;
			ghost.alpha = 0.4;
			ghost.color = 0xFF9FD8FF;
			world.add(ghost);
			ch = new Character(p[0], p[1], doc.id, slot == "bf", def);
			ch.holdingKeys = true;
			world.add(ch);
		}
		if (stage != null)
			world.add(stage.front);
		builtKey = stageName + "|" + slot;
		play(curAnim, true);
	}

	/** Toca uma animação do documento do começo. */
	public function play(name:String, force:Bool = true):Void
	{
		curAnim = name;
		if (ch != null)
		{
			ch.playAnim(name, force);
			ch.animation.resume();
		}
		updateGhost();
	}

	function updateGhost():Void
	{
		if (ghost == null)
			return;
		var show = showGhost && curAnim != "idle" && ghost.hasAnim("idle");
		ghost.visible = show;
		if (show)
		{
			ghost.playAnim("idle", true);
			ghost.animation.pause();
		}
	}

	public function togglePause():Void
	{
		if (ch == null || ch.animation.curAnim == null)
			return;
		if (ch.animation.paused)
			ch.animation.resume();
		else
			ch.animation.pause();
	}

	public function paused():Bool
		return ch != null && ch.animation.paused;

	public function stepFrame(d:Int):Void
	{
		if (ch == null || ch.animation.curAnim == null)
			return;
		ch.animation.pause();
		var a = ch.animation.curAnim;
		var n = a.numFrames;
		a.curFrame = Std.int((a.curFrame + d + n) % n);
	}

	public function frameInfo():String
	{
		if (ch == null || ch.animation.curAnim == null)
			return "-";
		var a = ch.animation.curAnim;
		return (a.curFrame + 1) + " / " + a.numFrames;
	}

	/** Valores novos de offset (usados por steppers e pelo arrasto) aplicados sem remontar. */
	function liveOffset(a:EAnim):Void
	{
		if (ch == null)
			return;
		ch.offsets.set(a.name, [a.ox, a.oy]);
		if (ch.animation.curAnim != null && ch.animation.curAnim.name == a.name)
			ch.offset.set(a.ox, a.oy);
	}

	// ------------------------------------------------------------------ mouse

	function mouse(allow:Bool):Void
	{
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		var wx = toWx(mx);
		var wy = toWy(my);
		var inVp = inside(mx, my) && allow;

		var panBtn = FlxG.mouse.pressedMiddle || FlxG.mouse.pressedRight || (FlxG.keys.pressed.SPACE && FlxG.mouse.pressed);
		if (panning)
		{
			if (!panBtn)
				panning = false;
			else
			{
				panX -= (mx - lastMx) / cam.zoom;
				panY -= (my - lastMy) / cam.zoom;
			}
		}
		else if (!dragging && inVp && panBtn && (FlxG.mouse.justPressedMiddle || FlxG.mouse.justPressedRight || FlxG.mouse.justPressed))
			panning = true;

		if (inVp && FlxG.mouse.wheel != 0)
		{
			var f = FlxG.mouse.wheel > 0 ? 1.12 : 1 / 1.12;
			var nz = Math.max(0.1, Math.min(4, zoomV * f));
			panX = wx + (panX - wx) * (zoomV / nz);
			panY = wy + (panY - wy) * (zoomV / nz);
			zoomV = nz;
		}
		lastMx = mx;
		lastMy = my;

		var a = doc.animByName(curAnim);
		if (!dragging && !panning && inVp && FlxG.mouse.justPressed && !panBtn && a != null && ch != null)
		{
			doc.begin();
			dragging = true;
			gx = wx;
			gy = wy;
			startOx = a.ox;
			startOy = a.oy;
		}
		if (dragging)
		{
			if (!FlxG.mouse.pressed || a == null)
			{
				dragging = false;
				doc.end("mover offset");
			}
			else
			{
				var nx = startOx - (wx - gx); // arrastar o desenho para a direita = offset.x diminui
				var ny = startOy - (wy - gy);
				if (FlxG.keys.pressed.SHIFT)
				{
					nx = Math.round(nx / 10) * 10;
					ny = Math.round(ny / 10) * 10;
				}
				a.ox = Math.round(nx);
				a.oy = Math.round(ny);
				liveOffset(a);
			}
		}
	}

	/** Setas: move o desenho 1 px (SHIFT = 10) mudando o offset da animação atual. */
	public function nudge(dx:Float, dy:Float):Void
	{
		var a = doc.animByName(curAnim);
		if (a == null)
			return;
		doc.edit("ajustar offset", function() {
			a.ox -= dx;
			a.oy -= dy;
		});
	}

	// ------------------------------------------------------------------ loop

	function line(s:FlxSprite, x:Float, y:Float, w:Float, h:Float, color:FlxColor, al:Float):Void
	{
		s.visible = true;
		s.setPosition(x, y);
		s.scale.set(w, h);
		s.color = color;
		s.alpha = al;
	}

	function updateOverlay():Void
	{
		var px = 1 / cam.zoom;
		var o = origin();
		line(axes[0], o[0] - 3000, o[1], 6000, px, 0xFF2B3442, 1);
		line(axes[1], o[0], o[1] - 3000, px, 6000, 0xFF2B3442, 1);
		// contorno do que se vê
		if (ch != null)
		{
			var w = ch.frameWidth * Math.abs(ch.scale.x);
			var h = ch.frameHeight * Math.abs(ch.scale.y);
			var bx = ch.x - ch.offset.x + (ch.frameWidth - w) / 2;
			var by = ch.y - ch.offset.y + (ch.frameHeight - h) / 2;
			line(box[0], bx, by, w, px, EdTheme.CYAN, 0.6);
			line(box[1], bx, by + h - px, w, px, EdTheme.CYAN, 0.6);
			line(box[2], bx, by, px, h, EdTheme.CYAN, 0.6);
			line(box[3], bx + w - px, by, px, h, EdTheme.CYAN, 0.6);
			// ponto de foco da câmera do jogo
			var mp = ch.getMidpoint();
			var cx = mp.x + doc.camX;
			var cy = mp.y + doc.camY;
			mp.put();
			var s = 14 * px;
			line(camMark[0], cx - s, cy - px, 2 * s, 2 * px, EdTheme.ACCENT, 1);
			line(camMark[1], cx - px, cy - s, 2 * px, 2 * s, EdTheme.ACCENT, 1);
			for (m in camMark)
				m.visible = showCam;
		}
		else
			for (l in box.concat(camMark))
				l.visible = false;
		// âncora (posição x,y do personagem no stage)
		var t = 8 * px;
		line(originMark[0], o[0] - t, o[1] - px, 2 * t, 2 * px, 0xFFFFFFFF, 0.9);
		line(originMark[1], o[0] - px, o[1] - t, 2 * px, 2 * t, 0xFFFFFFFF, 0.9);
	}

	override public function update(elapsed:Float):Void
	{
		if (ver != doc.version || builtKey != stageName + "|" + slot)
		{
			ver = doc.version;
			remount();
		}
		if (ghost != null)
			ghost.visible = ghost.visible && showGhost;
		mouse(!EdLock.locked && !TextInput.typing());

		// repetição da animação em loop (as de canto não repetem sozinhas)
		if (ch != null && loopPlay && !ch.animation.paused && ch.animation.curAnim != null && ch.animation.curAnim.finished)
			ch.animation.curAnim.restart();

		super.update(elapsed);

		var o = origin();
		var k = dragging || panning ? 6.0 : 30.0;
		curCx = EdTheme.lerpf(curCx, panX, elapsed, k);
		curCy = EdTheme.lerpf(curCy, panY, elapsed, k);
		curZoom = EdTheme.lerpf(curZoom, zoomV, elapsed, 30);
		cam.zoom = curZoom;
		cam.scroll.set(curCx - vw / 2, curCy - vh / 2);
		updateOverlay();
	}

	override public function destroy():Void
	{
		FlxG.cameras.remove(cam);
		super.destroy();
	}
}
