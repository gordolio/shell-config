# Zoxide - smarter cd command (z replacement)
if __tool_check_cmd "zoxide" zoxide directory-jump
    zoxide init fish | source
end
