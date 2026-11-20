package debug;

import flixel.FlxG;
import haxe.Timer;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;
import openfl.utils.Assets;
import flixel.util.FlxStringUtil;
#if cpp
import cpp.vm.Gc;
#end

class FPSCounter extends Sprite
{
	public var currentFPS(default, null):Int;
	public var memoryMegas(get, never):Float;
	public var taskMemoryMegas(get, never):Float;

	private var textField:TextField;
	private var bgSprite:Sprite;

	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 10, y:Float = 3, color:Int = 0xFFFFFFFF)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		times = [];

		bgSprite = new Sprite();
		addChild(bgSprite);

		textField = new TextField();
		textField.selectable = false;
		textField.mouseEnabled = false;
		textField.defaultTextFormat = new TextFormat("_sans", 12, color);
		textField.autoSize = LEFT;
		textField.multiline = false;
		textField.text = "FPS: 0";
		textField.x = 6;
		textField.y = 2;
		addChild(textField);

		#if flash
		addEventListener(Event.ENTER_FRAME, function(e)
		{
			var time = Lib.getTimer();
			__enterFrame(time - currentTime);
		});
		#end
	}

	var deltaTimeout:Float = 0.0;

	private function __enterFrame(deltaTime:Float):Void
	{
		if (deltaTimeout > 1000)
		{
			deltaTimeout = 0.0;
			return;
		}

		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000)
			times.shift();

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
		updateText();
		deltaTimeout += deltaTime;
	}

	public dynamic function updateText():Void
	{
		var stateName:String = "UnknownState";
		if (FlxG.state != null)
		{
			stateName = Type.getClassName(Type.getClass(FlxG.state));
			if (stateName != null && !StringTools.startsWith(stateName, "funkin."))
				stateName = "funkin." + stateName;
		}

		var gcMemStr:String = FlxStringUtil.formatBytes(memoryMegas);
		var taskMemStr:String = FlxStringUtil.formatBytes(taskMemoryMegas);

		textField.text = 'FPS: ' + currentFPS + ' • [GC: ' + gcMemStr + ' | Task: ' + taskMemStr + '] • ' + stateName;

		textField.textColor = 0xFFFFFFFF;
		if (currentFPS < FlxG.drawFramerate * 0.5)
			textField.textColor = 0xFFFF0000;

		drawBackground();
	}

	private function drawBackground():Void
	{
		bgSprite.graphics.clear();
		bgSprite.graphics.beginFill(0x000000, 0.65);
		bgSprite.graphics.drawRoundRect(0, 0, textField.width + 12, textField.height + 4, 6, 6);
		bgSprite.graphics.endFill();
	}

	inline function get_memoryMegas():Float
	{
		#if cpp
		return cast(Gc.memInfo64(Gc.MEM_INFO_USAGE), Float);
		#else
		return cast(System.totalMemory, Float);
		#end
	}

	inline function get_taskMemoryMegas():Float
	{
		#if cpp
		var reserved:Float = cast(Gc.memInfo64(Gc.MEM_INFO_RESERVED), Float);
		return reserved > 0 ? reserved : cast(System.totalMemory, Float);
		#else
		return cast(System.totalMemory, Float);
		#end
	}
}
