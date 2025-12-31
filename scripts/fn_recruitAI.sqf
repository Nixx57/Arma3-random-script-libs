/*
    Example usage: this addAction ["Recruit AI", SBX_fnc_recruitAI, ["B_Soldier_F", "B_medic_F"]];
*/

params ["_target", "_caller", "_id", "_arguments"];

private _unitsToSpawn = [];
if (!isNil "_arguments") then {
    _unitsToSpawn = _arguments;
};

if (count _unitsToSpawn == 0) then {
    private _sideID = [east, west, resistance, civilian] find (side _caller);
	private _dataHashMap = [_sideID, "Man"] call SBX_fnc_randomUnitsArray;

    private _allClassnames = [];
    {
        _allClassnames append _y;
    } forEach _dataHashMap;

    if (count _allClassnames > 0) then {
        _unitsToSpawn = [selectRandom _allClassnames];
    };
};

private _spawnPos = _target modelToWorld [0, 10, 0];
_spawnPos set [2, 0];

private _group = group _caller;

{
    private _className = _x;
    
    private _unit = nil;
	if (!(_x isKindOf "Man")) then {
		_unit = createVehicle [_className, _spawnPos, [], 10, "NONE"];
	} else {
		_unit = _group createUnit [_className, _spawnPos, [], 10, "NONE"];
		_unit setSkill 1;
		private _allSkills = "true" configClasses (configFile >> "CfgAISkill");
		{
			_unit setSkill [configName _x, 1];
		} forEach _allSkills;
	};

    _unit setDir (random 360);
        
} forEach _unitsToSpawn;