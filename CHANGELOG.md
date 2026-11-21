# Changelog

## 5.2.0 (21 Nov 2026)

### Added
- **ShyAuction:** Other parts of the family can open the auction house on an item you pick, with what is listed of it already asked for
- **ShyMaps:** The dungeon journal shows what its players recorded dropping, with the kills they counted. The newest dungeons show roughly where each boss stands and where you come in, marked as rough
- **ShyMaps:** The land between the zones on the drawn map is painted in now, so the world map no longer has bare gaps between its zones
- **ShyQuest:** When a vendor is out of what a quest needs, the card offers the auction house, coming back later, or skipping the quest. The route stops sending you to that vendor, and the guide sets the quest's steps aside until you choose
- **ShyQuest:** Levelling guides now carry you from 1 to 60, for both sides, not only to 30. Where the quests run out the guide sends you to a camp to fight, and a guide that needs a level waits for it at a camp of creatures, never inside a capital city
- **ShyQuest:** Click a quest on your route card and the map opens with that quest's page beside it, flown to where it is done. Click an objective and the map goes to that objective. What you opened stays lit on the card

### Changed
- **ShyDock:** The menu and bag rows under the map keep the size your layout gives them, instead of being shrunk or stretched to fit the map as it is now
- **ShyGroup:** Your group post and your asks now say which roles you already have, like "(2/5, have healer, DPS)". When others write "have tank, need dps", the role after "have" is no longer read as one they want
- **ShyMaps:** The map window opens in the middle of the screen with your quests beside it, as tall as the space over your bars allows and as wide as the map needs. The minimap is the same width at every login
- **ShyMaps:** The map is its own window whenever the drawn map is on. The game's map no longer opens behind it, and the choice between the two is gone
- **ShyQuest:** When your bags are nearly full, the row now lets you make room as well as sell. A click opens your bags with the cheapest things lit, each to drop, even with no shop near
- **ShyQuest:** Newer level data for places, so the route knows better what level the land around a quest is
- **ShyQuest:** Levelling guides count on a mount from level 40, so the long ways between places are shorter. From there they also fight at a camp sooner than cross the world for a quest that pays little
- **ShyQuest:** You are no longer sent to fight what is three or more levels above you while anything in reach gives the same item, and such a fight waits behind the rest of your route. A quest three levels above you counts as too high for now, and a creature seen dropping an item counts as a source of it
- **ShyQuest:** A trip to the bank now waits until you have done what you can right where you stand. You hand in the quest in front of you before you are sent across town
- **ShyQuest:** When an item drops from a few spawns or a rare, the route weighs the work of getting it, not only the walk. You aren't sent for a one-in-a-hundred drop when a nearby camp gives it far more often
- **ShyQuest:** Newer drop chances from what players recorded in this game, so the quests that ask for items point you at the creatures that really drop them. Where nothing is known for an item, the route goes where the quest was seen to advance
- **ShyQuest:** What the addon says in your party chat now starts with <Shy>, so nobody takes it for words you typed
- **ShyQuest:** Newer quest data, with the latest game update, quest experience and fixed quest chains. The guides are planned again from it
- **ShyWay:** Ways now keep to the roads where what lives off them is five or more levels above you, and go straight where it is not. "Roads in higher zones" is the new setting for it, and what you have is kept
- **ShyWay:** Once you ride a mount, ways and routes count its speed. A long walk is ridden and a flight is only taken where it beats the ride
- **ShyXP:** The experience bar under your bars wears your theme's frame, slimmer than a window's, and the bars sit inside it

### Fixed
- **ShyCore:** The page behind a window's text covered the window's frame at the sides and the bottom. It now stops at the frame, and follows when you change the look or its weight
- **ShyCore:** The grey used for captions and counts was too dim to read on the panel. It is brighter now
- **ShyFarm:** The farming card's captions, figures, stats line and clock were hidden under the card and hard to see. They show clearly now
- **ShyKeys:** The How to play pullout's level line, tip and captions were hard to read. They are clear now
- **ShyMaps:** Showing a place on another map left that map as you last had it, and the view often framed nothing. It now opens the whole map and frames the place at once
- **ShyQuest:** The line on the minimap stopped short when your way doubled back close to you. It now carries on while the end of the way would be in sight
- **ShyQuest:** A vendor whose list had dropped what a quest needs was treated as never selling it. They now count as having none for a little while, and the quests that wait on that item wait with it
- **ShyQuest:** During a dungeon run, a place you sent yourself to, a quest you picked or the one you pointed the way to was left off the card until the run ended. They lead the run's steps now, and the arrow points there
- **ShyQuest:** After you learned a flight path, your guide still told you to get it until you reloaded. It goes away by itself now
- **ShyQuest:** Dungeon quests far away, like the Wailing Caverns for an Alliance warrior, came into your guide because another class's errand stood near them. Only what you are ever given counts now
- **ShyQuest:** The words in the Quests your guide skips window were hard to read. They are clear now
- **ShyQuest:** A ride whose walks were still being worked out could be picked over a walk you could already count on. The route now waits for them and is built again once they are known
- **ShyQuest:** The hearthstone was offered as a saving when the way from home was too long to work out. It is only offered now where the way from home is known
- **ShyWay:** The guide thought you knew every flight path, the other side's too. It now learns only the ones you find at a flight master, so yours are learned again the next time you talk to one
- **ShyWay:** Swimming round Orgrimmar's west side could take you through its walls, onto the ground under the city. Walls standing in the water now stop you, and the ways and levels are worked out again

## 5.1.7 (18 Nov 2026)

### Added
- **ShyCore:** A card can hold buttons and items you point at, and one a click keeps goes at the next press anywhere else. Your map opens from anywhere that sends you to it
- **ShyCore:** A window is two surfaces with a setting of its own each: the housing the theme works on, and the sheet its content is read off

### Changed
- **ShyCore:** Every window is made with a sheet of its own, so every one of them answers the same two settings
- **ShyKeys:** Setup's keys page starts on No, so Next and Finish never touch your keys. The keys list names what each key did, gives every key we take one of your own to pick, and keeps strafing on A and D when your arrows strafe
- **ShyKeys:** The Keys page starts with how your keys work and how you move, then the keys that fall out of those two, instead of the list first
- **ShyKeys:** A key's row is one line of cells read straight across, every other one banded, instead of two lines of words with a plate between them
- **ShyKeys:** Nothing of yours is bound until you press Save, on a bar that stays at the window's foot; /shy keys is one page to change a key on, with your keys whole at the top of it
- **ShyKeys:** Your keys keep their own settings now instead of the core's. Your layout, the keys you keep and the way you move all come across the first time it loads, on every profile
- **ShyKeys:** Your keys are an addon of their own now, so you can switch them off and keep the rest of Shy. Your layout, hotkeys and macros are untouched, and the Keys room goes from /shy when the addon is off
- **ShyMaps:** The map's window opens from the game's map key, has room for your quests beside it, and follows you the way you pick: not at all, in the middle, or smart. Notes, sharing and the overlay moved into the map's menu
- **ShyQuest:** Your quests list beside the map's window, and the card, route and offers read better. A stop you put on your route yourself is washed in your color

### Fixed
- **ShyCore:** A bar at the window's foot ran out past the room it belongs to, over the scroll bar
- **ShyCore:** The foot of the hub showed the rail's darker ground and a line through it, cutting it in two. It is one clean strip now
- **ShyCore:** A window of ours hung from a game window, like the mailbox's, kept the screen from fading after you closed the game's. It fades again
- **ShyCore:** Picking a new key for one of your hotkeys could change a different key and move an ability you never touched. The key you clicked is the one that changes now, and the list stays put while you pick
- **ShyCore:** A bar at the window's foot stopped short of the window, and a room left up to fifty pixels unused at its right edge
- **ShyDock:** Your console was told it no longer fit right after you set it up, or after a tiny measuring difference between logins. It only says so when something really changed
- **ShyFarm:** Farms were not being ended properly between closing and switching characters when a new item was looted that you were farming before
- **ShyKeys:** The Save bar stood over the list instead of above it, and a key's row left you guessing which of the two things on it a picker moved
- **ShyKeys:** Hiding a page you never touched put your whole book of keys back to how it looked when that page was built, losing every override you had saved
- **ShyKeys:** The room said Your keys three times over, and the column of keys was named to the wrong edge
- **ShyKeys:** The keys you reach for most were told apart by a colour on the words and nothing else, and the columns were half named
- **ShyKeys:** The arrow by each key was a box the font can't draw, the plates landed wherever their words ended, and the choice named us instead of saying what it does
- **ShyKeys:** A key was said in the capitals the game keeps it under, so a row read Still on LEFT
- **ShyKeys:** A key you had bound to something else was stuck: asking for your new key back did nothing, and picking a key moved the ability instead of what the key did. New key takes it back now, and each key picker says what it moves
- **ShyKeys:** A macro of your own whose lines matched one of ours was deleted when you put your keys back. Anything you wrote before your keys were first laid out is left alone now
- **ShyWay:** Pressing a shared route's offer did nothing in a fight or with your map window open. It opens your map now

## 5.1.6 (17 Nov 2026)

### Changed
- **ShyMaps:** Dungeon bosses and their loot are brought up to the game's latest patch
- **ShyQuest:** Quests, creatures and guides are brought up to the game's latest patch. Some guides are renamed and re-planned, and a Horde character is offered the Hall of Thanes
- **ShyTip:** Spell schools and talents are brought up to the game's latest patch

### Fixed
- **ShyChat:** Speech bubbles could be too narrow, so the last word of a line dropped to the next one. They fit their words at the size they are drawn now
- **ShyQuest:** A quest item that only another quest hands out, like the keg for Dry Times, sent you nowhere. The guide now sends you to whoever gives it for that quest

## 5.1.5 (17 Nov 2026)

### Changed
- **ShyFarm:** Looking up which creatures drop an item is much quicker. Items that creatures almost never drop are no longer treated as something to farm

### Fixed
- **ShyAuction:** Where to farm it on the Buy card showed for items no creature really drops, and the farm list didn't lead with the item you asked about. It shows only where it helps now, and lists that item first
- **ShyBags:** Searching another character's bags, or the bank when you're away from it, could throw an error. It searches them fine now
- **ShySkin:** Opening the professions window in a fight could break the Create button. The window leaves it alone then
- **ShySkin:** In a fight the unit frames could throw an error while being dressed. They're left as the game had them and dress fine now

## 5.1.4 (16 Nov 2026)

### Fixed
- **ShyAuction:** Close the auction house and open it again, and the item you had picked showed no prices. It asks for them again each time you open it
- **ShyAuction:** Herbs in your herb bag didn't show on the sell list. They're listed now, and right-clicking one picks it

## 5.1.3 (16 Nov 2026)

### Added
- **ShyCore:** A and D can keep turning you instead of strafing. Pick it on their row in your keys, and give strafing or turning a key of your own

### Changed
- **ShyAuction:** Selling a pile now goes up stack by stack, with a strip showing how far along you are. Space posts the next one, and right-clicking an item in your bags picks it on the Sell tab
- **ShyCore:** The game-style red buttons turn their own art around when held, so they look pushed in, and no longer get a second light along the top
- **ShyCore:** The game-style red buttons keep the same thin rim on a tall card as on a small button
- **ShyCore:** The Maximize and Minimize buttons on windows no longer pop up a tooltip
- **ShyDock:** The Screen page in setup is laid out new. A band says what happens to your screen, the layouts are cards, and the sizes, bars and menu sit in two columns under them. The card in use is badged
- **ShyDock:** If you changed the console's layout yourself, setup now leaves it alone and marks it custom. Pick a layout to start fresh
- **ShyThreat:** One threat setting for the meter, nameplates and warrior light, with one aggro sound. The meter counts mobs that got loose from you

### Fixed
- **ShyBags:** Stack counts in your bank slots didn't show when the bank first opened. They show from the start now
- **ShyCore:** Clicking the choice that was already picked made its button flash as if you were pointing at it. It stays still now
- **ShyCore:** The chosen card on the keys page flickered when you pointed at another one. It stays steady now
- **ShyDock:** In a fight your off-hand swing bar went missing while dual wielding. It stays now
- **ShyQuest:** Some quests were offered from level 1 when they are really for high levels, and two Praise quests sent low levels to an empty spot. Both are right now

## 5.1.2 (16 Nov 2026)

### Fixed
- **ShyBags:** Opening your bags at a banker threw an error. They open cleanly now

## 5.1.1 (16 Nov 2026)

### Added
- **ShyChat:** Whisper conversations can dock in the chat as tabs beside its own, and each person opens where you last put them. Dragging a tab lights every place it can go, the chat's tabs scroll with the wheel instead of being cut short, and commands like /rl work in a conversation
- **ShyFarm:** Farm a creature for everything it drops, or just record everything you loot. The finder has a farming side with the best farms for you and a search for any item or creature you could farm, and the auction house can open it to pick an item

### Changed
- **ShyBags:** A special bag's slots, like an herb bag's or a quiver's, stand after your other bags' whatever the sort, framed in that bag's color
- **ShyChat:** Chat bubbles wear your look, their tail drawn in the look's own edge, and read clearly in every look. They follow your interface's size, a yell or raid warning wears its own red or orange, and a language you don't speak shows before the words
- **ShyCore:** Setup turns on nameplates for friendly NPCs, so the one your next quest step sends you to shows its mark
- **ShyCore:** Picking a key that already does something, or is picked for something else, asks if you're sure and says where the old use goes, instead of refusing it
- **ShyCore:** Clicking a hover no longer pins it on the screen. It closes when you move away, as every hover does
- **ShyCore:** Colored words on hovers, like an item's quality, stay readable in every look. A color too dark or pale for the background is brightened just enough, keeping its hue
- **ShyCore:** All of Shy's words, down to names, numbers and list lines, wear your look's text effect, so they read on every look's background
- **ShyDock:** The minimal layout shows your main bar alone. Your other bars and side bars fade in while you point at the bars or carry a spell to them, and their keys work all the while
- **ShyDock:** The layout cards in setup are simple flat drawings of your whole screen's foot, all at one scale, so you can tell the layouts apart at a glance

### Fixed
- **ShyCore:** A hover could stand over a menu you had just opened and hide half of it. The menu stands over hovers now, and the hover of what you opened it on closes
- **ShyCore:** In the tooled leather look the carved band round the edge ran under what windows hold, and under chat lines and meter bars on screen. Windows keep their contents clear of it now, a little bigger to make room, and the band stays off pieces with no room for it
- **ShyCore:** In a dungeon run, buttons on the quest card showed a block of the dungeon's color over their pictures. Their highlight stays hidden until you point at them now
- **ShyTweaks:** A spell out of range on a faded bar tinted the world behind it red. The red shows only on bars you can see now

## 5.1.0 (16 Nov 2026)

### Added
- **ShyCore:** In layout mode you can switch a piece off from its panel. Off, it shows grey with a few words on what it does: the quest window, death recap, the hits on you and the farming window
- **ShyDock:** Moving your XP bars under the action bars, or away from there, tells you the console no longer fits and that /shy setup refits it
- **ShyXP:** The reputation you track gets a bar of its own under your XP, and takes the XP bar's place at max level. You pick where the bars go: the quest window, under your action bars or the stats window

### Changed
- **ShyAuction:** The market price goes by what most of the cheap end asks over the last two weeks, recent days counting most, so one bait listing or one odd day doesn't make it. Item cards chart the price by day and say how many days of scans it's from
- **ShyCore:** Setting up your keys asks first, then walks you through it a page at a time, in setup and in the /shy window. Whatever a key did before moves to Ctrl and that key, so nothing of yours is lost, and you can pick your own key for anything in the list
- **ShyCore:** Voice captions sit at the top of the screen now, under what runs along the top, clear of your character. Layout mode only offers them when they can show, and you can switch them off there
- **ShyCore:** Every addon has a new mark of its own, sharp at any size, and the /shy window and the minimap's menu list the addons by what they're for: leveling, combat, items and gold, chat and groups, interface
- **ShyCore:** Setting up a character now happens in the /shy window, walking its pages with the same rail, and Not now takes you back to the rest of /shy
- **ShyDock:** The swing timer takes the cast bar's spot under your health and power while you swing, with your weapon's picture, and a cast takes the spot back. In layout mode the cast bar can be dragged out and back in, and taken apart, the cooldown manager waits at the side for you to drop pieces back on it
- **ShyDock:** The pictures of the console in setup show a few cooldowns even before you have any, so you can tell how big they'll be, and they no longer hitch as you point at the choices
- **ShyDock:** The farming window and how to play sit right in the top left corner. In a raid your raid's frames have the corner: how to play goes under them and the farming window steps aside
- **ShyQuest:** At max level the quest window lists just the quests you have, without the guide, quests to pick up or errands. Leveling help in its menu brings them back for that character
- **ShyTip:** Pings and raid markers on Shift start off. Turn them on in ShyTip's options or from their piece in layout mode

### Fixed
- **ShyAuction:** A whole scan froze the game for a moment as it went into the price book. It goes in a little at a time now, and closing the auction house still keeps all of it
- **ShyAuction:** Items listed several to a listing, like five recipes in one row, showed and were noted at a fraction of their price. Each one's price is the listing's buyout now, as the auction house means it
- **ShyChat:** A menu opened from the chat's button row closed as soon as you moved onto it, when the row hides away. The row stays while its menu is open now
- **ShyCore:** In layout mode, dragging another piece while a piece's panel was open swapped the panel over to it. A drag closes that panel now, and a click still shows the piece you picked
- **ShyCore:** Resizing the /shy window by its corner stuttered, as every page was laid out again while you dragged. It follows the mouse smoothly now and keeps each page it built for a width
- **ShyCore:** A key for a spell you can only cast on a friend, like Divine Grace, showed a question mark with no friend about. It shows the spell now
- **ShyQuest:** Creatures the game had shown don't drop what your quest needs still showed on the map, in Find and in a dungeon run's list. They're left out there too now
- **ShyQuest:** A dungeon run at max level turned the leveling guide on for all your characters and left it on. It goes off again when the run ends, and the guide's switch in the options follows your leveling help at max level
- **ShyQuest:** At max level without leveling help, the quest window's menu had no Errands, so you couldn't turn off fetching quest items from your bank and mailbox. Errands is back with what still runs
- **ShyQuest:** The guide could send you to fight creatures that don't drop what your quest needs. Once the game shows you one doesn't, it's left out of the step, the map and the route
- **ShySkin:** Some menus with a dividing line in them stretched all the way to the corner of the screen. They keep their size now
- **ShyXP:** After the update, your XP bars went to the quest window even if you had turned the stats window off or kept the game's bar, and stats you had switched off came back on. Your old settings carry over now
- **ShyXP:** At max level, a reputation you stopped tracking got picked for you again with the next gain, and turning reputation at max level off left its pick tracked. Neither happens now

## 5.0.6 (15 Nov 2026)

### Fixed
- **ShyQuest:** The guide could stop at a flight master and wait for you to fly somewhere you hadn't found the flight point for yet. It moves on now and tells you that you can't fly there from here yet
- **ShyQuest:** Quests both factions share, like Research Access, could send you to the other side's city to pick them up or hand them in. You go to your own side's person now

## 5.0.5 (15 Nov 2026)

### Fixed
- **ShyQuest:** A hunter who had already learned to tame was still sent to another race's pet trainer for their taming quests, and after Beast Training for Training the Beast. Those are skipped now, and the quest says you know it already
- **ShySkin:** After you had arranged your screen, the messages in the middle of it, like quest progress, could stay up for good. They fade after their time again now
- **ShySkin:** Some drop-down menus kept growing wider each time they opened, until they filled the screen. They stay the size of their choices now

## 5.0.4 (15 Nov 2026)

### Added
- **ShyCore:** Before your keys are set up, you see each of your own keys that would change, and can tick any to keep as it is. A key you rebind yourself afterwards stays yours

### Changed
- **ShyQuest:** The campfire only asks you to sit by it once your Camp Benefits have run out, not while a few minutes are still left

### Fixed
- **ShyCore:** Setup didn't come back on a new character once it had been closed by the game or a reload, and a disconnect right after setup could leave it looking done when it wasn't. It's offered at every login until you finish it now
- **ShyCore:** The setup window could shrink until its text was too small to read, or keep a size from another screen. It stays readable and fits the screen you're on now
- **ShyCore:** Opening setup could shrink your whole screen when you had set your own UI size. Your size stays as it is now
- **ShyQuest:** The arrow let go of a quest you pointed it at and went back to the first step once that quest's spot moved. It stays on that quest now
- **ShyQuest:** The game stuttered while a dungeon run was on. It runs smoothly now
- **ShyWay:** Flight points your character starts out knowing, like Stormwind's for the Skyborne, still sent you to go find them. They count as known now

## 5.0.2 (15 Nov 2026)

### Changed
- **ShyCore:** Setup leaves your keys as they are unless you pick a layout. It no longer picks Shy's hotkeys for you

## 5.0.1 (15 Nov 2026)

### Changed
- **ShyWay:** The ground packs in your addon list say they need Shy, and that each loads only while you're in its world

### Fixed
- **ShyCore:** The Sources page spelled license the British way. It says license now
- **ShyFarm:** A farm started and ended in the same moment could stay on your route and your screen. It goes away now
- **ShyFarm:** A favorite you ended farming started up again on loot once you'd farmed and ended something else. It stays ended until you farm it again
- **ShyFarm:** The farming window you closed kept popping back up when farming started by itself or asked to go on. It stays closed now until you bring it back

## 5.0.0 (15 Nov 2026)

### Added
- **ShyCore:** /shy, Tools, Sources lists everyone whose work these addons build on, each with a link
