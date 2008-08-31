# Author:  Matt Wozniski (mjw@drexel.edu)
#
# Feel free to do whatever you would like with this file as long as you give
# credit where credit is due.
#
# If nothing else, you should at least look at the Behavior Overrides section
# to see if there's anything that you want to disable.  (Most people probably
# won't like that it changes their terminals' colors, but, who cares, I like
# it, and they can disable it. :-D )
#
# NOTE:
# This .zshrc does define LANG and LC_CTYPE.  If you don't want en_US.UTF-8 and
# C, search for those variable names and change them in the section "Environment
# Variables".
#
# NOTE:
# If you're editing this in Vim and don't know how folding works, type zR to
# unfold them all.

### SETUP
# These settings are only for interactive shells. Return if not interactive.
# This stops us from ever accidentally executing, rather than sourcing, .zshrc
[[ -o nointeractive ]] && return

# Disable flow control, since it really just annoys me.
stty -ixon &>/dev/null

#### Optional Behaviors
# Setting any of these options will modify the behavior of a new shell to
# better suit your needs.  These values given specify the default for each
# option when the shell starts.  At the moment, changing shellopts[utf8] during
# an execution does nothing whatsoever, as it only sets up some aliases and
# variables when the shell starts.  However, all of the other options can be
# changed while the shell is running to change its behavior from that point
# forward.
typeset -A shellopts
shellopts[utf8]=1         # Set up a few programs for UTF-8 mode
shellopts[titlebar]=1     # Whether the titlebar can be dynamically changed
shellopts[screen_names]=1 # Dynamically change window names in GNU screen
shellopts[preexec]=1      # Run preexec to update screen title and titlebar
shellopts[precmd]=1       # Run precmd to show job count and retval in RPROMPT
shellopts[rprompt]=1      # Show the right-side time, retval, job count prompt.

#### Helper Functions
# Checks if a file can be autoloaded by trying to load it in a subshell.
# If we find it, return 0, else 1
function autoloadable {
  ( unfunction $1 ; autoload -U +X $1 ) &>/dev/null
}

# Returns whether its argument should be considered "true"
# Succeeds with "1", "y", "yes", "t", and "true", case insensitive
function booleancheck {
  [[ -n "$1" && "$1" == (1|[Yy]([Ee][Ss]|)|[Tt]([Rr][Uu][Ee]|)) ]]
}

# Performs the same job as pidof, using only zsh capabilities
function pids {
  local i
  for i in /proc/<->/stat
  do
    [[ "$(< $i)" = *\((${(j:|:)~@})\)* ]] && echo $i:h:t
  done
}

# Replaces the current window title in Gnu Screen with its positional parameters
function set-screen-title {
  echo -n "\ek$*\e\\"
}

# Replaces the current terminal titlebar with its positional parameters.
function set-window-title {
  echo -n "\e]2;"${${(pj: :)*}[1,254]}"\a"
}

# Replaces the current terminal icon text with its positional parameters.
function set-icon-title {
  echo -n "\e]1;"${${(pj: :)*}[1,254]}"\a"
}

# Given a command as a single word and an optional directory, this generates
# a titlebar string like "hostname> dir || cmd" and assigns that to an element
# in PSVAR for use by the prompt, and to the exported variable TITLE for use by
# other applications.  If the directory is omitted, it will default to the
# current working directory.  It then takes the first word of that command
# (splitting on whitespace), excluding variable assignments, the word sudo, and
# command flags, and assigns that to an element in PSVAR for use as a screen
# name and icon title, as well as to the exported variable ICON.  Finally, it
# actually writes those strings as the screen name and title bar text.
function set-title-by-cmd {
  # Rather than setting the screen name and titlebar to "fg..." when fg is
  # executed, we determine what the user is trying to foreground and change the
  # screen name and titlebar to that, before actually calling fg.  So, we take
  # our current job texts and directories and use them, in a subshell from a
  # process substitution, to set the title properly.
  if [[ "${1[(w)1]}" == (fg|%*)(\;|) ]]; then
    # The first word of the command either was 'fg' or began with '%'
    if [[ "${1[(wi)%*(\;|)]}" -eq 0 ]]; then
      local arg="%+"              # No arg began with %, default to %+
    else
      local arg=${1[(wr)%*(\;|)]} # Found a % arg, use it
    fi

    # Make local copies of our jobtexts and jobdirs vars, for use in a subshell
    local -A jt jd
    jt=(${(kv)jobtexts}) jd=(${(kv)jobdirs})

    # Run the jobs command with the chosen % arg.  If it can't find a matching
    # job, we discard the error message and continue setting the title as
    # though we hadn't found a command that should change the foreground app.
    # If it finds a matching job, we redirect the output into a process
    # substitution that handles getting the job number and calling
    # set-title-by-cmd-impl with the job description and job CWD.  We use a
    # process substitution so that the text processing can be done in a
    # subshell, leaving the 'jobs' command run in the current shell.  This
    # should work fine with older versions of zsh.
    jobs $arg 2>/dev/null > >( read num rest
                               set-title-by-cmd-impl \
                                 "${(e):-\$jt$num}" "${(e):-\$jd$num}"
                             ) || set-title-by-cmd-impl "$1" "$2"
  else
    # Not foregrounding an app, just continue with setting title
    set-title-by-cmd-impl "$1" "$2"
  fi
}

# This function actually does the work for set-title-by-command, described
# above.
function set-title-by-cmd-impl {
  set "$1" "${2:-$PWD}"                      # Replace $2 with $PWD if blank
  psvar[1]=${(V)$(cd "$2"; print -Pn "%m> %~ || "; print "$1")} # The new title
  if [ ${1[(wi)^(*=*|sudo|-*)]} -ne 0 ]; then
    psvar[2]=${1[(wr)^(*=*|sudo|-*)]}        # The one-word command to execute
  else
    psvar[2]=$1                              # The whole line if only one word
  fi                                         # or a variable assignment, etc

  if booleancheck "$shellopts[screen_names]" ; then
    set-screen-title "$psvar[2]"           # set the command as the screen title
  fi
  if booleancheck "$shellopts[titlebar]" ; then
    set-icon-title   "$psvar[2]"
    set-window-title "$psvar[1]"
  fi
  export TITLE=$psvar[1]
  export ICON=$psvar[2]
}

#### Capability checks

# Xterm, URxvt, Rxvt, aterm, mlterm, Eterm, and dtterm can set the titlebar
# TODO So can quite a few other terminal emulators...  If I'm missing a
# terminal emulator that you know can set the titlebar, please let me know.
[[ -n "$STY" || "$TERM" == ((x|a|ml|dt|E)term*|(u|)rxvt*|screen*) ]] || shellopts[titlebar]=0

# TODO Should probably check terminal emulator really is using unicode...
# [[ TEST IF UNICODE WORKS ]] || shellopts[utf8]=0

# Dynamically change a screen name to the last command used when in Gnu Screen
[[ "$TERM" == (screen*) ]] || shellopts[screen_names]=0

### Colon-separated Arrays
# Tie colon separated arrays to zsh-arrays, like (MAN)PATH and (man)path
typeset -T INFOPATH           infopath
typeset -T LD_LIBRARY_PATH    ld_library_path
typeset -T LD_LIBRARY_PATH_32 ld_library_path_32
typeset -T LD_LIBRARY_PATH_64 ld_library_path_64
typeset -T CLASSPATH          classpath
typeset -T LS_COLORS          ls_colors

### Aliases
# First off, allow commands after sudo to still be alias expanded.
# An alias ending in a space allows the next word on the command line to
# be alias expanded as well.
alias sudo="sudo "
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -l'
alias ls='ls --color=auto -B'
alias grep='grep --color=auto'
alias pu='pushd'
alias po='popd'
alias ..='cd ..'
alias cd..='cd ..'
alias cd/='cd /'
alias vi='vim'

alias -g L='|less'
alias -g T='|tail'
alias -g H='|head'
alias -g V='|vim -'
alias -g B='&>/dev/null &'
alias -g D='&>/dev/null &|'

booleancheck "$shellopts[utf8]" && alias screen="screen -U"

### Options
#### Shell Options
# I don't want to be told if the zsh version I'm using is missing some of these.
# I'll figure it out on my own.  So, redirect error messages to /dev/null
     # Allow comments in an interactive shell.
setopt InteractiveComments 2>/dev/null
     # Don't interrupt me to let me know about a finished bg task
setopt NoNotify            2>/dev/null
     # Run backgrounded processes at full speed
setopt NoBgNice            2>/dev/null
     # Turn off terminal beeping
setopt NoBeep              2>/dev/null
     # Automatically list ambiguous completions
setopt AutoList            2>/dev/null
     # Don't require an extra tab before listing ambiguous completions
setopt NoBashAutoList      2>/dev/null
     # Don't require an extra tab when there is an unambiguous pre- or suffix
setopt NoListAmbiguous     2>/dev/null
     # Tab on ambiguous completions cycles through possibilities
setopt AutoMenu            2>/dev/null
     # Allow extended globbing syntax needed by preexec()
setopt ExtendedGlob        2>/dev/null
     # Before storing an item to the history, delete any dups
setopt HistIgnoreAllDups   2>/dev/null
     # Append each line to the history immediately after it is entered
setopt ShareHistory        2>/dev/null
     # Complete Mafile to Makefile if cursor is on the f
setopt CompleteInWord      2>/dev/null
     # Allow completion list columns to be different sizes
setopt ListPacked          2>/dev/null
     # cd adds directories to the stack like pushd
setopt AutoPushd           2>/dev/null
     # the same folder will never get pushed twice
setopt PushdIgnoreDups     2>/dev/null
     # - and + are reversed after cd
setopt PushdMinus          2>/dev/null
     # pushd will not print the directory stack after each invocation
setopt PushdSilent         2>/dev/null
     # pushd with no parameters acts like 'pushd $HOME'
setopt PushdToHome         2>/dev/null
     # if alias foo=bar, complete as if foo were entered, rather than bar
setopt CompleteAliases     2>/dev/null
     # Allow short forms of function contructs
setopt ShortLoops          2>/dev/null
     # Automatically continue disowned jobs
setopt AutoContinue        2>/dev/null
     # Attempt to spell-check command names - I mistype a lot.
setopt Correct             2>/dev/null

#### Environment variables
export SHELL=$(whence -p zsh)             # Let apps know the full path to zsh
export DIRSTACKSIZE=10                    # Max number of dirs on the dir stack

if booleancheck "$shellopts[utf8]" ; then
  export LANG=en_US.UTF-8                 # Use a unicode english locale
  #export LC_CTYPE=C                      # but fix stupid not-unicode man pages
fi

export HISTSIZE=5500                      # Lines of history to save in mem
export SAVEHIST=5000                      # Lines of history to write out
export HISTFILE="$ZDOTDIR/.zsh_history"   # File to which history will be saved
export HOST=${HOST:-$HOSTNAME}            # Ensure that $HOST contains hostname

### Dotfile (Re)Compilation
# Allows dot files to be compiled into a pre-parsed form for use by zsh, which
# lets them be sourced much faster - A good idea for any zsh file that's not
# updated excessively often.
if autoloadable zrecompile ; then
  autoload -U zrecompile
  zrecompile -pq $ZDOTDIR/.zshrc
  zrecompile -pq $ZDOTDIR/.zprofile
  zrecompile -pq $ZDOTDIR/.zcompdump
  # We attempt to compile every file in .zfunctions whose name does not
  # contain a dot and does not end in a tilde.
  zrecompile -pq $ZDOTDIR/.zfunctions.zwc $ZDOTDIR/.zfunctions/^(*~|*.*);
fi

### Key bindings
bindkey -e                                       # Use emacs keybindings
#bindkey -v                                     # Use vi keybindings

if zmodload -i zsh/terminfo; then
  [ -n "${terminfo[khome]}" ] &&
  bindkey "${terminfo[khome]}" beginning-of-line # Home
  [ -n "${terminfo[kend]}" ] &&
  bindkey "${terminfo[kend]}"  end-of-line       # End
  [ -n "${terminfo[kdch1]}" ] &&
  bindkey "${terminfo[kdch1]}" delete-char       # Delete
fi

bindkey "\e[1~"   beginning-of-line              # Another Home
bindkey "\e[4~"   end-of-line                    # Another End
bindkey "\e[3~"   delete-char                    # Another Delete
bindkey "\e[1;5A" up-line-or-search              # Ctrl - Up in xterm
bindkey "\e[1;5B" down-line-or-search            # Ctrl - Down in xterm
bindkey "\e[1;5C" forward-word                   # Ctrl - Right in xterm
bindkey "\e[1;5D" backward-word                  # Ctrl - Left in xterm
bindkey "\eOa"    up-line-or-search              # Another ctrl-up
bindkey "\eOb"    down-line-or-search            # Another ctrl-down
bindkey "\eOc"    forward-word                   # Another possible ctrl-right
bindkey "\eOd"    backward-word                  # Another possible ctrl-left
bindkey "\e[Z"    reverse-menu-complete          # S-Tab menu completes backward
bindkey " "       magic-space                    # Space expands history subst's
bindkey "^@"      _history-complete-older        # C-Space to complete from hist

bindkey "\et"       vi-find-next-char            # A-t char to find next char
bindkey $'\xC3\xB4' vi-find-next-char            # Same, for my multibyte setup
bindkey "\eT"       vi-find-prev-char            # A-T char to find prev char
bindkey $'\xC3\x94' vi-find-prev-char            # Same, for my multibyte setup
bindkey "\eq"       push-line-or-edit            # Combine lines or push
bindkey $'\xC3\xB1' push-line-or-edit            # Same, for my multibyte setup

# Up and down search only for   lines whose beginnings match the current line
# up to the cursor.  If  possible, the cursor will move to the end of the line
# after each history search, but will return to its original position before
# actually searching.
if autoloadable history-search-end; then
  autoload -U history-search-end
  zle -N history-beginning-search-backward-end history-search-end
  zle -N history-beginning-search-forward-end history-search-end
  bindkey "^[[A" history-beginning-search-backward-end
  bindkey "^[[B" history-beginning-search-forward-end
else
  bindkey "^[[A" history-beginning-search-backward
  bindkey "^[[B" history-beginning-search-forward
fi

bindkey "^I"      complete-word                  # Tab completes, never expands
                                                 # so expansion can be handled
                                                 # by a completer.

#### Function to hide prompts on the line - Will be replaced eventually
function TogglePrompt {
  if [[ -n "$PS1" && -n "$RPS1" ]]; then
    OLDRPS1=$RPS1; OLDPS1=$PS1
    unset RPS1 PS1
  else
    RPS1=$OLDRPS1; PS1=$OLDPS1
  fi
  zle reset-prompt
}
zle -N TogglePrompt

bindkey "^X^X" TogglePrompt

#### Function to allow Ctrl-z to toggle between suspend and resume
function Resume {
  zle push-input
  BUFFER="fg"
  zle accept-line
}
zle -N Resume

bindkey "^Z" Resume

#### Allow interactive editing of command line in $EDITOR
if autoloadable edit-command-line; then
  autoload -U edit-command-line
  zle -N edit-command-line
  bindkey "\ee" edit-command-line
fi

### Misc
#### Some minicom options:
# linewrap use-status-line capture-file=/dev/null color=off
export MINICOM='-w -z  -C /dev/null -c off'

#### Man and Info options
# Make vim the manpage viewer or info viewer
# Requires manpageview.vim from
# http://vim.sourceforge.net/scripts/script.php?script_id=489
if [[ -f $HOME/.vim/plugin/manpageview.vim ]]; then
  function man {
    [[ $# -eq 0 ]] && return 1
    vim -R -c "Man $*" -c "silent! only"
  }

  function info {
    [[ $# -eq 1 ]] || return 1
    vim -R -c "Man $1.i" -c "silent! only"
  }

  function perldoc {
    [[ $# -eq 1 ]] || return 1
    vim -R -c "Man $1.pl" -c "silent! only"
  }
fi

#### Less and ls options
# make less more friendly for non-text input files, see lesspipe(1)
# If we have it, we'll use it.
which lesspipe &>/dev/null && eval "$(lesspipe)"

# customize the colors used by ls, if we have the right tools
# Also changes colors for completion, if initialized first
which dircolors &>/dev/null && eval `dircolors -b $HOME/.dircolors`

#### Add colorscheme support
autoloadable colorscheme && autoload -U colorscheme

if [[ -z "$COLORSCHEME" ]]; then
  function PickScheme() {
    local xprop="$(xprop WM_CLASS -id $WINDOWID 2>/dev/null)"
    (( $? == 0 )) && [[ -n "$xprop" ]] || return
    if [[ "$xprop" == (WM_CLASS\(STRING\) = \"fxterm\", \"*\") ]]; then
      colorscheme light
    else
      colorscheme dark
    fi
  }
  PickScheme
fi


### Completion
if autoloadable compinit; then
autoload -U compinit; compinit # Set up the required completion functions

# Order in which completion mechanisms will be tried:
# 1. Try completing the results of an old list
#    ( for use with history completion on ctrl-space )
# 2. Try to complete using context-sensitive completion
# 3. Try interpretting the typed text as a pattern and matching it against the
#    possible completions in context
# 4. Try completing the word just up to the cursor, ignoring anything past it.
# 5. Try combining the effects of completion and correction.
zstyle ':completion:*' completer _oldlist _complete _match \
                                 _expand _prefix _approximate

# Don't complete backup files as executables
zstyle ':completion:*:complete:-command-::commands' ignored-patterns '*\~'

# If I don't have ``executable'', don't complete to the _executable completer
zstyle ':completion:*:functions' ignored-patterns '_*'

# Match lowercase letters to uppercase letters and dashes to underscores (not
# vice-versa), and allow ".t<TAB>" to list all files containing the text ".t"
zstyle ':completion:*' matcher-list 'm:{a-z-}={A-Z_}' 'r:|.=** r:|=*'

# Try to use verbose listings when we have more information
zstyle ':completion:*' verbose true

# Allows /u/l/b<TAB> to menu complete as though you typed /u*/l*/b*<TAB>
zstyle ':completion:*:paths' expand suffix

# Menu complete on ambiguous paths
zstyle ':completion:*:paths' list-suffixes true

# Have '/home//<TAB>' list '/home/*', rather than '/home/*/*'
zstyle ':completion:*:paths' squeeze-slashes false

# Enter "menu selection" if there are at least 2 choices while completing
zstyle ':completion:*' menu select=2

# vi or vim will match first files that don't end in a backup extension,
# followed by files that do, followed last by files that are known to be binary
# types that should probably not be edited.
zstyle ':completion:*:*:(vi|vim):*:*' \
    file-patterns '*~(*.o|*~|*.old|*.bak|*.pro|*.zwc|*.swp):regular-files' \
                  '(*~|*.bak|*.old):backup-files' \
                  '(*.o|*.pro|*.zwc|*.swp):hidden-files'

# Use colors in tab completion listings
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Add a space after an expansion, so that 'ls $TERM' expands to 'ls xterm '
zstyle ':completion:*:expand:*' add-space true

# Tweaks to kill: list processes using the given command and show them in a menu
zstyle ':completion:*:*:kill:*' command 'ps -u$USER -o pid,%cpu,tty,cputime,cmd'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:*:kill:*' force-list always

# Use caching for commands that would like a cache.
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ${ZDOTDIR}/.zcache

# Page long completion lists, using this prompt.
zstyle ':completion:*' list-prompt %S%L -- More --%s

# Show a warning when no completions were found
zstyle ':completion:*:warnings' format '%BNo matches for: %d%b'
fi

### Prompt
# The prompt will use the following elements in psvar:
# 1 - Xterm title string
# 2 - Screen title string
# 3 - Signal or Return value string
# 4 - Number of jobs ( for zsh versions without %j )

# In addition, precmd and preexec both modify a variable called shownexterr,
# which is manipulated to ensure that the failure status is only shown once
# per failed command.

typeset +x PS1     # Don't export PS1 - Other shells just mangle it.

#### Preexec is run after a command line is read, before the command is executed
# We use it to inform the prompt that error messages should once again be
# shown, and to set the screen name / titlebar text based on the command line,
# unless the user has disabled those features.
function preexec {
  booleancheck "$shellopts[preexec]" || return # Return if we're not wanted
  shownexterr=1
  #print -n "\e[K"    # Why did I do this?
  set-title-by-cmd $1
}

#### Precmd is run before displaying the new prompt
# We use it to find the exit status of the command for use in our prompt,
# attempt to interpret as a signal name if it seems to be in the correct range,
# and reset our titlebar text to what it was before running the command.
function precmd {
  local exitstatus=$?

  [[ -z "$RPS1" ]] &&   booleancheck "$shellopts[rprompt]" && rprompt-setup
  [[ -n "$RPS1" ]] && ! booleancheck "$shellopts[rprompt]" && rprompt-setup

  booleancheck "$shellopts[precmd]" || return # Return if we're not wanted

  psvar[4]=$#jobtexts
  [[ $psvar[4] -eq 0 || "$shownexterr" -le 0 ]] && psvar[4]=()

  local sigstart=127
  [[ "$OSTYPE" == (solaris*) ]] && sigstart=-1 # This makes it work a BIT better

  if [[ "$exitstatus" -gt 0 && "$shownexterr" -gt 0 ]]; then
    if [[ "$exitstatus" -gt "$sigstart" \
     && "$exitstatus" -le "($sigstart+${#signals})" ]]; then
      psvar[3]="[${signals[exitstatus-sigstart]}]"
    elif [[ "$exitstatus" -eq 127 ]]; then
      psvar[3]="[Not Found]"
    else
      psvar[3]="[${exitstatus}]"
    fi
  else
    psvar[3]=""
  fi
  shownexterr=0;

  if booleancheck "$shellopts[titlebar]" ; then
    psvar[1]=$(print -Pn $'%m> %~')    # set titlebar to Hostname> FullPath
    set-window-title "$psvar[1]"
  fi

  if ! ( setopt PromptSp ) &>/dev/null; then
    # Equivalent of PROMPT_SP for older versions of zsh
    echo -n ${(l:$((COLUMNS-1)):::):-} # Add $COLUMNS spaces to the line
  fi
  # Explanation: Pads, on the left, a field $COLUMNS wide, with spaces.
  # Append nothing to the left or right of these spaces, and tack them
  # on to nothing (:-)
}

#### Prompt setup functions
# Global color variable
PROMPT_COLOR_NUM=$(((${#${HOST#*.}}+11)%12))

function prompt-setup {
  local CC=$'\e['$((PROMPT_COLOR_NUM>6))$'m\e[3'$((PROMPT_COLOR_NUM%6+1))'m'
  if booleancheck "$shellopts[titlebar]" ; then
    # Can set titlebar, so sparse prompt: 'blue(shortpath)'
    # <blue bright=1><truncate side=right len=20 string="..">
    #   pwd (home=~, only print trailing component)</truncate>&gt;</blue>
    PS1=$'%{'"$CC"$'%}%20>..>%1~%>>>%{\e[0m%}'
  else
    # No titlebar, so verbose prompt: 'white(Hostname)default(::)blue(fullpath)'
    # Explained in pseudo-html:
    # <white bright=1>non-FQDN hostname</white>::<blue bright=1>
    #  <truncate side=left len=33 string="..">pwd (home=~)</truncate>&gt;</blue>
    PS1=$'%{\e[1;37m%}%m%{\e[0m%}::%{'"$CC"$'%}%35<..<%~%<<>%{\e[0m%}'
  fi
}

function rprompt-setup {
  local CC=$'\e['$((PROMPT_COLOR_NUM>6))$'m\e[3'$((PROMPT_COLOR_NUM%6+1))'m'
  # Right side prompt: '[(red)ERRORS]{(yellow)jobs}(blue)time'
  # in perl pseudocode this time, since html doesn't have a ternary operator...
  # "<red>$psvar[3]</red> "
  #   . ( $psvar[4] ? "<yellow>{" . $psvar[4] ."} </yellow> : '' )
  #     . "<blue bright=1>" . strftime("%L:%M:%S") . "<blue>"
  if booleancheck "$shellopts[rprompt]" ; then
    RPS1=$'%{\e[0;31m%}%3v%{\e[0m%} %(4v.%{\e[33m%}{%4v}%{\e[0m%} .)%{'"$CC"$'%}<%D{%L:%M:%S}%{\e[0m%}'
  else
    RPS1=""
  fi
}

prompt-setup
rprompt-setup

# Prompt for spelling corrections.
# %R is word to change, %r is suggestion, and Y and N are colored green and red.
SPROMPT=$'Should zsh correct "%R" to "%r" ? ([\e[0;32mY\e[0m]es/[\e[0;31mN\e[0m]o/[E]dit/[A]bort) '


### Set up our ssh keychain
# Checks if an ssh-agent seems to be working
function verify-agent-vars {
  # Definitely not SSH_AUTH_SOCK is empty
  [[ -z "$SSH_AUTH_SOCK" ]] && return 1

  # Nor if SSH_AGENT_PID (local agent) and SSH_CLIENT (forwarding) are unset
  [[ -z "$SSH_AGENT_PID" && -z "$SSH_CLIENT" ]] && return 1

  # Nor is it valid if the agent's process wasn't started by us
  [[ -n "$SSH_AGENT_PID" && ! -O /proc/"$SSH_AGENT_PID" ]] && return 1

  # Nor if the socket isn't a socket
  [[ ! -S "$SSH_AUTH_SOCK" ]] && return 1

  # Nor if the socket isn't owned by us
  [[ ! -O "$SSH_AUTH_SOCK" ]] && return 1

  ssh-add -l &>/dev/null

  [[ $? -ne 2 ]] # Return 0 unless ssh-add returned 2 (couldn't find agent)
}

# Caches the ssh agent variables to a file
function save-agent-vars {
  emulate -L zsh

  : >~/.keychain/"$HOST".sh
  for var in SSH_AGENT_PID SSH_AUTH_SOCK SSH_CLIENT SSH_CONNECTION SSH_TTY
    echo export $var=${(qq)${(e)var/#/$}} >>~/.keychain/"$HOST".sh
}

# Retrieves the ssh agent variables
function load-agent-vars {
  [ -r ~/.keychain/"$HOST".sh ] && . ~/.keychain/"$HOST".sh
}

# Functions to wrap commands that would like a working keychain
function ssh scp svn {
  setup-keychain; command "$0" "$@"
}

function setup-keychain {
  # keychain doesn't strike me as that complicated.  Let's try to fake it.
  # Give us a directory to store the info between logins
  [ -d ~/.keychain ] || { mkdir ~/.keychain; chmod 700 ~/.keychain }

  # Check existing variables, store and use them if valid
  if verify-agent-vars; then
    save-agent-vars
    return 0
  fi

  # Try cached variables
  load-agent-vars
  verify-agent-vars && return 0

  # Can't do much to help at this point if we can't start an agent...
  whence -p ssh-agent &>/dev/null || return 0

  # Or if we don't have any public keys...
  set -- ~/.ssh/id_[rd]sa(N)
  [ $# -eq 0 ] && return 0

  # Otherwise, we can try starting a new agent.
  eval $(ssh-agent)
  verify-agent-vars || return 1
  save-agent-vars
}

setup-keychain

### Uncategorized
# mplayer wrapper to work around xorg brightness change on issuing xset -dpms
function mplayer {
  [ -n $commands[brightness] ] && brightness=$(brightness get)
  xset -dpms
  [ -n $brightness ] && brightness set "$brightness"
  command mplayer "$@"
}

## vim:fdm=expr:fdl=0
## vim:fde=getline(v\:lnum)=~'^##'?'>'.(matchend(getline(v\:lnum),'##*')-2)\:'='
