setup_path()
{
  # Prune out any directories in $PATH that don't exist
  local i

  for ((i = $#path; i >= 1; --i)) {
    [ -d "$path[i]" ] || path[i]=()
  }

  # Add some directories that belong even if they don't exist yet
  path=(~/$(uname -s)/bin ~/bin /opt/bb/bin /opt/bin $path)

  # Remove any duplicates
  typeset -Ug path
}

setup_path
# And fix up manpath
export MANPATH="$MANPATH:"${PATH//bin/man}:${PATH//bin/share/man}

[ -d /opt/bb/share/terminfo/ ] && export TERMINFO=/opt/bb/share/terminfo
umask 022
