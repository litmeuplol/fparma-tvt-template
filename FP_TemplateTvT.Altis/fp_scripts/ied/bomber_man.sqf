// by SSG Cuel 2012
//Place a unit (civilian/opfor) that you want to be a suicide bomber, give him a name.
//trigger activation: getposATL (thislist select 0) select 2 < 10
// on act: 0 =[unitName] execVM "fp_scripts\ied\bomber_man.sqf";
//will search for a nearby player in a 250m radius. if no player within 400m, it deletes the unit.
if (!isServer) exitWith {};

_unit  = _this select 0;
if (isNil "_unit") exitWith {hint "Invalid unit for suicide bomber."};
_bombtype = "M_Mo_82mm_AT_LG";
_bombfaction = faction _unit;

_unit setCaptive true;
_unit setBehaviour "CARELESS";
_unit setCombatMode "BLUE";
_unit setSpeedMode "LIMITED";
_unit disableAI "TARGET";
_unit disableAI "AUTOTARGET";
_unit enableAI "MOVE";
_unit setUnitPos "UP";
_unit setVariable ["KRON_exclude",true];
_unit removeAllEventHandlers "Killed";

_expl1 = "DemoCharge_Remote_Ammo" createVehicle [0,0,0];
_expl2 = "DemoCharge_Remote_Ammo" createVehicle  [0,0,0];
_expl3 = "DemoCharge_Remote_Ammo" createVehicle  [0,0,0];
sleep 0.01;
_expl1 attachTo [_unit, [-0.1,0.1,0.15],"Pelvis"];
_expl2 attachTo [_unit, [0,0.15,0.15],"Pelvis"];
_expl3 attachTo [_unit, [0.1,0.1,0.15],"Pelvis"];

[[[_expl1,_expl2,_expl3], {
	_expl1 = _this select 0;
	_expl2 = _this select 1;
	_expl3 = _this select 2;
	_expl1 setVectorDirAndUp [[0.5,0.5,0],[-0.5,0.5,0]];
	_expl1 setPosATL (getPosATL _expl1);
	_expl2 setVectorDirAndUp [[1,0,0],[0,1,0]];
	_expl2 setPosATL (getPosATL _expl2);
	_expl3 setVectorDirAndUp [[0.5,-0.5,0],[0.5,0.5,0]]; 
	_expl3 setPosATL (getPosATL _expl3);
}],"BIS_fnc_spawn", true] call BIS_fnc_MP;




[_unit,_expl1,_expl2,_expl3] spawn {
	waitUntil {sleep .5;!alive (_this select 0)};
	{deleteVehicle _x}foreach [_this select 1,_this select 2, _this select 3];
};

//function to see if the unit is still capable of doing anything
_canAct = {
	if (damage _unit < 0.5) exitWith {true};
	false
};

//function to find the nearest target
_findNearest = 
{
	_targets = call CBA_fnc_players;
	_dist= 250;
	_nearest = objNull;
		{
			if (isTouchingGround _x) then {
				if ((faction _x) != _bombfaction) then {
					_distance=_unit distance (vehicle _x);
					if (_distance<_dist) then {
						_nearest=_x;
						_dist=_distance;
					};
				 };
			};
			sleep 0.01;
		} forEach _targets;
	_nearest
};

//loop
_exit = false;
while {_unit call _canAct && !_exit} do {
	_ret = call _findNearest;
	if (!isNull _ret) then 
	{
		_unit reveal [_ret,4];
		_unit lookAt _ret;
		_sp = "LIMITED";
		if (_unit distance _ret < 20) then {_sp = "FULL"};
		_unit doMove (getposatl _ret);
		_unit setSpeedMode _sp;
	}
	else
	{
		sleep 8;
	};
	sleep 0.5;
	if ([getPosATL _unit,7] call CBA_fnc_nearPlayer) then 
	{
		if (_unit call _canAct) then {
			[[_unit], "fp_akbar"] call CBA_fnc_globalSay;
			sleep 0.5;
			doStop _unit;
			_unit playmove "AmovPercMstpSsurWnonDnon";
			sleep 1;
		};
		if (_unit call _canAct) then 
		{
			_b = _bombtype createVehicle [getposatl _unit select 0,getposatl _unit select 1,(getposatl _unit select 2)+1];
			_b setVelocity [0, 0, -5];
		} else {_exit = true};
	}
	else
	{
		if !([getPosATL _unit,400] call CBA_fnc_nearPlayer) exitWith {_unit setDamage 1;  deleteVehicle _unit;};
	};
	sleep 2;
};

if (alive _unit) then {
	doStop _unit;
	_unit lookAt objNull;
	_unit setUnitPos "DOWN";
}else{
	sleep 60;
	hideBody _unit;
	sleep 5;
	deletevehicle _unit;
};

if (true) exitWith {};