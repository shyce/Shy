# Shy

<p align="center">
  <a href="CHANGELOG.md"><img alt="version 5.2.16" src="https://img.shields.io/badge/version-5.2.16-29b3ff"></a>
  <img alt="released 26 Nov 2026" src="https://img.shields.io/badge/released-26_Nov_2026-4a5568">
  <img alt="tests 38,777 passed" src="https://img.shields.io/badge/tests-38%2C777_passed-4ade80">
  <img alt="WoW Forever 1.60.1" src="https://img.shields.io/badge/WoW_Forever-1.60.1-f4a623">
  <a href="https://www.curseforge.com/wow/addons/shy"><img alt="CurseForge get it" src="https://img.shields.io/badge/CurseForge-get_it-f16436?logo=curseforge&logoColor=white"></a>
  <a href="https://discord.gg/tuJ8EbDdSU"><img alt="Discord join us" src="https://img.shields.io/badge/Discord-join_us-5865F2?logo=discord&logoColor=white"></a>
  <a href="LICENSE.txt"><img alt="license GPL-3.0" src="https://img.shields.io/badge/license-GPL--3.0-3373ff"></a>
</p>

<p align="center"><img src="media/hero.jpg" alt="A fight in Redridge with the whole screen set up" width="100%"></p>

A family of World of Warcraft addons for WoW Forever: quests, maps, bags, unit frames, chat, the auction house
and more, all in one look you pick once.

## Questing

Your next step is always on screen, with an arrow that takes you there and the route drawn on your map. Take a
flight and the guide counts down until you land.

<table>
  <tr>
    <td width="50%"><img src="media/route.jpg" alt="The route on the map, beside the quest log"></td>
    <td width="50%"><img src="media/flying.jpg" alt="Flying over Westfall while the guide counts down"></td>
  </tr>
</table>

## Dungeons

Every dungeon has its map with the way through, what each boss does, and which of its drops are upgrades for you.

<table>
  <tr>
    <td width="50%"><img src="media/dungeon.jpg" alt="The Deadmines, boss by boss, with the upgrades for you"></td>
    <td width="50%"><img src="media/boss.jpg" alt="One boss: what it does and what it drops for you"></td>
  </tr>
</table>

## The auction house

See what's cheap against the market right now, and the best places to farm gold at your level.

<table>
  <tr>
    <td width="50%"><img src="media/ah-deals.jpg" alt="Deals under the market, with their price trends"></td>
    <td width="50%"><img src="media/ah-farm.jpg" alt="The best gold an hour for your level"></td>
  </tr>
</table>

## Bags and gear

Search finds an item on any of your characters, in their bags, bank or mail. Point at a piece of gear and see what
you'd gain and what you'd lose.

<table>
  <tr>
    <td width="50%"><img src="media/bags-search.jpg" alt="A search across every character's bags, bank and mail"></td>
    <td width="50%"><img src="media/gear.jpg" alt="Your character next to a new chest piece, compared"></td>
  </tr>
</table>

## Your look

Over thirty themes to pick from, or make your own.

<table>
  <tr>
    <td width="50%"><img src="media/stone.jpg" alt="The same kind of fight in another theme"></td>
    <td width="50%"><img src="media/themes.jpg" alt="Some of the themes"></td>
  </tr>
</table>

## Set it up once

The first time you log in on a character, setup opens and walks you through it: your theme, your layout and how
you want to play your class. It starts on what's recommended, so you can just press Finish. Your keys stay as they
are unless you pick a layout for them, and if you do, your old hotkeys are saved so you can go back any time.

<table>
  <tr>
    <td width="50%"><img src="media/setup.jpg" alt="Everything you picked, on one page"></td>
    <td width="50%"><img src="media/talents.jpg" alt="Picking how to play a priest"></td>
  </tr>
</table>

<p align="center"><img src="media/keys.jpg" alt="Your keys, laid out for how you play" width="80%"></p>

## Professions

Which recipes make money, which lose it, and how likely each one is to give you a skill-up.

<p align="center"><img src="media/cooking.jpg" alt="Cooking, with the profit on every recipe" width="60%"></p>

## What's new in 5.2.16

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

[Every release](CHANGELOG.md)

## Install

Get **Shy** from CurseForge with the CurseForge app (set the game version to WoW Forever first). Add
**Shy Ground** too if you want routes that follow the terrain; without it, the arrow points straight at where
you're going.

By hand: copy every folder here into `World of Warcraft\_forever_\Interface\AddOns`, and every folder of the
Shy-Ground repository too if you want it.

In game:

- `/shy setup` walks you through setting up the character you're on, all in one go. It opens by itself the first
  time you log in on a character, and you can run it again whenever you want a fresh start.
- `/shy` opens every setting, so you can change one thing at a time. Changes show right away.

## Community

Questions, bug reports and what's coming next: [join the Discord](https://discord.gg/tuJ8EbDdSU).

## License

Free software under the GNU General Public License, version 3 (`LICENSE.txt` in every folder). It is built
with others' work: `ShyCore/CREDITS.txt` names each one and its license, and the same list is in game under
`/shy`, Tools, Sources.

World of Warcraft and its art belong to Blizzard Entertainment. These addons are not made or endorsed by
Blizzard.

Each commit here is one release, exactly as it ships.
