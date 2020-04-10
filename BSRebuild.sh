#!/bin/sh

# Written by Stephen Bush, Workiva (HyperText)

# Username of the Dev Account on the local machine
BSVAR__User_Name='StephenBush'

# ======================================================
#   Bigsky Builder System Config
# ======================================================
# Directory of the workspace where all your Workiva repositories live
BSVAR__Root_Workspace_Directory='/Users/'"$BSVAR__User_Name"'/workspaces/wf/'
# Directory into which to store backup files (Settings,data,etc)
BSVAR__BKDIR='/Users/'"$BSVAR__User_Name"'/Documents/Programming Environment Stuff/bigsky Backup Files/'
# Github URL for the main Bigsky development fork used by you or your team
BSVAR__Bigsky_Fork='git@github.com:timmccall-wf/bigsky.git'
# These are the login credentials used to authenticate the SuperAdmin in the Erase-reset script
BSVAR__EraseResetAdmin="stephen.bush@webfilings.com"
BSVAR__EraseResetPassword="w3b"
# Flag to allow/disallow the Rebuild script from running while BigSky is running
# Recommended false, as changes to the Bigsky repo while the server is running could
#   cause problems with the running server AND/OR important pieces of the rebuild process 
#   could be caused to fail.
BSVAR__Allow_Rebuild_When_Server_Running=false
# Flag to allow 'git gc' to run during build process.  Adds about 5 minutes to build time.
#    Effects may be negligible for most users who dont actually perform dev work on Bigsky.
BSVAR__Run_Git_Garbage_Collection=false
BSVAR__Accounts_CSV_Content="
Stephen,Bush,stephen.bush@webfilings.com,w3b,,WebFilings,stephen.bush@webfilings.com,666-666-6667,555-555-5556,444-444-4445,333-333-3334,2131 North Loop Drive,,,Ames,IA,50011
Leroy,Jenkins,leroy@jenkins.com,m0r3pyl0ns!,,WebFilings,leroy@jenkins.com,666-666-6667,555-555-5556,444-444-4445,333-333-3334,2131 North Loop Drive,,,Ames,IA,50011
"



# ======================================================
#   Datastore Management Config
# ======================================================
BSVAR__Datastore_Directory='/Users/'"$BSVAR__User_Name"'/Documents/Programming Environment Stuff/datastore/'
# Flag to allow/disallow the Datastore scripts from running during a build.
BSVAR__Backup_And_Restore_Datastore=true
# Flag to allow/disallow the Datastore scripts from running while BigSky is running
# Recommended false, because the datastore files are somewhat volatile and some elements 
#   may not be saved until after the server is properly shut down.
BSVAR__Allow_Datastore_Imaging_When_Server_Running=false



bsRebuild () {

  # Helper function for printing a timestamp in status messages
  function bstimestamp() {
    echo $(date -j "+[%H:%M:%S]")
  }

  # Helper function for removing instances of text $2 from original text $1 
  function stripString() {
    echo $1 | sed -e "s/${2}//g"
  }

  # Dependency Checks
  if [[ $BSVAR__Backup_And_Restore_Datastore == true ]]; then
    which -s dsBackup &> /dev/null && local useDataStoreBackup=true
    which -s dsRestore &> /dev/null && local useDataStoreRestore=true
  fi
  
  if [[ $1 == "help" ]]; then
    echo "$fg[cyan]================================================================================"
    echo "Workiva BigSky Project-Builder Script,"
    echo "   written by Stephen Bush (Hypertext)"
    echo ""
    echo ""
    echo "  This script is designed to be comprehensive, and yield a successful (but not"
    echo "necessarily fast) BigSky build.  It contains many extra steps, including a full"
    echo "rebuilding of dependencies and wiping of the VirtualEnv for bigsky.  The reason"
    echo "for this is that these steps typically fix common build problems, and can lead"
    echo "to build failures if they need to be run and aren't.  So every single step is"
    echo "run pre-emptively."
    echo "  The goal is, you can start a rebuild and go grab a snack and a cup of coffee"
    echo "and come back knowing your build will be successful.  Chances are that a failed"
    echo "quick build (or multiple failures), a fix and a quick rebuild will still eat up"
    echo "more time than a long build that completes successfully."
    echo "  This build also includes many link steps designed to hook other development"
    echo "repositories into BigSky, making development easier.  Individual link steps"
    echo "should be commented out of the script in order to skip them when rebuilding, "
    echo "else these repos should be kept up-to-date to ensure that BigSky still runs as"
    echo "expected."
    echo ""
    echo ""
    echo "================================================================================"
    echo ""
    echo "  $fg[cyan] Usage:"
    echo ""
    echo "     $reset_color bsRebuild [options]"
    echo ""
    echo ""
    echo "  $fg[cyan] Options:"
    echo ""
    echo "     $fg[cyan] help, --help, -h"
    echo "        $reset_color Shows this help dialog"
    echo ""
    echo "     $fg[cyan] -f"
    echo "        $reset_color Runs in full rebuild mode.  When this flag is set, in addition to all"
    echo "       of the other build steps, the script will also completely remove and"
    echo "       re-clone BigSky from the remote repository, and perform additional steps."
    echo "       This can usually fix rare problems related to a corrupted or extremely"
    echo "       outdated file structure."
    echo ""
    echo "     $fg[cyan] -b <origin> <branch>"
    echo "        $reset_color When this flag is set, the specified remote branch is checked out and"
    echo "       used instead of master prior to running the rebuild steps."
    echo ""
    echo "     $fg[cyan] -s"
    echo "        $reset_color Skips many of the hefty rebuild steps (including ant full) and only"
    echo "       performs update/link steps.  This can often fix minor dependency and/or "
    echo "       linking issues that dont require a full rebuild."
    echo ""
    echo "     $fg[cyan] -l"
    echo "        $reset_color Skips almost all of the build steps and only links in external repos."
    echo ""
    echo "     $fg[cyan] -L"
    echo "        $reset_color Skips the link step."
    echo ""
    echo "     $fg[cyan] -r"
    echo "        $reset_color When the build completes, run bigsky (bsRunServer)."
    echo ""
    echo "     $fg[cyan] -R"
    echo "        $reset_color Normally a build command will fail if Bigsky is running.  The -R flag"
    echo "       overrides this and allows the build to run anyway"
    echo ""
    echo "     $fg[cyan] -u"
    echo "        $reset_color Update the local branch with remote updates (git pull)."
    echo ""
    if [[ $useDataStoreBackup == true ]]; then    
      echo "     $fg[cyan] -d <name>"
      echo "        $reset_color Backs up the datastore prior to build with the specified name."
      echo ""
    fi
    if [[ $useDataStoreRestore == true ]]; then    
      echo "     $fg[cyan] -D <name>"
      echo "        $reset_color Restores the datastore during build with the specified name."
      echo ""
    fi
    return 0
  fi

  echo "$fg[magenta]==============================\n    === BigSky Builder ===\n==============================$reset_color"

  # Dynamic argument parsing
  FlagFull=false
  FlagSkip=false
  FlagLinkOnly=false
  FlagSkipLink=false
  FlagBranch=false
  FlagDatastoreBackup=false
  FlagDatastoreRestore=false
  FlagRunBigSky=false
  FlagUpdate=false
  FlagOverrideRunningBigSky=false
  CurParamNum=1
  while true; do
    eval "CurParam=\$$CurParamNum"
    if [[ $CurParam == "" ]]; then
      break
    fi

    if [[ $CurParam =~ '^-.*f.*' ]]; then
      CurParam=$(stripString $CurParam f)
      FlagFull=true
      echo "$fg[cyan] $(bstimestamp) [bs build] -- Enabling full build (Repo nuke + full re-build)$reset_color"
    fi

    if [[ $CurParam =~ '^-.*s.*' ]]; then
      CurParam=$(stripString $CurParam s)
      FlagSkip=true
      echo "$fg[cyan] $(bstimestamp) [bs build] -- Skipping main build-steps$reset_color"
    fi

    if [[ $CurParam =~ '^-.*l.*' ]]; then
      CurParam=$(stripString $CurParam l)
      FlagLinkOnly=true
      echo "$fg[cyan] $(bstimestamp) [bs build] -- Only build repo links$reset_color"
    fi

    if [[ $CurParam =~ '^-.*L.*' ]]; then
      CurParam=$(stripString $CurParam L)
      FlagSkipLink=true
      echo "$fg[cyan] $(bstimestamp) [bs build] -- Skip building repo links$reset_color"
    fi

    if [[ $CurParam =~ '^-.*r.*' ]]; then
      CurParam=$(stripString $CurParam r)
      FlagRunBigSky=true
      echo "$fg[cyan] $(bstimestamp) [bs build] -- Running BigSky after build$reset_color"
    fi

    if [[ $CurParam =~ '^-.*R.*' ]]; then
      CurParam=$(stripString $CurParam R)
      FlagOverrideRunningBigSky=true
      echo "$fg[cyan] $(bstimestamp) [bs build] -- Override error if bigsky running$reset_color"
    fi

    if [[ $CurParam =~ '^-.*u.*' ]]; then
      CurParam=$(stripString $CurParam u)
      FlagUpdate=true
      echo "$fg[cyan] $(bstimestamp) [bs build] -- Updating branch with remote server$reset_color"
    fi

    if [[ $CurParam =~ '^-.*b.*' ]]; then
      CurParam=$(stripString $CurParam b)
      FlagBranch=true

      # Parse extra param for the Branch Origin
      CurParamNum=$(($CurParamNum+1))
      eval "BranchOrigin=\$$CurParamNum"
      if [[ $BranchOrigin == "" || $BranchOrigin =~ '^-.*' ]]; then
        echo "$fg[red] $(bstimestamp) [bs build] ERROR: This command requires at least two arguments following the -b parameter!  See 'bsRebuild --help' for more details.$reset_color"
        return 11
      fi

      # Parse extra param for the Branch Name
      CurParamNum=$(($CurParamNum+1))
      eval "BranchName=\$$CurParamNum"
      if [[ $BranchName == "" || $BranchName =~ '^-.*' ]]; then
        echo "$fg[red] $(bstimestamp) [bs build] ERROR: This command requires at least two arguments following the -b parameter!  See 'bsRebuild --help' for more details.$reset_color"
        return 11
      fi

      echo "$fg[cyan] $(bstimestamp) [bs build] -- Building remote branch { $BranchOrigin $BranchName }$reset_color"
    fi

    DSBackup="PreBuild Backup"
    if [[ $useDataStoreBackup == true && $CurParam =~ '^-.*d.*' ]]; then
      CurParam=$(stripString $CurParam d)
      FlagDatastoreBackup=true

      # Parse extra param
      CurParamNum=$(($CurParamNum+1))
      eval "DSBackup=\$$CurParamNum"
      if [[ $DSBackup == "" || $DSBackup =~ '^-.*' ]]; then
        echo "$fg[red] $(bstimestamp) [bs build] ERROR: This command requires at least one argument following the -d parameter! (Backup name)  See 'bsRebuild --help' for more details.$reset_color"
        return 11
      fi

      echo "$fg[cyan] $(bstimestamp) [bs build] -- Backing up Datastore directory { $DSBackup }$reset_color"
    fi

    DSRestore="PreBuild Backup"
    if [[ $useDataStoreRestore == true && $CurParam =~ '^-.*D.*' ]]; then
      CurParam=$(stripString $CurParam D)
      FlagDatastoreRestore=true

      # Parse extra param
      CurParamNum=$(($CurParamNum+1))
      eval "DSRestore=\$$CurParamNum"
      if [[ $DSRestore == "" || $DSRestore =~ '^-.*' ]]; then
        echo "$fg[red] $(bstimestamp) [bs build] ERROR: This command requires at least one argument following the -D parameter! (Backup name)  See 'bsRebuild --help' for more details.$reset_color"
        return 11
      fi

      echo "$fg[cyan] $(bstimestamp) [bs build] -- Restoring Datastore directory { $DSRestore }$reset_color"
    fi    

    if [[ $CurParam =~ '^-.*h.*' || $CurParam =~ '^-.*help.*' || $CurParam =~ '^help' ]]; then
      bsRebuild help
      return 0
    fi

    if [[ ! $CurParam == "-" && ! $CurParam == "--" ]]; then
      echo "$fg[yellow] $(bstimestamp) [bs build] WARNING: Unrecognized command or parameters, $CurParam $reset_color"
    fi

    CurParamNum=$(($CurParamNum+1))
  done

  # Check to see whether Bigsky is currently running
  if [[ $BSVAR__Allow_Rebuild_When_Server_Running == false && $(isBigskyRunning) == true && $FlagOverrideRunningBigSky == false ]]; then
    echo "$fg[red]Error, cannot execute this function while BigSky server is running.$reset_color"
    return 10
  fi

  if [[ "${PWD##*/}" != 'bigsky' ]]; then
    echo "$fg[red]Error, this function must be run from a bigsky directory.$reset_color"
    return 10
  fi
  # cd "$BSVAR__Root_Workspace_Directory"
  # gtsky
  cd ..
  baseDir="${PWD##*/}"
  baseVenv=$baseDir"-sky"
  cd bigsky
  workon $baseVenv

  if [[ $FlagLinkOnly == false ]]; then
  
    if [[ $FlagSkip == false ]]; then
      deactivate
      echo "$fg[cyan] $(bstimestamp) [bs build] Removing Sky Virtual Environment$reset_color"
      rmvirtualenv $baseVenv
      rm -rf "$WORKON_HOME/$baseVenv/"
    fi

    if [[ $FlagDatastoreReset != true && $useDataStoreBackup == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] Backing up the Local Datastore to $DSBackup $reset_color"
      dsBackup $DSBackup
    fi

    if [[ $FlagFull == true && $FlagSkip == false ]]; then

      cd ..
      if [[ -d bigsky ]]; then
        echo "$fg[cyan] $(bstimestamp) [bs build] Wiping the working BigSky directory...$reset_color"
        rm -rf bigsky
      else
        echo "$fg[cyan] $(bstimestamp) [bs build] No BigSky directory detected, creating one...$reset_color"
        cd -
      fi

      echo "$fg[cyan] $(bstimestamp) [bs build] Cloning new Repository...$reset_color"
      git clone $BSVAR__Bigsky_Fork

      cd bigsky

      echo "$fg[cyan] $(bstimestamp) [bs build] Building new Virtual Environment $reset_color"
      mkvirtualenv $baseVenv -a $PWD
      workon $baseVenv

      git remote -v
      echo "$fg[cyan] $(bstimestamp) [bs build] Updating Remote repository settings $reset_color"
      git remote remove origin
      git remote add origin $BSVAR__Bigsky_Fork
      #git remote add trentgrover git@github.com:trentgrover-wf/bigsky.git
      #git remote add robbielamb git@github.com:robbielamb-wf/bigsky.git
      #git remote add mikethiesen git@github.com:mikethiesen-wf/bigsky.git
      #git remote add timmccall git@github.com:timmccall-wf/bigsky.git
      #git remote add jasonzerbe git@github.com:jasonzerbe-wf/bigsky.git
      git remote add upstream git@github.com:Workiva/bigsky.git
      git remote add CI git@github.com:codebuilders-wf/bigsky.git
      git remote -v

      if [[ $FlagBranch == true ]]; then
        echo "$fg[cyan] $(bstimestamp) [bs build] Fetching/Pruning remote $BranchOrigin $reset_color"
        git remote update --prune $BranchOrigin
        echo "$fg[cyan] $(bstimestamp) [bs build] Switching branches $reset_color"
        git checkout $BranchName
        git checkout -b $BranchName
        if [[ $FlagUpdate == true ]]; then
          git pull $BranchOrigin $BranchName
        fi
      fi

      # echo "$fg[cyan] $(bstimestamp) [bs build] Building libraries $reset_color"
      # brew install python --framework
      # sudo chown -R $BSVAR__User_Name /Library/Python/2.7/site-packages
      # wget https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -O - | python

      # ========= Temporary Issue workaround =========
      echo "$fg[cyan] $(bstimestamp) [bs build] Downgrading pip to v1.5.6 (Temporary issue workaround) $reset_color"
      pip install pip==1.5.6
      # ========= Temporary Issue workaround =========
  
      echo "$fg[cyan] $(bstimestamp) [bs build] Installing/Updating dependencies $reset_color"
      pip install gae_link_libs
      env CFLAGS="-Qunused-arguments" CPPFLAGS="-Qunused-arguments" pip install -r requirements_dev.txt
      pip install -r requirements.txt
      pip install -e .
      ant link-libs
      npm install -g n
      npm update
      bower update

      # ========= Temporary Issue workaround =========
      echo "$fg[cyan] $(bstimestamp) [bs build] Downgrading pip to v1.5.6 (Temporary issue workaround) $reset_color"
      pip install pip==1.5.6
      # ========= Temporary Issue workaround =========

    else

      if [[ $FlagSkip == false ]]; then
        echo "$fg[cyan] $(bstimestamp) [bs build] Building new Virtual Environment $reset_color"
        mkvirtualenv $baseVenv -a $PWD
        workon $baseVenv

        echo "$fg[cyan] $(bstimestamp) [bs build] Cleaning up Repository directory $reset_color"
        git reset --hard HEAD
        git clean -xfd
        yes | pycleaner
        if [[ $BSVAR__Run_Git_Garbage_Collection == true ]]; then        
          echo "$fg[cyan] $(bstimestamp) [bs build] Running git gc $reset_color"
          git gc --aggressive
        fi
      fi

      if [[ $FlagBranch == true ]]; then
        echo "$fg[cyan] $(bstimestamp) [bs build] Fetching/Pruning remote $BranchOrigin $reset_color"
        git remote update --prune $BranchOrigin
        echo "$fg[cyan] $(bstimestamp) [bs build] Switching branches $reset_color"
        git checkout $BranchName
        git checkout -b $BranchName
        if [[ $FlagUpdate == true ]]; then
          git pull $BranchOrigin $BranchName
        fi
      else
        echo "$fg[cyan] $(bstimestamp) [bs build] Fetching/Pruning origin branches $reset_color"
        git remote update --prune origin
        if [[ $FlagUpdate == true ]]; then
          git pull
        fi
      fi

    fi  

    echo "$fg[cyan] $(bstimestamp) [bs build] Replacing untracked files backed up earlier $reset_color"
    replaceStaticBigSkyFiles

    # ========= Temporary Issue workaround =========
    echo "$fg[cyan] $(bstimestamp) [bs build] Downgrading pip to v1.5.6 (Temporary issue workaround) $reset_color"
    pip install pip==1.5.6
    # ========= Temporary Issue workaround =========
  
    echo "$fg[cyan] $(bstimestamp) [bs build] Installing/Updating dependencies $reset_color"
    git submodule update --init
    env CFLAGS="-Qunused-arguments" CPPFLAGS="-Qunused-arguments" pip install -r requirements_dev.txt

    # ========= Temporary Issue workaround =========
    echo "$fg[cyan] $(bstimestamp) [bs build] Downgrading pip to v1.5.6 (Temporary issue workaround) $reset_color"
    pip install pip==1.5.6
    # ========= Temporary Issue workaround =========

    npm update
    bower update
    if [[ $FlagSkip == false ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] Running BigSky build (ant full)... $reset_color"
      ant full
    fi

    if [[ $FlagDatastoreReset == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] Running erase/reset script $reset_color"
      # echo "$fg[cyan] $(bstimestamp) [bs build] ** Make sure the Python erase_reset_data.py script arguments match your user login credentials in ./tools/bulkdata/accounts.csv, or you may have problems running BigSky! $reset_color"
      bsResetData
    elif [[ $useDataStoreRestore == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] Restoring Datastore image to $DSRestore $reset_color"
      dsRestore $DSRestore
    else
      echo "$fg[cyan] $(bstimestamp) [bs build] Running erase/reset script $reset_color"
      # echo "$fg[cyan] $(bstimestamp) [bs build] ** Make sure the Python erase_reset_data.py script arguments match your user login credentials in ./tools/bulkdata/accounts.csv, or you may have problems running BigSky! $reset_color"
      bsResetData
    fi
    git checkout 'tools/bulkdata/accounts.csv'

  else 
    if [[ $FlagBranch == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] Fetching/Pruning remote $BranchOrigin $reset_color"
      git remote update --prune $BranchOrigin
      echo "$fg[cyan] $(bstimestamp) [bs build] Switching branches $reset_color"
        git checkout $BranchName
        git checkout -b $BranchName
        if [[ $FlagUpdate == true ]]; then
          git pull $BranchOrigin $BranchName
        fi
    fi
  fi

  if [[ $FlagSkipLink == false ]]; then
    # =======================================================
    # Throw in some commands here to build bower/symlinks for development repos.
    # Pre-existing ones can also be toggled on/off by default by changing the install flag from false -> true
    # =======================================================
    
    echo "$fg[cyan] $(bstimestamp) [bs build] ===$fg[red] :: WARNING ::$fg[cyan] ===\n $(bstimestamp) [bs build] ** Linking in external development modules:$reset_color"

    # Link Reference Viewer
    installMe=false
    if [[ $installMe == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] -- 'wf-js-reference-viewer' via rv.sh$reset_color"
      cd apps
      ./rv.sh link
      cd ..
    fi

    # Link Doc-viewer
    installMe=false
    if [[ $installMe == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] -- 'sky-docviewer/wf-js-document-viewer' via pip install -e (linkDocViewer())$reset_color"
      linkDocViewer
    fi

    # Viewerize
    installMe=false
    if [[ $installMe == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] -- 'server_composition', 'wf-viewer-services', 'sky-docviewer/wf-js-document-viewer' via pip install -e (bsviewerize())$reset_color"
      bsviewerize
    fi

    # Link in w-annotation via SymLink
    installMe=false
    if [[ $installMe == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] -- 'w-annotation' via ln -s$reset_color"
      ln -s "$BSVAR__Root_Workspace_Directory"w-annotation/annotation annotation
    fi

    # Link in w-annotation via pip install
    installMe=false
    if [[ $installMe == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] -- 'w-annotation' via pip install -e$reset_color"
      pip uninstall -y w-annotation
      pip install -e ../w-annotation
    fi

    # Link in wf-sdk via pip install
    installMe=false
    if [[ $installMe == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] -- 'wf-sdk' via pip install -e$reset_color"
      yes | pip uninstall wf-sdk
      pip install -e ../wf-sdk
    fi

    # Copy Static w-annotation-js file into BigSky
    installMe=false
    if [[ $installMe == true ]]; then
      echo "$fg[cyan] $(bstimestamp) [bs build] -- 'w-annotation-js' via static file copy (copyStaticAnnotationFile())$reset_color"
      copyStaticAnnotationFile
      workon $baseVenv
    fi
  fi

  echo "$fg[green]====================================="
  echo "    === BigSky Build Complete ==="
  echo "=====================================$reset_color"


  # Alert
  say "Build complete"
  osascript -e "display notification \"Bigsky Build Complete\" sound name \"Ping.aiff\" with title \"Build Complete\" "  # Mac notification system

  if [[ $FlagRunBigSky == true ]]; then
    bsRunServer
  fi
}

killBS () {
  for PID in $(ps -A -v | grep "manage.py" | awk '{print $1}');
  do
    kill -9 $PID &> /dev/null
  done
  if [[ $1 == "--run" ]]; then
    bsRunServer
  fi
}

# Big Sky Quick-Build and Run
alias bsqbar="bsRebuild -sLr -ub upstream master"

# This helper function determines whether a bigsky server is currently running
isBigskyRunning () {
  curl -s http://localhost:8001/home/
  if [[ $? == 0 ]]; then
    echo true
  else
    echo false
  fi
}

copyStaticBigSkyFiles() {
  cp settingslocal.py $BSVAR__BKDIR
  cp build-user.properties $BSVAR__BKDIR
  #cp tools/bulkdata/accounts.csv $BSVAR__BKDIR
}


replaceStaticBigSkyFiles() {
  cp $BSVAR__BKDIR"settingslocal.py" $PWD
  cp $BSVAR__BKDIR"build-user.properties" $PWD
  #cp $BSVAR__BKDIR"accounts.csv" $PWD"/tools/bulkdata/"
}

bsResetData () {
  rm -rf $BSVAR__Datastore_Directory
  mkdir $BSVAR__Datastore_Directory
  echo $BSVAR__Accounts_CSV_Content > ./tools/bulkdata/accounts.csv
  bsEraseReset
}

bsEraseReset() {
  python tools/erase_reset_data.py \
    --admin="$BSVAR__EraseResetAdmin" \
    --password="$BSVAR__EraseResetPassword" \
    --enabled_settings= \
        enable_presentations, \
        enable_doc_viewer, \
        enable_charts, \
        enable_two_column, \
        enable_risk, \
        enable_csr, \
        enable_books_viewer_comments, \
        enable_books_viewer_shared_comments, \
        enable_table_bullets, \
        enable_annotation_attachments, \
}

gtsky () {
  if [[ $VIRTUAL_ENV != "" ]]; then
    deactivate
  fi
  builtin cd ~/workspaces/wf/bigsky
  activate_virtualenv
}

function bsRunServer() {
  gtsky
  ./manage.py runserver 0.0.0.0:8001
  # dev_appserver.py --port=8001 --datastore_path='/Users/stephenbush/Documents/Programming Environment Stuff/datastore/django_dev~big-sky.datastore' .
}

function rebuild() {

  # Helper function for printing a timestamp in status messages
  function bstimestamp() {
    echo $(date -j "+[%H:%M:%S]")
  }



  # If there's a venv, re-create it
  if [[ $1 == "-f" ]]; then
    which -s check_virtualenv &> /dev/null &&
    which -s activate_virtualenv &> /dev/null || {
      echo "$fg[red]Unable to rebuild; Missing dependency 'check_virtualenv'"
      return
    }
    local VENV=$(check_virtualenv)

    if [[ $VENV != "" ]]; then
      echo "$fg[cyan] $(bstimestamp) [rebuild] -- Re-create VirtualEnvironment$reset_color"
      deactivate
      rmvirtualenv $VENV
      rm -rf "$WORKON_HOME/$VENV/"
      mkvirtualenv $VENV -a $PWD
    fi
  fi
  local FlagSkip=false
  if [[ $1 == "-s" ]]; then
    FlagSkip=true
  fi

  activate_virtualenv

  git submodule update

  # Pull Deps
  if [[ -e bower.json ]]; then  
    echo "$fg[cyan] $(bstimestamp) [rebuild] -- Running bower install$reset_color"
    # if [[ $FlagSkip == false ]]; then
    #   rm -rf bower_components/    
    # fi
    bower prune
    bower install
  fi
  if [[ -e package.json ]]; then  
    echo "$fg[cyan] $(bstimestamp) [rebuild] -- Running npm install$reset_color"
    # if [[ $FlagSkip == false ]]; then
    #   rm -rf node_modules/
    # fi
    npm prune
    npm install
  fi
  if [[ -e requirements.txt ]]; then  
    echo "$fg[cyan] $(bstimestamp) [rebuild] -- Running pip install$reset_color"
    pip-sync || pip install -e . || pip install requirements.txt
  fi
  if [[ -e pubspec.yaml ]]; then  
    echo "$fg[cyan] $(bstimestamp) [rebuild] -- Running pub get$reset_color"
    pub get
  fi


  # Pull Deps And/Or Compile & Build
  if [[ -e Makefile ]]; then
    echo "$fg[cyan] $(bstimestamp) [rebuild] -- Running make install$reset_color"
    make install
  fi


  # Compile & Build
  if [[ -e Gruntfile.js ]]; then  
    echo "$fg[cyan] $(bstimestamp) [rebuild] -- Grunt$reset_color"
    grunt
  fi
  if [[ -e gulpfile.js ]]; then  
    echo "$fg[cyan] $(bstimestamp) [rebuild] -- Gulp$reset_color"
    gulp
  fi

  echo "$fg[green]====================================="
  echo "        === Build Complete ==="
  echo "=====================================$reset_color"

  # Alert
  say "Rebuild complete"
  osascript -e "display notification \"$(PWD) Build Complete\" sound name \"Ping.aiff\" with title \"Build Complete\" "  # Mac notification system
}



# ==============================================================================
# Repo link aliases/scripts

updateBigskyWithBranch() {
  Egg=$1
  Repo=$2
  Branch=$3
  if [[ $Egg == "" || $Repo == "" || $Branch == "" ]]; then
    echo "$fg[red]Error, this command requires at least 3 arguments (Module name, Repository name, Branch/Tag name, [Fork name]).$reset_color"
    return
  fi
  Fork=$4
  if [[ $Fork == "" ]]; then
    Fork='Workiva'
  fi

  # Replace with constructed Github target link
  REPLACE_WITH="git\+ssh:\/\/git\@github.com\/$Fork\/$Repo.git\@$Branch\#egg\=$Egg"

  # Github target form (Replace first so it doesnt write twice)
  REPLACE_REGEX1="git\+ssh:\/\/git\@github.com\/[\w,\_,\-]*\/$Repo.git\@[\w,\_,\-]*\#egg\=$Egg"
  perl -pi -w -e "s/${REPLACE_REGEX1}/${REPLACE_WITH}/g;" requirements.txt

  # Pip module form
  REPLACE_REGEX2="$Egg==[\d]*.[\d]*.[\d]*"
  perl -pi -w -e "s/${REPLACE_REGEX2}/${REPLACE_WITH}/g;" requirements.txt
}
updateBigskyWithDocviewerBranch() {
  updateBigskyWithBranch sky-docviewer wf-js-document-viewer ${@:1}
}



copyStaticAnnotationFile () {
  cd "$BSVAR__Root_Workspace_Directory"w-annotation-js
  gulp build dist
  cp dist/w-annotation.js ../bigsky/static/js/annotation/w-annotation_1.js
}

function unpip () {
  pip uninstall -y ${@:1}
}


# (From Tim McCall) Link in the viewers and stuff
alias bsviewerize=" 
  pip uninstall -y server_composition &&
  pip install -e ../server_composition &&
  pip uninstall -y wf-viewer-services &&
  pip install -e ../wf-viewer-services &&
  linkDocViewer
  ant link-libs
"
# (From Tim McCall) Bower link in external modules
alias bla="bower link wf-js-annotations"
alias blc="bower link wf-common"
alias blrv="bower link wf-js-reference-viewer"
alias blui="bower link wf-uicomponents"
alias blv="bower link wf-js-viewer"


# (From Pat Kujawa) Link in the viewers and stuff
alias bspipssc="
  pip freeze | grep wf-sdk | read wfsdk &&
  bsrepip server-composition server_composition &&
  pip install $wfsdk
"

# (From Pat Kujawa) Link in pip modules and stuff
function bsrepip() {
  pipName=${1?"First arg needs to be the pip name of the lib"}
  # if none supplied, default to $1
  folderName=${2:-$pipName}
  pip uninstall -y $pipName &&
  pip install -e "../$folderName" &&
  ant link-libs
}

function linkSSC() {
  pip freeze | grep wf-sdk | read wfsdk
  pip uninstall -y server_composition
  pip uninstall -y server_composition
  pip install -e ../server_composition
  ant link-libs
  if [[ $wfsdk != "" ]]; then
    pip install $wfsdk
  else
    echo "$fg[red]Error, could not detect version of wfsdk$reset_color"
  fi
}

function linkDocViewer() {
  pip uninstall -y sky-docviewer
  pip uninstall -y sky-docviewer
  pip install -e ../wf-js-document-viewer
  ant link-libs
  ant link-doc-viewer
  ./tools/link_assets.py sky.docviewer assets
}

alias linkBooks="
  bsrepip wf-books books &&
  ant generate-media &&
  ant link-libs &&
  ant link-books
"

alias linkAnnotationServices="
  bsrepip wf-annotation-services
"






# ==============================================================================
# Datastore Management, allows backing up and restoring of the local 
# Datastore directory in order to save settings, documents used for testing, 
# etc.  These functions should not be used while the BigSky server is running, 
# because the files are considered volatile and some elements may not be saved 
# until after the server is properly shut down.

dsBackup () {

  # Helper function for printing a timestamp in status messages
  function dstimestamp() {
    echo $(date -j "+%Y-%m-%d %H.%M.%S")
  }

  # Check to see whether Bigsky is currently running
  if [[ $BSVAR__Allow_Datastore_Imaging_When_Server_Running == false && $(isBigskyRunning) == true ]]; then
    echo "$fg[red]Error, cannot execute this function while BigSky server is running.$reset_color"
    return 10
  fi

  # Create the main directory if it doesnt already exist
  if [[ ! -d $BSVAR__BKDIR"Datastore Images/" ]]; then
    mkdir $BSVAR__BKDIR"Datastore Images/"
  fi

  if [[ ${1} == "" ]]; then
    ImageName=$(dstimestamp)
  else
    ImageName=${1}
  fi

  if [[ -d $BSVAR__BKDIR"Datastore Images/$ImageName/" ]]; then
    # If the directory already exists, remove it so it can be replaced
    rm -rf $BSVAR__BKDIR"Datastore Images/$ImageName/"
  fi
  mkdir $BSVAR__BKDIR"Datastore Images/$ImageName/"

  if [[ -d $BSVAR__Datastore_Directory ]]; then
    cp -R $BSVAR__Datastore_Directory $BSVAR__BKDIR"/Datastore Images/$ImageName/datastore"
  fi
}

dsRestore () {

  if [[ ${1} == "" ]]; then
    echo "Select an available image:"

    for dir in $BSVAR__BKDIR"Datastore Images/"*; do
      echo " $fg[green] >$reset_color "$(getBaseDir $dir)
    done
    return 0
  fi

  # Check to see whether Bigsky is currently running
  if [[ $BSVAR__Allow_Datastore_Imaging_When_Server_Running == false && $(isBigskyRunning) == true ]]; then
    echo "$fg[red]Error, cannot execute this function while BigSky server is running.$reset_color"
    return 10
  fi

  ImageName=${1}

  if [[ ! -d $BSVAR__BKDIR"Datastore Images/$ImageName/" ]]; then
    echo "Error, specified Backup image does not exist."
    return 11
  fi

  if [[ -d $BSVAR__Datastore_Directory ]]; then
    rm -rf $BSVAR__Datastore_Directory
  fi
  cp -R $BSVAR__BKDIR"Datastore Images/$ImageName/datastore/" $BSVAR__Datastore_Directory
}
# ==============================================================================


buildBSDeployPRForDVBranch() {
  local origin="timmccall-wf"
  local Ticket=$(echo ${1} | cut -d"_" -f1)  
  local branch="${Ticket}_DEPLOY"
  git branch $branch
  git checkout $branch
  updateBigskyWithDocviewerBranch $1
  perl -pi -w -e "s/ant ci-release/ant ci-test-release/g;" smithy.yml
  git commit -am "Deploy Only"
  git push origin $branch
  open "https://github.com/${origin}/bigsky/compare/master...${origin}:${branch}?expand=1"
}
