package editor.stage;

import core.Chart.NoteData;
import core.Paths;
import editor.stage.StageDoc.SObj;
import editor.ui.EdUI;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import game.Character;
import game.StageTimeline;

using StringTools;

/**
 * Viewport do Stage Editor: câmera própria, objetos do cenário e personagens reais.
 *  - edição: tudo com scrollFactor 1 (posições reais); clique seleciona, arrasta move, cantos redimensionam;
 *  - testar câmera: usa o scrollFactor real e o zoom do jogo, com foco num personagem (parallax de verdade).
 */
class StageView extends FlxGroup
{
	public static var idBf:String = "bf";
	public static var idDad:String = "dad";
	public static var idGf:String = "gf";

	static inline var HANDLE:Float = 11; // em pixels de tela

	public var doc:StageDoc;
	public var sel:String = "";
	public var testCam:Bool = false;
	public var tlBeat:Float = 0; // beat em que a timeline é avaliada
	public var tlOn(default, set):Bool = false;
	var tline:StageTimeline = new StageTimeline();
	var tlVer:Int = -1;

	function set_tlOn(v:Bool):Bool
	{
		if (tlOn && !v)
		{
			for (k in keys.keys()) // força recriar os sprites para voltar às imagens originais
				keys.set(k, "");
			tline.forget();
		}
		return tlOn = v;
	}
	public var focus:String = "bf";
	public var showFrame:Bool = true;
	public var animate:Bool = false;
	public var songPlaying:Bool = false; // com música tocando, quem manda nas danças é o beat do chart

	var cam:FlxCamera;
	var vx:Float;
	var vy:Float;
	var vw:Float;
	var vh:Float;
	var world:FlxGroup;
	var overlay:FlxGroup;
	var sprites:Map<String, FlxSprite> = new Map();
	var keys:Map<String, String> = new Map();
	var chars:Map<String, Character> = new Map();
	var charKey:String = "";
	var orderKey:String = "";
	var release:Map<Character, Float> = new Map();
	var clock:Float = 0;
	var beatT:Float = 0;

	// câmera de edição
	var panX:Float = 640;
	var panY:Float = 360;
	var zoomV:Float = 0.5;
	var curCx:Float = 640;
	var curCy:Float = 360;
	var curZoom:Float = 0.5;

	// arrasto
	var drag:Int = 0; // 0 nada, 1 mover, 2 redimensionar, 3 pan
	var dragCorner:Int = 0;
	var gx:Float = 0; // posição do mouse (mundo) ao começar
	var gy:Float = 0;
	var startX:Float = 0;
	var startY:Float = 0;
	var startScale:Float = 1;
	var startW:Float = 1;
	var startH:Float = 1;
	var anchorX:Float = 0;
	var anchorY:Float = 0;
	var lastMx:Float = 0;
	var lastMy:Float = 0;
	var hover:String = "";
	var placing:String = ""; // imagem recém-importada: segue o mouse até o clique

	var lines:Array<FlxSprite> = [];
	var handles:Array<FlxSprite> = [];
	var frameLines:Array<FlxSprite> = [];
	var hoverLines:Array<FlxSprite> = [];
	var axes:Array<FlxSprite> = [];

	public function new(doc:StageDoc, x:Float, y:Float, w:Float, h:Float)
	{
		super();
		this.doc = doc;
		vx = x;
		vy = y;
		vw = w;
		vh = h;
		cam = new FlxCamera(Std.int(x), Std.int(y), Std.int(w), Std.int(h));
		cam.bgColor = 0xFF0F131A;
		cam.zoom = 0.5;
		FlxG.cameras.add(cam, false);
		world = new FlxGroup();
		overlay = new FlxGroup();
		for (_ in 0...4)
			lines.push(mk(overlay));
		for (_ in 0...4)
			handles.push(mk(overlay));
		for (_ in 0...4)
			frameLines.push(mk(overlay));
		for (_ in 0...4)
			hoverLines.push(mk(overlay));
		for (_ in 0...2)
			axes.push(mk(overlay));
		add(world);
		add(overlay);
		world.cameras = [cam];
		overlay.cameras = [cam];
		fitAll();
	}

	function mk(g:FlxGroup):FlxSprite
	{
		var s = new FlxSprite();
		s.makeGraphic(1, 1, FlxColor.WHITE);
		s.origin.set(0, 0);
		g.add(s);
		return s;
	}

	/** Redimensiona o viewport (painel lateral recolhido/aberto). */
	public function resize(w:Float, h:Float):Void
	{
		vw = w;
		vh = h;
		cam.setSize(Std.int(w), Std.int(h));
	}

	public function fitAll():Void
	{
		panX = 640;
		panY = 380;
		zoomV = Math.min(vw / 1500, vh / 900);
	}

	// ------------------------------------------------------------------ conversões

	inline function toWx(mx:Float):Float
		return (mx - vx - vw / 2) / cam.zoom + cam.scroll.x + vw / 2;

	inline function toWy(my:Float):Float
		return (my - vy - vh / 2) / cam.zoom + cam.scroll.y + vh / 2;

	public function inside(mx:Float, my:Float):Bool
		return mx >= vx && mx < vx + vw && my >= vy && my < vy + vh;

	public function centerOfView():Array<Float>
		return [Math.round(curCx), Math.round(curCy)];

	// ------------------------------------------------------------------ construção

	static function tint(hex:String):FlxColor
	{
		if (hex == "")
			return FlxColor.WHITE;
		var c = FlxColor.fromString("#" + hex.replace("#", ""));
		return c == null ? FlxColor.WHITE : c;
	}

	function makeSprite(o:SObj):FlxSprite
	{
		var s = new FlxSprite();
		var ok = false;
		if (o.animated)
		{
			var f = Paths.sparrow("images/" + o.image);
			if (f != null)
			{
				s.frames = f;
				if (o.idle != "")
				{
					s.animation.addByPrefix("idle", o.idle, 24, true);
					s.animation.play("idle");
				}
				ok = true;
			}
		}
		else
		{
			var g = Paths.graphic("images/" + o.image + ".png");
			if (g != null)
			{
				s.loadGraphic(g);
				ok = true;
			}
		}
		if (!ok) // imagem não achada: placeholder selecionável
			s.makeGraphic(240, 140, 0x66FF4D8D);
		return s;
	}

	function charPos(slot:String):Array<Float>
	{
		var id = slot == "bf" ? idBf : (slot == "dad" ? idDad : idGf);
		return doc.positionOf(slot, id);
	}

	function slotId(slot:String):String
		return slot == "bf" ? idBf : (slot == "dad" ? idDad : idGf);

	function makeChar(slot:String):Character
	{
		var p = charPos(slot);
		var id = slotId(slot);
		var c:Character;
		try
			c = new Character(p[0], p[1], id, slot == "bf")
		catch (e:Dynamic)
		{
			trace('[StageView] falha ao carregar "$id": $e');
			c = new Character(p[0], p[1], "bf", slot == "bf");
		}
		c.holdingKeys = true;
		return c;
	}

	public function charFor(slot:String):Null<Character>
		return chars.get(slot);

	// ------------------------------------------------------------------ poses de teste

	public function pose(slot:String, name:String):Bool
	{
		var c = chars.get(slot);
		if (c == null)
			return false;
		var ok = true;
		switch (name)
		{
			case "IDLE":
				c.specialAnim = false;
				c.dance();
			case "HEY":
				ok = c.hasAnim("hey");
				c.playAnim("hey", true);
				c.specialAnim = ok;
			default:
				var lane = ["ESQ", "BAI", "CIM", "DIR"].indexOf(name);
				if (lane >= 0)
				{
					ok = c.hasAnim("sing" + Character.DIRS[lane]);
					c.specialAnim = false;
					c.sing(lane, false);
					release.set(c, clock + 0.6);
				}
		}
		return ok;
	}

	// ------------------------------------------------------------------ reação à música

	/** Uma nota do chart foi tocada: o personagem do lado dela canta. step = duração de um passo em segundos. */
	public function noteHit(n:NoteData, alt:Bool, step:Float):Void
	{
		var c = chars.get(n.player ? "bf" : "dad");
		if (c == null)
			return;
		c.specialAnim = false;
		c.sing(n.lane, alt);
		release.set(c, clock + n.sustain / 1000 + step * Math.max(2, c.singDuration));
	}

	public function beat(b:Int):Void
	{
		for (c in chars)
			if (b % Std.int(Math.max(1, c.danceEvery)) == 0 && !c.isSinging() && !c.specialAnim)
				c.dance();
	}

	// ------------------------------------------------------------------ sincronização com o documento

	function relayer():Void
	{
		world.clear();
		var f = doc.flat();
		var gfHidden = idDad == idGf;
		for (id in f)
		{
			if (id.startsWith("@"))
			{
				var c = chars.get(id.substr(1));
				if (c != null)
					world.add(c);
			}
			else if (sprites.exists(id))
				world.add(sprites.get(id));
		}
		var g = chars.get("gf");
		if (g != null)
			g.visible = !gfHidden;
		orderKey = f.join("|");
	}

	function syncObjects():Void
	{
		var live:Map<String, Bool> = new Map();
		var changed = false;
		for (o in doc.objs)
		{
			live.set(o.id, true);
			var k = o.image + "|" + o.animated + "|" + o.idle;
			if (!sprites.exists(o.id) || keys.get(o.id) != k)
			{
				var old = sprites.get(o.id);
				if (old != null)
					old.destroy();
				sprites.set(o.id, makeSprite(o));
				keys.set(o.id, k);
				changed = true;
			}
			var s = sprites.get(o.id);
			s.scale.set(o.scale, o.scale);
			s.updateHitbox();
			s.setPosition(o.x, o.y);
			s.visible = o.visible;
			s.alpha = o.alpha;
			s.color = tint(o.color);
			s.angle = o.angle;
			s.flipX = o.flipX;
			s.antialiasing = o.aa;
			s.scrollFactor.set(testCam ? o.sx : 1, testCam ? o.sy : 1);
		}
		for (id in sprites.keys())
			if (!live.exists(id))
			{
				sprites.get(id).destroy();
				sprites.remove(id);
				keys.remove(id);
				changed = true;
			}
		if (changed || orderKey != doc.flat().join("|"))
			relayer();
	}

	function syncChars():Void
	{
		var k = idBf + "|" + idDad + "|" + idGf;
		if (k != charKey)
		{
			charKey = k;
			for (c in chars)
				c.destroy();
			chars = new Map();
			release = new Map();
			for (slot in ["gf", "dad", "bf"])
				chars.set(slot, makeChar(slot));
			relayer();
		}
		for (slot in ["gf", "dad", "bf"])
		{
			var c = chars.get(slot);
			var p = charPos(slot);
			c.setPosition(p[0], p[1]);
		}
		if (chars.get("gf") != null)
			chars.get("gf").visible = idDad != idGf;
	}

	// ------------------------------------------------------------------ mouse

	function boundsOf(id:String):Null<Array<Float>>
	{
		if (id.startsWith("@"))
		{
			var c = chars.get(id.substr(1));
			if (c == null || !c.visible)
				return null;
			// retângulo do que se VÊ (o hitbox do personagem muda com a animação e pode ser minúsculo)
			var w = c.frameWidth * Math.abs(c.scale.x);
			var h = c.frameHeight * Math.abs(c.scale.y);
			if (w < 8 || h < 8)
			{
				w = Math.max(w, 150);
				h = Math.max(h, 300);
			}
			var cx = c.x - c.offset.x + (c.frameWidth - w) / 2;
			var cy = c.y - c.offset.y + (c.frameHeight - h) / 2;
			return [cx, cy, w, h];
		}
		var s = sprites.get(id);
		return s == null ? null : [s.x, s.y, s.width, s.height];
	}

	public function hit(wx:Float, wy:Float):String
	{
		var f = doc.flat();
		var i = f.length - 1;
		while (i >= 0)
		{
			var id = f[i--];
			if (!id.startsWith("@"))
			{
				var o = doc.byId(id);
				if (o == null || !o.visible || o.locked)
					continue;
			}
			var b = boundsOf(id);
			if (b != null && wx >= b[0] && wx <= b[0] + b[2] && wy >= b[1] && wy <= b[1] + b[3])
				return id;
		}
		return "";
	}

	/** Canto sob o mouse (0 = TL, 1 = TR, 2 = BL, 3 = BR) ou -1. */
	function cornerAt(wx:Float, wy:Float):Int
	{
		if (sel == "" || sel.startsWith("@"))
			return -1;
		var b = boundsOf(sel);
		if (b == null)
			return -1;
		var r = HANDLE / cam.zoom;
		var cs = [[b[0], b[1]], [b[0] + b[2], b[1]], [b[0], b[1] + b[3]], [b[0] + b[2], b[1] + b[3]]];
		for (i in 0...4)
			if (Math.abs(wx - cs[i][0]) <= r && Math.abs(wy - cs[i][1]) <= r)
				return i;
		return -1;
	}

	/** A camada passa a seguir o mouse; o próximo clique no palco a coloca no lugar. */
	public function startPlacing(id:String):Void
	{
		sel = id;
		placing = id;
		doc.begin();
	}

	function mouse(allow:Bool):Void
	{
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		var wx = toWx(mx);
		var wy = toWy(my);
		var inVp = inside(mx, my) && allow;

		if (placing != "")
		{
			var po = doc.byId(placing);
			var ps = sprites.get(placing);
			if (po == null || FlxG.keys.justPressed.ESCAPE)
			{
				doc.end("posicionar imagem");
				placing = "";
			}
			else
			{
				if (ps != null && inside(mx, my))
				{
					po.x = Math.round(wx - ps.width / 2);
					po.y = Math.round(wy - ps.height / 2);
				}
				if (inVp && FlxG.mouse.justPressed)
				{
					doc.end("posicionar imagem");
					placing = "";
				}
			}
			return;
		}

		// pan: botão do meio, direito, ou ESPAÇO + esquerdo
		var panBtn = FlxG.mouse.pressedMiddle || FlxG.mouse.pressedRight || (FlxG.keys.pressed.SPACE && FlxG.mouse.pressed);
		if (drag == 3)
		{
			if (!panBtn)
				drag = 0;
			else if (!testCam)
			{
				panX -= (mx - lastMx) / cam.zoom;
				panY -= (my - lastMy) / cam.zoom;
			}
		}
		else if (drag == 0 && inVp && panBtn && (FlxG.mouse.justPressedMiddle || FlxG.mouse.justPressedRight || FlxG.mouse.justPressed))
			drag = 3;

		// zoom com a roda (em torno do ponto sob o mouse)
		if (inVp && FlxG.mouse.wheel != 0 && !testCam)
		{
			var f = FlxG.mouse.wheel > 0 ? 1.12 : 1 / 1.12;
			var nz = Math.max(0.05, Math.min(4, zoomV * f));
			panX = wx + (panX - wx) * (zoomV / nz);
			panY = wy + (panY - wy) * (zoomV / nz);
			zoomV = nz;
		}
		lastMx = mx;
		lastMy = my;

		hover = "";
		if (inVp && drag == 0 && !testCam)
		{
			hover = hit(wx, wy);
			if (FlxG.mouse.justPressed && !panBtn)
			{
				var c = cornerAt(wx, wy);
				if (c >= 0)
					beginResize(c, wx, wy);
				else
				{
					sel = hover;
					if (sel != "")
						beginMove(wx, wy);
				}
			}
		}

		if (drag == 1)
		{
			if (!FlxG.mouse.pressed)
				endDrag("mover");
			else
			{
				var nx = startX + (wx - gx);
				var ny = startY + (wy - gy);
				if (FlxG.keys.pressed.SHIFT)
				{
					nx = Math.round(nx / 10) * 10;
					ny = Math.round(ny / 10) * 10;
				}
				setPos(Math.round(nx), Math.round(ny));
			}
		}
		else if (drag == 2)
		{
			if (!FlxG.mouse.pressed)
				endDrag("redimensionar");
			else
				doResize(wx, wy);
		}
	}

	function beginMove(wx:Float, wy:Float):Void
	{
		doc.begin();
		drag = 1;
		gx = wx;
		gy = wy;
		var p = posOf(sel);
		startX = p[0];
		startY = p[1];
	}

	function beginResize(corner:Int, wx:Float, wy:Float):Void
	{
		var o = doc.byId(sel);
		var b = boundsOf(sel);
		if (o == null || b == null)
			return;
		doc.begin();
		drag = 2;
		dragCorner = corner;
		startScale = o.scale;
		startW = Math.max(1, b[2]);
		startH = Math.max(1, b[3]);
		// âncora = canto oposto
		anchorX = (corner == 0 || corner == 2) ? b[0] + b[2] : b[0];
		anchorY = (corner == 0 || corner == 1) ? b[1] + b[3] : b[1];
	}

	function doResize(wx:Float, wy:Float):Void
	{
		var o = doc.byId(sel);
		if (o == null)
			return;
		var left = (dragCorner == 0 || dragCorner == 2);
		var top = (dragCorner == 0 || dragCorner == 1);
		var w = Math.max(4, left ? anchorX - wx : wx - anchorX);
		var ns = Math.max(0.02, startScale * w / startW);
		if (FlxG.keys.pressed.SHIFT)
			ns = Math.round(ns * 20) / 20;
		var nw = startW * ns / startScale;
		var nh = startH * ns / startScale;
		o.scale = ns;
		o.x = Math.round(left ? anchorX - nw : anchorX);
		o.y = Math.round(top ? anchorY - nh : anchorY);
	}

	function endDrag(label:String):Void
	{
		doc.end(label);
		drag = 0;
	}

	function posOf(id:String):Array<Float>
	{
		if (id.startsWith("@"))
		{
			var slot = id.substr(1);
			return charPos(slot);
		}
		var o = doc.byId(id);
		return o == null ? [0, 0] : [o.x, o.y];
	}

	function setPos(x:Float, y:Float):Void
	{
		if (sel.startsWith("@"))
		{
			var slot = sel.substr(1);
			doc.setPosition(slot, slotId(slot), x, y);
		}
		else
		{
			var o = doc.byId(sel);
			if (o != null)
			{
				o.x = x;
				o.y = y;
			}
		}
	}

	/** Setas do teclado. */
	public function nudge(dx:Float, dy:Float):Void
	{
		if (sel == "" || testCam)
			return;
		var p = posOf(sel);
		doc.begin();
		setPos(p[0] + dx, p[1] + dy);
		doc.end("mover");
	}

	// ------------------------------------------------------------------ câmera e overlay

	function focusPoint():Array<Float>
	{
		var c = chars.get(focus);
		if (c == null)
			return [640, 360];
		var mp = c.getMidpoint();
		var off = (focus == "bf" && doc.camBf != null) ? doc.camBf : c.camOffset;
		var r = [mp.x + off[0], mp.y + off[1]];
		mp.put();
		return r;
	}

	function line(s:FlxSprite, x:Float, y:Float, w:Float, h:Float, color:FlxColor, a:Float):Void
	{
		s.visible = true;
		s.setPosition(x, y);
		s.scale.set(w, h);
		s.color = color;
		s.alpha = a;
	}

	function box(ls:Array<FlxSprite>, x:Float, y:Float, w:Float, h:Float, t:Float, color:FlxColor, a:Float):Void
	{
		line(ls[0], x, y, w, t, color, a);
		line(ls[1], x, y + h - t, w, t, color, a);
		line(ls[2], x, y, t, h, color, a);
		line(ls[3], x + w - t, y, t, h, color, a);
	}

	function updateCamera(dt:Float):Void
	{
		var tz:Float;
		var cx:Float;
		var cy:Float;
		if (testCam)
		{
			var fp = focusPoint();
			cx = fp[0];
			cy = fp[1];
			tz = doc.zoom * Math.min(vw / 1280, vh / 720);
		}
		else
		{
			cx = panX;
			cy = panY;
			tz = zoomV;
		}
		var k = (testCam || drag == 3) ? 6.0 : 30.0;
		curCx = EdTheme.lerpf(curCx, cx, dt, k);
		curCy = EdTheme.lerpf(curCy, cy, dt, k);
		curZoom = EdTheme.lerpf(curZoom, tz, dt, testCam ? 6 : 30);
		cam.zoom = curZoom;
		cam.scroll.set(curCx - vw / 2, curCy - vh / 2);
	}

	function updateOverlay():Void
	{
		var px = 1 / cam.zoom; // 1 pixel de tela em unidades do mundo
		// eixos da origem
		line(axes[0], -5000, 0, 10000, px, 0xFF2B3442, 1);
		line(axes[1], 0, -5000, px, 10000, 0xFF2B3442, 1);
		for (a in axes)
			a.visible = !testCam;

		// seleção
		var b = (sel == "" || testCam) ? null : boundsOf(sel);
		for (l in lines)
			l.visible = b != null;
		for (h in handles)
			h.visible = b != null && !sel.startsWith("@");
		if (b != null)
		{
			box(lines, b[0], b[1], b[2], b[3], 2 * px, EdTheme.ACCENT, 0.95);
			if (!sel.startsWith("@"))
			{
				var hs = HANDLE * px;
				var cs = [[b[0], b[1]], [b[0] + b[2], b[1]], [b[0], b[1] + b[3]], [b[0] + b[2], b[1] + b[3]]];
				for (i in 0...4)
					line(handles[i], cs[i][0] - hs / 2, cs[i][1] - hs / 2, hs, hs, 0xFFFFFFFF, 1);
			}
		}

		// contorno do que está sob o mouse (mesmo com outra peça selecionada)
		var hb = (hover != "" && hover != sel && drag == 0 && !testCam) ? boundsOf(hover) : null;
		for (l in hoverLines)
			l.visible = hb != null;
		if (hb != null)
			box(hoverLines, hb[0], hb[1], hb[2], hb[3], 2 * px, EdTheme.CYAN, 0.9);

		// moldura da câmera do jogo no ponto de foco
		var showF = showFrame && !testCam;
		for (f in frameLines)
			f.visible = showF;
		if (showF)
		{
			var fp = focusPoint();
			var fw = 1280 / doc.zoom;
			var fh = 720 / doc.zoom;
			box(frameLines, fp[0] - fw / 2, fp[1] - fh / 2, fw, fh, 2 * px, EdTheme.CYAN, 0.55);
		}
	}

	override public function update(elapsed:Float):Void
	{
		clock += elapsed;
		syncChars();
		syncObjects();
		if (tlOn && placing == "")
		{
			if (tlVer != doc.version)
			{
				tlVer = doc.version;
				tline.setEvents(doc.tl);
			}
			tline.apply(tlBeat, sprites, function(id) {
				var o = doc.byId(id);
				if (o == null)
					return null;
				return {
					x: o.x,
					y: o.y,
					scale: o.scale,
					alpha: o.alpha,
					angle: o.angle,
					color: tint(o.color),
					image: o.image
				};
			});
		}
		mouse(!EdLock.locked && !TextInput.typing());

		// personagens: voltam ao idle depois da pose, e "dançam" no ritmo se pedido
		for (c in chars)
			if (c.isSinging() && !c.specialAnim && release.exists(c) && clock >= release.get(c))
				c.dance();
		if (animate && !songPlaying)
		{
			beatT += elapsed;
			if (beatT >= 0.5)
			{
				beatT = 0;
				for (c in chars)
					if (!c.isSinging() && !c.specialAnim)
						c.dance();
			}
		}

		super.update(elapsed);
		updateCamera(elapsed);
		updateOverlay();
	}

	override public function destroy():Void
	{
		FlxG.cameras.remove(cam);
		super.destroy();
	}
}
