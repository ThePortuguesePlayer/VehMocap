----------------------------
-- VEHICLE MOTION CAPTURE --
----------------------------

local localPlayer = getLocalPlayer() 
local vehicle 
local logTable = {}
local isRecording = false
local firstSave
local lastSave
local settings = {recordDriver = false, recordCamera = true, msPerKeyframe = 33, filePath = "./captures/", memUseRefresh = 2000, showLabel = true}
local frameCount = 0
local vehType = "Automobile"
local resMemUse
local lastMemRefresh
local screenX
local labelColor = 0xFFFFFFFF

function init()
    outputChatBox("Vehicle Motion Capture activated.")
    outputChatBox("Start and stop the capture by pressing * on your numpad or with the command /s.")
end

function clearData()
    frameCount = 0 
    logTable = {}
    lastSave = nil
    firstSave = nil
    resMemUse = nil
    lastMemRefresh = nil
    collectgarbage("collect")
end

-- CAPTURE MANAGEMENT FUNCTIONS ------

function toggleRecording(playerSource)
    if isRecording then
        isRecording = false
        local fileName = getFileName()
        local fullPath = settings.filePath .. fileName
        outputChatBox("The recording has stopped. Saving file to " .. fullPath .. "..." )
        local success = exportFile(fullPath)
        if success then
            outputChatBox(success .. " has been saved.")
        else
            outputChatBox("No file has been generated.")
        end
        clearData()
    elseif isPedInVehicle(localPlayer) then
        refreshMemoryUsage(getTickCount())
        screenX = guiGetScreenSize()
        screenX = screenX/2-40
        isRecording = startRecording()
        if isRecording then 
            outputChatBox("The recording process has started. Saving keyframes every " .. settings.msPerKeyframe .. "ms. (" .. math.floor(1000/settings.msPerKeyframe) .. "fps)")
        else
            outputChatBox("The recording process has failed to start.")
        end
    end
end

function recordKeyframe()
    if isRecording then
        local tick = getTickCount()
        if lastSave == nil then
            firstSave = tick
            lastSave = firstSave
        end
        local frameTime = tick - lastSave
        if frameTime >= settings.msPerKeyframe then
            frameID = tostring(frameCount)
            if vehType == "Automobile" then
                logTable[frameID] = getKeyframeAutomobile(vehicle)
            -- Insert support for other vehicle types here.
            end
            if settings.recordCamera == true then
                logTable[frameID]["c"] = getKeyframeCamera()
            end
            if settings.recordDriver == true then
                logTable[frameID]["P"] = saveKeyframeDriver(localPlayer)
            end
        end
        if (tick - lastMemRefresh) >= settings.memUseRefresh then
            refreshMemoryUsage(tick)
        end
        if settings.showLabel == true then
            drawMemoryUsage()
        end
    end
end

function refreshMemoryUsage(tick)
    resMemUse = collectgarbage("count")
    lastMemRefresh = tick
    if labelColor == 0xFFFFFFFF then
        labelColor = 0xFFFF0000
    else
        labelColor = 0xFFFFFFFF
    end
end

function drawMemoryUsage()
    local mb = string.sub(tostring(resMemUse * 0.001), 1, 5)
    dxDrawText("RECORDING\n"..mb.." MB", screenX, 8, screenX+80, 42, labelColor, 1.0, "unifont", "center", "top", false, false, true)
end

function playerHasExited()
    --[[ A note: 
    This resource can be made to support recording more than 1 vehicle at a time.
    In reality, the player does not have to be inside the vehicle for the capture to be possible,
    I just made it stop on vehicle exit because at this moment I have no use for recording cars I'm not driving. ]]
    if isRecording then
        isRecording = false
        outputChatBox("The recording stopped due to the player leaving the vehicle.")
        local fullPath = settings.filePath .. getFileName()
        local success = exportFile(fullPath)
        if success then
            outputChatBox(success .. " has been saved.")
        else
            outputChatBox("No file has been generated.")
        end
        clearData()
    end
    outputChatBox("Vehicle Motion Capture deactivated.")
end

function startRecording()
    vehicle = getPedOccupiedVehicle(localPlayer)
    if vehicle then
        vehType = getVehicleType(vehicle)
        return true
    else
        return false
    end
end

function exportFile(path)
    local file = fileCreate(path)
    if file then
        logTable["i"] = getInfo()
        local json = toJSON(logTable) -- If adapting the script to record more than 1 vehicle, concatenate the other tables converted toJSON string to this one to save all vehicles into the same file.
        if json then
            fileWrite(file, json)
            local result = fileGetPath(file)
            fileClose(file)
            return result
        end
    end
    return false
end

-- CAPTURE TYPES ----------------

function saveKeyframeDriver(driver)
    local driverPX, driverPY, driverPZ = getElementPosition(driver)
    local driverRX, driverRY, driverRZ = getElementRotation(driver)
    local boneIDs = {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 21,
        22, 23, 24, 25, 26, 31, 32, 33,
        34, 35, 36, 41, 42, 43, 44, 51,
        52, 53, 54, 201, 301, 302
    }
    local bonesTable = {P = {pX = driverPX, pY = driverPY, pZ = driverPZ, rX = driverRX, rY = driverRY, rZ = driverRZ}}
    for idx, id in pairs(boneIDs) do 
        local posX, posY, posZ = getElementBonePosition(driver, id)
        if idx >= 30 then
            local boneMatrix = getElementBoneMatrix(driver, id)
            local rotX, rotY, rotZ = math.asin(-boneMatrix[3][2]), math.atan2(boneMatrix[3][1], boneMatrix[3][3]), math.atan2(boneMatrix[1][2], boneMatrix[2][2])
            bonesTable[id] = {pX = posX-driverPX, pY = posY-driverPY, pZ = posZ-driverPZ, rX = rotX, rY = rotY, rZ = rotZ}
        else
            local rotX, rotY, rotZ, rotW = getElementBoneQuaternion(driver, id)
            bonesTable[id] = {pX = posX-driverPX, pY = posY-driverPY, pZ = posZ-driverPZ, rX = rotX, rY = rotY, rZ = rotZ, rW = rotW}
        end
    end
    return bonesTable
end

function getKeyframeCamera()
    local camX, camY, camZ, tgtX, tgtY, tgtZ, roll, fieldOfView = getCameraMatrix(localPlayer)
    return {cX = camX, cY = camY, cZ = camZ, tX = tgtX, tY = tgtY, tZ = tgtZ, r = roll, fov = fieldOfView}
end

function getKeyframeAutomobile(theVehicle)
    local vehPX, vehPY, vehPZ = getElementPosition(theVehicle)
    local vehRX, vehRY, vehRZ = getElementRotation(theVehicle)
    local lfpX, lfpY, lfpZ =  getVehicleComponentPosition(theVehicle, "wheel_lf_dummy")
    local lfrX, lfrY, lfrZ =  getVehicleComponentRotation(theVehicle, "wheel_lf_dummy")
    local rfpX, rfpY, rfpZ = getVehicleComponentPosition(theVehicle, "wheel_rf_dummy")
    local rfrX, rfrY, rfrZ = getVehicleComponentRotation(theVehicle, "wheel_rf_dummy")
    local lbpX, lbpY, lbpZ = getVehicleComponentPosition(theVehicle, "wheel_lb_dummy")
    local lbrX, lbrY, lbrZ = getVehicleComponentRotation(theVehicle, "wheel_lb_dummy")
    local rbpX, rbpY, rbpZ = getVehicleComponentPosition(theVehicle, "wheel_rb_dummy")
    local rbrX, rbrY, rbrZ = getVehicleComponentRotation(theVehicle, "wheel_rb_dummy")
    local saveTime = getTickCount()
    local frameTime = saveTime - lastSave
    lastSave = saveTime
    frameCount = frameCount + 1
    local velocity = Vector3(getElementVelocity(theVehicle))
    local braking = isBraking()
    local reversing = false
    local state
    local vehVel
    if braking then
        reversing = isReversing(velocity)
        state = "B"
    end
    if reversing then
        --vehVel = - math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
        vehVel = -velocity.length
        state = "R"
    else
        --vehVel = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
        vehVel = velocity.length
    end
    if state == nil then
        if isAccelerating() then
            state = "A"
        else 
            state = "I"
        end
    end
    return {
        ["fT"] = frameTime,
        ["v"] = {pX = vehPX, pY = vehPY, pZ = vehPZ, rX = vehRX, rY = vehRY, rZ = vehRZ},
        ["lf"] = {pX = lfpX, pY = lfpY, pZ = lfpZ, rX = lfrX, rY = lfrY, rZ = lfrZ},
        ["rf"] = {pX = rfpX, pY = rfpY, pZ = rfpZ, rX = rfrX, rY = rfrY, rZ = rfrZ},
        ["lb"] = {pX = lbpX, pY = lbpY, pZ = lbpZ, rX = lbrX, rY = lbrY, rZ = lbrZ},
        ["rb"] = {pX = rbpX, pY = rbpY, pZ = rbpZ, rX = rbrX, rY = rbrY, rZ = rbrZ},
        ["s"] = state, --states: I_dle, A_ccelerating, B_raking, R_eversing (priority lowest to highest)
        ["V"] = vehVel, -- velocity units in meters per 1/50th of a second
    }
end

-- HELPER FUNCTIONS ---------

function getInfo()
    local info = {
        ["kfPS"] = math.floor(1000 / settings.msPerKeyframe), -- keyframes Per Second
        ["vN"] = getVehicleName(vehicle),
        ["d"] = (lastSave - firstSave) * 0.001, -- duration time in seconds
        ["fC"] = frameCount,
        ["vT"] = vehType,
    }
    if settings.recordDriver == true then
        info["pM"] = getDriverSkin(localPlayer)
    end
    return info
end

function getDriverSkin(theDriver)
    local skinsTable = {
        [0] = "cj", [1] = "truth", [2] = "maccer", [3] = "cdeput", [4] = "sfpdm1", 
        [5] = "bb", [6] = "wfycrp", [7] = "male01", [8] = "wmycd2", [9] = "bfori",
        [10] = "bfost", [11] = "vbfycrp", [12] = "bfyri", [13] = "bfyst", [14] = "bmori",
        [15] = "bmost", [16] = "bmyap", [17] = "bmybu", [18] = "bmybe", [19] = "bmydj",
        [20] = "bmyri", [21] = "bmycr", [22] = "bmyst", [23] = "wmybmx", [24] = "wbdyg1",
        [25] = "wbdyg2", [26] = "wmybp", [27] = "wmycon", [28] = "bmydrug", [29] = "wmydrug",
        [30] = "hmydrug", [31] = "dwfolc", [32] = "dwmolc1", [33] = "dwmolc2", [34] = "dwmylc1",
        [35] = "hmogar", [36] = "wmygol1", [37] = "wmygol2", [38] = "hfori", [39] = "hfost",
        [40] = "hfyri", [41] = "hfyst", [42] = "suzie", [43] = "hmori", [44] = "hmost", [45] = "hmybe",
        [46] = "hmyri", [47] = "hmycr", [48] = "hmyst", [49] = "omokung", [50] = "wmymech", [51] = "bmymoun",
        [52] = "wmymoun", [53] = "ofori", [54] = "ofost", [55] = "ofyri", [56] = "ofyst",
        [57] = "omori", [58] = "omost", [59] = "omyri", [60] = "omyst", [61] = "wmyplt",
        [62] = "wmopj", [63] = "bfypro", [64] = "hfypro", [65] = "vwmyap", [66] = "bmypol1", [67] = "bmypol2",
        [68] = "wmoprea", [69] = "sbfyst", [70] = "wmosci", [71] = "wmysgrd", [72] = "swmyhp1",
        [73] = "swmyhp2", [75] = "swfopro", [76] = "wfystew", [77] = "swmotr1", [78] = "wmotr1",
        [79] = "bmotr1", [80] = "vbmybox", [81] = "vwmybox", [82] = "vhmyelv", [83] = "vbmyelv",
        [84] = "vimyelv", [85] = "vwfypro", [86] = "vhfyst", [87] = "vwfyst1", [88] = "wfori", [89] = "wfost",
        [90] = "wfyjg", [91] = "wfyri", [92] = "wfyro", [93] = "wfyst", [94] = "wmori",
        [95] = "wmost", [96] = "wmyjg", [97] = "wmylg", [98] = "wmyri", [99] = "wmyro", [100] = "wmycr",
        [101] = "wmyst", [102] = "ballas1", [103] = "ballas2", [104] = "ballas3", [105] = "fam1",
        [106] = "fam2", [107] = "fam3", [108] = "lsv1", [109] = "lsv2", [110] = "lsv3",
        [111] = "maffa", [112] = "maffb", [113] = "maffboss", [114] = "vla1", [115] = "vla2",
        [116] = "vla3", [117] = "triada", [118] = "triadb", [119] = "lvpdm1", [120] = "triboss",
        [121] = "dnb1", [122] = "dnb2", [123] = "dnb3", [124] = "vmaff1", [125] = "vmaff2",
        [126] = "vmaff3", [127] = "vmaff4", [128] = "dnmylc", [129] = "dnfolc1", [130] = "dnfolc2",
        [131] = "dnfylc", [132] = "dnmolc1", [133] = "dnmolc2", [134] = "sbmotr2", [135] = "swmotr2",
        [136] = "sbmytr3", [137] = "swmotr3", [138] = "wfybe", [139] = "bfybe", [140] = "hfybe",
        [141] = "sofybu", [142] = "sbmyst", [143] = "sbmycr", [144] = "bmycg", [145] = "wfycrk",
        [146] = "hmycm", [147] = "wmybu", [148] = "bfybu", [150] = "wfybu",
        [151] = "dwfylc1", [152] = "wfypro", [153] = "wmyconb", [154] = "wmybe", [155] = "wmypizz",
        [156] = "bmobar", [157] = "cwfyhb", [158] = "cwmofr", [159] = "cwmohb1", [160] = "cwmohb2",
        [161] = "cwmyfr", [162] = "cwmyhb1", [163] = "bmyboun", [164] = "wmyboun", [165] = "wmomib",
        [166] = "bmymib", [167] = "wmybell", [168] = "bmochil", [169] = "sofyri", [170] = "somyst",
        [171] = "vwmybjd", [172] = "vwfycrp", [173] = "sfr1", [174] = "sfr2", [175] = "sfr3",
        [176] = "bmybar", [177] = "wmybar", [178] = "wfysex", [179] = "wmyammo", [180] = "bmytatt",
        [181] = "vwmycr", [182] = "vbmocd", [183] = "vbmycr", [184] = "vhmycr", [185] = "sbmyri",
        [186] = "somyri", [187] = "somybu", [188] = "swmyst", [189] = "wmyva", [190] = "copgrl3",
        [191] = "gungrl3", [192] = "mecgrl3", [193] = "nurgrl3", [194] = "crogrl3", [195] = "ganggrl3",
        [196] = "cwfofr", [197] = "cwfohb", [198] = "cwfyfr1", [199] = "cwfyfr2", [200] = "cwmyhb2",
        [201] = "dwfylc2", [202] = "dwmylc2", [203] = "omykara", [204] = "wmykara", [205] = "wfyburg",
        [206] = "vwmycd", [207] = "vhfypro", [209] = "omonood", [210] = "omoboat", [211] = "wfyclot",
        [212] = "vwmotr1", [213] = "vwmotr2", [214] = "vwfywai", [215] = "sbfori", [216] = "swfyri",
        [217] = "wmyclot", [218] = "sbfost", [219] = "sbfyri", [220] = "sbmocd", [221] = "sbmori",
        [222] = "sbmost", [223] = "shmycr", [224] = "sofori", [225] = "sofost", [226] = "sofyst",
        [227] = "somobu", [228] = "somori", [229] = "somost", [230] = "swmotr5", [231] = "swfori",
        [232] = "swfost", [233] = "swfyst", [234] = "swmocd", [235] = "swmori", [236] = "swmost",
        [237] = "shfypro", [238] = "sbfypro", [239] = "swmotr4", [240] = "swmyri", [241] = "smyst", [242] = "smyst2",
        [243] = "sfypro", [244] = "vbfyst2", [245] = "vbfypro", [246] = "vhfyst3", [247] = "bikera",
        [248] = "bikerb", [249] = "bmypimp", [250] = "swmycr", [251] = "wfylg", [252] = "wmyva2",
        [253] = "bmosec", [254] = "bikdrug", [255] = "wmych", [256] = "sbfystr", [257] = "swfystr",
        [258] = "heck1", [259] = "heck2", [260] = " bmycon", [261] = "wmycd1", [262] = "bmocd",
        [263] = "vwfywa2", [264] = "wmoice", [265] = "tenpen", [266] = "pulaski", [267] = "hern",
        [268] = "dwayne", [269] = "smoke", [270] = "sweet", [271] = "ryder", [272] = "forelli",
        [273] = "mediatr", [274] = "laemt1", [275] = "lvemt1", [276] = "sfemt1", [277] = "lafd1", [278] = "lvfd1",
        [279] = "sffd1", [280] = "lapd1", [281] = "sfpd1", [282] = "lvpd1", [283] = "csher",
        [284] = "lapdm1", [285] = "swat", [286] = "fbi", [287] = "army", [288] = "dsher",
        [290] = "rose", [291] = "paul", [292] = "cesar", [293] = "ogloc", [294] = "wuzimu",
        [295] = "torino", [296] = "jizzy", [297] = "maddogg", [298] = "cat", [299] = "claude",
        [300] = "ryder2", [301] = "ryder3", [302] = "emmet", [303] = "andre", [304] = "kendl",
        [305] = "jethro", [306] = "zero", [307] = "tbone", [308] = "sindaco", [309] = "janitor",
        [310] = "bbthin", [311] = "smokev", [312] = "psycho", 
        }
    local id = getElementModel(theDriver)
    if skinsTable[id] ~= nil then
        return skinsTable[id]
    end
    return tostring(id)
end

function getFileName()
    -- format: YY-DDD-HH-MM-SS-vehicle
    local vehName = getVehicleName(vehicle)
    local time = getRealTime()
    local stringName = time.year + 1900 .. "-" .. time.yearday .. "-" .. time.hour .. "-" .. time.minute .. "-" .. time.second .. "-" .. vehName .. ".json"
    return stringName
end

function isReversing(velocity)
    local matrix = getElementMatrix(vehicle)
    local vectorDirection = (velocity.x * matrix[2][1]) + (velocity.y * matrix[2][2]) + (velocity.z * matrix[2][3])
    if (getVehicleCurrentGear(vehicle) == 0 and vectorDirection < 0) then
        return true
    end
    return false
end

function isBraking()
    return getPedControlState(localPlayer,"brake_reverse")
end

function isAccelerating()
    return getPedControlState(localPlayer,"accelerate") 
end

-- SETTING SETTER FUNCTIONS -------

function setSavePath(playerSource, path)
    if path ~= "" then
        settings.filePath = "./" + path
        if sub(path, #path, #path) ~= "/" then
            settings.filePath = settings.filePath + "/"
        end
    end
end

function setKeyframesPerSecond(playerSource, fps)
    settings.msPerKeyframe = math.floor(1000/tonumber(fps))
end

function setMemRefreshRate(playerSource, value)
    settings.memUseRefresh = tonumber(value)
end

function setShowLabel(playerSource)
    settings.showLabel = not settings.showLabel
end

function includeDriver(playerSource)
    if settings.recordDriver == true then
        settings.recordDriver = false
        outputChatBox("Capture will not include the driver model.")
    elseif settings.recordDriver == false then
        settings.recordDriver = true
        outputChatBox("Capture will include the driver model.")
    end
end

function includeCamera(playerSource)
    if settings.recordCamera == true then
        settings.recordCamera = false
        outputChatBox("Capture will not include the camera.")
    elseif settings.recordCamera == false then
        settings.recordCamera = true
        outputChatBox("Capture will include the camera.")
    end
end

-- HANDLERS ---------------

addEventHandler ("onClientPlayerVehicleEnter", localPlayer, init)
addEventHandler ("onClientPlayerVehicleExit", localPlayer, playerHasExited)
addEventHandler("onClientRender", root, recordKeyframe) 
addCommandHandler("s", toggleRecording)
addCommandHandler("kfps", setKeyframesPerSecond)
addCommandHandler("folder", setSavePath)
addCommandHandler("driver", includeDriver)
addCommandHandler("camera", includeCamera)
addCommandHandler("memory", setShowLabel)
addCommandHandler("memrefresh", setMemRefreshRate)
bindKey("num_mul", "up", toggleRecording)