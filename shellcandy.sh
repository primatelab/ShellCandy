#! /bin/bash

declare -A COLOUR

################ THEME ###############
    COLOUR[quote]="38;5;221"
 COLOUR[variable]="38;5;202"
     COLOUR[misc]="38;5;208"
   COLOUR[number]="38;5;153"
 COLOUR[operator]="38;5;213"
  COLOUR[keyword]="38;5;81"
  COLOUR[comment]="38;5;61"
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

########### Create runtime dir, preferrably in tmpfs storage
for i in "/run/user/$UID" "/dev/shm" "$HOME/.local" "$HOME" "/tmp/"; do
  if [[ -w "$i" && ! -e ${i}/.shellcandy.$$ ]]; then
    _sc_rtdir="$i/.shellcandy.$$"
    mkdir -p $_sc_rtdir
    break
  fi
done

################### Traps

_sc_byebye () {
  stty "$sttyb"
  rm -rf $_sc_rtdir
}
trap _sc_byebye EXIT

########### Look up the Backspace key
_sc_ERASE="$(stty -a | grep -Po '(?<= erase = )[^;]*' | sed 's/\^/\\C-/')"

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
################# Location and Prompt functions
_sc_themecolour () {
  COLOUR[def]=$(echo $PS1 | grep -o '\[[0-9;]*m' | grep -o '[0-9;]*' | tail -n1)
}
_sc_getpos () {
  local pos
  echo -en "\e[?25l\e[8m\e[6n" > /dev/tty
  IFS=R read -d R -r pos < /dev/tty
  echo -en '\e[?25h\e[28m\r'
  pos="${pos#*[}"
  pos="${pos%;*}"
  echo $pos > $_sc_rtdir/pos
}
_sc_nakedprompt () {
  echo "${1@P}" | sed -r 's/\x1B\]0;.*\a//; s/\x1B\[[0-9;]*[A-Za-z]//g' | tr -d [:cntrl:]
}

############## Completion
_sc_bash_parse () {
  local stack='' cmdline=''
  local whole_line="$@"
  for((i=0;i<${#whole_line};i++)); do
    local chr=${whole_line:i:1}
    cmdline="${cmdline}${chr}"
    [[ -z $stack ]] && stack='n'
    case "${stack}" in
      *n ) case $chr in  ### normal
          "#"   ) stack="${stack}C" ;;
          "'"   ) stack="${stack}s" ;;
          '"'   ) stack="${stack}d" ;;
          ')'   ) stack="${stack%n}"; cmdline="${cmdline%\$\(᛭*}" ;;
          '$'   ) stack="${stack}a" ;;
          '|'   ) stack="${stack}p" ;;
          "\\"  ) stack="${stack}E" ;;
          *     )  ;;
        esac ;;
      *p ) case $chr in  ### A p|pe has been entered
          "|"   ) stack="${stack%p}" ;; # || c'est ne pas une pipe
          *     ) stack="${stack%p}"; cmdline="${cmdline}᛬" ;; # piped subshell
        esac ;;
      *s ) case $chr in  ### single quotes
          "'"   ) stack="${stack%s}" ;;
          *     ) : ;;
        esac ;;
      *e ) case $chr in  # escapable single quotes
          "'"   ) stack="${stack%e}" ;;
          "\\"  ) stack="${stack}E" ;;
          *     ) : ;;
        esac ;;
      *E ) case $chr in  # escaped character
          *     ) stack="${stack%E}" ;;
        esac ;;
      *d ) case $chr in  ### double quotes
          '"'   ) stack="${stack%d}" ;;
          '$'   ) stack="${stack}a" ;;
          "\\"  ) stack="${stack}E" ;;
          *     ) : ;;
        esac ;;
      *a ) case $chr in  ### dollar'd
          [0-9A-Za-z_] ) stack="${stack%a}v" ;;
          "'"          ) stack="${stack%a}e" ;;
          '{'          ) stack="${stack%a}V" ;;
          '('          ) stack="${stack%a}n"; cmdline="${cmdline}᛭" ;; # subshell
          *            ) stack="${stack%a}" ;;
        esac ;;
      *v ) case $chr in  ### variable
          [0-9A-Za-z_] )  ;;
          *            ) stack="${stack%v}";; 
        esac ;;
      *V ) case $chr in  ### variable expansion
          '}' ) stack="${stack%V}" ;;
          *   ) : ;;
        esac ;;
      *C ) : ;;  ### Comment
    esac
  done
  out="${cmdline##*᛭}" # output current () subshell
  out="${out##*᛬}" # output current | subshell
  echo "$stack" "$out"
}
_sc_autocomplete () {
  local arr=( $(_sc_bash_parse "$@") )
  local stack="${arr[0]}"
  unset arr[0]
  local cmdline="${arr[@]}"
  if [[ "$stack" != *s && "$stack" != *d && "$stack" != *C ]]; then # don't do completions in strings and comments
    [[ -f /etc/bash_completion ]] && source /etc/bash_completion
    COMP_LINE="$cmdline"
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
    COMPREPLY=( ${COMPREPLY[@]/_sc_*/} ) ## Hide ShellCandy internals
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
_sc_tabcomplete () {                    # stdout is the prefix, $_sc_rtdir/comp is the output
  local arr=( $(_sc_bash_parse "$@") )
  local stack="${arr[0]}"
  unset arr[0]
  local cmdline="${arr[@]}"
  if [[ "$stack" != *s && "$stack" != *d && "$stack" != *C ]]; then # don't do completions in strings and comments
    [[ -f /etc/bash_completion ]] && source /etc/bash_completion
    COMP_LINE="$cmdline"
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
    COMPREPLY=( ${COMPREPLY[@]/_sc_*/} ) ## Hide ShellCandy internals
    if (("${#COMPREPLY[@]}" > 1)); then
      echo "$cur" #> $_sc_rtdir/comp
      IFSb="$IFS"
      IFS=$'\n'
      echo "${COMPREPLY[*]}" > $_sc_rtdir/comp
      IFS="$IFSb"
    else
      : > $_sc_rtdir/comp
    fi
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
        sub="${colourcode}${item}"$'\e'"[${COLOUR[def]}m"
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
  MODE[n]=$'\e'"[${COLOUR[def]}m"
  MODE[a]=$'\e'"[1;${COLOUR[operator]}m"
  MODE[s]=$'\e'"[1;${COLOUR[quote]}m"
  MODE[e]=$'\e'"[1;${COLOUR[quote]}m"
  MODE[E]=$'\e'"[${COLOUR[operator]}m"
  MODE[D]=$'\e'"[${COLOUR[operator]}m"
  MODE[d]=$'\e'"[22;${COLOUR[quote]}m"
  MODE[V]=$'\e'"[${COLOUR[variable]}m"
  MODE[v]=$'\e'"[${COLOUR[variable]}m"
  MODE[C]=$'\e'"[3;${COLOUR[comment]}m"
  #---
  local b=$'\e[1m'
  local B=$'\e[22m'
  local p=$'\e'"[1;${COLOUR[operator]}m"
  local P=$'\e[22;39m'
  local m=$'\e'"[1;${COLOUR[misc]}m"
  local M=$'\e[22;39m'
  local n=$'\e'"[1;${COLOUR[number]}m"
  local N=$'\e[22;39m'
  # out="${MODE[n]}"
  for((i=0;i<${#whole_line};i++)); do
    local chr=${whole_line:i:1}
    [[ -z $stack ]] && stack='n'
    (( i == READLINE_POINT )) && echo "$stack" > $_sc_rtdir/stack
    case "${stack}" in
      *n ) case $chr in  # normal
          ')'   ) stack="${stack%n}"; insrt="$b${chr}$B${MODE[${stack:(-1)}]}" ;;
          "'"   ) stack="${stack}s" ;;&
          '"'   ) stack="${stack}d" ;;&
          '$'   ) stack="${stack}a" ;;&
          "#"   ) stack="${stack}C" ;;&
          "\\"  ) stack="${stack}E" ;;&
          [\)\'\"\$\#\\]   ) insrt="${MODE[${stack:(-1)}]}${chr}" ;;
          [\*\|\<\>\[\]\&] ) insrt="$p$chr$P" ;;
          *     ) insrt="$chr" ;;
        esac ;;
      *e ) case $chr in  # escapable single quotes (eg $'foo')
          "'"   ) stack="${stack%e}"; insrt="${chr}${MODE[${stack:(-1)}]}" ;;
          "\\"  ) stack="${stack}E";  insrt="${MODE[${stack:(-1)}]}${chr}" ;;
          *     )                     insrt="${MODE[${stack:(-1)}]}$chr" ;;
        esac ;;
      *E ) case $chr in  # escaped character
          *     ) stack="${stack%E}"; insrt="${chr}${MODE[${stack:(-1)}]}" ;;
        esac ;;
      *D ) case $chr in  # escaped \" in double quotes
          '"'   ) stack="${stack%D}"; insrt="${chr}${MODE[${stack:(-1)}]}" ;;
          *     ) stack="${stack%D}"; insrt="${MODE[${stack:(-1)}]}"$'\e[1D\\'"${chr}" ;;
        esac ;;
      *s ) case $chr in  # single quotes
          "'"   ) stack="${stack%s}"; insrt="${chr}${MODE[${stack:(-1)}]}" ;;
          *     )                     insrt="${MODE[${stack:(-1)}]}$chr" ;;
        esac ;;
      *d ) case $chr in  # double quotes
          '"'   ) stack="${stack%d}"; insrt="${chr}${MODE[${stack:(-1)}]}" ;;
          '$'   ) stack="${stack}a";  insrt="${MODE[${stack:(-1)}]}${chr}" ;;
          "\\"  ) stack="${stack}D";  insrt="${MODE[${stack:(-1)}]}${chr}" ;;
          *     )                     insrt="${MODE[${stack:(-1)}]}$chr" ;;
        esac ;;
      *a ) case $chr in  # dollar'd
          [0-9A-Za-z_*@#?\$\!-] ) stack="${stack%a}v"; insrt="${MODE[${stack:(-1)}]}"$'\e[1D$'"${chr}" ;;
          '{'          ) stack="${stack%a}V" ;;&
          "'"          ) stack="${stack%a}e" ;;&
          '('          ) stack="${stack%a}n" ;;& # subshell
          [\{\'\(]     ) insrt="${MODE[${stack:(-1)}]}$b"$'\e[1D$'"${chr}$B" ;;
          *            ) stack="${stack%a}"; insrt="$chr" ;;
        esac ;;
      *v ) case $chr in  # variable
          [0-9A-Za-z_] ) insrt="${MODE[${stack:(-1)}]}${chr}" ;;
          *            ) stack="${stack%v}"; insrt="${MODE[${stack:(-1)}]}"; ((i--)) ;; # subshell
        esac ;;
      *V ) case $chr in  # expanded variable
          '}' ) stack="${stack%V}"; insrt="$m${chr}$M${MODE[${stack:(-1)}]}" ;;
          [A-Za-z_] ) insrt="${MODE[${stack:(-1)}]}$chr" ;;
          [0-9]     ) insrt="${MODE[${stack:(-1)}]}$n${chr}$N" ;;
          [\[\]\#\%\@\,\^\(\)\*\+\/\?]   ) insrt="$m$chr$M" ;;
          *   ) insrt="$b$chr$B" ;;
        esac ;;
      *C ) insrt="$chr" ;; # Comment: do nothing else
    esac
    out="${out}${insrt}"
  done
  echo -n "$out"
}
_sc_bash_words () {
  local b=$'\e'"[1m"
  local k=$'\e'"[1;${COLOUR[keyword]}m"
  local r=$'\e'"[${COLOUR[def]}m"
  local line cmd
  line="$@"
  krx="$(compgen -k | grep '[a-z]' | tr $'\n' '|' )break"
  read cmd _ <<< "$line"
  cmdrgx="$(compgen -ca | grep -Ev "($krx)" | sort -u | grep "^${cmd}$")"
  sed -E "
    s/\b($krx)\b/${k}\1${r}/g;
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
  read PS < $_sc_rtdir/PS
  read pos < $_sc_rtdir/pos
  case "${PS}" in
    PS1 ) NP="$(_sc_nakedprompt "$PS1")" ;;
    PS2 ) NP="$(_sc_nakedprompt "$PS2b")" ;;
  esac
  outout=$'\e[?25l\e7\e'"[$pos;$((${#NP}+1))H"
  if [[ -z $autocomp || "${part2%% *}" == "${autocomp%…}"* ]]; then
    outout="${outout}$(highlight_bash_syntax "${part1}${part2}")"$'\e[0K\e'"[${COLOUR[def]}m"$'\e[?25h\e8'
  else
    local p2w1="${part2%% *}"
    autocomp="${autocomp%$p2w1}"
    outout="${outout}$(highlight_bash_syntax "${part1}${autocomp}${part2}")"$'\e[0K\e'"[$pos;$(( ${#NP} + $READLINE_POINT + 1))H"$'\e'"[1;${COLOUR[comp]}m${autocomp}"$'\e'"[${COLOUR[def]}m"$'\e[?25h\e8'
  fi
  echo -n "$outout"
  if [[ "$@" != *"nodel"* && $_sc_TabCompLines -gt 0 ]] ; then
    echo -n $'\e7'
    for((i=0;i<_sc_TabCompLines;i++)); do
      echo -n $'\n\e[2K'
    done
    echo -n $'\e'"[${_sc_TabCompLines}A"$'\e8' # Clears the tabcomp columns
  fi
}
_sc_overwrite () {
  _sc_afterwrite "$@" 2>/dev/null & disown
}
_sc_underprint () {  #stdin is the list, $1 is the term to highlight
  local pfx="$1" rowlim="${2:-6}" e=$'\e' rowcount=0 cl=$COLUMNS
  mapfile allwords
  for((i=0;i<"${#allwords[@]}";i++)); do
    rowcount=$(
    for j in "${allwords[@]:0:i}"; do
      echo "$j"
    done | column -c $cl | wc -l)
    if ((rowcount > rowlim)); then
      ((i--))
      break
    fi
  done
  pfx="$(sed -E 's/\$/\\$/g; s/\{/\\{/g' <<< "$pfx"})"
  echo " ${allwords[@]:0:$i}" | column -c $cl | sed -E "s|(\s)${pfx}|$e[1;${COLOUR[lightcomp]}m\1$pfx$e[1;${COLOUR[comp]}m|g"
}

################# Input
_sc_key () {
  local key="$1"
  [[ $key != "\t" ]] && ((_sc_TabTaps=0))
  case "$key" in
    "\t" )
      ((_sc_TabTaps++))
      if (( READLINE_POINT > 0 )); then
        local part1="${READLINE_LINE:0:$READLINE_POINT}"
        local part2="${READLINE_LINE:$READLINE_POINT}"
        local autocomp="$(_sc_autocomplete "${part1}")"
        autocomp="${autocomp// /\\\ }"
        # if [[ ! "${READLINE_LINE:$READLINE_POINT:${#READLINE_LINE}}" == "${autocomp%…}"* ]]; then
        if [[ ! "${part2}" == "${autocomp%…}"* ]]; then
          local p2w1="${part2%% *}"
          autocomp="${autocomp%$p2w1}"
          READLINE_LINE="${part1}${autocomp%…}${part2}"
          ((READLINE_POINT += ${#autocomp}))
          (_sc_overwrite 2>/dev/null)
          _sc_TabCompLines=0
        else
          if [[ -n "$autocomp" ]]; then
            ((READLINE_POINT += ${#autocomp}))
            (_sc_overwrite 2>/dev/null)
            _sc_TabCompLines=0
          else
            local comppfx="$(_sc_tabcomplete "${part1}")"
            local tabcomp="$(_sc_underprint "${comppfx}" < $_sc_rtdir/comp)"
            if [[ -n $tabcomp ]]; then
              _sc_TabCompLines=$(wc -l <<< "$tabcomp")
              echo -n $'\e[1B'"${tabcomp}"$'\e'"[${_sc_TabCompLines}A"
              _sc_getpos
              (_sc_overwrite nodel 2>/dev/null)
            else
              (_sc_overwrite 2>/dev/null)
              _sc_TabCompLines=0
            fi
          fi
        fi
      fi
    ;;
    "\e[C" ) ((READLINE_POINT < ${#READLINE_LINE})) && ((READLINE_POINT++)) ;;&
    "\e[D" ) ((READLINE_POINT > 0)) && ((READLINE_POINT--)) ;;&
    "\e[A" )
      ((_sc_HistBack<HISTCMD?_sc_HistBack++:_sc_HistBack))
    ;;& 
    "\e[B" )
      ((_sc_HistBack>0?_sc_HistBack--:_sc_HistBack))
    ;;& 
    "\e["[AB] )
      # up arrow, down arrow
      local HistLine=$(HISTTIMEFORMAT= builtin history | grep "^ *$((HISTCMD-_sc_HistBack))" )
      READLINE_LINE="${HistLine##+( )+([0-9])+( )}"
     ;;&
    "\e[H" ) READLINE_POINT=0 ;;&
    "\e["[FAB] ) READLINE_POINT=${#READLINE_LINE} ;;&
    "\e["[ABCDFH] )
      # Left arrow, right arrow, up arrow, down arrow, home, end
      (_sc_overwrite 2>/dev/null)
      _sc_TabCompLines=0
     ;;
    "\C-l" )
      ### Clear screen
      clear
      _sc_TabCompLines=0
      _sc_getpos
    ;;
    "\C-r" )
      # TODO
      # Reverse history search
      :
    ;;
    "\e[3~" ) 
      READLINE_LINE=${READLINE_LINE:0:READLINE_POINT}${READLINE_LINE:READLINE_POINT+1} # Delete
      _sc_TabCompLines=0
      (_sc_overwrite nocomp 2>/dev/null)
    ;;
    "$_sc_ERASE" )
      if ((READLINE_POINT > 0)); then
        READLINE_LINE=${READLINE_LINE:0:READLINE_POINT-1}${READLINE_LINE:READLINE_POINT} # Backspace
        ((READLINE_POINT--))
        _sc_TabCompLines=0
        (_sc_overwrite nocomp 2>/dev/null)
      fi
    ;;
    * )
      ### Self-insert
      READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${key}${READLINE_LINE:$READLINE_POINT}"
      ((READLINE_POINT++))
      (_sc_overwrite 2>/dev/null)
      _sc_TabCompLines=0
    ;;
  esac
  : > $_sc_rtdir/comp
}

######## INIT  ###############

## Command keys
CmdKeys=( '\C-y' '\C-l' '\e[A' '\e[B' '\e[C' '\e[D' '\e[F' '\e[H' '\t' "$_sc_ERASE" '\e[3~' )

## Text keys
for char in {0..9} {a..z} {A..Z} ' ' {\!,\",\£,\$,%,^,\*,\(,\),-,=,_,+,[,],\{,\},\;,\',\#,:,@,\~,\,,.,/,\<,\>,\?,\|} "${CmdKeys[@]}" ; do
  bind "-x \"${char}\": _sc_key \"${char}\""
done

## Shell and terminal options
stty erase undef
shopt -s extglob

## Globals
COLOUR[def]="0" # default colour, determined by the PS1
declare -i -g _sc_TabCompLines=0
declare -i -g _sc_TabTaps=0
declare -i -g _sc_HistBack=0
unset char CmdKeys

################## Finding the row, etc
PROMPT_COMMAND=( '_sc_getpos' '_sc_themecolour' "echo PS1 > $_sc_rtdir/PS" ": > $_sc_rtdir/comp" "echo n > $_sc_rtdir/stack" '_sc_overwrite 2>/dev/null' '_sc_HistBack=0')
PS2b="$PS2"
PS2="\$(echo PS2 > $_sc_rtdir/PS; _sc_getpos)$PS2b"
