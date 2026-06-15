local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local RemoteEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
local gardensFolder = Workspace:WaitForChild("Gardens")

local plantActionEnabled = false
local autoFarmEnabled = false
local autoSellEnabled = false
local autoBuyEnabled = false
local selectedSeeds = {}

local seedBuffers = {
    ["Acorn"]           = "h\000\005Acorn",
    ["Apple"]           = "h\000\005Apple",
    ["Bamboo"]          = "h\000\006Bamboo",
    ["Banana"]          = "h\000\006Banana",
    ["Blueberry"]       = "h\000\009Blueberry",
    ["Cactus"]          = "h\000\006Cactus",
    ["Carrot"]          = "h\000\006Carrot",
    ["Cherry"]          = "h\000\006Cherry",
    ["Coconut"]         = "h\000\007Coconut",
    ["Corn"]            = "h\000\004Corn",
    ["Dragon Fruit"]    = "h\000\012Dragon Fruit",
    ["Dragon's Breath"] = "h\000\015Dragon's Breath",
    ["Grape"]           = "h\000\005Grape",
    ["Green Bean"]      = "h\000\010Green Bean",
    ["Mango"]           = "h\000\005Mango",
    ["Moon Bloom"]      = "h\000\010Moon Bloom",
    ["Mushroom"]        = "h\000\008Mushroom",
    ["Pineapple"]       = "h\000\009Pineapple",
    ["Poison Apple"]    = "h\000\012Poison Apple",
    ["Pomegranate"]     = "h\000\011Pomegranate",
    ["Strawberry"]      = "h\000\010Strawberry",
    ["Sunflower"]       = "h\000\009Sunflower",
    ["Tomato"]          = "h\000\006Tomato",
    ["Tulip"]           = "h\000\005Tulip",
    ["Venus Fly Trap"]  = "h\000\013Venus Fly Trap",
}

local function getMyPlotData()
    local myUserIdStr = tostring(LocalPlayer.UserId)
    local myNameStr = LocalPlayer.Name
    local allBedSections = {}
    local allPlantsFolders = {}

    local plots = gardensFolder:GetChildren()

    for idx, plot in ipairs(plots) do
        local attributeOwner = plot:GetAttribute("Owner")
        local valueObjectOwner = plot:FindFirstChild("Owner")
        local actualOwner = attributeOwner or (valueObjectOwner and valueObjectOwner.Value)
        
        if tostring(actualOwner) == myNameStr or tostring(actualOwner) == myUserIdStr then
            local localBedsCount = 0
            for _, descendant in ipairs(plot:GetDescendants()) do
                if string.find(descendant.Name, "BedSection") and (descendant:IsA("Model") or descendant:IsA("BasePart")) then
                    table.insert(allBedSections, descendant)
                    localBedsCount = localBedsCount + 1
                end
            end
            
            local plants = plot:FindFirstChild("Plants")
            if plants then
                table.insert(allPlantsFolders, plants)
            end
        end
    end
    
    return allBedSections, allPlantsFolders
end

local function useSeedAtPosition(position, seedName, seedTool)
    local bufferSize = 2 + 12 + 1 + #seedName
    local buf = buffer.create(bufferSize)
    buffer.writeu16(buf, 0, 4)
    buffer.writef32(buf, 2, position.X)
    buffer.writef32(buf, 6, position.Y)
    buffer.writef32(buf, 10, position.Z)
    buffer.writeu8(buf, 14, #seedName)
    buffer.writestring(buf, 15, seedName)
    RemoteEvent:FireServer(buf, { seedTool })
end

local function getNextAvailableSeed()
    local character = LocalPlayer.Character
    local itemsToCheck = {}
    for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do table.insert(itemsToCheck, item) end
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") then table.insert(itemsToCheck, item) end
        end
    end
    for _, child in ipairs(itemsToCheck) do
        if child:GetAttribute("MainCategory") == "Seed" then
            local nameLower = string.lower(child.Name)
            local isRainbow = string.find(nameLower, "rainbow") ~= nil
                or child:GetAttribute("Rarity") == "Rainbow"
                or child:GetAttribute("Type") == "Rainbow"
                or child:GetAttribute("SubCategory") == "Rainbow"
            if not isRainbow then return child end
        end
    end
    return nil
end

local function startGridPlanting(setLabel)
    local bedSections, plantsFolders = getMyPlotData()
    
    if not bedSections or #bedSections == 0 then
        plantActionEnabled = false
        if setLabel then setLabel("Plot not found") end
        return
    end

    local step = 2
    local checkRadius = 1.6

    while plantActionEnabled do
        local plantedThisPass = false

        local occupiedPositions = {}
        if type(plantsFolders) == "table" then
            for _, folder in ipairs(plantsFolders) do
                if typeof(folder) == "Instance" then
                    for _, plant in ipairs(folder:GetChildren()) do
                        if plant:IsA("BasePart") then
                            table.insert(occupiedPositions, plant.Position)
                        elseif plant:IsA("Model") then
                            table.insert(occupiedPositions, plant:GetPivot().Position)
                        end
                    end
                end
            end
        end

        for bIdx, bed in ipairs(bedSections) do
            if not plantActionEnabled then break end

            if typeof(bed) == "Instance" and (bed:IsA("BasePart") or bed:IsA("Model")) then
                local bedCFrame, bedSize
                if bed:IsA("BasePart") then
                    bedCFrame = bed.CFrame
                    bedSize = bed.Size
                else
                    bedCFrame, bedSize = bed:GetBoundingBox()
                end

                local halfWidthX = bedSize.X / 2
                local halfLengthZ = bedSize.Z / 2

                for xOffset = -halfWidthX + (step/2), halfWidthX - (step/2), step do
                    for zOffset = -halfLengthZ + (step/2), halfLengthZ - (step/2), step do
                        if not plantActionEnabled then break end

                        local localOffset = Vector3.new(xOffset, 0.5, zOffset)
                        local targetPosition = bedCFrame:PointToWorldSpace(localOffset)

                        local isOccupied = false
                        for _, pos in ipairs(occupiedPositions) do
                            local flatTarget = Vector3.new(targetPosition.X, 0, targetPosition.Z)
                            local flatPos = Vector3.new(pos.X, 0, pos.Z)
                            if (flatTarget - flatPos).Magnitude < checkRadius then
                                isOccupied = true
                                break
                            end
                        end

                        if not isOccupied then
                            local currentSeed = getNextAvailableSeed()
                            if not currentSeed then
                                if setLabel then setLabel("Waiting for seeds...") end
                                while plantActionEnabled and not currentSeed do
                                    task.wait(1)
                                    currentSeed = getNextAvailableSeed()
                                end
                                if not plantActionEnabled then return end
                            end
                            
                            if setLabel then setLabel("Planting: " .. tostring(currentSeed.Name)) end
                            useSeedAtPosition(targetPosition, currentSeed.Name, currentSeed)
                            
                            table.insert(occupiedPositions, targetPosition)
                            plantedThisPass = true
                            task.wait(0.05)
                        end
                    end
                    if not plantActionEnabled then break end
                end
            end
        end

        if not plantedThisPass and plantActionEnabled then
            if setLabel then setLabel("All plots full, waiting...") end
            task.wait(2)
        end

        task.wait(0.1)
    end

    plantActionEnabled = false
end

local function collectFruit(plantId, fruitId)
    RemoteEvent:FireServer(buffer.fromstring("\178\000$" .. plantId .. "$" .. fruitId))
end

local function collectPlantOnly(plantId)
    RemoteEvent:FireServer(buffer.fromstring("\178\000$" .. plantId .. "\000"))
end

local function harvestEverything()
    if not autoFarmEnabled then return end
    local bedSections, plantsFolders = getMyPlotData()
    if not plantsFolders or type(plantsFolders) ~= "table" then return end
    
    for _, folder in ipairs(plantsFolders) do
        if typeof(folder) == "Instance" then
            for _, item in ipairs(folder:GetDescendants()) do
                if not autoFarmEnabled then break end
                local plantId = item:GetAttribute("PlantId")
                local fruitId = item:GetAttribute("FruitId")
                if plantId then
                    if fruitId then
                        pcall(collectFruit, plantId, fruitId)
                        task.wait(0.05)
                    else
                        if item.Parent == folder
                            or item:GetAttribute("MainCategory") == "Plant"
                            or string.find(string.lower(item.Name), "plant") then
                            pcall(collectPlantOnly, plantId)
                            task.wait(0.05)
                        end
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        if autoFarmEnabled then pcall(harvestEverything) end
        task.wait(0.01)
    end
end)

task.spawn(function()
    while true do
        if autoSellEnabled then
            pcall(function() RemoteEvent:FireServer(buffer.fromstring("\154\000\028")) end)
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    while true do
        if autoBuyEnabled and #selectedSeeds > 0 then
            for _, seedName in ipairs(selectedSeeds) do
                if seedBuffers[seedName] then
                    pcall(function()
                        RemoteEvent:FireServer(buffer.fromstring(seedBuffers[seedName]))
                    end)
                    task.wait(0.2)
                end
            end
        end
        task.wait(1)
    end
end)

-- Rayfield GUI
local Window = Rayfield:CreateWindow({
    Name = "SkyPie Hub",
    LoadingTitle = "SkyPie Hub",
    LoadingSubtitle = "Garden Script Fixed",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false
})

local Tab = Window:CreateTab("Garden", "shovel")
local StatusLabel = Tab:CreateLabel("Status: Idle")

Tab:CreateToggle({
    Name = "Auto Plant",
    CurrentValue = false,
    Flag = "AutoPlant",
    Callback = function(Value)
        plantActionEnabled = Value
        if Value then
            StatusLabel:Set("Status: Planting...")
            task.spawn(function()
                startGridPlanting(function(text)
                    StatusLabel:Set("Status: " .. text)
                end)
            end)
        else
            StatusLabel:Set("Status: Auto Plant OFF")
        end
    end
})

Tab:CreateToggle({
    Name = "Auto Farm",
    CurrentValue = false,
    Flag = "AutoFarm",
    Callback = function(Value)
        autoFarmEnabled = Value
        StatusLabel:Set(Value and "Status: Auto Farm ON" or "Status: Auto Farm OFF")
    end
})

Tab:CreateToggle({
    Name = "Auto Sell",
    CurrentValue = false,
    Flag = "AutoSell",
    Callback = function(Value)
        autoSellEnabled = Value
        StatusLabel:Set(Value and "Status: Auto Sell ON" or "Status: Auto Sell OFF")
    end
})

Tab:CreateSection("Auto Buy")
Tab:CreateDropdown({
    Name = "Select Seeds",
    Options = {
        "Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", 
        "Apple", "Bamboo", "Corn", "Cactus", "Pineapple", 
        "Mushroom", "Green Bean",  "Banana", "Grape", "Coconut",
        "Mango", "Dragon Fruit", "Acorn", "Cherry", "Sunflower", 
        "Venus Fly Trap", "Pomegranate", "Poison Apple", 
        "Moon Bloom", "Dragon's Breath",
    },
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "SeedDropdown",
    Callback = function(Value)
        selectedSeeds = type(Value) == "table" and Value or {Value}
        StatusLabel:Set("Selected: " .. #selectedSeeds .. " seed(s)")
    end
})

Tab:CreateToggle({
    Name = "Auto Buy",
    CurrentValue = false,
    Flag = "AutoBuy",
    Callback = function(Value)
        autoBuyEnabled = Value
        if Value then
            StatusLabel:Set("Status: Auto Buy ON (" .. #selectedSeeds .. " seeds)")
        else
            StatusLabel:Set("Status: Auto Buy OFF")
        end
    end
})