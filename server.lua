local Framework = nil
local ESX, QBCore = nil, nil
local JobVehicleKeys = {}

local DB = {
    table = "owned_vehicles", 
    owner = "owner",          
    vehicle = "vehicle"      
}

CreateThread(function()
    if GetResourceState("es_extended") == "started" then
        ESX = exports["es_extended"]:getSharedObject()
        Framework = "ESX"
        DB.table = "owned_vehicles"
        DB.owner = "owner"
        DB.vehicle = "vehicle"
        print("^2[TB_GARAGE] Framework: ESX Detected - Using Table: "..DB.table.."^0")
    elseif GetResourceState("qb-core") == "started" then
        QBCore = exports["qb-core"]:GetCoreObject()
        Framework = "QBCore"
        DB.table = "player_vehicles"
        DB.owner = "citizenid"
        DB.vehicle = "mods"
        print("^2[TB_GARAGE] Framework: QBCore Detected - Using Table: "..DB.table.."^0")
    end
end)

local function Trim(value)
    if not value then return nil end
    return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

local function GetIdentifier(source)
    if Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier
    elseif Framework == "QBCore" then
        local Player = QBCore.Functions.GetPlayer(source)
        return Player and Player.PlayerData.citizenid
    end
end

local function GetJobName(source)
    if Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.job.name or "none"
    elseif Framework == "QBCore" then
        local Player = QBCore.Functions.GetPlayer(source)
        return Player and Player.PlayerData.job.name or "none"
    end
    return "none"
end

local function DeductMoney(source, amount)
    if amount <= 0 then return true end
    if Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer.getMoney() >= amount then
            xPlayer.removeMoney(amount)
            return true
        end
    elseif Framework == "QBCore" then
        local Player = QBCore.Functions.GetPlayer(source)
        return Player.Functions.RemoveMoney('cash', amount)
    end
    return false
end

local function IsAdmin(source)
    if source == 0 then return true end
    if Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(source)
        local g = xPlayer.getGroup()
        return (g == 'admin' or g == 'superadmin' or g == 'mod')
    elseif Framework == "QBCore" then
        return QBCore.Functions.HasPermission(source, 'admin')
    end
    return false
end

RegisterNetEvent("tb_garage:getVehicles", function(currentGarage, requestType)
    local src = source
    local identifier = GetIdentifier(src)
    local jobName = GetJobName(src)
    local isPolice = (jobName == 'police')

    local query = string.format(
        "SELECT plate, %s as vehicle, stored, parking, impound, impound_fee, impound_reason, impound_release_date, nickname FROM %s WHERE %s = ?", 
        DB.vehicle, DB.table, DB.owner
    )
    local queryParams = { identifier }

    if isPolice and requestType == 'impound' then
        query = string.format(
            "SELECT plate, %s as vehicle, stored, parking, impound, impound_fee, impound_reason, impound_release_date FROM %s WHERE impound = 1", 
            DB.vehicle, DB.table
        )
        queryParams = {}
    end

    local result = MySQL.query.await(query, queryParams)
    local vehiclesToSend = {}

    local activePlates = {}
    for _, veh in ipairs(GetAllVehicles()) do
        local p = GetVehicleNumberPlateText(veh)
        if p then activePlates[Trim(p)] = true end
    end

    if result then
        for _, dbVeh in ipairs(result) do
            local cleanPlate = Trim(dbVeh.plate)
            local isImpounded = (dbVeh.impound == 1 or dbVeh.impound == true)
            local isStored = (dbVeh.stored == 1 or dbVeh.stored == true)

            if isImpounded then
                dbVeh.state = "in_impound"
            elseif isStored then
                dbVeh.state = "stored"
            else
                dbVeh.state = activePlates[cleanPlate] and "out" or "impounded"
            end

            dbVeh.impound = isImpounded and 1 or 0
            dbVeh.stored = isStored and 1 or 0

            if requestType == 'impound' then
                if isImpounded then table.insert(vehiclesToSend, dbVeh) end
            else
                table.insert(vehiclesToSend, dbVeh)
            end
        end
    end

    TriggerClientEvent("tb_garage:sendVehicles", src, vehiclesToSend, requestType, isPolice)
end)

RegisterNetEvent("tb_garage:spawnVehicle", function(plate, requestGarage)
    local src = source
    local identifier = GetIdentifier(src)
    local cleanPlate = Trim(plate)

    local query = string.format("SELECT * FROM %s WHERE %s = ? AND plate LIKE ? AND parking = ? AND stored = 1", DB.table, DB.owner)
    local result = MySQL.single.await(query, { identifier, '%'..cleanPlate..'%', requestGarage })

    if not result then 
        return TriggerClientEvent("ox_lib:notify", src, {type="error", description="Vehicle not found here!"})
    end

    local rawData = result.mods or result.vehicle
    local vehicleProps = {}

    if rawData and rawData ~= "" then
        vehicleProps = (type(rawData) == "table") and rawData or json.decode(rawData)
    end

    if not vehicleProps.model then
        local fallbackModel = result.hash or result.model or result.vehicle_model
        if fallbackModel then
            vehicleProps.model = fallbackModel
        else
            vehicleProps.model = result.vehicle 
        end
    end

    if not vehicleProps.model or vehicleProps.model == 0 or vehicleProps.model == "" then
        return TriggerClientEvent("ox_lib:notify", src, {type="error", description="Database Error: No Model Hash found!"})
    end

    MySQL.update(string.format("UPDATE %s SET stored = 0 WHERE plate LIKE ?", DB.table), {'%'..cleanPlate..'%'})
    TriggerClientEvent("tb_garage:spawn", src, vehicleProps, requestGarage)
end)

RegisterNetEvent("tb_garage:storeOwnedVehicle", function(plate, vehicleProps, garageName)
    local src = source
    local identifier = GetIdentifier(src)
    local cleanPlate = Trim(plate)

    local updateQuery = string.format("UPDATE %s SET stored = 1, %s = ?, parking = ? WHERE plate = ? AND %s = ?", DB.table, DB.vehicle, DB.owner)
    
    MySQL.update(updateQuery, { json.encode(vehicleProps), garageName, cleanPlate, identifier })
    
    TriggerClientEvent("ox_lib:notify", src, { type = "success", description = "Vehicle Stored!" })
end)

RegisterNetEvent("tb_garage:submitImpound", function(plate, reason, time, fine)
    local src = source
    local cleanPlate = Trim(plate)
    local releaseDate = os.time() + (tonumber(time) * 60)
    local fee = tonumber(fine)

    local query = string.format("UPDATE %s SET impound = 1, stored = 1, impound_reason = ?, impound_release_date = ?, impound_fee = ? WHERE plate = ?", DB.table)
    local check = MySQL.update.await(query, { reason, releaseDate, fee, cleanPlate })

    if check > 0 then
        for _, v in ipairs(GetAllVehicles()) do
            if Trim(GetVehicleNumberPlateText(v)) == cleanPlate then DeleteEntity(v) break end
        end
        TriggerClientEvent("ox_lib:notify", src, {type="success", description="Vehicle Impounded."})
    else
        TriggerClientEvent("ox_lib:notify", src, {type="error", description="Vehicle not owned by a player."})
    end
end)

RegisterNetEvent("tb_garage:retrieveImpound", function(plate)
    local src = source
    local jobName = GetJobName(src)
    local isPolice = (jobName == 'police')

    local query = string.format("SELECT * FROM %s WHERE plate = ?", DB.table)
    local result = MySQL.single.await(query, {plate})
    
    if not result then 
        return TriggerClientEvent("ox_lib:notify", src, {type="error", description="Vehicle not found in database."})
    end

    if not isPolice and os.time() < result.impound_release_date then
        local minsLeft = math.ceil((result.impound_release_date - os.time()) / 60)
        return TriggerClientEvent("ox_lib:notify", src, {type="error", description="Vehicle locked for "..minsLeft.." minutes."})
    end

    local cost = isPolice and 0 or (result.impound_fee or 0)
    
    if DeductMoney(src, cost) then
        local vehicleData = nil
        local rawData = result[DB.vehicle] or result.mods or result.vehicle

        if rawData and rawData ~= "" then
            vehicleData = (type(rawData) == "table") and rawData or json.decode(rawData)
        else
            vehicleData = {}
        end

        if not vehicleData.model then
            vehicleProps.model = result.hash or result.model or result.vehicle
        end

        local updateQuery = string.format("UPDATE %s SET impound = 0, stored = 0, impound_fee = 0 WHERE plate = ?", DB.table)
        MySQL.update(updateQuery, {plate}, function(affectedRows)
            if affectedRows > 0 then
                TriggerClientEvent("tb_garage:spawn", src, vehicleData)
                TriggerClientEvent("ox_lib:notify", src, {type="success", description="Vehicle released"})
            end
        end)
    else
        TriggerClientEvent("ox_lib:notify", src, {type="error", description="Insufficient funds. Need $"..cost})
    end
end)

RegisterNetEvent("tb_garage:payReturn", function(plate)
    local src = source
    local cost = Config.ReturnSystem.ChargeFee and Config.ReturnSystem.Price or 0

    if DeductMoney(src, cost) then
        local query = string.format("UPDATE %s SET stored = 1 WHERE plate = ?", DB.table)
        
        MySQL.update(query, {plate}, function(affectedRows)
            if affectedRows > 0 then
                TriggerClientEvent("ox_lib:notify", src, {type="success", description="Vehicle returned"})
                TriggerClientEvent("tb_garage:returnSuccessful", src, plate)
            else
                TriggerClientEvent("ox_lib:notify", src, {type="error", description="Database error!"})
            end
        end)
    else
        TriggerClientEvent("ox_lib:notify", src, {type="error", description="Need $"..cost})
    end
end)

RegisterNetEvent("tb_garage:transferVehicle", function(plate, type, target)
    local src = source
    local identifier = GetIdentifier(src)
    local cleanPlate = Trim(plate)

    local query = string.format("SELECT plate FROM %s WHERE %s = ? AND plate = ?", DB.table, DB.owner)
    local result = MySQL.single.await(query, { identifier, cleanPlate })
    
    if not result then return TriggerClientEvent("ox_lib:notify", src, { type = "error", description = "You do not own this vehicle." }) end

    local cost = 0
    if type == "garage" and Config.TransferSystem.GarageFeeEnabled then cost = Config.TransferSystem.GarageFee
    elseif type == "player" and Config.TransferSystem.PlayerFeeEnabled then cost = Config.TransferSystem.PlayerFee end

    if not DeductMoney(src, cost) then
        return TriggerClientEvent("ox_lib:notify", src, { type = "error", description = "Need $" .. cost })
    end

    if type == "player" then
        local targetId = tonumber(target)
        local targetIdent = GetIdentifier(targetId)
        if targetIdent then
            local updateQuery = string.format("UPDATE %s SET %s = ? WHERE plate = ?", DB.table, DB.owner)
            MySQL.update(updateQuery, { targetIdent, cleanPlate })
            
            TriggerClientEvent("ox_lib:notify", src, { type = "success", description = "Transferred to ID: " .. targetId })
            TriggerClientEvent("ox_lib:notify", targetId, { type = "inform", description = "You received vehicle: " .. cleanPlate })
        else
            if cost > 0 then 
                 if Framework == "ESX" then ESX.GetPlayerFromId(src).addMoney(cost) 
                 else QBCore.Functions.GetPlayer(src).Functions.AddMoney('cash', cost) end
            end
            TriggerClientEvent("ox_lib:notify", src, { type = "error", description = "Player not found." })
        end
    elseif type == "garage" then
        local updateQuery = string.format("UPDATE %s SET parking = ? WHERE plate = ?", DB.table)
        MySQL.update(updateQuery, { target, cleanPlate })
        TriggerClientEvent("ox_lib:notify", src, { type = "success", description = "Transferred to " .. target })
    end
end)

RegisterNetEvent("tb_garage:toggleLock", function(netId, plate)
    local src = source
    local identifier = GetIdentifier(src)
    local cleanPlate = Trim(plate)
    
    local query = string.format("SELECT %s FROM %s WHERE %s = ? AND plate = ?", DB.owner, DB.table, DB.owner)
    local isOwner = MySQL.single.await(query, { identifier, cleanPlate })
    
    local hasJobKey = (JobVehicleKeys[cleanPlate] and JobVehicleKeys[cleanPlate] == identifier)

    if isOwner or hasJobKey then
        TriggerClientEvent("tb_garage:receiveLockUpdate", src, netId, true)
    else
        TriggerClientEvent("ox_lib:notify", src, { type = "error", description = "No keys for this vehicle." })
        TriggerClientEvent("tb_garage:receiveLockUpdate", src, netId, false)
    end
end)

RegisterNetEvent("tb_garage:remoteAction", function(netId, plate, action)
    local src = source
    local identifier = GetIdentifier(src)
    local cleanPlate = Trim(plate)
    
    local query = string.format("SELECT %s FROM %s WHERE %s = ? AND plate = ?", DB.owner, DB.table, DB.owner)
    local isOwner = MySQL.single.await(query, { identifier, cleanPlate })
    
    if isOwner then
        TriggerClientEvent("tb_garage:executeRemoteAction", src, netId, action)
    else
        TriggerClientEvent("ox_lib:notify", src, { type = "error", description = "No keys for this vehicle." })
    end
end)

RegisterNetEvent("tb_garage:spawnJobVehicle", function(vehicleData, spawnPoint, type)
    local src = source
    local ped = GetPlayerPed(src)
    local identifier = GetIdentifier(src)
    
    local plateText = (vehicleData.plate or "JOB") .. " " .. math.random(100, 999)
    local vehicle = CreateVehicle(vehicleData.model, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, true)

    local attempts = 0
    while not DoesEntityExist(vehicle) and attempts < 50 do Wait(10); attempts = attempts + 1 end

    if DoesEntityExist(vehicle) then
        SetVehicleNumberPlateText(vehicle, plateText)
        TaskWarpPedIntoVehicle(ped, vehicle, -1)
        JobVehicleKeys[Trim(plateText)] = identifier
        TriggerClientEvent("ox_lib:notify", src, {type="success", description="Job Vehicle Spawned. Keys added."})
    end
end)

RegisterNetEvent("tb_garage:removeJobKey", function(plate)
    JobVehicleKeys[Trim(plate)] = nil
end)

if Config.PrivateGarages.ENABLE then
    RegisterCommand(Config.PrivateGarages.create_chat_command, function(source, args)
        local src = source
        if not IsAdmin(src) and not Config.PrivateGarages.Authorized_Jobs[GetJobName(src)] then 
            return TriggerClientEvent("ox_lib:notify", src, {type="error", description="No Permissions"}) 
        end

        local targetId, garageName = tonumber(args[1]), args[2]
        if not targetId or not garageName then return end

        local targetIdent = GetIdentifier(targetId)
        if not targetIdent then return end

        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        local rad = math.rad(heading)
        local sX, sY = coords.x + (-math.sin(rad) * 5.0), coords.y + (math.cos(rad) * 5.0)

        MySQL.insert('INSERT INTO private_garages (identifier, name, coords, spawnPoint) VALUES (?, ?, ?, ?)', 
            {targetIdent, garageName, json.encode(coords), json.encode({x=sX, y=sY, z=coords.z, w=heading})}, 
            function(id)
                TriggerClientEvent("ox_lib:notify", src, {type="success", description="Garage Created"})
                TriggerClientEvent("tb_garage:syncPrivateGarages", targetId)
            end
        )
    end)

    RegisterNetEvent("tb_garage:requestPrivateGarages", function()
        local src = source
        local identifier = GetIdentifier(src)
        local result = MySQL.query.await('SELECT * FROM private_garages WHERE identifier = ?', {identifier})
        local garages = {}

        if result then
            for _, v in pairs(result) do
                local c, s = json.decode(v.coords), json.decode(v.spawnPoint)
                table.insert(garages, {
                    name = v.name,
                    coords = vector3(c.x, c.y, c.z),
                    spawnPoint = vector4(s.x, s.y, s.z, s.w),
                    isPrivate = true
                })
            end
        end
        TriggerClientEvent("tb_garage:receivePrivateGarages", src, garages)
    end)
end

if Config.AdminCommands.Enabled then
    RegisterCommand(Config.AdminCommands.GiveCommand, function(source, args)
        if IsAdmin(source) then TriggerClientEvent("tb_garage:adminGetVehicleData", source, tonumber(args[1])) end
    end)

    RegisterNetEvent("tb_garage:adminSaveVehicle", function(targetId, vehicleProps, vehicleType, garageName)
        local src = source
        if not IsAdmin(src) then return end
        
        local targetIdent = GetIdentifier(targetId)
        local plate = vehicleProps.plate

        local query = string.format(
            "INSERT INTO %s (%s, plate, %s, stored, parking) VALUES (?, ?, ?, ?, ?)", 
            DB.table, DB.owner, DB.vehicle
        )
        
        MySQL.insert(query, { 
            targetIdent, 
            plate, 
            json.encode(vehicleProps), 
            1, 
            garageName 
        }, function()
            if src ~= 0 then
                TriggerClientEvent("ox_lib:notify", src, {type="success", description="Vehicle Given to ID: "..targetId})
            end
            
            if targetId then
                TriggerClientEvent("ox_lib:notify", targetId, {type="success", description="A new vehicle has been added to your garage"})
            end
        end)
    end)

    RegisterCommand(Config.AdminCommands.DeleteCommand, function(source)
        if IsAdmin(source) then TriggerClientEvent("tb_garage:adminRequestDelete", source) end
    end)

    RegisterNetEvent("tb_garage:adminConfirmDelete", function(plate)
        local src = source
        if not IsAdmin(src) then return end
        
        local query = string.format("DELETE FROM %s WHERE plate = ?", DB.table)
        
        MySQL.update(query, {Trim(plate)}, function(affectedRows)
            if affectedRows > 0 then
                TriggerClientEvent("ox_lib:notify", src, {type="success", description="Vehicle permanently deleted from database."})
            else
                TriggerClientEvent("ox_lib:notify", src, {type="error", description="Error: Vehicle not found in database."})
            end
        end)
    end)
end

RegisterNetEvent("tb_garage:sendToGarage", function(plate, fee)
    local src = source
    local identifier = GetIdentifier(src)
    local cleanPlate = Trim(plate)
    local sendFee = tonumber(fee) or 0
    
    local defaultGarage = "Central Garage" 

    if DeductMoney(src, sendFee) then
        local query = string.format(
            "UPDATE %s SET impound = 0, stored = 1, parking = ?, impound_fee = 0, impound_reason = NULL WHERE plate = ? AND %s = ?", 
            DB.table, DB.owner
        )
        
        local check = MySQL.update.await(query, { defaultGarage, cleanPlate, identifier })

        if check > 0 then
            TriggerClientEvent("ox_lib:notify", src, {
                type = "success", 
                description = "Fine Paid: $"..sendFee..". Vehicle transferred to " .. defaultGarage 
            })
        else
            TriggerClientEvent("ox_lib:notify", src, {type = "error", description = "Database error: Could not find vehicle to transfer."})
        end
    else
        TriggerClientEvent("ox_lib:notify", src, {type = "error", description = "You cannot afford the fine of $"..sendFee})
    end
end)

RegisterNetEvent("tb_garage:renameVehicle", function(plate, nickname)
    local src = source
    local identifier = GetIdentifier(src)
    local cleanPlate = Trim(plate)

    local nameToSave = string.sub(nickname, 1, 20)

    local query = string.format(
        "UPDATE %s SET nickname = ? WHERE plate = ? AND %s = ?", 
        DB.table, DB.owner
    )

    local check = MySQL.update.await(query, { nameToSave, cleanPlate, identifier })

    if check > 0 then
        TriggerClientEvent("ox_lib:notify", src, {type="success", description="Vehicle renamed to: " .. nameToSave})
    else
        TriggerClientEvent("ox_lib:notify", src, {type="error", description="Failed to rename vehicle."})
    end
end)