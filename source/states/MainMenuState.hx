package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;

import backend.Mods;
import backend.Discord;
import backend.ClientPrefs;
import backend.Paths;
import backend.Conductor;
import backend.MusicBeatState;

import states.StoryMenuState;
import states.FreeplayState;
import states.CreditsState;
import states.AchievementsMenuState;
import states.TitleState;
import states.editors.MasterEditorMenu;
import options.OptionsState;

class MainMenuState extends MusicBeatState
{
	public static var fromTitle:Bool = false;
	
	var lockMovement:Bool = false;
	var mouseMode:Bool = true;
	
	static var curMenuItem:Int = 0;
	static var lastSmallBtn:Int = 3;
	
	var menuButtons:Array<FlxSprite> = [];
	var menuLabels:Array<FlxText> = [];
	var menuLabelBaseSizes:Array<Int> = [];
	var menuLabelYOffsets:Array<Float> = [];
	var menuIcons:Array<FlxSprite> = [];
	var menuIconOrigX:Array<Float> = [];
	var menuIconTweens:Array<FlxTween> = [];
	
	var redMenu:FlxSprite;
	var greenMenu:FlxSprite;
	var logo:FlxSprite;
	var backpanel:FlxSprite;
	
	var panelIntroItems:Array<FlxSprite> = [];
	var introActive:Bool = false;
	var introTimer:Float = 0;
	
	static final BIG_LABELS:Array<String> = ['STORY MODE', 'FREEPLAY', 'CREDITS'];
	static final SMALL_LABELS:Array<String> = ['OPTIONS', 'AWARDS'];
	static final ICON_PREFIXES:Array<String> = [
		'Red and Green instance 1', 
		'Cone instance 1', 
		'Polus instance 1', 
		'Gear instance 1', 
		'Trophy instance 1'
	];
	static final MENU_LABEL_MIN_SIZE:Int = 12;

	override function create()
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		if (FlxG.sound.music == null) {
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		}

		logo = new FlxSprite(0, -5);
		logo.frames = Paths.getSparrowAtlas('logoBumpin');
		logo.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logo.antialiasing = ClientPrefs.data.antialiasing;
		logo.scale.set(0.5, 0.5);
		logo.updateHitbox();
		logo.screenCenter(X);
		logo.x += 20;
		add(logo);

		buildPanel();

		var redTargetX:Float = 630;
		var greenTargetX:Float = -225;

		redMenu = new FlxSprite(redTargetX, 70);
		redMenu.frames = Paths.getSparrowAtlas('menu/main/redmenu');
		redMenu.animation.addByPrefix('idle', 'idle', 24, false);
		redMenu.animation.addByPrefix('select', 'confirm', 24, false);
		redMenu.antialiasing = ClientPrefs.data.antialiasing;
		redMenu.animation.play('idle');
		add(redMenu);

		greenMenu = new FlxSprite(greenTargetX, 100);
		greenMenu.frames = Paths.getSparrowAtlas('menu/main/greenmenu');
		greenMenu.animation.addByPrefix('idle', 'idle', 24, false);
		greenMenu.animation.addByPrefix('select', 'confirm', 24, false);
		greenMenu.antialiasing = ClientPrefs.data.antialiasing;
		greenMenu.animation.play('idle');
		add(greenMenu);

		var glow = new FlxSprite().loadGraphic(Paths.image('menu/main/glow'));
		glow.scale.set(1.1, 1.1);
		glow.updateHitbox();
		glow.screenCenter();
		glow.blend = ADD;
		add(glow);

		var vignette = new FlxSprite().loadGraphic(Paths.image('menu/main/vignette'));
		vignette.scrollFactor.set();
		vignette.active = false;
		add(vignette);

		var versionShit = new FlxText(12, FlxG.height - 24, 0, "VS Impostor Legacy Port - PE v1.0.4", 16);
		versionShit.scrollFactor.set();
		versionShit.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		Conductor.bpm = 102;
		
		FlxG.mouse.enabled = true;
		#if android
		FlxG.mouse.visible = false;
		#else
		FlxG.mouse.visible = true;
		#end

		super.create();

		if (fromTitle)
		{
			redMenu.x = FlxG.width + 120;
			greenMenu.x = -greenMenu.width - 120;
			FlxTween.tween(redMenu, {x: redTargetX}, 1.2, {ease: FlxEase.expoOut});
			FlxTween.tween(greenMenu, {x: greenTargetX}, 1.2, {ease: FlxEase.expoOut});
			playPanelIntro();
			fromTitle = false;
		}

		updateMenuSelection();
	}

	function buildPanel()
	{
		final ext:String = 'menu/main/';
		final r:Float = (1280 / 1920);

		backpanel = new FlxSprite(0, 350).loadGraphic(Paths.image('${ext}tablet'));
		backpanel.scale.set(r, r);
		backpanel.updateHitbox();
		backpanel.screenCenter(X);
		backpanel.antialiasing = ClientPrefs.data.antialiasing;
		add(backpanel);
		panelIntroItems.push(backpanel);

		var buttonY:Float = (backpanel.y + 28);
		for (i in 0...BIG_LABELS.length)
		{
			var btn = new FlxSprite(0, buttonY);
			btn.frames = Paths.getSparrowAtlas('${ext}new buttons and stuff');
			btn.animation.addByPrefix('idle', 'Big button instance 1', 24, false);
			btn.animation.play('idle');
			btn.animation.pause();
			btn.scale.set(r, r);
			btn.updateHitbox();
			btn.screenCenter(X);
			btn.antialiasing = ClientPrefs.data.antialiasing;
			add(btn);
			menuButtons.push(btn);
			panelIntroItems.push(btn);

			buttonY += (btn.height + 8);

			var lbl = new FlxText(btn.x + 16, 0, btn.width - 32, BIG_LABELS[i], 24);
			lbl.setFormat(Paths.font('vcr.ttf'), 28, 0xFF0F332F, RIGHT);
			lbl.y = Math.round(btn.y + (btn.height - lbl.height) * 0.5 + 4);
			add(lbl);
			menuLabels.push(lbl);
			menuLabelBaseSizes.push(28);
			menuLabelYOffsets.push(4);
			panelIntroItems.push(lbl);
		}

		for (i in 0...SMALL_LABELS.length)
		{
			var btn = new FlxSprite(0, buttonY);
			btn.frames = Paths.getSparrowAtlas('${ext}new buttons and stuff');
			btn.animation.addByPrefix('idle', 'Small Button instance 1', 24, false);
			btn.animation.play('idle');
			btn.animation.pause();
			btn.scale.set(r, r);
			btn.updateHitbox();
			btn.x = Math.round(i == 0 ? backpanel.x + 28 : backpanel.x + backpanel.width - btn.width - 28);
			btn.antialiasing = ClientPrefs.data.antialiasing;
			add(btn);
			menuButtons.push(btn);
			panelIntroItems.push(btn);

			var lbl = new FlxText(btn.x + 16, 0, btn.width - 32, SMALL_LABELS[i], 22);
			lbl.setFormat(Paths.font('vcr.ttf'), 18, 0xFF0F332F, RIGHT);
			lbl.y = Math.round(btn.y + (btn.height - lbl.height) * 0.5 + 3);
			add(lbl);
			menuLabels.push(lbl);
			menuLabelBaseSizes.push(18);
			menuLabelYOffsets.push(3);
			panelIntroItems.push(lbl);
		}

		for (i in 0...menuButtons.length)
		{
			var btn = menuButtons[i];
			var icon = new FlxSprite();
			icon.frames = Paths.getSparrowAtlas('${ext}new buttons and stuff');
			icon.animation.addByPrefix('idle', ICON_PREFIXES[i], 24, false);
			icon.animation.play('idle');
			icon.scale.set(r, r);
			icon.updateHitbox();
			icon.x = btn.x + 10;
			icon.y = btn.y + (btn.height - icon.height) * 0.5;
			icon.antialiasing = ClientPrefs.data.antialiasing;
			add(icon);
			
			menuIcons.push(icon);
			menuIconOrigX.push(icon.x);
			menuIconTweens.push(null);
			panelIntroItems.push(icon);
		}

		refreshMenuLabelLayout();
	}

	function refreshMenuLabelLayout()
	{
		for (i in 0...menuLabels.length)
			fitMenuLabel(i);
	}

	function fitMenuLabel(i:Int)
	{
		var btn = menuButtons[i];
		var lbl = menuLabels[i];
		var icon = menuIcons[i];

		var leftBound:Float = btn.x + 8;
		if (icon != null && icon.visible) leftBound = Math.max(leftBound, icon.x + icon.width + 8);
		var rightBound:Float = btn.x + btn.width - 8;

		lbl.x = Math.round(leftBound + 4);
		lbl.fieldWidth = Math.max(8, Math.round(rightBound - lbl.x - 4));

		var size:Int = menuLabelBaseSizes[i];
		lbl.setFormat(Paths.font('vcr.ttf'), size, lbl.color, RIGHT);
		lbl.textField.wordWrap = false;
		lbl.textField.multiline = false;

		while (size > MENU_LABEL_MIN_SIZE && lbl.textField != null && lbl.textField.textWidth > lbl.fieldWidth)
		{
			size--;
			lbl.setFormat(Paths.font('vcr.ttf'), size, lbl.color, RIGHT);
			lbl.textField.wordWrap = false;
			lbl.textField.multiline = false;
		}

		lbl.y = Math.round(btn.y + (btn.height - lbl.height) * 0.5 + menuLabelYOffsets[i]);
	}

	function playPanelIntro()
	{
		introActive = true;
		introTimer = 0.6;
		for (item in panelIntroItems)
		{
			var targetY = item.y;
			item.y += 220;
			FlxTween.tween(item, {y: targetY}, 1.2, {ease: FlxEase.expoOut});
		}
	}

	function updateMenuSelection()
	{
		for (i in 0...menuButtons.length)
		{
			if (menuButtons[i].animation.curAnim != null) {
				menuButtons[i].animation.curAnim.curFrame = (i == curMenuItem) ? 1 : 0;
			}
			
			if (menuIconTweens[i] != null)
			{
				menuIconTweens[i].cancel();
				menuIconTweens[i] = null;
			}

			if (i < 3)
			{
				var targetX = menuIconOrigX[i] + (i == curMenuItem ? 15 : 0);
				menuIconTweens[i] = FlxTween.tween(menuIcons[i], {x: targetX}, 0.15, {ease: FlxEase.quadOut});
			}
		}
	}

	override function beatHit()
	{
		super.beatHit();

		if (logo != null) logo.animation.play('bump', true);
		if (redMenu != null && redMenu.animation.name != 'select') redMenu.animation.play('idle', true);
		if (greenMenu != null && greenMenu.animation.name != 'select') greenMenu.animation.play('idle', true);
	}

	function select()
	{
		if (lockMovement) return;
		lockMovement = true;

		redMenu.animation.play('select');
		greenMenu.animation.play('select');

		for (item in [menuButtons[curMenuItem], menuLabels[curMenuItem], menuIcons[curMenuItem]])
		{
			item.scale.scale(0.9);
			FlxTween.tween(item.scale, {x: item.scale.x * 1.05, y: item.scale.y * 1.05}, 0.2, {ease: FlxEase.circOut});
		}

		FlxG.sound.play(Paths.sound('confirmMenu'));

		FlxTween.tween(redMenu, {y: redMenu.y + 750}, 1.2, {ease: FlxEase.quadInOut, startDelay: 0.6});
		FlxTween.tween(greenMenu, {y: greenMenu.y + 750}, 1.2, {ease: FlxEase.quadInOut, startDelay: 0.6});
		FlxTween.tween(logo, {y: logo.y + 1000}, 1.2, {ease: FlxEase.quadInOut, startDelay: 0.6});
		
		for (item in panelIntroItems)
			FlxTween.tween(item, {y: item.y + 1000}, 1.2, {ease: FlxEase.quadInOut, startDelay: 0.6});

		new FlxTimer().start(1.0, function(tmr:FlxTimer) {
			switchToSelection();
		});
	}

	function switchToSelection()
	{
		switch (curMenuItem)
		{
			case 0:
				MusicBeatState.switchState(new StoryMenuState());
			case 1:
				MusicBeatState.switchState(new FreeplayState());
			case 2:
				MusicBeatState.switchState(new CreditsState());
			case 3:
				MusicBeatState.switchState(new OptionsState());
				OptionsState.onPlayState = false;
			case 4:
				#if ACHIEVEMENTS_ALLOWED
				MusicBeatState.switchState(new AchievementsMenuState());
				#else
				MusicBeatState.switchState(new CreditsState());
				#end
		}
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
		{
			if (FlxG.sound.music.volume < 0.8) FlxG.sound.music.volume += 0.5 * elapsed;
			Conductor.songPosition = FlxG.sound.music.time;
		}

		if (controls.justPressed('debug_1')) {
			MusicBeatState.switchState(new MasterEditorMenu());
		}

		if (FlxG.keys.firstJustPressed() != FlxKey.NONE) mouseMode = false;
		if (FlxG.mouse.justMoved || FlxG.mouse.justPressed) mouseMode = true;

		if (!lockMovement && !introActive && mouseMode)
		{
			for (i in 0...menuButtons.length)
			{
				if (FlxG.mouse.overlaps(menuButtons[i]))
				{
					if (curMenuItem != i)
					{
						curMenuItem = i;
						updateMenuSelection();
					}
					if (FlxG.mouse.justPressed)
					{
						select();
					}
					break;
				}
			}
		}

		if (introActive)
		{
			introTimer -= elapsed;
			if (introTimer <= 0) introActive = false;
		}

		if (!lockMovement && !introActive)
		{
			var moved = false;
			if (controls.UI_UP_P)
			{
				final prev = curMenuItem;
				if (curMenuItem >= 3)
				{
					lastSmallBtn = curMenuItem;
					curMenuItem = 2;
				}
				else if (curMenuItem > 0) curMenuItem--;

				moved = curMenuItem != prev;
			}
			else if (controls.UI_DOWN_P)
			{
				final prev = curMenuItem;
				if (curMenuItem == 2) curMenuItem = lastSmallBtn;
				else if (curMenuItem < 2) curMenuItem++;

				moved = curMenuItem != prev;
			}
			else if (controls.UI_LEFT_P && curMenuItem == 4)
			{
				curMenuItem = 3;
				moved = true;
			}
			else if (controls.UI_RIGHT_P && curMenuItem == 3)
			{
				curMenuItem = 4;
				moved = true;
			}

			if (moved)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
				updateMenuSelection();
			}

			if (controls.ACCEPT) select();

			if (controls.BACK #if android || FlxG.android.justReleased.BACK #end)
			{
				lockMovement = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}
		}

		super.update(elapsed);
	}
}
