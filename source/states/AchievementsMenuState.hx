package states;

import flixel.addons.display.FlxBackdrop;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import backend.Achievements;
import backend.ClientPrefs;
import backend.Language;
import backend.Paths;
import backend.MusicBeatState;
import states.MainMenuState;

#if DISCORD_ALLOWED
import backend.DiscordClient;
#end

using StringTools;

class AchievementsMenuState extends MusicBeatState
{
	var options:Array<String> = [];
	var nameText:FlxText;
	var infoText:FlxText;
	var completionText:FlxText;
	var howManyText:FlxText;
	var achArray:Array<FlxSprite> = [];

	var bg:FlxBackdrop;
	var curSel:Int = 0;
	var hoveredMouseSel:Int = -1;
	var mouseControlActive:Bool = true;
	var holdTime:Float = 0;

	final columnsPerRow:Int = 7;

	override function create()
	{
		super.create();

		FlxG.mouse.visible = true;

		bg = new FlxBackdrop(Paths.image('menu/common/starFG'), X);
		bg.setGraphicSize(1280, 720);
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		Achievements.load();
		options = [];
		for (key => data in Achievements.achievements)
		{
			options.push(key);
		}

		achArray = [];
		var xAdd:Int = 0;
		var yAdd:Int = 0;
		var unlockedAwards:Int = 0;

		for (i in 0...options.length)
		{
			final achName:String = options[i];
			final unlocked:Bool = Achievements.isUnlocked(achName);
			if (unlocked) unlockedAwards++;

			var imgPath:String = 'achievements/$achName';
			if (!unlocked || !Paths.fileExists('images/$imgPath.png', IMAGE))
			{
				imgPath = 'achievements/lockedachievement';
			}

			var img:FlxSprite = new FlxSprite(85 + (xAdd * 165), 30 + (yAdd * 130)).loadGraphic(Paths.image(imgPath));
			img.setGraphicSize(120, 120);
			img.updateHitbox();
			img.antialiasing = ClientPrefs.data.antialiasing;
			img.ID = i;
			add(img);
			achArray.push(img);

			xAdd += 1;
			if (xAdd >= columnsPerRow)
			{
				xAdd = 0;
				yAdd += 1;
			}
		}

		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Awards Menu (${unlockedAwards}/${options.length})', null);
		#end

		nameText = new FlxText(0, 540, 1280, '', 40);
		infoText = new FlxText(0, 590, 1280, '', 25);
		completionText = new FlxText(10, 0, 0, '', 25);
		howManyText = new FlxText(0, 700, 1250, '', 25);

		for (txt in [nameText, infoText, completionText, howManyText])
		{
			txt.setFormat(Paths.font("vcr.ttf"), txt.size, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			txt.borderSize = 2.5;
			txt.antialiasing = ClientPrefs.data.antialiasing;
			add(txt);
		}

		var percent:Float = options.length > 0 ? (unlockedAwards / options.length) * 100 : 0;
		completionText.alignment = LEFT;
		completionText.text = 'Completion: ${Math.floor(percent)}%';
		completionText.y = (FlxG.height - completionText.height) - 9;
		if (percent >= 100) completionText.color = 0xFFFFE066;

		howManyText.alignment = RIGHT;
		howManyText.text = '${unlockedAwards}/${options.length}';
		howManyText.y = (FlxG.height - howManyText.height) - 9;
		if (unlockedAwards >= options.length) howManyText.color = 0xFFFFE066;

		refreshSelection();
	}

	function refreshSelection():Void
	{
		refreshIconAlphas();

		if (options.length == 0) return;

		final achKey:String = options[curSel];
		final achData = Achievements.achievements.get(achKey);
		final unlocked:Bool = Achievements.isUnlocked(achKey);

		nameText.color = unlocked ? 0xFFFFE066 : FlxColor.WHITE;

		if (achData != null && achData.hidden && !unlocked)
		{
			nameText.text = '???';
			infoText.text = Language.getPhrase('hidden_achievement', 'Hidden Achievement');
		}
		else
		{
			var defaultName:String = achData != null ? achData.name : achKey;
			var defaultDesc:String = achData != null ? achData.description : '';
			nameText.text = Language.getPhrase('achievement_${achKey}_name', defaultName);
			infoText.text = Language.getPhrase('achievement_${achKey}_desc', defaultDesc);
		}
	}

	function refreshIconAlphas():Void
	{
		for (icon in achArray)
		{
			icon.alpha = 0.6;
			if (icon.ID == hoveredMouseSel && icon.ID != curSel)
			{
				icon.alpha = 0.8;
			}
			if (icon.ID == curSel)
			{
				icon.alpha = 1.0;
			}
		}
	}

	function changeColumn(by:Int = 0):Void
	{
		if (options.length == 0) return;

		final curRow:Int = Std.int(curSel / columnsPerRow);
		final maxColumn:Int = FlxMath.minInt(options.length - curRow * columnsPerRow, columnsPerRow);

		if (maxColumn <= 1) return;

		curSel = (FlxMath.wrap(curSel % columnsPerRow + by, 0, maxColumn - 1) + curRow * columnsPerRow);

		if (by != 0) FlxG.sound.play(Paths.sound('scrollMenu'));

		refreshSelection();
	}

	function changeRow(by:Int = 0):Void
	{
		if (options.length == 0) return;

		final curColumn:Int = (curSel % columnsPerRow);
		final curRow:Int = Std.int(curSel / columnsPerRow);
		final maxRow:Int = (Math.floor(options.length / columnsPerRow) + (options.length % columnsPerRow <= curColumn ? 0 : 1));

		if (maxRow <= 1) return;

		final newRow:Int = FlxMath.wrap(curRow + by, 0, maxRow - 1);
		curSel = (curColumn + newRow * columnsPerRow);

		if (by != 0) FlxG.sound.play(Paths.sound('scrollMenu'));

		refreshSelection();
	}

	function handleMouse():Void
	{
		var newHovered:Int = -1;
		for (icon in achArray)
		{
			if (!FlxG.mouse.overlaps(icon)) continue;
			newHovered = icon.ID;
			if (FlxG.mouse.justPressed)
			{
				if (curSel != icon.ID)
				{
					curSel = icon.ID;
					refreshSelection();
				}
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			break;
		}

		if (hoveredMouseSel != newHovered)
		{
			hoveredMouseSel = newHovered;
			refreshIconAlphas();
		}
	}

	override function update(elapsed:Float)
	{
		if (FlxG.mouse.justMoved)
		{
			mouseControlActive = true;
		}

		if (controls.UI_UP_P || controls.UI_DOWN_P || controls.UI_LEFT_P || controls.UI_RIGHT_P || controls.BACK)
		{
			mouseControlActive = false;
		}

		if (mouseControlActive)
		{
			handleMouse();
		}
		else if (hoveredMouseSel != -1)
		{
			hoveredMouseSel = -1;
			refreshIconAlphas();
		}

		if (controls.UI_UP_P)
		{
			changeRow(-1);
			holdTime = 0;
		}
		if (controls.UI_DOWN_P)
		{
			changeRow(1);
			holdTime = 0;
		}
		if (controls.UI_LEFT_P)
		{
			changeColumn(-1);
			holdTime = 0;
		}
		if (controls.UI_RIGHT_P)
		{
			changeColumn(1);
			holdTime = 0;
		}

		if (controls.UI_UP || controls.UI_DOWN || controls.UI_LEFT || controls.UI_RIGHT)
		{
			var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
			holdTime += elapsed;
			var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

			if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
			{
				if (controls.UI_UP) changeRow(-1);
				if (controls.UI_DOWN) changeRow(1);
				if (controls.UI_LEFT) changeColumn(-1);
				if (controls.UI_RIGHT) changeColumn(1);
			}
		}

		if (controls.BACK)
		{
			FlxG.mouse.visible = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}

		bg.x -= 9 * elapsed;
		super.update(elapsed);
	}
}
