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

with missionNamespace do { missionNamespace setVariable ["BIS_fnc_garage_center", [ true, 1, _veh, [ objNull ] ] call bis_fnc_param]; };

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
        private _groupW = 1;
        private _groupH = 1;
        private _ctrlGroup = _display ctrlCreate ["RscControlsGroupNoScrollbars", -1];
        _ctrlGroup ctrlSetPosition [safeZoneX + safeZoneW - _groupW - 0.05, safeZoneY + (safeZoneH / 2) - (_groupH / 2), _groupW, _groupH];
        _ctrlGroup ctrlCommit 0;

        // 2. Background of the group (to make it visible)
        private _groupBG = _display ctrlCreate ["RscText", -1, _ctrlGroup];
        _groupBG ctrlSetPosition [0, 0, _groupW, _groupH];
        _groupBG ctrlSetBackgroundColor [0.25, 0.25, 0.25, 1];
        _groupBG ctrlCommit 0;

        private _ctrlPic = _display ctrlCreate ["RscPictureKeepAspect", -1, _ctrlGroup];
        _ctrlPic ctrlSetPosition [0, 0, _groupW, _groupH];
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
                    private _pylonComboBoxes = [];
                    {
                        private _pylonName = configName _x;
                        private _compatibleMags = _currentVeh getCompatiblePylonMagazines _pylonName;
                        private _pos = getArray (_x >> "UIposition"); // Position relative on the UI [x, y]
                        
                        // Creation of the ComboBox
                        private _combo = _display ctrlCreate ["RscCombo", -1, _ctrlGroup];
                        _activeControls pushBack _combo;
                        
                        _combo ctrlSetPosition [
                            (_pos select 0), 
                            (_pos select 1)
                        ];
                        _combo ctrlCommit 0;

                        _combo lbAdd "Empty"; // First empty entry
                        _combo lbSetData [0, ""]; // Data for empty entry
                        {
                            private _displayName = getText (configFile >> "CfgMagazines" >> _x >> "displayName");
                            private _picture = getText (configFile >> "CfgMagazines" >> _x >> "picture");
                            private _description = getText (configFile >> "CfgMagazines" >> _x >> "descriptionShort");

                            private _idx = _combo lbAdd _displayName;
                            
                            _combo lbSetData [_idx, _x];
                            
                            _combo lbSetPicture [_idx, _picture];
                            if (_description != "") then {
                                _combo lbSetTooltip [_idx, _description];
                            };
                        } forEach _compatibleMags;

                        // Set current selection
                        private _pylonIdx = _forEachIndex + 1;
                        private _currentMag = (getPylonMagazines _currentVeh) select (_pylonIdx - 1);

                        private _currentMagIndex = -1;
                        for "_i" from 0 to ((lbSize _combo) - 1) do {
                            if (_combo lbData _i == _currentMag) exitWith {
                                _currentMagIndex = _i;
                            };
                        };

                        if (_currentMagIndex != -1) then {
                            _combo lbSetCurSel _currentMagIndex;
                        };

                        // Change event
                        _combo ctrlAddEventHandler ["LBSelChanged", {
                            params ["_ctrl", "_index"];
                            private _mag = _ctrl lbData _index;
                            private _pylonIdx = _ctrl getVariable "pylonIndex";
                            _veh = missionNamespace getVariable ["BIS_fnc_arsenal_center", objNull];
                            if (_mag != "" && !isNull _veh) then {
                                _veh setPylonLoadout [_pylonIdx, _mag, true];
                            }
                            else {
                                // Si vide, on applique "Empty"
                                _veh setPylonLoadout [_pylonIdx, "", false];
                            };
                        }];
                        _combo setVariable ["pylonIndex", _forEachIndex + 1];
                        _pylonComboBoxes pushBack _combo;

                    } forEach _pylonPaths;
                    _display setVariable ["SBX_activePylonCombos", _pylonComboBoxes];
                    // Generate preset comboBox
                    private _presetsConfig = _cfgPylons >> "Presets";
                    if (isClass _presetsConfig) then {
                        private _presetCombo = _display ctrlCreate ["RscCombo", -1, _ctrlGroup];
                        _activeControls pushBack _presetCombo;
                        
                        // Position at top center of the group
                        _presetCombo ctrlSetPosition [0.01, 0.01];
                        _presetCombo ctrlCommit 0;
                        
                        // Add "Custom" option as default
                        private _customIdx = _presetCombo lbAdd "Custom";
                        _presetCombo lbSetData [_customIdx, ""];
                        _presetCombo lbSetCurSel _customIdx;
                        
                        // Add all available presets
                        private _presetClasses = "true" configClasses _presetsConfig;
                        {
                            private _presetName = configName _x;
                            private _displayName = getText (_x >> "displayName");
                            if (_displayName == "") then { _displayName = _presetName; };
                            
                            private _idx = _presetCombo lbAdd _displayName;
                            _presetCombo lbSetData [_idx, _presetName];
                        } forEach _presetClasses;
                        
                        // Event handler for preset selection
                        _presetCombo ctrlAddEventHandler ["LBSelChanged", {
                            params ["_ctrl", "_index"];
                            private _display = ctrlParent _ctrl; // On récupère le display
                            private _pylonComboBoxes = _display getVariable ["SBX_activePylonCombos", []]; // On récupère l'array !
                            private _presetName = _ctrl lbData _index;
                            private _veh = missionNamespace getVariable ["BIS_fnc_arsenal_center", objNull];
                            
                            if (_presetName != "" && !isNull _veh) then {
                                // Apply the preset
                                private _vehClass = typeOf _veh;
                                private _presetCfg = configFile >> "CfgVehicles" >> _vehClass >> "Components" >> "TransportPylonsComponent" >> "Presets" >> _presetName;
                                private _attachment = getArray (_presetCfg >> "attachment");
                                {
                                    private _combo = _x;
                                    if ( count _attachment > 0) then {
                                        private _magToApply = _attachment select _forEachIndex;

                                        if (_magToApply == "") exitWith {
                                            // Si vide, on applique "Empty"
                                            _magToApply = "";
                                            _veh setPylonLoadout [_forEachIndex + 1, "", false];
                                        };
                                        // 1. Appliquer au véhicule
                                        _veh setPylonLoadout [_forEachIndex + 1, _magToApply, true];
                                        
                                        // 2. Mettre à jour visuellement la Combo correspondante
                                        for "_i" from 0 to ((lbSize _combo) - 1) do {
                                            if (_combo lbData _i == _magToApply) exitWith {
                                                _combo lbSetCurSel _i;
                                            };
                                        };
                                    }
                                    else {
                                        // No attachment for this pylon in the preset, set to empty
                                        _veh setPylonLoadout [_forEachIndex + 1, "", false];
                                        
                                        // Update ComboBox selection to "Empty"
                                        _combo lbSetCurSel 0;
                                    };
                                    
                                } forEach _pylonComboBoxes;
                            };
                        }];
                    };
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