function __ngrok_prepare_completions
    set -g __ngrok_comp_results

    if not command -q ngrok
        return 1
    end

    set -l tokens (commandline -opc)
    set -l current (commandline -ct)
    set -l args $tokens[2..-1]

    if test -n "$current"
        set args $args $current
    else
        set args $args ""
    end

    set -l results (command ngrok __complete $args 2>/dev/null)
    if test (count $results) -le 1
        return 1
    end

    for result in $results[1..-2]
        if string match -q '_activeHelp_*' -- $result
            continue
        end

        set -a __ngrok_comp_results $result
    end

    test (count $__ngrok_comp_results) -gt 0
end

complete -c ngrok -n '__ngrok_prepare_completions' -f -a '$__ngrok_comp_results'
