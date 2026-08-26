# My m. OS shortcuts
v() {
  if [ -n "$1" ]; then
    nvim "$1"
  else
    nvim
  fi
}

[ -x "$(command -v nvim)" ] && alias vdiff="nvim -d"

n() {
  cd ~/repos/notes || exit
  nvim
  cd - || exit
}

vn() {
  cd ~/repos/nixos || exit
  nvim
  cd - || exit
}

vv() {
  cd ~/.config/nvim || exit
  nvim
  cd - || exit
}

#TODO Notes
t() {
  cd ~/repos/todo || exit
  git pull

  nvim

  git_status=$(git status -s)
  if [ -n "$git_status" ]; then
    echo "$git_status"

    # git add .
    # git commit -m "Update Todo $(date)"
    # git push
  else
    cd - || exit
  fi

}

tb() {
  cd ~/repos/todo || exit
  git pull

  nvim backlog.md

  git_status=$(git status -s)
  if [ -n "$git_status" ]; then
    git add .
    git commit -m "Update Todo $(date)"
    git push
  fi

  cd - || exit
}

ta() { # Add Todo - ta 'new note to add'
  cd ~/repos/todo || exit
  git pull

  sed -i 6i"- [ ] $1" ~/repos/todo/backlog.md

  git add .
  git commit -m "Add to Backlog $(date)"
  git push

  cd - || exit
  # echo "- [ ] $1" >>~/repos/todo/backlog.md
}

tsearch() { # Search Backlog and Todo for arg
  cd ~/repos/todo || exit
  grep -rniI --exclude-dir={bundles,dist,node_modules,bower_components} todo.md backlog.md -e "$1"
  cd - || exit
}

tpull() { # pull todo
  cd ~/repos/todo || exit
  git pull
  cd - || exit
}

tpush() { # diff/upload todo.md
  cd ~/repos/todo || exit
  git push origin master
  cd - || exit
}

tcommit() { #commit todos
  cd ~/repos/todo || exit
  git diff todo.md
  git add todo.md
  git commit -m "Update Todo $(date)"
  cd - || exit
}

tdiff() { # diff todo.md
  cd ~/repos/todo || exit
  git diff todo.md
  cd - || exit
}

tcleanup() {
  cd ~/repos/todo || exit
  grep "\- \[x\]" todo.md >>done.md
  grep "\- \[n\]" todo.md >>no.md
  sed -i -e '/- \[x]/ d' todo.md
  sed -i -e '/- \[n]/ d' todo.md

  grep "\- \[x\]" backlog.md >>done.md
  grep "\- \[n\]" backlog.md >>no.md
  sed -i -e '/- \[x]/ d' backlog.md
  sed -i -e '/- \[n]/ d' backlog.md

  cd - || exit
}

m.function-definition() {
  declare -f "$1"
}

m.function-where() {
  type -a "$1"
}

m.time-global() {
  echo 'Current:          ' "$(date)"
  echo 'UTC:              ' "$(date -u)"
  echo '              '
  echo 'Los Angeles (-7): ' $(TZ='America/Los_Angeles' date)
  echo 'Chicago: (-5)     ' $(TZ='America/Chicago' date)
  echo 'London: (+1)      ' $(TZ='Europe/London' date)
  echo 'Hong Kong: (+8)   ' $(TZ='Asia/Hong_Kong' date)
}

m.time-zones() {
  timedatectl list-timezones --no-pager
}

m.time-meet() {
  #!/usr/bin/env bash
  # ./meet.sh || meet.sh 09/22
  # ig20180122 - displays meeting options in other time zones
  # ml20220712 - Linux GNU date compatible
  # https://superuser.com/questions/164339/timezone-conversion-by-command-line
  # https://stackoverflow.com/questions/53075017/how-can-i-do-bash-arithmetic-with-variables-that-are-numbers-with-leading-zeroes
  # set the following variable to the start and end of your working day
  # start and end time, with one space
  daystart=8
  dayend=24
  # set the local TZ
  myplace='America/Los_Angeles'
  # set the most common places
  place[1]='America/Chicago'
  place[2]='Europe/London'
  place[3]='Asia/Hong_Kong'
  place[4]='Asia/Kolkata'
  # add cities using place[5], etc.
  # set the date format for search
  dfmt="%m/%d" # date format for meeting date
  # New format so It can be used as argument
  hfmt="+%B %e, %Y" # date format for the header
  # no need to change onwards
  format1="%-12s " # Increase if your cities names are long
  format2="%02d "
  mdate=$1
  if [[ "$1" == "" ]]; then mdate=$(date +"$dfmt"); fi
  # date -j -f "$dfmt" "$hfmt" "$mdate"
  date -d $mdate "$hfmt"                 # GNU linux compliant
  here=$(TZ=$myplace date -d $mdate +%z) # Same Here
  here=$(($(printf "%g" $here) / 100))
  printf "$format1" ${myplace/*\//} #"Here"
  printf "$format2" $(seq $daystart $dayend)
  printf "\n"
  for i in $(seq 1 "${#place[*]}"); do
    there=$(TZ=${place[$i]} date -d "$mdate" +%z) # same here
    there=$(($(printf "%g" $there) / 100))
    city[$i]=${place[$i]/*\//}
    tdiff[$i]=$(($there - $here))
    printf "$format1" ${city[$i]}
    for j in $(seq $daystart $dayend); do
      sub=$(($j + ${tdiff[$i]}))
      if [[ $sub -gt 24 ]]; then sub="$((sub - 24))"; fi
      #if [[ 10#$sub > 12 ]]; then sub="$((10#$sub-12))"; fi
      printf "$format2" $sub
    done
    printf "(%+d)\n" ${tdiff[$i]}
  done
}

m.time-overtime() {
  cd /tmp
  nix-shell -p nodejs --run "git clone https://github.com/diit/overtime-cli.git; \
  cd overtime-cli; \
  npm install; \
  node index.js show America/Los_Angeles America/Chicago Asia/Hong_Kong Europe/London; \
  exit; \
  "
  cd -
}

m.time-time.is() {
  firefox "https://time.is/900AM_4_Feb_2023_in_HKT/Kolkata/GMT/London/San_Francisco"
}
m.time-time.is-table() {
  firefox "https://time.is/compare/900AM_4_Feb_2023_in_HKT/Kolkata/GMT/London/San_Francisco"
}

m.weather_sf() {
  curl wttr.in/sanfrancisco
}

m.weather_chicago() {
  curl wttr.in/chicago
}

m.weather_terralinda() {
  curl wttr.in/94903
}

m.weather() {
  curl wttr.in
}

m.vlcc() {
  vlc -I ncurses "$@"
}

m.vlcc_brain() {
  vlc -I ncurses "$HOME/Music/Brain.fm" --random
}

m.source_alias() {
  source /home/matt/repos/nixos/home/aliases
}

m.edit_vim() {
  nvim ~/.config/nvim/
}

m.edit_alias() {
  nvim ~/repos/nixos/home/aliases
}

m.edit_i3() {
  nvim ~/repos/nixos/home/i3/i3.config
}

m.edit_home_manager() {
  nvim ~/repos/nixos/home/home-baremetal.nix
}

function m.ffmpeg-info() {
  ffmpeg -i "$1"
}
# chatgpt command for extracting audio from mkv
# ffmpeg -i 2024-02-06\ 09-30-08_keeper.ai_tech_interview_1.mkv -vn -acodec pcm_s16le -ar 44100 -ac 2 output.wav
#
# Whisper.cpp 16-bit WAV
# ::: ffmpeg -i input.mp3 -ar 16000 -ac 1 -c:a pcm_s16le output16.wav
# ::: ffmpeg -i input.mp3 -ar 16000 -ac 2 -c:a pcm_s16le output_stereo_16.wav

# ffmpeg -i 2024-02-06\ 09-30-08_keeper.ai_tech_interview_1.mkv -ar 16000 -ac 1 -acodec pcm_s16le output.wav
# gpt:
# ffmpeg -i 2024-02-06\ 09-30-08_keeper.ai_tech_interview_1.mkv -vn  -ac 2 output.wav
#
function m.ffmpeg-reduce-ultrafast() {
  file=$1
  filename=${file%. *}
  extension=${file##*.}

  ffmpeg -i "$file" -c:v libx265 -crf 28 -preset ultrafast "${filename}_ultrafast_reduced.$extension"
}

function m.ffmpeg-reduce-fast() {
  file=$1
  filename=${file%. *}
  extension=${file##*.}

  ffmpeg -i "$file" -c:v libx265 -crf 28 -preset fast "${filename}_fast_reduced.$extension"
}

function m.ffmpeg-extract-wav() {
  file=$1
  ffmpeg -i "$file" -vn -acodec pcm_s16le -ar 16000 -ac 2 "${file}_16Bit.wav"
}

function m.ff() {
  local file
  file=$(fzf --preview 'bat --style=numbers --color=always --line-range :500 {}')
  if [[ $file ]]; then
    $EDITOR "$file"
  else
    echo "cancelled m.ff"
  fi
}

# Custom xrandr auto-adjustment function
m.x() {
  xrandr --auto
}

# Set OPENAI_API_KEY from a decrypted file and run sgpt
sgpt() {
  OPENAI_API_KEY=$(gpg --decrypt $HOME/.chatgpt-secret.txt.gpg 2>/dev/null) sgpt "$@"
}

# Interactive tldr with fzf for command usage summaries
m.tldrf() {
  tldr --list | fzf --preview "tldr {1} --color=always" --preview-window=right,70% | xargs tldr
}

function m.list-alias-functions() {
  # TODO list full definitions, then only paste func name/alias to command line
  echo
  echo -e "\033[1;4;32m""Functions:""\033[0;34m"
  compgen -A function
  echo
  echo -e "\033[1;4;32m""Aliases:""\033[0;34m"
  compgen -A alias
  echo
  echo -e "\033[0m"
}

function m.show-def() {
  item=$1
  itemtype=$(whence -w "$item" | awk '{ print $2}')
  echo "Type: $itemtype"
  if [ "$itemtype" = "alias" ]; then
    alias "$1"
  else
    declare -f "$1"
  fi
}

m.mos-show() {
  declare -f "$1"
  type -a "$1"
}

#menu
function m() {
  local tmpfile=$(mktemp)
  typeset -f >"$tmpfile"
  selected_command=$(compgen -c | fzf \
    --bind "ctrl-n:down,ctrl-p:up,ctrl-d:preview-page-down,ctrl-u:preview-page-up" \
    --preview "sed -n '/^{1} () {$/,/^}$/p' $tmpfile || which {1} 2>/dev/null")
  rm -f "$tmpfile"
  print -z "$selected_command "
}

if [[ "$(uname)" != "Darwin" ]]; then
  function open() {
    xdg-open $1
  }
  function o() {
    xdg-open $1
  }
fi
m.screen() {
  echo "xrandr --query"
  echo "-------------------------------"
  xrandr --query

  echo ""
  echo "xset q"
  echo "-------------------------------"
  xset q

  echo ""
  echo "xrandr --listmonitors"
  echo "-------------------------------"
  xrandr --listmonitors
}

m.screen-above() {
  ~/.config/i3/monitor.sh above
}

m.screen-mirror() {
  ~/.config/i3/monitor.sh same-as
}

m.www() {
  python3 -m http.server
}

alias nvim-new='NVIM_APPNAME="neovim-config" nvim'
alias nvim-plugin-testing='NVIM_APPNAME="nvim-plugin-testing" nvim'

m.rclone-downloads-dry() {
  rclone sync -vP ~/Downloads/ gdrive:NixOS-Downloads --dry-run
}
m.rclone-downloads() {
  rclone sync -vP ~/Downloads/ gdrive:NixOS-Downloads
}

p() {
  python "$@"
}

m.copy() {
  xclip -selection clipboard
}

m.paste() {
  xclip -o -selection clipboard
}

#----- tmux helpers -----
# One entry point: m.tmux
#   m.tmux                    fzf menu: sessions + actions (new/kill/rename/detach/ls)
#   m.tmux <name>             attach-or-create <name> (fast path, no fzf).
#                             Nested ($TMUX set) + missing session prints a hint
#                             rather than nesting, which tmux refuses anyway.
#   m.tmux ls                 plain list-sessions
#   m.tmux kill [name]        kill session (fzf picker if no arg)
#   m.tmux rename <new> [old] rename session (pickers/prompts if args missing)
#   m.tmux detach             detach current client (like prefix + d)

# Session names can't contain spaces (tmux restriction), so fzf rows are
# parsed by taking the first whitespace-separated token.

_tmux_attach_or_create() { # Attach/switch if session exists, else create it
  local name="$1"
  if tmux has-session -t "$name" 2>/dev/null; then
    if [ -n "$TMUX" ]; then
      tmux switch-client -t "$name"
    else
      tmux attach -t "$name"
    fi
  else
    # tmux refuses new-session while TMUX is set, and nesting is almost never
    # intended (e.g. SSH'd somewhere from inside a local tmux). Hint the escape.
    if [ -n "$TMUX" ]; then
      echo "in a tmux client and '$name' doesn't exist -- run: env -u TMUX tmux new-session -s '$name'"
      return 1
    fi
    tmux new-session -s "$name"
  fi
}

_tmux_session_rows() { # Formatted session rows for fzf menus
  tmux list-sessions -F '#{session_name} · #{session_windows}w#{?session_attached, · attached,} · #{t:session_last_attached}' 2>/dev/null
}

_tmux_pick_session() { # fzf-pick a session name; $1 = header. Prints name or nothing.
  local target
  target=$(_tmux_session_rows | fzf --reverse --header "$1" \
    --preview 'tmux list-windows -t {1} -F "  #{window_index}: #{window_name} #{window_flags}"' \
    --preview-window=right:40% | awk '{print $1}') || return 1
  [ -n "$target" ] && printf '%s' "$target"
}

_tmux_kill() { # m.tmux kill [name]
  local target="$1"
  if [ -z "$target" ]; then
    target=$(_tmux_pick_session 'kill session (enter) · esc to cancel') || return
  fi
  [ -n "$target" ] && tmux kill-session -t "$target"
}

_tmux_rename() { # m.tmux rename <new> [old]
  if [ -n "$2" ]; then
    tmux rename-session -t "$2" "$1"
    return
  fi
  if [ -n "$1" ]; then
    tmux rename-session "$1"
    return
  fi
  # No args: pick a session, then prompt for the new name.
  local target newname
  target=$(_tmux_pick_session 'rename which session? (enter) · esc to cancel') || return
  [ -z "$target" ] && return
  printf 'new name for %s: ' "$target"
  read -r newname
  [ -n "$newname" ] && tmux rename-session -t "$target" "$newname"
}

_tmux_menu() { # Bare m.tmux: fzf menu of sessions + actions
  local dirname
  dirname=$(basename "$PWD")

  local sel
  sel=$(
    {
      echo "＋ new session ($dirname)"
      _tmux_session_rows
      echo "✂ kill session →"
      echo "✎ rename session →"
      if [ -n "$TMUX" ]; then
        echo "⇤ detach client"
      fi
      echo "≡ list sessions"
    } | fzf --reverse --header 'session or action (enter) · esc to cancel' \
      --preview 'case {1} in ＋|✂|✎|⇤|≡) ;; *) tmux list-windows -t {1} -F "  #{window_index}: #{window_name} #{window_flags}" ;; esac' \
      --preview-window=right:40%
  ) || return
  [ -z "$sel" ] && return

  local first
  first=$(printf '%s' "$sel" | awk '{print $1}')
  case "$first" in
  ＋) _tmux_attach_or_create "$dirname" ;;
  ✂) _tmux_kill ;;
  ✎) _tmux_rename ;;
  ⇤) tmux detach-client ;;
  ≡) tmux list-sessions ;;
  *) _tmux_attach_or_create "$first" ;;
  esac
}

m.tmux() { # tmux session manager: m.tmux [name | ls | kill | rename | detach]
  case "$1" in
  ls) tmux list-sessions ;;
  kill)
    shift
    _tmux_kill "$@"
    ;;
  rename)
    shift
    _tmux_rename "$@"
    ;;
  detach)
    if [ -n "$TMUX" ]; then
      tmux detach-client
    else
      echo "not in tmux"
    fi
    ;;
  "") _tmux_menu ;;
  *) _tmux_attach_or_create "$1" ;;
  esac
}
