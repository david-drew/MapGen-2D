# MapGen-2D
### Version 0.1

This is a prototype 2D procedural map generation app.  It's built in Godot 4.5 gdscript.


## Features
* It creates 2x2 grid-based maps, populated procedurally from JSON data files.
* It can support image assets, but generates color-coded shapes by default.
* It has a UI to view and test map details.
* It should be modular enough to easily integrate in both 2D and 3D projects.

## Requirements
* Godot 4.5

## To Do
* A few biomes are still in dev: desert, swamp, beach
* Switching between generated maps (when applicable) is slow because there's no caching.
* Spawn points not integrated.
* Clue and story system not integrated (might be best to keep separate).
