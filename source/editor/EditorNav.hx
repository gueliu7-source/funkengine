package editor;

import flixel.FlxG;
import states.EditorsState;

/** Troca direta entre os editores (Chart, Character, Stage) e o menu dos editores. */
class EditorNav
{
	public static function toChart(songId:String, suffix:String = ""):Void
	{
		ChartEditorState.songId = songId;
		ChartEditorState.suffix = suffix;
		FlxG.switchState(new ChartEditorState());
	}

	public static function toChar(id:String):Void
	{
		CharEditorState.charId = id;
		CharEditorState.cloneFrom = "";
		FlxG.switchState(new CharEditorState());
	}

	public static function toStage(name:String):Void
	{
		StageEditorState.stageName = name;
		FlxG.switchState(new StageEditorState());
	}

	public static function toMenu():Void
		FlxG.switchState(new EditorsState());
}
