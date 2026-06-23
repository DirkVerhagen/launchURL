Persistent
/************************************************************************
 * @description launchURL.ahk
 * @author Dirk Verhagen
 * @date 2026/06/22
 * @version 0.0.1
 * 
 * Launches itself to the system tray where it will wait for a URL to be sent to it via a command line parameter
 * If this is executed, the software will send the URL to the already running systray application and close itself
 * The Systray application will than, via some mechanism determine the preferred browser and launch the URL in that browser
 * 
 * You can use this if you don't always have the same default browser to open URLs
 ***********************************************************************/
; TODO: Add hotkey for launching URL in clipboard
; TODO: Add hotkey for launching search URL on text in clipboard


#SingleInstance Off
#Requires AutoHotkey v2.0
global applicationTitle := "Browser_Picker"
; Leave this in, just in case the GetInstalledBrowsers function does not work anymore
global browsers := [{ Name: "Firefox", Path: "C:\Program Files\Mozilla Firefox\firefox.exe" }, { Name: "Brave", Path: "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe" }, { Name: "Zen", Path: "C:\Program Files\Zen Browser\zen.exe" }
]
global currentBrowserIndex := 1
global personalBrowserIndex := 1
global workBrowserIndex := 1
global settingsFileName := "settings.ini"
DetectHiddenWindows True
hw := WinExist(applicationTitle " ahk_exe AutoHotkey64.exe") ; When launched with AHK Interpreter
hw2 := WinExist(applicationTitle " ahk_exe launchURL.exe") ; When launched with compiled version

; if either hw1 or hw2 is true, it means either there's an interpreted version or a compiled version of this script already running
if (hw) {
    ; Send the URL string to the running instance using WM_COPYDATA
    if (A_Args.Length >= 1) {
        TargetURL := A_Args[1]
        SendCopyData(hw, TargetURL)
    }
    ExitApp()
}
else if (hw2) {
    if (A_Args.Length >= 1) {
        TargetURL := A_Args[1]
        SendCopyData(hw2, TargetURL)
    }
    ExitApp()
}
; if none of the above evaluated to true this is the first instance running
; create a GUI and if there are arguments open a URL

browsers := GetInstalledBrowsers()

global browserGUI := gui_constructor()

gui_constructor() {
    MyGui := Gui("+AlwaysOnTop", applicationTitle)

    MyGui.OnEvent("Close", HideGUI)
    MyGui.AddText("", "Personal Browser:")
    BrowserNames := []
    for b in Browsers
        BrowserNames.Push(b.Name)
    PersonalBrowserDrop := MyGui.AddDropDownList("Choose" personalBrowserIndex " w200", BrowserNames)
    storedIndex := IniRead(settingsFileName, "Settings", "PersonalBrowserIndex", "1")
    PersonalBrowserDrop.Value := Number(storedIndex)
    global personalBrowserIndex := PersonalBrowserDrop.Value
    PersonalBrowserDrop.OnEvent("Change", OnPersonalBrowserChange)

    OnPersonalBrowserChange(CtrlObj, *) {
        global personalBrowserIndex := CtrlObj.Value
        IniWrite(PersonalBrowserDrop.Value, settingsFileName, "Settings", "PersonalBrowserIndex")
    }

    MyGui.AddText("", "Work Browser:")
    WorkBrowserDrop := MyGui.AddDropDownList("Choose" workBrowserIndex " w200", BrowserNames)
    storedIndex := IniRead(settingsFileName, "Settings", "WorkBrowserIndex", "1")
    WorkBrowserDrop.Value := Number(storedIndex)
    global personalBrowserIndex := WorkBrowserDrop.Value
    WorkBrowserDrop.OnEvent("Change", OnWorkBrowserChange)

    OnWorkBrowserChange(CtrlObj, *) {
        global workBrowserIndex := CtrlObj.Value
        IniWrite(WorkBrowserDrop.Value, settingsFileName, "Settings", "WorkBrowserIndex")
    }

    hideGUI(thisGUI) {
        thisGUI.Hide()
        return 1
    }
    return MyGui
}


;; Code to put everything in system tray
A_IconHidden := false
Tray := A_TrayMenu
Tray.Delete() ; Clear default options
Tray.Add("Show Settings", (*) => browserGUI.Show())
Tray.Add("Exit", (*) => ExitApp())
Tray.Default := "Show Settings"


; If this call had an argument open it. Otherwise show the gui to indicate that we've booted
if (A_Args.Length >= 1) {
    OpenURL(A_Args[1])
} else {
    browserGUI.Show()
}


; Start waiting for messages
OnMessage(0x004A, ReceiveCopyData) ; 0x004A is WM_COPYDATA

; Functions

OpenURL(url) {
    global personalBrowserIndex
    global workBrowserIndex

    isWorkDay := (A_WDay >= 2 && A_WDay <= 6) ; 1 is Sunday, 2-6 is Mon-Fri, 7 is Saturday
    isWorkHour := (A_Hour >= 9 && A_Hour < 17) ; 09:00 to 16:59

    index := personalBrowserIndex
    if (isWorkDay && isWorkHour)
        index := workBrowserIndex

    browserPath := Browsers[index].Path
    try {
        Run('"' browserPath '" "' url '"')
    } catch Error as err {
        MsgBox("Failed to launch " Browsers[index].Name "`n`n" err.Message, "Error", "IconX")
    }
}

ReceiveCopyData(wParam, lParam, msg, hwnd) {
    ; Extract the string (URL) from the pointer structure
    StringPtr := NumGet(lParam, 2 * A_PtrSize, "Ptr")
    URL := StrGet(StringPtr)

    ; Open the URL using our currently selected browser!
    OpenURL(URL)
    return true
}

SendCopyData(hwndTarget, stringToSend) {
    size := (StrLen(stringToSend) + 1) * 2
    cds := Buffer(A_PtrSize * 3, 0)
    NumPut("Ptr", 0, cds, 0)
    NumPut("UInt", size, cds, A_PtrSize)

    buf := Buffer(size, 0)
    StrPut(stringToSend, buf, "UTF-16")
    NumPut("Ptr", buf.Ptr, cds, A_PtrSize * 2)

    return SendMessage(0x004A, 0, cds.Ptr, hwndTarget)
}

GetInstalledBrowsers() {
    browserList := []
    regKey := "HKLM\SOFTWARE\Clients\StartMenuInternet"

    ; Loop through the subkeys (each representing an installed browser)
    Loop Reg, regKey, "K" {
        browserRegName := A_LoopRegName

        ; 1. Get the friendly display name
        try {
            friendlyName := RegRead(regKey "\" browserRegName)
        } catch {
            friendlyName := browserRegName ; Fallback if standard value is empty
        }

        ; 2. Get the execution path
        try {
            execPath := RegRead(regKey "\" browserRegName "\shell\open\command")


        } catch {
            continue ; Skip this entry if we can't find a valid path
        }
        ; This regular expression assumes a results will look like '"<EXEC PATH>" -- Flags'
        cleanExecPath := RegExReplace(execPath, '^"([^"]+)"(.*)$', '$1')
        ; Add it to our array if it exists
        if FileExist(cleanExecPath) {

            browserList.Push({ Name: friendlyName, Path: cleanExecPath })
        }
    }

    ; Fallback in case the registry loop comes up completely empty
    if (browserList.Length == 0) {
        browserList.Push({ Name: "Edge (Fallback)", Path: "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" })
    }

    return browserList
}