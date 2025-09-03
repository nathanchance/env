complete -c tio -x -s b -l baudrate -d "Baud rate"
complete -c tio -x -s d -l databits -d "Data bits" -a "5 6 7 8"
complete -c tio -x -s f -l flow -d "Flow control" -a "hard soft none"
complete -c tio -x -s s -l stopbits -d "Stop bits" -a "1 2"
complete -c tio -x -s p -l parity -d Parity -a "odd even none mark space"
complete -c tio -x -s o -l output-delay -d "Output character delay"
complete -c tio -x -s O -l output-line-delay -d "Output line delay"
complete -c tio -f -l line-pulse-duration -d "Set line pulse duration"
complete -c tio -x -s a -l auto-connect -d "Automatic connect strategy" -a "new latest direct"
complete -c tio -x -l exclude-devices -d "Exclude devices by pattern"
complete -c tio -x -l exclude-drivers -d "Exclude drivers by pattern"
complete -c tio -x -l exclude-tids -d "Exclude topology IDs by pattern"
complete -c tio -f -s n -l no-reconnect -d "Do not reconnect"
complete -c tio -f -s e -l local-echo -d "Enable local echo"
complete -c tio -x -l input-mode -d "Select input mode" -a "normal hex line"
complete -c tio -x -l output-mode -d "Select output mode" -a "normal hex"
complete -c tio -f -s t -l timestamp -d "Enable line timestamp"
complete -c tio -x -l timestamp-format -d "Set timestamp format"
complete -c tio -x -l timestamp-timeout -d "Set timestamp timeout"
complete -c tio -f -s l -l list -d "List available serial devices, TIDs, and profiles"
complete -c tio -f -s L -l log -d "Enable log to file"
complete -c tio -r -l log-file -d "Set log filename"
complete -c tio -x -l log-directory -d "Set log directory path for automatic named logs" -a "(__fish_complete_directories)"
complete -c tio -f -l log-append -d "Append to log file"
complete -c tio -f -l log-strip -d "Strip control characters and escape sequences"
complete -c tio -x -s m -l map -d "Map characters"
complete -c tio -x -s c -l color -d "Colorize tio text"
complete -c tio -x -s S -l socket -d "Redirect I/O to socket"
complete -c tio -f -l rs-485 -d "Enable RS-485 mode"
complete -c tio -x -l rs-485-config -d "Set RS-485 configuration"
complete -c tio -x -l alert -d "Alert on connect/disconnect" -a "bell blink none"
complete -c tio -f -l mute -d "Mute tio messages"
complete -c tio -x -l script -d "Run script from string"
complete -c tio -r -l script-file -d "Run script from file"
complete -c tio -x -l script-run -d "Run script on connect" -a "once always never"
complete -c tio -x -l exec -d "Execute shell command with I/O redirected to device"
complete -c tio -f -s v -l version -d "Display version"
complete -c tio -f -s h -l help -d "Display help"

function __tio_serial_arguments
    string join \n -- (path sort /dev/ttyUSB* /dev/serial/by-{id,path}/*)\t'serial device'

    set -l tio_config $HOME/.config/tio/config
    if test -e $tio_config
        string join \n -- (string match -gr '^\[(.*)\]$' <$tio_config)\t'connection profile'
    end
end
complete -c tio -x -a "(__tio_serial_arguments)"
