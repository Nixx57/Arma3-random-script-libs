// ------------------3DEN--------------------

// Create hidden object via 3den
create3DENEntity ["Object", "ModuleLogic_F", screenToWorld [0.5, 0.5]];

// set 3den grid to 5m for terrain, 15m for roads, 5m for structures
set3DENGrid ["t", 5];
set3DENGrid ["r", 15];
set3DENGrid ["s", 5];

// ----------------ZEUS CURATOR----------------

// Make all units and vehicles editable by Zeus curators every 10s
[] spawn {
	while { true } do {
		{
			private _toAdd = (allUnits + vehicles) select {
				!(_x in (curatorEditableObjects _x))
			};
			_x addCuratorEditableObjects [_toAdd, true];
		} forEach allCurators;
		sleep 10;
	};
};

// DEBUG