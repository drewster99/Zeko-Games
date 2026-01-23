# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Greenbean is a single-file HTML5 side-scrolling platformer game built with vanilla JavaScript, Canvas 2D API, and WebGL for background effects. The entire game is contained in `index.html` (~2450 lines).

## Running the Game

```bash
# Simply open the HTML file in a browser
open index.html

# Or serve it locally (if you need to test web features)
python3 -m http.server 8000
# Then navigate to http://localhost:8000
```

No build process, dependencies, or compilation required - it's pure HTML/CSS/JavaScript.

## Architecture

### Game Structure

The game uses a classic game loop architecture with the following main components:

1. **Game Loop** (`gameLoop()` at line ~2432):
   - Runs via `requestAnimationFrame()`
   - Calls `updateGame(dt)` and `renderGame()` when in PLAYING state
   - Renders WebGL background effects every frame

2. **Core Classes**:
   - `Player` (line ~883): Main character with physics (position, velocity, jumping, shooting)
   - `Enemy` (line ~1170): Enemies with multiple types and behaviors:
     - **Normal** (red): Basic chasing enemy
     - **Fast** (orange): Quick runner with less health, sleek triangular design
     - **Tank** (gray): Slow, armored, lots of health, rectangular with armor plates
     - **Flyer** (green): Ignores gravity, flies in circular patterns with wings
     - **Jumper** (magenta): Hops toward player periodically
     - **Shooter** (cyan): Keeps distance and fires projectiles at player
   - `Boss` (line ~1361): Special blue enemy for boss levels (every 10 levels) with multi-phase behavior and minion spawning
   - `Particle` (line ~666): Visual effects system for explosions, impacts, etc.

3. **Level Generation** (`generateLevel(levelNum)` at line ~699):
   - Procedurally generates platforms, enemies, collectibles, and powerups
   - **Boss levels** occur every 10 levels (10, 20, 30... 100) with special arena layout
   - **Mini game levels** occur every 5 levels (5, 15, 25, 35... 95) - not on boss levels
   - Uses standardized platform widths (multiples of `PLATFORM_WIDTH_UNIT = 80`)
   - Ensures platform reachability based on max jump height (~130px) and distance (~250px)
   - Difficulty scales with level number but is capped to prevent extreme difficulty
   - Enemy variety increases with level:
     - Levels 1-2: Normal and fast enemies
     - Levels 3-4: Normal, fast, jumper, and flyer enemies
     - Levels 5+: All enemy types (normal, fast, tank, flyer, jumper, shooter)

4. **Mini Games** (`generateMiniGame(levelNum)` at line ~699):
   - Four rotating mini game types that provide variety:
     - **Target Shooting** (type 0): Shoot static bullseye targets - 8 targets in various positions
     - **Collectible Rush** (type 1): Collect 50 collectibles scattered throughout the arena
     - **Survival Wave** (type 2): Defeat 12 enemies in an arena with cover platforms and powerups
     - **Platforming Challenge** (type 3): Vertical platforming gauntlet with zigzag platforms

5. **Rendering Layers**:
   - `bgCanvas`: WebGL shader-based animated background (z-index: 1)
   - `gameCanvas`: Main 2D game rendering (z-index: 2)
   - `glitchOverlay`: Visual effects for taking damage (z-index: 2)
   - `#ui`: DOM-based UI overlay (z-index: 3)
   - Screen overlays for menus (z-index: 4)

6. **Game States**:
   - `START`: Initial menu screen
   - `PLAYING`: Active gameplay
   - `LEVEL_COMPLETE`: Level transition screen
   - `GAME_OVER`: Death/restart screen

### Key Systems

**Physics Constants**:
- `GRAVITY = 0.8` - Applied to player/enemies each frame
- `JUMP_STRENGTH = -15` - Initial upward velocity for jumps
- `MOVE_SPEED = 1.5` - Horizontal movement speed
- `PLAYER_SIZE = 40` - Collision box size

**Camera System**:
- Side-scrolling camera follows player horizontally via `cameraX`
- Keeps player in view while allowing level exploration
- Used for rendering: `x - cameraX` for screen-space positioning

**Powerup System** (tracked in `powerups` object):
- `doubleJump`: Allows mid-air jumping (stacks infinitely, persists across levels)
- `rapidFire`: Increases shooting rate (timed, 20 seconds)
- `zeroGravity`: Reduces gravity effect (timed, 15 seconds)
- `shield`: Prevents one hit of damage (toggle, consumed on hit)
- `invincibility`: Complete immunity from all damage (permanent for the level)
- `bigBoy`: Increases player size (timed, 15 seconds)
- `enemySleep`: Puts all enemies to sleep (timed, 20 seconds)
- Most powerups are duration-based except doubleJump (stacks) and invincibility (permanent per level)

**Collision Detection**:
- AABB (axis-aligned bounding box) for all entities
- Platform collision uses bottom-of-player alignment
- Enemy/projectile collision uses center-point checks
- Special `fallingIntoGoal` flag disables collision when entering goal

**Projectile System**:
- Three types of projectiles: player (yellow), boss (red), and enemy (cyan)
- Player projectiles have random angle variation (up to 7 degrees)
- Boss projectiles are larger and deal damage to player
- Enemy projectiles from shooter enemies deal damage to player
- All projectiles have particle trail effects and glow rendering

**Audio System**:
- Procedural audio using Web Audio API (`AudioContext`)
- No external audio files - all sounds generated via oscillators
- Background music with note sequences
- Sound effects for jumps, shots, hits, collectibles

### WebGL Shader Background

The background uses custom vertex and fragment shaders (lines ~200-260) with:
- Time-based animations (`u_time` uniform)
- Glitch effects (`u_glitch` uniform - activated on damage)
- Level-based color themes (`u_levelTheme` uniform)

### State Management

Global variables track game state:
- `gameState`: Current screen/mode
- `currentLevel`: Level number (1-100)
- `score`, `health`, `gameTime`: Player stats
- `glitchIntensity`, `glitchEndTime`: Visual damage feedback
- `highScore`: Persisted to `localStorage`
- `cameraX`: Camera scroll position
- `powerups`: Active powerup states (timers and flags)
- `boss`: Boss instance (only on boss levels, every 10 levels)

### Input Handling

Keyboard controls (lines ~1525-1550):
- Arrow keys / WASD: Movement
- Space: Jump (double jump if powerup active)
- X key: Shoot projectiles (respects cooldown)
- Click anywhere: Starts game / advances screens
- Cheat codes during gameplay:
  - `5`: Jump to level 5 (first mini game)
  - `8`: Jump to level 10 (first boss)
  - `9`: Jump to level 90 (9th boss)
  - `0`: Jump to level 100 (final boss)

## Development Guidelines

### Making Changes

When modifying the game:

1. **Visual Changes**: Look for Canvas 2D rendering calls in `renderGame()` and entity `draw()` methods
2. **Physics/Gameplay**: Modify constants at lines ~261-272 or update methods in Player/Enemy classes
3. **Level Design**: Adjust `generateLevel()` function for procedural changes, or modify boss level hardcoded layout
4. **WebGL Effects**: Edit shader source strings at lines ~200-260
5. **UI/Styling**: CSS is inline in `<style>` tag at top of file (lines ~7-190)

### Testing Changes

Simply refresh the browser after editing `index.html`. No build step required.

For debugging:
- Open browser DevTools Console for errors/logs
- Use `console.log()` in game loop to inspect state
- WebGL errors will appear in console if shaders fail to compile

### Performance Considerations

The game runs at 60 FPS via `requestAnimationFrame()`:
- Delta time (`dt`) is capped at 0.1s to prevent physics glitches
- Particle systems are culled when dead
- Projectiles removed when off-screen
- Camera culling could be added for large levels if needed

### Common Modifications

**Adding a new enemy type**: Enemy class supports multiple types via `enemyType` parameter. Add new case to switch statement in `update()` method for behavior, add rendering in `draw()` method, and add to spawn logic in `generateLevel()` (line ~797)

**New powerup**: Add property to `powerups` object, create pickup in `generateLevel()`, handle collection in `updateGame()`, implement effect in relevant update methods

**Adjusting difficulty**: Modify enemy spawn rates in `generateLevel()` (line ~798), change enemy speed/health in `Enemy` class, adjust `GRAVITY`/`JUMP_STRENGTH` constants. Note: difficulty scaling is capped to prevent extremes:
- Enemy spawn rate caps at 0.8
- Enemy health caps at 10
- Level width caps at level 20 equivalent (24,000 pixels)
- Powerup count caps at 12 per level
- Boss health scales as: 50 + (bossNumber - 1) * 10

**Visual themes**: Edit shader `u_levelTheme` uniform usage in fragment shader, or modify particle colors in collision code

**Boss battles**: Bosses appear every 10 levels. They are blue, spawn minions, have 3 phases, and stay within arena bounds (x: 100-1100)
