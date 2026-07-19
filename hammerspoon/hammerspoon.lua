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
