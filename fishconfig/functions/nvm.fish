# ~/.config/fish/functions/nvm.fish
if [ -f ~/.nvm/nvm.sh ]
  function nvm
    bass source ~/.nvm/nvm.sh --no-use ';' nvm $argv
  end
end

