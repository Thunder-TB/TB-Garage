Config = {}

--------------------------------------------------------------------------------
-- GENERAL SETTINGS
--------------------------------------------------------------------------------
Config.EnableRemote = true
Config.EnableKey = true

-- Parking Logic
-- true = Vehicles must be retrieved from the exact garage where they were parked.
-- false = Vehicles can be retrieved from any garage.
Config.StrictParking = true 

-- Job Garages
Config.UseJobGarages = true

--------------------------------------------------------------------------------
-- BLIP SETTINGS
--------------------------------------------------------------------------------
Config.BlipSettings = {
    Display = 4,
    Scale = 0.8,
    Colour = 3,
    
    -- Sprites for specific garage types
    SpriteTypes = {
        ['car'] = 357,   -- Garage Icon
        ['air'] = 43,    -- Helipad Icon
        ['boat'] = 427   -- Boat Anchor Icon
    }
}

--------------------------------------------------------------------------------
-- COMMANDS
--------------------------------------------------------------------------------
Config.AdminCommands = {
    Enabled = true,               
    GiveCommand = "givevehicle",    -- Usage: /givevehicle [ID]
    DeleteCommand = "deletevehicle" -- Usage: /deletevehicle
}

--------------------------------------------------------------------------------
-- ECONOMY & FEES
--------------------------------------------------------------------------------
Config.ReturnSystem = {
    Enabled = true,     
    ChargeFee = true,   
    Price = 500         
}

Config.TransferSystem = {
    GarageFeeEnabled = true,
    GarageFee = 1000,

    PlayerFeeEnabled = false, 
    PlayerFee = 0
}

--------------------------------------------------------------------------------
-- PRIVATE GARAGES
--------------------------------------------------------------------------------
Config.PrivateGarages = {
    ENABLE = true, 
    create_chat_command = 'privategarage',       -- /privategarage [ID] [Name]
    delete_chat_command = 'privategaragedelete', -- /privategaragedelete [ID] [Name]

    Authorized_Jobs = { 
        ['realestate'] = true,
        ['police'] = false, 
    }
}

--------------------------------------------------------------------------------
-- PUBLIC GARAGES
--------------------------------------------------------------------------------
Config.Garages = {
    {
        name = "Main Garage",
        type = "car",
        coords = vec3(213.1082, -803.5333, 30.8581),
        spawnPoint = vec4(226.0684, -791.5635, 30.2696, 247.7036)
    }, 

    {
        name = "Sandy Shores Garage",
        type = "car",
        coords = vec3(1877.2, 3751.2, 33.0), 
        spawnPoint = vec4(1882.2, 3745.0, 33.0, 200.0) 
    },

    {
        name = "Marina Boat House",
        type = "boat",
        coords = vec3(-711.62, -1320.24, 0.6), 
        spawnPoint = vec4(-725.29, -1328.71, 0.0, 137.0)
    },

    {
        name = "LS Airport",
        type = "air",
        coords = vec3(-1008.36, -2975.76, 12.95), 
        spawnPoint = vec4(-1017.58, -2986.32, 13.95, 30.0)
    }
}

--------------------------------------------------------------------------------
-- JOB GARAGES
--------------------------------------------------------------------------------
Config.JobGarages = {
    ['police'] = {
        label = "Police Garage",
        type = "car",
        coords = vec3(436.43, -998.27, 25.7), 
        spawnPoint = vec4(448.33, -998.92, 25.7, 90.0),
        
        vehicles = {
            { model = "police", label = "Crown Vic", grade = 0, plate = "VIC" },
            { model = "police3", label = "Interceptor", grade = 2, plate = "INT" },
        }
    },

    ['ambulance'] = {
        label = "EMS Helipad",
        type = "air",
        coords = vec3(351.68, -587.69, 74.16),
        spawnPoint = vec4(351.68, -587.69, 74.16, 70.0),
        
        vehicles = {
            { model = "polmav", label = "Medic Heli", grade = 0, plate = "MEDIC" }
        }
    }
}

--------------------------------------------------------------------------------
-- IMPOUND SYSTEM
--------------------------------------------------------------------------------
Config.Impound = {
    Enabled = true,
    RetrievePrice = 2500, 
    Command = "impound",
    AuthorizedJobs = { ['police'] = true, ['sheriff'] = true },

    Blip = { 
        Enable = true, 
        Sprite = 67, 
        Color = 47, 
        Scale = 0.8, 
        Name = "Police Impound" 
    },

    Locations = {
        {
            Coords = vec3(409.17, -1623.8, 29.29), 
            SpawnPoint = vec4(401.76, -1631.7, 29.29, 230.0)
        },
        
        {
            Coords = vec3(1730.9652, 3710.7917, 34.1854), 
            SpawnPoint = vec4(1727.9431, 3716.3071, 33.7270, 20.6906)
        },

        {
            Coords = vec3(-193.8311, 6224.8042, 31.0790), 
            SpawnPoint = vec4(-193.8311, 6224.8042, 31.0790, 225.9025)
        },
    }
}