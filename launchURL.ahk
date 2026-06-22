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
global browsers := [{ Name: "Firefox", Path: "C:\Program Files\Mozilla Firefox\firefox.exe" }, { Name: "Brave", Path: "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe" }, { Name: "Zen", Path: "C:\Program Files\Zen Browser\zen.exe" }
]
global currentBrowserIndex := 1
global settingsFileName := "settings.ini"
DetectHiddenWindows True
hw := WinExist(applicationTitle " ahk_exe AutoHotkey64.exe") ; When launched with AHK Interpreter
hw2 := WinExist(applicationTitle " ahk_exe launchURL.exe") ; When launched with compiled version

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


; if no instance running
global browserGUI := gui_constructor()


gui_constructor() {
    MyGui := Gui("+AlwaysOnTop", applicationTitle)
    MyGui.AddText("", "Select your default browser:")
    MyGui.OnEvent("Close", HideGUI)
    ; Map the array names to a simple list for the DropDownList
    BrowserNames := []
    for b in Browsers
        BrowserNames.Push(b.Name)

    ; Add the dropdown and select the current one
    ChooseDrop := MyGui.AddDropDownList("Choose" CurrentBrowserIndex " w200", BrowserNames)

    currentIndex := IniRead(settingsFileName, "Settings", "CurrentBrowserIndex", "1")
    ChooseDrop.Value := Number(currentIndex)
    global currentBrowserIndex := ChooseDrop.Value
    ChooseDrop.OnEvent("Change", OnBrowserChange)

    OnBrowserChange(CtrlObj, *) {
        global CurrentBrowserIndex := CtrlObj.Value
        IniWrite(ChooseDrop.Value, settingsFileName, "Settings", "CurrentBrowserIndex")
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

if (A_Args.Length >= 1) {
    OpenURL(A_Args[1])
} else {
    browserGUI.Show()
}

OpenURL(url) {
    browserPath := Browsers[CurrentBrowserIndex].Path
    try {
        Run('"' browserPath '" "' url '"')
    } catch Error as err {
        MsgBox("Failed to launch " Browsers[CurrentBrowserIndex].Name "`n`n" err.Message, "Error", "IconX")
    }
}

OnMessage(0x004A, ReceiveCopyData) ; 0x004A is WM_COPYDATA

;; MESSAGING HELPER FUNCTIONS

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