package states;

import flixel.addons.display.FlxBackdrop;
import backend.WeekData;
import backend.Highscore;
import backend.Song;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;
import openfl.display.BlendMode;

import openfl.utils.Assets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

import haxe.Json;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var accuracyText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpCards:FlxTypedGroup<FlxSprite>;
	private var grpSongs:FlxTypedGroup<FlxText>;
	private var grpNoteIcons:FlxTypedGroup<FlxSprite>;
	private var grpCredits:FlxTypedGroup<FlxText>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	var bg:FlxBackdrop;
	var glowBG:FlxSprite;
	var glowTween:FlxTween;
	var songFrame:FlxSprite;
	var frameTween:FlxTween;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	var spacingY:Float = 115;

	var lastTouchX:Float = 0;
	var lastTouchY:Float = 0;
	var isSwiping:Bool = false;
	var hasDragged:Bool = false;

	var freeplayCreditsMap:Map<String, String> = new Map();

	override function create()
	{
		//Paths.clearStoredMemory();
		//Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		final accept:String = (controls.mobileC) ? "A" : "ACCEPT";
		final reject:String = (controls.mobileC) ? "B" : "BACK";

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress " + accept + " to go to the Week Editor Menu.\nPress " + reject + " to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);

			for (j in 0...leWeek.songs.length)
			{
				addSong(leWeek.songs[j][0], i, leWeek.songs[j][1]);
			}
		}

		Mods.loadTopMod();
		loadFreeplayCredits();

		bg = new FlxBackdrop(Paths.image('menu/common/starFG'), X);
		bg.setGraphicSize(1280, 720);
		bg.updateHitbox();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		glowBG = new FlxSprite(0, 0);
		if (Paths.fileExists('images/menu/freeplay/glow.png', IMAGE))
		{
			glowBG.loadGraphic(Paths.image('menu/freeplay/glow'));
		}
		else
		{
			glowBG.makeGraphic(650, 650, FlxColor.WHITE);
		}
		glowBG.updateHitbox();
		glowBG.x = FlxG.width - glowBG.width;
		glowBG.y = FlxG.height - glowBG.height;
		glowBG.blend = BlendMode.ADD;
		glowBG.alpha = 0.85;
		glowBG.antialiasing = ClientPrefs.data.antialiasing;
		add(glowBG);
		
		songFrame = new FlxSprite(0, 0);
		songFrame.antialiasing = ClientPrefs.data.antialiasing;
		add(songFrame);

		grpCards = new FlxTypedGroup<FlxSprite>();
		add(grpCards);
		
		grpSongs = new FlxTypedGroup<FlxText>();
		add(grpSongs);

		grpNoteIcons = new FlxTypedGroup<FlxSprite>();
		add(grpNoteIcons);

		grpCredits = new FlxTypedGroup<FlxText>();
		add(grpCredits);

		var hasCardAsset:Bool = Paths.fileExists('images/menu/freeplay/card.png', IMAGE);
		var hasNoteAsset:Bool = Paths.fileExists('images/menu/freeplay/musicNote.png', IMAGE);

		for (i in 0...songs.length)
		{
			Mods.currentModDirectory = songs[i].folder;

			var card:FlxSprite = new FlxSprite(0, 320);
			if (hasCardAsset)
			{
				card.loadGraphic(Paths.image('menu/freeplay/card'));
				card.setGraphicSize(490, 96);
				card.updateHitbox();
			}
			else
			{
				card.makeGraphic(490, 96, 0xFF7B9BA0);
			}
			card.antialiasing = ClientPrefs.data.antialiasing;
			card.visible = card.active = false;
			grpCards.add(card);

			var songText:FlxText = new FlxText(0, 320, 340, songs[i].songName, 34);
			songText.setFormat(Paths.font("vcr.ttf"), 34, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			songText.borderSize = 2.2;
			songText.antialiasing = ClientPrefs.data.antialiasing;
			songText.ID = i;
			songText.visible = songText.active = false;
			grpSongs.add(songText);

			var creditStr:String = getSongCredit(songs[i]);

			var noteIcon:FlxSprite = new FlxSprite(0, 320);
			if (hasNoteAsset)
			{
				noteIcon.loadGraphic(Paths.image('menu/freeplay/musicNote'));
				noteIcon.setGraphicSize(18, 22);
				noteIcon.updateHitbox();
			}
			else
			{
				noteIcon.makeGraphic(14, 18, FlxColor.WHITE);
			}
			noteIcon.antialiasing = ClientPrefs.data.antialiasing;
			noteIcon.visible = noteIcon.active = false;
			grpNoteIcons.add(noteIcon);

			var creditText:FlxText = new FlxText(0, 320, 315, creditStr, 20);
			creditText.setFormat(Paths.font("vcr.ttf"), 20, 0xFFE8F4F8, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			creditText.borderSize = 1.6;
			creditText.antialiasing = ClientPrefs.data.antialiasing;
			creditText.visible = creditText.active = false;
			grpCredits.add(creditText);

			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.visible = icon.active = false;

			iconArray.push(icon);
			add(icon);
		}
		WeekData.setDirectoryFromWeek();
		
		scoreBG = new FlxSprite(0, 0).makeGraphic(1, 108, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		scoreText = new FlxText(-14, 8, FlxG.width, "", 30);
		scoreText.setFormat(Paths.font("vcr.ttf"), 30, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreText.borderSize = 1.5;
		add(scoreText);

		accuracyText = new FlxText(-14, 42, FlxG.width, "", 28);
		accuracyText.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		accuracyText.borderSize = 1.5;
		add(accuracyText);

		diffText = new FlxText(0, 76, 0, "", 24);
		diffText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		diffText.borderSize = 1.5;
		add(diffText);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		final space:String = (controls.mobileC) ? "X" : "SPACE";
		final control:String = (controls.mobileC) ? "C" : "CTRL";
		final reset:String = (controls.mobileC) ? "Y" : "RESET";
		
		var leText:String = Language.getPhrase("freeplay_tip", "Press {1} to listen to the Song / Press {2} to open the Gameplay Changers Menu / Press {3} to Reset your Score and Accuracy.", [space, control, reset]);
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);
		
		lerpSelected = curSelected;
		changeSelection();
		updateTexts(0);

		FlxG.mouse.visible = true;
		addTouchPad('NONE', 'A_B_C_X_Y_Z');
		super.create();
	}

	function loadFreeplayCredits()
	{
		freeplayCreditsMap.clear();
		var pathsToCheck:Array<String> = [
			Paths.getPath('stages/credits/freeplayCredits.json', TEXT),
			'assets/stages/credits/freeplayCredits.json'
		];

		#if MODS_ALLOWED
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			pathsToCheck.unshift(Paths.mods(Mods.currentModDirectory + '/stages/credits/freeplayCredits.json'));
		pathsToCheck.unshift(Paths.mods('stages/credits/freeplayCredits.json'));
		#end

		for (p in pathsToCheck)
		{
			if (p == null) continue;
			try
			{
				var rawJson:String = null;
				#if sys
				if (FileSystem.exists(p))
					rawJson = File.getContent(p);
				#end
				if (rawJson == null && Assets.exists(p))
					rawJson = Assets.getText(p);

				if (rawJson != null && rawJson.length > 0)
				{
					var parsed:Dynamic = Json.parse(rawJson);
					for (field in Reflect.fields(parsed))
					{
						var val:Dynamic = Reflect.field(parsed, field);
						if (val != null)
							freeplayCreditsMap.set(Paths.formatToSongPath(field), Std.string(val));
					}
					break;
				}
			}
			catch (e:Dynamic) {}
		}
	}

	function getSongCredit(meta:SongMetadata):String
	{
		var formatted:String = Paths.formatToSongPath(meta.songName);
		if (freeplayCreditsMap.exists(formatted))
			return freeplayCreditsMap.get(formatted);

		try
		{
			var songPath:String = Paths.json(formatted + '/' + formatted);
			var rawJson:String = null;
			#if sys
			if (FileSystem.exists(songPath))
				rawJson = File.getContent(songPath);
			#end
			if (rawJson == null && Assets.exists(songPath))
				rawJson = Assets.getText(songPath);

			if (rawJson != null && rawJson.length > 0)
			{
				var parsed:Dynamic = Json.parse(rawJson);
				var songObj:Dynamic = Reflect.hasField(parsed, "song") ? Reflect.field(parsed, "song") : parsed;
				if (songObj != null)
				{
					if (Reflect.hasField(songObj, "composer") && Reflect.field(songObj, "composer") != null)
						return Std.string(Reflect.field(songObj, "composer"));
					if (Reflect.hasField(songObj, "credit") && Reflect.field(songObj, "credit") != null)
						return Std.string(Reflect.field(songObj, "credit"));
					if (Reflect.hasField(songObj, "credits") && Reflect.field(songObj, "credits") != null)
						return Std.string(Reflect.field(songObj, "credits"));
				}
			}
		}
		catch (e:Dynamic) {}

		return "";
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
		removeTouchPad();
		addTouchPad('NONE', 'A_B_C_X_Y_Z');
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;
	override function update(elapsed:Float)
	{
		if(WeekData.weeksList.length < 1)
			return;

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2)
			ratingSplit.push('');
		
		while(ratingSplit[1].length < 2)
			ratingSplit[1] += '0';

		var shiftMult:Int = 1;
		if((FlxG.keys.pressed.SHIFT || touchPad.buttonZ.pressed) && !player.playingMusic) shiftMult = 3;

		if (!player.playingMusic)
		{
			scoreText.text = Language.getPhrase('freeplay_score', 'Score: {1}', [formatScore(lerpScore)]);
			accuracyText.text = Language.getPhrase('freeplay_accuracy', 'Accuracy: {1}%', [ratingSplit.join('.')]);
			positionHighscore();
			
			if(songs.length > 1)
			{
				if(FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;	
				}
				else if(FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;	
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}

				#if mobile
				var touch = FlxG.touches.getFirst();
				if (touch != null)
				{
					if (touch.justPressed)
					{
						lastTouchX = touch.screenX;
						lastTouchY = touch.screenY;
						isSwiping = true;
						hasDragged = false;
					}
					else if (touch.pressed && isSwiping)
					{
						var dx:Float = touch.screenX - lastTouchX;
						var dy:Float = touch.screenY - lastTouchY;
						if (Math.abs(dy) > 42)
						{
							changeSelection(dy < 0 ? 1 : -1);
							lastTouchY = touch.screenY;
							lastTouchX = touch.screenX;
							hasDragged = true;
						}
						else if (Math.abs(dx) > 65)
						{
							changeDiff(dx < 0 ? -1 : 1);
							_updateSongLastDifficulty();
							lastTouchX = touch.screenX;
							lastTouchY = touch.screenY;
							hasDragged = true;
						}
					}
					else if (touch.justReleased)
					{
						isSwiping = false;
					}
				}
				#end
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		bg.x -= 9 * elapsed;
		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else 
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}

		if (!player.playingMusic && FlxG.mouse.justReleased && !hasDragged)
		{
			for (i in _lastVisibles)
			{
				var card:FlxSprite = grpCards.members[i];
				if (card != null && card.visible && FlxG.mouse.overlaps(card))
				{
					if (i == curSelected)
					{
						confirmSong();
					}
					else
					{
						changeSelection(i - curSelected);
						holdTime = 0;
					}
					break;
				}
			}
		}

		if((FlxG.keys.justPressed.CONTROL || touchPad.buttonC.justPressed) && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
			removeTouchPad();
		}
		else if(FlxG.keys.justPressed.SPACE || touchPad.buttonX.justPressed)
		{
			if(instPlaying != curSelected && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
				if (PlayState.SONG.needsVoices)
				{
					vocals = new FlxSound();
					try
					{
						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
						if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							vocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(vocals);
							vocals.persist = vocals.looped = true;
							vocals.volume = 0.8;
							vocals.play();
							vocals.pause();
						}
						else vocals = FlxDestroyUtil.destroy(vocals);
					}
					catch(e:Dynamic)
					{
						vocals = FlxDestroyUtil.destroy(vocals);
					}
					
					opponentVocals = new FlxSound();
					try
					{
						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							opponentVocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(opponentVocals);
							opponentVocals.persist = opponentVocals.looped = true;
							opponentVocals.volume = 0.8;
							opponentVocals.play();
							opponentVocals.pause();
						}
						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch(e:Dynamic)
					{
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
				}

				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

				player.playingMusic = true;
				player.curTime = 0;
				player.switchPlayMusic();
				player.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			confirmSong();
		}
		else if((controls.RESET || touchPad.buttonY.justPressed) && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			removeTouchPad();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		
		updateTexts(elapsed);
		super.update(elapsed);
	}

	function confirmSong()
	{
		persistentUpdate = false;
		var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
		var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

		try
		{
			Song.loadFromJson(poop, songLowercase);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = curDifficulty;

			trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
		}
		catch(e:haxe.Exception)
		{
			trace('ERROR! ${e.message}');

			var errorStr:String = e.message;
			if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1);
			else errorStr += '\n\n' + e.stack;

			missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
			missingText.screenCenter(Y);
			missingText.visible = true;
			missingTextBG.visible = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		@:privateAccess
		if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
		{
			trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
			Paths.freeGraphicsFromMemory();
		}
		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
		#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
		stopMusicPlay = true;

		destroyFreeplayVocals();
		#if (MODS_ALLOWED && DISCORD_ALLOWED)
		DiscordClient.loadModRPC();
		#end
	}
	
	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	function getHealthColorFromCharacter(char:String):FlxColor
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			var rawJson:String = null;
			#if MODS_ALLOWED
			if (FileSystem.exists(path))
				rawJson = File.getContent(path);
			#end
			if (rawJson == null && Assets.exists(path))
				rawJson = Assets.getText(path);

			if (rawJson != null && rawJson.length > 0)
			{
				var character:Dynamic = Json.parse(rawJson);
				if (character != null && character.healthbar_colors != null && character.healthbar_colors.length >= 3)
				{
					return FlxColor.fromRGB(
						Std.int(character.healthbar_colors[0]),
						Std.int(character.healthbar_colors[1]),
						Std.int(character.healthbar_colors[2])
					);
				}
			}
		}
		catch (e:Dynamic) {}
		return 0xFF7B9BA0;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var rawDiff:String = Difficulty.getString(curDifficulty);
		var diffKey:String = 'difficulty_' + Paths.formatToSongPath(rawDiff);
		var displayDiff:String = Language.getPhrase(diffKey, rawDiff).toUpperCase();

		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff + ' >';
		else
			diffText.text = displayDiff;

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;
		
		curSelected = Std.int(FlxMath.bound(curSelected + change, 0, songs.length - 1));
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		Mods.currentModDirectory = songs[curSelected].folder;

		var targetGlowColor:FlxColor = getHealthColorFromCharacter(songs[curSelected].songCharacter);
		if (glowTween != null)
		{
			glowTween.cancel();
		}
		glowTween = FlxTween.color(glowBG, 0.35, glowBG.color, targetGlowColor, {
			ease: FlxEase.quartOut,
			onComplete: function(twn:FlxTween) {
				glowTween = null;
			}
		});

		var songFormatted:String = Paths.formatToSongPath(songs[curSelected].songName);
		var imagePath:String = 'menu/freeplay/portraits/' + songFormatted;

		if (!Paths.fileExists('images/' + imagePath + '.png', IMAGE)) {
			imagePath = 'menu/freeplay/portraits/placeholder';
		}

		songFrame.loadGraphic(Paths.image(imagePath));
		songFrame.scale.set(1, 1);
		songFrame.updateHitbox();
		songFrame.y = (FlxG.height - songFrame.height) / 2;

		if (frameTween != null) {
			frameTween.cancel();
		}

		var targetX:Float = FlxG.width - songFrame.width + 5;
		songFrame.x = targetX + 150;
		songFrame.alpha = 0;

		frameTween = FlxTween.tween(songFrame, {x: targetX, alpha: 1}, 0.25, {
			ease: FlxEase.quartOut,
			onComplete: function(twn:FlxTween) {
				frameTween = null;
			}
		});
		
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();
		
		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(savedDiff != null && Difficulty.list.contains(savedDiff))
			curDifficulty = Difficulty.list.indexOf(savedDiff);
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

	private function formatScore(val:Int):String
	{
		var str:String = Std.string(val);
		var res:String = "";
		var count:Int = 0;
		var i:Int = str.length - 1;
		while (i >= 0)
		{
			res = str.charAt(i) + res;
			count++;
			if (count % 3 == 0 && i > 0 && str.charAt(i - 1) != '-')
				res = "," + res;
			i--;
		}
		return res;
	}

	private function positionHighscore()
	{
		var scoreW:Float = scoreText.textField.textWidth;
		var accW:Float = accuracyText.textField.textWidth;
		var diffW:Float = diffText.textField.textWidth;
		var maxW:Float = Math.max(Math.max(scoreW, accW), diffW);

		var boxWidth:Float = Math.max(240, maxW + 32);
		scoreBG.setGraphicSize(Std.int(boxWidth), 108);
		scoreBG.updateHitbox();
		scoreBG.x = FlxG.width - scoreBG.width;

		scoreText.x = -14;
		accuracyText.x = -14;
		diffText.x = scoreBG.x + (scoreBG.width - diffText.width) / 2;
	}

	var _drawDistance:Int = 5;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 10.5));
		for (i in _lastVisibles)
		{
			if (grpCards.members[i] != null) grpCards.members[i].visible = grpCards.members[i].active = false;
			if (grpSongs.members[i] != null) grpSongs.members[i].visible = grpSongs.members[i].active = false;
			if (grpNoteIcons.members[i] != null) grpNoteIcons.members[i].visible = grpNoteIcons.members[i].active = false;
			if (grpCredits.members[i] != null) grpCredits.members[i].visible = grpCredits.members[i].active = false;
			if (iconArray[i] != null) iconArray[i].visible = iconArray[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var card:FlxSprite = grpCards.members[i];
			var item:FlxText = grpSongs.members[i];
			var noteIcon:FlxSprite = grpNoteIcons.members[i];
			var credit:FlxText = grpCredits.members[i];
			var icon:HealthIcon = iconArray[i];

			var diff:Float = i - lerpSelected;
			var absDiff:Float = Math.abs(diff);

			var targetScale:Float = Math.max(0.65, 1.0 - (absDiff * 0.1));
			var targetAlpha:Float = (i == curSelected) ? 1.0 : Math.max(0.45, 1.0 - (absDiff * 0.22));

			var centerY:Float = (FlxG.height * 0.47) + (diff * spacingY);
			var targetCardX:Float = 95 - (Math.pow(absDiff, 1.35) * 42);

			card.visible = card.active = true;
			card.scale.set(targetScale, targetScale);
			card.updateHitbox();
			card.alpha = targetAlpha;

			var targetCardY:Float = centerY - (card.height / 2);
			card.x = (elapsed > 0) ? FlxMath.lerp(card.x, targetCardX, Math.exp(-elapsed * 14)) : targetCardX;
			card.y = (elapsed > 0) ? FlxMath.lerp(card.y, targetCardY, Math.exp(-elapsed * 14)) : targetCardY;

			if (icon != null)
			{
				icon.visible = icon.active = true;
				icon.alpha = targetAlpha;
				icon.scale.set(targetScale * 0.56, targetScale * 0.56);
				icon.updateHitbox();
				icon.x = card.x + (18 * targetScale);
				icon.y = card.y + (card.height - icon.height) / 2;
			}

			var hasCredit:Bool = (credit != null && credit.text != null && credit.text.length > 0);
			var textStartX:Float = card.x + (128 * targetScale);

			item.visible = item.active = true;
			item.alpha = targetAlpha;
			item.scale.set(targetScale, targetScale);
			item.updateHitbox();
			item.x = textStartX;
			if (hasCredit)
				item.y = card.y + (16 * targetScale);
			else
				item.y = card.y + (card.height - item.height) / 2;

			if (credit != null && noteIcon != null)
			{
				if (hasCredit)
				{
					noteIcon.visible = noteIcon.active = true;
					noteIcon.alpha = targetAlpha;
					noteIcon.scale.set(targetScale, targetScale);
					noteIcon.updateHitbox();
					noteIcon.x = textStartX;
					noteIcon.y = card.y + (55 * targetScale);

					credit.visible = credit.active = true;
					credit.alpha = targetAlpha;
					credit.scale.set(targetScale, targetScale);
					credit.updateHitbox();
					credit.x = noteIcon.x + noteIcon.width + (6 * targetScale);
					credit.y = card.y + (54 * targetScale);
				}
				else
				{
					noteIcon.visible = noteIcon.active = false;
					credit.visible = credit.active = false;
				}
			}
			
			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}	
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}
