# set -ux equivalent
Set-PSDebug -trace 1 -Strict

# Define sleep time
if ($args.count -gt 0) {
    $sleeptime = $args[0]
}
else {
    $sleeptime = 10
}

# Shutdown the VM
wsl --shutdown

# Start up the VM and print the version
Start-Sleep -Seconds $sleeptime
wsl -d ubuntu -- /usr/bin/bat /proc/version

# If the distro fails to start, try again
if (!$?) {
    wsl --shutdown
    Start-Sleep -Seconds $sleeptime
    wsl -d ubuntu -- /usr/bin/bat /proc/version
}

# Turn debug back off
Set-PSDebug -Off
