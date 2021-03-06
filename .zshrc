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
[[ -n "$STY" || "$TERM" == ((x|a|ml|dt|E)term*|(u|)rxvt*|screen*|putty*) ]] || shellopts[titlebar]=0

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
export HISTFILE=$ZDOTDIR/history/history  # File to which history will be saved
export HOST=${HOST:-$HOSTNAME}            # Ensure that $HOST contains hostname

# Save one history file per day
( date=$(print -P "%D{%Y-%m-%d}"); [[ -a $HISTFILE.$date ]] || cp $HISTFILE{,.$date} )

### Dotfile (Re)Compilation
# Allows dot files to be compiled into a pre-parsed form for use by zsh, which
# lets them be sourced much faster - A good idea for any zsh file that's not
# updated excessively often.
if autoloadable zrecompile ; then
  autoload -U zrecompile
  zrecompile -pq $ZDOTDIR/.zshrc
  zrecompile -pq $ZDOTDIR/.zprofile
  zrecompile -pq $ZDOTDIR/.zcompdump
  # We attempt to compile every file in zfunctions whose name does not
  # contain a dot and does not end in a tilde.
  zrecompile -pq $ZDOTDIR/zfunctions.zwc $ZDOTDIR/zfunctions/^(*~|*.*);
fi

### Key bindings
bindkey -e                                       # Use emacs keybindings
#bindkey -v                                     # Use vi keybindings

if zmodload -i zsh/terminfo; then
  # Make sure that the terminal is in application mode when zle is active,
  # since only then will <Home> emit khome, etc
  if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
    function zle-line-init()   echoti smkx
    function zle-line-finish() echoti rmkx
    zle -N zle-line-init
    zle -N zle-line-finish
  fi
else
  typeset -A terminfo
fi

function bind_terminfo_key() bindkey ${terminfo[$1]:-$2} $3

bind_terminfo_key khome "\e[1~" beginning-of-line     # Home
bind_terminfo_key kend  "\e[4~" end-of-line           # End
bind_terminfo_key kdch1 "\e[3~" delete-char           # Delete
bind_terminfo_key kcbt  "\e[Z"  reverse-menu-complete # Shift-Tab

autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bind_terminfo_key kcuu1 "\e[A" up-line-or-beginning-search
bind_terminfo_key kcud1 "\e[B" down-line-or-beginning-search

bindkey "\e"      vi-cmd-mode

bindkey "\e[1;5A" up-line-or-search              # Ctrl - Up in xterm
bindkey "\e[1;5B" down-line-or-search            # Ctrl - Down in xterm
bindkey "\e[1;5C" forward-word                   # Ctrl - Right in xterm
bindkey "\e[1;5D" backward-word                  # Ctrl - Left in xterm
bindkey " "       magic-space                    # Space expands history subst's
bindkey "^@"      _history-complete-older        # C-Space to complete from hist
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
  #function PickScheme() {
  #  local xprop="$(xprop WM_CLASS -id $WINDOWID 2>/dev/null)"
  #  (( $? == 0 )) && [[ -n "$xprop" ]] || return
  #  if [[ "$xprop" == (WM_CLASS\(STRING\) = \"fxterm\", \"*\") ]]; then
  #    colorscheme light
  #  else
  #    colorscheme dark
  #  fi
  #}
  #PickScheme
  colorscheme light
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
zstyle ':completion:*:*:(vi|vim):*:*' file-patterns \
    '*~(*.o|*~|*.old|*.bak|*.pro|*.zwc|*.swp|*.pyc):regular-files' \
    '(*~|*.bak|*.old):backup-files' \
    '(*.o|*.pro|*.zwc|*.swp|*.pyc):hidden-files'

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

if autoloadable vcs_info; then
    autoload -Uz vcs_info
fi

setopt prompt_subst

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' actionformats '%F{magenta}|%b%F{yellow}(%a)%F{magenta}|%f '
zstyle ':vcs_info:*' formats '%F{magenta}|%b|%f '

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

  type vcs_info &>/dev/null && vcs_info

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
PROMPT_COLOR='%F{'$((PROMPT_COLOR_NUM%6+1))'}'
(( PROMPT_COLOR_NUM > 6 )) && PROMPT_COLOR="%B$PROMPT_COLOR"
unset PROMPT_COLOR_NUM

function prompt-setup {
  if booleancheck "$shellopts[titlebar]" ; then
    # Can set titlebar, so sparse prompt: 'blue(shortpath)'
    # <blue bright=1><truncate side=right len=20 string="..">
    #   pwd (home=~, only print trailing component)</truncate>&gt;</blue>
    PS1=$'$PROMPT_COLOR%20>..>%1~%>>>%f%b'
  else
    # No titlebar, so verbose prompt: 'white(Hostname)default(::)blue(fullpath)'
    # Explained in pseudo-html:
    # <white bright=1>non-FQDN hostname</white>::<blue bright=1>
    #  <truncate side=left len=33 string="..">pwd (home=~)</truncate>&gt;</blue>
    PS1=$'%{\e[1;37m%}%m%{\e[0m%}::$PROMPT_COLOR%35<..<%~%<<>%f%b'
  fi
}

function rprompt-setup {
  # Right side prompt: '[(red)ERRORS]{(yellow)jobs}(blue)time'
  # in perl pseudocode this time, since html doesn't have a ternary operator...
  # "<red>$psvar[3]</red> "
  #   . ( $psvar[4] ? "<yellow>{" . $psvar[4] ."} </yellow> : '' )
  #     . "<blue bright=1>" . strftime("%L:%M:%S") . "<blue>"
  if booleancheck "$shellopts[rprompt]" ; then
    RPS1=$'%F{1}%3v%f %(4v.%F{3}{%4v}%f .)${vcs_info_msg_0_}$PROMPT_COLOR<%D{%L:%M:%S}%f%b'
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

function ssh-add {
  if (( $# )); then
    command ssh-add "$@"
  else
    command ssh-add ~/.ssh/*.pub(e:'reply=(${REPLY%.pub})':)
  fi
}

# Functions to wrap commands that would like a working keychain
function ssh scp svn git {
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
  set -- ~/.ssh/*.pub(N)
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

autoload -U zmv
alias mmv='noglob zmv -W'

compdef t=todo.sh
zstyle ':completion:*:descriptions' format $'\e[35mFrom %d\e[m'
zstyle ':completion:*' group-name ''

## vim:fdm=expr:fdl=0
## vim:fde=getline(v\:lnum)=~'^##'?'>'.(matchend(getline(v\:lnum),'##*')-2)\:'='
