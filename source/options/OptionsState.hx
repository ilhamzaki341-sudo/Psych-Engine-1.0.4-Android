package options;

import flixel.addons.display.FlxBackdrop;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.FlxSprite;

import backend.ClientPrefs;
import backend.Language;
import backend.Paths;
import backend.MusicBeatState;
import states.MainMenuState;
import states.PlayState;
import options.NoteOffsetState;
import options.ControlsSubState;
import options.GraphicsSettingsSubState;
import options.VisualsSettingsSubState;
import options.GameplaySettingsSubState;
import options.LanguageSubState;
import options.NotesColorSubState;

#if DISCORD_ALLOWED
import backend.Discord;
#end

using StringTools;

class OptionsState extends MusicBeatState
{
	public static var onPlayState:Bool = false;

	var options:Array<String> = [
		'Note Colors',
		'Controls',
		'Adjust Delay and Combo',
		'Graphics',
		'Visuals',
		'Gameplay',
		'Language'
	];

	var __openedOption:Null<String> = null;
	var optionTexts:FlxTypedGroup<FlxText>;

	private static var curSelected:Int = 0;

	var blockAllInput:Bool = false;
	var blockInput:Bool = false;
	var pendingSubstate:Null<String> = null;

	var bg:FlxBackdrop;
	var titleText:FlxText;
	var versionText:FlxText;
	var artImage:FlxSprite;
	var optionsHeader:FlxText;
	var menuBackButton:FlxSprite;

	var mouseControlActive:Bool = true;
	var hoveredOption:Int = -1;

	static final OPTION_LABEL_BASE_SIZE:Int = 26;
	static final OPTION_LABEL_MIN_SIZE:Int = 14;
	static final OPTION_LABEL_MAX_LINES:Int = 2;

	var buttonBaseX:Float = 95;
	var buttonBaseY:Float = 112;
	var buttonSpacing:Float = 72;

	function byeByeHomePanel(visible:Bool):Void
	{
		if (titleText != null) titleText.visible = visible;
		if (versionText != null) versionText.visible = visible;
		if (artImage != null) artImage.visible = visible;
	}

	public function openSelectedSubstate(label:String)
	{
		if (label == 'Adjust Delay and Combo')
		{
			MusicBeatState.switchState(new NoteOffsetState());
			return;
		}

		byeByeHomePanel(false);
		blockInput = true;

		switch (label)
		{
			case 'Note Colors':
				openSubState(new NotesColorSubState());
			case 'Controls':
				openSubState(new ControlsSubState());
			case 'Graphics':
				openSubState(new GraphicsSettingsSubState());
			case 'Visuals':
				openSubState(new VisualsSettingsSubState());
			case 'Gameplay':
				openSubState(new GameplaySettingsSubState());
			case 'Language':
				openSubState(new LanguageSubState());
		}

		__openedOption = label;
		pendingSubstate = null;
	}

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		persistentUpdate = true;
		FlxG.mouse.enabled = true;
		#if android
		FlxG.mouse.visible = false;
		#else
		FlxG.mouse.visible = true;
		#end

		var ext:String = 'menu/options/';

		bg = new FlxBackdrop(Paths.image('menu/common/starFG'), X);
		bg.setGraphicSize(1280, 720);
		bg.updateHitbox();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		var thingy:FlxSprite = new FlxSprite(50, 30).loadGraphic(Paths.image(ext + 'thingy'));
		thingy.antialiasing = ClientPrefs.data.antialiasing;
		add(thingy);

		optionsHeader = new FlxText(75, 30, 0, Language.getPhrase('options_menu', 'OPTIONS'), 50);
		optionsHeader.setFormat(Paths.font('AmaticSC-Bold.ttf'), 50, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		optionsHeader.borderSize = 2;
		optionsHeader.antialiasing = ClientPrefs.data.antialiasing;
		add(optionsHeader);

		menuBackButton = new FlxSprite(1100, 30).loadGraphic(Paths.image('menu/common/menuBack'));
		menuBackButton.antialiasing = ClientPrefs.data.antialiasing;
		add(menuBackButton);

		optionTexts = new FlxTypedGroup<FlxText>();
		add(optionTexts);

		for (i in 0...options.length)
		{
			var keyName:String = options[i].toLowerCase().replace(' ', '_');
			var labelStr:String = Language.getPhrase('options_$keyName', options[i]);

			var txt:FlxText = new FlxText(buttonBaseX, buttonBaseY + (buttonSpacing * i), 320, labelStr);
			txt.setFormat(Paths.font("vcr.ttf"), OPTION_LABEL_BASE_SIZE, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			txt.borderSize = 2;
			txt.antialiasing = ClientPrefs.data.antialiasing;
			txt.ID = i;
			fitLeftOptionLabel(txt);
			optionTexts.add(txt);
		}

		artImage = new FlxSprite(500, 375).loadGraphic(Paths.image(ext + 'art'));
		artImage.antialiasing = ClientPrefs.data.antialiasing;
		artImage.y -= Math.round(artImage.height * 0.5);
		add(artImage);

		titleText = new FlxText(480, artImage.y, 700, 'VS IMPOSTOR: LEGACY');
		titleText.setFormat(Paths.font("vcr.ttf"), 42, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.y -= (titleText.height + 16);
		titleText.borderSize = 2;
		titleText.antialiasing = ClientPrefs.data.antialiasing;
		add(titleText);

		versionText = new FlxText(480, artImage.y + artImage.height + 20, 700, 'Vs Impostor Legacy Port - PE 1.0.4');
		versionText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionText.borderSize = 1.5;
		versionText.antialiasing = ClientPrefs.data.antialiasing;
		add(versionText);

		changeSelection();
		refreshOptionFonts();
		byeByeHomePanel(true);

		#if TOUCH_CONTROLS_ALLOWED
		addTouchPad('UP_DOWN', 'A_B');
		#end

		super.create();
	}

	override function closeSubState()
	{
		__openedOption = null;
		blockInput = false;
		refreshOptionFonts();

		if (pendingSubstate == null) byeByeHomePanel(true);

		super.closeSubState();
	}

	override function destroy():Void
	{
		ClientPrefs.saveSettings();
		super.destroy();
	}

	function refreshOptionFonts()
	{
		optionsHeader.text = Language.getPhrase('options_menu', 'OPTIONS');
		optionsHeader.y = (38 + Math.round((optionsHeader.size - optionsHeader.height) * 0.5));

		for (txt in optionTexts.members)
		{
			var keyName:String = options[txt.ID].toLowerCase().replace(' ', '_');
			txt.text = Language.getPhrase('options_$keyName', options[txt.ID]);
			fitLeftOptionLabel(txt);
		}

		refreshOptionVisuals();
	}

	function fitLeftOptionLabel(txt:FlxText):Void
	{
		var size:Int = OPTION_LABEL_BASE_SIZE;
		txt.fieldWidth = 300;
		txt.setFormat(Paths.font('vcr.ttf'), size, txt.color, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		txt.borderSize = 2;
		txt.textField.wordWrap = true;
		txt.textField.multiline = true;

		while (size > OPTION_LABEL_MIN_SIZE && txt.textField.numLines > OPTION_LABEL_MAX_LINES)
		{
			size--;
			txt.setFormat(Paths.font('vcr.ttf'), size, txt.color, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			txt.borderSize = 2;
			txt.textField.wordWrap = true;
			txt.textField.multiline = true;
		}

		var slotY:Float = buttonBaseY + (buttonSpacing * txt.ID);
		txt.y = Math.round(slotY + Math.max(0, (buttonSpacing - txt.height) * 0.5));
	}

	function refreshOptionVisuals()
	{
		if (blockAllInput) return;
		for (txt in optionTexts.members)
		{
			txt.alpha = 1;
			txt.color = 0xFFC9C9C9;

			if (txt.ID == hoveredOption && txt.ID != curSelected)
			{
				txt.color = FlxColor.WHITE;
			}
			if (txt.ID == curSelected)
			{
				txt.color = 0xFFFFE066;
			}
		}
	}

	function exitOptions():Void
	{
		#if !android
		FlxG.mouse.visible = false;
		#end
		FlxG.sound.play(Paths.sound('cancelMenu'));
		if (onPlayState)
		{
			MusicBeatState.switchState(new PlayState());
			if (FlxG.sound.music != null) FlxG.sound.music.volume = 0;
			onPlayState = false;
		}
		else
		{
			MusicBeatState.switchState(new MainMenuState());
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		bg.x -= 9 * elapsed;

		hoveredOption = -1;

		if (FlxG.mouse.justMoved || FlxG.mouse.justPressed)
		{
			mouseControlActive = true;
		}
		if (controls.UI_UP_P || controls.UI_DOWN_P || controls.ACCEPT || controls.BACK)
		{
			mouseControlActive = false;
		}

		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(menuBackButton) && !blockAllInput)
		{
			exitOptions();
			return;
		}

		if (mouseControlActive && !blockAllInput)
		{
			for (txt in optionTexts.members)
			{
				if (!FlxG.mouse.overlaps(txt)) continue;
				hoveredOption = txt.ID;

				if (FlxG.mouse.justPressed)
				{
					if (txt.ID != curSelected)
					{
						curSelected = txt.ID;
						changeSelection(0, true);
					}

					if (blockInput)
					{
						if (options[curSelected] == 'Adjust Delay and Combo')
						{
							MusicBeatState.switchState(new NoteOffsetState());
						}
						else if (__openedOption != null && __openedOption != options[curSelected])
						{
							pendingSubstate = options[curSelected];
							closeSubState();
							openSelectedSubstate(options[curSelected]);
						}
					}
					else
					{
						openSelectedSubstate(options[curSelected]);
					}
				}
				break;
			}
		}

		refreshOptionVisuals();

		if (!blockInput && !blockAllInput)
		{
			if (controls.UI_UP_P) changeSelection(-1);
			if (controls.UI_DOWN_P) changeSelection(1);

			if (controls.BACK #if android || FlxG.android.justReleased.BACK #end)
			{
				exitOptions();
			}

			if (controls.ACCEPT)
			{
				openSelectedSubstate(options[curSelected]);
			}
		}
	}

	function changeSelection(change:Int = 0, ?fromMouse:Bool = false)
	{
		curSelected += change;
		if (curSelected < 0) curSelected = options.length - 1;
		if (curSelected >= options.length) curSelected = 0;
		refreshOptionVisuals();

		FlxG.sound.play(Paths.sound('scrollMenu'), fromMouse ? 0.7 : 0.5);
	}
}
