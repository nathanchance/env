# set -ux equivalent
Set-PSDebug -trace 1 -Strict

# Define sleep time
if ($args.count -gt 0) {
    $sleeptime = $args[0]
} else {
    $sleeptime = 60
}

# WSL config variable
$wslconfig = 'C:\Users\natec\.wslconfig'
if (Test-Path $wslconfig) {
    # Reboot with the default WSL kernel
    wsl --shutdown
    # Make sure that 'kernel =' is uncommented (in case script was interrupted before the second block below)
    (Get-Content $wslconfig).replace('# kernel =', 'kernel =') -join "`n" | Set-Content -NoNewline $wslconfig
    (Get-Content $wslconfig).replace('kernel =', '# kernel =') -join "`n" | Set-Content -NoNewline $wslconfig
    Start-Sleep -Seconds $sleeptime
    wsl -d Debian -- /usr/bin/batcat /proc/version

    # Reboot with the custom kernel
    wsl --shutdown
    (Get-Content $wslconfig).replace('# kernel =', 'kernel =') -join "`n" | Set-Content -NoNewline $wslconfig
    Start-Sleep -Seconds $sleeptime
    wsl -d Debian -- /usr/bin/batcat /proc/version
}