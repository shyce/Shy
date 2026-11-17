# Changelog

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
