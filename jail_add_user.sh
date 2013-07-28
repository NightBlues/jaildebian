#!/bin/bash

# Get accountname to create / move
if [ -z "$1" ] ; then
  echo
  echo "ERROR: Parameter missing. Did you forget the username?"
  echo 
  exit
fi
if [ ! -d "./jail_backup/" ] ; then
	echo "No jail_backup found...";
	exit 1;
fi
CHROOT_USERNAME=$1
CHROOT_GROUP=`cat jail_backup/group`
SHELL="/bin/bash"
JAILPATH=`cat jail_backup/jail_dir`
HOMEDIR="$JAILPATH/home/$CHROOT_USERNAME"
echo "Adding User \"$CHROOT_USERNAME\" to system"
useradd -m -d "/home/$CHROOT_USERNAME" -s "$SHELL" -g "$CHROOT_GROUP" $CHROOT_USERNAME 
mv "/home/$CHROOT_USERNAME" ${HOMEDIR}
chmod 700 "$HOMEDIR"
if !(passwd $CHROOT_USERNAME);
	then echo "Passwords are probably not the same, try again."
	exit 1;
fi
echo "alias ls='ls -la --color'" >> ${HOMEDIR}/.bashrc
echo "Adding User $CHROOT_USERNAME to jail"
grep -e "^$CHROOT_USERNAME:" /etc/passwd | \
 sed -e "s#$JAILPATH##"      \
     -e "s#$SHELL#/bin/bash#"  >> ${JAILPATH}/etc/passwd
grep -e "^$CHROOT_USERNAME:" /etc/shadow >> ${JAILPATH}/etc/shadow
chmod 600 ${JAILPATH}/etc/shadow
mkdir jail_backup >/dev/null 2>&1
if [ ! -f "./jail_backup/users" ] ; then
	touch ./jail_backup/users
fi
echo $CHROOT_USERNAME >> ./jail_backup/users
