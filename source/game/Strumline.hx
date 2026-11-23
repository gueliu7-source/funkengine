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

	var pending:Array<NoteData>;
	var pendingIdx:Int = 0;

	var sustainLayer:FlxGroup = new FlxGroup();
	var headLayer:FlxGroup = new FlxGroup();
	var free:Map<Int, Array<NoteSprite>> = new Map();

	var pxPerMs:Float;
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
		pxPerMs = 0.45 * speed / rate;
		spawnMs = (FlxG.height + 160) / pxPerMs;
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
		if (!hidden)
		{
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
		var cy = n.holding ? r.cy : r.cy + (downscroll ? -dt : dt) * pxPerMs;

		if (n.head != null)
		{
			n.head.alpha = n.missed ? 0.3 : 1;
			n.head.setPosition(r.cx - n.head.width / 2, cy - n.head.height / 2);
		}
		if (n.body == null)
			return;

		var remaining = n.holding ? (n.time + n.sustain - songPos) : n.sustain;
		if (remaining < 0)
			remaining = 0;
		var a = (n.missed || n.dropped) ? 0.3 : 0.6;
		var tail = n.tail;
		var body = n.body;
		var bodyPx = remaining * pxPerMs - tail.height;
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

	public function receptorFor(lane:Int):Receptor
		return receptors[lane];
}
