#!/bin/bash

#set -x
WIN_ROON_DIR=my_roon_instance
ROON_DOWNLOAD=http://download.roonlabs.com/builds/RoonInstaller64.exe
WINETRICKS_DOWNLOAD=https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
WINE_PLATFORM="win64"
test "$WINE_PLATFORM" = "win32" && ROON_DOWNLOAD=http://download.roonlabs.com/builds/RoonInstaller.exe
VERBOSE=1

PREFIX="$HOME/$WIN_ROON_DIR"


# Set according to your display characteristics
SCALEFACTOR="no"   # set to "yes" to scale display and modify SET_SCALEFACTOR
SET_SCALEFACTOR="2"

START_SCRIPT="start_my_roon_instance.sh"


# solve directory path for most use cases (not all)
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
/bin/echo "Using $SCRIPT_DIR as the build directory"
cd $SCRIPT_DIR



# check for a "-u" flag for Ubuntu 22.04 LTS
while getopts ":u" OPT; do
  case $OPT in
    u)
      /bin/echo "The -u option creates a desktop shortcut for Ubuntu." >&2
      UBUNTU="yes"
      /usr/bin/sleep 1
      ;;
    \?)
      /bin/echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done


_check_for_executable()
{
   local exe=$1

   if ! type $exe >/dev/null 2>&1
   then
      echo "ERROR: can't find $exe, which is required for Roon installation."
      echo "Please install $exe using your distribution package tooling."
      echo
      exit 1

   fi
}

_winetricks()
{
   comment="$1"
   shift
   echo "[${WINE_PLATFORM}|${PREFIX}] $comment ..."
   if [ $VERBOSE -eq 1 ]
   then
      env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX ./winetricks "$@"
   else
      env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX ./winetricks "$@" >/dev/null 2>&1
   fi

   sleep 2
}

_wine()
{
   comment="$1"
   shift
   echo "[${WINE_PLATFORM}|${PREFIX}] $comment ..."
   if [ $VERBOSE -eq 1 ]
   then
      #env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX wine "$@"
      env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX WINEDLLOVERRIDES=winemenubuilder.exe=d wine "$@"
   else
      #env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX wine "$@" >/dev/null 2>&1
      env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX WINEDLLOVERRIDES=winemenubuilder.exe=d wine "$@" >/dev/null 2>&1
   fi

   sleep 2
}



# download winetricks
rm -f ./winetricks
wget $WINETRICKS_DOWNLOAD
chmod +x ./winetricks

# check necessary stuff
_check_for_executable wine
_check_for_executable winecfg
_check_for_executable ./winetricks
_check_for_executable wget

# configure Wine
rm -rf $HOME/$WIN_ROON_DIR
_wine "Setup Wine bottle" wineboot --init

# installing .NET needs to be done in a few steps; if we do this at once it fails on a few systems

#_winetricks "Installing .NET 2.0"   -q dotnet20
#_winetricks "Installing .NET 3.0"   -q dotnet30sp1
#_winetricks "Installing .NET 3.5"   -q dotnet35
_winetricks "Installing .NET 4.0"    -q --force dotnet40
#_winetricks "Installing .NET 4.5"    -q --force dotnet45
#_winetricks "Installing .NET 4.5.2"  -q --force dotnet452
#_winetricks "Installing .NET 4.6.2" -q dotnet462
#_winetricks "Installing .NET 4.7.2" -q dotnet472
#_winetricks "Installing .NET 4.8" -q dotnet48

# setting some environment stuff
_winetricks "Setting Windows version to 7" -q win7
_winetricks "Setting DDR to OpenGL"        -q ddr=opengl
_winetricks "Disabling crash dialog"       -q nocrashdialog

rm -f ./NDP472-KB4054530-x86-x64-AllOS-ENU.exe
# wget 'https://download.microsoft.com/download/6/E/4/6E48E8AB-DC00-419E-9704-06DD46E5F81D/NDP472-KB4054530-x86-x64-AllOS-ENU.exe'
wget 'https://download.visualstudio.microsoft.com/download/pr/1f5af042-d0e4-4002-9c59-9ba66bcf15f6/089f837de42708daacaae7c04b7494db/ndp472-kb4054530-x86-x64-allos-enu.exe' -O ./NDP472-KB4054530-x86-x64-AllOS-ENU.exe
_wine "Installing .NET..." ./NDP472-KB4054530-x86-x64-AllOS-ENU.exe /q

sleep 2

# download Roon
rm -rf $ROON_DOWNLOAD
test -f $( basename $ROON_DOWNLOAD ) || wget $ROON_DOWNLOAD

# install Roon
_wine "Installing Roon" $( basename $ROON_DOWNLOAD  )





#######################################################################################
##
## This section for creating the start script
##


# default Roon executable location (update if the default should change for most use cases)
ROON_EXE_DEFAULT="$PREFIX/drive_c/users/$USER/AppData/Local/Roon/Application/Roon.exe"

# Ubuntu 22.04 LTS with default Wine 6.0.3 as at 2022-07-31
ROON_EXE_BAK="$PREFIX/drive_c/users/$USER/Local Settings/Application Data/Roon/Application/Roon.exe"

# Alternative Roon.exe location. Change this to a known value if needed if the two options above don't apply.
ROON_EXE_ALT="$PREFIX/drive_c/users/$USER/CHANGE-PATH-AS-REQUIRED-HERE"


# Check for Roon.exe file
if [ -f "$ROON_EXE_DEFAULT" ]; then
   /bin/echo "Setting Roon.exe location to: $ROON_EXE_DEFAULT"
   /bin/echo ""
   ROON_EXE="$ROON_EXE_DEFAULT"
elif [ -f "$ROON_EXE_BAK" ]; then
   /bin/echo "Setting Roon.exe location to: $ROON_EXE_BAK"
   /bin/echo ""
   ROON_EXE="$ROON_EXE_BAK"
else
   /bin/echo "Path to the Roon executable will need to be corrected!"
   /bin/echo "Edit ./start_my_roon_instance.sh or ~/start_my_roon"
   ROON_EXE="$ROON_EXE_ALT"
fi


cat << _EOF_ > $SCRIPT_DIR/$START_SCRIPT
#!/bin/bash
# v. 2022-08-06

# change these values as desired
SCALEFACTOR=$SCALEFACTOR         # "yes" or "no"
SET_SCALEFACTOR=$SET_SCALEFACTOR # usually "2", if set to yes

# default is "~/$WIN_ROON_DIR"
PREFIX=$PREFIX



# check for file first (if this fails, this will need to be corrected manually)
if [ -f "$ROON_EXE" ]; then
   if [ \$SCALEFACTOR == "yes" ]; then
      # default with scale factor
      env WINEPREFIX="$PREFIX" wine "$ROON_EXE" -scalefactor="$SET_SCALEFACTOR"
         if [ \$? -eq 0 ]; then
            /bin/echo "Ran: env WINEPREFIX=$PREFIX wine $ROON_EXE -scalefactor=2"
         else
            /bin/echo "Failed: env WINEPREFIX=$PREFIX wine $ROON_EXE -scalefactor=2"
            /bin/echo "Error starting Roon: " \$?
            /bin/echo ""
         fi
   else
      # no scale factor
      env WINEPREFIX="$PREFIX" wine "$ROON_EXE"
         if [ \$? -eq 0 ]; then
             /bin/echo "Ran: env WINEPREFIX=$PREFIX wine $ROON_EXE"
         else
            /bin/echo "Failed: env WINEPREFIX=$PREFIX wine $ROON_EXE"
            /bin/echo "Error starting Roon: " \$?
            /bin/echo ""
         fi
   fi
else
   /bin/echo "Something is wrong, as the Roon executable is missing"
   /bin/echo "Error code: " \$?
   exit;
fi

_EOF_

## end start script
##
#######################################################################################


# copy icons locally
/usr/bin/cp $SCRIPT_DIR/icons/16x16/roon-on-wine.png ${HOME}/.local/share/icons/hicolor/16x16/apps/0369_Roon.0.png
/usr/bin/cp $SCRIPT_DIR/icons/32x32/roon-on-wine.png ${HOME}/.local/share/icons/hicolor/32x32/apps/0369_Roon.0.png
/usr/bin/cp $SCRIPT_DIR/icons/48x48/roon-on-wine.png ${HOME}/.local/share/icons/hicolor/48x48/apps/0369_Roon.0.png
/usr/bin/cp $SCRIPT_DIR/icons/256x256/roon-on-wine.png ${HOME}/.local/share/icons/hicolor/256x256/apps/0369_Roon.0.png


if [ $UBUNTU != "yes" ]; then

# default setup
# create XDG stuff
cat << _EOF2_ > ${HOME}/.local/share/applications/roon-on-wine.desktop
[Desktop Entry]
Name=Roon
Exec=${HOME}/${START_SCRIPT}
Terminal=false
Type=Application
StartupNotify=true
Icon=0369_Roon.0
StartupWMClass=roon.exe
_EOF2_

   # refresh XDG stuff
   update-desktop-database ~/.local/share/applications
   gtk-update-icon-cache

else

# for Ubuntu 22.04 LTS
/bin/echo "Setting up desktop icon"
cat << _EOF3_ > ~/Desktop/Roon.desktop
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Exec=${HOME}/${START_SCRIPT}
Name=Roon
Comment=Roon
Icon=${HOME}/.local/share/icons/hicolor/256x256/apps/0369_Roon.0.png
Hidden=false
Categories=Audio
_EOF3_

   if [ -f  ~/Desktop/Roon.desktop ]; then
      gio set ~/Desktop/Roon.desktop metadata::trusted true
      chmod a+x ~/Desktop/Roon.desktop
      # hardcoded removal
      rm ~/Desktop/Roon.lnk
      fi
fi


chmod +x $SCRIPT_DIR/$START_SCRIPT
cp $SCRIPT_DIR/$START_SCRIPT ~


exit 0
