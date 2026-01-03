// //// //// ////////////////////////////////////////////////////////////////////////////////////////////
//                                           CONFIG                                                // 
// //// //// ////////////////////////////////////////////////////////////////////////////////////////////

_SpawnAreaAroundPlayers = 2000; // Radius around players to spawn groups
_WaypointsArea = 500; // Radius around players to place waypoints

UnitsLimit = ["SBX_UnitsLimit", -1] call BIS_fnc_getParamValue;
SpawnOnMakers = (["SBX_SpawnOnMarkers", 1] call BIS_fnc_getParamValue) == 1;
CaptureSectors = (["SBX_CaptureSectors", 1] call BIS_fnc_getParamValue) == 1;

SpawnEAST = (["SBX_SpawnEAST", 1] call BIS_fnc_getParamValue) == 1;
SpawnWEST = (["SBX_SpawnWEST", 1] call BIS_fnc_getParamValue) == 1;
SpawnGUER = (["SBX_SpawnGUER", 1] call BIS_fnc_getParamValue) == 1;
SpawnCIV = (["SBX_SpawnCIV", 0] call BIS_fnc_getParamValue) == 1;

Interval = ["SBX_Interval", 30] call BIS_fnc_getParamValue;

ShowActiveUnits = (["SBX_ShowActiveUnits", 1] call BIS_fnc_getParamValue) == 1;
MaxUnitsPerGroup = ["SBX_MaxUnitsPerGroup", 12] call BIS_fnc_getParamValue;

private _behaviourList = ["RANDOM", "SAFE", "AWARE", "COMBAT", "STEALTH"];
private _index = ["SBX_UnitsBehaviours", 1] call BIS_fnc_getParamValue;
UnitsBehaviours = _behaviourList select _index;

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

//// //////////////////////////////////////////////////////////////////////////////////////////////////
//                                           spawn FUNCTIONS                                        // 
//// //////////////////////////////////////////////////////////////////////////////////////////////////

private _behaviours = ["SAFE", "AWARE", "COMBAT", "STEALTH"];
private _formations = ["COLUMN", "STAG COLUMN", "WEDGE", "ECH LEFT", "ECH RIGHT", "VEE", "LINE", "FILE", "DIAMOND"];
private _ranks = ["PRIVATE", "CORPORAL", "SERGEANT", "LIEUTENANT", "CAPTAIN", "MAJOR", "COLONEL"];

private _fnc_atSpawned = {
	private _artilleryVehicles = [];
	private _highestRankIndex = -1;
	private _potentialLeader = objNull;

	private _mode = switch (UnitsBehaviours) do {
		case "RANDOM": { selectRandom _behaviours };
		default { UnitsBehaviours };
	};

	_this setVariable ["isSpawnedGrp", true];
	_this setBehaviourStrong _mode;
	_this setSpeedMode "NORMAL";
	_this setCombatMode "RED";
	_this setFormation (selectRandom _formations);
	_this deleteGroupWhenEmpty true;
	
	{
		private _rank = selectRandom _ranks;
		private _currentIndex = _ranks find _rank;
		private _allSkills = "true" configClasses (configFile >> "CfgAISkill");

		// Randomize skills
		_x setSkill (([0, 100] call BIS_fnc_randomInt) / 100);
		{
			private _skillName = configName _x;
			private _randomValue = (([0, 100] call BIS_fnc_randomInt) / 100);

			_x setSkill [_skillName, _randomValue];
		} forEach _allSkills;

		// Mark unit as spawned
		_x setVariable ["isSpawnedUnit", true];

		// Set random rank
		_x setRank _rank;

		// Determine leader
		if (_currentIndex > _highestRankIndex) then {
			_highestRankIndex = _currentIndex;
			_potentialLeader = _x;
		};

		// Mark artillery vehicles
		private _veh = vehicle _x;
		if (_veh != _x && // Crew inside
			(getNumber (configFile >> "CfgVehicles" >> (typeOf _veh) >> "artilleryScanner") == 1) && 
			(!(_veh getVariable ["isArtilleryVehicle", false]))
		) then {
			_veh setVariable ["isArtilleryVehicle", true];
		};

		if (_veh != _x && (_veh isKindOf "Static")) then {
			private _crew = crew _veh;
			private _staticGrp = createGroup (side _x);
			{
				[_x] joinSilent _staticGrp;
				_x setVariable ["isSpawnedUnit", true];
			} forEach _crew;

			_staticGrp setVariable ["isSpawnedGrp", true];
			_staticGrp setBehaviourStrong _mode;
			_staticGrp setSpeedMode "NORMAL";
			_staticGrp setCombatMode "RED";
			_staticGrp deleteGroupWhenEmpty true;

			if (_potentialLeader in _crew) then {
				_potentialLeader = objNull;
				_highestRankIndex = -1;
			};
		};
	} forEach units _this;	

	if (!isNull _potentialLeader) then {
		_this selectLeader _potentialLeader;
	};
};

private _fnc_tryArtilleryFire = {
    params ["_artilleryVehicles", "_targetGroups"];

    {
        private _vehArty = _x;
        
        if (unitReady _vehArty) then {
            
            private _magsInInventory = (magazinesAmmo _vehArty) select { (_x select 1) > 0 };
            private _magsNames = _magsInInventory apply { _x select 0 };

            private _validEntries = [];

            {
                private _targetPos = getPosATL (leader _x);
                
                private _availableMagsAtPos = getArtilleryAmmo [_vehArty] select { 
                    (_x in _magsNames) && { _targetPos inRangeOfArtillery [[_vehArty], _x] }
                };

                if (count _availableMagsAtPos > 0) then {
                    private _chosenMag = selectRandom _availableMagsAtPos;
                    
                    private _idx = _magsInInventory findIf { (_x select 0) == _chosenMag };
                    private _stock = (_magsInInventory select _idx) select 1;

                    _validEntries pushBack [_targetPos, _chosenMag, _stock];
                };
            } forEach _targetGroups;

            if (count _validEntries > 0) then {
                private _selection = selectRandom _validEntries;
                _selection params ["_fpos", "_fmag", "_fstock"];

				private _maxAllowed = (_fstock min 9);
                private _shots = (floor (random _maxAllowed)) + 1;

                _vehArty doArtilleryFire [_fpos, _fmag, _shots];

				private _displayName = getText (configFile >> "CfgVehicles" >> typeOf _vehArty >> "displayName");
				private _gridPos = mapGridPosition _fpos;
				private _magName = getText (configFile >> "CfgMagazines" >> _fmag >> "displayName");

				_vehArty sideChat format ["[%1] - Firing %2 rounds of %3 at Grid %4", 
					_displayName, 
					_shots, 
					_magName, 
					_gridPos
				];
            };
        };
    } forEach _artilleryVehicles;
};

private _fnc_spawnObject = {
	params ["_group", "_class", "_pos"];
	private _spawnedObj = objNull;
	_pos set [2, 0];
	if (_class isKindOf "Air") then {
		private _alt = 400 + (random 1000);
		_pos set [2, _alt];
		_spawnedObj = createVehicle [_class, _pos, [], 0, "FLY"];
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
	_spawnedObj setDir (random 360);
	_spawnedObj
};

private _fnc_markerExists = {
    params ["_markerName"];
    (markerColor _markerName != "")
};

private _fnc_generateMarker = {
	params ["_side"];
	private _markerPos = [] call BIS_fnc_randomPos;
	private _markerName = format ["%1_ai", (str _side)];
	private _markerObj = createMarker [_markerName, _markerPos];
	private _markerColor = format ["Color%1", (str _side)];

	_markerObj setMarkerColor _markerColor;
	_markerObj setMarkerShape "ELLIPSE";
	_markerObj setMarkerSize [100, 100];
	_markerObj setMarkerAlpha 1;
	private _hq = missionNamespace getVariable (format ["BIS_SUPP_HQ_%1", (str _side)]);
	_hq setPos (getMarkerPos _markerName);
};

// //// //// ////////////////////////////////////////////////////////////////////////////////////////////
//                                         MAIN LOOP                                                  // 
//// //// //// //////////////////////////////////////////////////////////////////////////////////////////

// Generate data libraries per side (once at init)
DataEAST = if (SpawnEAST) then {[0] call _fnc_generateData} else {createHashMap};
DataWEST = if (SpawnWEST) then {[1] call _fnc_generateData} else {createHashMap};
DataGUER = if (SpawnGUER) then {[2] call _fnc_generateData} else {createHashMap};
DataCIV = if (SpawnCIV) then {[3] call _fnc_generateData} else {createHashMap};


_Sides = [];
{
    // _x = side
    private _sideName = str _x; // "WEST", "EAST", etc.
    private _spawnSide = missionNamespace getVariable [format ["Spawn%1", _sideName], false];

    if (_spawnSide) then {
        _Sides pushBack _x;
        
		if (SpawnOnMakers) then {
			private _markerName = format ["%1_ai", _sideName];
			
			if !([_markerName] call _fnc_markerExists) then {
				[_x] call _fnc_generateMarker;
			};
		}
    };
} forEach [west, east, resistance, civilian];

while {true} do {
    private _activeGroups = allGroups select {(_x getVariable ["isSpawnedGrp", false]) && ({alive _x} count units _x > 0)};
	private _activeUnits = allUnits select {(_x getVariable ["isSpawnedUnit", false]) && (alive _x)};

	if (((count _activeUnits < UnitsLimit) || UnitsLimit == -1) && (diag_fps > 35)) then {
		private _side = selectRandom _Sides;
		private _sideName = str _side;
		private _lib = missionNamespace getVariable (format ["Data%1", _sideName]);

		if (count _lib > 0) then {
			private _faction = selectRandom (keys _lib);
			private _unitPool = _lib get _faction;
			private _newGroup = createGroup _side;
			private _targetSize = floor(random MaxUnitsPerGroup) + 1;
			private _spawnPos = [0,0,0];

			if (SpawnOnMakers) then {
				private _marker = format ["%1_ai", _sideName];
				private _mPos = getMarkerPos _marker;
				private _mSize = getMarkerSize _marker; 

				_spawnPos = _mPos;
			}
			else {
				private _player = selectRandom allPlayers;

				if (!isNil "_player") then {
					_requiredDistance = _SpawnAreaAroundPlayers;

					if ((vehicle _player) isKindOf "Air") then {
						_requiredDistance = _requiredDistance + 4000;
					};
					_spawnPos = [[[position _player, _requiredDistance]], [""]] call BIS_fnc_randomPos;
				};
			};
			
			while { (count (units _newGroup) < _targetSize) } do {
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

				[_newGroup, _class, _currentPos] call _fnc_spawnObject;
			};
			_newGroup call _fnc_atSpawned;

		};
	};

	private _allSectors = entities "ModuleSector_F";

	{
		private _grp = _x;
		private _sideGrp = side _grp;
		private _leader = leader _grp;
		private _wpPos = nil;

		if (alive _leader && {currentWaypoint _grp >= count waypoints _grp}) then 
		{
			for "_i" from count waypoints _grp - 1 to 0 step -1 do {deleteWaypoint [_grp, _i]};

			if (CaptureSectors) then {
				private _enemySectors = _allSectors select {
					([_sideGrp, (_x getVariable ["owner", sideUnknown])] call BIS_fnc_sideIsEnemy) || 
					((_x getVariable ["owner", sideUnknown]) == sideUnknown)
				};

				private _targetSector = objNull;
				if (count _enemySectors > 0) then {
					_targetSector = [_enemySectors, _leader] call BIS_fnc_nearestPosition;
				};

				_wpPos = if (!isNull _targetSector) then {
					[[[getPos _targetSector, ((_targetSector getVariable "objectArea" select 0) max (_targetSector getVariable "objectArea" select 1))]]] call BIS_fnc_randomPos
				} else {
					[[[getPos _leader, 1000]]] call BIS_fnc_randomPos
				};

				if (_wpPos isEqualTo [0, 0]) then {
					_wpPos = if (!isNull _targetSector) then {
						[[[getPos _targetSector, ((_targetSector getVariable "objectArea" select 0) max (_targetSector getVariable "objectArea" select 1))]], []] call BIS_fnc_randomPos
					} else {
						[[[getPos _leader, 1000]], []] call BIS_fnc_randomPos
					};
				};
			} else {
				private _p = selectRandom allPlayers;
				if (!isNil "_p") then {
					_wpPos = [[[position _p, _WaypointsArea]]] call BIS_fnc_randomPos;
					if (_wpPos isEqualTo [0,0]) then {_wpPos = [[[position _p, _WaypointsArea]], []] call BIS_fnc_randomPos};
				};
			};
			private _wp = _grp addWaypoint [_wpPos, 0];
			_wp setWaypointSpeed "NORMAL";
		};

		// Artillery fire
		private _artilleryVehicles = [];
		{
			private _veh = vehicle _x;
			if (_veh != _x && {_veh getVariable ["isArtilleryVehicle", false]}
			) then {
				_artilleryVehicles pushBack _veh;
			};
		} forEach units _grp;

		if (count _artilleryVehicles > 0) then {
			private _spottedGroups = ([[]] call BIS_Marta_getVisibleGroups) select {([side _grp, side _x] call BIS_fnc_sideIsEnemy)};
			private _eligibleTargets = _spottedGroups select {
				!(vehicle (leader _x) isKindOf "Air")
			};
			if (count _eligibleTargets > 0) then {
				[_artilleryVehicles, _eligibleTargets] call _fnc_tryArtilleryFire;
			};
		};

		// Clean up distant units, no longer used for now

		// {
		// 	private _currentUnit = _x;
		// 	private _unitVeh = vehicle _currentUnit;

		// 	private _requiredDistance = _SpawnAreaAroundPlayers;

		// 	if (_unitVeh isKindOf "Air") then {
		// 		_requiredDistance = _requiredDistance + 4000;
		// 	};

		// 	private _isTooFar = allPlayers findIf {
		// 		private _playerVeh = vehicle _x;
		// 		private _dynamicDist = _requiredDistance;

		// 		if (_playerVeh isKindOf "Air") then {
		// 			_dynamicDist = _dynamicDist + 4000;
		// 		};

		// 		(_x distance _currentUnit) < _dynamicDist
		// 	} == -1;

		// 	if (_isTooFar) then {
		// 		if (_unitVeh != _currentUnit) then {
		// 			deleteVehicle _unitVeh;
		// 		};
		// 		deleteVehicle _currentUnit;
		// 	};
		// } forEach units _grp;
	} forEach _activeGroups;

if (ShowActiveUnits) then {hintSilent format ["Active units: %1", count _activeUnits]};
	sleep Interval;
};