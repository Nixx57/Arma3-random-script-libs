// This file is a compilation of various random snippets and experiments in SQF, used in the mission.sqm

// Use the MARTAManager (Military symbole), code placed in module's init;
setGroupIconsVisible [true, false]; // Show the icons on map, hide on HUD (bool map, bool hud)
(group BIS_SUPP_HQ_WEST) setVariable ["MARTA_customIcon", ["b_hq"]]; // Set a custom icon for the group ("MARTA_customIcon", [array of icon names])
(group BIS_SUPP_HQ_GUER) setVariable ["MARTA_customIcon", ["n_hq"]];
(group BIS_SUPP_HQ_EAST) setVariable ["MARTA_customIcon", ["o_hq"]];
(group BIS_SUPP_HQ_CIV) setVariable ["MARTA_customIcon", ["c_unknown"]];

(group SUPP_W_REPAIR_T) setVariable ["MARTA_customIcon", ["b_maint"]];
(group SUPP_W_FUEL_T) setVariable ["MARTA_customIcon", ["b_support"]];
(group SUPP_W_MEDIC_T) setVariable ["MARTA_customIcon", ["b_med"]];
(group SUPP_W_AMMO_T) setVariable ["MARTA_customIcon", ["b_support"]];
(group SUPP_W_MEDIC) setVariable ["MARTA_customIcon", ["b_med"]];
(group SUPP_W_REPAIR) setVariable ["MARTA_customIcon", ["b_maint"]];
// ------------------------------------------------------------------------


// Spawning unit on a placed marker
this addAction ["Spawn " + getText (configFile >> "CfgVehicles" >> "B_UGV_01_rcws_F" /*ClassName of the vehicle*/ >> "displayName"), { 
 params["_target", "_caller"]; 
 _spawnPos = markerPos "ugv_stomper_pos";  // Marker name where to spawn
 _veh = createVehicle ["B_UGV_01_rcws_F", _spawnPos, [], 0, "NONE"]; 
 createVehicleCrew _veh; 
 { 
  _x setSkill 1; // Maybe useless
 } forEach crew _veh; 
 [_veh] call fnc_forceRandomizeTextures; // See fnc_forceRandomizeTextures in fn_initAC.sqf
 [_veh] call fnc_forceRandomizeAnims; 
 [_veh] call fnc_forceRandomizePylons; 
}, [], 1.5, true, true, "", "true", 5];
// ------------------------------------------------------------------------

