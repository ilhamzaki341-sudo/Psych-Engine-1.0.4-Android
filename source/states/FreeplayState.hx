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

	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var topBar:FlxSprite;
	var categoryTitleText:FlxText;
	var grpCategoryTabs:FlxTypedGroup<FlxSprite>;
	var grpCategoryIcons:FlxTypedGroup<FlxSprite>;
	var grpCategoryLabels:FlxTypedGroup<FlxText>;

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
	var menuBack:FlxSprite;

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

	var boldFont:String;
	var regFont:String;

	override function create()
	{
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
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

		Mods.loadTopMod();
		loadFreeplayCategories();
		loadFreeplayCredits();

		bg = new FlxBackdrop(Paths.image('menu/common/starFG'), X);
		bg.setGraphicSize(1280, 720);
		bg.updateHitbox();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		glowBG = new FlxSprite(0, 0);
		if (Paths.fileExists('images/menu/freeplay/Backglow.png', IMAGE))
		{
			glowBG.loadGraphic(Paths.image('menu/freeplay/Backglow'));
		}
		else
		{
			glowBG.makeGraphic(650, 650, FlxColor.WHITE);
		}
		glowBG.updateHitbox();
		glowBG.x = FlxG.width - glowBG.width;
		glowBG.y = FlxG.height - glowBG.height;
		glowBG.blend = BlendMode.ADD;
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

		categoryTitleText = new FlxText(560, 125, 420, "", 42);
		categoryTitleText.setFormat(boldFont, 42, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		categoryTitleText.borderSize = 2.5;
		categoryTitleText.antialiasing = ClientPrefs.data.antialiasing;
		add(categoryTitleText);

		topBar = new FlxSprite(0, 0);
		if (Paths.fileExists('images/menu/common/topBar.png', IMAGE))
		{
			topBar.loadGraphic(Paths.image('menu/common/topBar'));
		}
		else if (Paths.fileExists('images/menu/freeplay/topBar.png', IMAGE))
		{
			topBar.loadGraphic(Paths.image('menu/freeplay/topBar'));
		}
		else
		{
			topBar.makeGraphic(FlxG.width, 96, 0xFF9FB0BF);
		}
		topBar.setGraphicSize(FlxG.width, 96);
		topBar.updateHitbox();
		topBar.scrollFactor.set();
		topBar.antialiasing = ClientPrefs.data.antialiasing;
		add(topBar);

		grpCategoryTabs = new FlxTypedGroup<FlxSprite>();
		add(grpCategoryTabs);

		grpCategoryIcons = new FlxTypedGroup<FlxSprite>();
		add(grpCategoryIcons);

		grpCategoryLabels = new FlxTypedGroup<FlxText>();
		add(grpCategoryLabels);

		buildCategoryTabs();
		
		var topOffset:Float = topBar.height;

		scoreBG = new FlxSprite(0, topOffset).makeGraphic(1, 108, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		scoreText = new FlxText(-14, topOffset + 8, FlxG.width, "", 30);
		scoreText.setFormat(regFont, 30, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreText.borderSize = 1.5;
		add(scoreText);

		accuracyText = new FlxText(-14, topOffset + 42, FlxG.width, "", 28);
		accuracyText.setFormat(regFont, 28, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		accuracyText.borderSize = 1.5;
		add(accuracyText);

		diffText = new FlxText(0, topOffset + 76, 0, "", 24);
		diffText.setFormat(boldFont, 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		diffText.borderSize = 1.5;
		add(diffText);

		menuBack = new FlxSprite(22, 14);
		if (Paths.fileExists('images/menu/common/menuBack.png', IMAGE))
		{
			menuBack.loadGraphic(Paths.image('menu/common/menuBack'));
		}
		else
		{
			menuBack.makeGraphic(68, 68, FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawCircle(menuBack, 34, 34, 32, 0xFF33393D);
			FlxSpriteUtil.drawCircle(menuBack, 34, 34, 27, 0xFFD9DEE1);
			FlxSpriteUtil.drawCircle(menuBack, 34, 34, 22, 0xFFF3F5F6);
			FlxSpriteUtil.drawLine(menuBack, 24, 24, 44, 44, {color: 0xFF23272A, thickness: 5});
			FlxSpriteUtil.drawLine(menuBack, 44, 24, 24, 44, {color: 0xFF23272A, thickness: 5});
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
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(regFont, size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);

		if (curCategory >= categories.length) curCategory = 0;
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
		grpCategoryIcons.clear();
		grpCategoryLabels.clear();

		if (categories.length == 0) return;

		var tabSize:Float = 76;
		var spacing:Float = 10;
		var totalWidth:Float = (categories.length * tabSize) + ((categories.length - 1) * spacing);
		var startX:Float = (FlxG.width - totalWidth) / 2;

		var hasTabAsset:Bool = Paths.fileExists('images/menu/freeplay/sections/blank.png', IMAGE);

		for (i in 0...categories.length)
		{
			var tabX:Float = startX + i * (tabSize + spacing);
			var tabY:Float = (topBar.height - tabSize) / 2;

			var tab:FlxSprite = new FlxSprite(tabX, tabY);
			if (hasTabAsset)
			{
				tab.loadGraphic(Paths.image('menu/freeplay/sections/blank'));
				tab.setGraphicSize(Std.int(tabSize), Std.int(tabSize));
				tab.updateHitbox();
			}
			else
			{
				tab.makeGraphic(Std.int(tabSize), Std.int(tabSize), FlxColor.TRANSPARENT, true);
				FlxSpriteUtil.drawRoundRect(tab, 0, 0, tabSize, tabSize, 14, 14, 0xFF49545E);
				FlxSpriteUtil.drawRoundRect(tab, 4, 4, tabSize - 8, tabSize - 8, 10, 10, 0xFFD9DEE1);
			}
			tab.ID = i;
			tab.scrollFactor.set();
			tab.antialiasing = ClientPrefs.data.antialiasing;
			grpCategoryTabs.add(tab);

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

			var catIcon:FlxSprite = new FlxSprite(tabX, tabY);
			if (foundIconPath != null)
			{
				catIcon.loadGraphic(Paths.image(foundIconPath));
				catIcon.setGraphicSize(Std.int(tabSize), Std.int(tabSize));
				catIcon.updateHitbox();
				catIcon.visible = true;
			}
			else
			{
				catIcon.makeGraphic(1, 1, FlxColor.TRANSPARENT);
				catIcon.visible = false;
			}
			catIcon.ID = i;
			catIcon.scrollFactor.set();
			catIcon.antialiasing = ClientPrefs.data.antialiasing;
			grpCategoryIcons.add(catIcon);

			var label:FlxText = new FlxText(tabX + 4, tabY + (tabSize - 18) / 2, tabSize - 8, categories[i].title.toUpperCase(), 13);
			label.setFormat(boldFont, 13, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 1.5;
			label.scrollFactor.set();
			label.visible = (foundIconPath == null);
			grpCategoryLabels.add(label);
		}
	}

	function selectCategory(catIdx:Int, isInitial:Bool = false)
	{
		if (categories.length == 0) return;

		curCategory = FlxMath.wrap(catIdx, 0, categories.length - 1);
		var activeCat:FreeplayCategory = categories[curCategory];

		if (categoryTitleText != null)
			categoryTitleText.text = activeCat.title.toUpperCase();

		for (i in 0...grpCategoryTabs.members.length)
		{
			var tab:FlxSprite = grpCategoryTabs.members[i];
			var icon:FlxSprite = grpCategoryIcons.members[i];
			var lbl:FlxText = grpCategoryLabels.members[i];
			var isSelected:Bool = (i == curCategory);

			var targetY:Float = ((topBar.height - tab.height) / 2) + (isSelected ? 4 : 0);
			var targetAlpha:Float = isSelected ? 1.0 : 0.65;
			var targetColor:FlxColor = isSelected ? 0xFFFFFFFF : 0xFFB0BCC4;

			tab.y = targetY;
			tab.alpha = targetAlpha;
			tab.color = targetColor;

			if (icon != null && icon.visible)
			{
				tab.visible = false;
				icon.x = tab.x;
				icon.y = targetY;
				icon.alpha = targetAlpha;
				icon.color = targetColor;
			}
			else
			{
				tab.visible = true;
			}

			if (lbl != null)
			{
				lbl.alpha = targetAlpha;
				lbl.y = tab.y + (tab.height - lbl.height) / 2;
			}
		}

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
			songText.setFormat(boldFont, 34, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
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
			changeSelection(0, !isInitial);
			if (isInitial)
				glowBG.color = getHealthColorFromCharacter(songs[curSelected].songCharacter);
		}
		else
		{
			intendedScore = 0;
			intendedRating = 0;
			songFrame.visible = false;
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
		if(FlxG.keys.pressed.SHIFT && !player.playingMusic) shiftMult = 3;

		var clickedBack:Bool = false;
		if (menuBack != null)
		{
			var hoveringBack:Bool = FlxG.mouse.overlaps(menuBack);
			var targetBackScale:Float = hoveringBack ? 1.08 : 1.0;
			var nextScale:Float = FlxMath.lerp(menuBack.scale.x, targetBackScale, Math.exp(-elapsed * 16));
			menuBack.scale.set(nextScale, nextScale);

			if (hoveringBack && FlxG.mouse.justPressed)
			{
				clickedBack = true;
			}
		}

		var clickedTab:Bool = false;
		if (!player.playingMusic && categories.length > 1)
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

			for (i in 0...grpCategoryTabs.members.length)
			{
				var tab:FlxSprite = grpCategoryTabs.members[i];
				var icon:FlxSprite = grpCategoryIcons.members[i];
				var isOver:Bool = (tab != null && FlxG.mouse.overlaps(tab)) || (icon != null && icon.visible && FlxG.mouse.overlaps(icon));

				if (isOver && FlxG.mouse.justPressed)
				{
					clickedTab = true;
					if (i != curCategory)
						selectCategory(i);
					break;
				}
			}
		}

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

		bg.x -= 9 * elapsed;
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

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic || songs.length == 0)
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

		songFrame.visible = true;
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
		var topOffset:Float = (topBar != null) ? topBar.height : 0;

		var scoreW:Float = scoreText.textField.textWidth;
		var accW:Float = accuracyText.textField.textWidth;
		var diffW:Float = diffText.textField.textWidth;
		var maxW:Float = Math.max(Math.max(scoreW, accW), diffW);

		var boxWidth:Float = Math.max(240, maxW + 32);
		scoreBG.setGraphicSize(Std.int(boxWidth), 108);
		scoreBG.updateHitbox();
		scoreBG.x = FlxG.width - scoreBG.width;
		scoreBG.y = topOffset;

		scoreText.x = -14;
		scoreText.y = topOffset + 8;

		accuracyText.x = -14;
		accuracyText.y = topOffset + 42;

		diffText.x = scoreBG.x + (scoreBG.width - diffText.width) / 2;
		diffText.y = topOffset + 76;
	}

	var _drawDistance:Int = 5;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		if (songs.length == 0) return;

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

			var centerY:Float = (FlxG.height * 0.50) + (diff * spacingY);
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

				var maxIconDim:Float = Math.max(icon.frameWidth, icon.frameHeight);
				if (maxIconDim <= 0) maxIconDim = 150;
				var iconFitScale:Float = ((74 * targetScale) / maxIconDim);

				icon.scale.set(iconFitScale, iconFitScale);
				icon.updateHitbox();

				var slotCenterX:Float = card.x + (56 * targetScale);
				var slotCenterY:Float = card.y + (card.height / 2);
				icon.x = slotCenterX - (icon.width / 2);
				icon.y = slotCenterY - (icon.height / 2);
			}

			var hasCredit:Bool = (credit != null && credit.text != null && credit.text.length > 0);
			var textStartX:Float = card.x + (116 * targetScale);

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
