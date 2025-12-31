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

Placed helpers (mission.sqm)
----------------------------
- Base computers (Land_MultiScreenComputer_01_black_F) at spawn run addActions: CTRG recruit console ("Recruter IA full team"/"Recruter 1 IA") calling `SBX_fnc_recruitAI` with a CTRG-heavy pool (Story SF Captain, CTRG medic/engineer/GL LAT/AR, CTRG sharpshooter, Story Protagonist).
- Three drone pads use addActions to spawn and crew vehicles at markers with randomization helpers (`fnc_forceRandomizeTextures/Anims/Pylons`): Sentinel UAV (B_UAV_05_F → `sentinel_pos`), MQ-4A Greyhawk (B_UAV_02_dynamicLoadout_F → `mq4a_pos`), and Stomper RCWS UGV (B_UGV_01_rcws_F → `ugv_stomper_pos`). Crew skills are set to 1.
- Pre-placed markers: `respawn_west`, `blufor_ai`, `sentinel_pos`, `mq4a_pos`, `ugv_stomper_pos` (OPFOR/IND start markers are spawned server-side in `initServer.sqf`).
- Support requester modules in the mission are configured with `BIS_SUPP_HQ_WEST` and virtual support providers; support limits (UAV, Transport, Drop, CAS, Artillery) are set to `-1` (effectively unlimited). To call support in-game, use the vanilla radio: `0-8` (Support) then pick UAV/Transport/Drop/CAS/Artillery; follow the prompts (map click/target) to execute the request.
- Support units with SUPPORT waypoints: initial vehicles flagged as support (medic/repair/refuel/rearm/UAV/transport/CAS/arty) are scanned at mission start by `fn_respawnVeh.sqf`, tagged via `SBX_fnc_has_support`, and given SUPPORT waypoints so the engine can route them automatically when called from the radio menu `5-1`. These assets will also be recreated with the same role by the respawn loop.

Notes & TODOs
--------------
- These scripts are POC: they may not follow strict SQF conventions and may need refactoring for production use.

Contributing
------------
If you want to contribute, please open an issue or a pull request. For now, changes to public function names should be coordinated to avoid breaking usage in missions.

License
-------
This project is licensed under the Do What The Fuck You Want To Public License v2. See [LICENSE](LICENSE).

Contact
-------
Author: Nixx (repository owner)
