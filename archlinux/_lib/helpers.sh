#!/bin/bash
# ------------------------------------------------------------------------
# archblocks - modular Arch Linux install script
# ------------------------------------------------------------------------
# blocks/lib/helpers.sh - common helper functions

# DEFAULTVALUE -----------------------------------------------------------
_defaultvalue ()
{
# Assign value to a variable in the install script only if unset.
# Note that *empty* variables that have purposefully been set as empty
# are not changed.
#
# usage:
#
# _defaultvalue VARNAME "value if VARNAME is currently unset or empty"
#
eval "${1}=\"${!1-${2}}\"";
}

# SETVALUE ---------------------------------------------------------------
_setvalue ()
{
# Assign a value to a "standard" bash format variable in a config file
# or script. For example, given a file with path "path/to/file.conf"
# with a variable defined like this:
#
# VARNAME=valuehere
#
# the value can be changed using this function:
#
# _setvalue newvalue VARNAME "path/to/file.conf"
#
valuename="$1" newvalue="$2" filepath="$3";
sed -i "s+^#\?\(${valuename}\)=.*$+\1=${newvalue}+" "${filepath}";
}

# COMMENTOUTVALUE --------------------------------------------------------
_commentoutvalue ()
{
# Comment out a value in "standard" bash format. For example, given a
# file with a variable defined like this:
#
# VARNAME=valuehere
#
# the value can be commented out to look like this:
#
# #VARNAME=valuehere
#
# using this function:
#
# _commentoutvalue VARNAME "path/to/file.conf"
#
valuename="$1" filepath="$2";
sed -i "s/^\(${valuename}.*\)$/#\1/" "${filepath}";
}

# UNCOMMENTVALUE ---------------------------------------------------------
_uncommentvalue ()
{
# Uncomment out a value in "standard" bash format. For example, given a
# file with a commented out variable defined like this:
#
# #VARNAME=valuehere
#
# the value can be UNcommented out to look like this:
#
# VARNAME=valuehere
#
# using this function:
#
# _uncommentoutvalue VARNAME "path/to/file.conf"
#
valuename="$1" filepath="$2";
sed -i "s/^#\(${valuename}.*\)$/\1/" "${filepath}";
}

# ADDTOLIST --------------------------------------------------------------
_addtolistvar ()
{
# Add to an existing list format variable (simple space delimited list)
# such as VARNAME="item1 item2 item3".
#
# Handles lists enclosed by either "quotes" or (parentheses)
#
# Usage (internal variable)
# _addtolist "new item" newitem newitem
#
if [ "$#" -lt 3 ]; then
newitem="$1" listname="$2"
eval "${listname}=\"${!listname} $newitem\""
else # add to list variable in an existing file
newitem="$1" listname="$2" filepath="$3";
sed -i "s_\(${listname}\s*=\s*[^)]*\))_\1 ${newitem})_" "${filepath}";
sed -i "s_\(${listname}\s*=\s*\"[^\"]*\)\"_\1 ${newitem}\"_" "${filepath}";
fi
}

# DAEMONS ADD/REMOVE -----------------------------------------------------
_daemon ()
{
# TODO: make work for systemd
# add|enable|change disable remove
#
# usage:
# daemon add @ntp
# daemon disable network
# daemon remove hwclock
# daemon remove hwclock network
#
! [ -e "/etc/rc.conf" ] && return 0
ACTION="$1"; shift; DAEMON_LIST="$@"
for DAEMON_ITEM in $DAEMON_LIST; do
DAEMON_BASE=$(echo "$DAEMON_ITEM" | sed "s/[!@]*\(.*\)/\1/") # strip any leading characters
case $ACTION in # assign DAEMON_NEW based on action
    add|change|enable|on) DAEMON_NEW="$DAEMON_ITEM" ;;
    disable|off) DAEMON_NEW="!${DAEMON_BASE}" ;; # normalize in case user passes !daemon format as argument
    remove|delete) DAEMON_NEW="" ;;
esac
echo -e "\nTEST: $ACTION $DAEMON_ITEM -> '$DAEMON_NEW'"
cat /etc/rc.conf | grep DAEMONS
# process /etc/rc.conf
if ! egrep -q "^DAEMONS\s*=.*[!@]?${DAEMON_BASE}" /etc/rc.conf; then # no daemon present
    [ $ACTION != remove ] && sed -i "/^\s*DAEMONS/ s_)_ ${DAEMON_NEW})_" /etc/rc.conf
else
    sed -i "/^\s*DAEMONS/ s_[!@]*${DAEMON_BASE}_${DAEMON_NEW}_" /etc/rc.conf
fi
# housekeeping: clean up extraneous spaces
sed -i "/^\s*DAEMONS/ \
s/  / /g
s/( /(/g
s/ )/)/g" /etc/rc.conf
done
}
# convenience functions
_daemon_add () { _daemon add $@ ; }
_daemon_enable () { _daemon enable $@ ; }
_daemon_change () { _daemon change $@ ; }
_daemon_on () { _daemon on $@ ; }
_daemon_disable () { _daemon disable $@ ; }
_daemon_off () { _daemon off $@ ; }
_daemon_remove () { _daemon remove $@ ; }
_daemon_delete () { _daemon delete $@ ; }

# ANYKEY -----------------------------------------------------------------
_anykey ()
{
# Provide an alert (with optional custom preliminary message) and pause.
#
# Usage:
# _anykey "optional custom message"
#
echo -e "\n$@"; read -sn 1 -p "Any key to continue..."; echo;
}


# INSTALLPKG -------------------------------------------------------------
_installpkg ()
{
# Install package(s) from official repositories, no confirmation needed.
# Takes single or multiple package names as arguments.
#
# Usage:
# _installpkg pkgname1 [pkgname2] [pkgname3]
#
pacman -S --noconfirm "$@";
}

# INSTALLAUR -------------------------------------------------------------
_installaur ()
{
# Install package(s) from arch user repository, no confirmation needed.
# Takes single or multiple package names as arguments.
#
# Installs default helper first ($AURHELPER)
#
# Usage:
# _installpkg pkgname1 [pkgname2] [pkgname3]
#
_defaultvalue AURHELPER packer
if command -v $AURHELPER >/dev/null 2>&1; then
    $AURHELPER -S --noconfirm "$@";
else
    pkg=$AURHELPER; orig="$(pwd)"; build_dir=/tmp/build/${pkg}; mkdir -p $build_dir; cd $build_dir;
    for req in wget git jshon; do
        command -v $req >/dev/null 2>&1 || _installpkg $req;
    done
    wget "https://aur.archlinux.org/packages/${pkg:0:2}/${pkg}/${pkg}.tar.gz";
    tar -xzvf ${pkg}.tar.gz; cd ${pkg};
    makepkg --asroot -si --noconfirm; cd "$orig"; rm -rf $build_dir;
    $AURHELPER -S --noconfirm "$@";
fi;
}

# CHROOT POSTSCRIPT ------------------------------------------------------
_chroot_postscript ()
{
# handle interactively assigned install drive value
echo -e "#!/bin/bash\nINSTALL_DRIVE=$INSTALL_DRIVE" > "${MNT}${POSTSCRIPT}";
grep -v "^\s*INSTALL_DRIVE.*" "${0}" >> "${MNT}${POSTSCRIPT}";
#cp "${0}" "${MNT}${POSTSCRIPT}";
chmod a+x "${MNT}${POSTSCRIPT}"; arch-chroot "${MNT}" "${POSTSCRIPT}";
}


# POST INSTALL MESSAGES --------------------------------------------------
_display_postinstall_messages ()
{
echo "\n\nInstallation complete; Reboot and then execute the post-reboot.sh script in the /root directory."
echo "\n"
[ -n "${POSTINSTALL_MSGS:-}" ] && echo "${POSTINSTALL_MSGS}"
}
_add_postinstall_messags ()
{
:
}

# LOAD BLOCK -------------------------------------------------------------
_loadblock ()
{
[ -z "$@" ] && return
for _block in $@; do
isurl=false ispath=false isrootpath=false;
case "$_block" in
    *://*) isurl=true ;;
    /*)    isrootpath=true ;;
    */*)   ispath=true ;;
esac
FILE="${_block/%.sh/}.sh";
if $isurl; then URL="${FILE}";
elif [ -f "${DIR/%\//}/${FILE}" ]; then URL="file://${FILE}";
else URL="${REMOTE/%\//}/archlinux/${FILE}"; fi

_loaded_block="$(curl -fsL ${URL})";

#set +e
[ -n "$_loaded_block" ] && eval "${_loaded_block}";
if [ "$?" -gt 0 ]; then
_anykey "EXECUTION OF BLOCK \"$_block\" EXPERIENCED ERRORS"
fi
#set -e
done
} 



# LOAD EFIVARS MODULE ----------------------------------------------------
_load_efi_modules ()
{
# Load efivars (or confirm they've loaded already) and set EFI_MODE for
# later use by bootloader.
#
modprobe efivars || true;
ls -l /sys/firmware/efi/vars/ &>/dev/null && return 0 || return 1;
}

# GET UUID ON DRIVE/PARTITION --------------------------------------------
_get_uuid ()
{
# usage:
# _get_uuid /dev/sda3
MATCH="$(echo "$1" | sed "s_/_\\\/_g")"
blkid -c /dev/null | sed -n "/${MATCH}/ s_.*UUID=\"\([^\"]*\).*_\1_p"
}

_install_mirrorlist ()
{
curl -fsL "${REMOTE}/archlinux/pre/mirrorlist.txt" -o /etc/pacman.d/mirrorlist
}

# ENABLE REPOSITORIES FOR SPECIFIC LANGUAGES/FRAMEWORKS ------------------
_enable_haskell_repos ()
{

# add repos to /etc/pacman.conf

#egrep -q "^\[haskell-testing\]" /etc/pacman.conf || \
#sed -i '/^\[core\]/i \
#[haskell-testing]\
#Server = http://www.kiwilight.com/haskell/testing/$arch\
#' /etc/pacman.conf

egrep -q "^\[haskell-extra\]" /etc/pacman.conf || \
sed -i '/^\[core\]/i \
[haskell-extra]\
Server = http://archhaskell.mynerdside.com/$repo/$arch\
' /etc/pacman.conf

egrep -q "^\[haskell\]" /etc/pacman.conf || \
sed -i '/^\[core\]/i \
[haskell]\
Server = http://xsounds.org/~haskell/$arch\
' /etc/pacman.conf

# update new repos

pacman --noconfirm -Sy

}

# INIT/SYSTEMD FUNCTIONS -------------------------------------------------

# return true if INIT_MODE is systemd (this is the INIT_MODE default)
_systemd () { [ "$INIT_MODE" == "systemd" ] && return 0 || return 1; }

# MISC FUNCTIONS ---------------------------------------------------------

_setfont () { setfont $FONT; }

# NULL FUNCTIONS (OVERRIDDEN BY EPONYMOUS BLOCKS)-------------------------
_filesystem_pre_baseinstall () { :; }
_filesystem_post_baseinstall () { :; }
_filesystem_pre_chroot () { :; }
_filesystem_post_chroot () { :; }





# CLEANUP BELOW:

#PRIMARY_BOOTLOADER="$(echo "$PRIMARY_BOOTLOADER" | tr [:lower:] [:upper:])";
#[ "${PRIMARY_BOOTLOADER#U}" == "EFI" ] && _load_efi_modules && EFI_MODE=true || EFI_MODE=false


#TODO: should add a first-run (first call to function for each phase) check and initialization phase