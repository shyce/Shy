# Changelog

## 5.2.16 (26 Nov 2026)

### Added
- **ShyCore:** Numbered pins show the order of things. Setup pages, talents, crates and key steps use them
- **ShyCore:** A grid shows while you move or size things. Pieces snap to its lines, and you can turn that off
- **ShySkin:** Talents you hold that your build doesn't take get a crimson ring. Hover says why and how to move the point

### Changed
- **ShyAuction:** Sell picks your price for you. It won't undercut below a floor you set, and it says why. Space posts the next item in the queue
- **ShyKeys:** Mage, druid and the other classes' keys moved. Wand on Z, armor on Shift + 5, talent picks match the new build
- **ShyQuest:** A creature you must kill shows as one line with its raid mark. The run banner scrolls with the card, and flights get no timer plate
- **ShyQuest:** Quests, items and the leveling guides match the new game build

### Fixed
- **ShyKeys:** The game moved your turn and strafe keys at log-in. They stay as you set them now

## 5.2.15 (26 Nov 2026)

### Changed
- **ShySkin:** The talent window shows your build's next talents with a turn badge. It follows the order even where the game's tree differs
- **ShySkin:** The new letter fills its room and drops the scroll bar when it fits. Send no longer loses a click, and the To list has a caret and a clear button

## 5.2.14 (26 Nov 2026)

### Changed
- **ShyChat:** Esc closes the whisper window you're in. The game's own whisper windows stay shut. Commands you type there run
- **ShyChat:** Esc closes the whisper window you're in. The typing row no longer says who it goes to
- **ShySkin:** The vendor's sell page lists everything a vendor buys and shows where each item fetches more
- **ShySkin:** The flight map shows the whole map again. It no longer zooms in on the flights you have

### Fixed
- **ShySkin:** Right-click menus cut off a name like "Invite to gro..." on first open. They fit the words now
- **ShySkin:** Right-click menus on players failed in instances. They open and light up as they should now
- **ShySkin:** The ├ù on the social window did nothing in a fight. It closes the window now
- **ShyWay:** The flight line jumped to the wrong leg when a flight came back past where it started. It follows your real position now

## 5.2.13 (25 Nov 2026)

### Fixed
- **ShyQuest:** From the Ashes was handed in without destroying the attack plans. The guide sends you to each one first
- **ShyQuest:** A quest you skipped in a guide far back wasn't picked up again. The guide sends you back for it now
- **ShyQuest:** "Fly to Menethil Harbor" stayed on the card after you'd walked into town. It clears now
- **ShyQuest:** A quest that waited on one you'd skipped in an earlier guide got stuck. The guide sends you back for it now
- **ShyQuest:** Seeking the Kor Gem was hidden or skipped when The Test of Righteousness needed its gem. It's offered and routed right now

## 5.2.12 (25 Nov 2026)

### Fixed
- **ShyQuest:** Blackfathom Deeps quests sent you away by boat before you could pick them up. They come first now
- **ShyQuest:** The guide flew you to a town you'd skipped. It passes that flight now and flies you from where you are

## 5.2.11 (25 Nov 2026)

### Changed
- **ShyQuest:** You won't be sent on an escort through elites at your level or higher. It comes back once you outlevel them

### Fixed
- **ShyCore:** Text boxes didn't follow their window when it was resized. They stretch with it now
- **ShyQuest:** New escort quests were taken for you and set off at once. They're left for you to start now
- **ShyQuest:** The trail and pin vanished when you stood on a spot's ground. They stay now, since the way may lead underground
- **ShyWay:** The trail to Sarltooth in the Wetlands went round the hills. It goes up the planks now

## 5.2.10 (25 Nov 2026)

### Fixed
- **ShyQuest:** You were sent back to the trainer for spells you already knew. It checks your spellbook now

## 5.2.9 (25 Nov 2026)

### Added
- **ShyBags:** Your currencies show in your bags, all your characters together. Your gold shows the ones you carry
- **ShyCore:** Your story on the away screen. Gold on all your characters, crates, Merchant's Favor and Honor, over the game's statistics rolling up
- **ShyCore:** Seven new game options in setup. Interact key, sharper picture, fuller grass, heavier weather, farther nameplates, camera past small things, shorter loading screens
- **ShyCrates:** Your crate count covers all your characters when ShyBags is on. It counts crates in bags, bank and mail
- **ShyCrates:** Waylaid Crates. See what fills each one, priced on its tooltip. A crate button on your bags opens a window to fill them, and the auction house gets a Crates page with a shopping list
- **ShyHots:** It knows how big each of your heals is now, with your gear and talents. Forget what it learned in Settings after a talent change
- **ShySkin:** A heal on your action bars shows how much of it would land. A strip fills with what the friend is missing
- **ShySkin:** Vendors that sell gear for a currency sort for you. Best for you, Cheapest or Level. Your currency shows beside your gold

### Changed
- **ShyCore:** Your keys and gear follow the build your talents make, even without ShyQuest. A spell you lose leaves its key
- **ShyDock:** You pick the console's layout, size and bars right in Settings. No trip to the Screen room
- **ShyFrames:** Your heal on a frame is mint where it lands and soft red where it'd be wasted. The bar's end lights gold when over half would be wasted
- **ShyKeys:** A new icon. It shows four keys laid out like the movement keys
- **ShyPaladin:** Your auras sit on 1, 2 and 3 in the same order as the game's bar. Devotion, Retribution, Concentration in every build
- **ShyQuest:** The trail on your maps holds still now. The spark that ran along it is gone, and walking costs less
- **ShyQuest:** Late-level guides from 34 to 60 are planned again. Some routes visit different zones now
- **ShyQuest:** Quest data rebuilt for the newest quests and what they pay. Guides are planned again, so a few routes changed
- **ShySkin:** Vendors that sell plans now sort by what the plan makes. Plans need your skill, so the ones you can learn come first
- **ShyTip:** Item, unit and object tooltips get one set of extra lines from every addon. A card can wear a tab, like Equipped, over its top edge

### Fixed
- **ShyCore:** Search words in the Settings list had a shadow that muddied the badge behind them. They're plain now
- **ShyDock:** The cast bar landed on your stance bar in a fight. The row now opens when the fight starts and stays open until it ends
- **ShyFrames:** Mouse 3, 4 and 5 did nothing over a party or raid frame. They press the key's button on your bars now, so a heal lands on that friend

## 5.2.8 (23 Nov 2026)

### Added
- **ShyQuest:** Creatures that share a spot with the one you need get marked. Hovers and cards say to kill them to make room
- **ShySkin:** Your professions window has Unlearn on each profession's card. The recipe list has a search by item level and a filter for sources and slots
- **ShyXP:** Your rested bar lights up while you rest. Well Rested and camp tents count toward how fast it fills

### Changed
- **ShyGear:** Quest rewards go by their vendor price again. The hand-in no longer quotes an auction price for a reward
- **ShyGear:** Quest rewards can be worth their auction price. Casters and hunters count melee weapons, and the hand-in names a reward that sells for more

### Fixed
- **ShyQuest:** The guide sent you back for travel steps you'd already skipped past. It marks them done once you're nearer the next step
- **ShyQuest:** The hearthstone suggestion jumped around while your route was worked out. It holds steady now, and an errand you pass is settled once
- **ShyWay:** The arrow sent you round walls and flipped between trails. It holds a trail now, and a boat or tram ride ends when it stops

## 5.2.7 (22 Nov 2026)

### Added
- **ShyQuest:** The card tells you about a long swim ahead. A swim is drawn as water on the map now, so it doesn't look like a boat

### Fixed
- **ShyQuest:** The boat step sent you into the sea. It's on the end of the pier now, and flight points nobody can learn are gone
- **ShyQuest:** You were sent to the Gurubashi Arena chest and other PvP quests. They're left out of your route now

## 5.2.6 (22 Nov 2026)

### Added
- **ShyQuest:** A /way you type is a stop on your route now. The card turns ice blue while it leads, and it's gone once you reach it or clear it
- **ShyQuest:** Right-click any guide step to do it now. Pick it from the card, the map or the guide window, and 'Back to my route' returns you
- **ShyQuest:** A what's new window opens after an update. It lists what changed since you last played

### Changed
- **ShyCore:** The family is called ShyUI now. Addon lists and chat lines use the new name
- **ShyQuest:** A step you took turns the card gold. It says 'Back to guide', and it's still there after a reload

### Fixed
- **ShyQuest:** Library book quests sent you back to where the book lay. They send you to the librarian now
- **ShySkin:** The game's settings dropdowns showed plain, unstyled rows. They wear your theme now

## 5.2.5 (22 Nov 2026)

### Added
- **ShyQuest:** While the way to your next stop is still being worked out, the head shows a spinner on its ring. It flares when the way is found

### Fixed
- **ShyFrames:** 3D heads stayed solid while the HUD faded out. They fade with their frames now
- **ShyQuest:** Creatures that walk about weren't shown when a quest needed them or what they drop. They show on the map now
- **ShyWay:** In Stormwind you could be put on the wrong floor and sent to Lakeshire and back. You get a walk to where you're going now
- **Windows:** Two windows docked side by side could hang from each other and jump around. They stay put now

## 5.2.4 (21 Nov 2026)

### Added
- **ShyFrames:** A hunter's pet shows its mood on its frame. Portraits in rings are the default now

### Changed
- **Menus:** Right-click menus on the quest window, XP box, threat meter and others are shorter. Settings you change rarely live in Settings now
- **ShyDock:** Your pet bar has a slim frame of its own now. The buttons are bigger and sit clear of the bars

## 5.2.3 (21 Nov 2026)

### Changed
- **ShyDock:** Request Stop on a flight sits in the extra ability's slot over your character
- **ShyQuest:** Errands no longer pull your route. Right-click one to take it and it leads until it's done
- **ShySkin:** The Shy button in the game menu opens Shy's home page

### Fixed
- **ShyBags:** Characters in your bag list showed the first two letters of the surname. They show your name's first letter and the surname's now
- **ShyCore:** A switch you can't change now showed in your accent color. It's pale grey now, so it reads as locked
- **ShyCore:** Your settings and layouts could split in two early in a session. They stay together now
- **ShyQuest:** Errand lines in your quest list sat cramped against what follows. They have room now
- **ShyQuest:** You got asked to switch guides in zones you were only passing through. It stays quiet on the way to your next step now
- **ShyQuest:** Gray quests your guide sends you for were skipped. They're accepted now, even with Gray quests too off
- **ShyQuest:** The crate at Three Corners and its twin in the Barrens sent you to a bank, auction house or mailbox. They don't now

### Removed
- **ShyDock:** You can't take a box out of the deck anymore. Boxes in the deck stay in it

## 5.2.2 (21 Nov 2026)

### Added
- **ShyBags:** Hover the gold button to see every character's gold on your realm. It also shows who has gold waiting in the mail
- **ShyBags:** The bag bar has a reagent bag slot. Dropping a bag on a worn one swaps them, even from inside it
- **ShyCore:** Any window docks to any other, on any side. Windows docked to one host line up past each other

### Changed
- **ShyBags:** Your character list and gold show only the characters on your realm. On a PvP realm that means your side too
- **ShyBags:** Your other characters are listed highest level first, then by gold. The one you're playing stays on top
- **ShyBags:** A character's hover on the bag rail opens to the left, clear of your bags
- **ShyBags:** You can size the mail, auction and gold windows. Mail letters show what they hold. Hovering the footer buttons says what they open
- **ShyQuest:** The guide asks you to talk to a flight master once so it learns your flight paths. It no longer says you may need ones you have

### Fixed
- **ShyBags:** The gold list could pick the wrong side on a PvP realm before the game named it. It keeps to your character's own realm now

## 5.2.1 (21 Nov 2026)

### Added
- **ShyCore:** One Settings room in /shy for every addon. Search it as you type. Each addon's command is now /shy and its name
- **ShyFrames:** Round portraits for your frames. Debuff rows start after the portrait and line up with it

### Changed
- **Shy:** The family does less work on busy moments. Coins, spellbook looks, tooltips and scaled windows no longer make every addon refresh
- **ShyAuction:** Scanning the auction house takes much less memory
- **ShyBags:** Item tooltips count what your characters hold faster
- **ShyCore:** Zooming the world map no longer redraws your route at every step. It redraws once you stop
- **ShyMaps:** Hovering an item for the first time no longer stalls. Dungeon drops load in the background after you log in
- **ShyQuest:** Guides check what applies to you faster. Fewer hitches while the route updates
- **ShyQuest:** Leveling guides are re-planned all the way to 60. Routes stay out of land you can't enter

### Fixed
- **ShyCore:** The Matrix look's scan on headers could jump back to the start. It runs smoothly now
- **ShyQuest:** A "Fly to Ironforge" step stayed on your route after you landed there. It clears now, and also after a portal or hearthstone
- **ShyWay:** The map's route from Ironforge's flight master started on the mountain top. It starts in the hall now
- **ShyWay:** Ironforge routes from the flight master started on the mountain top. They start in the hall now. Mines and fast mounts aren't taken for lifts or rides

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
