----------------------------
-- VEHICLE MOTION CAPTURE --
----------------------------

local localPlayer = getLocalPlayer() 
local vehicle 
local logTable = {}
local isRecording = false
local firstSave
local lastSave
local keyframesPerSecond = 33 -- 1000ms / 30fps
local filePath = "./captures/" -- Change the save location here.
local frameCount = 0
local vehType = "Automobile"

function init()
    outputChatBox("Vehicle Motion Capture activated.")
    outputChatBox("Start and stop the capture by pressing * on your numpad or with the command /s.")
end

function clearData()
    frameCount = 0 
    logTable = {}
    lastSave = nil
    firstSave = nil
end

function toggleRecording(playerSource)
    if isRecording then
        isRecording = false
        local fileName = getFileName()
        local fullPath = filePath .. fileName
        outputChatBox("The recording has stopped. Saving file to " .. fullPath .. "..." )
        local success = exportFile(fullPath)
        if success then
            outputChatBox(success .. " has been saved.")
        else
            outputChatBox("No file has been generated.")
        end
        clearData()
    elseif isPedInVehicle(localPlayer) then
        isRecording = startRecording()
        if isRecording then 
            outputChatBox("The recording process has started. Saving keyframes every " .. keyframesPerSecond .. "ms. (" .. math.floor(1000/keyframesPerSecond) .. "fps)")
        else
            outputChatBox("The recording process has failed to start.")
        end
    end
end

function recordKeyframe()
    if isRecording then
        if lastSave == nil then
            firstSave = getTickCount()
            lastSave = firstSave
        end
        local frameTime = getTickCount() - lastSave
        if frameTime >= keyframesPerSecond then
            if vehType == "Automobile" then
                saveKeyframeAutomobile()
            -- Insert support for other vehicle types here.
            end
        end
    end
end

function playerHasExited()
    --[[ A note: 
    This resource can be made to support recording more than 1 vehicle at a time.
    In reality, the player does not have to be inside the vehicle for the capture to be possible,
    I just made it stop on vehicle exit because at this moment I have no use for recording cars I'm not driving. ]]
    if isRecording then
        isRecording = false
        outputChatBox("The recording stopped due to the player leaving the vehicle.")
        local fullPath = filePath .. getFileName()
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

function saveKeyframeAutomobile()
    local vehPX, vehPY, vehPZ = getElementPosition(vehicle)
    local vehRX, vehRY, vehRZ = getElementRotation(vehicle)
    local lfpX, lfpY, lfpZ =  getVehicleComponentPosition(vehicle, "wheel_lf_dummy")
    local lfrX, lfrY, lfrZ =  getVehicleComponentRotation(vehicle, "wheel_lf_dummy")
    local rfpX, rfpY, rfpZ = getVehicleComponentPosition(vehicle, "wheel_rf_dummy")
    local rfrX, rfrY, rfrZ = getVehicleComponentRotation(vehicle, "wheel_rf_dummy")
    local lbpX, lbpY, lbpZ = getVehicleComponentPosition(vehicle, "wheel_lb_dummy")
    local lbrX, lbrY, lbrZ = getVehicleComponentRotation(vehicle, "wheel_lb_dummy")
    local rbpX, rbpY, rbpZ = getVehicleComponentPosition(vehicle, "wheel_rb_dummy")
    local rbrX, rbrY, rbrZ = getVehicleComponentRotation(vehicle, "wheel_rb_dummy")
    local camX, camY, camZ, tgtX, tgtY, tgtZ, roll, fieldOfView = getCameraMatrix(localPlayer)
    local saveTime = getTickCount()
    local frameTime = saveTime - lastSave
    lastSave = saveTime
    frameCount = frameCount + 1
    local velocity = Vector3(getElementVelocity(vehicle))
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
    logTable[tostring(frameCount)] = {
        ["fT"] = frameTime,
        ["c"] = {cX = camX, cY = camY, cZ = camZ, tX = tgtX, tY = tgtY, tZ = tgtZ, r = roll, fov = fieldOfView},
        ["v"] = {pX = vehPX, pY = vehPY, pZ = vehPZ, rX = vehRX, rY = vehRY, rZ = vehRZ},
        ["lf"] = {pX = lfpX, pY = lfpY, pZ = lfpZ, rX = lfrX, rY = lfrY, rZ = lfrZ},
        ["rf"] = {pX = rfpX, pY = rfpY, pZ = rfpZ, rX = rfrX, rY = rfrY, rZ = rfrZ},
        ["lb"] = {pX = lbpX, pY = lbpY, pZ = lbpZ, rX = lbrX, rY = lbrY, rZ = lbrZ},
        ["rb"] = {pX = rbpX, pY = rbpY, pZ = rbpZ, rX = rbrX, rY = rbrY, rZ = rbrZ},
        ["s"] = state, --states: I_dle, A_ccelerating, B_raking, R_eversing (priority lowest to highest)
        ["V"] = vehVel, -- velocity units in meters per 1/50th of a second
    }
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

function getInfo()
    return {
        ["kfPS"] = math.floor(1000 / keyframesPerSecond), -- keyframes Per Second
        ["vN"] = getVehicleName(vehicle),
        ["d"] = (lastSave - firstSave) * 0.001, -- duration time in seconds
        ["fC"] = frameCount,
        ["vT"] = vehType,
    }
end

function getFileName()
    -- format: YY-DDD-HH-MM-SS-vehicle
    local vehName = getVehicleName(vehicle)
    local time = getRealTime()
    local stringName = time.year + 1900 .. "-" .. time.yearday .. "-" .. time.hour .. "-" .. time.minute .. "-" .. time.second .. "-" .. vehName .. ".json"
    return stringName
end

function setKeyframesPerSecond(playerSource, fps)
    keyframesPerSecond = math.floor(1000/tonumber(fps))
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

-- HANDLERS ---------------

addEventHandler ("onClientPlayerVehicleEnter", localPlayer, init)
addEventHandler ("onClientPlayerVehicleExit", localPlayer, playerHasExited)
addEventHandler("onClientRender", root, recordKeyframe) 
addCommandHandler("s", toggleRecording)
addCommandHandler("kfps", setKeyframesPerSecond)
bindKey("num_mul", "up", toggleRecording)