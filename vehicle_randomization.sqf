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
