local _, ns = ...

if GetLocale() ~= "deDE" then
    return
end

local L = ns.L

L["ADDON_LOADED"] = "Version %s geladen. Tippe /gryphoncraft für Hilfe."
L["DEBUG_ON"] = "Debug-Ausgabe aktiviert."
L["DEBUG_OFF"] = "Debug-Ausgabe deaktiviert."
L["HELP_HEADER"] = "Befehle:"
L["HELP_VERSION"] = "/gryphoncraft version - zeigt die Addon-Version"
L["HELP_DEBUG"] = "/gryphoncraft debug - schaltet die Debug-Ausgabe um"
L["HELP_NOTIFY"] = "/gryphoncraft notify on||off - automatische Meldungen (Login, Hinweise)"
L["NOTIFY_ON"] = "Automatische Meldungen sind für diesen Charakter an."
L["NOTIFY_OFF"] = "Automatische Meldungen sind für diesen Charakter aus. Antworten auf Befehle erscheinen weiter."
L["HELP_OPTIONS"] = "/gryphoncraft options - öffnet die Optionen"
L["OPTIONS_IN_COMBAT"] = "Im Kampf lassen sich die Optionen nicht per Befehl öffnen. "
    .. "Esc > Optionen > AddOns nutzen oder nach dem Kampf erneut versuchen."
L["OPTIONS_NOTIFICATIONS"] = "Automatische Meldungen"
L["OPTIONS_NOTIFICATIONS_TOOLTIP"] = "Meldungen, die das Addon von sich aus zeigt: beim Login und Hinweise. "
    .. "Antworten auf Befehle erscheinen immer. Für diesen Charakter."
