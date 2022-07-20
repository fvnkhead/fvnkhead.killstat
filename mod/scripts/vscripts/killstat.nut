global function killstat_Init

struct Parameter {
    string name
    string value
}

array<string> HEADERS = [
    "killstat_version",
    "match_id",
    "game_mode",
    "map",
    "unix_time",
    "game_time",
    "player_count",
    "attacker_name",
    "attacker_id",
    "attacker_current_weapon",
    "attacker_current_weapon_mods",
    "attacker_weapon_1",
    "attacker_weapon_1_mods",
    "attacker_weapon_2",
    "attacker_weapon_2_mods",
    "attacker_weapon_3",
    "attacker_weapon_3_mods",
    "attacker_offhand_weapon_1",
    "attacker_offhand_weapon_2",
    "attacker_offhand_weapon_3",
    "victim_name",
    "victim_id",
    "victim_current_weapon",
    "victim_current_weapon_mods",
    "victim_weapon_1",
    "victim_weapon_1_mods",
    "victim_weapon_2",
    "victim_weapon_2_mods",
    "victim_weapon_3",
    "victim_weapon_3_mods",
    "victim_offhand_weapon_1",
    "victim_offhand_weapon_2",
    "victim_offhand_weapon_3",
    "cause_of_death",
    "distance"
]

array<string> WEAPON_MODS = [
    "iron_sights",
    "holosight",
    "redline_sight",
    "threat_scope",
    "scope_4x",
    "smart_lock",
    "pro_screen",
    "pas_fast_reload",
    "extended_ammo",
    "pas_fast_ads",
    "pas_fast_swap",
    "pas_run_and_gun",
    "tactical_cdr_on_kill",
    "ricochet"
    "quick_charge"
]

struct {
    string killstatVersion

    array<string> headers
    array<Parameter> customParameters

    int matchId
    string gameMode
    string map
} file

void function killstat_Init() {
    file.killstatVersion = GetConVarString("killstat_version")
    file.headers = HEADERS

    // custom parameters
    string customParameterString = GetConVarString("killstat_custom_parameters")
    array<string> customParameterEntries = split(customParameterString, ",")
    file.customParameters = []
    foreach (string customParameterEntry in customParameterEntries) {
        array<string> customParameterPair = split(customParameterEntry, "=")
        if (customParameterPair.len() != 2) {
            Log("[WARN] ignoring invalid custom parameter: " + customParameterEntry)
            continue
        }

        Parameter customParameter
        customParameter.name = strip(customParameterPair[0])
        customParameter.value = strip(customParameterPair[1])
        file.customParameters.append(customParameter)
    }

    // callbacks
    AddCallback_GameStateEnter(eGameState.Playing, killstat_Begin)
    AddCallback_OnPlayerKilled(killstat_Record)
    AddCallback_GameStateEnter(eGameState.Postmatch, killstat_End)
}

entity function GetNthWeapon(array<entity> weapons, int index) {
    return index < weapons.len() ? weapons[index] : null
}

void function AddWeapon(array<string> list, entity weapon) {
    string s = "null"
    if (weapon != null) {
        s = weapon.GetWeaponClassName()
    }
    list.append(s)
}

void function AddWeaponMods(array<string> list, entity weapon) {
    array<string> quotedMods = []
    if (weapon != null) {
        foreach (string mod in WEAPON_MODS) {
            if(weapon.HasMod(mod)) {
                quotedMods.append(format("'%s'", mod))
            }
        }
    }
    string cell = "\"[" + join(quotedMods, ", ") + "]\""
    list.append(cell)
}

Parameter function NewParameter(string name, string value) {
    Parameter p
    p.name = name
    p.value = value
    return p
}

void function killstat_Begin() {
    file.matchId = RandomInt(2000000000)
    file.gameMode = GameRules_GetGameMode()
    file.map = GetMapName()

    array<string> headers = []
    foreach (Parameter p in file.customParameters) {
        headers.append(p.name)
    }
    foreach (string s in file.headers) {
        headers.append(s)
    }

    string headerRow = ToCsvRow(headers)

    Log("-----BEGIN KILLSTAT-----")
    Log("[HEADERS] " + headerRow)
}

void function killstat_Record(entity victim, entity attacker, var damageInfo) {
    if ( !victim.IsPlayer() || !attacker.IsPlayer() || GetGameState() != eGameState.Playing )
            return

    array<string> values = []

    foreach (Parameter p in file.customParameters) {
        values.append(p.value)
    }

    array<entity> attackerWeapons = attacker.GetMainWeapons()
    array<entity> victimWeapons = victim.GetMainWeapons()
    array<entity> attackerOffhandWeapons = attacker.GetOffhandWeapons()
    array<entity> victimOffhandWeapons = victim.GetOffhandWeapons()

    entity aw1 = GetNthWeapon(attackerWeapons, 0)
    entity aw2 = GetNthWeapon(attackerWeapons, 1)
    entity aw3 = GetNthWeapon(attackerWeapons, 2)
    entity vw1 = GetNthWeapon(victimWeapons, 0)
    entity vw2 = GetNthWeapon(victimWeapons, 1)
    entity vw3 = GetNthWeapon(victimWeapons, 2)
    entity aow1 = GetNthWeapon(attackerOffhandWeapons, 0)
    entity aow2 = GetNthWeapon(attackerOffhandWeapons, 1)
    entity aow3 = GetNthWeapon(attackerOffhandWeapons, 2)
    entity vow1 = GetNthWeapon(victimOffhandWeapons, 0)
    entity vow2 = GetNthWeapon(victimOffhandWeapons, 1)
    entity vow3 = GetNthWeapon(victimOffhandWeapons, 2)


    foreach (string header in file.headers) {
        switch (header) {
            case "killstat_version":
                values.append(file.killstatVersion)
                break

            case "match_id":
                values.append(format("%08x", file.matchId))
                break

            case "game_mode":
                values.append(file.gameMode)
                break

            case "map":
                values.append(file.map)
                break

            case "unix_time":
                values.append(format("%d", GetUnixTimestamp()))
                break

            case "game_time":
                values.append(format("%.2f", Time()))
                break

            case "player_count":
                values.append(format("%d", GetPlayerArray().len()))
                break

            case "attacker_name":
                values.append(attacker.GetPlayerName())
                break

            case "attacker_id":
                values.append(Anonymize(attacker))
                break

            case "attacker_current_weapon":
                AddWeapon(values, attacker.GetLatestPrimaryWeapon())
                break

            case "attacker_current_weapon_mods":
                AddWeaponMods(values, attacker.GetLatestPrimaryWeapon())
                break

            case "attacker_weapon_1":
                AddWeapon(values, aw1)
                break

            case "attacker_weapon_1_mods":
                AddWeaponMods(values, aw1)
                break
            
            case "attacker_weapon_2":
                AddWeapon(values, aw2)
                break

            case "attacker_weapon_2_mods":
                AddWeaponMods(values, aw2)
                break

            case "attacker_weapon_3":
                AddWeapon(values, aw3)
                break

            case "attacker_weapon_3_mods":
                AddWeaponMods(values, aw3)
                break

            case "attacker_offhand_weapon_1":
                AddWeapon(values, aow1)
                break

            case "attacker_offhand_weapon_2":
                AddWeapon(values, aow2)
                break

            case "attacker_offhand_weapon_3":
                AddWeapon(values, aow3)
                break
                
            case "victim_name":
                values.append(victim.GetPlayerName())
                break

            case "victim_id":
                values.append(Anonymize(victim))
                break

            case "victim_current_weapon":
                AddWeapon(values, victim.GetLatestPrimaryWeapon())
                break

            case "victim_current_weapon_mods":
                AddWeaponMods(values, victim.GetLatestPrimaryWeapon())
                break

            case "victim_weapon_1":
                AddWeapon(values, vw1)
                break

            case "victim_weapon_1_mods":
                AddWeaponMods(values, vw1)
                break

            case "victim_weapon_2":
                AddWeapon(values, vw2)
                break

            case "victim_weapon_2_mods":
                AddWeaponMods(values, vw2)
                break

                case "victim_weapon_3":
                AddWeapon(values, vw3)
                break

            case "victim_weapon_3_mods":
                AddWeaponMods(values, vw3)
                break

            case "victim_offhand_weapon_1":
                AddWeapon(values, vow1)
                break

            case "victim_offhand_weapon_2":
                AddWeapon(values, vow2)
                break

            case "victim_offhand_weapon_3":
                AddWeapon(values, vow3)
                break

            case "cause_of_death":
                int damageSourceId = DamageInfo_GetDamageSourceIdentifier(damageInfo)
                values.append(DamageSourceIDToString(damageSourceId))
                break

            case "distance":
                float dist = Distance(attacker.GetOrigin(), victim.GetOrigin())
                values.append(format("%.2f", dist))
                break

            default:
                break
        }
    }

    string row = ToCsvRow(values)
    Log("[ROW] " + row)
}

void function killstat_End() {
    Log("-----END KILLSTAT-----")
}

void function Log(string s) {
     print("[fvnkhead.killstat] " + s)
}

string function Anonymize(entity player) {
    int hash = StringHash(player.GetPlayerName() + "/" + player.GetUID()) // NSA grade security
    return format("%08x", hash)
}

string function ToCsvRow(array<string> list) {
    return join(list, ",")
}

string function join(array<string> list, string separator) {
    string s = ""
        for (int i = 0; i < list.len(); i++) {
            s += list[i]
                if (i < list.len() - 1) {
                    s += separator
                }
        }

    return s
}
