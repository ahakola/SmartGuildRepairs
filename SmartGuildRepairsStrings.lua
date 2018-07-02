--[[----------------------------------------------------------------------------
	Smart Guild Repairs

	2016-
	Sanex @ EU-Arathor / ahak @ Curseforge
----------------------------------------------------------------------------]]--

local ADDON_NAME, ns = ...

local LOCALE = GetLocale()
local L = {}
ns.L = L

L.RepairThis = "R" -- Short indicator in the PaperDollFrame slots for item marked for manual repair in optimal solution.
L.RepairedWithGuildMoney = "Repaired using guild bank withdraws for %1$s (%2$s remaining)." -- %1$s = formatMoney-string of used withdraws, %2$s = formatMoney-string of remaining withdraws
L.OptimalSolutionFound = "Not enough guild bank withdraws to repair all, but found optimal solution that uses guild bank withdraws for: %1$s (%2$d%% of current maximum)." -- Only in Full-mode, %1$s = formatMoney-string of withdraws to be used, %2$d = percentage
L.NoSolutions = "Not enough guild bank withdraws to repair all and found no possible solutions." -- Only in Full-mode
L.RepairTheseManually = "You have to repair these items with your own expense: %s." -- %s = list of items for user to manually repair
L.NoNeedForRepairs = "No need for repairs."
L.psilent = "silent" -- Parameter for silent-mode
L.pnormal = "normal" -- Parameter for normal-mode
L.pfull = "full" -- Parameter for full-mode
L.Help = "/smartguildrepairs ( %1$s | %2$s | %3$s )\n %1$s - No print output at all.\n %2$s - Default print output.\n %3$s - Print extra info." -- %1$s == L.psilent, %2$s == L.pnormal, %3$s == L.pfull
L.Silent = "Silent"
L.Normal = "Normal"
L.Full = "Full"
L.VerboseLevelSet = "Verboselevel set to %s" -- %s == L.Silent, L.Normal or L.Full
L.VerboseLevelIs = "Current verbose level: %s" -- %s == L.Silent, L.Normal or L.Full

if LOCALE == "deDE" then
--@localization(locale="deDE", format="lua_additive_table", same-key-is-true=true)@

elseif LOCALE == "esES" then
--@localization(locale="esES", format="lua_additive_table", same-key-is-true=true)@

elseif LOCALE == "esMX" then
--@localization(locale="esMX", format="lua_additive_table", same-key-is-true=true)@

elseif LOCALE == "frFR" then
--@localization(locale="frFR", format="lua_additive_table", same-key-is-true=true)@

elseif LOCALE == "itIT" then
--@localization(locale="itIT", format="lua_additive_table", same-key-is-true=true)@

elseif LOCALE == "ptBR" then
--@localization(locale="ptBR", format="lua_additive_table", same-key-is-true=true)@

elseif LOCALE == "ruRU" then
--@localization(locale="ruRU", format="lua_additive_table", same-key-is-true=true)@

elseif LOCALE == "koKR" then
--@localization(locale="koKR", format="lua_additive_table", same-key-is-true=true)@

elseif LOCALE == "zhCN" then
--@localization(locale="zhCN", format="lua_additive_table", same-key-is-true=true)@

elseif LOCALE == "zhTW" then
--@localization(locale="zhTW", format="lua_additive_table", same-key-is-true=true)@

end