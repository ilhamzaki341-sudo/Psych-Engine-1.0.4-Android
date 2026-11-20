package debug;

import haxe.Timer;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;
import flixel.FlxG;
import flixel.util.FlxStringUtil;
#if cpp
import cpp.vm.Gc;
#end

class FPSCounter extends Sprite
{
	public var currentFPS(default, null):Int;
	public var memoryMegas(get, never):Float;

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var skippedFrames:Int = 0;

	public var textField:TextField;
	public var bgSprite:Sprite;

	public function new(x:Float = 10, y:Float = 3, color:Int = 0xFFFFFF)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		times = [];

		bgSprite = new Sprite();
		addChild(bgSprite);

		textField = new TextField();
		textField.x = 6;
		textField.y = 2;
		textField.selectable = false;
		textField.mouseEnabled = false;
		textField.defaultTextFormat = new TextFormat("_sans", 13, color, true);
		textField.autoSize = LEFT;
		textField.multiline = false;
		textField.text = "FPS: 0";
		addChild(textField);

		updateBackground();
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		final now:Float = Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000)
			times.shift();

		if (skippedFrames < 6)
		{
			skippedFrames++;
			return;
		}
		skippedFrames = 0;

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
		updateText();
	}

	public dynamic function updateText():Void
	{
		var gcMem:Float = 0;
		#if cpp
		gcMem = Gc.memInfo64(Gc.MEM_INFO_USAGE);
		#else
		gcMem = System.totalMemory;
		#end
		var taskMem:Float = memoryMegas;

		var gcStr:String = FlxStringUtil.formatBytes(gcMem);
		var taskStr:String = FlxStringUtil.formatBytes(taskMem);
		var stateName:String = getFormattedStateName();

		textField.text = 'FPS: $currentFPS • [GC: $gcStr | Task: $taskStr] • $stateName';
		textField.textColor = (currentFPS < FlxG.drawFramerate / 2) ? 0xFFFF0000 : 0xFFFFFFFF;

		updateBackground();
	}

	private function getFormattedStateName():String
	{
		if (FlxG.state == null)
			return "funkin.states.InitState";

		var className:String = Type.getClassName(Type.getClass(FlxG.state));
		if (className == null || className.length == 0)
			return "funkin.states.UnknownState";

		if (StringTools.startsWith(className, "states."))
			return "funkin." + className;

		if (className.indexOf(".") == -1)
			return "funkin.states." + className;

		return className;
	}

	private function updateBackground():Void
	{
		if (bgSprite == null || textField == null)
			return;

		var w:Float = textField.textWidth + 14;
		var h:Float = textField.textHeight + 6;

		bgSprite.graphics.clear();
		bgSprite.graphics.beginFill(0x000000, 0.55);
		bgSprite.graphics.drawRoundRect(0, 0, w, h, 4, 4);
		bgSprite.graphics.endFill();
	}

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1):Void
	{
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;
		x = FlxG.game.x + X;
		y = FlxG.game.y + Y;
	}

	inline function get_memoryMegas():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
}
