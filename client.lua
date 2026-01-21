local ESX = nil
local QBCore = nil

local inRange = false
local isUiOpen = false
local currentGarageData = nil
local AllGarages = {}
local garageBlips = {}
local jobBlips = {}
local PlayerJob = {}
local isJobGarage = false
local currentJobGarageConfig = nil

local function Trim(value)
    if not value then return nil end
    return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

local function GetVehicleProperties(vehicle)
    local props = nil
    if ESX then props = ESX.Game.GetVehicleProperties(vehicle)
    elseif QBCore then props = QBCore.Functions.GetVehicleProperties(vehicle)
    else props = { plate = GetVehicleNumberPlateText(vehicle), model = GetEntityModel(vehicle) } end

    props.burstTyres = {}
    for i = 0, 7 do
        if IsVehicleTyreBurst(vehicle, i, false) then
            props.burstTyres[tostring(i)] = IsVehicleTyreBurst(vehicle, i, true)
        end
    end

    props.brokenDoors = {}
    for i = 0, 5 do
        if IsVehicleDoorDamaged(vehicle, i) then
            props.brokenDoors[tostring(i)] = true
        end
    end

    props.brokenWindows = {}
    for i = 0, 7 do
        if not IsVehicleWindowIntact(vehicle, i) then
            props.brokenWindows[tostring(i)] = true
        end
    end

    props.bodyHealth = GetVehicleBodyHealth(vehicle)
    props.engineHealth = GetVehicleEngineHealth(vehicle)

    return props
end

local function SetVehicleProperties(vehicle, props)
    if ESX then ESX.Game.SetVehicleProperties(vehicle, props)
    elseif QBCore then QBCore.Functions.SetVehicleProperties(vehicle, props) end

    if props.bodyHealth and props.bodyHealth < 1000.0 then
        SetVehicleBodyHealth(vehicle, 100.0) 
        SetVehicleEngineHealth(vehicle, props.engineHealth or 100.0)
        
        SetVehicleDamage(vehicle, 0.0, 0.0, 0.1, 100.0, 100.0, true)

        Wait(50)
        SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0)
    end

    if props.brokenDoors then
        for id, _ in pairs(props.brokenDoors) do
            SetVehicleDoorBroken(vehicle, tonumber(id), true)
        end
    end

    if props.brokenWindows then
        for id, _ in pairs(props.brokenWindows) do
            SmashVehicleWindow(vehicle, tonumber(id))
        end
    end

    if props.burstTyres then
        for id, onRim in pairs(props.burstTyres) do
            SetVehicleTyreBurst(vehicle, tonumber(id), onRim, 1000.0)
        end
    end
end

local function GetPlayerGrade()
    if not PlayerJob or not PlayerJob.grade then return 0 end
    if type(PlayerJob.grade) == "table" then return PlayerJob.grade.level or 0 end
    return tonumber(PlayerJob.grade) or 0
end

local function IsVehicleAllowed(model, garageType)
    local class = GetVehicleClassFromName(model)
    if garageType == "boat" then return class == 14
    elseif garageType == "air" then return class == 15 or class == 16
    else return class ~= 14 and class ~= 15 and class ~= 16 end
end

local function ClearBlips(blipTable)
    for _, blip in pairs(blipTable) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    return {}
end

local function CreateBlip(coords, sprite, display, scale, color, name)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, display)
    SetBlipScale(blip, scale)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function RefreshJobBlips()
    if not Config.UseJobGarages then return end
    jobBlips = ClearBlips(jobBlips)

    if PlayerJob and PlayerJob.name and Config.JobGarages[PlayerJob.name] then
        local garage = Config.JobGarages[PlayerJob.name]
        local blip = CreateBlip(garage.coords, 60, 4, 0.7, 38, garage.label or "Job Garage")
        table.insert(jobBlips, blip)
    end
end

local function LoadGarages(privateGarages)
    AllGarages = {}
    garageBlips = ClearBlips(garageBlips)

    for _, v in pairs(Config.Garages) do
        table.insert(AllGarages, v)
        local sprite = Config.BlipSettings.SpriteTypes[v.type] or 357
        local blip = CreateBlip(v.coords, sprite, Config.BlipSettings.Display, Config.BlipSettings.Scale, Config.BlipSettings.Colour, v.name)
        table.insert(garageBlips, blip)
    end

    if Config.PrivateGarages.ENABLE and privateGarages then
        for _, v in pairs(privateGarages) do
            table.insert(AllGarages, v)
            local blip = CreateBlip(v.coords, 40, 4, 0.6, 2, "Private: " .. v.name)
            table.insert(garageBlips, blip)
        end
    end
end

CreateThread(function()
    if Config.Impound.Enabled and Config.Impound.Blip.Enable then
        for _, loc in pairs(Config.Impound.Locations) do
            CreateBlip(loc.Coords, Config.Impound.Blip.Sprite, 4, Config.Impound.Blip.Scale, Config.Impound.Blip.Color, Config.Impound.Blip.Name)
        end
    end

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local veh = GetVehiclePedIsIn(ped, false)
        local inDriverSeat = (veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped)
        
        local nearbyGarage = nil 
        local typeOfGarage = nil

        for _, garage in pairs(AllGarages) do
            local dist = #(pos - garage.coords)
            if dist < 3 then 
                sleep = 0
                nearbyGarage = garage
                typeOfGarage = 'public' 
            end
        end

        if Config.UseJobGarages and not nearbyGarage and PlayerJob and Config.JobGarages[PlayerJob.name] then
            local jobGarage = Config.JobGarages[PlayerJob.name]
            local dist = #(pos - jobGarage.coords)
            if dist < 3 then 
                sleep = 0 
                nearbyGarage = jobGarage
                typeOfGarage = 'job' 
            end
        end

        if Config.Impound.Enabled and not nearbyGarage then
            for _, loc in pairs(Config.Impound.Locations) do
                local dist = #(pos - loc.Coords)

                if dist < 3 then 
                    sleep = 0
                    nearbyGarage = { 
                        name = "Impound Lot", 
                        type = "impound", 
                        spawnPoint = loc.SpawnPoint 
                    } 
                    typeOfGarage = 'impound' 
                end
            end
        end

        if nearbyGarage then
            if not inRange then
                inRange = true
                local keyText = inDriverSeat and "G" or "E"
                local labelText = "Open Garage"

                if inDriverSeat then
                    labelText = (typeOfGarage == 'job') and "Store Job Vehicle" or "Store Vehicle"
                else
                    if typeOfGarage == 'job' then labelText = "Job Garage"
                    elseif typeOfGarage == 'impound' then labelText = "Open Impound" end
                end

                SendNUIMessage({
                    action = 'showTextUI',
                    key = keyText,
                    label = labelText
                })
            end

            if inDriverSeat then
                if IsControlJustPressed(0, 47) then 
                    if typeOfGarage == 'impound' then
                        lib.notify({ type = 'error', description = 'You cannot store vehicles in the Impound!' })
                    elseif typeOfGarage == 'public' then
                        local currentVehClass = GetVehicleClass(veh)
                        local gType = nearbyGarage.type or "car"
                        local allowed = false
                        
                        if gType == "boat" and currentVehClass == 14 then allowed = true
                        elseif gType == "air" and (currentVehClass == 15 or currentVehClass == 16) then allowed = true
                        elseif gType == "car" and (currentVehClass ~= 14 and currentVehClass ~= 15 and currentVehClass ~= 16) then allowed = true
                        end

                        if allowed then
                            local props = GetVehicleProperties(veh)
                            TriggerServerEvent("tb_garage:storeOwnedVehicle", GetVehicleNumberPlateText(veh), props, nearbyGarage.name)
                            Wait(500); TaskLeaveVehicle(ped, veh, 0); Wait(1500); DeleteVehicle(veh)
                            SendNUIMessage({ action = 'hideTextUI' })
                            inRange = false
                        else
                            lib.notify({ type = 'error', description = 'You cannot store this vehicle type here!' })
                        end

                    elseif typeOfGarage == 'job' then
                        local plate = GetVehicleNumberPlateText(veh)
                        TaskLeaveVehicle(ped, veh, 0); Wait(1500); DeleteVehicle(veh)
                        TriggerServerEvent("tb_garage:removeJobKey", plate)
                        lib.notify({ type = 'success', description = 'Vehicle Stored' })
                        SendNUIMessage({ action = 'hideTextUI' })
                        inRange = false
                    end
                end
            else
                if IsControlJustPressed(0, 38) then 
                    SendNUIMessage({ action = 'hideTextUI' })
                    
                    if typeOfGarage == 'public' then
                        currentGarageData = nearbyGarage
                        TriggerServerEvent("tb_garage:getVehicles", nearbyGarage.name, "public")

                    elseif typeOfGarage == 'impound' then
                        currentGarageData = nearbyGarage 
                        TriggerServerEvent("tb_garage:getVehicles", "Impound", "impound")

                    elseif typeOfGarage == 'job' then
                        local processedVehicles = {}
                        local myGrade = GetPlayerGrade()
                        for _, v in ipairs(nearbyGarage.vehicles) do
                            if myGrade >= v.grade then
                                table.insert(processedVehicles, {
                                    label = v.label, plate = v.plate, stored = true, state = "stored",
                                    engine = 1000.0, body = 1000.0, fuel = 100.0, vehicleProps = { model = v.model }
                                })
                            end
                        end
                        isJobGarage = true
                        currentJobGarageConfig = nearbyGarage
                        SetNuiFocus(true, true)
                        SendNUIMessage({
                            action = 'open',
                            vehicles = processedVehicles,
                            garages = {}, 
                            returnPrice = 0, chargeFee = false,
                            transferConfig = { GarageFeeEnabled = false, PlayerFeeEnabled = false },
                            garageType = 'job'
                        })
                        isUiOpen = true
                    end
                end
            end
        else
            if inRange then 
                SendNUIMessage({ action = 'hideTextUI' })
                inRange = false 
            end
        end
        Wait(sleep)
    end
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    isUiOpen = false
    inRange = false
    SendNUIMessage({ action = 'hideTextUI' })
    isJobGarage = false
    currentJobGarageConfig = nil
    cb('ok')
end)

RegisterNUICallback('retrieveImpound', function(data, cb)
    TriggerServerEvent("tb_garage:retrieveImpound", data.plate)
    cb('ok')
end)

RegisterNUICallback('submitImpound', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent("tb_garage:submitImpound", data.plate, data.reason, data.time, data.fine)
    cb('ok')
end)

RegisterNUICallback('payReturn', function(data, cb)
    TriggerServerEvent("tb_garage:payReturn", data.plate)
    cb('ok')
end)

RegisterNUICallback('transferVehicle', function(data, cb)
    TriggerServerEvent("tb_garage:transferVehicle", data.plate, data.type, data.target)
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    SetNuiFocus(false, false)
    isUiOpen = false
    inRange = false
    SendNUIMessage({ action = 'hideTextUI' })
    
    if isJobGarage then
        local selectedVeh = nil
        if currentJobGarageConfig and currentJobGarageConfig.vehicles then
            for _, v in pairs(currentJobGarageConfig.vehicles) do
                if v.plate == data.plate then selectedVeh = v; break end
            end
        end
        if selectedVeh then
            TriggerServerEvent("tb_garage:spawnJobVehicle", selectedVeh, currentJobGarageConfig.spawnPoint, currentJobGarageConfig.type)
        end
        isJobGarage = false; currentJobGarageConfig = nil
    else
        local gName = currentGarageData and currentGarageData.name or nil
        
        if gName then
            TriggerServerEvent("tb_garage:spawnVehicle", data.plate, gName)
        else
            lib.notify({ type = 'error', description = 'Garage location error. Please try again.' })
        end
    end
    cb('ok')
end)

RegisterNetEvent("tb_garage:sendVehicles", function(vehicles, typeRequested, isPolice)
    local processedVehicles = {}
    local currentGarageType = currentGarageData and currentGarageData.type or "car"

    for _, v in pairs(vehicles) do
        if v.vehicle and v.vehicle ~= "" then
            local data = json.decode(v.vehicle)
            
            local allowed = true
            if typeRequested ~= 'impound' then
                 allowed = IsVehicleAllowed(data.model, currentGarageType)
            end

            if data and allowed then
                local modelName = GetDisplayNameFromVehicleModel(data.model)
                local label = GetLabelText(modelName)
                if label == "NULL" then label = modelName end
                label = label:lower():gsub("^%l", string.upper)

                table.insert(processedVehicles, {
                    label = label or "Unknown",
                    plate = v.plate,
                    nickname = v.nickname,
                    stored = v.stored,
                    state = v.state, 
                    engine = data.engineHealth or 1000.0,
                    body = data.bodyHealth or 1000.0,
                    fuel = data.fuelLevel or 100.0,
                    vehicleProps = v.vehicle,
                    impound = v.impound,
                    fee = v.impound_fee,
                    reason = v.impound_reason,
                    releaseDate = v.impound_release_date
                })
            end
        end
    end

    local filteredGarages = {}
    if typeRequested == 'public' then
        for _, g in pairs(AllGarages) do
            if (g.type or "car") == currentGarageType then table.insert(filteredGarages, g) end
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        vehicles = processedVehicles,
        garages = filteredGarages,
        returnPrice = (typeRequested == 'impound') and Config.Impound.RetrievePrice or Config.ReturnSystem.Price,
        chargeFee = Config.ReturnSystem.ChargeFee,
        transferConfig = Config.TransferSystem,
        garageType = typeRequested,
        isPolice = isPolice
    })
    isUiOpen = true
end)

RegisterNetEvent("tb_garage:spawn", function(props, garageName)
    if not props then return end

    local model = props.model
    
    if type(model) == "string" then
        if tonumber(model) then 
            model = tonumber(model)
        else
            model = GetHashKey(model)
        end
    end

    if not model or model == 0 or not IsModelInCdimage(model) then
        print("^1[ERROR] Invalid Model: " .. tostring(props.model) .. ". Check your database!^0")
        lib.notify({ type = 'error', description = 'Vehicle model is invalid or missing in DB!' })
        return
    end

    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do 
        Wait(10) 
        timeout = timeout + 1 
    end

    if not HasModelLoaded(model) then
        lib.notify({ type = 'error', description = 'Model failed to load (Invalid Model?)' })
        return
    end

    local spawn = nil
    for _, v in pairs(AllGarages) do
        if v.name == garageName then spawn = v.spawnPoint; break end
    end
    if not spawn then
        local p = GetEntityCoords(PlayerPedId())
        spawn = {x = p.x, y = p.y, z = p.z, w = GetEntityHeading(PlayerPedId())}
    end

    local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    SetEntityAsMissionEntity(veh, true, true)
    
    Wait(200)
    if QBCore then
        QBCore.Functions.SetVehicleProperties(veh, props)
    else
        SetVehicleProperties(veh, props)
    end
    
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    lib.notify({ type = 'success', description = 'Vehicle retrieved!' })
end)

RegisterNetEvent("tb_garage:receivePrivateGarages", function(privateData)
    LoadGarages(privateData)
end)

RegisterNetEvent("tb_garage:syncPrivateGarages", function()
    TriggerServerEvent("tb_garage:requestPrivateGarages")
end)

if Config.EnableKey then
    RegisterKeyMapping('togglevehiclelock', 'Toggle Vehicle Lock', 'keyboard', 'U')

    RegisterCommand('togglevehiclelock', function()
        local ped = PlayerPedId()
        local vehicle = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or GetClosestVehicle(GetEntityCoords(ped), 5.0, 0, 71)

        if DoesEntityExist(vehicle) then
            TriggerServerEvent("tb_garage:toggleLock", NetworkGetNetworkIdFromEntity(vehicle), GetVehicleNumberPlateText(vehicle))
        else
            lib.notify({ type = 'error', description = 'No vehicle found nearby.' })
        end
    end)
end

RegisterNetEvent("tb_garage:receiveLockUpdate", function(netId, isOwner)
    if not isOwner then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        local lockStatus = GetVehicleDoorLockStatus(vehicle)
        local ped = PlayerPedId()

        if not IsPedInAnyVehicle(ped, true) then
            local dict = "anim@mp_player_intmenu@key_fob@"
            RequestAnimDict(dict)
            while not HasAnimDictLoaded(dict) do Wait(10) end
            TaskPlayAnim(ped, dict, "fob_click_fp", 8.0, 8.0, -1, 48, 1, false, false, false)
        end

        if lockStatus == 1 then
            SetVehicleDoorsLocked(vehicle, 2)
            SetVehicleDoorsLockedForAllPlayers(vehicle, true)
            PlayVehicleDoorCloseSound(vehicle, 1)
            lib.notify({ type = 'success', description = 'Vehicle Locked' })
            SetVehicleLights(vehicle, 2); Wait(150); SetVehicleLights(vehicle, 0); Wait(150); SetVehicleLights(vehicle, 2); Wait(150); SetVehicleLights(vehicle, 0)
            StartVehicleHorn(vehicle, 100, "HELDDOWN", false)
        elseif lockStatus == 2 then
            SetVehicleDoorsLocked(vehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(vehicle, false)
            PlayVehicleDoorOpenSound(vehicle, 0)
            lib.notify({ type = 'success', description = 'Vehicle Unlocked' })
            SetVehicleLights(vehicle, 2); Wait(200); SetVehicleLights(vehicle, 0)
            StartVehicleHorn(vehicle, 100, "HELDDOWN", false)
        end
    end
end)

if Config.EnableRemote then
    local isFobOpen = false
    RegisterCommand('carremote', function()
        isFobOpen = not isFobOpen
        SetNuiFocus(isFobOpen, isFobOpen)
        SendNUIMessage({ action = 'toggleFob' })
    end)
    RegisterKeyMapping('carremote', 'Open Vehicle Remote', 'keyboard', 'F6')

    RegisterNUICallback('closeFob', function(_, cb)
        isFobOpen = false
        SetNuiFocus(false, false)
        cb('ok')
    end)

    RegisterNUICallback('fobAction', function(data, cb)
        local ped = PlayerPedId()
        local vehicle = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or GetClosestVehicle(GetEntityCoords(ped), 10.0, 0, 71)

        if not DoesEntityExist(vehicle) then
            lib.notify({ type = 'error', description = 'No vehicle in range.' })
            cb('error')
        else
            TriggerServerEvent("tb_garage:remoteAction", NetworkGetNetworkIdFromEntity(vehicle), GetVehicleNumberPlateText(vehicle), data.action)
            cb('ok')
        end
    end)

    RegisterNetEvent("tb_garage:executeRemoteAction", function(netId, action)
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if not DoesEntityExist(vehicle) then return end

        if action == "engine" then
            local state = not GetIsVehicleEngineRunning(vehicle)
            SetVehicleEngineOn(vehicle, state, true, true)
            lib.notify({ type = state and 'success' or 'inform', description = state and 'Remote Start Active' or 'Remote Stop' })
        elseif action == "lock" then
            SetVehicleDoorsLocked(vehicle, 2)
            lib.notify({ type = 'success', description = 'Vehicle Locked' })
        elseif action == "unlock" then
            SetVehicleDoorsLocked(vehicle, 1)
            lib.notify({ type = 'success', description = 'Vehicle Unlocked' })
        elseif action == "trunk" then
            if GetVehicleDoorAngleRatio(vehicle, 5) > 0 then SetVehicleDoorShut(vehicle, 5, false) else SetVehicleDoorOpen(vehicle, 5, false, false) end
        elseif action == "lights" then
            local _, lightsOn, _ = GetVehicleLightsState(vehicle)
            SetVehicleLights(vehicle, (lightsOn == 1) and 1 or 2)
        end
    end)
end

RegisterNetEvent("tb_garage:adminGetVehicleData", function(targetId)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return lib.notify({ type = 'error', description = 'You must be sitting in a vehicle.' }) end

    local vehicleProps = GetVehicleProperties(veh)
    local class = GetVehicleClass(veh)
    local vehicleType = "car"
    if class == 14 then vehicleType = "boat" elseif class == 15 or class == 16 then vehicleType = "air" end

    local defaultGarage = "Central Garage"
    for _, g in pairs(Config.Garages) do
        if (g.type or "car") == vehicleType then defaultGarage = g.name; break end
    end

    TriggerServerEvent("tb_garage:adminSaveVehicle", targetId, vehicleProps, vehicleType, defaultGarage)
end)

RegisterNetEvent("tb_garage:adminRequestDelete", function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return lib.notify({ type = 'error', description = 'You must be sitting in the vehicle.' }) end

    TriggerServerEvent("tb_garage:adminConfirmDelete", GetVehicleNumberPlateText(veh))
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
end)

local function InitialSetup()
    if Config.Framework == "ESX" or GetResourceState("es_extended") == "started" then
        if not ESX then TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end) end
        local playerData = ESX.GetPlayerData()
        if playerData then PlayerJob = playerData.job end
    elseif Config.Framework == "QBCore" or GetResourceState("qb-core") == "started" then
        if not QBCore then QBCore = exports['qb-core']:GetCoreObject() end
        local playerData = QBCore.Functions.GetPlayerData()
        if playerData then PlayerJob = playerData.job end
    end

    LoadGarages(nil)
    RefreshJobBlips()
    TriggerServerEvent("tb_garage:requestPrivateGarages")
end

if Config.Framework == "ESX" or GetResourceState("es_extended") == "started" then
    RegisterNetEvent('esx:playerLoaded', function(xPlayer) PlayerJob = xPlayer.job; Wait(1000); InitialSetup() end)
    RegisterNetEvent('esx:setJob', function(job) PlayerJob = job; RefreshJobBlips() end)
    RegisterNetEvent('esx:onPlayerLogout', function() LoadGarages(nil) end)
elseif Config.Framework == "QBCore" or GetResourceState("qb-core") == "started" then
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() Wait(1000); InitialSetup() end)
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo) PlayerJob = JobInfo; RefreshJobBlips() end)
    RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() LoadGarages(nil) end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    Wait(500)
    InitialSetup()
end)

RegisterCommand(Config.Impound.Command, function(source, args)
    local jobName = PlayerJob and PlayerJob.name or "none"
    
    if not Config.Impound.AuthorizedJobs[jobName] then 
        return lib.notify({ type = 'error', description = 'No Permissions' }) 
    end

    local ped = PlayerPedId()
    local vehicle = ESX and ESX.Game.GetClosestVehicle() or GetClosestVehicle(GetEntityCoords(ped), 5.0, 0, 71)

    if DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openImpoundForm',
            plate = Trim(plate)
        })
    else
        lib.notify({ type = 'error', description = 'No vehicle nearby' })
    end
end)

RegisterNUICallback('sendToGarage', function(data, cb)
    SetNuiFocus(false, false)
    isUiOpen = false
    inRange = false
    SendNUIMessage({ action = 'hideTextUI' })
    
    TriggerServerEvent("tb_garage:sendToGarage", data.plate, data.fee)
    cb('ok')
end)

RegisterNUICallback('renameVehicle', function(data, cb)
    TriggerServerEvent("tb_garage:renameVehicle", data.plate, data.nickname)
    cb('ok')
end)