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
    "time",
    "player_count",
    "attacker_name",
    "attacker_id",
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

    entity aw1 = attackerWeapons.len() >= 1 ? attackerWeapons[0] : null
    entity aw2 = attackerWeapons.len() >= 2 ? attackerWeapons[1] : null
    entity aw3 = attackerWeapons.len() >= 3 ? attackerWeapons[2] : null
    entity vw1 = victimWeapons.len() >= 1 ? victimWeapons[0] : null
    entity vw2 = victimWeapons.len() >= 2 ? victimWeapons[1] : null
    entity vw3 = victimWeapons.len() >= 3 ? victimWeapons[2] : null
    entity aow1 = attackerOffhandWeapons.len() >= 1 ? attackerOffhandWeapons[0] : null
    entity aow2 = attackerOffhandWeapons.len() >= 2 ? attackerOffhandWeapons[1] : null
    entity aow3 = attackerOffhandWeapons.len() >= 3 ? attackerOffhandWeapons[2] : null
    entity vow1 = victimOffhandWeapons.len() >= 1 ? victimOffhandWeapons[0] : null
    entity vow2 = victimOffhandWeapons.len() >= 2 ? victimOffhandWeapons[1] : null
    entity vow3 = victimOffhandWeapons.len() >= 3 ? victimOffhandWeapons[2] : null


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

            case "time":
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

            case "attacker_weapon_1":
                if (aw1 != null) {
                    values.append(aw1.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break

            case "attacker_weapon_1_mods":
                array<string> quotedMods = []
                if (aw1 != null) {
                    foreach (string mod in WEAPON_MODS) {
                        if(aw1.HasMod(mod)) {
                            quotedMods.append(format("'%s'", mod))
                        }
                    }
                    string cell = "\"[" + join(quotedMods, ", ") + "]\""
                    values.append(cell)
                }
                else {
                    values.append("null")
                }
                break
            
            case "attacker_weapon_2":
                if (aw2 != null) {
                    values.append(aw2.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break

            case "attacker_weapon_2_mods":
                array<string> quotedMods = []
                if (aw2 != null) {
                    foreach (string mod in WEAPON_MODS) {
                        if(aw2.HasMod(mod)) {
                            quotedMods.append(format("'%s'", mod))
                        }
                    }
                    string cell = "\"[" + join(quotedMods, ", ") + "]\""
                    values.append(cell)
                }
                else {
                    values.append("null")
                }
                break

            case "attacker_weapon_3":
                if (aw3 != null) {
                    values.append(aw3.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break

            case "attacker_weapon_3_mods":
                array<string> quotedMods = []
                if (aw3 != null) {
                    foreach (string mod in WEAPON_MODS) {
                        if(aw3.HasMod(mod)) {
                            quotedMods.append(format("'%s'", mod))
                        }
                    }
                    string cell = "\"[" + join(quotedMods, ", ") + "]\""
                    values.append(cell)
                }
                else {
                    values.append("null")
                }
                break

            case "attacker_offhand_weapon_1":
                if (aow1 != null) {
                    values.append(aow1.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break

            case "attacker_offhand_weapon_2":
                if (aow2 != null) {
                    values.append(aow2.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break

            case "attacker_offhand_weapon_3":
                if (aow3 != null) {
                    values.append(aow3.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break
                

            case "victim_name":
                values.append(victim.GetPlayerName())
                break

            case "victim_id":
                values.append(Anonymize(victim))
                break

            case "victim_weapon_1":
                if (vw1 != null) {
                    values.append(vw1.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break

            case "victim_weapon_1_mods":
                array<string> quotedMods = []
                if (vw1 != null) {
                    foreach (string mod in WEAPON_MODS) {
                        if(vw1.HasMod(mod)) {
                            quotedMods.append(format("'%s'", mod))
                        }
                    }
                    string cell = "\"[" + join(quotedMods, ", ") + "]\""
                    values.append(cell)
                }
                else {
                    values.append("null")
                }
                break

            case "victim_weapon_2":
                if (vw2 != null) {
                    values.append(vw2.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break

            case "victim_weapon_2_mods":
                array<string> quotedMods = []
                if (vw2 != null) {
                    foreach (string mod in WEAPON_MODS) {
                        if(vw2.HasMod(mod)) {
                            quotedMods.append(format("'%s'", mod))
                        }
                    }
                    string cell = "\"[" + join(quotedMods, ", ") + "]\""
                    values.append(cell)
                }
                else {
                    values.append("null")
                }
                break

                case "victim_weapon_3":
                if (vw3 != null) {
                    values.append(vw3.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break

            case "victim_weapon_3_mods":
                array<string> quotedMods = []
                if (vw3 != null) {
                    foreach (string mod in WEAPON_MODS) {
                        if(vw3.HasMod(mod)) {
                            quotedMods.append(format("'%s'", mod))
                        }
                    }
                    string cell = "\"[" + join(quotedMods, ", ") + "]\""
                    values.append(cell)
                }
                else {
                    values.append("null")
                }
                break

            case "victim_offhand_weapon_1":
                if (vow1 != null) {
                    values.append(vow1.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break

            case "victim_offhand_weapon_2":
                if (vow2 != null) {
                    values.append(vow2.GetWeaponClassName())
                } else {
                    values.append("null")
                }
                break

            case "victim_offhand_weapon_3":
                if (vow3 != null) {
                    values.append(vow3.GetWeaponClassName())
                } else {
                    values.append("null")
                }
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
