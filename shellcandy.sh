#! /bin/bash

################ THEME ###############
declare -A COLOUR

COLOUR[quote]="38;5;221"
COLOUR[variable]="38;5;202"
COLOUR[misc]="38;5;208"
COLOUR[number]="38;5;153"
COLOUR[operator]="38;5;213"
COLOUR[keyword]="38;5;81"
COLOUR[comp]="38;5;240"
COLOUR[lightcomp]="38;5;250"

######################################

sttyb="$(stty -g)"
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then 
  rndclr () { echo -en "\e[38;5;$((($RANDOM % 130)+100))m"; }
  echo
  for char in 🍬 Ｓ ｈ ｅ ｌ ｌ Ｃ ａ ｎ ｄ ｙ 🍬 '\n\n' '~' Making '~' Bash '~' Look '~' Sweeet '~'; do
    echo -en "\e[1m$(rndclr)${char} "
  done
  echo
  case "${1,,}" in
    -i | --install )
      # echo -e "\n\e[0m"
      echo -en "\n\n$(rndclr)"
      read -ei "$HOME/.shellcandy" -p $'\e[1m'"Install location: "$'\e[0m' dest
      if [[ -w "${dest%/*}" && ! -e "$dest" ]]; then
        echo "$(rndclr)Installinating..."
        cp "$0" "$dest"
        chmod +x "$dest"
        if ( ! grep -E "^\. (${dest/$HOME/\~}|${dest/$HOME/\~})" $HOME/.bashrc &>/dev/null) ; then
          echo -e "\n. ${dest/$HOME/\~}" >> .bashrc
        fi
        echo "$(rndclr)Shell$(rndclr)Candy$(rndclr) is now installed."      
      else
        echo "$(rndclr)Couldn't install to $(rndclr)$dest"
        exit 1
      fi
    ;;
    -t | --try )
      bash --rcfile <(cat ~/.bashrc; echo ". $0 ; clear")
      echo -en "\n\e[1m$(rndclr)That was "
      for char in Ｓ ｈ ｅ ｌ ｌ Ｃ ａ ｎ ｄ ｙ '.' '\n\n\e[0m'; do
        echo -en "\e[1m$(rndclr)${char}"
      done
    ;;
    *) 
      echo -e "\n\e[1;38;5;189m Usage:\e[22m"
      echo -e "  -i, --install : Install ShellCandy \e[2m(Copy this file and source it in .bashrc)\e[22m"
      echo -e "  -t, --try     : Try ShellCandy now \e[2m(Starts a new shell with this file sourced)\e[0m\n"
    ;;
  esac
  unset -f rndclr
  exit
fi

for i in "/run/user/$UID" "/dev/shm" "$HOME/.local" "$HOME" "/tmp/"; do
  if [[ -w "$i" && ! -e ${i}/.shellcandy.$$ ]]; then
    rtdir="$i/.shellcandy.$$"
    mkdir -p $rtdir
    break
  fi
done
byebye () {
  stty "$sttyb"
  rm -rf $rtdir
}
trap byebye EXIT

########### Look up the Backspace key
ERASE="$(stty -a | grep -Po '(?<= erase = )[^;]*' | sed 's/\^/\\C-/')"

########### Misc functions
common_prefix () {
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
################# Location
_sc_getpos () {
  echo -en "\e[?25l\e[8m\e[6n" > /dev/tty
  IFS=R read -d R -r pos < /dev/tty
  echo -en '\e[?25h\e[28m\r'
  pos="${pos#*[}"
  pos="${pos%;*}"
  echo $pos > $rtdir/pos
}
_sc_nakedprompt () {
  echo "${1@P}" | sed -r 's/\x1B\]0;.*\a//; s/\x1B\[[0-9;]*[A-Za-z]//g' | tr -d [:cntrl:]
}

############## Completion
_sc_bash_parse () {
  local stack
  local whole_line="$@"
  for((i=0;i<${#whole_line};i++)); do
    local chr=${whole_line:i:1}
    [[ -z $stack ]] && stack='n'
    case "${stack}" in
      *n ) case $chr in
          "'"   ) stack="${stack}s" ;;
          '"'   ) stack="${stack}d" ;;
          ')'   ) stack="${stack%n}" ;;
          '$'   ) stack="${stack}a" ;;
          *     )  ;;
        esac ;;
      *s ) case $chr in
          "'"   ) stack="${stack%s}" ;;
          *     ) : ;;
        esac ;;
      *d ) case $chr in
          '"' ) stack="${stack%d}" ;;
          '$' ) stack="${stack}a" ;;
          *   ) : ;;
        esac ;;
      *a ) case $chr in
          [0-9A-Za-z_] ) stack="${stack%a}v" ;;
          '{'          ) stack="${stack%a}V" ;;
          '('          ) stack="${stack%a}n";; #subshell
          *            ) stack="${stack%a}" ;;
        esac ;;
      *v ) case $chr in
          [0-9A-Za-z_] )  ;;
          *            ) stack="${stack%v}";; #subshell
        esac ;;
      *V ) case $chr in
          '}' ) stack="${stack%V}" ;;
          *   ) : ;;
        esac ;;
    esac
  done
  echo "$stack" > $rtdir/stack
}
_sc_autocomplete () {
  _sc_bash_parse "$@"
  local stack="$(cat $rtdir/stack)"
  # if [[ "$stack" == *n ]]; then 
  if [[ "$stack" != *s && "$stack" != *d ]]; then # don't do completions in strings
    [[ -f /etc/bash_completion ]] && source /etc/bash_completion
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
      if [[ -d "$s_word" && -z "$(type -t "$s_word")" ]]; then
        s_word="${s_word%/}/"
      fi
    else
      local s_word="$(common_prefix "${COMPREPLY[@]}")…"
    fi
    local suff="${s_word#$cur}"
    if [[ -n "${suff}" && "${suff}" != '…' ]]; then
      echo "${suff}"
    fi
  fi
}
_sc_tabcomplete () {
  _sc_bash_parse "$@"
  local stack="$(cat $rtdir/stack)"
  # if [[ "$stack" == *n ]]; then 
  if [[ "$stack" != *s && "$stack" != *d ]]; then # don't do completions in strings
    [[ -f /etc/bash_completion ]] && source /etc/bash_completion
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
      local completion_func="$(complete -p "$cmd")"
      completion_func="${completion_func##* -F }"
      completion_func="${completion_func%% *}"
      if [[ -n $completion_func && $(type -t "$completion_func") == "function" ]]; then
        "$completion_func" &>/dev/null
      fi
    fi
    if (("${#COMPREPLY[@]}" > 1)); then
    longest=''
    for i in "${COMPREPLY[@]}"; do
      (( ${#i} > ${#longest} )) && longest=${i}
    done
    local outcols=$(( ($COLUMNS / ${#longest})-1 ))
    for((i=0;i<${#COMPREPLY[@]};i++)); do
      (( (i % outcols) == 0 )) && echo || echo -n "¬"
      echo -n "${COMPREPLY[$i]}"
    done | column -s¬ -t > $rtdir/comp
      compcolumns="$(
        for i in "${COMPREPLY[@]}"; do
          echo -e "\e[1;${COLOUR[lightcomp]}m${cur}\e[0m\e[1;${COLOUR[comp]}m${i#$cur}\e[0m"
        done | paste - - - - - | head -n6)"
      TabCompLines=$(echo "$compcolumns" | wc -l)
      if (( TabCompLines > 5 )); then
        compcolumns="$(echo "$compcolumns" | head -n5)
        \e[1;${COLOUR[lightcomp]}m "$'\t'" "$'\t'" --more-- "$'\t'" "$'\t'" \e[0m"
      fi
      echo "$compcolumns"
    else
      TabCompLines=0
    fi | column -s$'\t' -t -c $(($COLUMNS/6))
  fi
}

####################### Syntax Highlighting
_sc_ls_colors () {
  local whole_line="$@"
  local -a words
  read -ra words <<< "$whole_line"
  for item in ${words[@]} ; do
    # item="${item// / }"
    if [[ -e "$item" || -h "$item" ]]; then
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
        colourcode=$'\e'"[${colourcode}m"
        sub="${colourcode}${item}"$'\e[0m'
        whole_line="${whole_line// $item / $sub }"
        whole_line="${whole_line/#$item /$sub }"
        whole_line="${whole_line/% $item/ $sub}"
      fi
    fi
  done
  echo -n "$whole_line"
}
_sc_bash_quotes () {
  local stack insrt out
  local whole_line="$@"
  #--- colours
  declare -A MODE
  MODE[n]=$'\e[22;39m'
  MODE[a]=$'\e'"[1;${COLOUR[operator]}m"
  MODE[s]=$'\e'"[1;${COLOUR[quote]}m"
  MODE[d]=$'\e'"[22;${COLOUR[quote]}m"
  MODE[V]=$'\e'"[${COLOUR[variable]}m"
  MODE[v]=$'\e'"[${COLOUR[variable]}m"
  #---
  local b=$'\e[1m'
  local B=$'\e[22m'
  local p=$'\e'"[1;${COLOUR[operator]}m"
  local P=$'\e[22;39m'
  local m=$'\e'"[1;${COLOUR[misc]}m"
  local M=$'\e[22;39m'
  local n=$'\e'"[1;${COLOUR[number]}m"
  local N=$'\e[22;39m'
  for((i=0;i<${#whole_line};i++)); do
    local chr=${whole_line:i:1}
    [[ -z $stack ]] && stack='n'
    (( i == READLINE_POINT )) && echo "$stack" > $rtdir/stack
    case "${stack}" in
      *n ) case $chr in
          "'"   ) stack="${stack}s"; insrt="${MODE[${stack:(-1)}]}${chr}" ;;
          '"'   ) stack="${stack}d"; insrt="${MODE[${stack:(-1)}]}${chr}" ;;
          ')'   ) stack="${stack%n}"; insrt="$b${chr}$B${MODE[${stack:(-1)}]}" ;;
          '$'   ) stack="${stack}a"; insrt="${MODE[${stack:(-1)}]}${chr}" ;;
          [\*\|\<\>\[\]\&]     ) insrt="$p$chr$P" ;;
          *     ) insrt="$chr" ;;
        esac ;;
      *s ) case $chr in
          "'"   ) stack="${stack%s}"; insrt="${chr}${MODE[${stack:(-1)}]}" ;;
          *     ) insrt="${MODE[${stack:(-1)}]}$chr" ;;
        esac ;;
      *d ) case $chr in
          '"' ) stack="${stack%d}"; insrt="${chr}${MODE[${stack:(-1)}]}" ;;
          '$' ) stack="${stack}a"; insrt="${MODE[${stack:(-1)}]}${chr}" ;;
          *   ) insrt="${MODE[${stack:(-1)}]}$chr" ;;
        esac ;;
      *a ) case $chr in
          [0-9A-Za-z_*@#?\$\!-] ) stack="${stack%a}v"; insrt="${MODE[${stack:(-1)}]}"$'\e[1D$'"${chr}" ;;
          '{'          ) stack="${stack%a}V"; insrt="${MODE[${stack:(-1)}]}$b"$'\e[1D$'"${chr}$B" ;;
          "'"          ) stack="${stack%a}s"; insrt="${MODE[${stack:(-1)}]}$b"$'\e[1D$'"${chr}$B" ;;
          '('          ) stack="${stack%a}n"; insrt="${MODE[${stack:(-1)}]}$b"$'\e[1D$'"${chr}$B" ;; # subshell
          *            ) stack="${stack%a}"; insrt="$chr" ;;
        esac ;;
      *v ) case $chr in
          [0-9A-Za-z_] ) insrt="${MODE[${stack:(-1)}]}${chr}" ;;
          *         ) stack="${stack%v}"; insrt="${MODE[${stack:(-1)}]}"; ((i--)) ;; # subshell
        esac ;;
      *V ) case $chr in
          '}' ) stack="${stack%V}"; insrt="$m${chr}$M${MODE[${stack:(-1)}]}" ;;
          [A-Za-z_] ) insrt="${MODE[${stack:(-1)}]}$chr" ;;
          [0-9]     ) insrt="${MODE[${stack:(-1)}]}$n${chr}$N" ;;
          [\[|\]|\#|\%|\@|\,|\^]   ) insrt="$m$chr$M" ;;
          *   ) insrt="$b$chr$B" ;;
        esac ;;
    esac
    out="${out}${insrt}"
  done
  echo -n "$out"
}
_sc_bash_words () {
  local b=$'\e'"[1m"
  local k=$'\e'"[1;${COLOUR[keyword]}m"
  local r=$'\e'"[22;39m"
  local line cmd
  line="$@"
  read cmd _ <<< "$line"
  cmdrgx="$(compgen -ca | sort -u | grep "^${cmd}$")"
  sed -E "
    s/\s(if|fi|then|else|elif|for|in|do|done|while|break|function|return|exit|case|esac)\s/ ${k}\1${r} /g;
    s/^(\s*$cmdrgx)\b/${b}\1${r}/" <<< "$line"
}
highlight_bash_syntax () {
  _sc_bash_words "$(_sc_ls_colors "$(_sc_bash_quotes "$@")")"
}



####################### Display
_sc_afterwrite () {
  local part1="${READLINE_LINE:0:$READLINE_POINT}"
  local part2="${READLINE_LINE:$READLINE_POINT:${#READLINE_LINE}}"
  local NP PS pos outout autocomp
  [[ "$@" == *"nocomp"* ]] || autocomp="$(_sc_autocomplete "$part1")"
  read PS < $rtdir/PS
  read pos < $rtdir/pos
  case "${PS}" in
    PS1 ) NP="$(_sc_nakedprompt "$PS1")" ;;
    PS2 ) NP="$(_sc_nakedprompt "$PS2b")" ;;
  esac
  outout=$'\e[?25l\e7\e'"[$pos;$((${#NP}+1))H"
  # (( READLINE_POINT > 0 )) && outout=$'\e[?25l\e7\e'"[${READLINE_POINT}D" || outout=$'\e[?25l\e7'
  # if [[ -z $autocomp || "$part2" == "${autocomp%…}"* ]]; then
  if [[ -z $autocomp || "${part2%% *}" == "${autocomp%…}"* ]]; then
    outout="${outout}$(highlight_bash_syntax "${part1}${part2}")"$'\e[0K\e[0m\e[?25h\e8'
  else
    local p2w1="${part2%% *}"
    autocomp="${autocomp%$p2w1}"
    outout="${outout}$(highlight_bash_syntax "${part1}${autocomp}${part2}")"$'\e[0K\e'"[$pos;$(( ${#NP} + $READLINE_POINT + 1))H"$'\e'"[1;${COLOUR[comp]}m${autocomp}"$'\e[0m\e[?25h\e8'
  fi
  echo -n "$outout"
  if [[ "$@" != *"nodel"* && $TabCompLines -gt 0 ]] ; then
    echo -n $'\e7'
    for((i=0;i<TabCompLines;i++)); do
      echo -n $'\n\e[2K'
    done
    echo -n $'\e'"[${TabCompLines}A"$'\e8' # Clears the autocomp columns
  fi
}
_sc_overwrite () {
  _sc_afterwrite "$@" 2>/dev/null & disown
}

################# Input
_sc_key () {
  local key="$1"
  case "$key" in
    "\t" )
      # if [[ -n "$READLINE_LINE" ]]; then
      if (( READLINE_POINT > 0 )); then
        local part1="${READLINE_LINE:0:$READLINE_POINT}"
        local part2="${READLINE_LINE:$READLINE_POINT}"
        local autocomp="$(_sc_autocomplete "${part1}")"
        autocomp="${autocomp// /\\\ }"
        if [[ ! "${part2}" == "${autocomp%…}"* ]]; then
          local p2w1="${part2%% *}"
          autocomp="${autocomp%$p2w1}"
          READLINE_LINE="${part1}${autocomp%…}${part2}"
          ((READLINE_POINT += ${#autocomp}))
          (_sc_overwrite 2>/dev/null)
          TabCompLines=0
        else
          if [[ -z "$autocomp" ]]; then
            local tabcomp="$(_sc_tabcomplete "${part1}")"
            if [[ -n $tabcomp ]]; then
              TabCompLines=$(echo "$tabcomp" | wc -l)
              echo -n $'\e[1B'"${tabcomp}"$'\e'"[${TabCompLines}A"
              _sc_getpos
              (_sc_overwrite nodel 2>/dev/null)
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
      # Left arrow, right arrow, home, end
      (_sc_overwrite 2>/dev/null)
      TabCompLines=0
      return
    ;;
    "\C-l" )
      ### Clear screen
      clear
      TabCompLines=0
      _sc_getpos
    ;;
    "\e[3~" ) 
      READLINE_LINE=${READLINE_LINE:0:READLINE_POINT}${READLINE_LINE:READLINE_POINT+1} # Delete
      TabCompLines=0
      (_sc_overwrite nocomp 2>/dev/null)
    ;;
    "$ERASE" )
      if ((READLINE_POINT > 0)); then
        READLINE_LINE=${READLINE_LINE:0:READLINE_POINT-1}${READLINE_LINE:READLINE_POINT} # Backspace
        ((READLINE_POINT--))
        TabCompLines=0
        (_sc_overwrite nocomp 2>/dev/null)
      fi
    ;;
    * )
      ### Self-insert
      READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${key}${READLINE_LINE:$READLINE_POINT}"
      ((READLINE_POINT++))
      (_sc_overwrite 2>/dev/null)
      TabCompLines=0
    ;;
  esac
}

######## INIT  ###############

## Command keys
CmdKeys=( '\C-y' '\C-l' '\e[C' '\e[D' '\e[F' '\e[H' '\t' "$ERASE" '\e[3~' )

## Text keys
for char in {0..9} {a..z} {A..Z} ' ' {\!,\",\£,\$,%,^,\*,\(,\),-,=,_,+,[,],\{,\},\;,\',\#,:,@,\~,\,,.,/,\<,\>,\?,\|} "${CmdKeys[@]}" ; do
  bind "-x \"${char}\": _sc_key \"${char}\""
done

stty erase undef

unset char CmdKeys

declare -i -g TabCompLines=0

################## Finding the row
PROMPT_COMMAND=( '_sc_getpos' "echo PS1 > $rtdir/PS" "echo n > $rtdir/stack" '_sc_overwrite 2>/dev/null' )
PS2b="$PS2"
PS2="\$(echo PS2 > $rtdir/PS; _sc_getpos)$PS2b"
