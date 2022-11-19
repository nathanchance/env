local wezterm = require 'wezterm';
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local pane_title = tab.active_pane.title
  local user_title = tab.active_pane.user_vars.panetitle

  if user_title ~= nil and #user_title > 0 then
    pane_title = user_title
  end

  return {
    {Text=" " .. pane_title .. " "},
  }
end)
local function get_hostname()
    local f = io.popen("/bin/hostname")
    local hostname = f:read("*a") or ""
    f:close()
    hostname =string.gsub(hostname, "\n$", "")
    return hostname
end
local function get_font_size()
    local _hostname = get_hostname()
    if _hostname == "Nathans-Mac-Studio.local" then
        return 14.0
    else
        return 13.0
    end
end
return {
  color_scheme = "Snazzy",
  debug_key_events = true,
  default_prog = {"/opt/homebrew/bin/fish", "-l"},
  font = wezterm.font_with_fallback({"Iosevka Term SS08", "SF Mono Regular"}),
  font_size = get_font_size(),
  initial_cols = 238,
  initial_rows = 51,
  keys = {
     {key="LeftArrow", mods="CMD", action={SendKey={key="Home"}}},
     {key="RightArrow", mods="CMD", action={SendKey={key="End"}}},
     {key="UpArrow", mods="CMD", action={SendKey={key="PageUp"}}},
     {key="DownArrow", mods="CMD", action={SendKey={key="PageDown"}}},
     {key="Enter", mods="ALT", action="DisableDefaultAssignment"}
  },
  window_padding = {
    left = 10,
    right = 10,
    top = 5,
    bottom = 5,
  }
}
