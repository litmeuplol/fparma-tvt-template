//if (!isMultiplayer) exitWith{};

/* === PARAMETERS === */
	/* If players can respawn, at all. true disables spectator */
	FP_playerCanRespawn = false;

	/* If players die, they can not reconnect and respawn  */
	FP_savePlayerDeathsAndPreventRespawn = true;

	/*Seconds before JIP will not be possible anymore */
	FP_timeBeforeJIPNotPossible = 120;

	/* If JIP player should be teleported to the the other units */
	FP_JIPTeleport = true;

/* === END PARAMETERS === */

/* Clients */
if (!isDedicated) then {
	waitUntil {!isNull player && {getPlayerUID player != ""}};
	FP_clientUID = getPlayerUID player;

	player addEventHandler ["Killed", {
		[[_this select 0, _this select 1,FP_clientUID],"FP_jrm_playerDied",false,false] call BIS_fnc_MP;
		if (!FP_playerCanRespawn) then {
			[_this select 0] spawn {
				setPlayerRespawnTime 9999;
				_this spawn F_fnc_CamInit;
			};
			
		};
	}];
	player setVariable ["FP_jrm_isInit",true, true];
};

/* Server */
if (isServer) then {
	FP_jrm_deadPlayers = [];

	FP_jrm_playerDied = {
		_whom = [_this,0, objNull,[objNull]] call BIS_fnc_param;
		if (isNull _whom) exitWith{};
		_killer = [_this,1,objNull,[objNull]] call BIS_fnc_param;
		_uid = [_this,2,"",[""]] call BIS_fnc_param;
		/* Logs who died from what */
		if (!isNull _killer) then {
			diag_log format ["JRM: %1 (%2) was killed by %3 who was using %4 and was %5 meters away",name _whom, _uid, name _killer,getText (configFile >> "cfgWeapons" >> currentWeapon _killer >> "displayName"), _whom distance _killer];
		};

		if (FP_savePlayerDeathsAndPreventRespawn) then {
			/* Saves death */
			if (time > 15 && _uid != "" && {!(_uid in FP_jrm_deadPlayers)}) then  {
				FP_jrm_deadPlayers pushback _uid;
			};	
		};
	};

	/* Handles JIPs connecting. Time is most precise on the server. It also knows where units are more precise*/
	FP_jrm_playerConnected = {
		_uid = [_this,0,"",[""]] call BIS_fnc_param;
		if (_uid == "") exitWith {};
		_timeout = time + 30;
		_unit = objNull;
		while {isNull _unit} do 
		{
			{ // forEach
				if (getPlayerUID _x == _uid) exitWith{
					_unit = _x;
				};
			}foreach ([] call CBA_fnc_players);
			sleep .2;
			if (time > _timeout) exitWith{};
		};
		
		// We have the player object
		if (FP_savePlayerDeathsAndPreventRespawn && {_uid in FP_jrm_deadPlayers || time > FP_timeBeforeJIPNotPossible}) then {
			/* Let player init this script so he has the killed EV */
			waitUntil {isNull _unit || (_unit getVariable ["FP_jrm_isInit",false])};
			// Timeout
			if (isNull _unit) exitWith{};
			_unit setDamage 1;
			sleep 1;
			deleteVehicle _unit;
		}else{
			if (FP_JIPTeleport) then {
				private ["_pos","_found","_goodPos"];
				_goodPos = {
					_pos = if (typename _this == typename objnull) then {_this modelToWorld [0,-2,0]}else{_this};
					_realPos = (getPosATL _unit findEmptyPosition [0,50]);
					if (count _realPos > 0) then {_pos = _realPos};
					_pos set [2,0];
					_pos
				};

				_tppos = [];
				if (leader group _unit == _unit) then {
					_averagex=0;
					_averagey=0;
					_sideUnits = [];

					if (count units group _unit == 1) then {
						// units is alone in group, avg pos on all units of same side
						{
							if (alive _x && {side _x == side _unit} && {_x != _unit}) then {
								_sideUnits pushback _x;
							};
						}forEach ([]call CBA_fnc_players);
					}else{

						// there are units in the group
						{
							if (alive _x && {_x != _unit}) then {
								_sideUnits pushback _x;
							};
						}forEach (units group _unit);
					};

					if (count _sideUnits == 0) exitWith{};
					_divide = count _sideUnits;
					{_averagex=_averagex+(getPosATL vehicle _x select 0);_averagey=_averagey+(getPosATL vehicle _x select 1)} forEach _sideUnits;
					_tppos= [_averagex/_divide,_averagey/_divide,0];
					_tppos = _tppos call _goodPos;

				}else{

					_tppos = (leader group _unit) call _goodPos;
				};
				if (count _tppos > 0 && {_tppos distance [0,0,0] > 10}) then {
					_unit setPosATL _tppos;
				};
			};
		};
	};
	/*Saves players who disconnect while unconscious, counts as death*/
	FP_jrm_playerDisconnected = {
		_uid = [_this,0,"",[""]] call BIS_fnc_param;
		_unit = objNull;
		{
			if (getPlayerUID _x == _uid) exitWith{
				_unit = _x;
			};
		}forEach ([] call CBA_fnc_players);
		if (isNull _unit) exitWith{};
		if (_unit getVariable ["AGM_Unconscious",false]) then {
			if (!_uid in FP_jrm_deadPlayers) then {
				FP_jrm_deadPlayers pushback _uid;
			};
		};
	};

	["FP_jrm_playerConnectedEV","onPlayerConnected",{if (time < 15 || {_name == "__SERVER__"}) exitWith {}; [_uid] spawn FP_jrm_playerConnected}] call BIS_fnc_addStackedEventHandler;
	["FP_jrm_playerDisconnectedEV","onPlayerDisconnected",{if (!FP_savePlayerDeathsAndPreventRespawn) exitWith{}; [_uid] call FP_jrm_playerDisconnected}] call BIS_fnc_addStackedEventHandler;
};