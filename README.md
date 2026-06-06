# Sans Vs Chara: The Hollow Route

**Sans Vs Chara: The Hollow Route** is a Roblox Undertale-inspired battlegrounds game made by a small team of friends. The game focuses on fast combat, flashy character kits, satisfying movement, and a lightweight lore setup centered around **Hollow Snowdin** and **The Hollow Route**.

The project started on **5/27/2026** and is currently in an early combat-polish / private testing stage.

---

## About the Game

The Hollow Route is not a normal timeline. It is a corrupted battle-scar left behind by broken violent routes, unfinished fights, LOVE, and timeline damage.

Chara, fresh from defeating a different Sans in another Judgement Hall, is misrouted into Hollow Snowdin and attacks a Sans who does not fully understand why his Snowdin has gone empty. The world is hollow, looping, and reacting to violence.

The story is intentionally lightweight so the main focus stays on battlegrounds gameplay.

---

## Current Playable Characters

### Chara

Chara is a rushdown / pressure character built around close-range offense, knife attacks, combo pressure, and dangerous punishes.

Current kit includes:

* M1 combo chain
* Knife Dash
* Red Slash
* Slash Barrage
* Killing Intent
* Special Hell ultimate
* RealKnife weapon system

### Sans

Sans is a zoning / control character built around bones, blue soul control, Gaster Blasters, and punishing bad movement.

Current kit includes:

* M1 VFX
* Bone Shot
* Bone Zone
* Blue Snare
* Gaster Blaster
* Bad Time ultimate
* DamageLock / ReservedVictim support

---

## Future / Test Characters

These characters have early folders, weapons, or animation assets, but are not release-ready yet.

### Disbelief Papyrus

Planned as a bone-staff fighter with aggressive bone attacks and Disbelief-inspired pressure.

Current setup:

* Character folder
* Weapon module
* BoneStaff weapon
* Placeholder move data
* Animation assets in progress

### Glitchtale Frisk

Planned as a sword-and-shield fighter using Determination-inspired attacks.

Current setup:

* Character folder
* Weapon module
* GT Frisk Sword
* GT Frisk Shield
* Placeholder move data
* Animation assets in progress

### Toriel

Planned as a protective fire bruiser / royal guardian.

Concept direction:

* Fire-fist martial arts
* Royal Reprimand / Mother’s Grip
* Flame Pillar
* Guardian Break
* Royal Snap
* Royal Pyre / Final Flame ultimate

---

## Current Systems

The game currently has:

* Character selection
* Character weapons
* M1 combo system
* Uptilt
* Downslam
* Blocking
* Guardbreak
* Armor
* IFrames
* Stun
* Damage numbers
* Standardized knockback behavior
* Ground-splat downslam system
* Ultimate meter
* Ultimate damage no longer gives ult meter
* DamageLock system
* ReservedVictim support
* Dust currency
* Dust DataStore saving
* Character unlock saving
* RespawnDummy testing
* Debug knockback visuals
* Topbar UI
* Shop/customization direction
* Hollow Snowdin map direction

---

## Current Balance Direction

The current balance goal is:

* Chara should feel fast, aggressive, and dangerous up close.
* Sans should feel tricky, ranged, and control-focused.
* Ultimates are allowed to be extremely dangerous because they require ult meter.
* Normal moves should not instantly delete players.
* Movement and knockback should feel readable and fair.
* Strong moves should be punishable if interrupted.
* Combos should feel good, but not infinite.

Upcoming combat system goal:

* **SOUL BURST** evasive system
  A combo-break / defensive burst mechanic built from taking long combos. The player will build a bar, press **R**, gain brief IFrames, and knock enemies away.

---

## Development Team

This is a passion project made by a small team of friends who enjoy Undertale-inspired combat, animation, and creative Roblox games.

### @nickjvang

**Lead Developer / Main Scripter**

Handles the main combat systems, character kits, move logic, UI, progression, balancing, debugging, Rojo/Git workflow, and overall project direction.

### @CharieSvang1

**Animator / Asset Creator / Tester**

Helps create character animations, assists with assets, tests moves, and gives feedback on combat feel.

### @Lastly_One

**Animator / Builder / Tester**

Works on animations, helps build and polish maps/environments, tests gameplay, and helps improve the feel of the game.

### @DeclinedFool

**Tester**

Tests characters, moves, bugs, balance, and overall gameplay to help make the game smoother and more fun.

### @yunavang

**Builder**

Helps build and polish maps, arenas, props, and environmental details for the game world.

We are still learning and improving as we build, but we are passionate about making this project the best it can be.

---

## Project Structure

This project uses **Rojo** to sync code between VS Code and Roblox Studio.

Common folders:

```text
src/
  ReplicatedStorage/
    Assets/
      Characters/
        Chara/
        Sans/
        Toriel/
        DisbeliefPapyrus/
        GlitchtaleFrisk/
    Shared/
    Packages/

  ServerScriptService/
    CombatServer/
    TestTools/

  StarterPlayer/
    StarterPlayerScripts/
```

Important areas:

```text
CombatServer
- Core combat services
- M1Service
- MoveService
- MovementService
- HitboxService
- BlockService
- StateService
- ProjectileService
- DamageNumberService
- ProgressionService
- UltService

ReplicatedStorage/Assets/Characters
- Character animations
- Character VFX
- Character SFX
- Character weapons
- Character move modules

StarterPlayerScripts
- CombatClient
- TopbarUI
- CharacterMovementAnimator
```

---

## Rojo Workflow

Start Rojo from the project root:

```bash
rojo serve
```

Then connect using the Roblox Studio Rojo plugin.

Recommended workflow:

1. Edit scripts in VS Code.
2. Let Rojo sync changes into Studio.
3. Test in Studio.
4. Commit stable changes to Git.
5. Avoid editing Rojo-managed scripts directly in Studio unless you copy the changes back into VS Code.

---

## Development Status

Current status:

```text
Private testing / early combat polish
```

Current estimated progress:

```text
Private friend test: 85–90% ready
Small public test: 70–75% ready
Polished public release: 55–65% ready
```

Main next goals:

* Add SOUL BURST evasive system
* Finish combat polish
* Test Chara vs Sans with real players
* Polish UI feedback
* Add more lore/map interactions
* Continue future character development
* Improve VFX/SFX timing
* Add more debug tools
* Prepare private testing build

---

## Notes

This project is inspired by Undertale-style battles and Roblox battlegrounds games, but it is being built with its own lore identity through **The Hollow Route** and **Hollow Snowdin**.

The project is still under active development, so code, balance, moves, and names may change frequently.
