
--Config
--- Reset Total Health Hotkey:
local hotKey = Key.F2
local modifierKeys = {} -- Valid: { SHIFT, CONTROL, ALT }, comma separated

--Namespaces
local Utils = require("Utils")

--Constants
local MAX_HEALTH = 1000000000.0
local ENEMY_CLASS  = "/Game/Blueprints/Enemies/BP_EnemyBase.BP_EnemyBase_C"
local HAZEMY_CLASS = "/Game/Blueprints/Enemies/NoAI_Enemies/BP_Hazemy_Base.BP_Hazemy_Base_C"
local PLAYERPAWN_CLASS = "/Game/ThirdPerson/Player/BP_PlayerGoatMain.BP_PlayerGoatMain_C"
local ENEMY_NAMES = {
	BP_Enemy__WalkinEgg_C = "Egg",
	BP_Hazemy_WardHand_C = "Hand",
	BP_Enemy_Maid_C = "Maid",
	BP_PrincessBoss_C = "Princess",
	BP_EnemyJumper_C = "Sword",
	BP_Enemy_Statue_C = "Statue",
	BP_Enemy_Keeper_C = "Strong Eyes",
	BP_Enemy_Horn_C = "Trumpet",
	BP_hazemy_WheelCrawler_C = "Wheel"
}
local ENEMY_CLASS_ORDERED = {
	"BP_Enemy__WalkinEgg_C",
	"BP_Hazemy_WardHand_C",
	"BP_Enemy_Maid_C",
	"BP_PrincessBoss_C",
	"BP_EnemyJumper_C",
	"BP_Enemy_Statue_C",
	"BP_Enemy_Keeper_C",
	"BP_Enemy_Horn_C",
	"BP_hazemy_WheelCrawler_C"
}
local MENU = {
	ERROR = -1,
	NO_ENEMY = 0,
	FOCUSED_ENEMIES = 1,
	ENEMY_LIST = 2,
	MINIATURE = 3
}

-- SaveFile
local enemySaveFile = (string.match((debug.getinfo(1, "S").source:sub(2)), "Win64\\(.-)Scripts") or "Mods\\PseudoregaliaHealth") .. "\\Saves\\Enemies.txt"

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
local menuVariant = MENU.MINIATURE
local saveVariantAll = true
local infiniteHP = {}
local currentArea = ""
local skip = 0

--Cache
local enemies = {area={class={name={ref_entity = nil,ref_health = nil,max_hp = 0,current_hp = 0,attack_id = 0,display_name = ""}}}}
local playerPawn = {ref_entity=nil,ref_health=nil,current_hp=0}

---@type UUserWidget?
local playerHealthWidget = nil
local enemyHealthWidget = nil

function addEntity(refHealth)
	local refEntity = refHealth:GetOwner()
	
	if refEntity:IsA(ENEMY_CLASS) or refEntity:IsA(HAZEMY_CLASS) then
		local class = refEntity:GetClass():GetFName():ToString() ---@type string
		if ENEMY_NAMES[class] == nil then return end
		currentArea = refEntity:GetWorld():GetFName():ToString() ---@type string
		local name = refEntity:GetFName():ToString() ---@type string
		if enemies[currentArea] == nil then enemies[currentArea] = {} end
		if enemies[currentArea][class] == nil then enemies[currentArea][class] = {count = 0} end
		
		enemies[currentArea][class][#enemies[currentArea][class] + 1] = {
			name = name,
			ref_entity = refEntity,
			ref_health = refHealth,
			max_hp = refHealth.maxHP,
			current_hp = 0,
			attack_id = 0,
			display_name = (ENEMY_NAMES[class] or "ERROR-ERROR-ERROR") .. " " .. #enemies[currentArea][class]
		}
		--print(class .. " : " .. enemies[currentArea][class][#enemies[currentArea][class]].display_name)
		return
	elseif refEntity:IsA(PLAYERPAWN_CLASS) then
		playerPawn = {
			ref_entity = refEntity,
			ref_health = refHealth,
			current_hp = 0
		}
	end
end
function removeVanillaHealth()
	for _,Box in ipairs(FindObjects(nil,"HorizontalBox","hpBox") or {}) do
		Box:ClearChildren()
	end
end
NotifyOnNewObject("/Game/Blueprints/BP_HpHitable.BP_HpHitable_C", addEntity)
for _,refHealth in ipairs(FindAllOf("BP_HpHitable_C") or {}) do
	addEntity(refHealth)
end

_ = RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(Context)
	currentArea = Context:get():GetWorld():GetFName():ToString()
	if enemies[currentArea] == nil then return end
	for _,class in pairs(enemies[currentArea]) do
		class = {}
	end
	removeVanillaHealth()
end)
removeVanillaHealth()

function isOption(option, isTrue, isFalse)
	if option then return isTrue end
	return isFalse
end

function menuDown()
	if menuVariant == MENU.FOCUSED_ENEMIES then menuIndex = menuIndex % 5 + 1 end
	if menuVariant == MENU.ENEMY_LIST then enemyIndex = enemyIndex + 1 end
end
function menuUp()
	if menuVariant == MENU.FOCUSED_ENEMIES then menuIndex = (menuIndex + 3) % 5 + 1 end
	if menuVariant == MENU.ENEMY_LIST then enemyIndex = enemyIndex - 1 end
end
function menuLeft()
	if menuVariant == MENU.FOCUSED_ENEMIES then menuOption = (menuOption + 4) % 6 + 1 end
end
function menuRight()
	if menuVariant == MENU.FOCUSED_ENEMIES then menuOption = menuOption % 6 + 1 end
end
function menuBack()
	if menuVariant == MENU.FOCUSED_ENEMIES and focusedEnemies[currentArea] ~= nil then
		focusedEnemies[currentArea][menuIndex] = { name = nil, index = nil }
	else menuVariant = MENU.FOCUSED_ENEMIES end
end
function menuEnter()
	if menuVariant == MENU.NO_ENEMY then
		menuVariant = MENU.MINIATURE
	elseif menuVariant == MENU.FOCUSED_ENEMIES then
		if menuOption == 1 and focusedEnemies[currentArea] ~= nil then
			if focusedEnemies[currentArea][menuIndex].name ~= nil then
				local enemy = focusedEnemies[currentArea][menuIndex].name
				infiniteHP[enemy] = not infiniteHP[enemy]
			end
		end
		if menuOption == 2 then
			enemyIndex = focusedEnemies[currentArea][menuIndex].index or 1
			menuVariant = 2
		end
		if menuOption == 3 then saveVariantAll = not saveVariantAll end
		if menuOption == 4 then SaveEnemyTargetsToFile(saveVariantAll) end
		if menuOption == 5 then LoadEnemyTargetsFromFile(saveVariantAll) end
		if menuOption == 6 then menuVariant = 3 end
	elseif menuVariant == MENU.ENEMY_LIST then
		if #areaEnemies >= enemyIndex then
			focusedEnemies[currentArea][menuIndex] = { name = areaEnemies[enemyIndex].name, index = enemyIndex}
		end
		menuVariant = MENU.FOCUSED_ENEMIES
	elseif menuVariant == MENU.MINIATURE then
		menuVariant = MENU.FOCUSED_ENEMIES
	end
end

---@param full bool -- default = true
function LoadEnemyTargetsFromFile(full)
	if full == nil then full = true end
	local File = io.open(enemySaveFile, "r")
	if File == nil then
		print("Nil File: " .. enemySaveFile)
	else
		for line in File:lines() do
			local area = string.match(line, "Area=([A-Za-z0-9_]+)")
			local focus = {
				string.match(line, "enemy_1=([A-Za-z0-9_]+)"),
				string.match(line, "enemy_2=([A-Za-z0-9_]+)"),
				string.match(line, "enemy_3=([A-Za-z0-9_]+)"),
				string.match(line, "enemy_4=([A-Za-z0-9_]+)"),
				string.match(line, "enemy_5=([A-Za-z0-9_]+)"),
			}
			if (full or area == currentArea) and area ~= nil then
				focusedEnemies[area] = {
					{name = focus[1], index = nil},
					{name = focus[2], index = nil},
					{name = focus[3], index = nil},
					{name = focus[4], index = nil},
					{name = focus[5], index = nil}
				}
			end
		end
		File:close()
	end
end
---@param full bool -- default = true
function SaveEnemyTargetsToFile(full)
	local  saveText = ""
	if full == nil then full = true end
	if not full then
		local oldFile = io.open(enemySaveFile, "r")
		for line in oldFile:lines() do
			local area = string.match(line, "Area=([A-Za-z0-9_]+)")
			if area ~= currentArea then
				saveText = saveText .. line .. "\n"
			end
		end
	end
	
	for area,focus in pairs(focusedEnemies) do
		if full or area == currentArea then
			saveText = saveText .. "Area=" .. area
			for i,enemy in ipairs(focus) do
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

-- Preload Save File
LoadEnemyTargetsFromFile()

--local LoopHandle = LoopInGameThreadAfterFrames(10, function()
local _ = LoopInGameThreadWithDelay(100, function()
--LoopAsync(100, function()
	for i = 1, 100 do
		if damageTimestamps[i] ~= nil and os.difftime(os.time(), damageTimestamps[i].timestamp) > 10 then
			toHeal = toHeal + damageTimestamps[i].damage
			damageTimestamps[i] = nil
		end
	end
	
	local lockonTarget = ""
	areaEnemies = {}
	
	if playerPawn.ref_entity ~= nil and playerPawn.ref_health ~= nil then
		if playerPawn.ref_entity:IsValid() and playerPawn.ref_health:IsValid() then
			currentArea = playerPawn.ref_entity:GetWorld():GetFName():ToString()
			
			local currentHP = playerPawn.ref_health.CurrentHp
			if type(currentHP) == "number" then
				local recentDamage = 0
				if currentHP <= MAX_HEALTH / 1000 or doReset then
					playerPawn.ref_health.CurrentHp = MAX_HEALTH
					playerPawn.ref_health.maxHP = MAX_HEALTH * 2
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
						playerPawn.ref_health.CurrentHp = currentHP
						toHeal = 0
					end
					lastHP = currentHP
					recentDamage = MAX_HEALTH - currentHP
				end
				
				
				local enemies_exist = false
				if enemies[currentArea] ~= nil then
					for class,enemiesInClass in pairs(enemies[currentArea]) do
						for _,enemy in ipairs(enemiesInClass) do
							if enemy ~= nil and type(enemy) == "table" then
								if enemy.ref_entity:IsValid() and enemy.ref_health:IsValid() then
									enemies_exist = true
									goto skip
								end
							end
						end
					end
				end
				::skip::
				if not enemies_exist then
					if menuVariant ~= MENU.MINIATURE then menuVariant = MENU.NO_ENEMY end
				else
					if menuVariant == MENU.NO_ENEMY then
						menuVariant = MENU.FOCUSED_ENEMIES
					end
					
					--print("\nEnemies\n")
					for class, enemiesInClass in pairs(enemies[currentArea]) do
						for _,enemy in ipairs(enemiesInClass) do
							if enemy ~= nil and type(enemy) == "table" then
								if enemy.ref_entity:IsValid() and enemy.ref_health:IsValid() then
									if infiniteHP[enemy.name] == nil then infiniteHP[enemy.name] = false end
									if infiniteHP[enemy.name] then
										enemy.ref_health.currentHP = MAX_HEALTH
									elseif enemy.ref_health.currentHP > enemy.max_hp then
										enemy.ref_health.currentHP = enemy.max_hp
									end
								end
							end
						end
					end
					if playerPawn.ref_entity.lockedOn == true then
						local target = playerPawn.ref_entity.lockonComponent:GetFullName()
						if target ~= nil then
							lockonTarget = target:match("%.[%w_]+%."):sub(2, -2)
						end
					end
					if focusedEnemies[currentArea] ~= nil then
						for _,focus in ipairs(focusedEnemies[currentArea]) do
							focus.index = nil
						end
					end
					for _, class in ipairs(ENEMY_CLASS_ORDERED) do
						if enemies[currentArea][class] ~= nil then
							for _,enemy in ipairs(enemies[currentArea][class]) do
								if enemy ~= nil and type(enemy) == "table" then
									areaEnemies[#areaEnemies + 1] = {name = enemy.name, enemy = enemy}
									if lockonTarget == enemy.name then
										enemyIndex = #areaEnemies
									end
									if focusedEnemies[currentArea] ~= nil then
										for _,focus in ipairs(focusedEnemies[currentArea]) do
											if focus.name == enemy.name then
												focus.index = #areaEnemies
											end
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
					playerHealthWidget = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), playerPawn.ref_entity, FName("PseudoregaliaHealth_Player_Display"))
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
					enemyHealthWidget = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), playerPawn.ref_entity, FName("PseudoregaliaHealth_Enemy_Display"))
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
				if menuVariant == MENU.NO_ENEMY then
					enemyText = "\n\n        No Enemies in Area\n\n\n =========================================\nPress Enter to Hide"
				elseif menuVariant == MENU.FOCUSED_ENEMIES then
					for i=1,5 do
						local line = "  "
						if i == menuIndex then line = ">" end
						if focusedEnemies[currentArea][i] ~= nil then
							if areaEnemies[focusedEnemies[currentArea][i].index] ~= nil then
								local enemy = areaEnemies[focusedEnemies[currentArea][i].index].enemy
								local name = enemy.display_name
								local maxHP = enemy.max_hp
								local currentHealth = 0
								local attack = "None"
								if enemy ~= nil then
									if enemy.ref_entity and enemy.ref_health:IsValid() then
										currentHealth = enemy.ref_health.CurrentHp
										attack = enemy.ref_entity.activeAttackID
									end
								end
								if infiniteHP[focusedEnemies[currentArea][i].name] then
									currentHealth = "∞"
								end
								
								line = line .. name .. ", HP = " .. currentHealth .. "/" .. maxHP .. ", Attack = " .. attack
							end
						end
						enemyText = enemyText .. line .."\n"
					end
					enemyText = enemyText .. " =========================================\n"
					local optionInfinite = "[  ]"
					if focusedEnemies[currentArea][menuIndex].name ~= nil then
						if infiniteHP[focusedEnemies[currentArea][menuIndex].name] then optionInfinite = "[x]" end
					end
					enemyText = enemyText .. "{ " .. isOption(menuOption == 1, ">","  ") .. optionInfinite .. "∞HP | "
					enemyText = enemyText .. isOption(menuOption == 2, ">","  ") .. "Enemy List... | "
					enemyText = enemyText .. isOption(menuOption == 3, ">","  ") .. isOption(saveVariantAll, "[Total]","[Area]")
					enemyText = enemyText .. isOption(menuOption == 4, ">","  ") .. "Save "
					enemyText = enemyText .. isOption(menuOption == 5, ">","  ") .. "Load | "
					enemyText = enemyText .. isOption(menuOption == 6, ">","  ") .. "Hide }"
				elseif menuVariant == MENU.ENEMY_LIST then
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
						if tableIndex >= min then
							local line = "  "
							if tableIndex == enemyIndex then line = ">" end
							enemyText = enemyText .. line .. enemy.enemy.display_name .. "\n"
							lineIndex = lineIndex + 1
							if lineIndex > 5 then break end
						end
					end
					while lineIndex <= 5 do
						lineIndex = lineIndex + 1
						enemyText = enemyText .. "\n"
					end
					enemyText = enemyText .. " =========================================\nEnter > Confirm | Backspace > Cancel | Lockon > Select"
				elseif menuVariant == MENU.MINIATURE then
					enemyText = "No Enemy Selected | Enter to open Menu"
					if focusedEnemies[currentArea] ~= nil then
						if focusedEnemies[currentArea][menuIndex].index ~= nil then
							if areaEnemies[focusedEnemies[currentArea][menuIndex].index] ~= nil then
								local enemy = areaEnemies[focusedEnemies[currentArea][menuIndex].index].enemy
								local name = enemy.display_name
								local maxHP = enemy.max_hp
								local currentHealth = 0
								local attack = "None"
								if enemy ~= nil then
									if enemy.ref_entity and enemy.ref_health:IsValid() then
										currentHealth = enemy.ref_health.CurrentHp
										attack = enemy.ref_entity.activeAttackID
									end
								end
								if infiniteHP[focusedEnemies[currentArea][menuIndex].name] then
									currentHealth = "∞"
								end
								
								enemyText = name .. ", HP = " .. currentHealth .. "/" .. maxHP .. ", Attack = " .. attack .. "   | Enter to open Menu"
							end
						end
					end
				else
					enemyText = enemyText .. "\n\n\n\n\n =========================================\n{ >[  ]∞HP |   Enemy List... |   [Total]  Save   Load |   Hide }"
				end
				playerHealthWidget.WidgetTree.RootWidget.Slots[1].Content:SetText(FText(playerText))
				playerHealthWidget.WidgetTree.RootWidget.Background.TintColor.SpecifiedColor = {R=0,G=0,B=0,A=0.4}
				playerHealthWidget:SetPositionInViewport(Utils.FVector2D(350, 10), false)
				playerHealthWidget:AddToViewport(0)
				
				enemyHealthWidget.WidgetTree.RootWidget.Slots[1].Content:SetText(FText(enemyText))
				enemyHealthWidget.WidgetTree.RootWidget.Slots[1].Content.Font.Size = 15
				enemyHealthWidget.WidgetTree.RootWidget.Background.TintColor.SpecifiedColor = {R=0,G=0,B=0,A=0.4}
				local enemyMenuPlacement = Utils.FVector2D(1405, 900)
				if menuVariant == 3 or menuVariant == -2 then
					enemyMenuPlacement = Utils.FVector2D(1405, 1050)
				end
				enemyHealthWidget:SetPositionInViewport(enemyMenuPlacement, false)
				enemyHealthWidget:AddToViewport(0)
			end
		end
	end
end)

RegisterKeyBindAsync(hotKey, modifierKeys, function() doReset = true; totalDamage = 0.0 end)
RegisterKeyBindAsync(Key.UP_ARROW,{}, function() menuUp() end)
RegisterKeyBindAsync(Key.DOWN_ARROW,{}, function() menuDown() end)
RegisterKeyBindAsync(Key.LEFT_ARROW,{}, function() menuLeft() end)
RegisterKeyBindAsync(Key.RIGHT_ARROW,{}, function() menuRight() end)
RegisterKeyBindAsync(Key.BACKSPACE,{}, function() menuBack() end)
RegisterKeyBindAsync(Key.RETURN,{}, function() menuEnter() end)
