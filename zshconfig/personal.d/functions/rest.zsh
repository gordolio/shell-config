# Pomodoro rest notification
function rest {
  terminal-notifier \
    -message 'Pomodoro' \
    -title 'Break is over! Get back to work' \
    -appIcon '/Users/gordon/Pictures/full-battery.png' \
    -sound default \
    "$@"
}
