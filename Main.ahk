/*
OpenMacro XTernal
Copyright © 2026 (@anorexc) on Discord.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.
*/

#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon

#Include library\JSON.ahk
#Include shared\Constants.ahk
#Include shared\Settings.ahk
#Include shared\Update.ahk
#Include shared\Process.ahk
#Include shared\Read.ahk
#Include shared\OffsetsRemote.ahk
#Include shared\Memory.ahk
#Include shared\Totem.ahk
#Include shared\Appraise.ahk
#Include shared\Hotkeys.ahk
#Include shared\Fish.ahk
#Include shared\Webhook.ahk
#Include library\Discord\DiscordBuilder.ahk
#Include ui\Dialogs\UpdateDialog.ahk
#Include ui\Dialogs\PostUpdateDialog.ahk
#Include ui\Dialogs\AdvSettingsDialog.ahk
#Include ui\Gui.ahk

global Macro := CreateFishingMacro()
global Controller := FishingController()

if HandleStartupUpdate()
    ExitApp()

HotkeyManager.RegisterAll(SETTINGS)

try {
    Initialize()
    RecordSuccessfulUpdateLaunch()
} catch as err {
    MsgBox(err.Message, "Startup Error")
    ExitApp(1)
}

ShowPendingPostUpdateDialog()
GetGui()

Initialize() {
    global RBLX_PID, RBLX_BASE, ROD, Macro

    EnsureAppDataDirs()

    if (rbxPid := GetRobloxPID()) {
        CheckRobloxVersionMismatch(rbxPid)

        if !EnsureRobloxReady(false, true)
            MsgBox("Roblox was detected, but XTernal could not attach. The app will still open. Use Fix Roblox or start the macro again after Roblox is ready.", "Roblox Attachment")
    }

    SetTimer(MacroLoop, MAIN["update_rate"])
}

HandleStartupUpdate() {
    remoteVersion := CheckForAvailableUpdate()

    if (remoteVersion = "")
        return false

    if (UPDATE["auto_update"])
        return BeginUpdateInstall(remoteVersion)

    return GetUpdDialog(FULL_VER, remoteVersion)
}

ShowPendingPostUpdateDialog() {
    updatedVersion := ConsumePostUpdateVersion()

    if (updatedVersion = "")
        return

    if UPDATE["show_confirmation"]
        GetPostUpdateDialog(updatedVersion)
}

[:: Reload()
