// Returns a HashMap of arrays of unit classnames, categorized by faction.
// Hashmap structure:
// ........Key: Faction name (string : e.g. "BLU_F")
// ........Value: Array of unit classnames (array of strings: e.g. ["B_Soldier_F", "B_medic_F"])
// Usage: 
// _sideID = [east, west, resistance, civilian] find (side _caller);
// _unitData = [_sideID, "Man"(default: "AllVehicles")] call SBX_fnc_randomUnitsArray;

params ["_sideNum", "_kindOf"];
private _data = createHashMap;
private _cfg = configFile >> "CfgVehicles";

private _excludeConditions = "";
if (isNil "_kindOf") then {
    // Only apply exclusions when caller omits _kindOf
    _kindOf = "AllVehicles";
    _excludeConditions = " &&
        !(configName _x isKindOf 'ParachuteBase') &&
        !(configName _x isKindOf 'Ship')";
};

private _filterString = format [
    "(getNumber (_x >> 'scope') == 2) && (getNumber (_x >> 'side') == %1) && (configName _x isKindOf '%2')%3",
    _sideNum,
    _kindOf,
    _excludeConditions
];

private _filtered = _filterString configClasses _cfg;

{
    private _faction = getText (_x >> "faction");
    if !(_faction in _data) then {
        _data set [_faction, []];
    };
    (_data get _faction) pushBack (configName _x);
} forEach _filtered;

_data