package scripting;

import flixel.FlxSubState;
import states.PlayState;

/** Tela criada por openCustomSubstate (Psych): repassa create/update/destroy aos scripts. */
class CustomSub extends FlxSubState
{
	public var subName:String;

	var first:Bool = true; // a tecla que abriu a tela ainda conta como "apertada" no primeiro frame

	public function new(name:String)
	{
		super(0x00000000);
		subName = name;
	}

	override public function create():Void
	{
		super.create();
		PlayState.instance.scripts.call("onCustomSubstateCreate", [subName]);
		PlayState.instance.scripts.call("onCustomSubstateCreatePost", [subName]);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (first)
		{
			first = false;
			return;
		}
		PlayState.instance.scripts.call("onCustomSubstateUpdate", [subName, elapsed]);
		PlayState.instance.scripts.call("onCustomSubstateUpdatePost", [subName, elapsed]);
	}

	override public function destroy():Void
	{
		PlayState.instance.scripts.call("onCustomSubstateDestroy", [subName]);
		PsychLua.sub = null;
		super.destroy();
	}
}
