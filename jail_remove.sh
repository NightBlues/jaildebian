#!/bin/bash

if [ -d "jail_backup" ] ; then
	for user in `cat ./jail_backup/users` ; do userdel $user; done ;
	JAIL_DIR=`cat jail_backup/jail_dir` && rm -rf  $JAIL_DIR
	rm -f /bin/chroot-shell
	#cp ./jail_backup/sudoers /etc/sudoers
	rm -rf ./jail_backup/
else
	echo "no jail_backup dir found..."
fi
