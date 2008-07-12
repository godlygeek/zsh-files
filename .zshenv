export PAGER=less
export EDITOR=vim
fpath=(~/.zfunctions $fpath) # Add a custom directory for my completion functions.
typeset -U fpath

#### Setup
# If $ZDOTDIR is defined, we keep the definition, otherwise we define $ZDOTDIR
# to equal $HOME/.zsh.  This is so that any other .z* files can refer to files
# in the current $ZDOTDIR.
ZDOTDIR=${ZDOTDIR:-$HOME/.zsh}

# "Outer Terminal" and "Screen Session ID" are only defined while in Gnu Screen
# but both of these variables would be exported into the environment of a new
# terminal emulator launched from inside screen.  We unset them if the terminal
# is set to anything that doesn't begin with screen.
[[ "$TERM" != (screen*) ]] && unset INTERM && unset STY
