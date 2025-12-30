/*
    Author: Nixx (for SBX Framework)
    Description: Analyzes an object (vehicle or group) and returns an array of its support capabilities.
    Usage: _hasSupport = [_myobject] call SBX_fnc_hasSupport;
    Returns: Boolean (true if the object has support capabilities, false otherwise)
*/

params ["_obj"];
if (isNull _obj) exitWith {false};

// 1. Get base class (if it's a vehicle, typeOf is enough. If it's a group, we iterate)
private _cfg = configFile >> "CfgVehicles" >> (typeOf _obj);

if ((getNumber (_cfg >> "engineer") > 0) ||
	(getNumber (_cfg >> "attendant") > 0) || 
	(getNumber (_cfg >> "transportAmmo") > 0) || 
	(getNumber (_cfg >> "transportFuel") > 0) || 
	(getNumber (_cfg >> "transportRepair") > 0))  
		exitWith {true};

// --- CREW SPECIFIC CAPABILITIES ---
// If it's a vehicle, check if any crew member has specific skills
if (_obj isKindOf "AllVehicles" && !(_obj isKindOf "Man")) then {
	private _hasSupportCrew = false;
    {
        private _unitCfg = configFile >> "CfgVehicles" >> (typeOf _x);
        if ((getNumber (_unitCfg >> "engineer") > 0) ||
		(getNumber (_unitCfg >> "attendant") > 0) || 
		(getNumber (_unitCfg >> "transportAmmo") > 0) || 
		(getNumber (_unitCfg >> "transportFuel") > 0) || 
		(getNumber (_unitCfg >> "transportRepair") > 0)) 
			exitWith {_hasSupportCrew = true}; 
		
    } forEach (crew _obj);

	if (_hasSupportCrew) exitWith { true };
};

false;