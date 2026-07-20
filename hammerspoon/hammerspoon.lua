require("hs.ipc")

if hs.host.operatingSystemVersion().major >= 27 then
    local function missionControlDisplays()
        local windowManagers = hs.application.applicationsForBundleID("com.apple.WindowManager")
        if #windowManagers == 0 then
            return {}
        end

        local displays = {}
        local windowManager = hs.axuielement.applicationElement(windowManagers[1])
        for _, element in ipairs(windowManager) do
            if element.AXIdentifier == "mc.display" then
                table.insert(displays, element)
            end
        end
        return displays
    end

    local function toggleMissionControl()
        hs.execute('/usr/bin/open -a "Mission Control"')
    end

    local function missionControlElement(screenID, identifier)
        for _ = 1, 40 do
            for _, display in ipairs(missionControlDisplays()) do
                if display.AXDisplayID == screenID then
                    for _, spaces in ipairs(display:attributeValue("AXChildren") or {}) do
                        if spaces.AXIdentifier == "mc.spaces" then
                            for _, element in ipairs(spaces:attributeValue("AXChildren") or {}) do
                                if element.AXIdentifier == identifier then
                                    return element
                                end
                            end
                        end
                    end
                end
            end
            hs.timer.usleep(50000)
        end
        return nil, "Mission Control element not found: " .. identifier
    end

    local function resolveScreenID(screenID)
        if screenID == nil then
            screenID = hs.screen.mainScreen():id()
        elseif getmetatable(screenID) == hs.getObjectMetatable("hs.screen") then
            screenID = screenID:id()
        elseif type(screenID) == "string" then
            if #screenID == 36 then
                for _, screen in ipairs(hs.screen.allScreens()) do
                    if screen:getUUID() == screenID then
                        screenID = screen:id()
                        break
                    end
                end
            elseif screenID:lower() == "main" then
                screenID = hs.screen.mainScreen():id()
            elseif screenID:lower() == "primary" then
                screenID = hs.screen.primaryScreen():id()
            end
        end

        assert(math.type(screenID) == "integer", "screen id must be an integer")
        return screenID
    end

    hs.spaces.toggleMissionControl = toggleMissionControl
    hs.spaces.openMissionControl = function()
        if #missionControlDisplays() == 0 then
            toggleMissionControl()
        end
    end
    hs.spaces.closeMissionControl = function()
        if #missionControlDisplays() > 0 then
            toggleMissionControl()
        end
    end
    hs.spaces.addSpaceToScreen = function(...)
        local args, screenID, closeMissionControl = {...}, nil, true
        assert(#args < 3, "expected no more than 2 arguments")
        if #args == 1 then
            if type(args[1]) == "boolean" then
                closeMissionControl = args[1]
            else
                screenID = args[1]
            end
        elseif #args == 2 then
            screenID, closeMissionControl = table.unpack(args)
        end
        assert(type(closeMissionControl) == "boolean", "close flag must be boolean")
        screenID = resolveScreenID(screenID)

        hs.spaces.openMissionControl()
        local addButton, errorMessage = missionControlElement(screenID, "mc.spaces.add")
        if not addButton then
            if closeMissionControl then
                hs.spaces.closeMissionControl()
            end
            return nil, errorMessage
        end

        local status, actionError = addButton:performAction("AXPress")
        if closeMissionControl then
            hs.spaces.closeMissionControl()
        end
        if status then
            return true
        end
        return nil, actionError
    end

    hs.spaces.removeSpace = function(...)
        local args, closeMissionControl = {...}, true
        assert(#args > 0 and #args < 3, "expected between 1 and 2 arguments")
        local spaceID = args[1]
        if #args == 2 then
            closeMissionControl = args[2]
        end
        assert(math.type(spaceID) == "integer", "space id must be an integer")
        assert(type(closeMissionControl) == "boolean", "close flag must be boolean")

        local screenUUID = hs.spaces.spaceDisplay(spaceID)
        if not screenUUID then
            return nil, "space not found in managed displays"
        end

        local screenID
        for _, screen in ipairs(hs.screen.allScreens()) do
            if screen:getUUID() == screenUUID then
                screenID = screen:id()
                break
            end
        end
        if not screenID then
            return nil, "display for space not found"
        end

        local spacesOnScreen = hs.spaces.spacesForScreen(screenUUID)
        if hs.spaces.spaceType(spaceID) == "user" then
            local userSpaceCount = 0
            for _, candidateID in ipairs(spacesOnScreen) do
                if hs.spaces.spaceType(candidateID) == "user" then
                    userSpaceCount = userSpaceCount + 1
                end
            end
            if userSpaceCount == 1 then
                return nil, "unable to remove the only user space on a screen"
            end
            if hs.spaces.activeSpaceOnScreen(screenID) == spaceID then
                return nil, "cannot remove a currently active user space"
            end
        end

        local spaceIndex
        for index, candidateID in ipairs(spacesOnScreen) do
            if candidateID == spaceID then
                spaceIndex = index
                break
            end
        end
        if not spaceIndex then
            return nil, "space not found on display"
        end

        hs.spaces.openMissionControl()
        local spacesList, errorMessage = missionControlElement(screenID, "mc.spaces.list")
        if not spacesList then
            if closeMissionControl then
                hs.spaces.closeMissionControl()
            end
            return nil, errorMessage
        end

        local spaceButton = (spacesList:attributeValue("AXChildren") or {})[spaceIndex]
        if not spaceButton then
            if closeMissionControl then
                hs.spaces.closeMissionControl()
            end
            return nil, "space not found in Mission Control"
        end

        local status, actionError = spaceButton:performAction("AXRemoveDesktop")
        if closeMissionControl then
            hs.spaces.closeMissionControl()
        end
        if status then
            return true
        end
        return nil, actionError
    end
end

local dynamicSpacesTimer
local reconcileDynamicSpaces

local function scheduleDynamicSpacesReconcile(delay)
    if dynamicSpacesTimer then
        dynamicSpacesTimer:stop()
    end
    dynamicSpacesTimer = hs.timer.doAfter(delay or 0.5, reconcileDynamicSpaces)
end

local function standardWindowState(spaceID)
    local windowIDs, errorMessage = hs.spaces.windowsForSpace(spaceID)
    if not windowIDs then
        print("Dynamic Spaces: " .. errorMessage)
        return nil
    end

    for _, windowID in ipairs(windowIDs) do
        local window = hs.window.get(windowID)
        if window and window:isStandard() then
            return true
        end
    end
    return false
end

local function userSpacesForScreen(screen)
    local spaces, errorMessage = hs.spaces.spacesForScreen(screen)
    if not spaces then
        print("Dynamic Spaces: " .. errorMessage)
        return nil
    end

    local userSpaces = {}
    for _, spaceID in ipairs(spaces) do
        if hs.spaces.spaceType(spaceID) == "user" then
            table.insert(userSpaces, spaceID)
        end
    end
    return userSpaces
end

reconcileDynamicSpaces = function()
    dynamicSpacesTimer = nil
    for _, screen in ipairs(hs.screen.allScreens()) do
        local spaces = userSpacesForScreen(screen)
        if spaces and #spaces > 0 then
            local lastSpace = spaces[#spaces]
            local lastSpaceHasWindows = standardWindowState(lastSpace)
            if lastSpaceHasWindows == nil then
                return
            end

            if lastSpaceHasWindows then
                local status, errorMessage = hs.spaces.addSpaceToScreen(screen)
                if not status then
                    print("Dynamic Spaces: " .. tostring(errorMessage))
                else
                    scheduleDynamicSpacesReconcile(1)
                end
                return
            end

            if #spaces > 1 then
                local previousSpace = spaces[#spaces - 1]
                local previousSpaceHasWindows = standardWindowState(previousSpace)
                if previousSpaceHasWindows == nil then
                    return
                end

                if not previousSpaceHasWindows then
                    local activeSpace = hs.spaces.activeSpaceOnScreen(screen)
                    local spaceToRemove = lastSpace
                    if activeSpace == lastSpace then
                        spaceToRemove = previousSpace
                    end

                    local status, errorMessage = hs.spaces.removeSpace(spaceToRemove)
                    if not status then
                        print("Dynamic Spaces: " .. tostring(errorMessage))
                    else
                        scheduleDynamicSpacesReconcile(1)
                    end
                    return
                end
            end
        end
    end
end

dynamicSpacesWindowFilter = hs.window.filter.new()
dynamicSpacesWindowFilter:subscribe({
    hs.window.filter.windowCreated,
    hs.window.filter.windowDestroyed,
    hs.window.filter.windowMoved,
}, function()
    scheduleDynamicSpacesReconcile()
end)

dynamicSpacesSpaceWatcher = hs.spaces.watcher.new(function()
    scheduleDynamicSpacesReconcile()
end):start()
dynamicSpacesScreenWatcher = hs.screen.watcher.new(function()
    scheduleDynamicSpacesReconcile(1)
end):start()
dynamicSpacesPollTimer = hs.timer.doEvery(5, function()
    scheduleDynamicSpacesReconcile()
end)
scheduleDynamicSpacesReconcile(1)

local sshAgentSocket = os.getenv("HOME") .. "/.ssh/agent/fish-agent.sock"
local unlockedSSHKeysDirectory = os.getenv("HOME") .. "/.ssh/.unlocked"

function checkBluetoothResult(rc, stdout, stderr)
    if rc ~= 0 then
        print(string.format("Unexpected result executing `blueutil`: rc=%d stderr=%s stdout=%s", rc, stderr, stdout))
    end
end

function bluetooth(power)
    print("Setting bluetooth to " .. power)
    local t = hs.task.new("/opt/homebrew/bin/blueutil", checkBluetoothResult, {"--power", power})
    t:start()
end

function checkSSHAgentResult(rc, stdout, stderr)
    if rc ~= 0 then
        print(string.format("Unexpected result executing `ssh-add -D`: rc=%d stderr=%s stdout=%s", rc, stderr, stdout))
    end
end

function forgetSSHKeys()
    print("Forgetting remembered SSH key passphrases")
    local t = hs.task.new("/usr/bin/ssh-add", checkSSHAgentResult, {"-D"})
    local environment = t:environment()
    environment.SSH_AUTH_SOCK = sshAgentSocket
    t:setEnvironment(environment)
    t:start()
end

function removeUnlockedSSHKeys()
    print("Removing temporary unlocked SSH keys")
    local t = hs.task.new("/bin/rm", function(rc, stdout, stderr)
        if rc ~= 0 then
            print(string.format("Unexpected result removing unlocked SSH keys: rc=%d stderr=%s stdout=%s", rc, stderr, stdout))
        end
    end, {"-rf", unlockedSSHKeysDirectory})
    t:start()
end

function cleanUpSSHKeys()
    forgetSSHKeys()
    removeUnlockedSSHKeys()
end

lidWatcher = hs.caffeinate.watcher.new(function(eventType)
    if (eventType == hs.caffeinate.watcher.screensDidSleep) then
        bluetooth("off")
        cleanUpSSHKeys()
    elseif (eventType == hs.caffeinate.watcher.screensDidWake) then
        bluetooth("on")
    elseif (eventType == hs.caffeinate.watcher.screensDidLock) then
        cleanUpSSHKeys()
    elseif (eventType == hs.caffeinate.watcher.systemWillPowerOff) then
        cleanUpSSHKeys()
    end
end)

lidWatcher:start()
