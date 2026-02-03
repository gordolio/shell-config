function fish_mode_prompt --wraps=echo --description 'alias fish_mode_prompt echo'
  switch $fish_bind_mode
    case default
      echo -ne "\e[\x32 q"
    case insert
      echo -ne "\e[\x36 q"
    case replace_one
      echo -ne "\e[\x32 q"
    case visual
      echo -ne "\e[\x32 q"
    case '*'
      echo -ne "\e[\x32 q"
  end
end
