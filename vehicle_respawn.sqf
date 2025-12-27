// Respawns all vehicles that are present when the script starts, and makes them respawn with their appearances and weapons

fnc_veh_respawn = {
	params ["_veh", "_pos", "_dir", "_type", "_custom", "_pylons", "_pylonPaths"];

	[_veh, _pos, _dir, _type, _custom, _pylons, _pylonPaths] spawn {
		params ["_veh", "_pos", "_dir", "_type", "_custom", "_pylons", "_pylonPaths"];

		_active = true;
		while { _active } do {
			sleep 5;

			_isDead = !alive _veh;
			_isEmpty = count (crew _veh select {
				alive _x
			}) == 0;
			_isDamaged = (damage _veh > 0);
			_isFar = (_veh distance2D _pos > 100);

			            
			if (_isDead || (_isEmpty && (_isDamaged || _isFar))) then {
				_active = false;

				sleep 60;
				_veh setPosASL [0, 0, 0];
				deleteVehicle _veh;

				sleep 5;

				_newVeh = createVehicle [_type, [0, 0, 0], [], 0, "NONE"];
				_newVeh setDir _dir;
				_newVeh setPosASL _pos;

				{
					_newVeh setPylonLoadout [_pylonPaths select _forEachIndex, _x, true];
				} forEach _pylons;
				
				if (unitIsUAV _newVeh) then {
					createVehicleCrew _newVeh;
				};

				// Uncomment to randomize visuals and weapons (see vehicle_randomization.sqf)
				// _newVeh call fnc_forceRandomizeTextures;
				// _newVeh call fnc_forceRandomizeAnims;
				// _newVeh call fnc_forceRandomizePylons;

				[_newVeh, _pos, _dir, _type, _custom, _pylons, _pylonPaths] call fnc_veh_respawn;
			};
		};
	};
};

// Initial scan 
{
	if (_x isKindOf "AllVehicles" && !(_x isKindOf "Man")) then {
		_type = typeOf _x;
		_pylonPaths = (configProperties [configFile >> "CfgVehicles" >> _type >> "Components" >> "TransportPylonsComponent" >> "Pylons", "isClass _x"]) apply {
			configName _x
		};

		[_x, getPosASL _x, getDir _x, _type, [_x] call BIS_fnc_getVehicleCustomization, getPylonMagazines _x, _pylonPaths] call fnc_veh_respawn;
	};
} forEach vehicles;
