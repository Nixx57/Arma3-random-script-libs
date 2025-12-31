if (!isServer) exitWith {};
_configPath = configFile >> "CfgWorlds" >> worldName >> "Names";
_locations = "true" configClasses (_configPath);

_allSectors = [];

{
	_pos = getArray (_x >> "position");
	_displayName = getText (_x >> "name");
	_radiusA = getNumber (_x >> "radiusA");
	_radiusB = getNumber (_x >> "radiusB");
	_angle = getNumber (_x >> "angle");

	if (_displayName != "") then {
		_grp = createGroup sideLogic;

		_sector = _grp createUnit ["ModuleSector_F", _pos, [], 0, "NONE"];

		_sector setVariable ["Name", _displayName, true];
		_sector setVariable ["Sides", [west, east, resistance, civilian], true];
		_sector setVariable ["OwnerLimit", 1, true];
		_sector setVariable ["objectArea", [_radiusA, _radiusB, _angle, true, 0], true];

		//[_sector] call BIS_fnc_moduleSector;

		_trg = createTrigger ["EmptyDetector", _pos];
		_trg setTriggerArea [_radiusA, _radiusB, _angle, true];
		_trg setTriggerActivation ["ANY", "PRESENT", true];

		_sector setVariable ["areas", [_trg], true];

		_allSectors pushBack _sector;
	};
} forEach _locations;

systemChat format ["%1 sectors generated and activated.", count _allSectors];