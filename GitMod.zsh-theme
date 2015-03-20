#!/bin/sh
# Written by Stephen Bush, Workiva (HyperText)
# Some elements borrowed and modified from existing Mods:
#   -- Soliah
#   -- fishy


# ========== Set up the Theme config: ==========
  # This option allows the theme to hook into the 'cd', 'pip' and 'bower' commands, enabling the 
  # dependencies to update.  You can set the option to false to disable the command hooks, however 
  # this will also automatically disable the dependency function.
MOD_OPTION_OVERRIDE_ALIASES=true
  # This option should contain the path to Stephen Bush's 'configWriter.sh', which is a tool used
  # for creating and using custom config files.  This is required by the mod to improve performance, 
  # enabling concurrency of operations and memoization of results.
MOD_OPTION_SOURCE_OF_CONFIGWRITER=$(scriptPath $0)"/configWriter.sh"


PROMPT='%{$fg[cyan]%}$(addSpace)Working in %{$reset_color%}%{$fg_bold[white]%}$(_getPwd)%b%{$reset_color%}$(getDeps)
$ '
RPROMPT='$(git_time_since_commit)$(check_git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[white]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"

# Text to display if the branch is dirty
ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[green]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[yellow]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[yellow]%}?%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[cyan]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_UNMERGED="(Merging)"
ZSH_THEME_GIT_PROMPT_STASHED="(S)"
ZSH_THEME_GIT_PROMPT_AHEAD="%{$fg[green]%}+\$(git_commits_ahead)%{$reset_color%}" 
ZSH_THEME_GIT_PROMPT_BEHIND="%{$fg[red]%}-%{$reset_color%}" 
ZSH_THEME_GIT_PROMPT_DIVERGED="%{$fg[green]%}+%{$reset_color%}%{$fg[red]%}-%{$reset_color%}" 
unset ZSH_THEME_GIT_PROMPT_DIRTY
unset ZSH_THEME_GIT_PROMPT_CLEAN

# Colors vary depending on time lapsed.
ZSH_THEME_GIT_TIME_SINCE_COMMIT_SHORT="%{$fg[green]%}"
ZSH_THEME_GIT_TIME_SHORT_COMMIT_MEDIUM="%{$fg[yellow]%}"
ZSH_THEME_GIT_TIME_SINCE_COMMIT_LONG="%{$fg[red]%}"
ZSH_THEME_GIT_TIME_SINCE_COMMIT_NEUTRAL="%{$fg[cyan]%}"


# Git sometimes goes into a detached head state. git_prompt_info doesn't
# return anything in this case. So wrap it in another function and check
# for an empty string.
function check_git_prompt_info() {
    if git rev-parse --git-dir > /dev/null 2>&1; then

        {
          # Check for new commits
          ( git fetch & )
        } &> /dev/null

        if [[ -z $(git_prompt_info) ]]; then
            echo "%{$fg[magenta]%}detached-head%{$reset_color%})"
        else
            local ret=""
            ret+="$(git_prompt_info)$(git_prompt_status))"
            eval echo \"$ret\"
        fi
    fi
}

# Determine if we are using a gemset.
function rvm_gemset() {
    if hash rvm 2>/dev/null; then
        GEMSET=`rvm gemset list | grep '=>' | cut -b4-`
        if [[ -n $GEMSET ]]; then
            echo "%{$fg[yellow]%}$GEMSET%{$reset_color%}|"
        fi 
    fi
}

# Determine the time since last commit. If branch is clean,
# use a neutral color, otherwise colors will vary according to time.
function git_time_since_commit() {
    load_config
    if [[ $repoHasCommit != $(getBaseDir $(git rev-parse --show-toplevel > /dev/null 2>&1)) ]]; then
        if git rev-parse --git-dir > /dev/null 2>&1; then
            if [[ $(git log 2>&1 > /dev/null | grep -c "^fatal: bad default revision") == 0 ]]; then
                set_config repoHasCommit $(getBaseDir $(git rev-parse --show-toplevel))
                repoHasCommit=""
            else
                # No commits
                COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_NEUTRAL"
                echo "($(rvm_gemset)$COLOR~|"
            fi
        else
            # Not a git repo
            return        
        fi
    fi

    # Get the last commit.
    last_commit=`git log --pretty=format:'%at' -1 2> /dev/null`
    now=`date +%s`
    seconds_since_last_commit=$((now-last_commit))

    # Totals
    MINUTES=$((seconds_since_last_commit / 60))
    HOURS=$((seconds_since_last_commit/3600))

    # Sub-hours and sub-minutes
    DAYS=$((seconds_since_last_commit / 86400))
    SUB_HOURS=$((HOURS % 24))
    SUB_MINUTES=$((MINUTES % 60))

    if [[ -n $(git status -s 2> /dev/null) ]]; then
        if [ "$MINUTES" -gt 30 ]; then
            COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_LONG"
        elif [ "$MINUTES" -gt 10 ]; then
            COLOR="$ZSH_THEME_GIT_TIME_SHORT_COMMIT_MEDIUM"
        else
            COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_SHORT"
        fi
    else
        COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_NEUTRAL"
    fi

    if [ "$HOURS" -gt 24 ]; then
        echo "($(rvm_gemset)$COLOR${DAYS}d${SUB_HOURS}h%{$reset_color%}|"
    elif [ "$MINUTES" -gt 60 ]; then
        echo "($(rvm_gemset)$COLOR${HOURS}h%{$reset_color%}|"
    else
        echo "($(rvm_gemset)$COLOR${MINUTES}m%{$reset_color%}|"
    fi
}

addSpace() {
    if [[ $VIRTUAL_ENV != "" ]]; then
      echo " "
    fi
}

# ========== Generate the PWD ==========
_getPwd () {
    if [[ $fishyPWD == "Update" ]]; then
        fishyPWD=$(_fishy_collapsed_wd)
    fi
    echo $fishyPWD
}
_fishy_collapsed_wd() {
  # TODO Remove/workaround perl dep
  which -s perl > /dev/null 2>&1
  if [[ $? -gt 0 ]]; then
    echo "%~"
  else
    echo $(pwd | perl -pe "
     BEGIN {
        binmode STDIN,  ':encoding(UTF-8)';
        binmode STDOUT, ':encoding(UTF-8)';
     }; s|^$HOME|~|g; s|/([^/])[^/]*(?=/)|/\$1|g
    ")
  fi
} 

# ========== Generate the Git Repo local dependencies ==========
getDeps () {
    while [[ true == true ]]; do
      ifBuildingDependencyList || break
      sleep 0.05
    done
    load_config
    if [[ $localD != "" ]]; then
        echo "%{$fg[cyan]%} with %{$reset_color%}"$localD
    fi
}

function ifBuildingDependencyList () {
  load_config 
  if [[ $localD == "Generating..." ]]; then
    return 0
  else
    return 1
  fi
}

buildDependencyList () {
    local RetStr=""
    set_config localD "Generating..."
    RetStr+=$(testBower)
    temp=$(testPip)
    if [[ $RetStr != "" && $temp != "" ]]; then
        RetStr+=", "
    fi
    RetStr+=$temp
    localD=$RetStr
    set_config localD $RetStr
}

testBower () {
  local RetStr=""
  \bower list | grep "linked" | while read -r line ; do
    local bLink=$(echo $line | sed -e "s/\#.*//g" | sed -e "s/.*\ //g")
    if [[ $RetStr =~ $bLink ]]; then
      continue
    fi
    if [[ $RetStr != "" ]]; then
      RetStr+=", "
    fi
    RetStr+="%{$fg[magenta]%}$bLink%{$reset_color%}"
    if [[ $line =~ 'incompatible' ]]; then
      RetStr+="%{$fg[yellow]%}✗%{$reset_color%}"
    fi
  done
  echo "$RetStr"
}

testPip () {
  local RetStr=""
  \pip freeze | grep "^-e" | while read -r line ; do
    local bLink=$(echo $line | sed -e "s/\.git.*//g" | sed -e "s/.*\///g")
    if [[ $(getBaseDir) == $bLink ]]; then
      continue
    fi
    if [[ $RetStr != "" ]]; then
      RetStr+=", "
    fi
    RetStr+="%{$fg[green]%}$bLink%{$reset_color%}"
  done
  echo "$RetStr"  
}



# ========== Set up the update handlers ==========
function theme_updateDeps () {
  # Only rebuild if not already rebuilding
  # ifBuildingDependencyList || ( buildDependencyList & )
  # Rebuild every time -- Reccomended, because a script with multiple pip/bower
  # commands could kick off a dependency update before the list is finalized, and
  # cause the list to be off indefinitely.
  ifBuildingDependencyList || ( buildDependencyList & )

}
function theme_updatePWD () {
  fishyPWD="Update"
}



# ========== Set up the Config Writer ==========
if [[ $MOD_OPTION_SOURCE_OF_CONFIGWRITER != false ]]; then
    CONFIG_FILE=$(scriptPath $0)"/.GitModTheme-""${TTY##*/}"".cfg"
    source $MOD_OPTION_SOURCE_OF_CONFIGWRITER
    reset_config
    add_config repoHasCommit "false"
    add_config localD
    theme_updateDeps
else
    localD=""
fi
fishyPWD="Update"



# ========== Set up the Alias Hooks ==========
if [[ $MOD_OPTION_OVERRIDE_ALIASES == true ]]; then
    which -s prependAlias &> /dev/null
    if [[ $? == 0 ]]; then
        appendAlias pip "theme_updateDeps"
        appendAlias bower "theme_updateDeps"
        appendAlias cd "theme_updateDeps; theme_updatePWD"
    else
        alias pip="theme_updateDeps; \pip"
        alias bower "theme_updateDeps; \bower"
        alias cd "theme_updateDeps; theme_updatePWD; \cd"
    fi
else
    localD=""
fi