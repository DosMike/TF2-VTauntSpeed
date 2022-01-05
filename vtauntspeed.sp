/**
 * DESCRIPTION:
 * Small plugin allowing players to change the speed of their vehicle taunts.
 * The command is /gofast [multiplier] (will show a menu if no value was specified).
 * The taunt has to be re-started for the selected multiplier to take effect.
 * Currently this plugin might not work with loadout taunts, but it's a start...
 *
 * Copyright (c) 2022 github.com/DosMike
 * MIT Licensed - https://opensource.org/licenses/MIT
 */

#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2items>
#include <tf2utils>

#define PLUGIN_VERSION "22w01a"
#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo = {
	name = "[TF2] VTauntMod",
	author = "reBane",
	description = "Change speed for vehicle taunts",
	version = PLUGIN_VERSION,
	url = "N/A"
}

static float vspeeds[MAXPLAYERS+1] = {1.0,...};
static bool inVehicle[MAXPLAYERS+1];
static const int vehicles[] = {
	1172, // Taunt: The Victory Lap
	1196, // Taunt: Panzer Pants
	1197, // Taunt: The Scooty Scoot
	30672, // Taunt: Zoomin' Broom
	30845, // Taunt: The Jumping Jack
	30919, // Taunt: The Skating Scorcher
	31155, // Taunt: Rocket Jockey
	31156, // Taunt: The Boston Boarder
	31160, // Taunt: Texas Truckin
	31203, // Taunt: The Mannbulance!
	31239, // Taunt: The Hot Wheeler
};

public void OnPluginStart() {
	RegConsoleCmd("sm_gofast", cmd_vspeed, "Set your vehicle taunt speed");
	HookEvent("post_inventory_application", OnClientInventoryRegeneratePost);
}

public void OnClientConnected(int client) {
	vspeeds[client] = 1.0;
	inVehicle[client] = false;
}

public void OnClientInventoryRegeneratePost(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid", 0));
	updateLoadout(client);
}

public Action cmd_vspeed(int client, int args) {
	int argc = GetCmdArgs();
	char buffer[32];
	if (argc == 0) {
		ShowVSpeedMenu(client);
	} else if (argc == 1) {
		float value;
		GetCmdArg(1, buffer, sizeof(buffer));
		int parsed = StringToFloatEx(buffer, value);
		if (parsed != strlen(buffer) || 0.25 > value > 3.0) {
			ReplyToCommand(client, "Invalid number, please specify a numberbetween 0.25 and 3.0");
		} else {
			SetVehicleTauntSpeed(client, value);
		}
	} else {
		GetCmdArg(0, buffer, sizeof(buffer));
		ReplyToCommand(client, "Usage: %s <speed> - Set your vehicle taunt speed", buffer);
	}
	return Plugin_Handled;
}

void ShowVSpeedMenu(int client) {
	Menu menu = new Menu(HandleVSpeedMenu);
	menu.SetTitle("Set Speed for your\nvehicle taunt");
	menu.AddItem("1", "0.25x");
	menu.AddItem("2", "0.5x");
	menu.AddItem("3", "0.75x");
	menu.AddItem("4", "1.0x");
	menu.AddItem("5", "1.5x");
	menu.AddItem("6", "2.0x");
	menu.AddItem("7", "3.0x");
	menu.Display(client, 30);
}

public int HandleVSpeedMenu(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_End) {
		delete menu;
	} else if (action == MenuAction_Select) {
		char buffer[4];
		menu.GetItem(param2, buffer, sizeof(buffer));
		int value = buffer[0]-'0';
		float speed;
		switch (value) {
			case 1: speed = 0.25;
			case 2: speed = 0.5;
			case 3: speed = 0.75;
			case 4: speed = 1.0;
			case 5: speed = 1.5;
			case 6: speed = 2.0;
			case 7: speed = 3.0;
			default: SetFailState("Error parsing menu selection");
		}
		SetVehicleTauntSpeed(param1, speed);
	}
}

static void SetVehicleTauntSpeed(int client, float multiplier) {
	if (multiplier < 0.25) multiplier = 0.25;
	else if (multiplier > 3.0) multiplier = 3.0;
	vspeeds[client] = multiplier;
	updateLoadout(client);
	if (inVehicle[client]) {
		PrintToChat(client, "[SM] Re-use the taunt to apply the speed multiplier of %.0f%%", vspeeds[client]*100.0);
	} else {
		PrintToChat(client, "[SM] Your taunt speed multiplier is now %.0f%%", vspeeds[client]*100.0);
	}
}

public int TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex) {
	modifyItem(client, itemDefinitionIndex, entityIndex);
}

static void updateLoadout(int client) {
	//don't know if this is neccessary
	for (int slot=0;slot<=18;slot++) {
		int item = TF2Util_GetPlayerLoadoutEntity(client, slot, false);
		if (item != INVALID_ENT_REFERENCE)
			modifyItem(client, GetEntItemDefinition(item), item);
	}
}

static void modifyItem(int client, int itemDefinitionIndex, int entity) {
	if (inArray(vehicles, sizeof(vehicles), itemDefinitionIndex)) {
		int attributes[16];
		float values[16];
		int attributeCount = TF2Attrib_GetStaticAttribs(itemDefinitionIndex, attributes, values);
		for (int i; i < attributeCount; i++) {
			if (attributes[i] == 689) { // taunt move speed
				TF2Attrib_SetByName(entity, "taunt move speed", values[i] * vspeeds[client]);
			}
		}
	}
}

public void TF2_OnConditionAdded(int client, TFCond condition) {
	if (condition == TFCond_Taunting && inArray(vehicles, sizeof(vehicles), GetEntItemDefinition(client))) {
		inVehicle[client] = true;
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition) {
	if (condition == TFCond_Taunting && inVehicle[client]) {
		inVehicle[client] = false;
	}
}

static int GetEntItemDefinition(int entity) {
	if (HasEntProp(entity, Prop_Send, "m_iTauntItemDefIndex"))
		return GetEntProp(entity, Prop_Send, "m_iTauntItemDefIndex");
	else
		return -1;
}
static bool inArray(const any[] haystack, int hslength, any needle) {
	for (int i; i<hslength; i++) if (haystack[i]==needle) return true;
	return false;
}
