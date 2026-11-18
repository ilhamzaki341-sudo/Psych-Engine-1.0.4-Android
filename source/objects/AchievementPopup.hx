package objects;

#if ACHIEVEMENTS_ALLOWED
import openfl.events.Event;
import openfl.geom.Matrix;
import flash.display.BitmapData;
import openfl.Lib;

class AchievementPopup extends openfl.display.Sprite
{
	public var onFinish:Void->Void = null;
	var alphaTween:FlxTween;
	var lastScale:Float = 1;

	static final POPUP_WIDTH:Float = 410;
	static final POPUP_HEIGHT:Float = 100;
	static final NAME_TEXT_BASE_SIZE:Int = 24;
	static final NAME_TEXT_MIN_SIZE:Int = 14;
	static final DESC_TEXT_BASE_SIZE:Int = 16;
	static final DESC_TEXT_MIN_SIZE:Int = 11;
	static final DESC_TEXT_MAX_HEIGHT:Int = 48;

	public function new(achieve:String, onFinish:Void->Void)
	{
		super();
		this.onFinish = onFinish;

		graphics.beginFill(0x000000, 0.75);
		graphics.drawRect(0, 0, POPUP_WIDTH, POPUP_HEIGHT);
		graphics.endFill();

		var graphic = null;
		var hasAntialias:Bool = ClientPrefs.data.antialiasing;
		var image:String = 'achievements/$achieve';

		var achievement:Achievement = null;
		if (Achievements.exists(achieve)) achievement = Achievements.get(achieve);

		#if MODS_ALLOWED
		var lastMod = Mods.currentModDirectory;
		if (achievement != null) Mods.currentModDirectory = achievement.mod != null ? achievement.mod : '';
		#end

		if (Paths.fileExists('images/$image-pixel.png', IMAGE))
		{
			graphic = Paths.image('$image-pixel', false);
			hasAntialias = false;
		}
		else
		{
			graphic = Paths.image(image, false);
		}

		#if MODS_ALLOWED
		Mods.currentModDirectory = lastMod;
		#end

		if (graphic == null) graphic = Paths.image('unknownMod', false);

		var sizeX:Float = 75;
		var sizeY:Float = 75;
		var imgX:Float = 10;
		var imgY:Float = 12;

		if (graphic != null && graphic.bitmap != null)
		{
			var bmp = graphic.bitmap;
			graphics.beginBitmapFill(bmp, new Matrix(sizeX / bmp.width, 0, 0, sizeY / bmp.height, imgX, imgY), false, hasAntialias);
			graphics.drawRect(imgX, imgY, sizeX, sizeY);
			graphics.endFill();
		}

		var name:String = 'Award Unlocked';
		var desc:String = '';
		if (achievement != null)
		{
			if (achievement.name != null) name = Language.getPhrase('achievement_$achieve', achievement.name);
			if (achievement.description != null) desc = Language.getPhrase('description_$achieve', achievement.description);
		}

		var textX:Float = 95;
		var textWidth:Int = 300;

		var nameText:FlxText = new FlxText(0, 0, textWidth, name, NAME_TEXT_BASE_SIZE);
		fitText(nameText, NAME_TEXT_BASE_SIZE, NAME_TEXT_MIN_SIZE, false, 0);
		drawTextAt(nameText, name, textX, 8);

		var descText:FlxText = new FlxText(0, 0, textWidth, desc, DESC_TEXT_BASE_SIZE);
		fitText(descText, DESC_TEXT_BASE_SIZE, DESC_TEXT_MIN_SIZE, true, DESC_TEXT_MAX_HEIGHT);
		drawTextAt(descText, desc, textX, 42);

		if (nameText.graphic != null && nameText.graphic.bitmap != null)
		{
			nameText.graphic.bitmap.dispose();
			nameText.graphic.bitmap.disposeImage();
		}
		nameText.destroy();

		if (descText.graphic != null && descText.graphic.bitmap != null)
		{
			descText.graphic.bitmap.dispose();
			descText.graphic.bitmap.disposeImage();
		}
		descText.destroy();

		FlxG.stage.addEventListener(Event.RESIZE, onResize);
		addEventListener(Event.ENTER_FRAME, update);
		FlxG.game.addChild(this);

		lastScale = (FlxG.stage.stageHeight / FlxG.height);
		this.scaleX = lastScale;
		this.scaleY = lastScale;

		var screenWidthInGame:Float = FlxG.stage.stageWidth / lastScale;
		this.x = (screenWidthInGame - POPUP_WIDTH - 20) * lastScale;

		this.y = FlxG.height * lastScale;
		this.alpha = 0;
		intendedY = FlxG.height - POPUP_HEIGHT - 15;
	}

	function fitText(textObj:FlxText, baseSize:Int, minSize:Int, multiline:Bool, maxHeight:Int):Void
	{
		var size:Int = baseSize;
		applyFormat(textObj, size, multiline);

		if (!multiline)
		{
			while (size > minSize && textObj.textField.textWidth > textObj.fieldWidth)
			{
				size--;
				applyFormat(textObj, size, false);
			}
		}
		else
		{
			while (size > minSize && textObj.textField.textHeight > maxHeight)
			{
				size--;
				applyFormat(textObj, size, true);
			}
		}
	}

	function applyFormat(textObj:FlxText, size:Int, multiline:Bool):Void
	{
		textObj.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		textObj.borderSize = 2;
		textObj.textField.wordWrap = multiline;
		textObj.textField.multiline = multiline;
		textObj.updateHitbox();
	}

	var bitmaps:Array<BitmapData> = [];
	function drawTextAt(text:FlxText, str:String, textX:Float, textY:Float)
	{
		text.text = str;
		text.updateHitbox();

		if (text.graphic == null || text.graphic.bitmap == null) return;

		var clonedBitmap:BitmapData = text.graphic.bitmap.clone();
		bitmaps.push(clonedBitmap);
		graphics.beginBitmapFill(clonedBitmap, new Matrix(1, 0, 0, 1, textX, textY), false, false);
		graphics.drawRect(textX, textY, text.width, text.height);
		graphics.endFill();
	}

	var lerpTime:Float = 0;
	var countedTime:Float = 0;
	var timePassed:Float = -1;
	public var intendedY:Float = 0;

	function update(e:Event)
	{
		if (timePassed < 0)
		{
			timePassed = Lib.getTimer();
			return;
		}

		var time = Lib.getTimer();
		var elapsed:Float = (time - timePassed) / 1000;
		timePassed = time;

		if (elapsed >= 0.5) return;

		countedTime += elapsed;

		if (countedTime < 3.5)
		{
			lerpTime = Math.min(1, lerpTime + (elapsed / 0.35));
			var startY:Float = FlxG.height + 20;
			var currentY:Float = startY + (FlxEase.circOut(lerpTime) * (intendedY - startY));
			y = currentY * lastScale;
			alpha = Math.min(1, lerpTime * 1.5);
		}
		else
		{
			var fadeProgress:Float = (countedTime - 3.5) / 0.35;
			alpha = Math.max(0, 1 - fadeProgress);
			if (alpha <= 0)
			{
				destroy();
			}
		}
	}

	private function onResize(e:Event)
	{
		var mult = (FlxG.stage.stageHeight / FlxG.height);
		scaleX = mult;
		scaleY = mult;

		var screenWidthInGame:Float = FlxG.stage.stageWidth / mult;
		x = (screenWidthInGame - POPUP_WIDTH - 20) * mult;
		y = (mult / lastScale) * y;
		lastScale = mult;
	}

	public function destroy()
	{
		Achievements._popups.remove(this);

		if (FlxG.game.contains(this))
		{
			FlxG.game.removeChild(this);
		}
		FlxG.stage.removeEventListener(Event.RESIZE, onResize);
		removeEventListener(Event.ENTER_FRAME, update);
		deleteClonedBitmaps();

		if (onFinish != null)
		{
			onFinish();
			onFinish = null;
		}
	}

	function deleteClonedBitmaps()
	{
		if (bitmaps == null) return;
		for (clonedBitmap in bitmaps)
		{
			if (clonedBitmap != null)
			{
				clonedBitmap.dispose();
				clonedBitmap.disposeImage();
			}
		}
		bitmaps = null;
	}
}
#end
