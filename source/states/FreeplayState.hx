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
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxStringUtil;
import openfl.display.BlendMode;

import openfl.utils.Assets;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

import haxe.Json;

typedef FreeplayCategory = {
	var title:String;
	var fileName:String;
	var index:Int;
	var weeks:Array<String>;
}

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];
	var categories:Array<FreeplayCategory> = [];
	private static var curCategory:Int = 0;
	var smoothCategory:Float = 0;

	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	// UI & Tabs ala Impostor Legacy
	var topBar:FlxSprite;
	var sectionText:FlxText;
	var grpCategoryTabs:FlxTypedGroup<FlxSprite>;
	var menuBack:FlxSprite;

	// Score & Difficulty (Public untuk kompatibilitas MusicPlayer.hx Psych Engine 1.0.4)
	public var scoreBG:FlxSprite;
	public var scoreText:FlxText;
	public var diffText:FlxText;
	var infoText:FlxText;
	var lerpScore:Float = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	// Cards Group
	private var grpCards:FlxTypedGroup<FlxSprite>;
	private var grpSongs:FlxTypedGroup<FlxText>;
	private var grpNoteIcons:FlxTypedGroup<FlxSprite>;
	private var grpCredits:FlxTypedGroup<FlxText>;
	private var iconArray:Array<HealthIcon> = [];

	// Background & Portraits
	var bg:FlxBackdrop;
	var porGlow:FlxSprite;
	var glowTween:FlxTween;
	var portrait:FlxSprite;
	var portraitTween:FlxTween;
	var portraitAlphaTween:FlxTween;
	var prevPort:String = '';

	// Konstanta Tata Letak VS Impostor Legacy
	final CARD_X:Float = 70;
	final CARD_Y:Float = (FlxG.height * 0.45);
	final TAB_DISTANCE:Float = 320;
	final TAB_RADIUS:Float = 5.3;
	final CARD_DISTANCE:Float = 117;
	final CARD_X_SHIFT:Float = -70;
	final CARD_FADE:Float = 0.25;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	var lastTouchX:Float = 0;
	var lastTouchY:Float = 0;
	var isSwiping:Bool = false;
	var hasDragged:Bool = false;

	var freeplayCreditsMap:Map<String, String> = new Map();

	var boldFont:String;
	var regFont:String;
	var sectionFont:String;

	override function create()
	{
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Freeplay Menu", null);
		#end

		final accept:String = "ACCEPT";
		final reject:String = "BACK";

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress " + accept + " to go to the Week Editor Menu.\nPress " + reject + " to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		boldFont = Paths.fileExists('fonts/liberbold.ttf', FONT) ? Paths.font('liberbold.ttf') : Paths.font('vcr.ttf');
		regFont = Paths.fileExists('fonts/liber.ttf', FONT) ? Paths.font('liber.ttf') : Paths.font('vcr.ttf');
		sectionFont = Paths.fileExists('fonts/AmaticSC-Bold.ttf', FONT) ? Paths.font('AmaticSC-Bold.ttf') : boldFont;

		Mods.loadTopMod();
		loadFreeplayCategories();
		loadFreeplayCredits();

		if (curCategory >= categories.length) curCategory = 0;
		smoothCategory = curCategory;

		bg = new FlxBackdrop(Paths.image('menu/common/starFG'), X);
		bg.setGraphicSize(1280, 720);
		bg.updateHitbox();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		// Portrait Glow & Character Portrait (Koordinat Impostor Legacy)
		porGlow = new FlxSprite(-11.1 + 496, -12.65);
		if (Paths.fileExists('images/menu/freeplay/backGlow.png', IMAGE))
			porGlow.loadGraphic(Paths.image('menu/freeplay/backGlow'));
		else if (Paths.fileExists('images/menu/freeplay/Backglow.png', IMAGE))
			porGlow.loadGraphic(Paths.image('menu/freeplay/Backglow'));
		else
			porGlow.makeGraphic(780, 740, FlxColor.WHITE);
		porGlow.blend = BlendMode.ADD;
		porGlow.antialiasing = ClientPrefs.data.antialiasing;
		add(porGlow);

		portrait = new FlxSprite(304.65, -100);
		portrait.antialiasing = ClientPrefs.data.antialiasing;
		add(portrait);

		// Grup Kartu Lagu
		grpCards = new FlxTypedGroup<FlxSprite>();
		add(grpCards);
		
		grpSongs = new FlxTypedGroup<FlxText>();
		add(grpSongs);

		grpNoteIcons = new FlxTypedGroup<FlxSprite>();
		add(grpNoteIcons);

		grpCredits = new FlxTypedGroup<FlxText>();
		add(grpCredits);

		// Upper Bar & Tab Kategori Carousel
		topBar = new FlxSprite(0, 0);
		if (Paths.fileExists('images/menu/common/topBar.png', IMAGE))
			topBar.loadGraphic(Paths.image('menu/common/topBar'));
		else if (Paths.fileExists('images/menu/freeplay/topBar.png', IMAGE))
			topBar.loadGraphic(Paths.image('menu/freeplay/topBar'));
		else
			topBar.makeGraphic(FlxG.width, 82, 0xFF9FB0BF);
		topBar.setGraphicSize(FlxG.width, 82);
		topBar.updateHitbox();
		topBar.scrollFactor.set();
		topBar.antialiasing = ClientPrefs.data.antialiasing;
		add(topBar);

		grpCategoryTabs = new FlxTypedGroup<FlxSprite>();
		add(grpCategoryTabs);
		buildCategoryTabs();

		// Judul Section di Tengah Atas (Gaya AmaticSC Impostor)
		sectionText = new FlxText(0, 82, FlxG.width, '---', 64);
		sectionText.setFormat(sectionFont, 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		sectionText.borderSize = 3;
		sectionText.antialiasing = ClientPrefs.data.antialiasing;
		add(sectionText);

		// Dummy transparan untuk kompatibilitas MusicPlayer.hx
		scoreBG = new FlxSprite(0, 82).makeGraphic(1, 1, 0x00000000);
		scoreBG.alpha = 0;
		add(scoreBG);

		scoreText = new FlxText(0, 91, 1, '', 1);
		scoreText.alpha = 0;
		add(scoreText);

		// Info Skor & Difficulty (Tanpa kotak hitam, rata kanan ala Impostor)
		infoText = new FlxText(0, 91, FlxG.width - 14, '', 34);
		infoText.setFormat(regFont, 34, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.borderSize = 2;
		infoText.antialiasing = ClientPrefs.data.antialiasing;
		add(infoText);

		diffText = new FlxText(0, 172, FlxG.width - 14, '', 24);
		diffText.setFormat(boldFont, 24, 0xFFFFD800, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		diffText.borderSize = 1.8;
		diffText.antialiasing = ClientPrefs.data.antialiasing;
		add(diffText);

		// Tombol Back di Kiri Atas
		menuBack = new FlxSprite(22, 10);
		if (Paths.fileExists('images/menu/common/menuBack.png', IMAGE))
		{
			menuBack.loadGraphic(Paths.image('menu/common/menuBack'));
		}
		else
		{
			menuBack.makeGraphic(62, 62, FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawCircle(menuBack, 31, 31, 29, 0xFF33393D);
			FlxSpriteUtil.drawCircle(menuBack, 31, 31, 24, 0xFFD9DEE1);
			FlxSpriteUtil.drawCircle(menuBack, 31, 31, 19, 0xFFF3F5F6);
			FlxSpriteUtil.drawLine(menuBack, 22, 22, 40, 40, {color: 0xFF23272A, thickness: 5});
			FlxSpriteUtil.drawLine(menuBack, 40, 22, 22, 40, {color: 0xFF23272A, thickness: 5});
		}
		menuBack.updateHitbox();
		menuBack.y = (topBar.height - menuBack.height) / 2;
		menuBack.scrollFactor.set();
		menuBack.antialiasing = ClientPrefs.data.antialiasing;
		add(menuBack);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(regFont, 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		final space:String = "SPACE";
		final control:String = "CTRL";
		final reset:String = "RESET";
		
		var leText:String = Language.getPhrase("freeplay_tip", "Press {1} to listen to the Song / Press {2} to open the Gameplay Changers Menu / Press {3} to Reset your Score and Accuracy.", [space, control, reset]);
		bottomString = leText;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, 16);
		bottomText.setFormat(regFont, 16, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);

		selectCategory(curCategory, true);

		FlxG.mouse.visible = true;
		super.create();
	}

	function loadFreeplayCategories()
	{
		categories = [];
		var foldersToScan:Array<String> = [];

		#if MODS_ALLOWED
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToScan.push(Paths.mods(Mods.currentModDirectory + '/weeks/freeplay'));
		foldersToScan.push(Paths.mods('weeks/freeplay'));
		#end
		foldersToScan.push(Paths.getPath('weeks/freeplay', TEXT));
		foldersToScan.push('assets/weeks/freeplay');

		var loadedFiles:Map<String, Bool> = new Map();

		for (folder in foldersToScan)
		{
			if (folder == null) continue;
			#if sys
			if (FileSystem.exists(folder) && FileSystem.isDirectory(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if (file.endsWith('.json') && !loadedFiles.exists(file))
					{
						loadedFiles.set(file, true);
						var cleanName:String = file.substr(0, file.length - 5);
						parseCategoryFile(folder + '/' + file, cleanName);
					}
				}
			}
			#end
		}

		if (categories.length == 0)
		{
			categories.push({
				title: "FREEPLAY",
				fileName: "freeplay",
				index: 0,
				weeks: WeekData.weeksList.copy()
			});
		}
		else
		{
			categories.sort(function(a:FreeplayCategory, b:FreeplayCategory):Int {
				return a.index - b.index;
			});
		}
	}

	function parseCategoryFile(filePath:String, fileName:String)
	{
		try
		{
			var rawJson:String = null;
			#if sys
			if (FileSystem.exists(filePath))
				rawJson = File.getContent(filePath);
			#end
			if (rawJson == null && Assets.exists(filePath))
				rawJson = Assets.getText(filePath);

			if (rawJson != null && rawJson.length > 0)
			{
				var parsed:Dynamic = Json.parse(rawJson);
				var title:String = Reflect.hasField(parsed, "Title") ? Std.string(Reflect.field(parsed, "Title")) : "Freeplay";
				var idx:Int = Reflect.hasField(parsed, "Index") ? Std.parseInt(Std.string(Reflect.field(parsed, "Index"))) : categories.length;
				var weekList:Array<String> = [];

				if (Reflect.hasField(parsed, "week"))
				{
					var rawWeek:Dynamic = Reflect.field(parsed, "week");
					if (Std.isOfType(rawWeek, Array))
					{
						var arr:Array<Dynamic> = cast rawWeek;
						for (w in arr)
							weekList.push(Std.string(w));
					}
					else if (rawWeek != null)
					{
						weekList.push(Std.string(rawWeek));
					}
				}

				categories.push({
					title: title,
					fileName: fileName,
					index: idx,
					weeks: weekList
				});
			}
		}
		catch (e:Dynamic)
		{
			trace('Error parsing freeplay category JSON ($filePath): $e');
		}
	}

	function buildCategoryTabs()
	{
		grpCategoryTabs.clear();
		if (categories.length == 0) return;

		var tabSize:Float = 71;
		var hasTabAsset:Bool = Paths.fileExists('images/menu/freeplay/sections/blank.png', IMAGE);

		for (i in 0...categories.length)
		{
			var firstWord:String = categories[i].title.split(' ')[0].toLowerCase();
			var candidates:Array<String> = [
				'menu/freeplay/sections/' + categories[i].fileName,
				'menu/freeplay/sections/' + categories[i].fileName.toLowerCase(),
				'menu/freeplay/sections/' + categories[i].title.toLowerCase(),
				'menu/freeplay/sections/' + firstWord,
				'menu/freeplay/sections/' + categories[i].index,
				'menu/freeplay/sections/icon-' + categories[i].index
			];

			var foundIconPath:String = null;
			for (cand in candidates)
			{
				if (Paths.fileExists('images/' + cand + '.png', IMAGE))
				{
					foundIconPath = cand;
					break;
				}
			}

			var tab:FlxSprite = new FlxSprite(0, (topBar.height - tabSize) * 0.5);
			if (foundIconPath != null)
			{
				tab.loadGraphic(Paths.image(foundIconPath));
				tab.setGraphicSize(-1, Std.int(tabSize));
				tab.updateHitbox();
			}
			else if (hasTabAsset)
			{
				tab.loadGraphic(Paths.image('menu/freeplay/sections/blank'));
				tab.setGraphicSize(Std.int(tabSize), Std.int(tabSize));
				tab.updateHitbox();
			}
			else
			{
				tab.makeGraphic(Std.int(tabSize), Std.int(tabSize), FlxColor.TRANSPARENT, true);
				FlxSpriteUtil.drawRoundRect(tab, 0, 0, tabSize, tabSize, 16, 16, 0xFF49545E);
				FlxSpriteUtil.drawRoundRect(tab, 4, 4, tabSize - 8, tabSize - 8, 12, 12, 0xFFD9DEE1);
			}
			tab.ID = i;
			tab.scrollFactor.set();
			tab.antialiasing = ClientPrefs.data.antialiasing;
			grpCategoryTabs.add(tab);
		}
	}

	function selectCategory(catIdx:Int, isInitial:Bool = false)
	{
		if (categories.length == 0) return;

		var prevCat:Int = curCategory;
		curCategory = FlxMath.wrap(catIdx, 0, categories.length - 1);
		var activeCat:FreeplayCategory = categories[curCategory];

		if (isInitial)
		{
			smoothCategory = curCategory;
		}
		else
		{
			FlxTween.cancelTweensOf(this, ['smoothCategory']);
			FlxTween.tween(this, {smoothCategory: curCategory}, 0.3, {ease: FlxEase.quartOut});
			if (prevCat != curCategory)
			{
				var soundName:String = (catIdx > prevCat) ? 'panelAppear' : 'panelDisappear';
				if (Paths.fileExists('sounds/' + soundName + '.ogg', SOUND))
					FlxG.sound.play(Paths.sound(soundName), 0.5);
				else
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
			}
		}

		if (sectionText != null)
			sectionText.text = activeCat.title;

		songs = [];
		grpCards.clear();
		grpSongs.clear();
		grpNoteIcons.clear();
		grpCredits.clear();
		for (icon in iconArray)
		{
			if (icon != null)
			{
				remove(icon);
				icon.destroy();
			}
		}
		iconArray = [];
		_lastVisibles = [];

		for (weekName in activeCat.weeks)
		{
			var weekIndex:Int = WeekData.weeksList.indexOf(weekName);
			if (weekIndex == -1) continue;
			if (weekIsLocked(weekName)) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(weekName);
			if (leWeek != null)
			{
				for (j in 0...leWeek.songs.length)
				{
					addSong(leWeek.songs[j][0], weekIndex, leWeek.songs[j][1]);
				}
			}
		}

		var hasCardAsset:Bool = Paths.fileExists('images/menu/freeplay/card.png', IMAGE);
		var hasNoteAsset:Bool = Paths.fileExists('images/menu/freeplay/musicNote.png', IMAGE);

		for (i in 0...songs.length)
		{
			Mods.currentModDirectory = songs[i].folder;

			var card:FlxSprite = new FlxSprite(CARD_X - 700, CARD_Y);
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

			var songText:FlxText = new FlxText(0, CARD_Y, 340, songs[i].songName, 34);
			songText.setFormat(boldFont, 34, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			songText.borderSize = 2.2;
			songText.antialiasing = ClientPrefs.data.antialiasing;
			songText.ID = i;
			songText.visible = songText.active = false;
			grpSongs.add(songText);

			var creditStr:String = getSongCredit(songs[i]);

			var noteIcon:FlxSprite = new FlxSprite(0, CARD_Y);
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

			var creditText:FlxText = new FlxText(0, CARD_Y, 315, creditStr, 20);
			creditText.setFormat(regFont, 20, 0xFFE8F4F8, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
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

		if (!isInitial)
			curSelected = 0;
		else if (curSelected >= songs.length)
			curSelected = 0;

		lerpSelected = curSelected;

		if (songs.length > 0)
		{
			changeSelection(0, true);
		}
		else
		{
			intendedScore = 0;
			intendedRating = 0;
			portrait.visible = false;
		}
		updateTexts(0);
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
		if (songs.length > 0)
			changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		if (leWeek == null) return true;
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

		// Sinkronisasi visibilitas scoreBG & scoreText milik MusicPlayer dengan infoText
		if (scoreBG != null && infoText != null)
		{
			infoText.visible = scoreBG.visible;
		}

		// Animasi Skor ala Impostor Legacy
		lerpScore = FlxMath.lerp(lerpScore, intendedScore, Math.min(1, elapsed * 18));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, Math.min(1, elapsed * 10));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.001)
			lerpRating = intendedRating;

		var scoreVal:String = FlxStringUtil.formatMoney(Math.round(lerpScore), false);
		var accVal:String = (Math.round(lerpRating * 10000) / 100) + '%';
		var scoreLabel:String = Language.getPhrase('freeplay_score_label', 'Score');
		var accLabel:String = Language.getPhrase('freeplay_accuracy_label', 'Accuracy');
		infoText.text = '$scoreLabel: $scoreVal\n$accLabel: $accVal';

		var shiftMult:Int = 1;
		if(FlxG.keys.pressed.SHIFT && !player.playingMusic) shiftMult = 3;

		// Tombol Back
		var clickedBack:Bool = false;
		if (menuBack != null)
		{
			var hoveringBack:Bool = FlxG.mouse.overlaps(menuBack);
			var targetBackScale:Float = hoveringBack ? 1.08 : 1.0;
			var nextScale:Float = FlxMath.lerp(menuBack.scale.x, targetBackScale, Math.exp(-elapsed * 16));
			menuBack.scale.set(nextScale, nextScale);

			if (hoveringBack && FlxG.mouse.justPressed)
				clickedBack = true;
		}

		// Update Posisi & Klik Tab Carousel Melengkung (Impostor Legacy)
		var clickedTab:Bool = false;
		if (!player.playingMusic && categories.length > 0)
		{
			if (categories.length > 1)
			{
				if (FlxG.keys.justPressed.Q)
				{
					selectCategory(curCategory - 1);
					clickedTab = true;
				}
				else if (FlxG.keys.justPressed.E)
				{
					selectCategory(curCategory + 1);
					clickedTab = true;
				}
			}

			for (i in 0...grpCategoryTabs.members.length)
			{
				var tab:FlxSprite = grpCategoryTabs.members[i];
				if (tab == null) continue;

				var scrollDiff:Float = (i - smoothCategory);
				var cos:Float = FlxMath.fastCos((1 - scrollDiff / TAB_RADIUS) * Math.PI / 2);

				tab.x = ((FlxG.width - tab.width) * 0.5 + cos * TAB_DISTANCE);
				tab.y = (topBar.height - tab.height) * 0.5;
				tab.alpha = Math.max(0.15, 1 - FlxEase.quintIn(Math.abs(scrollDiff / 5)) * 0.6 - FlxEase.quintOut(Math.abs(scrollDiff / 5)) * 0.4);

				var tabScale:Float = (i == curCategory) ? 1.0 : 0.85;
				tab.scale.set(tabScale, tabScale);

				if (FlxG.mouse.overlaps(tab) && FlxG.mouse.justPressed)
				{
					clickedTab = true;
					if (i != curCategory)
						selectCategory(i);
				}
			}
		}

		if (!player.playingMusic)
		{
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
					if (FlxG.mouse.y <= topBar.height && categories.length > 1)
						selectCategory(curCategory + (FlxG.mouse.wheel > 0 ? -1 : 1));
					else
						changeSelection(-shiftMult * FlxG.mouse.wheel);
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

			if (songs.length > 0)
			{
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
		}

		if (controls.BACK || clickedBack)
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
			updateTexts(elapsed);
			super.update(elapsed);
			return;
		}

		if (!player.playingMusic && FlxG.mouse.justReleased && !hasDragged && !clickedBack && !clickedTab && songs.length > 0)
		{
			for (i in _lastVisibles)
			{
				var card:FlxSprite = grpCards.members[i];
				if (card != null && card.visible && FlxG.mouse.y >= topBar.height && FlxG.mouse.overlaps(card))
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

		if(FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(FlxG.keys.justPressed.SPACE && songs.length > 0)
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
		else if (controls.ACCEPT && !player.playingMusic && songs.length > 0)
		{
			confirmSong();
		}
		else if(controls.RESET && !player.playingMusic && songs.length > 0)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		
		updateTexts(elapsed);
		bg.x -= 9 * elapsed;
		super.update(elapsed);
	}

	function confirmSong()
	{
		if (songs.length == 0) return;

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
		return FlxColor.RED;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	public function positionHighscore()
	{
		if (infoText != null)
		{
			infoText.x = 0;
			infoText.y = 91;
		}
		if (diffText != null)
		{
			diffText.x = 0;
			diffText.y = 172;
		}
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic || songs.length == 0)
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

	function changeSelection(change:Int = 0, forceReset:Bool = false)
	{
		if (player.playingMusic || songs.length == 0)
			return;
		
		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
		_updateSongLastDifficulty();

		if (change != 0)
		{
			var hoverSound:String = Paths.fileExists('sounds/hover.ogg', SOUND) ? 'hover' : 'scrollMenu';
			FlxG.sound.play(Paths.sound(hoverSound), 0.5);
		}

		Mods.currentModDirectory = songs[curSelected].folder;

		// Update Portrait & Glow ala Impostor Legacy
		var songFormatted:String = Paths.formatToSongPath(songs[curSelected].songName);
		var targetColor:FlxColor = getHealthColorFromCharacter(songs[curSelected].songCharacter);

		if (forceReset || prevPort != songFormatted)
		{
			var imagePath:String = 'menu/freeplay/portraits/' + songFormatted;
			if (!Paths.fileExists('images/' + imagePath + '.png', IMAGE))
				imagePath = 'menu/freeplay/portraits/placeholder';

			if (Paths.fileExists('images/' + imagePath + '.png', IMAGE))
			{
				portrait.visible = true;
				portrait.loadGraphic(Paths.image(imagePath));
				portrait.updateHitbox();
				portrait.offset.x += (portrait.frameWidth - 1215) * 0.5 * portrait.scale.x;
				portrait.offset.y += (portrait.frameHeight - 1097) * 0.5 * portrait.scale.y;

				if (portraitTween != null) portraitTween.cancel();
				if (portraitAlphaTween != null) portraitAlphaTween.cancel();
				if (glowTween != null) glowTween.cancel();

				portrait.x = 504.65;
				portrait.y = -100;
				portrait.alpha = 0;

				glowTween = FlxTween.color(porGlow, 0.2, porGlow.color, targetColor);
				portraitTween = FlxTween.tween(portrait, {x: 304.65}, 0.3, {ease: FlxEase.expoOut});
				portraitAlphaTween = FlxTween.tween(portrait, {alpha: 1}, 0.3, {ease: FlxEase.expoOut});
			}
			else
			{
				portrait.visible = false;
			}
		}
		prevPort = songFormatted;
		
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

	var _drawDistance:Int = 5;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		if (songs.length == 0) return;

		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 12));
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

			// Rumus Posisi Kartu VS Impostor Legacy
			final dist:Float = (i - lerpSelected);
			final targetX:Float = (Math.abs(dist) * CARD_X_SHIFT + Math.round(CARD_X));
			final targetY:Float = (dist * CARD_DISTANCE + Math.round(CARD_Y));
			final targetAlpha:Float = Math.max(0, 1 - Math.abs(dist) * CARD_FADE);

			card.visible = card.active = true;
			card.alpha = (elapsed > 0) ? FlxMath.lerp(card.alpha, targetAlpha, Math.exp(-elapsed * 14)) : targetAlpha;
			card.x = (elapsed > 0) ? FlxMath.lerp(card.x, targetX, Math.exp(-elapsed * 14)) : targetX;
			card.y = (elapsed > 0) ? FlxMath.lerp(card.y, targetY, Math.exp(-elapsed * 14)) : targetY;

			if (icon != null)
			{
				icon.visible = icon.active = true;
				icon.alpha = card.alpha;

				var maxIconDim:Float = Math.max(icon.frameWidth, icon.frameHeight);
				if (maxIconDim <= 0) maxIconDim = 150;
				var iconFitScale:Float = (74 / maxIconDim);

				icon.scale.set(iconFitScale, iconFitScale);
				icon.updateHitbox();

				icon.x = card.x + 56 - (icon.width / 2);
				icon.y = card.y + (card.height / 2) - (icon.height / 2);
			}

			var hasCredit:Bool = (credit != null && credit.text != null && credit.text.length > 0);
			var textStartX:Float = card.x + 116;

			item.visible = item.active = true;
			item.alpha = card.alpha;
			item.x = textStartX;
			item.y = hasCredit ? (card.y + 16) : (card.y + (card.height - item.height) / 2);

			if (credit != null && noteIcon != null)
			{
				if (hasCredit)
				{
					noteIcon.visible = noteIcon.active = true;
					noteIcon.alpha = card.alpha;
					noteIcon.x = textStartX;
					noteIcon.y = card.y + 55;

					credit.visible = credit.active = true;
					credit.alpha = card.alpha;
					credit.x = noteIcon.x + noteIcon.width + 6;
					credit.y = card.y + 54;
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
