global function killstat_Init

struct Parameter {
    string name
    string value
}

array<string> KNOWN_HEADERS = [
    "matchid",
    "gamemode",
    "map",
    "time",
    "playercount",
    "attackerid",
    "attackerweapon",
    "victimid",
    "distance"
]

struct {
    array<string> headers
    array<Parameter> customParameters

    int matchId
    string gameMode
    string map
} file

void function killstat_Init() {
    // headers
    file.headers = []
    string headerString = GetConVarString("killstat_headers")
    array<string> headers = split(headerString, ",")
    foreach (string header in headers) {
        header = strip(header)
        if (!KNOWN_HEADERS.contains(header)) {
            Log("[WARN] ignoring invalid header: " + header)
            continue
        }
        file.headers.append(header)
    }

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

    foreach (string header in file.headers) {
        switch (header) {
            case "matchid":
                values.append(format("%08x", file.matchId))
                break

            case "gamemode":
                values.append(file.gameMode)
                break

            case "map":
                values.append(file.map)
                break

            case "time":
                values.append(format("%.2f", Time()))
                break

            case "playercount":
                values.append(format("%d", GetPlayerArray().len()))
                break

            case "attackerid":
                values.append(Anonymize(attacker))
                break

            case "attackerweapon":
                int damageSourceId = DamageInfo_GetDamageSourceIdentifier(damageInfo)
                values.append(DamageSourceIDToString(damageSourceId))
                break

            case "victimid":
                values.append(Anonymize(victim))
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
