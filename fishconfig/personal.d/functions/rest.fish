function rest
  #timer 10s && \
  terminal-notifier \
  -message 'Pomodoro' \
  -title 'Break is over! Get back to work 😬' \
  -appIcon "$HOME/Pictures/full-battery.png" \
  -sound default \
  $argv

end
