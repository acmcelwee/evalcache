# Caches the output of a binary initialization command, to avoid the time to
# execute it in the future.
#
# Usage: _evalcache [NAME=VALUE]... COMMAND [ARG]...

# default cache directory
export ZSH_EVALCACHE_DIR=${ZSH_EVALCACHE_DIR:-"$HOME/.zsh-evalcache"}
__log_file=/tmp/zsh-evalcache.log
touch ${__log_file}

# log function for evalcache messages
function __evalcache_log () {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "${__log_file}"
}

function _evalcache () {
  mkdir -p "$ZSH_EVALCACHE_DIR"
  local cmdHash="nohash" data="$*" name

  # use the first non-variable argument as the name
  for name in $@; do
    if [ "${name}" = "${name#[A-Za-z_][A-Za-z0-9_]*=}" ]; then
      break
    fi
  done

  # if command is a function, include its definition in data
  if typeset -f "${name}" > /dev/null; then
    data=${data}$(typeset -f "${name}")
  fi

  if builtin command -v md5 > /dev/null; then
    cmdHash=$(echo -n "${data}" | md5)
  elif builtin command -v md5sum > /dev/null; then
    cmdHash=$(echo -n "${data}" | md5sum | cut -d' ' -f1)
  fi

  local cacheFile="$ZSH_EVALCACHE_DIR/init-${name##*/}-${cmdHash}.sh"

  if [ -s "$cacheFile" ]; then
    # Calculate the time difference and cleanup if needed
    local now=$(date +%s)
    if [[ $(stat --version 2>&1 | grep GNU) ]]; then
      # use the coreutils stat args
      local file_modification=$(stat --format="%Y" "$cacheFile")
    else
      # use the BSD stat args
      local file_modification=$(stat -f "%m" "$cacheFile")
    fi

    (( diff = (now - file_modification) / ZSH_CLEANUP_SECONDS ))
    if [ $diff -gt 1 ]; then
      echo "evalcache: cache for $* expired, rebuilding it"
      rm -f "$cacheFile"
    fi
  fi

  if [ "$ZSH_EVALCACHE_DISABLE" = "true" ]; then
    eval ${(q)@}
  elif [ -s "$cacheFile" ]; then
    source "$cacheFile"
  else
    if type "${name}" > /dev/null; then
      __evalcache_log "${name} initialization not cached, caching output of: $*"
      eval ${(q)@} > "$cacheFile"
      source "$cacheFile"
    else
      echo "_evalcache[ERROR]: ${name} is not installed or in PATH" >&2
    fi
  fi
}

function _evalcache_clear () {
  rm -i "$ZSH_EVALCACHE_DIR"/init-*.sh
}
