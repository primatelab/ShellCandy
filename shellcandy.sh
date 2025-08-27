#! /bin/bash

## rlyeh

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
  echo "Needs to be sourced."
  exit 1
fi

function bleat () {
  echo "$@" > /tmp/baa
}

common_prefix () {
  # finds the common prefix in an array of strings
  local wordlist=( "$@" )
  local prefix=''
  for((pl=1;pl<=${#wordlist};pl++)); do
    local partial="${wordlist:0:$pl}"
    local comps=( ${wordlist[@]/$partial*/} )
    if (( ${#comps[@]} == 0 )); then
      prefix=$partial
    else
      break
    fi
  done
  echo $prefix
}

_getrow () {
  declare -n envglobal=$1
  echo -en '\e[6n' 
  local a b
  IFS= read -sn1 a
  IFS= read -sdR b
  if [[ ${a} == $'\e' ]]; then
    b=${b#[}
    b=${b%;*}
    export envglobal="${b}"
  fi
  unset a b
}
_sc_nakedprompt () {
  export NAKEDPROMPT1="$(echo "${PS1@P}" | sed -r 's/\x1B\]0;.*\a//; s/\x1B\[[0-9;]*[A-Za-z]//g' | tr -d [:cntrl:])"
  export NAKEDPROMPT2="$(echo "${PS2@P}" | sed -r 's/\x1B\]0;.*\a//; s/\x1B\[[0-9;]*[A-Za-z]//g' | tr -d [:cntrl:])"
}

_sc_complete () {
  [[ -f /etc/bash_completion ]] && source /etc/bash_completion
  COMP_LINE="$@"
  read -ra COMP_WORDS <<< "$COMP_LINE"
  COMP_CWORD=${#COMP_WORDS[@]}
  ((COMP_CWORD--))
  COMP_POINT=${#COMP_LINE}
  local cmd="${COMP_WORDS[0]}"
  local cur="${COMP_WORDS[$COMP_CWORD]}"
  complete -p "$cmd" &>/dev/null || _completion_loader "$cmd" &>/dev/null
  local completion_func
  completion_func=$(complete -p "$cmd" 2>/dev/null | sed -n "s/.*-F \([^ ]*\).*/\1/p")
  if [[ -n $completion_func && $(type -t "$completion_func") == "function" ]]; then
    COMPREPLY=()
    "$completion_func"
    if (( ${#COMPREPLY[@]} == 0)); then
      local suff=' '
    elif (( ${#COMPREPLY[@]} == 1)); then
      local s_word="${COMPREPLY[0]}"
    else
      local s_word="$(common_prefix "${COMPREPLY[@]}")…"
    fi
    local suff="${s_word#$cur}"
    if [[ -n "${suff}" && "${suff}" != '…' ]]; then
      echo "${suff}"
    fi
  fi
}
# _sc_innercolour () {
#   local regex="$1"
#   local colour="$2"
#   sed -E "s/(\x1B[[0-9\;]*m)([^\x1B]*)(${regex})/\1\2${colour}\3\1/g"
# }
## Let the syntax highlighting function be defined elsewhere if you like
# if [[ ! $(declare -F highlight_bash_syntax) == highlight_bash_syntax ]]; then 
  highlight_bash_syntax () {
    local yel=$'\e[33;1m'
    local cya=$'\e[36;1m'
    local wht=$'\e[1m'
    local red=$'\e[31m'
    local dim=$'\e[90;2m'
    local def=$'\e[0m'
    if [[ -p /dev/stdin ]]; then 
      # IFS= read text
      while IFS= read line; do
        text="$text"$'\n'"$line"
      done
    else
      text="${text}$@"
    fi
    echo -n "$text" | sed -E "
      s/\b(if|fi|then|else|elif|for|in|do|done|while|break|function|return|exit|case|esac)\b/${cya}\1${def}/g;
      s/\b(echo|cat|ssh|cp|mv|cd|curl|ls|ln|ll|rm)\b/${wht}\1${def}/g;
      s/("'\$'"[A-Za-z0-9_]+)/${red}\1${def}/g;
      s/("'\$'"\{[^}]*\})/${red}\1${def}/g;
      s/("'"'"|')/${yel}\1${def}/g"
  }
# fi

_sc_afterwrite () {
  sleep 0.0001
  part1="${READLINE_LINE:0:$READLINE_POINT}"
  part2="${READLINE_LINE:$READLINE_POINT:${#READLINE_LINE}}"
  local autocomp="$(_sc_complete "$part1")"
  part1="${part1//\\/\\\\}"
  part2="${part2//\\/\\\\}"
  echo -en "\e7\e[$PROMPT1_ROW;$((${#NAKEDPROMPT1} + 1))H"
  if (( PROMPT1_ROW != PROMPT2_ROW )); then
    # Making multiline migraines moot
    echo -en "\e[$PROMPT2_ROW;$((${#NAKEDPROMPT2}+1))H"
  fi
  if [[ -n $autocomp ]]; then
    # echo -en "$(highlight_bash_syntax "${part1}$autocomp ${part2}" | _sc_innercolour "$autocomp" $'\e[90;2m' )\e[0K\e[0m\e8" 
    echo -en "$(highlight_bash_syntax "${part1}$autocomp ${part2}")\e[0K\e[$PROMPT1_ROW;$((${#NAKEDPROMPT1} + $READLINE_POINT + 1))H\e[1;90m$autocomp\e[0m\e8" 
  else
    echo -en "$(highlight_bash_syntax "${part1}${part2}")\e[0K\e[0m\e8" 
  fi
}
_sc_overwrite () {
  _sc_afterwrite "$@" 2>/dev/null & disown
  wait -n
}

_resize () {
  ## Handling terminal resize events
  local rll="$READLINE_LINE"
  local rlp="$READLINE_POINT"
  _getrow PROMPT1_ROW &>/dev/null
  _getrow PROMPT2_ROW &>/dev/null
  READLINE_LINE="$rll"
  READLINE_LINE="$rlp"
  _sc_overwrite 2>/dev/null
}
function resize () {
  _resize 2>/dev/null & disown
  wait -n
}

function _sc_key () {
  local key="$1"
  case "${key}" in
    "\t" )
      : ## TODO: Handle tabs to make completion look better.
    ;;
    "\C-y" )
      ### Debugging key
      _getrow PROMPT1_ROW
      _getrow PROMPT2_ROW
      (_sc_overwrite 2>/dev/null)
      bleat "
      READLINE_LINE=$READLINE_LINE
      READLINE_POINT=$READLINE_POINT
      autocomp=$(_sc_complete "${READLINE_LINE:0:$READLINE_POINT}")
      PROMPT1_ROW=$PROMPT1_ROW
      PROMPT2_ROW=$PROMPT2_ROW"
    ;;
    "\C-l" )
      ### Clear screen
      clear
      _getrow PROMPT1_ROW
    ;;
    [[:print:]] )
      ### Self-insert
      READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${key}${READLINE_LINE:$READLINE_POINT}"
      ((READLINE_POINT++))
      _getrow PROMPT2_ROW
      (_sc_overwrite 2>/dev/null)
    ;;
    *) : ;;
  esac
}

######## INIT  ###############

## Command keys
# CmdKeys=( '\C-y' '\C-l' '\t' )
CmdKeys=( '\C-y' '\C-l' )

## Text keys
for char in {0..9} {a..z} {A..Z} ' ' {\!,\",\£,\$,%,^,\*,\(,\),-,=,_,+,[,],\{,\},\;,\',\#,:,@,\~,\,,.,/,\<,\>,\?,\|} "${CmdKeys[@]}"; do
  bind "-x \"${char}\": _sc_key \"${char}\""
done

## Testing keys
# bind '-x "\C-y": _sc_key "\C-y"'
# bind '"\C-m": accept-line'

## Finding the row
PROMPT_COMMAND=( '_getrow PROMPT1_ROW' _sc_nakedprompt )

trap resize SIGWINCH

############### Boneyard ######################

## In case I ever want to muck aroung with Enter (which I won't)
    # "\C-m" )
    #   ### ENTER
    #   if bash -n <<<"$READLINE_LINE" 2>/dev/null; then
    #     # bind '"\C-m": accept-line'
    #     # READLINE_POINT=${#READLINE_LINE}
    #     # return 1
    #     echo "${READLINE_LINE@A}" >> /tmp/blarg
    #     history -s "$READLINE_LINE"
    #     # echo -e "${PS1@P}$READLINE_LINE"
    #     eval "$READLINE_LINE"
    #     echo -e "${PS1@P}$(highlight_bash_syntax "$READLINE_LINE")"
    #     READLINE_LINE=''
    #     READLINE_POINT=${#READLINE_LINE}
    #     _getrow PROMPT1_ROW
    #     ## This seems to replicate it well
    #   else
    #     READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}"$'\n'"${READLINE_LINE:$READLINE_POINT}"
    #     ((READLINE_POINT++))
    #     # D_LINE="$READLINE_LINE"   # undecorated
    #     D_LINE="$(highlight_bash_syntax "$READLINE_LINE")"
    #     (_sc_overwrite "$D_LINE" 2>/dev/null)
    #   fi
    # ;;




# _sc_afterwrite () {
#   sleep 0.0001
#   # autocomp="$(_sc_complete "$READLINE_LINE")"
#   part1="${READLINE_LINE:0:$READLINE_POINT}"
#   part2="${READLINE_LINE:$READLINE_POINT:${#READLINE_LINE}}"
#   local autocomp="$(_sc_complete "$part1")"
#   local rlbuffer="${READLINE_LINE//\\/\\\\}"
#   local ac_col
#   # local rlbuffer="${READLINE_LINE}"
#   # local rlbuffer="${@//\\/\\\\}"
#   # if [[ -n $autocomp ]]; then
#   #   # local nakedprompt=$(echo "${PS1@P}" | sed -r 's/\x1B\]0;.*\a//; s/\x1B\[[0-9;]*[A-Za-z]//g' | tr -d [:cntrl:] )
#   #   ac_col=$(( ${#NAKEDPROMPT1} + $READLINE_POINT + 1))
#   #   autocomp="$autocomp "
#   # fi
#   # echo -en "\e7\e[$PROMPT1_ROW;0H${PS1@P}"
#   echo -en "\e7\e[$PROMPT1_ROW;$((${#NAKEDPROMPT1} + 1))H"
#   if (( PROMPT1_ROW != PROMPT2_ROW )); then
#     # Making multiline Ctrl-M migraines moot
#     # echo -en "\e[$PROMPT2_ROW;${#NAKEDPROMPT2}H${PS2@P}"
#     echo -en "\e[$PROMPT2_ROW;$((${#NAKEDPROMPT2}+1))H"
#   fi
#   if [[ -n $autocomp ]]; then
#     ac_col=$(( ${#NAKEDPROMPT2} + $READLINE_POINT + 1))
#     echo -en "$(highlight_bash_syntax "${part1}$autocomp ${part2}" | _sc_innercolour "$autocomp" $'\e[90;2m' )\e[0K\e[0m\e8" 
#   else
#     echo -en "$(highlight_bash_syntax "${part1}${part2}")\e[0K\e[0m\e8" 
#   fi
#   # # # echo -en "${rlbuffer}\e[90;2m${autocomp}\e[0m\e[0K\e8"
#   # # # echo -en "${rlbuffer}\e[0K\e[${ac_col}G${autocomp}\e[0m\e8"
#   # # echo -en "$(highlight_bash_syntax "${rlbuffer}")\e[0K\e[${ac_col}G${autocomp}\e[0m\e8" 
#   # echo -en "$(highlight_bash_syntax "${part1}")\e[0K\e[${ac_col}G${autocomp}\e[0m\e8" 
# }
# _sc_overwrite () {
#   _sc_afterwrite "$@" 2>/dev/null & disown
#   wait -n
# }