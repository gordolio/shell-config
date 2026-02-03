# History search chain: atuin > fzf
# Loads after other personal configs (zz- prefix) to run after fish_vi_key_bindings
# atuin provides intelligent history with context (pwd, exit code, duration)

if __tool_check_cmd "atuin" atuin history-search
    # atuin init binds Ctrl+R, overriding fzf's binding
    atuin init fish | source
else
    # fzf binding from conf.d/fzf.fish remains active
    __tool_record "fzf-history" "history-search" loaded "fzf (fallback)" ""
end
