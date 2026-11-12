# Isla command completion activity, installed explicitly by the user.
function __isla_activity_postexec --on-event fish_postexec
    set -l command_status $status
    set -l finished_command "$argv[1]"
    set -l command_duration $CMD_DURATION
    if test (count $argv) -gt 1; and string match -rq '^[0-9]+$' -- "$argv[2]"
        set command_status $argv[2]
    end
    if test (count $argv) -gt 2; and string match -rq '^[0-9]+$' -- "$argv[3]"
        set command_duration $argv[3]
    end
    test "$command_duration" -gt 3000; or return
    set -l threshold 10
    set -l enabled true
    set -l config_file
    if set -q ISLA_CONFIG; and test -n "$ISLA_CONFIG"
        set config_file "$ISLA_CONFIG"
    else if set -q XDG_CONFIG_HOME
        set config_file "$XDG_CONFIG_HOME/isla/shell.json"
    else
        set config_file "$HOME/.config/isla/shell.json"
    end
    if test -r "$config_file"
        set -l settings (python3 -c 'import json,sys; a=json.load(open(sys.argv[1])).get("activities",{}); print(a.get("longCommandSeconds",10)); print(str(a.get("enabled",True)).lower())' "$config_file" 2>/dev/null)
        set -l configured $settings[1]
        if test "$settings[2]" = false
            set enabled false
        end
        if string match -rq '^[0-9]+([.][0-9]+)?$' -- "$configured"
            if test $configured -ge 3; and test $configured -le 600
                set threshold $configured
            end
        end
    end
    test "$enabled" = true; or return
    test "$command_duration" -gt (math "$threshold * 1000"); or return
    command -q hyprctl; and command -q jq; or return
    set -l active_pid (hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty')
    test -n "$active_pid"; or return
    # The active window must not be this shell or any of its ancestors.
    set -l pid $fish_pid
    while test "$pid" -gt 1
        test "$active_pid" = "$pid"; and return
        set pid (awk '/^PPid:/ {print $2}' /proc/$pid/status 2>/dev/null)
        test -n "$pid"; or break
    end
    set -l seconds (math "round($command_duration / 1000)")
    set -l duration "$seconds s"
    if test $seconds -ge 60
        set duration (math "floor($seconds / 60)")" m "(math "$seconds % 60")" s"
    end
    set -l id "fish-$fish_pid-(date +%s)"
    set -l activity_cli (command -s isla-activity)
    if test -z "$activity_cli"
        set activity_cli (path resolve (path dirname (path resolve (status filename)))/../isla-activity 2>/dev/null)
        test -x "$activity_cli"; or return
    end
    "$activity_cli" start --id "$id" --title (string sub -l 120 -- "$finished_command") --icon terminal --source fish >/dev/null 2>&1
    set -l final_state done
    test $command_status -eq 0; or set final_state failed
    "$activity_cli" end --id "$id" --state "$final_state" --subtitle "$duration" >/dev/null 2>&1
end
