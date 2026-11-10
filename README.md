# MidBoss for PortMaster

Port of **MidBoss** by Kitsune Games for PortMaster-compatible Linux handheld gaming devices (muOS, ArkOS, AmberELEC, ROCKNIX, JELOS, etc.).

## About the Game
*MidBoss* is a turn-based tactical roguelike about playing the ultimate underdog: an ambitious imp trapped in a dungeon who seeks to overthrow the dungeon master. By defeating other dungeon creatures, you can possess their bodies, gain their abilities, and use their powers to battle deeper into the dungeon!

## Requirements
- A PortMaster-compatible ARM Linux handheld (e.g. Anbernic RG35XX series, RG40XX, TrimUI Smart Pro, Powkiddy, etc.)
- PortMaster **Mono** runtime (`mono-6.12.0.122-aarch64.squashfs`, automatically installed via PortMaster)
- A legally purchased copy of *MidBoss* (DRM-free from [itch.io](https://kitsunegames.itch.io/midboss) or [Steam](https://store.steampowered.com/app/561740/MidBoss/))

## Installation Instructions

### Option 1: Automatic Setup on Device (Easiest)
1. Download or clone this port repository.
2. Copy `MidBoss.sh` and the `midboss/` folder into your handheld's `/roms/ports/` directory (or `/ports/` depending on your OS).
3. Place your purchased `MidBoss-Linux-142-bin` (or game zip) into `/roms/ports/midboss/gamedata/`.
4. Launch **MidBoss** from your Ports menu. PortMaster will extract the game data and configure it on first launch.

### Option 2: Pre-assemble on Mac / PC
1. Run the included `tools/extract_midboss.py` on your computer:
   ```bash
   python3 tools/extract_midboss.py /path/to/MidBoss-Linux-142-bin
   ```
2. Transfer the populated `gamedata/` folder, `MidBoss.sh`, and `midboss/` to your handheld SD card.

## Controls

| Handheld Button | Game Action |
| :--- | :--- |
| **D-Pad / Left Stick** | Move / Aim Direction |
| **A** | Confirm / Attack / Interact |
| **B** | Wait Turn (Rest) / Cancel |
| **X** | Possess Defeated Creature |
| **Y** | Inventory Screen |
| **L1 / R1** | Cycle Targets / Abilities |
| **Start** | Menu / Settings |
| **Select** | Dungeon Map & Message Log |

## Credits
- **Original Game**: Kitsune Games ([Official Website](https://kitsunegames.com/))
- **Mono / FNA Framework**: Ethan Lee (flibitijibibo) and the FNA community
- **Port Package**: [XenoSlug](https://github.com/XenoSlug)
