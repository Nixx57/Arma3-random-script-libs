private _posOpfor = [] call BIS_fnc_randomPos;
private _mOpfor = createMarker ["opfor_ai", _posOpfor];
_mOpfor setMarkerColor "ColorOPFOR";
_mOpfor setMarkerShape "ELLIPSE";
_mOpfor setMarkerSize [100, 100];
_mOpfor setMarkerAlpha 1;
BIS_SUPP_HQ_EAST setPos _posOpfor;

private _posInd = [] call BIS_fnc_randomPos;
private _mInd = createMarker ["ind_ai", _posInd];
_mInd setMarkerColor "ColorIndependent";
_mInd setMarkerShape "ELLIPSE";
_mInd setMarkerSize [100, 100];
_mInd setMarkerAlpha 1;
BIS_SUPP_HQ_GUER setPos _posInd;


[] spawn SBX_fnc_respawnVeh;
[] spawn SBX_fnc_initAC_Control;
[] call SBX_fnc_loadout;