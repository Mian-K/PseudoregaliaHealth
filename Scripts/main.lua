--Settings
--- Reset Total Health:
local hotKey = Key.F2
local modifierKeys = {} -- Valid: { SHIFT, CONTROL, ALT }, comma seperated  

--Namespaces
local PseudoregaliaHealth = {}
local UEHelpers = require("UEHelpers")
local Utils = require("Utils")

--Constants
local MAX_HEALTH = 1000000000.0

--Variables
local lastHP = 0
local damageTimestamps = {}
local totalDamage = 0.0
local index = 1
local doReset = false
local toHeal = 0

---@type UUserWidget?
local widget = nil

Utils.RegisterKey("Reset Total", function() doReset = true; totalDamage = 0.0 end, hotKey, modifierKeys)

LoopAsync(100, function()
	for i = 1, 100 do
		if damageTimestamps[i] ~= nil and os.difftime(os.time(), damageTimestamps[i].timestamp) > 10 then
			toHeal = toHeal + damageTimestamps[i].damage
			damageTimestamps[i] = nil
		end
	end
	
	local PlayerController = Utils.hook_PlayerController()
	if PlayerController ~= nil then
		local currentHP = PlayerController.Pawn.BP_HPHitable["CurrentHp"]
		if type(currentHP) == "number" then
			local recentDamage = 0
			if currentHP <= MAX_HEALTH / 1000 or doReset then
				PlayerController.Pawn.BP_HPHitable:SetPropertyValue("CurrentHp", MAX_HEALTH)
				lastHP = MAX_HEALTH
				damageTimestamps = {}
				doReset = false
				print("Reset to Max HP")
			else
				if lastHP ~= currentHP then
					totalDamage = totalDamage + lastHP - currentHP
					damageTimestamps[index] = { timestamp = os.time(), damage = lastHP - currentHP }
					index = (index + 1) % 100 
				end
				if toHeal > 0 then
					currentHP = currentHP + toHeal
					PlayerController.Pawn.BP_HPHitable:SetPropertyValue("CurrentHp", currentHP)
					toHeal = 0
				end
				lastHP = currentHP
				recentDamage = MAX_HEALTH - currentHP
			end
			local hpBox = FindObject("HorizontalBox","hpBox")
			local GameInstance = PseudoregaliaUtils.hook_GameInstance()
			if hpBox:IsValid() and GameInstance ~= nil then
				hpBox:ClearChildren()
				
				
				--UserWidget
				---WidgetTree
				----Border
				-----BorderSlot
				------TextBlock
				
				if widget == nil then
				---@type UUserWidget
					widget = FindFirstOf("PseudoregaliaHealth_Display")
				end
				if not widget:IsValid() then
					widget = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), GameInstance, FName("PseudoregaliaHealth_Display"))
					if not widget:IsValid() then
						print("Error creating Health Display...\n")
						return
					end
				end
				if widget.WidgetTree == nil or not widget.WidgetTree:IsValid() then	
					widget.WidgetTree = StaticConstructObject(StaticFindObject("/Script/UMG.WidgetTree"), widget, FName("PseudoregaliaHealth_Tree"))
					if not widget.WidgetTree:IsValid() then
						print("Error creating Health Display Tree...\n")
						return
					end
				end
				if widget.WidgetTree.RootWidget == nil or not widget.WidgetTree.RootWidget:IsValid() then
					widget.WidgetTree.RootWidget = StaticConstructObject(StaticFindObject("/Script/UMG.Border"), widget.WidgetTree, FName("PseudoregaliaHealth_Border"))
					if not widget.WidgetTree.RootWidget:IsValid() then
						print("Error creating Health Display Border...\n")
						return
					end
				end
				if widget.WidgetTree.RootWidget.Slots[1] == nil or not widget.WidgetTree.RootWidget.Slots[1]:IsValid() then
					widget.WidgetTree.RootWidget.Slots[1] = StaticConstructObject(StaticFindObject("/Script/UMG.BorderSlot"), widget.WidgetTree.RootWidget, FName("PseudoregaliaHealth_BorderSlot"))
					if not widget.WidgetTree.RootWidget.Slots[1]:IsValid() then
						print("Error creating Health Display BorderSlot...\n")
						return
					end
				end
				
				
				
				
				if widget.WidgetTree.RootWidget.Slots[1].Content == nil or not widget.WidgetTree.RootWidget.Slots[1].Content:IsValid() then
					widget.WidgetTree.RootWidget.Slots[1].Content = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), widget.widget.WidgetTree.RootWidget.Slots[1], FName("PseudoregaliaHealth_Display_Text"))
					if not widget.WidgetTree.RootWidget.Slots[1].Content:IsValid() then
						print("Error creating Health Display Text...\n")
						return
					end
				end
				widget.WidgetTree.RootWidget.Slots[1].Content:SetText(FText("Total Damage: " .. totalDamage /10 .. "\nRecent Damage: " .. recentDamage /10))
				widget.WidgetTree.RootWidget.Background.TintColor.SpecifiedColor = {R=0,G=0,B=0,A=0.4}
				widget:SetPositionInViewport(PseudoregaliaUtils.FVector2D(350, 10), false)
				widget:AddToViewport(99)
			end
		end
	end
end)

