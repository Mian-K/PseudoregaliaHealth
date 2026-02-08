
--Config
--- Reset Total Health Hotkey:
local hotKey = Key.F2
local modifierKeys = {} -- Valid: { SHIFT, CONTROL, ALT }, comma seperated
--- SaveFile
local enemySaveFile = "UE4SS/Mods/PseudoregaliaHealth/Saves/Enemies.txt"



--Namespaces
local UEHelpers = require("UEHelpers")
local Utils = require("Utils")

--Constants
local MAX_HEALTH = 1000000000.0
local MAP_NAME = "mapName_4_423D13C74469858B6E9893BEB6ABFBBB"
local ENEMY_NAMES = {
	{ class = "BP_Enemy__WalkinEgg_C", name = "Egg" },
	{ class = "BP_Hazemy_WardHand_C", name = "Hand" },
	{ class = "BP_Enemy_Maid_C", name = "Maid" },
	{ class = "BP_PrincessBoss_C", name = "Princess" },
	{ class = "BP_EnemyJumper_C", name = "Sword" },
	{ class = "BP_Enemy_Statue_C", name = "Statue" },
	{ class = "BP_Enemy_Keeper_C", name = "Strong Eyes" },
	{ class = "BP_Enemy_Horn_C", name = "Trumpet" },
	{ class = "BP_hazemy_WheelCrawler_C", name = "Wheel" }
}

--Variables
local lastHP = 0
local damageTimestamps = {}
local totalDamage = 0.0
local healthIndex = 1
local doReset = false
local toHeal = 0
local focusedEnemies = {}
local areaEnemies = {}
local enemyIndex = 1
local menuIndex = 1
local menuOption = 1
local menuVariant = 1
local infiniteHP = {}
local currentArea = ""

---@type UUserWidget?
local playerHealthWidget = nil
local enemyHealthWidget = nil

Utils.RegisterKey("Reset Total", function() doReset = true; totalDamage = 0.0 end, hotKey, modifierKeys)
Utils.RegisterKey("Menu Up", function() menuUp() end, Key.UP_ARROW,{})
Utils.RegisterKey("Menu Down", function() menuDown() end, Key.DOWN_ARROW,{})
Utils.RegisterKey("Menu Left", function() menuLeft() end, Key.LEFT_ARROW,{})
Utils.RegisterKey("Menu Right", function() menuRight() end, Key.RIGHT_ARROW,{})
Utils.RegisterKey("Menu Back", function() menuBack() end, Key.BACKSPACE,{})
Utils.RegisterKey("Menu Enter", function() menuEnter() end, Key.RETURN,{})

function menuDown()
	if menuVariant == 1 then menuIndex = menuIndex % 5 + 1 end
	if menuVariant == 2 then enemyIndex = enemyIndex + 1 end
end
function menuUp()
	if menuVariant == 1 then menuIndex = (menuIndex + 3) % 5 + 1 end
	if menuVariant == 2 then enemyIndex = enemyIndex - 1 end
end
function menuLeft()
	if menuVariant == 1 then menuOption = (menuOption + 4) % 6 + 1 end
end
function menuRight()
	if menuVariant == 1 then menuOption = menuOption % 6 + 1 end
end
function menuBack()
	if menuVariant == 1 then
		focusedEnemies[currentArea][menuIndex] = { name = nil, index = nil }
	end
	if menuVariant == 2 then menuVariant = 1 end
end
function menuEnter()
	if menuVariant == 1 then
		if menuOption == 1 then
			if focusedEnemies[currentArea][menuIndex].name ~= nil then
				enemy = focusedEnemies[currentArea][menuIndex].name
				infiniteHP[enemy] = not infiniteHP[enemy]
			end
		end
		if menuOption == 2 then SaveEnemyTargetsToFile(false) end
		if menuOption == 3 then LoadEnemyTargetsFromFile(false) end
		if menuOption == 4 then SaveEnemyTargetsToFile(true) end
		if menuOption == 5 then LoadEnemyTargetsFromFile(true) end
		if menuOption == 6 then
			enemyIndex = focusedEnemies[currentArea][menuIndex].index or 1
			menuVariant = 2
		end
	elseif menuVariant == 2 then
		if #areaEnemies >= enemyIndex then
			focusedEnemies[currentArea][menuIndex] = { name = areaEnemies[enemyIndex].name, index = enemyIndex}
		end
		menuVariant = 1
	end
end

---@param full bool -- default = true
function LoadEnemyTargetsFromFile(full)
	if full == nil then full = true end
	local File = io.open(enemySaveFile, "r")
	if File == nil then
		print("Nil")
	else
		for line in File:lines() do
			local area = string.match(line, "Area=([A-Za-z0-9_]+)")
			local enemies = {
				string.match(line, "enemy_1=([A-Za-z0-9_]+)"),
				string.match(line, "enemy_2=([A-Za-z0-9_]+)"),
				string.match(line, "enemy_3=([A-Za-z0-9_]+)"),
				string.match(line, "enemy_4=([A-Za-z0-9_]+)"),
				string.match(line, "enemy_5=([A-Za-z0-9_]+)"),
			}
			if (full or area == currentArea) and area ~= nil then  
				focusedEnemies[area] = {
					{name = enemies[1], index = nil},
					{name = enemies[2], index = nil},
					{name = enemies[3], index = nil},
					{name = enemies[4], index = nil},
					{name = enemies[5], index = nil}
				}
			end
		end 
		File:close()
	end
end
---@param full bool -- default = true
function SaveEnemyTargetsToFile(full)
	if full == nil then full = true end
	local saveText = ""
	if not full then 
		local oldFile = io.open(enemySaveFile, "r")
		for line in oldFile:lines() do
			local area = string.match(line, "Area=([A-Za-z0-9_]+)")
			if area ~= currentArea then
				saveText = saveText .. line .. "\n"
			end
		end
	end
			
	for area,enemies in pairs(focusedEnemies) do
		if full or area == currentArea then
			saveText = saveText .. "Area=" .. area
			for i,enemy in ipairs(enemies) do
				if enemy.name ~= nil then
					saveText = saveText .. " :: enemy_".. i .. "=" .. enemy.name
				end
			end
			saveText = saveText .. "\n"
		end
	end
	print(saveText)
	local File = io.open(enemySaveFile, "w+")
	File:write(saveText)
	File:close()
end

-- Pre-load Save File
LoadEnemyTargetsFromFile()

LoopAsync(100, function()
	for i = 1, 100 do
		if damageTimestamps[i] ~= nil and os.difftime(os.time(), damageTimestamps[i].timestamp) > 10 then
			toHeal = toHeal + damageTimestamps[i].damage
			damageTimestamps[i] = nil
		end
	end
	
	local PlayerController = Utils.hook_PlayerController(true)
	local GameInstance = Utils.hook_GameInstance(true)
	local hpBox = FindObjects(nil,"HorizontalBox","hpBox")
	local lockonTarget = ""
	areaEnemies = {}
	
	if PlayerController ~= nil and GameInstance ~= nil then
		local currentHP = PlayerController.Pawn.BP_HPHitable["CurrentHp"]
		if type(currentHP) == "number" then
			local recentDamage = 0
			if currentHP <= MAX_HEALTH / 1000 or doReset then
				PlayerController.Pawn.BP_HPHitable.CurrentHp = MAX_HEALTH
				PlayerController.Pawn.BP_HPHitable.maxHP = MAX_HEALTH * 2
				lastHP = MAX_HEALTH
				damageTimestamps = {}
				doReset = false
				print("Reset to Max HP")
			else
				if lastHP > currentHP then
					totalDamage = totalDamage + lastHP - currentHP
				end
				if lastHP ~= currentHP then
					damageTimestamps[healthIndex] = { timestamp = os.time(), damage = lastHP - currentHP }
					healthIndex = healthIndex % 100 + 1 
				end
				if toHeal > 0 then
					currentHP = currentHP + toHeal
					PlayerController.Pawn.BP_HPHitable.CurrentHp = currentHP
					toHeal = 0
				end
				lastHP = currentHP
				recentDamage = MAX_HEALTH - currentHP
			end
			if GameInstance ~= nil then
				for _,Box in pairs(hpBox) do
					Box:ClearChildren()
				end
				
				currentArea = GameInstance.activeZoneStr[MAP_NAME]:ToString()
				if currentArea == "Zone_Tower" then
					menuVariant = 1
				end
				areaEnemies = {}
				local enemyListByClass = {}
				for _,class in ipairs(ENEMY_NAMES) do
					enemyListByClass[class.name] = {}
				end
				local enemies = FindAllOf("BP_EnemyBase_C") or {}
				local hazards = FindAllOf("BP_Hazemy_Base_C") or {}
				for _,enemy in ipairs(enemies) do
					local fullName = enemy:GetFullName()
					local className = string.match(fullName,("%S+"))
					if fullName ~= nil then
						local class
						for i=1,#ENEMY_NAMES do
							if ENEMY_NAMES[i].class == className then
								class = ENEMY_NAMES[i].name
							end
						end
						if class ~= nil then
							local name = enemy:GetFName():ToString()
							local maxHP = enemy.BP_HpHitable.maxHP
							if infiniteHP[name] == nil then infiniteHP[name] = false end
							if infiniteHP[name] then
								enemy.BP_HpHitable.currentHP = MAX_HEALTH
							elseif enemy.BP_HpHitable.currentHP > maxHP then
								enemy.BP_HpHitable.currentHP = maxHP
							end
							enemyListByClass[class][#enemyListByClass[class] + 1] = {name = name, enemy = enemy, class = class, count = #enemyListByClass[class] + 1, maxHP = maxHP}
						end
					end
				end
				for _,enemy in ipairs(hazards) do
					local fullName = enemy:GetFullName()
					local className = string.match(fullName,("%S+"))
					if fullName ~= nil then
						local class
						for i=1,#ENEMY_NAMES do
							if ENEMY_NAMES[i].class == className then
								class = ENEMY_NAMES[i].name
							end
						end
						if class ~= nil then
							local name = enemy:GetFName():ToString()
							local maxHP = enemy.BP_HpHitable.maxHP
							if infiniteHP[name] == nil then infiniteHP[name] = false end
							if infiniteHP[name] then
								enemy.BP_HpHitable.currentHP = MAX_HEALTH
							elseif enemy.BP_HpHitable.currentHP > maxHP then
								enemy.BP_HpHitable.currentHP = maxHP
							end
							enemyListByClass[class][#enemyListByClass[class] + 1] = {name = name, enemy = enemy, class = class, count = #enemyListByClass[class] + 1, maxHP = maxHP}
						end
					end
				end
				if PlayerController.Pawn.lockedOn == true then
					lockonTarget = PlayerController.Pawn.LocketActorTarget:GetFName():ToString()
				end
				for _,class in ipairs(ENEMY_NAMES) do
					for _,enemy in ipairs(enemyListByClass[class.name]) do
						areaEnemies[#areaEnemies + 1] = enemy
						if lockonTarget == areaEnemies[#areaEnemies].name then
							enemyIndex = #areaEnemies
						end
						if focusedEnemies[currentArea] ~= nil then
							for _,focus in ipairs(focusedEnemies[currentArea]) do
								if enemy ~= nil then 
									if focus.name == enemy.name then
										focus.index = #areaEnemies
									end
								end
							end
						end
					end
				end
				if focusedEnemies[currentArea] == nil then
					focusedEnemies[currentArea] = {}
					for i=1,5 do
						local tempEnemy = { name = nil, index = nil }
						if areaEnemies[i] ~= nil then
							tempEnemy = { name = areaEnemies[i].name, index = i}
						end
						focusedEnemies[currentArea][i] = tempEnemy
					end
				end
				--UserWidget
				---WidgetTree
				----Border
				-----BorderSlot
				------TextBlock
				
				if playerHealthWidget == nil then
				---@type UUserWidget
					playerHealthWidget = FindFirstOf("PseudoregaliaHealth_Player_Display")
				end
				if not playerHealthWidget:IsValid() then
					playerHealthWidget = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), GameInstance, FName("PseudoregaliaHealth_Player_Display"))
					if not playerHealthWidget:IsValid() then
						print("Error creating Player Health Display...\n")
						return
					end
				end
				if playerHealthWidget.WidgetTree == nil or not playerHealthWidget.WidgetTree:IsValid() then	
					playerHealthWidget.WidgetTree = StaticConstructObject(StaticFindObject("/Script/UMG.WidgetTree"), playerHealthWidget, FName("PseudoregaliaHealth_Player_Tree"))
					if not playerHealthWidget.WidgetTree:IsValid() then
						print("Error creating Player Health Display Tree...\n")
						return
					end
				end
				if playerHealthWidget.WidgetTree.RootWidget == nil or not playerHealthWidget.WidgetTree.RootWidget:IsValid() then
					playerHealthWidget.WidgetTree.RootWidget = StaticConstructObject(StaticFindObject("/Script/UMG.Border"), playerHealthWidget.WidgetTree, FName("PseudoregaliaHealth_Player_Border"))
					if not playerHealthWidget.WidgetTree.RootWidget:IsValid() then
						print("Error creating Player Health Display Border...\n")
						return
					end
				end
				if playerHealthWidget.WidgetTree.RootWidget.Slots[1] == nil or not playerHealthWidget.WidgetTree.RootWidget.Slots[1]:IsValid() then
					playerHealthWidget.WidgetTree.RootWidget.Slots[1] = StaticConstructObject(StaticFindObject("/Script/UMG.BorderSlot"), playerHealthWidget.WidgetTree.RootWidget, FName("PseudoregaliaHealth_Player_BorderSlot"))
					if not playerHealthWidget.WidgetTree.RootWidget.Slots[1]:IsValid() then
						print("Error creating Player Health Display BorderSlot...\n")
						return
					end
				end
				if playerHealthWidget.WidgetTree.RootWidget.Slots[1].Content == nil or not playerHealthWidget.WidgetTree.RootWidget.Slots[1].Content:IsValid() then
					playerHealthWidget.WidgetTree.RootWidget.Slots[1].Content = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), playerHealthWidget.WidgetTree.RootWidget.Slots[1], FName("PseudoregaliaHealth_Player_Display_Text"))
					if not playerHealthWidget.WidgetTree.RootWidget.Slots[1].Content:IsValid() then
						print("Error creating Player Health Display Text...\n")
						return
					end
				end
				
				if enemyHealthWidget == nil then
				---@type UUserWidget
					enemyHealthWidget = FindFirstOf("PseudoregaliaHealth_Player_Display")
				end
				if not enemyHealthWidget:IsValid() then
					enemyHealthWidget = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), GameInstance, FName("PseudoregaliaHealth_Enemy_Display"))
					if not enemyHealthWidget:IsValid() then
						print("Error creating Enemy Health Display...\n")
						return
					end
				end
				if enemyHealthWidget.WidgetTree == nil or not enemyHealthWidget.WidgetTree:IsValid() then
					enemyHealthWidget.WidgetTree = StaticConstructObject(StaticFindObject("/Script/UMG.WidgetTree"), enemyHealthWidget, FName("PseudoregaliaHealth_Enemy_Tree"))
					if not enemyHealthWidget.WidgetTree:IsValid() then
						print("Error creating Enemy Health Display Tree...\n")
						return
					end
				end
				if enemyHealthWidget.WidgetTree.RootWidget == nil or not enemyHealthWidget.WidgetTree.RootWidget:IsValid() then
					enemyHealthWidget.WidgetTree.RootWidget = StaticConstructObject(StaticFindObject("/Script/UMG.Border"), enemyHealthWidget.WidgetTree, FName("PseudoregaliaHealth_Enemy_Border"))
					if not enemyHealthWidget.WidgetTree.RootWidget:IsValid() then
						print("Error creating Enemy Health Display Border...\n")
						return
					end
				end
				if enemyHealthWidget.WidgetTree.RootWidget.Slots[1] == nil or not enemyHealthWidget.WidgetTree.RootWidget.Slots[1]:IsValid() then
					enemyHealthWidget.WidgetTree.RootWidget.Slots[1] = StaticConstructObject(StaticFindObject("/Script/UMG.BorderSlot"), enemyHealthWidget.WidgetTree.RootWidget, FName("PseudoregaliaHealth_Enemy_BorderSlot"))
					if not enemyHealthWidget.WidgetTree.RootWidget.Slots[1]:IsValid() then
						print("Error creating Enemy Health Display BorderSlot...\n")
						return
					end
				end
				if enemyHealthWidget.WidgetTree.RootWidget.Slots[1].Content == nil or not enemyHealthWidget.WidgetTree.RootWidget.Slots[1].Content:IsValid() then
					enemyHealthWidget.WidgetTree.RootWidget.Slots[1].Content = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), enemyHealthWidget.WidgetTree.RootWidget.Slots[1], FName("PseudoregaliaHealth_Enemy_Display_Text"))
					if not enemyHealthWidget.WidgetTree.RootWidget.Slots[1].Content:IsValid() then
						print("Error creating Enemy Health Display Text...\n")
						return
					end
				end
				
				local playerText = "Total Damage: " .. totalDamage /10 .. "\nRecent Damage: " .. recentDamage /10
				
				
				local enemyText = ""
				if menuVariant == 1 then
					if currentArea == "Zone_Tower" then
						enemyText = "\n\n        No Enemies in Area\n\n\n =========================================\n"
					else
						for i=1,5 do
							local line = "  "
							if i == menuIndex then line = ">" end
							if focusedEnemies[currentArea][i] ~= nil then
								if areaEnemies[focusedEnemies[currentArea][i].index] ~= nil then
									local enemy = areaEnemies[focusedEnemies[currentArea][i].index]
									local name = enemy.class .. " - " .. enemy.count
									local maxHP = enemy.maxHP
									local currentHP = 0
									local attack = "None"
									if enemy.enemy:IsValid() then
										currentHP = enemy.enemy.BP_HpHitable.CurrentHp
										attack = enemy.enemy.activeAttackID
									end
									if infiniteHP[focusedEnemies[currentArea][i].name] then
										currentHP = "∞"
									end
									
									line = line .. name .. ", HP = " .. currentHP .. "/" .. maxHP .. ", Attack = " .. attack
								end
							end
							enemyText = enemyText .. line .."\n"
						end
						enemyText = enemyText .. " =========================================\n"
					end
					if menuOption == 1 then enemyText = enemyText .. "{ >" else enemyText = enemyText .. "{   " end
					optionInfinite = "[  ]"
					if focusedEnemies[currentArea][menuIndex].name ~= nil then
						if infiniteHP[focusedEnemies[currentArea][menuIndex].name] then optionInfinite = "[x]" end
					end
					enemyText = enemyText .. optionInfinite .. "Invincible"
					if menuOption <= 3 then 
						enemyText = enemyText .. " | Area:"
						if menuOption == 2 then enemyText = enemyText .. ">" else enemyText = enemyText .. "  " end
						enemyText = enemyText .. "Save "
						if menuOption == 3 then enemyText = enemyText .. ">" else enemyText = enemyText .. "  " end
						enemyText = enemyText .. "Load [->]| "
					else
						enemyText = enemyText .. " |[<-] Total:"
						if menuOption == 4 then enemyText = enemyText .. ">" else enemyText = enemyText .. "  " end
						enemyText = enemyText .. "Save "
						if menuOption == 5 then enemyText = enemyText .. ">" else enemyText = enemyText .. "  " end
						enemyText = enemyText .. "Load | "
					end
					if menuOption == 6 then enemyText = enemyText .. ">" else enemyText = enemyText .. "  " end
					enemyText = enemyText .. "Enemy Select... }"
				elseif menuVariant == 2 then
					enemyIndex = (enemyIndex + #areaEnemies - 1) % #areaEnemies + 1
					local min = enemyIndex - 2
					if min < 1 then min = 1 end
					local max = min + 4
					if min > 1 and max > #areaEnemies then
						max = #areaEnemies
						min = max - 4
					end
					local tableIndex = 0
					local lineIndex = 1
					for name,enemy in pairs(areaEnemies) do
						tableIndex = tableIndex + 1
						if tableIndex < min then goto continue end
						local line = "  "
						if tableIndex == enemyIndex then line = ">" end 
						enemyText = enemyText .. line .. enemy.class .. " - " .. enemy.count .. "\n"
						lineIndex = lineIndex + 1
						if lineIndex > 5 then break end
						::continue::
					end
					while lineIndex <= 5 do
						lineIndex = lineIndex + 1
						enemyText = enemyText .. "\n"
					end
					enemyText = enemyText .. " =========================================\nEnter > Confirm | Backspace > Cancel | Lockon > Select"
				else
					enemyText = enemyText .. "\n\n\n\n\n =========================================\nEnter > Confirm | Backspace > Cancel | Lockon > Jump"
				end
				
				playerHealthWidget.WidgetTree.RootWidget.Slots[1].Content:SetText(FText(playerText))
				playerHealthWidget.WidgetTree.RootWidget.Background.TintColor.SpecifiedColor = {R=0,G=0,B=0,A=0.4}
				playerHealthWidget:SetPositionInViewport(Utils.FVector2D(350, 10), false)
				playerHealthWidget:AddToViewport(99)
				
				enemyHealthWidget.WidgetTree.RootWidget.Slots[1].Content:SetText(FText(enemyText))
				enemyHealthWidget.WidgetTree.RootWidget.Slots[1].Content.Font.Size = 15
				enemyHealthWidget.WidgetTree.RootWidget.Background.TintColor.SpecifiedColor = {R=0,G=0,B=0,A=0.4}
				enemyHealthWidget:SetPositionInViewport(Utils.FVector2D(1405, 900), false)
				enemyHealthWidget:AddToViewport(99)
			end
		end
	end
end)

