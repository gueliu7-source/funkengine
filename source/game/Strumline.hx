package game;

import core.Chart.NoteData;
import core.Settings;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.group.FlxGroup;

/**
 * Um lado do jogo (jogador ou oponente): 4 receptores + as notas dele.
 * Só cria sprites para notas que estão perto da tela e devolve ao pool quando saem.
 */
@:keep
class Strumline extends FlxGroup
{
	public var isPlayer:Bool;
	public var receptors:Array<Receptor> = [];
	public var activeNotes:Array<NoteData> = []; // notas na tela, em ordem de tempo
	public var hidden:Bool;
	public var downscroll:Bool;
	public var cam:FlxCamera;
	public var onSpawn:NoteData->Void; // chamado quando a nota entra na tela (onSpawnNote dos scripts Psych)

	var pending:Array<NoteData>;
	var pendingIdx:Int = 0;

	var sustainLayer:FlxGroup = new FlxGroup();
	var headLayer:FlxGroup = new FlxGroup();
	var free:Map<Int, Array<NoteSprite>> = new Map();

	var baseSpeed:Float = 1;
	var rate:Float = 1;
	var spawnMs:Float;
	var strumY:Float;

	public function new(isPlayer:Bool, notes:Array<NoteData>, centerX:Float, strumY:Float, speed:Float, rate:Float, hidden:Bool, cam:FlxCamera)
	{
		super();
		this.cam = cam;
		this.isPlayer = isPlayer;
		this.hidden = hidden;
		this.strumY = strumY;
		this.downscroll = Settings.d.downscroll;
		pending = notes;
		setSpeed(speed, rate);

		for (i in 0...4)
		{
			var r = new Receptor(i, centerX + (i - 1.5) * NoteSkin.SIZE, strumY);
			r.visible = !hidden;
			r.cameras = [cam];
			receptors.push(r);
			add(r);
		}
		add(sustainLayer);
		add(headLayer);
	}

	public function setSpeed(speed:Float, rate:Float):Void
	{
		baseSpeed = speed;
		this.rate = rate;
		recalc();
	}

	/** Velocidade (do chart) de uma nota: a da nota, senão a da lane, senão a do jogo. O modo "fixa" vale para todas. */
	public function speedOf(n:NoteData):Float
	{
		if (Settings.d.scrollMode != 1)
		{
			if (n.scrollSpeed != null)
				return n.scrollSpeed;
			if (receptors.length > n.lane && receptors[n.lane].scrollSpeed != null)
				return receptors[n.lane].scrollSpeed;
		}
		return baseSpeed;
	}

	/** px por ms de uma nota (0,45 × velocidade, como no Codename/Kade). */
	public inline function pxOf(n:NoteData):Float
		return 0.45 * speedOf(n) / rate;

	/** Define a velocidade de uma lane (null volta à do jogo). */
	public function setLaneSpeed(lane:Int, v:Null<Float>):Void
	{
		if (lane >= 0 && lane < receptors.length)
			receptors[lane].scrollSpeed = v;
		recalc();
	}

	/** Janela de spawn: a mais lenta das velocidades em uso decide quanto tempo antes a nota precisa existir. */
	function recalc():Void
	{
		var slow = baseSpeed;
		if (Settings.d.scrollMode != 1)
			for (r in receptors)
				if (r.scrollSpeed != null && r.scrollSpeed < slow)
					slow = r.scrollSpeed;
		spawnMs = (FlxG.height + 160) / (0.45 * Math.max(0.05, slow) / rate);
	}

	/** Cria os sprites das notas que entram na janela de tela e posiciona todas. */
	public function updateNotes(songPos:Float):Void
	{
		while (pendingIdx < pending.length && pending[pendingIdx].time - songPos < spawnMs)
			spawn(pending[pendingIdx++]);

		var i = activeNotes.length;
		while (--i >= 0)
		{
			var n = activeNotes[i];
			if (!n.done && songPos - (n.time + n.sustain) > spawnMs)
				n.done = true; // saiu da tela por trás
			if (n.done)
			{
				release(n);
				activeNotes.splice(i, 1);
			}
			else if (!hidden)
				place(n, songPos);
		}
	}

	function spawn(n:NoteData):Void
	{
		n.spawned = true;
		if (onSpawn != null)
			onSpawn(n);
		if (!hidden)
		{
			n.head = null;
			if (n.texture != "")
			{
				var cs = NoteSprite.withTexture(n.texture, n.lane, n.scaleX, n.scaleY);
				if (cs != null)
				{
					cs.cameras = [cam];
					headLayer.add(cs);
					n.head = cs;
				}
			}
			if (n.head == null)
				n.head = acquire(0, n.lane, headLayer);
			if (n.sustain > 0)
			{
				n.body = acquire(1, n.lane, sustainLayer);
				n.tail = acquire(2, n.lane, sustainLayer);
				n.body.flipY = n.tail.flipY = downscroll;
			}
		}
		activeNotes.push(n);
	}

	function place(n:NoteData, songPos:Float):Void
	{
		var r = receptors[n.lane];
		var dt = n.time - songPos;
		// usa o centro atual do receptor: scripts podem mover receptores e as notas acompanham
		var px = pxOf(n);
		var cy = n.holding ? r.cy : r.cy + (downscroll ? -dt : dt) * px;

		if (n.head != null)
		{
			n.head.alpha = (n.missed ? 0.3 : 1) * n.nAlpha;
			n.head.visible = n.nVisible;
			n.head.setPosition(r.cx - n.head.width / 2, cy + n.yOff - n.head.height / 2);
		}
		if (n.body == null)
			return;

		var remaining = n.holding ? (n.time + n.sustain - songPos) : n.sustain;
		if (remaining < 0)
			remaining = 0;
		var a = (n.missed || n.dropped) ? 0.3 : 0.6;
		var tail = n.tail;
		var body = n.body;
		var bodyPx = remaining * px - tail.height;
		if (bodyPx < 1)
		{
			body.visible = false;
			bodyPx = 0;
		}
		else
		{
			body.visible = true;
			var sy = bodyPx / body.frameHeight;
			if (Math.abs(sy - body.scale.y) > 0.002) // evita recalcular o hitbox todo frame
			{
				body.scale.y = sy;
				body.updateHitbox();
			}
		}
		body.alpha = tail.alpha = a;
		body.x = tail.x = r.cx - body.width / 2;

		if (downscroll)
		{
			body.y = cy - bodyPx;
			tail.y = body.y - tail.height;
		}
		else
		{
			body.y = cy;
			tail.y = cy + bodyPx;
		}
	}

	/** Remove só a cabeça (quando um sustain é acertado e segue sendo segurado). */
	public function releaseHead(n:NoteData):Void
	{
		if (n.head != null)
		{
			if (n.head.custom)
				n.head.kill();
			else
				recycleSprite(n.head);
			n.head = null;
		}
	}

	function release(n:NoteData):Void
	{
		releaseHead(n);
		if (n.body != null)
		{
			recycleSprite(n.body);
			n.body = null;
		}
		if (n.tail != null)
		{
			recycleSprite(n.tail);
			n.tail = null;
		}
	}

	function acquire(kind:Int, lane:Int, layer:FlxGroup):NoteSprite
	{
		var key = kind * 4 + lane;
		var list = free.get(key);
		var s:NoteSprite;
		if (list != null && list.length > 0)
		{
			s = list.pop();
			s.revive();
		}
		else
		{
			s = new NoteSprite(kind, lane);
			s.cameras = [cam];
			layer.add(s);
		}
		s.visible = true;
		s.alpha = (kind == 0) ? 1 : 0.6;
		return s;
	}

	function recycleSprite(s:NoteSprite):Void
	{
		s.kill();
		var key = s.kind * 4 + s.lane;
		var list = free.get(key);
		if (list == null)
		{
			list = [];
			free.set(key, list);
		}
		list.push(s);
	}

	/** Diagnóstico (F3): px/s em uso e a nota ativa mais próxima da seta. */
	public function debugInfo(songPos:Float):String
	{
		var best:NoteData = null;
		for (n in activeNotes)
			if (!n.hit && n.head != null && (best == null || n.time < best.time))
				best = n;
		var t = "px/s " + Math.round(0.45 * baseSpeed / rate * 1000);
		if (best != null)
			t += "  nota: dt " + Math.round(best.time - songPos) + " ms, y " + Math.round(best.head.y + best.head.height / 2) + " (seta " + Math.round(receptors[best.lane].cy) + ")";
		return t;
	}

	public function receptorFor(lane:Int):Receptor
		return receptors[lane];
}
