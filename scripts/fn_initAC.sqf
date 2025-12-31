// //// //// ////////////////////////////////////////////////////////////////////////////////////////////
//                                           CONFIG                                                // 
// //// //// ////////////////////////////////////////////////////////////////////////////////////////////

_SpawnAreaAroundPlayers = 2000; // Radius around players to spawn groups
_WaypointsArea = 500; // Radius around players to place waypoints
//_GroupsLimit = 12;
_UnitsLimit = 144;

_SpawnBLUFOR = true;
_SpawnOPFOR = true;
_SpawnINDEPENDENT = true;

_Interval = 30;

_ShowActiveGroups = true;
_MaxUnitsPerGroup = 12;

// //// //// ////////////////////////////////////////////////////////////////////////////////////////////
//                                                 INIT                                              // 
// //// //// ////////////////////////////////////////////////////////////////////////////////////////////

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
	!(configName _x isKindOf 'StaticWeapon') &&
	!(configName _x isKindOf 'Ship')
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
private _dataW = if (_SpawnBLUFOR) then {[1] call _fnc_generateData} else {createHashMap};
private _dataE = if (_SpawnOPFOR) then {[0] call _fnc_generateData} else {createHashMap};
private _dataI = if (_SpawnINDEPENDENT) then {[2] call _fnc_generateData} else {createHashMap};

//// //////////////////////////////////////////////////////////////////////////////////////////////////
//                                           spawn FUNCTIONS                                        // 
//// //////////////////////////////////////////////////////////////////////////////////////////////////

_Behaviour = ["SAFE", "AWARE", "COMBAT", "STEALTH"];
_Formations = ["COLUMN", "STAG COLUMN", "WEDGE", "ECH LEFT", "ECH RIGHT", "VEE", "LINE", "FILE", "DIAMOND"];
_Ranks = ["PRIVATE", "CORPORAL", "SERGEANT", "LIEUTENANT", "CAPTAIN", "MAJOR", "COLONEL"];

private _atSpawnedFnc = {
	_this setVariable ["isSpawnedGrp", true];
    _this setBehaviourStrong (/*selectRandom _Behaviour*/ "SAFE");
    _this setSpeedMode "NORMAL";
    _this setCombatMode "RED";
    _this setFormation (selectRandom _Formations);
    _this deleteGroupWhenEmpty true;

    private _highestRankIndex = -1;
    private _potentialLeader = objNull;
    {
		_x setVariable ["isSpawnedUnit", true];
		_x setSkill (([0, 100] call BIS_fnc_randomInt) / 100);
		private _allSkills = "true" configClasses (configFile >> "CfgAISkill");
		{
			private _skillName = configName _x;
			private _randomValue = (([0, 100] call BIS_fnc_randomInt) / 100);

			_x setSkill [_skillName, _randomValue];
    	} forEach _allSkills;

        
        private _rank = selectRandom _Ranks;
        _x setRank _rank;

        private _currentIndex = _Ranks find _rank;
        if (_currentIndex > _highestRankIndex) then {
            _highestRankIndex = _currentIndex;
            _potentialLeader = _x;
        };
    } forEach units _this;

    if (!isNull _potentialLeader) then {
        _this selectLeader _potentialLeader;
    };
};

private _spawnElement = {
	params ["_group", "_class", "_pos"];
	private _spawnedObj = objNull;
	_pos set [2, 0];
	if (_class isKindOf "Air") then {
		private _alt = 400 + (random 1000);
		_pos set [2, _alt];
		_spawnedObj = createVehicle [_class, _pos, [], 0, "FLY"];
		_spawnedObj setDir (random 360);
		_spawnedObj setVelocityModelSpace [0, 100, 0];
		createVehicleCrew _spawnedObj;
		(crew _spawnedObj) joinSilent _group;
	} else {
		if (_class isKindOf "Man") then {
			_spawnedObj = _group createUnit [_class, _pos, [], 5, "NONE"];
		} else {
			_spawnedObj = createVehicle [_class, _pos, [], 0, "NONE"];
			createVehicleCrew _spawnedObj;
			(crew _spawnedObj) joinSilent _group;
		};
	};

	if !(_class isKindOf "Man") then {
		_group addVehicle _spawnedObj;
		[_spawnedObj] call fnc_forceRandomizeTextures;
		[_spawnedObj] call fnc_forceRandomizeAnims;
		[_spawnedObj] call fnc_forceRandomizePylons;
	};
	_spawnedObj
};

// //// //// ////////////////////////////////////////////////////////////////////////////////////////////
//                                         MAIN LOOP                                                  // 
//// //// //// //////////////////////////////////////////////////////////////////////////////////////////

_Sides = [];
if (_SpawnBLUFOR) then {_Sides pushBack west};
if (_SpawnOPFOR) then {_Sides pushBack east};
if (_SpawnINDEPENDENT) then {_Sides pushBack independent};

while {true} do {
    private _activeGroups = allGroups select {(_x getVariable ["isSpawnedGrp", false]) && ({alive _x} count units _x > 0)};
	private _activeUnits = allUnits select {(_x getVariable ["isSpawnedUnit", false]) && (alive _x)};
	
	if ((count _activeUnits < _UnitsLimit) && (diag_fps > 35)) then {
		private _side = selectRandom _Sides;
		private _lib = switch (_side) do {case west: {_dataW}; case east: {_dataE}; default {_dataI}};

		if (count _lib > 0) then {
			private _faction = selectRandom (keys _lib);
			private _unitPool = _lib get _faction;
			private _player = selectRandom allPlayers;

			if (!isNil "_player") then {
				private _newGroup = createGroup _side;
				private _targetSize = floor(random _MaxUnitsPerGroup) + 1;

				_requiredDistance = _SpawnAreaAroundPlayers;

				if ((vehicle _player) isKindOf "Air") then {
					_requiredDistance = _requiredDistance + 4000;
				};

				private _spawnPos = [[[position _player, _requiredDistance]], [""]] call BIS_fnc_randomPos;

				while { count (units _newGroup) < _targetSize } do {
					private _class = selectRandom _unitPool;
					private _currentPos = call {
						if (_class isKindOf "Air") exitWith {
							[[[_spawnPos, 500]], []] call BIS_fnc_randomPos
						};
						if (_class isKindOf "Ship") exitWith {
							[[[_spawnPos, 500]], ["ground"]] call BIS_fnc_randomPos
						};

						[[[_spawnPos, 100]]] call BIS_fnc_randomPos
					};

					[_newGroup, _class, _currentPos] call _spawnElement;
				};
				_newGroup call _atSpawnedFnc;
			};
		};
	};
};

	{
		private _grp = _x;
		private _leader = leader _grp;

		if (alive _leader && {currentWaypoint _grp >= count waypoints _grp}) then {
        for "_i" from count waypoints _grp - 1 to 0 step -1 do {deleteWaypoint [_grp, _i]};

		private _p = selectRandom allPlayers;
		if (!isNil "_p") then {
			private _wpPos = [[[position _p, _WaypointsArea]]] call BIS_fnc_randomPos;
			if (_wpPos isEqualTo [0,0]) then {_wpPos = [[[position _p, _WaypointsArea]], []] call BIS_fnc_randomPos};
			private _wp = _grp addWaypoint [_wpPos, 0];
			_wp setWaypointSpeed "NORMAL";
		};

		{
			private _currentUnit = _x;
			private _unitVeh = vehicle _currentUnit;

			private _requiredDistance = _SpawnAreaAroundPlayers;

			if (_unitVeh isKindOf "Air") then {
				_requiredDistance = _requiredDistance + 4000;
			};

			private _isTooFar = allPlayers findIf {
				private _playerVeh = vehicle _x;
				private _dynamicDist = _requiredDistance;

				if (_playerVeh isKindOf "Air") then {
					_dynamicDist = _dynamicDist + 4000;
				};

				(_x distance _currentUnit) < _dynamicDist
			} == -1;

			if (_isTooFar) then {
				if (_unitVeh != _currentUnit) then {
					deleteVehicle _unitVeh;
				};
				deleteVehicle _currentUnit;
			};
		} forEach units _grp;
	} forEach _activeGroups;

	if (_ShowActiveGroups) then {hintSilent format ["Active units: %1", count _activeUnits]};
	sleep _Interval;
};