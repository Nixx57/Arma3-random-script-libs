// usage : this addaction ["Virtual Garage", {[("garage_marker")] call "scripts/fn_enhancedGarage.sqf";}];

// UI Picture = getText (configFile >> "CfgVehicles" >> typeOf vehicle player >> "Components" >> "TransportPylonsComponent" >> "uiPicture")

params ["_markerName", "_caller"];

disableSerialization;

uiNamespace setVariable [ "current_garage", ( _this select 0 ) ];

_fullVersion = missionNamespace getVariable [ "BIS_fnc_arsenal_fullGarage", false ];

if !( isNull ( uiNamespace getVariable [ "BIS_fnc_arsenal_cam", objNull ] ) ) exitwith { "Garage Viewer is already running" call bis_fnc_logFormat; };

{ 
    if (!(_x isKindOf "Man")) then
    {
        { 
            moveOut _x;
            unassignVehicle _x;
            deleteVehicle _x;
        } forEach crew _x;
    };
} forEach nearestObjects [ getMarkerPos ( _this select 0 ), [ "AllVehicles" ], 10 ];

_playerCurrentVehicle = _caller getVariable [ "current_vehicle", objNull ];
if !isNull _playerCurrentVehicle then {
    {
        moveOut _x;
        unassignVehicle _x;
        deleteVehicle _x;
    } forEach crew _playerCurrentVehicle;
    deleteVehicle _playerCurrentVehicle;
    _caller setVariable [ "current_vehicle", objNull, true ];
};

_veh = createVehicle [ "Land_HelipadEmpty_F", getMarkerPos ( _this select 0 ), [], 0, "NONE" ];
uiNamespace setVariable [ "garage_pad", _veh ];
missionNamespace setVariable [ "BIS_fnc_arsenal_fullGarage", [ true, 0, false, [ false ] ] call bis_fnc_param ];

with missionNamespace do { BIS_fnc_garage_center = [ true, 1, _veh, [ objNull ] ] call bis_fnc_param; };

with uiNamespace do {  
	_displayMission = [] call ( uiNamespace getVariable "bis_fnc_displayMission" );
	if !( isNull findDisplay 312 ) then { _displayMission = findDisplay 312; };
	_garageDisplay = _displayMission createDisplay "RscDisplayGarage";
	uiNamespace setVariable [ "running_garage", true ];

    ///////////////////////////
    [_garageDisplay] spawn {
        disableSerialization;
        params ["_display"];
        
        // 1. Container
        private _groupW = 0.8;
        private _groupH = 0.5;
        private _ctrlGroup = _display ctrlCreate ["RscControlsGroupNoScrollbars", -1];
        _ctrlGroup ctrlSetPosition [safeZoneX + safeZoneW - _groupW - 0.05, safeZoneY + (safeZoneH / 2) - (_groupH / 2), _groupW, _groupH];
        _ctrlGroup ctrlCommit 0;

        // 2. Background of the group (to make it visible)
        private _groupBG = _display ctrlCreate ["RscText", -1, _ctrlGroup];
        _groupBG ctrlSetPosition [0, 0, _groupW, _groupH];
        _groupBG ctrlSetBackgroundColor [0.25, 0.25, 0.25, 1]; // Semi-transparent black
        _groupBG ctrlCommit 0;

        // 1. Définition des dimensions de l'image
        private _picW = _groupH; 
        private _picH = _groupH;

        // 2. Calcul du centrage
        // X = (0.8 - 0.4) / 2 = 0.2
        // Y = (0.5 - 0.4) / 2 = 0.05
        private _centerX = (_groupW - _picW) / 2;
        private _centerY = (_groupH - _picH) / 2;

        private _ctrlPic = _display ctrlCreate ["RscPictureKeepAspect", -1, _ctrlGroup];
        _ctrlPic ctrlSetPosition [_centerX, _centerY, _picW, _picH];
        _ctrlPic ctrlSetTextColor [0, 0, 0, 1];
        _ctrlPic ctrlCommit 0;

        private _lastClass = "";
        private _activeControls = []; // To store created controls for later deletion

        while {!isNull _display} do {
            _currentVeh = missionNamespace getVariable ["BIS_fnc_arsenal_center", objNull];

            if (!isNull _currentVeh && {typeOf _currentVeh != _lastClass}) then {
                _lastClass = typeOf _currentVeh;
                
                // Clear previous controls
                { ctrlDelete _x } forEach _activeControls;
                _activeControls = [];

                _cfgPylons = configFile >> "CfgVehicles" >> _lastClass >> "Components" >> "TransportPylonsComponent";
                
                if (isClass _cfgPylons) then {
                    _ctrlPic ctrlSetText getText (_cfgPylons >> "uiPicture");
                    
                    // --- GENERATION OF COMBOBOXES ---
                    private _pylonPaths = "true" configClasses (configFile >> "CfgVehicles" >> _lastClass >> "Components" >> "TransportPylonsComponent" >> "Pylons");
                    {
                        private _pylonName = configName _x;
                        private _compatibleMags = _currentVeh getCompatiblePylonMagazines _pylonName;
                        private _pos = getArray (_x >> "UIposition"); // Position relative on the UI [x, y]
                        
                        // Creation of the ComboBox
                        private _combo = _display ctrlCreate ["RscCombo", -1, _ctrlGroup];
                        _activeControls pushBack _combo;
                        
                        _combo ctrlSetPosition [
                            _pos select 0, 
                            _pos select 1, 
                            0.25, 
                            0.035
                        ];
                        _combo ctrlCommit 0;

                        {
                            private _displayName = getText (configFile >> "CfgMagazines" >> _x >> "displayName");
                            private _picture = getText (configFile >> "CfgMagazines" >> _x >> "picture");

                            private _idx = _combo lbAdd _displayName;
                            
                            _combo lbSetData [_idx, _x];
                            
                            _combo lbSetPicture [_idx, _picture];
                        } forEach _compatibleMags;

                        // Change event
                        _combo ctrlAddEventHandler ["LBSelChanged", {
                            params ["_ctrl", "_index"];
                            private _mag = _ctrl lbData _index;
                            private _pylonIdx = _ctrl getVariable "pylonIndex";
                            _veh = missionNamespace getVariable ["BIS_fnc_arsenal_center", objNull];
                            if (_mag != "" && !isNull _veh) then {
                                _veh setPylonLoadout [_pylonIdx, _mag, true];
                            };
                        }];
                        _combo setVariable ["pylonIndex", _forEachIndex + 1];

                    } forEach _pylonPaths;
                } else {
                    _ctrlPic ctrlSetText "";
                };
            };
            sleep 0.2;
        };
    };
    //////////////////////////
    
	waitUntil { sleep 0.25; isNull ( uiNamespace getVariable [ "BIS_fnc_arsenal_cam", objNull ] ) };

	_marker = uiNamespace getVariable "current_garage";
	_pad = uiNamespace getVariable "garage_pad";
	deleteVehicle _pad;

    _veh = missionNamespace getVariable "BIS_fnc_garage_center";
    systemChat format ["Exiting Garage, Spawning Vehicle: %1", typeOf _veh];
    _vehType = typeOf _veh;
    _custom = [_veh] call BIS_fnc_getVehicleCustomization;
    _pylons = getPylonMagazines _veh;
    _crew = crew _veh;

    _pylonPaths = (configProperties [configFile >> "CfgVehicles" >> _vehType >> "Components" >> "TransportPylonsComponent" >> "Pylons", "isClass _x"]) apply {configName _x};
    

    private _savedCrewData = fullCrew [_veh, "", false] apply {[_x select 1, _x select 2, _x select 3]};
    {
        private _unit = _x;
        moveOut _unit;
        unassignVehicle _unit;
        if (!( isPlayer _unit)) then {
            deleteVehicle _unit;
        };
    } forEach _crew;

    deleteVehicle _veh;
    sleep 0.1;
    
    _new_veh = createVehicle [ _vehType, getMarkerPos _marker, [], 0, "NONE" ];
    _new_veh setPosATL [ ( position _new_veh select 0 ), ( position _new_veh select 1 ), 0.25 ];
    _vehDir = markerDir _marker;
    _new_veh setDir _vehDir;

    [_new_veh, _custom select 0, _custom select 1] call BIS_fnc_initVehicle;
    { _new_veh setPylonLoadout [_pylonPaths select _forEachIndex, _x, true]; } forEach _pylons;

    if (!(unitIsUAV _new_veh)) then {  
        _playerGrp = group _caller;
        _defaultCrewClass = getText ( configFile >> "CfgVehicles" >> _vehType >> "crew" );
        {
            _x params ["_role", "_cargoIdx", "_turretPath"];
            _ai = _playerGrp createUnit [_defaultCrewClass, getMarkerPos _marker, [], 50, "NONE"];

            switch (_role) do {
                case "commander": { _ai assignAsCommander _new_veh; _ai moveInCommander _new_veh; };
                case "driver": { _ai assignAsDriver _new_veh; _ai moveInDriver _new_veh; };
                case "gunner": { _ai assignAsGunner _new_veh; _ai moveInGunner _new_veh; };
                case "turret": { _ai assignAsTurret [_new_veh, _turretPath]; _ai moveInTurret [_new_veh, _turretPath]; };
                case "cargo": { _ai assignAsCargoIndex [_new_veh, _cargoIdx]; _ai moveInCargo [_new_veh, _cargoIdx]; };
            };

            _ai setSkill 1;
            { _ai setSkill [configName _x, 1]; } forEach ("true" configClasses (configFile >> "CfgAISkill"));
        } forEach _savedCrewData;
    }
    else {
        createVehicleCrew _new_veh;
    };
    _caller setVariable ["current_vehicle", _new_veh, true ];
};

// "a3\ui_f\data\logos\arma3_white_ca.paa"