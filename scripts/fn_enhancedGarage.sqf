// usage : this addaction ["Virtual Garage", {[("garage_marker"), _this select 1] call "scripts/fn_enhancedGarage.sqf";}];

// UI Picture = getText (configFile >> "CfgVehicles" >> typeOf vehicle player >> "Components" >> "TransportPylonsComponent" >> "uiPicture")

params ["_markerName", "_caller"];

disableSerialization;

// === UI SIZE CONSTANTS ===
#define SBX_PANEL_W 0.35
#define SBX_PANEL_H 0.45
#define SBX_MARGIN 0.01
#define SBX_COMBO_H 0.025
#define SBX_TURRET_BTN_SIZE 0.022
#define SBX_HEADER_H 0.03

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
        
        // === UI SIZE CALCULATIONS ===
        private _panelW = SBX_PANEL_W * safezoneW;
        private _panelH = SBX_PANEL_H * safezoneH;
        private _margin = SBX_MARGIN * safezoneW;
        private _comboH = SBX_COMBO_H * safezoneH;
        private _turretBtnSize = SBX_TURRET_BTN_SIZE * safezoneH;
        private _headerH = SBX_HEADER_H * safezoneH;
        
        // 1. Container - positioned at right side with proper spacing
        private _ctrlGroup = _display ctrlCreate ["RscControlsGroupNoScrollbars", -1];
        _ctrlGroup ctrlSetPosition [
            safeZoneX + safeZoneW - _panelW - _margin * 2, 
            safeZoneY + (safeZoneH - _panelH) / 2 + (safeZoneH * 0.10), 
            _panelW, 
            _panelH
        ];
        _ctrlGroup ctrlCommit 0;

        // 2. Background with semi-transparent dark color
        private _groupBG = _display ctrlCreate ["RscText", -1, _ctrlGroup];
        _groupBG ctrlSetPosition [0, 0, _panelW, _panelH];
        _groupBG ctrlSetBackgroundColor [0.1, 0.1, 0.1, 0.85];
        _groupBG ctrlCommit 0;

        // 3. Header background
        private _headerBG = _display ctrlCreate ["RscText", -1, _ctrlGroup];
        _headerBG ctrlSetPosition [0, 0, _panelW, _headerH];
        _headerBG ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
        _headerBG ctrlCommit 0;

        // 4. Header title
        private _headerTitle = _display ctrlCreate ["RscText", -1, _ctrlGroup];
        _headerTitle ctrlSetPosition [_margin, 0, _panelW * 0.4, _headerH];
        _headerTitle ctrlSetText "PYLONS SETTINGS";
        _headerTitle ctrlSetTextColor [1, 1, 1, 1];
        _headerTitle ctrlCommit 0;

        // 5. Vehicle UI Picture - sized to fit within panel
        private _picAreaY = _headerH + _margin;
        private _picAreaH = _panelH - _headerH - _margin * 2;
        private _ctrlPic = _display ctrlCreate ["RscPictureKeepAspect", -1, _ctrlGroup];
        _ctrlPic ctrlSetPosition [0, _picAreaY, _panelW, _picAreaH];
        _ctrlPic ctrlSetTextColor [0, 0, 0, 1];
        _ctrlPic ctrlCommit 0;

        private _lastClass = "";
        private _activeControls = [];
        private _pylonTurretOwners = []; // Store turret ownership: [] = driver, [0] = gunner

        while {!isNull _display} do {
            _currentVeh = missionNamespace getVariable ["BIS_fnc_arsenal_center", objNull];

            if (!isNull _currentVeh && {typeOf _currentVeh != _lastClass}) then {
                _lastClass = typeOf _currentVeh;
                
                // Clear previous controls
                { ctrlDelete _x } forEach _activeControls;
                _activeControls = [];
                _pylonTurretOwners = [];

                _cfgPylons = configFile >> "CfgVehicles" >> _lastClass >> "Components" >> "TransportPylonsComponent";
                
                if (isClass _cfgPylons) then {
                    _ctrlPic ctrlSetText getText (_cfgPylons >> "uiPicture");
                    
                    // --- PYLON COMBOBOXES GENERATION ---
                    private _pylonPaths = "true" configClasses (_cfgPylons >> "Pylons");
                    private _pylonComboBoxes = [];
                    private _hasTurrets = count (allTurrets [_currentVeh, false]) > 0;
                    
                    {
                        private _pylonName = configName _x;
                        private _compatibleMags = _currentVeh getCompatiblePylonMagazines _pylonName;
                        private _pos = getArray (_x >> "UIposition");
                        private _defaultTurret = getArray (_x >> "turret");
                        
                        // Initialize turret owner from config default
                        _pylonTurretOwners pushBack _defaultTurret;
                        
                        // Store initial turret owner on vehicle
                        _currentVeh setVariable [format ["SBX_pylonTurret_%1", _forEachIndex + 1], _defaultTurret];
                        
                        // Calculate position relative to panel
                        // UIposition values are normalized: X is 0 to ~0.87, Y is 0 to ~0.614
                        private _relX = if ((_pos select 0) isEqualType "") then { call compile (_pos select 0) } else { _pos select 0 };
                        private _relY = if ((_pos select 1) isEqualType "") then { call compile (_pos select 1) } else { _pos select 1 };
                        
                        // Scale positions to match uiPicture area
                        private _comboW = _panelW * 0.18;
                        private _comboX = (_relX / 0.87) * _panelW + (_panelW * 0.05);
                        private _comboY = _picAreaY + (_relY / 0.614) * _picAreaH * 0.93;
                        
                        // === TURRET OWNER BUTTON (left of combo) ===
                        if (_hasTurrets) then {
                            private _turretBtn = _display ctrlCreate ["RscActivePicture", -1, _ctrlGroup];
                            _activeControls pushBack _turretBtn;
                            
                            _turretBtn ctrlSetPosition [
                                _comboX - _turretBtnSize - _margin * 0.5,
                                _comboY,
                                _turretBtnSize,
                                _comboH
                            ];
                            
                            // Set initial icon based on default turret
                            if (count _defaultTurret == 0) then {
                                _turretBtn ctrlSetText "a3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\role_driver_ca.paa";
                                _turretBtn ctrlSetTooltip "Driver controls this pylon - Click to change";
                            } else {
                                _turretBtn ctrlSetText "a3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\role_gunner_ca.paa";
                                _turretBtn ctrlSetTooltip "Gunner controls this pylon - Click to change";
                            };
                            _turretBtn ctrlCommit 0;
                            
                            _turretBtn setVariable ["pylonIndex", _forEachIndex + 1];
                            _turretBtn setVariable ["parentDisplay", _display];
                            _turretBtn setVariable ["ctrlGroup", _ctrlGroup];
                            
                            _turretBtn ctrlAddEventHandler ["ButtonClick", {
                                params ["_ctrl"];
                                private _pylonIdx = _ctrl getVariable "pylonIndex";
                                private _veh = missionNamespace getVariable ["BIS_fnc_arsenal_center", objNull];
                                private _display = _ctrl getVariable "parentDisplay";
                                private _ctrlGroup = _ctrl getVariable "ctrlGroup";
                                private _pylonTurretOwners = _ctrlGroup getVariable ["SBX_pylonTurretOwners", []];
                                
                                if (isNull _veh) exitWith {};
                                
                                // Toggle turret owner
                                private _currentOwner = _pylonTurretOwners select (_pylonIdx - 1);
                                private _newOwner = if (count _currentOwner == 0) then { [0] } else { [] };
                                
                                _pylonTurretOwners set [_pylonIdx - 1, _newOwner];
                                _ctrlGroup setVariable ["SBX_pylonTurretOwners", _pylonTurretOwners];
                                
                                // Store turret owner on vehicle for later retrieval
                                _veh setVariable [format ["SBX_pylonTurret_%1", _pylonIdx], _newOwner];
                                
                                // Update icon
                                if (count _newOwner == 0) then {
                                    _ctrl ctrlSetText "a3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\role_driver_ca.paa";
                                    _ctrl ctrlSetTooltip "Driver controls this pylon - Click to change";
                                } else {
                                    _ctrl ctrlSetText "a3\ui_f\data\IGUI\RscIngameUI\RscUnitInfo\role_gunner_ca.paa";
                                    _ctrl ctrlSetTooltip "Gunner controls this pylon - Click to change";
                                };
                                
                                // Re-apply pylon loadout with new owner
                                private _pylonCombos = _display getVariable ["SBX_activePylonCombos", []];
                                if (count _pylonCombos >= _pylonIdx) then {
                                    private _combo = _pylonCombos select (_pylonIdx - 1);
                                    private _mag = _combo lbData (lbCurSel _combo);
                                    _veh setPylonLoadout [_pylonIdx, _mag, true, _newOwner];
                                };
                            }];
                        };
                        
                        // === WEAPON COMBOBOX ===
                        private _combo = _display ctrlCreate ["RscCombo", -1, _ctrlGroup];
                        _activeControls pushBack _combo;
                        
                        _combo ctrlSetPosition [_comboX, _comboY, _comboW, _comboH];
                        _combo ctrlSetBackgroundColor [0, 0, 0, 0.7];
                        _combo ctrlSetTooltip _pylonName;
                        _combo ctrlCommit 0;

                        _combo lbAdd "Empty";
                        _combo lbSetData [0, ""];
                        
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
                        } else {
                            _combo lbSetCurSel 0;
                        };

                        // Change event
                        _combo setVariable ["pylonIndex", _pylonIdx];
                        _combo setVariable ["ctrlGroup", _ctrlGroup];
                        _combo ctrlAddEventHandler ["LBSelChanged", {
                            params ["_ctrl", "_index"];
                            private _mag = _ctrl lbData _index;
                            private _pylonIdx = _ctrl getVariable "pylonIndex";
                            private _ctrlGroup = _ctrl getVariable "ctrlGroup";
                            private _veh = missionNamespace getVariable ["BIS_fnc_arsenal_center", objNull];
                            private _pylonTurretOwners = _ctrlGroup getVariable ["SBX_pylonTurretOwners", []];
                            
                            if (!isNull _veh) then {
                                private _turretOwner = if (count _pylonTurretOwners >= _pylonIdx) then {
                                    _pylonTurretOwners select (_pylonIdx - 1)
                                } else { [] };
                                
                                if (_mag != "") then {
                                    _veh setPylonLoadout [_pylonIdx, _mag, true, _turretOwner];
                                } else {
                                    _veh setPylonLoadout [_pylonIdx, "", false, _turretOwner];
                                };
                            };
                        }];
                        
                        _pylonComboBoxes pushBack _combo;

                    } forEach _pylonPaths;
                    
                    // Store turret owners in group
                    _ctrlGroup setVariable ["SBX_pylonTurretOwners", _pylonTurretOwners];
                    _display setVariable ["SBX_activePylonCombos", _pylonComboBoxes];
                    
                    // === PRESET COMBOBOX ===
                    private _presetsConfig = _cfgPylons >> "Presets";
                    if (isClass _presetsConfig) then {
                        private _presetCombo = _display ctrlCreate ["RscCombo", -1, _ctrlGroup];
                        _activeControls pushBack _presetCombo;
                        
                        // Position at top right of panel header area
                        _presetCombo ctrlSetPosition [
                            _panelW - _panelW * 0.35 - _margin,
                            (_headerH - _comboH) / 2,
                            _panelW * 0.35,
                            _comboH
                        ];
                        _presetCombo ctrlSetBackgroundColor [0.15, 0.15, 0.15, 0.9];
                        _presetCombo ctrlSetTooltip "Select preset loadout";
                        _presetCombo ctrlCommit 0;
                        
                        // Add "Custom" option
                        private _customIdx = _presetCombo lbAdd "Custom";
                        _presetCombo lbSetData [_customIdx, ""];
                        _presetCombo lbSetCurSel _customIdx;
                        
                        // Add all presets
                        private _presetClasses = "true" configClasses _presetsConfig;
                        {
                            private _presetName = configName _x;
                            private _displayName = getText (_x >> "displayName");
                            if (_displayName == "") then { _displayName = _presetName; };
                            
                            private _idx = _presetCombo lbAdd _displayName;
                            _presetCombo lbSetData [_idx, _presetName];
                        } forEach _presetClasses;
                        
                        _presetCombo setVariable ["ctrlGroup", _ctrlGroup];
                        _presetCombo ctrlAddEventHandler ["LBSelChanged", {
                            params ["_ctrl", "_index"];
                            private _display = ctrlParent _ctrl;
                            private _ctrlGroup = _ctrl getVariable "ctrlGroup";
                            private _pylonComboBoxes = _display getVariable ["SBX_activePylonCombos", []];
                            private _pylonTurretOwners = _ctrlGroup getVariable ["SBX_pylonTurretOwners", []];
                            private _presetName = _ctrl lbData _index;
                            private _veh = missionNamespace getVariable ["BIS_fnc_arsenal_center", objNull];
                            
                            if (_presetName != "" && !isNull _veh) then {
                                private _vehClass = typeOf _veh;
                                private _presetCfg = configFile >> "CfgVehicles" >> _vehClass >> "Components" >> "TransportPylonsComponent" >> "Presets" >> _presetName;
                                private _attachment = getArray (_presetCfg >> "attachment");
                                
                                {
                                    private _combo = _x;
                                    private _turretOwner = if (count _pylonTurretOwners > _forEachIndex) then {
                                        _pylonTurretOwners select _forEachIndex
                                    } else { [] };
                                    
                                    if (count _attachment > _forEachIndex) then {
                                        private _magToApply = _attachment select _forEachIndex;

                                        if (_magToApply == "") then {
                                            _veh setPylonLoadout [_forEachIndex + 1, "", false, _turretOwner];
                                            _combo lbSetCurSel 0;
                                        } else {
                                            _veh setPylonLoadout [_forEachIndex + 1, _magToApply, true, _turretOwner];
                                            
                                            for "_i" from 0 to ((lbSize _combo) - 1) do {
                                                if (_combo lbData _i == _magToApply) exitWith {
                                                    _combo lbSetCurSel _i;
                                                };
                                            };
                                        };
                                    } else {
                                        _veh setPylonLoadout [_forEachIndex + 1, "", false, _turretOwner];
                                        _combo lbSetCurSel 0;
                                    };
                                    
                                } forEach _pylonComboBoxes;
                            };
                        }];
                    };
                } else {
                    _ctrlPic ctrlSetText "";
                    // Update header for non-pylon vehicles
                    _headerTitle ctrlSetText "NO PYLONS AVAILABLE";
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
    
    // Get pylon turret owners from the vehicle (they were applied during garage use)
    private _pylonTurretData = [];
    {
        private _pylonName = _x;
        private _turretOwner = _veh getVariable [format ["SBX_pylonTurret_%1", _forEachIndex + 1], []];
        _pylonTurretData pushBack _turretOwner;
    } forEach _pylonPaths;

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
    
    // Apply pylons with their turret owners
    {
        private _turretOwner = if (count _pylonTurretData > _forEachIndex) then { _pylonTurretData select _forEachIndex } else { [] };
        _new_veh setPylonLoadout [_pylonPaths select _forEachIndex, _x, true, _turretOwner];
    } forEach _pylons;

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