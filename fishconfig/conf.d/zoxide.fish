# Zoxide - smarter cd command
# Initialize zoxide
if type -q zoxide
  zoxide init fish | source

  # Optional: alias 'cd' to 'z' for seamless integration
  # Uncomment the line below if you want cd to use zoxide
  alias cd='z'
end
