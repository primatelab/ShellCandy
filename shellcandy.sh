#! /bin/bash



if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
  echo "Needs to be sourced."
  exit 1
fi

bleat () {
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
  echo -en '\e[?25l\e[8m\e[6n' 
  local a b
  IFS= read -sn1 a
  IFS= read -sdR b
  if [[ ${a} == $'\e' ]]; then
    b=${b#[}
    b=${b%;*}
    export envglobal="${b}"
  fi
  unset a b
  echo -en '\e[?25h\e[28m'
}
_sc_nakedprompt () {
  export NAKEDPROMPT1="$(echo "${PS1@P}" | sed -r 's/\x1B\]0;.*\a//; s/\x1B\[[0-9;]*[A-Za-z]//g' | tr -d [:cntrl:])"
  export NAKEDPROMPT2="$(echo "${PS2@P}" | sed -r 's/\x1B\]0;.*\a//; s/\x1B\[[0-9;]*[A-Za-z]//g' | tr -d [:cntrl:])"
}

_sc_autocomplete () {
  [[ -f /etc/bash_completion ]] && source /etc/bash_completion
  # [[ -f ~/.bashrc.d/completions.sh ]] && source ~/.bashrc.d/completions.sh
  COMP_LINE="$@"
  read -ra COMP_WORDS <<< "$COMP_LINE"
  [[ $COMP_LINE == *" " ]] && COMP_WORDS+=("")
  COMP_CWORD=${#COMP_WORDS[@]}
  ((COMP_CWORD--))
  COMP_POINT=${#COMP_LINE}
  local cmd="${COMP_WORDS[0]}"
  local cur="${COMP_WORDS[$COMP_CWORD]}"
  if (( COMP_CWORD == 0 )); then
    COMPREPLY=( $(compgen -cafu -- "$cmd" | sort -u) )
  else
    COMPREPLY=()
    complete -p "$cmd" &>/dev/null || _completion_loader "$cmd" &>/dev/null
    # read _ _ completion_func _ <<< $(complete -p "$cmd")
    local completion_func="$(complete -p "$cmd")"
    completion_func="${completion_func##* -F }"
    completion_func="${completion_func%% *}"
    if [[ -n $completion_func && $(type -t "$completion_func") == "function" ]]; then
      "$completion_func" &>/dev/null
    fi
  fi
  if (( ${#COMPREPLY[@]} == 0)); then
    local suff=''
  elif (( ${#COMPREPLY[@]} == 1)); then
    local s_word="${COMPREPLY[0]}"
  else
    local s_word="$(common_prefix "${COMPREPLY[@]}")…"
  fi
  local suff="${s_word#$cur}"
  if [[ -n "${suff}" && "${suff}" != '…' ]]; then
    echo "${suff}"
  fi
}

_sc_tabcomplete () {
  [[ -f /etc/bash_completion ]] && source /etc/bash_completion
  COMP_LINE="$@"
  read -ra COMP_WORDS <<< "$COMP_LINE"
  # [[ $COMP_LINE == *" " ]] && COMP_WORDS+=("")
  COMP_CWORD=${#COMP_WORDS[@]}
  ((COMP_CWORD--))
  COMP_POINT=${#COMP_LINE}
  local cmd="${COMP_WORDS[0]}"
  local cur="${COMP_WORDS[$COMP_CWORD]}"
  if (( COMP_CWORD == 0 )); then
    COMPREPLY=( $(compgen -cafu -- "$cmd" | sort -u) )
  else
    COMPREPLY=()
    complete -p "$cmd" &>/dev/null || _completion_loader "$cmd" &>/dev/null
    local completion_func
    # read _ _ completion_func _ <<< $(complete -p "$cmd")
    local completion_func="$(complete -p "$cmd")"
    completion_func="${completion_func##* -F }"
    completion_func="${completion_func%% *}"
    if [[ -n $completion_func && $(type -t "$completion_func") == "function" ]]; then
      "$completion_func" &>/dev/null
    fi
  fi
  if (("${#COMPREPLY[@]}" > 1)); then
    compcolumns="$(
      for i in "${COMPREPLY[@]}"; do
        echo -e "\e[2;1m${cur}\e[0m\e[1;90m${i#$cur}\e[0m"
      # done | paste - - - - - | column -s$'\t' -t -c $(($COLUMNS/6)) | head -n6)"
      done | paste - - - - - | head -n6)"
    _TabCompLines=$(echo "$compcolumns" | wc -l)
    if (( _TabCompLines > 5 )); then
      compcolumns="$(echo "$compcolumns" | head -n5)
      \e[2;1m "$'\t'" "$'\t'" --more-- "$'\t'" "$'\t'" \e[0m"
    fi
    echo "$compcolumns"
  else
    _TabCompLines=0
  fi | column -s$'\t' -t -c $(($COLUMNS/6))
  # for i in "${COMPREPLY[@]}"; do
  #   echo -e "\e[2;1m${cur}\e[0m\e[1;90m${i#$cur}\e[0m"
  # done | paste - - - - - | column -s$'\t' -t -c $(($COLUMNS/6)) | head -n5
}

# function _sc_tabcom_erase () {
#   echo -en "\e[1B\e[2K\e[1B\e[2K\e[1B\e[2K\e[1B\e[2K\e[1B\e[2K\e[6A"
# }

_sc_ls_colors () {
  local whole_line="$@"
  local -a words
  read -ra words <<< "$whole_line"
  for item in ${words[@]} ; do
    if [[ -e $item || -h $item ]]; then
      local itemtype=''
      local sub=''
      local colourcode=''
      local stats=$(stat -c %A "$item" 2>/dev/null)
      case "${stats}" in
        p?????????  ) itemtype="pi" ;;
        s?????????  ) itemtype="so" ;;
        b?????????  ) itemtype="bd" ;;
        c?????????  ) itemtype="cd" ;;
        l?????????  ) [[ -e "${item}" ]] && itemtype="ln" || itemtype="or" ;;
        ???S??????  ) itemtype="su" ;;
        ??????S???  ) itemtype="sg" ;;
        d???????wt  ) itemtype="tw" ;;
        d????????t  ) itemtype="st" ;;
        d???????w?  ) itemtype="ow" ;;
        d?????????  ) itemtype="di" ;;
        -????????x  ) itemtype="ex" ;;
        -?????????  ) itemtype="*.${item##*.}" ;;
        *   ) : ;;
      esac
      colourcode=":${LS_COLORS}"
      colourcode="${colourcode##*:${itemtype}=}"
      colourcode="${colourcode%%:*}"
      if [[ -n $colourcode ]]; then
        colourcode="\e[${colourcode}m"
        sub="${colourcode}${item}\e[0m"
        whole_line="${whole_line// $item / $sub }"
        whole_line="${whole_line/#$item /$sub }"
        whole_line="${whole_line/% $item/ $sub}"
      fi
    fi
  done
  echo -n "$whole_line"
}


## Let the syntax highlighting function be defined elsewhere if you like
# if [[ ! $(declare -F highlight_bash_syntax) == highlight_bash_syntax ]]; then 
  highlight_bash_syntax () {
    local yel=$'\e[33;1m'
    local cya=$'\e[36;1m'
    local wht=$'\e[1m'
    local red=$'\e[31m'
    local dim=$'\e[90;2m'
    local def=$'\e[0m'
    # echo -n "$@" | sed -E "
    local line cmd
    line="$@"
    read cmd _ <<< "$line"

# cmnds=( $(compgen -ca) )
# IFS='|'; echo "${cmnds[*]}"

    sed -E "
      s/\b(if|fi|then|else|elif|for|in|do|done|while|break|function|return|exit|case|esac)\b/${cya}\1${def}/g;
      s/^ *([A-Za-z0-9._-]+\s)/${wht}\1${def}/g;
      s/("'\$'"[A-Za-z0-9_]+)/${red}\1${def}/g;
      s/("'\$'"\{[^}]*\})/${red}\1${def}/g;
      s/("'"'"|')/${yel}\1${def}/g" <<< "$line"
  }
# fi

_sc_afterwrite () {
  local part1="${READLINE_LINE:0:$READLINE_POINT}"
  local part2="${READLINE_LINE:$READLINE_POINT:${#READLINE_LINE}}"
  local autocomp="$(_sc_autocomplete "$part1")"
  part1="${part1//\\/\\\\}"
  part2="${part2//\\/\\\\}"
  part1="$(_sc_ls_colors "$part1")"
  part2="$(_sc_ls_colors "$part2")"
  local whole="$(_sc_ls_colors "${part1}${part2}")"
  # echo -en "\e7\e[?25l\e[$PROMPT1_ROW;$((${#NAKEDPROMPT1} + 1))H\e[0K"
  echo -en "\e7\e[?25l\e[$PROMPT1_ROW;1H${PS1@P}"
  sleep 0.0001
  if (( PROMPT1_ROW != PROMPT2_ROW )); then
    # Making multiline migraines moot
    # echo -en "\e[$PROMPT2_ROW;$((${#NAKEDPROMPT2}+1))H"
    echo -en "\e[$PROMPT2_ROW;1H${PS2@P}"
  fi
  if [[ -z $autocomp || "$part2"* == "${autocomp%…}"* ]]; then
    echo -en "$(highlight_bash_syntax "${whole}")\e[0K\e[0m\e[?25h\e8"
  else
    local x y
    if (( PROMPT1_ROW == PROMPT2_ROW )); then
      x=$PROMPT1_ROW
      y=${#NAKEDPROMPT1}
    else
      x=$PROMPT2_ROW
      y=${#NAKEDPROMPT2}
    fi
    echo -en "$(highlight_bash_syntax "${part1}${autocomp}${part2}")\e[0K\e[$x;$(($y + $READLINE_POINT + 1))H\e[1;90m$autocomp\e[0m\e[?25h\e8" 
  fi
  if (( TabCompLines > 0 )); then
    echo -en "\e7"
    for((i=0;i<TabCompLines;i++)); do
      # echo -en "\e[1B\e[2K"
      echo -en "\n\e[2K"
    done
    echo -en "\e[${TabCompLines}A\e8" # Clears the autocomp columns
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
  # _getrow PROMPT1_ROW &>/dev/null
  _getrow PROMPT2_ROW &>/dev/null
  READLINE_LINE="$rll"
  READLINE_LINE="$rlp"
  _sc_overwrite 2>/dev/null
}
resize () {
  _resize 2>/dev/null & disown
  wait -n
}

# getpos () {
#   echo -en "\e[8m\e[6n" > /dev/tty
#   IFS=R read -d R -r _pos < /dev/tty
#   echo -en '\e[28m\r'
#   rowcol="${_pos#*[}"
#   row=${rowcol%;*}
#   col=${rowcol#*;}
#   echo $row $col > $tmpdir/rowcol
# }

_sc_key () {
  local key="$1"
  # TabCompLines=0
  case "${key}" in
    "\t" )
      if [[ -n "$READLINE_LINE" ]]; then
        local autocomp="$(_sc_autocomplete "${READLINE_LINE:0:$READLINE_POINT}")"
        if [[ ! "${READLINE_LINE:$READLINE_POINT:${#READLINE_LINE}}" == "${autocomp%…}"* ]]; then 
          READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${autocomp%…}${READLINE_LINE:$READLINE_POINT}"
          ((READLINE_POINT += ${#autocomp}))
          (_sc_overwrite 2>/dev/null)
          TabCompLines=0
        else
          if [[ -z "$autocomp" ]]; then
            # (_sc_overwrite 2>/dev/null)
            local tabcomp="$(_sc_tabcomplete "${READLINE_LINE:0:$READLINE_POINT}")"
            if [[ -n $tabcomp ]]; then
              TabCompLines=$(echo "$tabcomp" | wc -l)
              # echo -en "\e7\e[1B\e[2K${tabcomp}\e[${TabCompLines}A\e8"
              echo -en "\e[1B\e[2K${tabcomp}\e[${TabCompLines}A\r"
            else
              (_sc_overwrite 2>/dev/null)
              TabCompLines=0
            fi
          else
            ((READLINE_POINT += ${#autocomp}))
            (_sc_overwrite 2>/dev/null)
            TabCompLines=0
          fi
        fi
      fi
    ;;
    "\e[C" ) ((READLINE_POINT < ${#READLINE_LINE})) && ((READLINE_POINT++)) ;;&
    "\e[D" ) ((READLINE_POINT > 0)) && ((READLINE_POINT--)) ;;&
    "\e[H" ) READLINE_POINT=0 ;;&
    "\e[F" ) READLINE_POINT=${#READLINE_LINE} ;;&
    "\e["[CDFH] )
      _getrow PROMPT2_ROW
      # [[ -n "$(_sc_autocomplete "${READLINE_LINE:0:$READLINE_POINT}" 2>/dev/null )" ]] && (_sc_overwrite 2>/dev/null)
      (_sc_overwrite 2>/dev/null)
      TabCompLines=0
     ;;
    "\C-y" )
      ### Debugging key
      # getpos
      # _getrow PROMPT1_ROW
      # _getrow PROMPT2_ROW
      # autocomp=\"$(_sc_autocomplete "${READLINE_LINE:0:$READLINE_POINT}")\"
      # tabcomp=\"$(_sc_tabcomplete "${READLINE_LINE:0:$READLINE_POINT}")\"
      bleat "
      READLINE_LINE=\"$READLINE_LINE\"
      READLINE_POINT=\"$READLINE_POINT\"
      TabCompLines=\"$TabCompLines\"
      LINES=\"$LINES\"
      COLUMNS=\"$COLUMNS\"
      _PS=\"$_PS\"
      PROMPT1_ROW=\"$PROMPT1_ROW\"
      PROMPT2_ROW=\"$PROMPT2_ROW\"
      part1=\"${READLINE_LINE:0:$READLINE_POINT}\"
      part2=\"${READLINE_LINE:$READLINE_POINT:${#READLINE_LINE}}\"
      "
      # (_sc_overwrite 2>/dev/null)
    ;;
    "\C-l" )
      ### Clear screen
      clear
      TabCompLines=0
      _getrow PROMPT1_ROW
    ;;
    [[:print:]] )
      ### Self-insert
      READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${key}${READLINE_LINE:$READLINE_POINT}"
      ((READLINE_POINT++))
      _getrow PROMPT2_ROW
      (_sc_overwrite 2>/dev/null)
      TabCompLines=0
    ;;
    *) : ;;
  esac
}

######## INIT  ###############

## Command keys
CmdKeys=( '\C-y' '\C-l' '\e[C' '\e[D' '\e[F' '\e[H' '\t' )

## Text keys
for char in {0..9} {a..z} {A..Z} ' ' {\!,\",\£,\$,%,^,\*,\(,\),-,=,_,+,[,],\{,\},\;,\',\#,:,@,\~,\,,.,/,\<,\>,\?,\|} "${CmdKeys[@]}"; do
  bind "-x \"${char}\": _sc_key \"${char}\""
done

## Testing keys
# bind '-x "\C-y": _sc_key "\C-y"'
# bind '"\C-m": accept-line'

unset char CmdKeys

## Finding the row
PROMPT_COMMAND=( '_getrow PROMPT1_ROW' '_getrow PROMPT2_ROW' _sc_nakedprompt )

trap resize SIGWINCH

declare -i -g TabCompLines=0
declare -g _PS
PS2b="$PS2"
PS2="\$(echo badger >> /tmp/baa)$PS2b"

# ticker () {
#   while :; do
#     echo "-${READLINE_LINE}-" >> /tmp/baa
#     sleep 1
#   done
# }

# ticker & disown

for i in "/run/user/$UID" "/dev/shm" "$HOME/.cache" "$HOME" "/tmp/"; do
  if [[ -w "$i" && ! -e ${i}/$$ ]]; then
    tmpdir="$i/.shellcandy.$$"
    mkdir $tmpdir
    break
  fi
done
trap "rm -rf $tmpdir" EXIT

function rndclr () {
  local char CLR
  for char in $(fold -w1 <<< $1); do
    CLR=$(( ($RANDOM % 130) + 100))
    echo -en "\e[38;5;${CLR}m${char}"
  done
}

echo " 🍬 $(rndclr ShellCandy) 🍬"
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