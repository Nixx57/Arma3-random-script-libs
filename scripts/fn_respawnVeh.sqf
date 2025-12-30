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
		_anims = _anims select {
			private _displayName = getText (_x >> "displayName");
			_displayName != ""};
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

fnc_veh_respawn = {
    params ["_veh", "_pos", "_dir", "_type", "_custom", "_pylons", "_pylonPaths", "_hadCrew", "_hadSupport"];    
        
    private _grp = group _veh;
    _grp deleteGroupWhenEmpty false;
    private _side = side _grp;
    private _active = true;
	private _initialCount = count (units _grp);

    while { _active } do {
        sleep 10;

        private _isDead = !alive _veh;
        private _isEmpty = (count (crew _veh select {alive _x})) == 0;

        private _currentAliveCount = count (units _grp select {alive _x});
        private _anyCrewDead = (_currentAliveCount < _initialCount);
        
        private _isFarFromAnyUnit = (count (allUnits select { (_x distance2D _veh < 100) })) == 0;
        private _isFarFromOriginalPos = (_veh distance2D _pos) > 100;

        // --- VEHICLES ---
        if (!(_veh isKindOf "Man") && (_isDead || _anyCrewDead || (_isEmpty && _isFarFromAnyUnit && _isFarFromOriginalPos))) then {
            sleep 60;
            
            // Double check
			private _isDead = !alive _veh;
			private _isEmpty = (count (crew _veh select {alive _x})) == 0;
			private _anyCrewDead = (_currentAliveCount < _initialCount);
			private _isFarFromAnyUnit = (count (allUnits select { (_x distance2D _veh < 100) }) == 0);
			private _isFarFromOriginalPos = (_veh distance2D _pos) > 100;
			if (!(_isDead || _anyCrewDead || (_isEmpty && _isFarFromAnyUnit && _isFarFromOriginalPos))) then { continue; };
            { deleteVehicle _x } forEach (units _grp);
            deleteVehicle _veh;
            sleep 1;

            _veh = createVehicle [_type, _pos, [], 0, "CAN_COLLIDE"];
            _veh setDir _dir;
            _veh setPos _pos;

            [_veh, _custom select 0, _custom select 1] call BIS_fnc_initVehicle;
            { _veh setPylonLoadout [_pylonPaths select _forEachIndex, _x, true]; } forEach _pylons;

            if (_hadCrew || unitIsUAV _veh) then {
                createVehicleCrew _veh;
                if (!isNull _grp) then { (crew _veh) joinSilent _grp; };
            };
        };

        // --- MAN ---
        if ((_veh isKindOf "Man") && _isDead) then {
            sleep 60;
            deleteVehicle _veh;
            
            if (isNull _grp) then { _grp = createGroup [_side, true]; };
            _veh = _grp createUnit [_type, _pos, [], 0, "NONE"];
            _veh setDir _dir;
            
            _veh setSkill 1;
            { _veh setSkill [configName _x, 1]; } forEach ("true" configClasses (configFile >> "CfgAISkill"));
        };

        if (_hadSupport && !isNull _grp) then {
            private _hasWP = false;
            { if (waypointType _x == "SUPPORT") exitWith { _hasWP = true }; } forEach (waypoints _grp);
            
            if (!_hasWP) then {
                private _wp = _grp addWaypoint [_pos, 0];
                _wp setWaypointType "SUPPORT";
                _grp setVariable ["hasSupportWaypoint", true, true];
            };
        };
    };
};

// Initial scan 
{
    if (!isPlayer _x && !(_x in playableUnits) && !(_x in switchableUnits) && (vehicle _x == _x)) then {
        private _type = typeOf _x;
        private _grp = group _x;
        private _hasSupport = false;
		private _hadCrew = ((count crew _x) > 0) && !(_x isKindOf "Man");


        if ((!isNull _grp && !(_grp getVariable ["hasSupportWaypoint", false])) || _hadCrew) then {
            _hasSupport = [_x] call SBX_fnc_has_support;
            
            if (!_hasSupport) then {
				{
					_hasSupport = [_x] call SBX_fnc_has_support;
					if (_hasSupport) then {
						break;
					};
				}forEach (units _grp);
			};

            if (_hasSupport) then {                
                if !(_grp getVariable ["hasSupportWaypoint", false]) then {
					private _pos = getPos _x;
					_pos set [2, 0];
                    private _wpInit = _grp addWaypoint [_pos, 0];
                    _wpInit setWaypointType "SUPPORT";
                    _grp setVariable ["supportWaypoint", _wpInit, true];
                    _grp setVariable ["hasSupportWaypoint", true, true];
                };
            };
        };

        private _pylonPaths = (configProperties [configFile >> "CfgVehicles" >> _type >> "Components" >> "TransportPylonsComponent" >> "Pylons", "isClass _x"]) apply {configName _x};

        [_x, getPos _x, getDir _x, _type, [_x] call BIS_fnc_getVehicleCustomization, getPylonMagazines _x, _pylonPaths, _hadCrew, _hasSupport] spawn fnc_veh_respawn;
    };
} forEach entities "AllVehicles";