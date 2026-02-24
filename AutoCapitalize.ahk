; ============================================================
; AutoCapitalize.ahk
; - Capitalizes sentence starts (. ! ? followed by space)
; - Capitalizes first letter after focus moves to a new text field
; - Skips terminals, editors, and IDEs listed below
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; Excluded applications (script stays passive in these processes)
ExcludedApps := [
    ; Terminals
    "WindowsTerminal.exe",
    "cmd.exe",
    "powershell.exe",
    "pwsh.exe",
    "wt.exe",
    "ConEmu64.exe",
    "ConEmuC64.exe",
    "mintty.exe",
    "bash.exe",
    "alacritty.exe",
    "hyper.exe",
    "FluentTerminal.exe",

    ; Text Editors
    "notepad++.exe",
    "sublime_text.exe",
    "atom.exe",
    "gedit.exe",
    "kate.exe",

    ; IDEs
    "code.exe",
    "idea64.exe",
    "pycharm64.exe",
    "webstorm64.exe",
    "clion64.exe",
    "goland64.exe",
    "rider64.exe",
    "devenv.exe",
    "eclipse.exe",
    "netbeans64.exe",
    "AndroidStudio.exe",
    "cursor.exe",
    "windsurf.exe",
    "zed.exe"
]

; State tracking
; lastChar: recent punctuation/space/letter marker
; shouldCapNext: force-capitalize next typed letter
; charCount: rough typed-length tracker for backspace/delete fallback
global lastChar          := ""
global lastWindow        := ""
global lastControl       := ""
global shouldCapNext     := false
global charCount         := 0
global countReliable     := true
global ctrlAStamp        := 0
global ctrlAWindow       := 0
global ctrlAControl      := ""
global lbtnDownX         := 0
global lbtnDownY         := 0
global excludedCacheHwnd := 0
global excludedCacheVal  := false

; New field detection: when focus moves, treat next letter as a new start.
SetTimer(CheckFocus, 150)

CheckFocus() {
    global lastWindow, lastControl, shouldCapNext, lastChar, charCount, ctrlAStamp, countReliable

    try {
        if IsExcluded()
            return

        hwnd    := WinGetID("A")
        control := ControlGetFocus("A")

        if (hwnd != lastWindow || control != lastControl) {
            lastWindow    := hwnd
            lastControl   := control
            lastChar      := ""
            charCount     := 0
            countReliable := true
            shouldCapNext := true
            ctrlAStamp    := 0
        }
    }
}

; Mouse drag detection for selection-replace behavior.
~LButton::
{
    global lbtnDownX, lbtnDownY
    if IsExcluded()
        return

    MouseGetPos(&lbtnDownX, &lbtnDownY)
}

~LButton Up::
{
    global shouldCapNext, lastChar, charCount, countReliable, ctrlAStamp, lbtnDownX, lbtnDownY
    if IsExcluded()
        return

    MouseGetPos(&upX, &upY)
    moved := Abs(upX - lbtnDownX) + Abs(upY - lbtnDownY)

    ; Drag-selection usually means next keypress replaces selected text.
    if (moved >= 6) {
        shouldCapNext := true
        lastChar      := ""
        charCount     := 0
        countReliable := true
        ctrlAStamp    := 0
    }
}

; Letter hooks
~a::HandleKey("a")
~b::HandleKey("b")
~c::HandleKey("c")
~d::HandleKey("d")
~e::HandleKey("e")
~f::HandleKey("f")
~g::HandleKey("g")
~h::HandleKey("h")
~i::HandleKey("i")
~j::HandleKey("j")
~k::HandleKey("k")
~l::HandleKey("l")
~m::HandleKey("m")
~n::HandleKey("n")
~o::HandleKey("o")
~p::HandleKey("p")
~q::HandleKey("q")
~r::HandleKey("r")
~s::HandleKey("s")
~t::HandleKey("t")
~u::HandleKey("u")
~v::HandleKey("v")
~w::HandleKey("w")
~x::HandleKey("x")
~y::HandleKey("y")
~z::HandleKey("z")

; Punctuation markers (US keyboard)
~.::
{
    global lastChar
    if IsExcluded()
        return

    lastChar := "."
}

; Shift+1 => !
~+1::
{
    global lastChar
    if IsExcluded()
        return

    lastChar := "!"
}

; Shift+/ => ?
~+/::
{
    global lastChar
    if IsExcluded()
        return

    lastChar := "?"
}

~Space::
{
    global lastChar, charCount
    if IsExcluded()
        return

    ; Preserve sentence-ending context for ". ", "! ", and "? ".
    if (lastChar == "." || lastChar == "!" || lastChar == "?")
        lastChar := lastChar . " "
    else
        lastChar := " "
    charCount += 1
}

~Enter::
{
    global lastChar, shouldCapNext, charCount, countReliable
    if IsExcluded()
        return

    lastChar      := ""
    charCount     := 0
    countReliable := true
    shouldCapNext := true
}

~BackSpace::
{
    global lastChar, shouldCapNext, charCount, countReliable, ctrlAStamp
    if IsExcluded()
        return

    ; Ctrl+A then Backspace clears content; treat next letter as a fresh start.
    if IsRecentCtrlA() {
        lastChar      := ""
        charCount     := 0
        countReliable := true
        shouldCapNext := true
        ctrlAStamp    := 0
        return
    }

    if !countReliable {
        lastChar      := ""
        shouldCapNext := false
        return
    }

    lastChar := ""
    if (charCount > 0)
        charCount -= 1

    if (charCount <= 0) {
        charCount     := 0
        shouldCapNext := true
    }
}

~^BackSpace::
{
    global lastChar, charCount, countReliable, shouldCapNext
    if IsExcluded()
        return

    charCount     := 0
    countReliable := true
    lastChar      := ""
    shouldCapNext := true
}

~^a::
{
    global ctrlAStamp, ctrlAWindow, ctrlAControl
    if IsExcluded()
        return

    ; Remember where Ctrl+A happened so Delete/typing logic can validate context.
    try {
        ctrlAStamp   := A_TickCount
        ctrlAWindow  := WinGetID("A")
        ctrlAControl := ControlGetFocus("A")
    }
}

~Delete::
{
    global shouldCapNext, lastChar, charCount, countReliable, ctrlAStamp
    if IsExcluded()
        return

    ; Ctrl+A then Delete clears content; next letter should be capitalized.
    if IsRecentCtrlA() {
        shouldCapNext := true
        lastChar      := ""
        charCount     := 0
        countReliable := true
    } else {
        lastChar := ""
        if (countReliable && charCount > 0)
            charCount -= 1
    }

    ctrlAStamp := 0
}

~^v::
{
    global lastChar, shouldCapNext, countReliable
    if IsExcluded()
        return

    ; Pasted text length/content is unknown to this tracker.
    ; Intentional tradeoff: keep countReliable false until a known reset event
    ; (focus change, Enter, drag-select replace, Ctrl+A clear path, etc.).
    lastChar      := ""
    shouldCapNext := false
    countReliable := false
}

~+Insert::
{
    global lastChar, shouldCapNext, countReliable
    if IsExcluded()
        return

    ; Shift+Insert is another common paste shortcut.
    lastChar      := ""
    shouldCapNext := false
    countReliable := false
}

; Core letter handler
HandleKey(letter) {
    global lastChar, shouldCapNext, charCount, countReliable, ctrlAStamp

    if IsExcluded()
        return

    ; Ignore shortcuts (Ctrl/Alt combos) so non-typing actions do not alter state.
    if GetKeyState("Ctrl") || GetKeyState("Alt")
        return

    recentSelectAll := IsRecentCtrlA(2500)
    if recentSelectAll {
        lastChar   := ""
        charCount  := 0
        countReliable := true
        ctrlAStamp := 0
    }

    needsCap := shouldCapNext
             || (lastChar == ". " || lastChar == "! " || lastChar == "? ")
             || recentSelectAll

    shouldCapNext := false

    if needsCap && !IsModifierDown() {
        Send("{BackSpace}")
        Send("{Shift Down}" . letter . "{Shift Up}")
    }

    lastChar  := letter
    charCount += 1
}

; Helper functions
IsExcluded() {
    global ExcludedApps, excludedCacheHwnd, excludedCacheVal

    try {
        hwnd := WinGetID("A")
        if (hwnd = excludedCacheHwnd)
            return excludedCacheVal

        pid := WinGetPID("A")
        exe := ProcessGetName(pid)
        isExcluded := false

        for app in ExcludedApps {
            if (exe = app) {
                isExcluded := true
                break
            }
        }

        excludedCacheHwnd := hwnd
        excludedCacheVal  := isExcluded
        return isExcluded
    }

    return false
}

IsModifierDown() {
    return GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("Shift")
}

IsRecentCtrlA(maxAgeMs := 1500) {
    global ctrlAStamp, ctrlAWindow, ctrlAControl
    if (ctrlAStamp <= 0)
        return false

    ; Valid only while still in the same target where Ctrl+A was pressed.
    try {
        hwnd    := WinGetID("A")
        control := ControlGetFocus("A")
        return (A_TickCount - ctrlAStamp) <= maxAgeMs
            && (hwnd = ctrlAWindow)
            && (control = ctrlAControl)
    }
    return false
}
