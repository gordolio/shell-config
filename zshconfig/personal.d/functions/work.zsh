# Pomodoro work timer - 25 minutes
function work {
  timer 25m && terminal-notifier \
    -message 'Pomodoro' \
    -title 'Work Timer is up! Take a Break' \
    -appIcon '~/Pictures/low-battery.png' \
    -sound Crystal \
    "$@"
}
