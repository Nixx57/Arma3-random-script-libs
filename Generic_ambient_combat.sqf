//// //// //////////////////////////////////////////////////////////////////////////////////////////////
//                                           CONFIG                                                // 
//// //// //////////////////////////////////////////////////////////////////////////////////////////////

_SpawnAreaAroundPlayers = 2000; // Radius around players to spawn groups
_WaypointsArea = 500; // Radius around players to place waypoints
_GroupsLimit = 12;

_SpawnBLUFOR = true;
_SpawnOPFOR = true;
_SpawnINDEPENDENT = true;

_Interval = 30;

_ShowActiveGroups = true;
_MaxUnitsPerGroup = 12;

//// //// //////////////////////////////////////////////////////////////////////////////////////////////
//                                                 INIT                                               //
//// //// //////////////////////////////////////////////////////////////////////////////////////////////

// Scan function to generate vehicle libraries per side and faction
private _fnc_generateData = {
	params ["_sideNum"];
	private _data = createHashMap;
	private _cfg = configFile >> "CfgVehicles";

	private _filtered = "
	(getNumber (_x >> 'scope') == 2) &&
	(getNumber (_x >> 'side') == " + str _sideNum + ") &&
	(configName _x isKindOf 'AllVehicles') &&
	!(configName _x isKindOf 'ParachuteBase') &&
	!(configName _x isKindOf 'StaticWeapon')
	" configClasses _cfg;

	{
		private _faction = getText (_x >> "faction");
		if !(_faction in _data) then {
			_data set [_faction, []];
		};
		(_data get _faction) pushBack (configName _x);
	} forEach _filtered;
	_data
};

// Generate data libraries per side (once at init)
private _dataW = if (_SpawnBLUFOR) then {
	[1] call _fnc_generateData
} else {
	createHashMap
};
private _dataE = if (_SpawnOPFOR) then {
	[0] call _fnc_generateData
} else {
	createHashMap
};
private _dataI = if (_SpawnINDEPENDENT) then {
	[2] call _fnc_generateData
} else {
	createHashMap
};

//////////////////////////////////////////////////////////////////////////////////////////////////////
//                                           SPAWN FUNCTIONS                                        // 
//////////////////////////////////////////////////////////////////////////////////////////////////////

_Behaviour =
[
	"SAFE",
	"AWARE",
	"COMBAT",
	"STEALTH"
];

_Formations =
[
	"COLUMN",
	"STAG COLUMN",
	"WEDGE",
	"ECH LEFT",
	"ECH RIGHT",
	"VEE",
	"LINE",
	"FILE",
	"DIAMOND"
];

_Ranks =
[
	"PRIVATE",
	"CORPORAL",
	"SERGEANT",
	"LIEUTENANT",
	"CAPTAIN",
	"MAJOR",
	"COLONEL"
];

// Randomize vehicle textures
fnc_forceRandomizeTextures = {
	params ["_veh"];
	private _class = typeOf _veh;
	private _cfg = configFile >> "CfgVehicles" >> _class;

	private _allSources = [];
	private _currentCfg = _cfg;

	while { configName _currentCfg != "AllVehicles" } do {
		private _sources = "true" configClasses (_currentCfg >> "textureSources");
		if (count _sources > 1) exitWith {
			_allSources = _sources;
		};
		_currentCfg = inheritsFrom _currentCfg;
	};

	if (count _allSources > 0) then {
		private _randomTexture = configName (selectRandom _allSources);
		[_veh, _randomTexture, nil, true] call BIS_fnc_initVehicle;
	};
};

// Randomize vehicle animations (modules, like doors, hatches, etc.)
fnc_forceRandomizeAnims = {
	params ["_veh"];
	private _class = typeOf _veh;
	private _cfg = configFile >> "CfgVehicles" >> _class;

	private _allAnims = [];
	_currentCfg = _cfg;
	while { configName _currentCfg != "AllVehicles" } do {
		private _anims = "true" configClasses (_currentCfg >> "animationSources");
		if (count _anims > 0) exitWith {
			_allAnims = _anims;
		};
		_currentCfg = inheritsFrom _currentCfg;
	};

	if (count _allAnims > 0) then {
		private _animsToApply = [];
		{
			_animsToApply pushBack configName _x;
			_animsToApply pushBack (selectRandom [0, 1]);
		} forEach _allAnims;

		[_veh, nil, _animsToApply, true] call BIS_fnc_initVehicle;
	};
};

// Randomize pylons
fnc_forceRandomizePylons = {
	params ["_veh"];
	private _class = typeOf _veh;

	private _pylonPaths = "true" configClasses (configFile >> "CfgVehicles" >> _class >> "Components" >> "TransportPylonsComponent" >> "Pylons");

	if (count _pylonPaths > 0) then {
		{
			private _pylonName = configName _x;
			private _compatibleMags = _veh getCompatiblePylonMagazines _pylonName;

			if (!isNil "_compatibleMags" && {
				count _compatibleMags > 0
			}) then {
				private _mag = selectRandom _compatibleMags;
				_veh setPylonLoadout [_pylonName, _mag, false];
			};
		} forEach _pylonPaths;
	};
};

private _atSpawnedFnc = {
	_this setVariable ["isSpawned", true];
	_this setBehaviour (selectRandom _Behaviour);
	_this setSpeedMode "NORMAL";
	_this setCombatMode "RED";
	_this setFormation (selectRandom _Formations);
	_this deleteGroupWhenEmpty true;

	{
		_randomNum = [0, 1] call BIS_fnc_randomNum;
		_x setSkill _randomNum;
		_x setRank (selectRandom _Ranks);
	} forEach units _this;
};

private _spawnElement = {
	params ["_group", "_class", "_pos"];
	private _spawnedObj = objNull;

	if (_class isKindOf "Air") then {
		private _alt = 400 + (random 1000);
		_pos set [2, _alt];
		_spawnedObj = createVehicle [_class, _pos, [], 0, "FLY"];
		_spawnedObj setDir (random 360);
		_spawnedObj setVelocityModelSpace [0, 100, 0];
		createVehicleCrew _spawnedObj;
		(crew _spawnedObj) joinSilent _group;

		private _pylonPaths = "true" configClasses (configFile >> "CfgVehicles" >> _class >> "Components" >> "TransportPylonsComponent" >> "Pylons");

		if (count _pylonPaths > 0) then {
			{
				private _pylonIdx = _forEachIndex + 1;
				private _compatible = _spawnedObj getCompatiblePylonMagazines _pylonIdx;

				if (!isNil "_compatible" && {
					count _compatible > 0
				}) then {
					_spawnedObj setPylonLoadout [_pylonIdx, selectRandom _compatible, true];
				};
			} forEach _pylonPaths;
		};
	} else {
		if (_class isKindOf "Man") then {
			_spawnedObj = _group createUnit [_class, _pos, [], 5, "FORM"];
		} 
		else {
			_spawnedObj = createVehicle [_class, _pos, [], 0, "FORM"];
			createVehicleCrew _spawnedObj;
			(crew _spawnedObj) joinSilent _group;
		};
	};

	if !(_class isKindOf "Man") then {
    [_spawnedObj] call _fnc_forceRandomizeTextures;
	[_spawnedObj] call _fnc_forceRandomizeAnims;
	[_spawnedObj] call _fnc_forceRandomizePylons;
};
	_spawnedObj
};

//// //// //////////////////////////////////////////////////////////////////////////////////////////////
//                                         MAIN LOOP                                                  // 
//// //// //////////////////////////////////////////////////////////////////////////////////////////////

_Sides = [];
if (_SpawnBLUFOR) then {
	_Sides pushBack west
};
if (_SpawnOPFOR) then {
	_Sides pushBack east
};
if (_SpawnINDEPENDENT) then {
	_Sides pushBack independent
};

while { true } do {
	_activeGroups = allGroups select {
		_x getVariable ["isSpawned", false] && {
			alive _x
		} count units _x > 0
	};

	if (count _activeGroups < _GroupsLimit) then {
		private _side = selectRandom _Sides;
		private _lib = switch (_side) do {
			case west: {
				_dataW
			};
			case east: {
				_dataE
			};
			default {
				_dataI
			};
		};

		if (count _lib > 0) then {
			private _faction = selectRandom (keys _lib);
			private _unitPool = _lib get _faction;
			private _player = selectRandom allPlayers;

			if (!isNil "_player") then {
				private _newGroup = createGroup _side;
				private _targetSize = floor(random _MaxUnitsPerGroup) + 1;

				private _spawnPos = [[[position _player, _SpawnAreaAroundPlayers]]] call BIS_fnc_randomPos;
				_spawnPos set [2, 0];

				while { count (units _newGroup) < _targetSize } do {
					private _class = selectRandom _unitPool;

					private _currentPos = call {
						if (_class isKindOf "Air") exitWith { 
							_spawnPos 
						};

						if (_class isKindOf "Ship" || _class isKindOf "Submarine") exitWith {
							[[[_spawnPos, 500]], ["ground"]] call BIS_fnc_randomPos
						};

						[[[_spawnPos, 100]], ["water"]] call BIS_fnc_randomPos
					};

					[_newGroup, _class, _currentPos] call _spawnElement;

					if (count (units _newGroup) >= _targetSize) exitWith {};
				};

				_newGroup call _atSpawnedFnc;
			};
		};
	};

	{
		private _grp = _x;

		for "_i" from count waypoints _grp - 1 to 0 step -1 do {
			deleteWaypoint [_grp, _i];
		};

		private _p = selectRandom allPlayers;
		if (!isNil "_p") then {
			private _wpPos = [[[position _p, _WaypointsArea]], []] call BIS_fnc_randomPos;
			private _wp = _grp addWaypoint [_wpPos, 0];
			_wp setWaypointType "MOVE";
			_wp setWaypointSpeed "NORMAL";
		};

		{
			private _currentUnit = _x;

			if (allPlayers findIf {
				(_x distance _currentUnit) < _SpawnAreaAroundPlayers
			} == -1) then {
				if (vehicle _currentUnit != _currentUnit) then {
					deleteVehicle (vehicle _currentUnit);
				};
				deleteVehicle _currentUnit;
			};
		} forEach units _grp;
	} forEach (allGroups select {
		_x getVariable ["isSpawned", false]
	});

	if (_ShowActiveGroups) then {
		hintSilent format ["Active groups : %1", count _activeGroups];
	};
	sleep _Interval;
};
