--[[----------------------------------------------------------------------------
	Smart Guild Repairs

	2016-
	Sanex @ EU-Arathor / ahak @ Curseforge
----------------------------------------------------------------------------]]--

-- GLOBALS: DEBUG_CHAT_FRAME, SLASH_SMARTGUILDREPAIRS1, SLASH_SMARTGUILDREPAIRS2, SmartGuildRepairsSettings

-- GLOBALS: _G, C_TooltipInfo, CanGuildBankRepair, CanMerchantRepair, ChatFrame1, CreateFrame, DEFAULT_CHAT_FRAME, Enum
-- GLOBALS: format, GetGuildBankMoney, GetGuildBankWithdrawMoney, GetRepairAllCost, IsInGuild, math, pairs
-- GLOBALS: RepairAllItems, SlashCmdList, string, strjoin, table, tostringall, type, UIParent

local ADDON_NAME, ns = ...
--local f = CreateFrame("Frame")
local f = CreateFrame("Frame", nil, _G.PaperDollFrame)
local L = ns.L
local registered = false
local numcalls, db
local gearSlots = { -- Slot names
	_G["HEADSLOT"], -- 1 ! Can break
	_G["NECKSLOT"], -- 2
	_G["SHOULDERSLOT"], -- 3 ! Can break
	_G["SHIRTSLOT"], -- 4
	_G["CHESTSLOT"], -- 5 ! Can break
	_G["WAISTSLOT"], -- 6 ! Can break
	_G["LEGSSLOT"], -- 7 ! Can break
	_G["FEETSLOT"], -- 8 ! Can break
	_G["WRISTSLOT"], -- 9 ! Can break
	_G["HANDSSLOT"], -- 10 ! Can break
	_G["FINGER0SLOT_UNIQUE"], -- 11
	_G["FINGER1SLOT_UNIQUE"], -- 12
	_G["TRINKET0SLOT_UNIQUE"], -- 13
	_G["TRINKET1SLOT_UNIQUE"], -- 14
	_G["BACKSLOT"], -- 15
	_G["MAINHANDSLOT"], -- 16 ! Can break
	_G["SECONDARYHANDSLOT"], -- 17 ! Can break
	_G["RANGEDSLOT"], -- 18
	_G["TABARDSLOT"], -- 19
}
local breakableSlots = { -- Items in these slots can break
	[1] = true,
	[3] = true,
	[5] = true,
	[6] = true,
	[7] = true,
	[8] = true,
	[9] = true,
	[10] = true,
	[16] = true,
	[17] = true,
}

local function Debug(text, ...)
	if not db.debugmode then return end

	if text then
		if text:match("%%[dfqsx%d%.]") then
			(DEBUG_CHAT_FRAME or ChatFrame1):AddMessage("|cffff9999"..ADDON_NAME..":|r " .. format(text, ...))
		else
			(DEBUG_CHAT_FRAME or ChatFrame1):AddMessage("|cffff9999"..ADDON_NAME..":|r " .. strjoin(" ", text, tostringall(...)))
		end
	end
end

local function Print(text, ...)
	if text then
		if text:match("%%[dfqs%d%.]") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00".. ADDON_NAME ..":|r " .. format(text, ...))
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00".. ADDON_NAME ..":|r " .. strjoin(" ", text, tostringall(...)))
		end
	end
end

local function formatMoney(money) -- Color codes from Tekkub @ https://gist.github.com/tekkub/44479
	local gold, silver, copper = math.floor(money / 10000), math.floor((money / 100) % 100), money % 100

	local ret = string.format("%d%s%s|r", copper, "|cffeda55f", _G["COPPER_AMOUNT_SYMBOL"])
	if silver > 0 or gold > 0 then
		ret = string.format("%d%s%s|r %s", silver, "|cffc7c7cf", _G["SILVER_AMOUNT_SYMBOL"], ret)
	end
	if gold > 0 then
		return string.format("%d%s%s|r %s", gold, "|cffffd700", _G["GOLD_AMOUNT_SYMBOL"], ret)
	end

	return ret
end

local repairTip
if not C_TooltipInfo then
	repairTip = CreateFrame("GameTooltip", "RepairScanningTooltip", nil, "GameTooltipTemplate")
	repairTip:SetOwner(UIParent, "ANCHOR_NONE")
end

local function optimizeRepairs(guildMoney, isTestRun)
	local function knapSolveFast(v, i, aW, m)
		--[[ This is just modified 0/1 Knapsack Problem solver function		]]
		numcalls = numcalls + 1

		if m[i] and m[i][aW] then
			return m[i][aW], m["picked"][i][aW]
		else
			m[i] = m[i] or {}
			m["picked"][i] = m["picked"][i] or {}

			if i == 0 then
				if v[i] and v[i] <= aW then
					m[i][aW] = v[i]
					m["picked"][i][aW] = { i }

					return v[i], { i }
				else
					m[i][aW] = 0
					m["picked"][i][aW] = {}

					return 0, {}
				end
			end

			local without_i, without_PI = knapSolveFast(v, i - 1, aW, m)
			if v[i] and v[i] > aW then
				m[i][aW] = without_i
				m["picked"][i][aW] = {}

				return without_i, {}
			else
				local with_i, with_PI = knapSolveFast(v, i - 1, aW - v[i], m)
				with_i = with_i + v[i]

				local res, picked
				if with_i > without_i then
					res = with_i
					picked = with_PI
					table.insert(picked, i)
				else
					res = without_i
					picked = without_PI
				end

				m[i][aW] = res
				m["picked"][i][aW] = picked
				
				return res, picked
			end
		end
	end

	numcalls = 0
	local costTable, memoTable = {}, { ["picked"] = {} }
	local countBroken, countRepairs = 0, 0
	local repairTable, repairThese = {}, ""

	for i = 1, 17 do -- Go through equiped items and record repair costs
		if breakableSlots[i] then -- Skip slots with items that cannot break
			local slotCost = 0
			if C_TooltipInfo then
				local hasItem = C_TooltipInfo.GetInventoryItem("Player", i)
				if hasItem then
					slotCost = hasItem.repairCost
				end
			else
				local _, _, slotCost = repairTip:SetInventoryItem("Player", i)
			end

			if isTestRun then
				slotCost = math.random(0, 100000)
			end

			costTable[i] = slotCost
			if slotCost and slotCost > 0 then -- Count items needing repair
				countBroken = countBroken + 1
			end
		else
			costTable[i] = 0
		end
	end

	local optimalCost, pickedItems = knapSolveFast(costTable, #costTable, guildMoney, memoTable)

	for _, v in pairs(pickedItems) do -- "Remove" items which we are going to repair with guild bank withdraws
		costTable[v] = 0
	end

	for k, v in pairs(costTable) do -- Turn optimized items results into a string
		if v and v > 0 then
			countRepairs = countRepairs + 1 -- Count items optimized for player repairs
			repairTable[k] = true
			if countRepairs == 1 then -- First item on the list
				repairThese = "|cffff0000" .. gearSlots[k] .. "|r"
			else -- Rest of the items on the list
				repairThese = repairThese .. ", |cffff0000" .. gearSlots[k] .. "|r"
			end
		end
	end

	Debug("Calls:", numcalls, "Broken/Result:", countBroken, "/", countRepairs, "Picked items: {", table.concat(pickedItems, ", "), "}", "Cost:", formatMoney(optimalCost))
	if countBroken == countRepairs then -- Say ALL if all the items are to be repaired by player
		repairThese = "|cffff0000" .. _G["ALL"] .. "|r" -- "All"
	elseif countRepairs == 0 then -- This shouldn't fire ever outside of testing
		repairThese = "|cffff0000" .. _G["NONE"] .. "|r" -- "None"
	end

	if #pickedItems > 0 then
		return true, optimalCost, repairThese, repairTable
	else
		return false, 0, repairThese, repairTable
	end
end

f:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if (...) ~= ADDON_NAME then return end
		self:UnregisterEvent(event)

		if type(SmartGuildRepairsSettings) ~= "table" then
			SmartGuildRepairsSettings = { debugmode = false, verboselevel = 1 }
		end
		db = SmartGuildRepairsSettings

		self:RegisterEvent("PLAYER_LOGIN")
		self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
		self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

	elseif event == "PLAYER_LOGIN" then
		local function _stringFactory(parent)
			local s = f:CreateFontString(nil, "OVERLAY", "SystemFont_OutlineThick_Huge2") --"Fancy18Font") --"GameFontNormalOutline")
			s:SetPoint("BOTTOMLEFT", parent, 1, 1)

			return s
		end

		self:UnregisterEvent(event)

		f:SetFrameLevel(_G.CharacterHeadSlot:GetFrameLevel())

		f[1] = _stringFactory(_G.CharacterHeadSlot)
		f[2] = _stringFactory(_G.CharacterNeckSlot)
		f[3] = _stringFactory(_G.CharacterShoulderSlot)
		f[15] = _stringFactory(_G.CharacterBackSlot)
		f[5] = _stringFactory(_G.CharacterChestSlot)
		f[9] = _stringFactory(_G.CharacterWristSlot)

		f[10] = _stringFactory(_G.CharacterHandsSlot)
		f[6] = _stringFactory(_G.CharacterWaistSlot)
		f[7] = _stringFactory(_G.CharacterLegsSlot)
		f[8] = _stringFactory(_G.CharacterFeetSlot)
		f[11] = _stringFactory(_G.CharacterFinger0Slot)
		f[12] = _stringFactory(_G.CharacterFinger1Slot)
		f[13] = _stringFactory(_G.CharacterTrinket0Slot)
		f[14] = _stringFactory(_G.CharacterTrinket1Slot)

		f[16] = _stringFactory(_G.CharacterMainHandSlot)
		f[17] = _stringFactory(_G.CharacterSecondaryHandSlot)

	elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
		if (...) ~= Enum.PlayerInteractionType.Merchant then return end -- 5
		if not CanMerchantRepair() then return end
		if not (IsInGuild() and CanGuildBankRepair()) then return end

		local totalCost, needRepair = GetRepairAllCost()
		if needRepair then
			local guildMoney = GetGuildBankWithdrawMoney()
			if guildMoney == (guildMoney - 1) then -- Withdraw limit is "infinite", set new limit (smaller than 2^64)
				guildMoney = GetGuildBankMoney()
			end
			if guildMoney >= totalCost then
				RepairAllItems(1)
				if db.verboselevel >= 1 then
					Print(L.RepairedWithGuildMoney, formatMoney(totalCost), formatMoney(guildMoney - totalCost))
				end
			elseif guildMoney > 0 then
				local solution, optimalCost, repairThese, repairTable = optimizeRepairs(guildMoney)

				if solution then
					if db.verboselevel == 2 then
						Debug("Optimal:", math.floor((optimalCost / guildMoney) * 100 + 0.5), (optimalCost / guildMoney) * 100 + 0.5)
						Print(L.OptimalSolutionFound, formatMoney(optimalCost), math.floor((optimalCost / guildMoney) * 100 + 0.5))
					end

					Debug("RegisterEvent")
					registered = true
					self:RegisterEvent("UPDATE_INVENTORY_DURABILITY")

					for i = 1, 17 do
						if breakableSlots[i] and repairTable[i] then
							--f[i]:SetText("|TInterface\\MerchantFrame\\UI-Merchant-RepairIcons:0:0:0:0:128:64:4:32:4:32|t")
							f[i]:SetText("|cffff0000"..L.RepairThis.."|r")
						else
							f[i]:SetText("")
						end
					end
				elseif db.verboselevel == 2 then
					Print(L.NoSolutions)
				end

				if db.verboselevel >= 1 then
					Print(L.RepairTheseManually, repairThese)
				end
			elseif db.verboselevel == 2 then
				Print(L.NoSolutions)
			end
		else
			if db.verboselevel >= 1 then
				Print(L.NoNeedForRepairs)
			end
		end

	elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
		if (...) ~= Enum.PlayerInteractionType.Merchant then return end -- 5
		if not registered then return end

		Debug("UnregisterEvent")
		registered = false
		self:UnregisterEvent("UPDATE_INVENTORY_DURABILITY")
		for i = 1, 17 do
			if breakableSlots[i] then
				f[i]:SetText("")
			end
		end

	elseif event == "UPDATE_INVENTORY_DURABILITY" then
		if not CanMerchantRepair() then return end
		if not (IsInGuild() and CanGuildBankRepair()) then return end

		for i = 1, 17 do
			if breakableSlots[i] and f[i]:GetText() ~= "" then
				local slotCost = 0
				local hasItem = C_TooltipInfo.GetInventoryItem("Player", i)
				if hasItem then
					slotCost = hasItem.repairCost
				end

				if not slotCost or slotCost == 0 then
					f[i]:SetText("")
				end
			end
		end

		local totalCost, needRepair = GetRepairAllCost()
		if needRepair then
			local guildMoney = GetGuildBankWithdrawMoney()
			if guildMoney >= totalCost then
				RepairAllItems(1)
				if db.verboselevel >= 1 then
					Print(L.RepairedWithGuildMoney, formatMoney(totalCost), formatMoney(guildMoney - totalCost))
				end
			end
		end

	end
end)
f:RegisterEvent("ADDON_LOADED")

SLASH_SMARTGUILDREPAIRS1 = "/smartguildrepairs"
SLASH_SMARTGUILDREPAIRS2 = "/srep"

SlashCmdList.SMARTGUILDREPAIRS = function(...)
	if (...) == "silent" then
		db.verboselevel = 0
		Print(L.VerboseLevelSet, L.Silent)
	elseif (...) == "normal" then
		db.verboselevel = 1
		Print(L.VerboseLevelSet, L.Normal)
	elseif (...) == "full" then
		db.verboselevel = 2
		Print(L.VerboseLevelSet, L.Full)
	elseif (...) == "debug" then
		db.debugmode = not db.debugmode
		Print("Debug:", (db.debugmode and "|cff00ff00true|r" or "|cffff0000false|r"))
	elseif (...) == "test" then
		Print("Test:")
		local testMoney = _G.GetMoney()
		while testMoney > 10000 do
			local solution, optimalCost, repairThese, repairTable = optimizeRepairs(testMoney, true)
			Print("\nSolution: %s (%s) \noptimalCost: %s (%d%%) \nrepairThese: %s", (solution) and "True" or "False", formatMoney(testMoney), formatMoney(optimalCost), math.floor((optimalCost / testMoney) * 100 + 0.5), repairThese)
			testMoney = math.floor(testMoney / 10)
		end
	else
		Print(L.Help, L.psilent, L.pnormal, L.pfull)
		Print(L.VerboseLevelIs, (db.verboselevel == 0 and L.Silent or (db.verboselevel == 1 and L.Normal or L.Full)))
	end
end