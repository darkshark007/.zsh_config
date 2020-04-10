#!/bin/sh
# Written by Stephen Bush, Workiva (HyperText)

# ==============================================================================
# Utility functions

# Return the path where the calling script lives.  Requires argument '$0' and
#  only works during initial sourcing of the script, so if this path is needed 
#  later, then it should be grabbed and saved by the calling script.
function scriptPath () {
    local DIR="`dirname \"$1\"`" # relative
    local DIR2="`( builtin cd \"$DIR\" && pwd )`" # absolutized and normalized
    if [ -z "$DIR2" ] ; then
        echo $DIR
        return 0
    fi
    echo $DIR2
    return 0
}

# This helper function gets the base directory name from the PWD
function getBaseDir() {
  if [[ ${@:1} == "" ]]; then
    echo "${PWD##*/}"
  else
    echo "${${@:1}##*/}"
  fi
  return 0
}

function abs_path() { (cd "$1" &>/dev/null && echo "$(pwd -P)") }

# Show/Hide hidden files and folders in the Finder
alias finderShowHiddenFiles="defaults write com.apple.finder AppleShowAllFiles YES"
alias finderHideHiddenFiles="defaults write com.apple.finder AppleShowAllFiles NO"

# Host a local file server available over the wifi for sharing/moving files
alias serveFiles="
  ifconfig | grep netmask &&
  echo 'Running file server on port 5000' &&
  python -m SimpleHTTPServer 5000
"

# Pause the currently running program until the user pushes Enter.
function pause() {
    echo "***************************************************"
    echo "** $*"
    echo "** Press ENTER to continue, Ctrl-C to quit."
    echo "***************************************************"
    read -e ""
}

# Create an easy detailed 'ls' alias
alias l="ls -1 -lah"

alias runPassageway="/Applications/runscope-passageway --bucket=4k0snp2zbost --fixed 8001"

function alert() {
  Title="$1"
  Msg="$2"
  osascript -e "display notification \"$Msg\" sound name \"Ping.aiff\" with title \"$Title\" "  # Mac notification system
  say "$Title"
}

alarm () {
  # Parse options
  local DELAY=10
  local INTERV=10
  local MESSAGE=0
  while getopts d:i:m: option; do
    case "${option}"; in
      d) DELAY=${OPTARG};;
      i) INTERV=${OPTARG};;
      m) MESSAGE=${OPTARG};;
    esac
  done

  # Validate Options

  # Set the alarm
  sleep $DELAY
  while true; do 
    alert $MESSAGE
    sleep $INTERV
  done
}

function printWithTimestamp() {
  echo "$(timestamp) ${@:1}"
}

function timestamp() {
  if [[ $1 == '-d' ]]; then
    echo $(date -j "+[%Y-%m-%d %H:%M:%S]")
  else
    echo $(date -j "+[%H:%M:%S]")
  fi
}

# NOT WORKING
function rand() {
  local rnd=$RANDOM
  #RANDOM=$rnd
  #echo "<< $RANDOM $rnd >>"
  if [[ $1 == '' || $2 == '' ]]; then
    echo $rnd
  else
    local Range=$(($2 - $1))
    local Scaled=$(($rnd * Range / 32768))
    echo $(($1+Scaled))
  fi
}
function randScaled() {
  if [[ $1 == '' || $2 == '' || $3 == '' ]]; then
    # Error msg!
    return 10;
  else
    local rnd=$3
    local Range=$(($2 - $1))
    local Scaled=$(($rnd * Range / 32768))
    echo $(($1+Scaled))
  fi
}

function lrencode() {
  if [[ $1 == '' ]]; then
    # Error msg!
    return 10;
  fi
  local randomized=false
  if [[ $2 == '-r' ]]; then
    randomized=true
  fi

  local String=$1
  local Index=0
  local Length=${#String}
  local fbSwitch=0
  local Output=''
  local rnd=0
  while [[ $Index -lt $Length ]]; do
    local char=${String:$Index:1}
    rnd=$RANDOM
    rnd=`randScaled 0 10 $rnd`
    if [[ $randomized == false || ( $randomized == true && $rnd -lt 3 ) ]]; then
      if [[ $fbSwitch == 0 ]]; then
        Output="$Output""‮"
      else
        Output="$Output""‭"
      fi
      fbSwitch=$((1-fbSwitch))
    fi

    Output="$Output""$char"
    Index=$((Index+1))
  done
  echo -n $Output | pbcopy
  echo $Output
}

# Modified, originally from http://superuser.com/questions/611538/is-there-a-way-to-display-a-countdown-or-stopwatch-timer-in-a-terminal
function settimer() {
  countdown ${@:1} &
}
function countdown() {
   date1=$((`date +%s` + $1)); 
   # echo $date1
   while [ "$date1" -ge `date +%s` ]; do 
     # echo -ne "$(date -u -date @$(($date1 - `date +%s`)) +%H:%M:%S)\r";
     sleep 0.1
   done
   alert ${@:2}
}
function stopwatch() {
  date1=`date +%s`; 
   while true; do 
    echo -ne "$(date -u -date @$((`date +%s` - $date1)) +%H:%M:%S)\r"; 
    sleep 0.1
   done
}

function waitFor() {
  while true; do
    local pCount=`ps -ax | grep $1 -c`
    # Less than 4 because when the terminal is idle, it's expected that these processes:
    #   * login -fp stephenbush
    #   * -zsh
    #   * grep (the process for the grep command below querying about the target terminal will always find itself)
    # will always be found, so any process count of 4 or more indicates the terminal is non-idle.
    # Wait until the terminal is idle, then break.
    if [[ $pCount -lt 4 ]]; then
      break
    fi
    sleep 0.2
  done
}

# ==============================================================================
# ZSH Extensions

function changeTheme() {
  ZSH_THEME=${1?"robbyrussell"}
  loadZSH
}

function loadZSH() {
  source $ZSH/oh-my-zsh.sh  
}




# ==============================================================================
# Alias Management -- Provides a framework for safely "Hooking" into aliases, 
#   for makeshift event handling

function _createBaseAlias () {
  {
    local AliasToTest=$1"_BaseAliasContent"
    if [[ $(eval echo \$$AliasToTest) == "" ]]; then
      if [[ true == true ]]; then
        local TempText=""
        alias $1
        if [[ $? -gt 0 ]]; then
          # No alias exists
          TempText="\\\\$1 $""@"
        else
          local TEMP_PREV_CONTENTS=$(eval echo \$$1)""
          eval $(alias $1 | sed -e 's:\\:\\\\:g')
          TempText="$(eval echo \$$1) $""@"
          eval "$1""=""$TEMP_PREV_CONTENTS"
        fi
        eval "$AliasToTest""="'$TempText'
      fi
    fi
  } &> /dev/null
}


function _createBaseAliasOLD () {
  {
    local AliasToTest=$1"_BaseAliasContent"
    if [[ $(eval echo \$$AliasToTest) == "" ]]; then
      local TempText="'\\\\$1 $""@'"
      eval $AliasToTest=$TempText
    fi
  } &> /dev/null
}

function _wrapAlias () {
  alias $1="function Alias_Function_Wrapper () { ""$(eval echo \$$1"_BaseAliasContent")"" }; Alias_Function_Wrapper"
}


function appendAlias () {
  {
    _createBaseAlias $1
    eval $1"_BaseAliasContent""="\$"$1""_BaseAliasContent""'; '""'${@:2}'"
    _wrapAlias $1
  } &> /dev/null
}

function prependAlias () {
  {
    _createBaseAlias $1
    eval $1"_BaseAliasContent""=""'${@:2}'""'; '"\$"$1""_BaseAliasContent"
    _wrapAlias $1
  } &> /dev/null
}





# ==============================================================================
# Docker Functions -- 

dockerReboot () {
  # # VBoxManage list
  # # VBoxManage showvminfo boot2docker-vm
  # # boot2docker stop
  # # VBoxManage controlvm boot2docker-vm poweroff
  # # VBoxManage unregistervm boot2docker-vm --delete
  # # rm -rf ~/VirtualBox\ VMs/boot2docker-vm/
  # boot2docker init

  (port=49444;VBoxManage modifyvm "boot2docker-vm" --natpf1 "tcp-port${port},tcp,,${port},,${port}")

  boot2docker up

  export DOCKER_HOST=tcp://192.168.59.103:2376
  export DOCKER_CERT_PATH=/Users/stephenbush/.boot2docker/certs/boot2docker-vm
  export DOCKER_TLS_VERIFY=1

  #docker login docker.webfilings.org --username="stephenbush-wf" --password="d60d1deb7b" --email="stephen.bush@workiva.com"
  # Use --insecure-registry ??

  # dockerUpdate $1 $2
}

dockerUpdate() {
  local imageToLoad="latest" # Default
  if [[ $1 != "" ]]; then
    imageToLoad="$1"
  fi

  local image2ToLoad="latest" # Default
  if [[ $2 != "" ]]; then
    image2ToLoad="$2"
  fi

  # Run the NVS Task Manager
  docker stop nvs-task-manager
  docker rm nvs-task-manager
  docker pull docker.webfilings.org/hydra/nvs-task-manager:"$imageToLoad"
  docker run -t -d -p 49444:49444 --name nvs-task-manager -e "DEMETER_CONF=-l DEBUG" docker.webfilings.org/hydra/nvs-task-manager:"$imageToLoad"

  # Run the NVS Worker
  docker stop nvs-worker
  docker rm nvs-worker
  docker pull docker.webfilings.org/hydra/nvs-worker:"$image2ToLoad"
  docker run -d --name nvs-worker --link nvs-task-manager:nvs-task-manager -e "DEMETER_CONF=-l DEBUG" docker.webfilings.org/hydra/nvs-worker:"$image2ToLoad"
}

function runTests() {
  runTerminalFunction runTests
}


# ==================================================================================================================
# Min/max functions
#   From Arnon Zilca
#   https://stackoverflow.com/questions/10415064/how-to-calculate-the-minimum-of-two-variables-simply-in-bash
#
# Examples:
#   min -g 3 2 5 1
#   max -g 1.5 5.2 2.5 1.2 5.7
#   min -h 25M 13G 99K 1098M
#   max -d "Lorem" "ipsum" "dolor" "sit" "amet"
#   min -M "OCT" "APR" "SEP" "FEB" "JUL"
min() {
    printf "%s\n" "${@:2}" | sort "$1" | head -n1
}
max() {
    # using sort's -r (reverse) option - using tail instead of head is also possible
    min ${1}r ${@:2}
}
# ==================================================================================================================



function forceKillAll () {
	local Target=$1
	for PID in $(ps -A -v | grep $Target | awk '{print $1}')
	do
		print Killing PID $PID
		kill -9 $PID &> /dev/null
	done
}


function searchUrl() {
  # Parse options
  local BURL=""
  local ITER=1
  local MAXCOUNT=0
  local DELAY=1
  local START=0
  local COMMAND=""
  while getopts u:i:m:d:s:c: option; do
    case "${option}"; in
      u) BURL=${OPTARG};;
      i) ITER=${OPTARG};;
      m) MAXCOUNT=${OPTARG};;
      d) DELAY=${OPTARG};;
      s) START=${OPTARG};;
      c) COMMAND=${OPTARG};;
    esac
  done

  # Validate Options

  # Run
  print "URL:      $BURL"
  print "Start at: $START"
  print "Iterate:  $ITER"
  print "Delay:    $DELAY sec"
  print "Count:    $MAXCOUNT"
  if [[ $COMMAND == "" ]]; then
    print "Action:   Open"
  else
    print "Action:   $COMMAND"
  fi
  sleep 2
  
  local CT=$(($START+0)); 
  while [[ $((($CT-$START)/ITER)) -lt $MAXCOUNT ]]; do
    local URL="${BURL/++/$CT}"
    if [[ $COMMAND == "" ]]; then
        echo "Opening $URL"
        open $URL
    else
        echo "Running Command on $URL"
        eval $(echo "$COMMAND $URL")
    fi
    CT=$(($CT+$ITER))
    sleep $DELAY
  done
}

# Helper function for printing a timestamp in status messages
function timestamp() {
  echo $(date -j "+[%H:%M:%S]")
}


function watchUrl() {
  # Parse options
  local BURL=""
  local BASEDELAY=1
  local SEARCH=""
  local INIT=0

  while getopts u:s:d: option; do
    case "${option}"; in
      u) BURL=${OPTARG};;
      d) BASEDELAY=${OPTARG};;
      s) SEARCH=${OPTARG};;
    esac
  done

  local compareStr=""
  while true; do
    local tempStrList=$(curl $BURL | grep $SEARCH) &>/dev/null
    if [[ $? -ne 0 ]]; then
      DELAY="10"
      continue
    fi
    local tempStr=""
    local DELAY="$BASEDELAY"
    for str in $tempStrList; do
      tempStr="$tempStr,$str"
    done

    if [[ $INIT -eq 0 ]]; then
      INIT=1
      compareStr="$tempStr"
      print "$(timestamp) Found Compare String:\n  $compareStr"
      DELAY="1"
    else
      if [[ $tempStr != $compareStr ]]; then
        #local dff=$(diff  <(echo "$compareStr" ) <(echo "$tempStr"))
        print "$(timestamp) Found New String:\n  $tempStr"
        alert "URL Updated" "$BURL\n$SEARCH"
        DELAY="$(min -g $BASEDELAY 10)"
      else
        echo -en " $(timestamp) Checked\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
      fi
    fi

    sleep $DELAY
  done
}

