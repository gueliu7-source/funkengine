package ui;

import core.Settings;
import flixel.FlxG;
import haxe.Timer;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.filters.DropShadowFilter;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

/**
 * Painel no centro superior da tela: FPS, tempo de quadro, memória, tela atual e objetos.
 * F3 alterna: oculto → FPS e memória → completo. A escolha fica salva nas opções.
 */
class DebugOverlay extends Sprite
{
	var tf:TextField;
	var frames:Int = 0;
	var acc:Float = 0;
	var last:Float;
	var fps:Float = 0;
	var ms:Float = 0;
	var peak:Float = 0;
	var worst:Float = 0;
	var shownW:Float = -1;

	public function new()
	{
		super();
		mouseEnabled = false;
		mouseChildren = false;
		tf = new TextField();
		tf.selectable = false;
		tf.mouseEnabled = false;
		tf.multiline = true;
		tf.wordWrap = false;
		tf.autoSize = TextFieldAutoSize.CENTER;
		tf.defaultTextFormat = new TextFormat("_sans", 14, 0xFFFFFF, true, null, null, null, null, TextFormatAlign.CENTER);
		tf.filters = [new DropShadowFilter(1.5, 45, 0x000000, 1, 3, 3, 6)];
		addChild(tf);
		last = Timer.stamp();
		addEventListener(Event.ENTER_FRAME, tick);
		Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, key);
		refresh();
	}

	function key(e:KeyboardEvent):Void
	{
		if (e.keyCode == 114) // F3
		{
			Settings.d.debugOverlay = (Settings.d.debugOverlay + 1) % 3;
			Settings.flush();
			refresh();
		}
	}

	static function memory():Float
	{
		#if cpp
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#else
		return openfl.system.System.totalMemory;
		#end
	}

	function tick(_:Event):Void
	{
		var now = Timer.stamp();
		var dt = now - last;
		last = now;
		frames++;
		acc += dt;
		if (dt * 1000 > worst)
			worst = dt * 1000;
		if (acc >= 0.5)
		{
			fps = frames / acc;
			ms = acc / frames * 1000;
			frames = 0;
			acc = 0;
			refresh();
			worst = 0;
		}
		var w = Lib.current.stage.stageWidth;
		if (w != shownW)
		{
			shownW = w;
			tf.x = (w - tf.width) / 2;
		}
	}

	function stateName():String
	{
		if (FlxG.state == null)
			return "";
		var n = Type.getClassName(Type.getClass(FlxG.state));
		return n.substr(n.lastIndexOf(".") + 1);
	}

	function refresh():Void
	{
		var mode = Settings.d.debugOverlay;
		visible = mode > 0;
		if (mode <= 0)
			return;
		var mem = memory();
		if (mem > peak)
			peak = mem;
		var mb = function(b:Float) return Std.string(Math.round(b / 1048576 * 10) / 10);
		var t = "FPS " + Math.round(fps) + "   RAM " + mb(mem) + " MB";
		if (mode >= 2)
		{
			t += "\n" + (Math.round(ms * 10) / 10) + " ms/quadro (pior " + Math.round(worst) + " ms)   pico " + mb(peak) + " MB";
			var st = FlxG.state;
			t += "\n" + stateName() + "   objetos " + (st != null ? st.members.length : 0) + "   F3: ocultar";
		}
		tf.textColor = fps > 0 && fps < Settings.d.fps * 0.6 ? 0xFF6666 : 0xFFFFFF;
		tf.text = t;
		tf.x = (Lib.current.stage.stageWidth - tf.width) / 2;
	}
}
