#!/usr/local/bin/zsh

function precmd {

  local TERMWIDTH
  (( TERMWIDTH = ${COLUMNS} - 1 ))


  ###
  # Truncate the path if it's too long.
  PR_FILLBAR=""
  PR_PWDLEN=""

  local promptsize=${#${(%):---(%n@%m:%l)---()--}}
  local pwdsize=${#${(%):-%~}}
  PR_GIT_STATUS=`ruby -e "print (%x{git branch 2>/dev/null}.split(/\n/).grep(/^\*/).first || '').gsub(/^\* (.+)$/,'[\1] ')"`
  #PR_GIT_STATUS=`git branch 2>/dev/null | grep '^\*' | awk '{print "[" $2 "] "}'`
  PR_GIT_SIZE="`echo $PR_GIT_STATUS | wc -c` - 1"
  if [[ $PR_GIT_SIZE -lt 0 ]]; then
    PR_GIT_SIZE=0
  fi

  if [[ "$promptsize + $pwdsize + $PR_GIT_SIZE" -gt $TERMWIDTH ]]; then
    ((PR_PWDLEN=$TERMWIDTH - $promptsize - $PR_GIT_SIZE + 2))
  else
    PR_FILLBAR="\${(l.(($TERMWIDTH - ($promptsize + $pwdsize + $PR_GIT_SIZE)))..${PR_HBAR}.)}"
  fi


  ###
  # Get APM info.

  if which pmset > /dev/null; then
    PR_RESULT=`pmset -g ps | grep InternalBattery`
    #PR_CHARGE_RESULT=`echo $PR_RESULT | awk '{print $3}' | sed 's/\(;charging\)/charging/'`
    PR_APM_RESULT=`echo $PR_RESULT | awk '{print $2}' | sed 's/\([0-9]*\).*/\1/'`
  elif which apm > /dev/null; then
    PR_APM_RESULT=`apm`
  elif which ibam > /dev/null; then
    PR_APM_RESULT=`ibam --percentbattery`
  fi

}


setopt extended_glob
preexec () {
  if [[ "$TERM" == "screen" ]]; then
    local CMD=${1[(wr)^(*=*|sudo|-*)]}
    echo -n "\ek$CMD\e\\"
  fi
}


setprompt () {
  ###
  # Need this so the prompt will work.

  setopt prompt_subst


  ###
  # See if we can use colors.

  autoload colors zsh/terminfo
  if [[ "$terminfo[colors]" -ge 8 ]]; then
    colors
  fi
  for color in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE; do
    eval PR_$color='%{$terminfo[bold]$fg[${(L)color}]%}'
    eval PR_LIGHT_$color='%{$fg[${(L)color}]%}'
    (( count = $count + 1 ))
  done
  PR_NO_COLOUR="%{$terminfo[sgr0]%}"


  ###
  # See if we can use extended characters to look nicer.

  typeset -A altchar
  set -A altchar ${(s..)terminfo[acsc]}
  PR_SET_CHARSET="%{$terminfo[enacs]%}"
  PR_SHIFT_IN="%{$terminfo[smacs]%}"
  PR_SHIFT_OUT="%{$terminfo[rmacs]%}"
  PR_HBAR=${altchar[q]:--}
  PR_ULCORNER=${altchar[l]:--}
  PR_LLCORNER=${altchar[m]:--}
  PR_LRCORNER=${altchar[j]:--}
  PR_URCORNER=${altchar[k]:--}


  ###
  # Decide if we need to set titlebar text.

  case $TERM in
    xterm*)
      PR_TITLEBAR=$'%{\e]0;%(!.-=*[ROOT]*=- | .)%n@%m:%~ | ${COLUMNS}x${LINES} | %y\a%}'
    ;;
    screen)
      PR_TITLEBAR=$'%{\e_screen \005 (\005t) | %(!.-=[ROOT]=- | .)%n@%m:%~ | ${COLUMNS}x${LINES} | %y\e\\%}'
    ;;
    *)
      PR_TITLEBAR=''
    ;;
  esac


  ###
  # Decide whether to set a screen title
  if [[ "$TERM" == "screen" ]]; then
    PR_STITLE=$'%{\ekzsh\e\\%}'
  else
    PR_STITLE=''
  fi


  ###
  # APM detection

  if which ibam > /dev/null; then
    PR_APM='$PR_RED${${PR_APM_RESULT[(f)1]}[(w)-2]}%%(${${PR_APM_RESULT[(f)3]}[(w)-1]})$PR_LIGHT_BLUE:'
  elif which apm > /dev/null; then
    PR_APM='$PR_RED${PR_APM_RESULT[(w)5,(w)6]/\% /%%}$PR_LIGHT_BLUE:'
  elif which pmset > /dev/null; then
    PR_APM='$PR_RED${PR_APM_RESULT}%%${PR_CHARGE_RESULT}$PR_LIGHT_BLUE:'
  else
    PR_APM=''
  fi


  LAMBDA=`echo -ne '\xce\xbb'`
  ###
  # Finally, the prompt.

  PROMPT='$PR_SET_CHARSET$PR_STITLE${(e)PR_TITLEBAR}\
$PR_CYAN$PR_SHIFT_IN$PR_ULCORNER$PR_BLUE$PR_HBAR$PR_SHIFT_OUT(\
$PR_GREEN%(!.%SROOT%s.%n)$PR_GREEN@%m:%l\
$PR_BLUE)$PR_SHIFT_IN$PR_HBAR$PR_CYAN$PR_HBAR${(e)PR_FILLBAR}\
$PR_BLUE$PR_HBAR$PR_SHIFT_OUT(\
$PR_RED$PR_GIT_STATUS\
$PR_MAGENTA%$PR_PWDLEN<...<%~%<<\
$PR_BLUE)$PR_SHIFT_IN$PR_HBAR$PR_CYAN$PR_URCORNER$PR_SHIFT_OUT\

$PR_CYAN$PR_SHIFT_IN$PR_LLCORNER$PR_BLUE$PR_HBAR$PR_SHIFT_OUT(\
%(?..$PR_LIGHT_RED%?$PR_BLUE:)\
${(e)PR_APM}$PR_YELLOW%D{%l:%M%p}\
$PR_LIGHT_BLUE %(!.$PR_RED.$PR_WHITE)\$$PR_BLUE)$PR_SHIFT_IN$PR_HBAR$PR_SHIFT_OUT\
$PR_CYAN$PR_SHIFT_IN$PR_HBAR$PR_SHIFT_OUT\
$PR_NO_COLOUR '

  RPROMPT=' $PR_CYAN$PR_SHIFT_IN$PR_HBAR$PR_BLUE$PR_HBAR$PR_SHIFT_OUT\
($PR_YELLOW%D{%a,%b%d}$PR_BLUE)$PR_SHIFT_IN$PR_HBAR$PR_CYAN$PR_LRCORNER$PR_SHIFT_OUT$PR_NO_COLOUR'

  PS2='$PR_CYAN$PR_SHIFT_IN$PR_HBAR$PR_SHIFT_OUT\
$PR_BLUE$PR_SHIFT_IN$PR_HBAR$PR_SHIFT_OUT(\
$PR_LIGHT_GREEN%_$PR_BLUE)$PR_SHIFT_IN$PR_HBAR$PR_SHIFT_OUT\
$PR_CYAN$PR_SHIFT_IN$PR_HBAR$PR_SHIFT_OUT$PR_NO_COLOUR '
}

setprompt
