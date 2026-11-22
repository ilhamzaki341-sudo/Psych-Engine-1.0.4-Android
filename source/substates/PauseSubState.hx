package substates;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.FlxStringUtil;
import flixel.group.FlxSpriteGroup;

import states.StoryMenuState;
import states.FreeplayState;
import options.OptionsState;

class PauseSubState extends MusicBeatSubstate
{
	public static var instance:PauseSubState;
	public static var songName:String = null;

	var pauseMusic:FlxSound;
	var pauseGroup:FlxSpriteGroup;
	var options:Array<String> = ['Resume', 'Restart Song', 'Options', 'Exit to menu'];

	var pauseBG:FlxSprite;
	var optionText:Array<FlxText> = [];

	var curSelect:Int = 0;

	var viewingMode:Bool = false;
	var looksie:FlxSprite;
	var infoTitle:FlxText;
	var infoSubtext:FlxText;

	var holdTime:Float = 0;
	public var skipToTimeOption:Null<FlxText> = null;
	var skipToTime:Float;

	var touchStartY:Float = 0;
	var touchStartX:Float = 0;
	var isSwiping:Bool = false;

	override function create()
	{
		instance = this;

		var cam:FlxCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];

		pauseMusic = new FlxSound();
		try
		{
			var pauseSong:String = getPauseSong();
			if (pauseSong != null) pauseMusic.loadEmbedded(Paths.music(pauseSong), true, true);
		}
		catch (e:Dynamic) {}

		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
		FlxG.sound.list.add(pauseMusic);

		pauseGroup = new FlxSpriteGroup();
		pauseGroup.cameras = [cam];

		pauseBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		pauseBG.alpha = 0;
		pauseGroup.add(pauseBG);

		var glow:FlxSprite = new FlxSprite(500, -12.65);
		if (Paths.fileExists('images/menu/freeplay/backGlow.png', IMAGE))
			glow.loadGraphic(Paths.image('menu/freeplay/backGlow'));
		else
			glow.makeGraphic(1, 1, FlxColor.TRANSPARENT);

		glow.flipX = false;
		if (PlayState.instance != null && PlayState.instance.dad != null)
		{
			var arr:Array<Int> = PlayState.instance.dad.healthColorArray;
			if (arr != null && arr.length >= 3)
				glow.color = FlxColor.fromRGB(arr[0], arr[1], arr[2]);
		}
		pauseGroup.add(glow);
		
		if (songs.length > 0)
		{
			var songFormatted:String = Paths.formatToSongPath(songs[curSelected].songName);
			var imagePath:String = 'menu/freeplay/portraits/' + songFormatted;
			
			portrait = new FlxSprite(FlxG.width, -125);
			if (Paths.fileExists('images/' + imagePath + '.png', IMAGE))
			{
				portrait.loadGraphic(Paths.image(imagePath));
			}
			else if (Paths.fileExists('images/menu/freeplay/portraits/placeholder.png', IMAGE))
			{
				portrait.loadGraphic(Paths.image('menu/freeplay/portraits/placeholder'));
			}
			else
			{
				portrait.makeGraphic(1, 1, FlxColor.TRANSPARENT);
			}

			portrait.antialiasing = ClientPrefs.data.antialiasing;
			portrait.offset.x += (portrait.frameWidth - 1215) * 0.5 * portrait.scale.x;
			portrait.offset.y += (portrait.frameHeight - 1097) * 0.5 * portrait.scale.y;
			
			pauseGroup.add(portrait);

			FlxTween.tween(portrait, {x: 304.65}, 0.3, {ease: FlxEase.circOut});
		}

		var pad:Int = 15;

		var boldFont:String = Paths.fileExists('fonts/liberbold.ttf', FONT) ? Paths.font('liberbold.ttf') : Paths.font('vcr.ttf');
		var regFont:String = Paths.fileExists('fonts/liber.ttf', FONT) ? Paths.font('liber.ttf') : Paths.font('vcr.ttf');

		infoTitle = new FlxText(0, pad, FlxG.width - pad, '');
		infoTitle.setFormat(boldFont, 24, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pauseGroup.add(infoTitle);

		infoSubtext = new FlxText(0, 30 + pad, FlxG.width - pad, '');
		infoSubtext.setFormat(regFont, 24, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pauseGroup.add(infoSubtext);

		var songTitle:String = (PlayState.SONG != null) ? PlayState.SONG.song : 'Unknown';
		assignValues(getSongInfo(songTitle));

		if (PlayState.chartingMode)
		{
			options.insert(2, 'Skip Time');
			options.insert(3, 'Leave Charting Mode');
		}

		var scale:Float = Math.min(300 / (options.length * 60), 1);

		for (i in 0...options.length)
		{
			var opt = new FlxText(-640, 0, 0, Language.getPhrase(options[i], options[i]));

			if (options[i] == 'Skip Time') skipToTimeOption = opt;

			opt.setFormat(regFont, Std.int(48 * scale), FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			opt.borderSize = 2;
			opt.y = FlxG.height / 2 + (i * 60 * scale) - opt.height;
			opt.ID = i;
			pauseGroup.add(opt);
			optionText.push(opt);
		}

		looksie = new FlxSprite(0, FlxG.height - 100);
		if (Paths.fileExists('images/menu/pause/looksie.png', IMAGE))
			looksie.loadGraphic(Paths.image('menu/pause/looksie'));
		else
			looksie.makeGraphic(50, 50, FlxColor.WHITE);

		looksie.origin.set(25, 75);
		looksie.cameras = [cam];
		looksie.flipX = true;

		add(pauseGroup);
		add(looksie);
		cameras = [cam];

		skipToTime = Math.max(Conductor.songPosition, 0);
		updateSkipTimeOption();

		if (Paths.fileExists('sounds/panelAppear.ogg', SOUND))
			FlxG.sound.play(Paths.sound('panelAppear'), 0.5);

		super.create();
	}

	function getPauseSong():String
	{
		var formattedSongName:String = (songName != null ? Paths.formatToSongPath(songName) : '');
		var formattedPauseMusic:String = Paths.formatToSongPath(ClientPrefs.data.pauseMusic);
		if (formattedSongName == 'none' || (formattedSongName != 'none' && formattedPauseMusic == 'none')) return null;

		return (formattedSongName != '') ? formattedSongName : formattedPauseMusic;
	}

	function updateSkipTimeOption():Void
	{
		if (skipToTimeOption == null) return;

		final skipStr:String = Language.getPhrase('Skip Time', 'Skip Time');

		if (skipToTimeOption.ID != curSelect)
		{
			skipToTimeOption.text = skipStr;
			return;
		}

		var musicLength:Float = (FlxG.sound.music != null) ? FlxG.sound.music.length : 1000;
		final timeStr:String = FlxStringUtil.formatTime(skipToTime / 1000, false);
		final lengthStr:String = FlxStringUtil.formatTime(musicLength / 1000, false);

		skipToTimeOption.text = '$skipStr \t$timeStr / $lengthStr';
	}

	public function changeSkipTime(secs:Float):Void
	{
		if (skipToTimeOption == null || FlxG.sound.music == null) return;

		skipToTime = FlxMath.wrap(Std.int(skipToTime + secs * 1000), 0, Std.int(FlxG.sound.music.length));
		updateSkipTimeOption();
	}

	override function update(elapsed:Float)
	{
		if (pauseMusic != null && pauseMusic.volume < 0.5) pauseMusic.volume += 0.01 * elapsed;
		super.update(elapsed);

		var cam:FlxCamera = (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
		var pointerPos:FlxPoint = FlxG.mouse.getScreenPosition(cam);
		var justPressed:Bool = FlxG.mouse.justPressed;
		var justReleased:Bool = FlxG.mouse.justReleased;

		#if android
		var touch = FlxG.touches.getFirst();
		if (touch != null)
		{
			pointerPos = touch.getScreenPosition(cam);
			justPressed = touch.justPressed;
			justReleased = touch.justReleased;
		}
		#end

		if (justPressed)
		{
			touchStartX = pointerPos.x;
			touchStartY = pointerPos.y;
			isSwiping = false;
		}

		if (FlxG.mouse.pressed #if android || (FlxG.touches.getFirst() != null && FlxG.touches.getFirst().pressed) #end)
		{
			var diffY:Float = pointerPos.y - touchStartY;
			var diffX:Float = pointerPos.x - touchStartX;

			if (!viewingMode)
			{
				if (Math.abs(diffY) > 45)
				{
					changeSelection(diffY > 0 ? 1 : -1);
					touchStartY = pointerPos.y;
					isSwiping = true;
				}
				else if (options[curSelect] == 'Skip Time' && Math.abs(diffX) > 35)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					changeSkipTime(diffX > 0 ? 5 : -5);
					touchStartX = pointerPos.x;
					isSwiping = true;
				}
			}
		}

		if (!viewingMode)
		{
			if (options[curSelect] == 'Skip Time')
			{
				if (controls.UI_LEFT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					changeSkipTime(-1);
					holdTime = 0;
				}
				if (controls.UI_RIGHT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					changeSkipTime(1);
					holdTime = 0;
				}

				if (controls.UI_LEFT || controls.UI_RIGHT)
				{
					holdTime += elapsed;
					if (holdTime > 0.5)
					{
						changeSkipTime((controls.UI_LEFT ? -1 : 1) * (elapsed * 15));
					}
				}
			}

			if (controls.UI_UP_P || FlxG.mouse.wheel > 0) changeSelection(-1);
			if (controls.UI_DOWN_P || FlxG.mouse.wheel < 0) changeSelection(1);
			if (controls.ACCEPT) acceptChoice();
		}

		if (controls.BACK #if android || FlxG.android.justReleased.BACK #end)
		{
			if (viewingMode)
			{
				changeView(false);
			}
			else
			{
				if (Paths.fileExists('sounds/paneldisAppear.ogg', SOUND))
					FlxG.sound.play(Paths.sound('paneldisAppear'), 0.5);
				close();
			}
		}

		pauseBG.alpha = FlxMath.lerp(pauseBG.alpha, 0.8, FlxMath.bound(elapsed * 15.6, 0, 1)) * pauseGroup.alpha;

		var looksieHover:Bool = looksie.overlapsPoint(pointerPos, true, cam);
		var looksieScale:Float = FlxMath.lerp(looksie.scale.x, looksieHover ? 1.25 : 1, FlxMath.bound(elapsed * 15.6, 0, 1));
		looksie.scale.set(looksieScale, looksieScale);

		if (looksieHover && justReleased && !isSwiping)
		{
			changeView(!viewingMode);
		}

		pauseGroup.alpha = FlxMath.lerp(pauseGroup.alpha, viewingMode ? 0 : 1, FlxMath.bound(elapsed * 15.6, 0, 1));
		looksie.alpha = FlxMath.lerp(looksie.alpha, viewingMode ? 0.3 : 1, FlxMath.bound(elapsed * 15.6, 0, 1));

		for (item in optionText)
		{
			if (item.overlapsPoint(pointerPos, true, cam) && justReleased && !isSwiping && !viewingMode)
			{
				if (curSelect == item.ID)
				{
					acceptChoice();
				}
				else
				{
					curSelect = item.ID;
					changeSelection(0);
				}
			}

			item.x = FlxMath.lerp(item.x, curSelect == item.ID ? 75 : 55, FlxMath.bound(elapsed * 15.6, 0, 1));
			item.alpha = FlxMath.lerp(item.alpha, curSelect == item.ID ? 1 : 0.3, FlxMath.bound(elapsed * 15.6, 0, 1)) * pauseGroup.alpha;
		}
	}

	override function destroy()
	{
		if (pauseMusic != null) pauseMusic.destroy();
		super.destroy();
	}

	public static function getDadPortrait():String
	{
		if (PlayState.instance == null || PlayState.instance.dad == null) return 'placeholder';
		var character:String = PlayState.instance.dad.curCharacter;
		return (portraitExists(character) ? character : PlayState.instance.dad.healthIcon);
	}

	static function portraitExists(id:String):Bool
	{
		return Paths.fileExists('images/menu/freeplay/portraits/$id.png', IMAGE);
	}

	public static function getSongInfo(songID:String):Array<String>
	{
		var formattedSong:String = Paths.formatToSongPath(songID);
		var path:String = Paths.getPath('data/' + formattedSong + '/info.txt', TEXT);
		if (Paths.fileExists('data/' + formattedSong + '/info.txt', TEXT))
		{
			var info:Array<String> = CoolUtil.coolTextFile(path);
			if (info != null && info.length > 0) return info;
		}
		return [songID.toUpperCase(), 'DIFFICULTY: ' + Difficulty.getString().toUpperCase()];
	}

	function assignValues(info:Array<String>):Void
	{
		infoTitle.text = (info != null && info.length > 0) ? info[0] : 'UNKNOWN';
		if (info != null && info.length > 1)
		{
			infoSubtext.text = info[1] + (info.length > 2 ? '\n' + info[2] : '');
		}
		else
		{
			infoSubtext.text = '';
		}
	}

	function changeView(view:Bool):Void
	{
		if (Paths.fileExists('sounds/menu/looksie.ogg', SOUND))
			FlxG.sound.play(Paths.sound('menu/looksie'));
		viewingMode = view;
	}

	function changeSelection(by:Int = 0):Void
	{
		var snd:String = Paths.fileExists('sounds/hover.ogg', SOUND) ? 'hover' : 'scrollMenu';
		FlxG.sound.play(Paths.sound(snd), 0.5);
		curSelect = FlxMath.wrap(curSelect + by, 0, options.length - 1);
		updateSkipTimeOption();
	}

	function acceptChoice():Void
	{
		switch (options[curSelect])
		{
			case 'Resume':
				close();

			case 'Restart Song':
				restartSong();

			case 'Skip Time':
				if (skipToTime < Conductor.songPosition)
				{
					PlayState.startOnTime = skipToTime;
					restartSong(true);
				}
				else
				{
					if (skipToTime != Conductor.songPosition)
					{
						PlayState.instance.clearNotesBefore(skipToTime);
						PlayState.instance.setSongTime(skipToTime);
					}
					close();
				}

			case 'Leave Charting Mode':
				restartSong();
				PlayState.chartingMode = false;

			case 'Options':
				PlayState.instance.paused = true;
				PlayState.instance.vocals.volume = 0;
				MusicBeatState.switchState(new OptionsState());
				if (ClientPrefs.data.pauseMusic != 'None')
				{
					FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), pauseMusic.volume);
					FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
					FlxG.sound.music.time = pauseMusic.time;
				}
				OptionsState.onPlayState = true;

			case 'Exit to menu':
				returnToMain();
		}
	}

	public function returnToMain():Void
	{
		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		PlayState.deathCounter = 0;
		PlayState.seenCutscene = false;

		Mods.loadTopMod();
		if (PlayState.isStoryMode)
			MusicBeatState.switchState(new StoryMenuState());
		else
			MusicBeatState.switchState(new FreeplayState());

		FlxG.sound.playMusic(Paths.music('freakyMenu'));
		PlayState.changedDifficulty = false;
		PlayState.chartingMode = false;
		FlxG.camera.followLerp = 0;
	}

	public static function restartSong(noTrans:Bool = false)
	{
		PlayState.instance.paused = true;
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if (noTrans)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		MusicBeatState.resetState();
	}
}
