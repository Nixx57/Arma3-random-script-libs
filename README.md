Sandbox.Malden — Arma 3 testing sandbox and random script library

This mission contains a collection of small Arma 3 SQF scripts and mission logic intended as a testbed for experiments and prototypes. The codebase is a set of proofs-of-concept (POC) used to test ideas — not a polished library. Expect informal code style and minimal optimizations.

Features
--------
- Dynamic spawning of units and vehicles around players (affects BLUFOR/OPFOR/Independent)
- Vehicle respawn and customization: random textures, animation sources, and pylon loadouts
- Sector generation (based on map names) and simple sector ownership behavior
- Utilities to collect unit lists by faction and to recruit AI via action

Usage
-----
1. Place the mission folder into your Arma 3 "Missions" folder or run it from the Editor.
2. Recommended: use `ModuleSector_F` if you plan to rely on sector behavior used by `initAC_Control`.
3. The mission is already configured to start the main systems from `initServer.sqf`:

	[] spawn SBX_fnc_respawnVeh;
	[] spawn SBX_fnc_initAC_Control;
	[] call SBX_fnc_loadout;

Key scripts
-----------
- `scripts/fn_initAC.sqf` — dynamic spawning around players (default behavior)
- `scripts/fn_initAC_Control.sqf` — controlled spawning using markers and sector behavior
- `scripts/fn_respawnVeh.sqf` — vehicle respawn and randomization (textures, anims, pylons)
- `scripts/fn_sectors.sqf` — auto-generate sector modules from map names
- `scripts/fn_randomUnitsArray.sqf` — build faction unit lists from `CfgVehicles`
- `scripts/fn_recruitAI.sqf` — spawn AI into a group (can be used as an action)
- `scripts/fn_has_support.sqf` — detect support-capable vehicles/crew

Notes & TODOs
--------------
- These scripts are POC: they may not follow strict SQF conventions and may need refactoring for production use.

Contributing
------------
If you want to contribute, please open an issue or a pull request. For now, changes to public function names should be coordinated to avoid breaking usage in missions.

License
-------
Add the license you prefer (MIT, etc.) or specify how you want the project licensed.

Contact
-------
Author: Nixx (repository owner)
