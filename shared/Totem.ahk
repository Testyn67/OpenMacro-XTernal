#Requires AutoHotkey v2.0

GetHotbarTotems() {
    totems := []
    seen := Map()
    hotbar := GetHotbarGui()

    if !hotbar
        return totems

    for itemAddr in ReadChildren(hotbar) {
        if (ReadClassName(itemAddr) != "ImageButton" || ReadInstanceName(itemAddr) != "ItemTemplate")
            continue

        toolName := ReadHotbarItemName(itemAddr)
        if !IsSupportedAutoTotem(toolName)
            continue

        if seen.Has(toolName)
            continue

        seen[toolName] := true
        totems.Push(toolName)
    }

    return totems
}

HasHotbarTotem(totemName) {
    return FindHotbarItemByName(totemName) ? true : false
}

GetHotbarItemSlotKey(itemName) {
    itemAddr := FindHotbarItemByName(itemName)
    if !itemAddr
        return ""

    return ReadHotbarItemSlotKey(itemAddr)
}

SelectHotbarSlot(slotKey) {
    if (slotKey = "")
        return false

    SendInput("{" slotKey "}")
    Sleep(75)
    return true
}

UseHotbarSlot(slotKey) {
    if !SelectHotbarSlot(slotKey)
        return false

    Click()
    Sleep(75)
    return true
}

UseEquippedHotbarItem() {
    Click()
    Sleep(75)
    return true
}

GetAutoTotemWaitMs() {
    return 30000
}

GetCharacterModel() {
    workspace := GetWorkspaceRoot()
    if !workspace
        return 0

    localPlayer := GetLocalPlayer()
    if !localPlayer
        return 0

    playerName := ReadInstanceName(localPlayer)
    if (playerName = "" || playerName = "<null>")
        return 0

    return FindChildByName(workspace, playerName)
}

GetEquippedToolName() {
    character := GetCharacterModel()
    if !character
        return ""

    for childAddr in ReadChildren(character) {
        if (ReadClassName(childAddr) = "Tool")
            return ReadInstanceName(childAddr)
    }

    return ""
}

IsAnythingEquipped() {
    character := GetCharacterModel()
    if !character
        return false

    for childAddr in ReadChildren(character) {
        if (ReadClassName(childAddr) = "Tool")
            return true
    }

    return false
}

IsRodEquipped() {
    equippedTool := GetEquippedToolName()
    if (equippedTool = "")
        return false

    rodName := GetHotbarRodName()
    if (rodName != "")
        return (equippedTool = rodName)

    return InStr(equippedTool, "Rod") ? true : false
}

EnsureRodEquipped() {
    if IsRodEquipped()
        return true

    return SelectHotbarSlot("1")
}

TryUseHotbarItem(itemName) {
    slotKey := GetHotbarItemSlotKey(itemName)
    if (slotKey = "")
        return false

    Loop 2 {
        equippedBefore := GetEquippedToolName()

        if (equippedBefore != itemName) {
            if !SelectHotbarSlot(slotKey)
                return false

            Sleep(175)
        }

        Click()
        Sleep(100)

        equippedAfter := GetEquippedToolName()

        if (equippedAfter = itemName || equippedBefore = itemName)
            return true

        Sleep(125)
    }

    return false
}

; ─────────────────────────────────────────────────────────────────────────
;  World state (weather / cycle) is read from the authoritative
;  ReplicatedStorage.world Configuration the game replicates. Since the weather
;  overhaul, weather is three coexisting layers: the base "weather", a buffing
;  "sovereign" child, and a "meteorological" (celestial, e.g. Aurora) child.
;  This replaces the old HUD-scraping, which broke when the HUD layout changed.
; ─────────────────────────────────────────────────────────────────────────

GetWorldConfig() {
    global g_CachedWorldConfig

    if (g_CachedWorldConfig)
        return g_CachedWorldConfig

    dataModel := GetDataModel()
    if (!dataModel)
        return 0

    replicatedStorage := FindChildByClass(dataModel, "ReplicatedStorage")
    if (!replicatedStorage)
        return 0

    world := FindChildByName(replicatedStorage, "world")
    if (world)
        g_CachedWorldConfig := world

    return world
}

; Read a StringValue's Value: inline std::string at +Value, falling back to a
; pointer-to-string if the inline read is empty.
ReadWorldStringValue(instanceAddr) {
    global OFFSETS

    if (!instanceAddr)
        return ""

    valueOffset := OFFSETS.Has("Value") ? (OFFSETS["Value"] + 0) : 0xd0

    embedded := ReadString(instanceAddr + valueOffset)
    if (embedded != "")
        return embedded

    ptr := ReadPointer(instanceAddr + valueOffset)
    if (ptr)
        return ReadString(ptr)

    return ""
}

; The game stores "None" for an inactive layer; surface that as empty.
NormalizeWorldNone(value) {
    trimmed := Trim(value)
    return (StrLower(trimmed) = "none") ? "" : trimmed
}

GetWorldWeatherInstance() {
    world := GetWorldConfig()
    if (!world)
        return 0

    return FindChildByName(world, "weather")
}

GetCurrentWeather() {
    return Trim(ReadWorldStringValue(GetWorldWeatherInstance()))
}

GetCurrentSovereign() {
    weatherInst := GetWorldWeatherInstance()
    if (!weatherInst)
        return ""

    return NormalizeWorldNone(ReadWorldStringValue(FindChildByName(weatherInst, "sovereign")))
}

GetCurrentMeteorological() {
    weatherInst := GetWorldWeatherInstance()
    if (!weatherInst)
        return ""

    return NormalizeWorldNone(ReadWorldStringValue(FindChildByName(weatherInst, "meteorological")))
}

GetCurrentCycle() {
    world := GetWorldConfig()
    if (!world)
        return ""

    return Trim(ReadWorldStringValue(FindChildByName(world, "cycle")))
}

IsNightCycle() {
    return InStr(StrLower(GetCurrentCycle()), "night") ? true : false
}

IsAuroraActive() {
    if InStr(StrLower(GetCurrentMeteorological()), "aurora")
        return true

    return InStr(StrLower(GetCurrentWeather()), "aurora") ? true : false
}

IsSovereignActive() {
    return (GetCurrentSovereign() != "") ? true : false
}

FindHotbarItemByName(itemName) {
    hotbar := GetHotbarGui()
    if !hotbar
        return 0

    for itemAddr in ReadChildren(hotbar) {
        if (ReadClassName(itemAddr) != "ImageButton" || ReadInstanceName(itemAddr) != "ItemTemplate")
            continue

        if (ReadHotbarItemName(itemAddr) = itemName)
            return itemAddr
    }

    return 0
}

ReadHotbarItemName(itemAddr) {
    nameInst := FindChildByName(itemAddr, "ItemName")
    if !nameInst
        return ""

    return NormalizeHotbarItemText(ReadGuiText(nameInst))
}

ReadHotbarItemSlotKey(itemAddr) {
    for childAddr in ReadChildren(itemAddr) {
        childClass := ReadClassName(childAddr)
        childName := ReadInstanceName(childAddr)

        if (childClass = "TextLabel" && childName = "TextLabel")
            return NormalizeHotbarItemText(ReadGuiText(childAddr))
    }

    return ""
}

NormalizeHotbarItemText(text) {
    if (text = "")
        return ""

    return Trim(RegExReplace(text, "<[^>]+>"))
}

IsSupportedAutoTotem(toolName) {
    return (toolName = "Aurora Totem")
}

FindDescendantByNameAndClass(rootAddr, targetName, targetClass := "") {
    queue := [rootAddr]
    index := 1

    while (index <= queue.Length) {
        current := queue[index]
        index += 1

        currentName := ReadInstanceName(current)
        currentClass := ReadClassName(current)

        if (currentName = targetName && (targetClass = "" || currentClass = targetClass))
            return current

        for childAddr in ReadChildren(current)
            queue.Push(childAddr)
    }

    return 0
}
