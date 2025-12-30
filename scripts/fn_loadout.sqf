private _unitsToMap = [
	"B_Story_SF_Captain_F", // Miller
	"B_CTRG_soldier_M_medic_F", // James
	"B_CTRG_soldier_engineer_exp_F", // Hardy
	"B_CTRG_soldier_GL_LAT_F", // Northgate
	"B_CTRG_soldier_AR_A_F", // McKay
	"B_CTRG_Sharphooter_F", // O'Connor
	"B_Story_Protagonist_F", // Kerry
	"I_G_resistanceLeader_F", // Stavrou
	"B_G_Story_Guerilla_01_F", // Alexis Kouris
	"B_Captain_Pettka_F", // Pettka
	"B_Captain_Jay_F", // Jay
	"B_G_Captain_Ivan_F", // Ivan
	"B_Captain_Dwarden_F", // Dwarden
	"B_Pilot_F",
	"B_Helipilot_F",
	"B_Fighter_Pilot_F",
	"B_Patrol_HeavyGunner_F",
	"B_Patrol_Soldier_TL_F",
	"B_Patrol_Soldier_AR_F",
	"B_Patrol_Medic_F",
	"B_Patrol_Soldier_MG_F",
	"B_Patrol_Soldier_UAV_F",
	"B_Patrol_Soldier_A_F",
	"B_Patrol_Engineer_F",
	"B_Patrol_Soldier_AT_F",
	"B_Patrol_Soldier_M_F"
];

{
	private _className = _x;
	[west, _className] call BIS_fnc_addRespawnInventory;
} forEach _unitsToMap;