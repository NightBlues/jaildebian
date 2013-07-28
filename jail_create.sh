#!/bin/bash

RELEASE="2012-09-03"


CHROOT_GROUP="developers"
groupadd -f "$CHROOT_GROUP"

mkdir jail_backup >/dev/null 2>&1
if [ ! -f "./jail_backup/sudoers" ] ; then
 cp /etc/sudoers jail_backup/.
fi
if [ ! -f "./jail_backup/users" ] ; then
	touch ./jail_backup/users
fi
echo $CHROOT_GROUP > jail_backup/group


# path to sshd's config file: needed for automatic detection of the locaten of
# the sftp-server binary
SSHD_CONFIG="/etc/ssh/sshd_config"


echo "This version may be used only for Debian/Squeeze"


if [ -z "$PATH" ] ; then 
  PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin
fi

echo
echo Release: $RELEASE
echo

echo "Am I root?  "
if [ "$(whoami &2>/dev/null)" != "root" ] && [ "$(id -un &2>/dev/null)" != "root" ] ; then
  echo "  NO!

Error: You must be root to run this script."
  exit 1
fi
echo "  OK";

# Specify the apps you want to copy to the jail
  APPS="/bin/bash /bin/cp /usr/bin/dircolors /bin/ls /bin/cat /bin/mkdir /bin/mv /bin/rm /bin/rmdir /bin/sh /bin/su /usr/bin/groups /usr/bin/id /usr/bin/rsync /usr/bin/ssh /usr/bin/scp /sbin/unix_chkpwd /usr/bin/git /usr/bin/mysql /usr/bin/php5 /bin/grep /bin/more /usr/bin/mc /bin/touch /usr/bin/whoami /usr/bin/whereis /usr/bin/whatis /bin/nano /usr/bin/nano /usr/bin/wget /usr/sbin/locale-gen /usr/bin/locale"


# Check existence of necessary files
echo "Checking for which... " 
#if [ -f $(which which) ] ;
# not good because if which does not exist I look for an 
# empty filename and get OK nevertheless
if ( test -f /usr/bin/which ) || ( test -f /bin/which ) || ( test -f /sbin/which ) || ( test -f /usr/sbin/which );
  then echo "  OK";
  else echo "  failed

Please install which-binary!
"
exit 1
fi

echo "Checking for chroot..." 
if [ `which chroot` ];
  then echo "  OK";
  else echo "  failed

chroot not found!
Please install chroot-package/binary!
"
exit 1
fi

echo "Checking for sudo..." 
if [ `which sudo` ]; then
  echo "  OK";
else 
  echo "  failed

sudo not found!
Please install sudo-package/binary!
"
exit 1
fi

echo "Checking for dirname..." 
if [ `which dirname` ]; then
  echo "  OK";
else 
  echo "  failed

dirname not found!
Please install dirname-binary (to be found eg in the package coreutils)!
"
exit 1
fi

echo "Checking for awk..." 
if [ `which awk` ]; then
  echo "  OK
";
else 
  echo "  failed

awk not found!
Please install (g)awk-package/binary!
"
exit 1
fi

# get location of sftp-server binary from /etc/ssh/sshd_config
# check for existence of /etc/ssh/sshd_config and for
# (uncommented) line with sftp-server filename. If neither exists, just skip
# this step and continue without sftp-server
#
#if  (test ! -f /etc/ssh/sshd_config &> /dev/null); then
#  echo "
#File /etc/ssh/sshd_config not found.
#Not checking for path to sftp-server.
#  ";
#else
if [ ! -f ${SSHD_CONFIG} ]
then
   echo "File ${SSHD_CONFIG} not found."
   echo "Not checking for path to sftp-server."
   echo "Please adjust the global \$SSHD_CONFIG variable"
else
  if !(grep -v "^#" ${SSHD_CONFIG} | grep -i sftp-server &> /dev/null); then
    echo "Obviously no sftp-server is running on this system.
";
  else SFTP_SERVER=$(grep -v "^#" ${SSHD_CONFIG} | grep -i sftp-server | awk  '{ print $3}')
  fi
fi

#if !(grep -v "^#" /etc/ssh/sshd_config | grep -i sftp-server /etc/ssh/sshd_config | awk  '{ print $3}' &> /dev/null); then
APPS="$APPS $SFTP_SERVER"


SHELL="/bin/chroot-shell"

if ! [ -z "$1" ] ; then
  JAILPATH=$1
else
  JAILPATH="/var/www/jail"
fi

echo $JAILPATH > jail_backup/jail_dir


# Create $SHELL (shell for jailed accounts)
if [ -f ${SHELL} ] ; then
  echo "
-----------------------------
The file $SHELL exists. 
Probably it was created by this script.

Are you sure you want to overwrite it?
(you want to say yes for example if you are running the script for the second
time when adding more than one account to the jail)"
read -p "(yes/no) -> " OVERWRITE
if [ "$OVERWRITE" != "yes" ]; then
  echo "
Not entered yes. Exiting...."
  exit 1
fi
else
  echo "Creating $SHELL"
  echo '#!/bin/sh' > $SHELL
  echo "`which sudo` `which chroot` $JAILPATH /bin/su - \$USER" \"\$@\" >> $SHELL
  chmod 755 $SHELL
fi

# make common jail for everybody if inexistent
if [ ! -d ${JAILPATH} ] ; then
  mkdir -p ${JAILPATH}
  echo "Creating ${JAILPATH}"
fi
cd ${JAILPATH}

# Create directories in jail that do not exist yet
JAILDIRS="dev etc etc/pam.d bin home sbin usr usr/bin usr/lib var var/run tmp"
for directory in $JAILDIRS ; do
  if [ ! -d "$JAILPATH/$directory" ] ; then
    mkdir $JAILPATH/"$directory"
    echo "Creating $JAILPATH/$directory"
  fi
done
chmod 777 tmp
chmod +t tmp
mkdir var/run/mysqld
chmod 777 var/run/mysqld
echo

# Comment in the following lines if your apache can't read the directories and
# uses the security contexts
# Fix security contexts so Apache can read files
#CHCON=$(`which chcon`)
#if [ -n "$CHCON" ] && [ -x $CHCON ]; then
#    $CHCON -t home_root_t $JAILPATH/home
#    $CHCON -t user_home_dir_t $JAILPATH/home/$CHROOT_USERNAME
#fi

# Creating necessary devices
[ -r $JAILPATH/dev/urandom ] || mknod $JAILPATH/dev/urandom c 1 9
[ -r $JAILPATH/dev/null ]    || mknod -m 666 $JAILPATH/dev/null    c 1 3
[ -r $JAILPATH/dev/zero ]    || mknod -m 666 $JAILPATH/dev/zero    c 1 5
[ -r $JAILPATH/dev/tty ]     || mknod -m 666 $JAILPATH/dev/tty     c 5 0 



# Modifiy /etc/sudoers to enable chroot-ing for users
# must be removed by hand if account is deleted
#echo "Modifying /etc/sudoers"
#echo "$CHROOT_USERNAME       ALL=NOPASSWD: `which chroot`, /bin/su - $CHROOT_USERNAME" >> /etc/sudoers

# Create /usr/bin/groups in the jail
echo "#!/bin/bash" > usr/bin/groups
echo "id -Gn" >> usr/bin/groups
chmod 755 usr/bin/groups

# Add users to etc/passwd
#
# check if file exists (ie we are not called for the first time)
# if yes skip root's entry and do not overwrite the file
	if [ ! -f etc/passwd ] ; then
	 grep /etc/passwd -e "^root" > ${JAILPATH}/etc/passwd
	fi
	if [ ! -f etc/group ] ; then
	 grep /etc/group -e "^root" > ${JAILPATH}/etc/group
	# add the group for all users to etc/group (otherwise there is a nasty error
	# message and probably because of that changing directories doesn't work with
	# winSCP)
	 grep /etc/group -e "^users" >> ${JAILPATH}/etc/group
	fi


# Copy the apps and the related libs
echo "Copying necessary library-files to jail (may take some time)"

# The original code worked fine on RedHat 7.3, but did not on FC3.
# On FC3, when the 'ldd' is done, there is a 'linux-gate.so.1' that 
# points to nothing (or a 90xb.....), and it also does not pick up
# some files that start with a '/'. To fix this, I am doing the ldd
# to a file called ldlist, then going back into the file and pulling
# out the libs that start with '/'
# 
# Randy K.
#
# The original code worked fine on 2.4 kernel systems. Kernel 2.6
# introduced an internal library called 'linux-gate.so.1'. This 
# 'phantom' library caused non-critical errors to display during the 
# copy since the file does not actually exist on the file system. 
# To fix re-direct output of ldd to a file, parse the file and get 
# library files that start with /
#

# create temporary files with mktemp, if that doesn't work for some reason use
# the old method with $HOME/ldlist[2] (so I don't have to check the existence
# of the mktemp package / binary at the beginning
#
TMPFILE1=`mktemp` &> /dev/null ||  TMPFILE1="${HOME}/ldlist"; if [ -x ${TMPFILE1} ]; then mv ${TMPFILE1} ${TMPFILE1}.bak;fi
TMPFILE2=`mktemp` &> /dev/null ||  TMPFILE2="${HOME}/ldlist2"; if [ -x ${TMPFILE2} ]; then mv ${TMPFILE2} ${TMPFILE2}.bak;fi

for app in $APPS;  do
    # First of all, check that this application exists
    if [ -x $app ]; then
        # Check that the directory exists; create it if not.
#        app_path=`echo $app | sed -e 's#\(.\+\)/[^/]\+#\1#'`
        app_path=`dirname $app`
        if ! [ -d .$app_path ]; then
            mkdir -p .$app_path
        fi

		# If the files in the chroot are on the same file system as the
		# original files you should be able to use hard links instead of
		# copying the files, too. Symbolic links cannot be used, because the
		# original files are outside the chroot.
		cp -p $app .$app

        # get list of necessary libraries
        ldd $app >> ${TMPFILE1}
    fi
done

# Clear out any old temporary file before we start
for libs in `cat ${TMPFILE1}`; do
   frst_char="`echo $libs | cut -c1`"
   if [ "$frst_char" = "/" ]; then
     echo "$libs" >> ${TMPFILE2}
   fi
done
for lib in `cat ${TMPFILE2}`; do
    mkdir -p .`dirname $lib` > /dev/null 2>&1

	# If the files in the chroot are on the same file system as the original
	# files you should be able to use hard links instead of copying the files,
	# too. Symbolic links cannot be used, because the original files are
	# outside the chroot.
    cp $lib .$lib
done

#
# Now, cleanup the 2 files we created for the library list
#
#/bin/rm -f ${HOME}/ldlist
#/bin/rm -f ${HOME}/ldlist2
/bin/rm -f ${TMPFILE1}
/bin/rm -f ${TMPFILE2}

# Necessary files that are not listed by ldd.
#
# There might be errors because of files that do not exist but in the end it
# may work nevertheless (I added new file names at the end without deleting old
# ones for reasons of backward compatibility).
# So please test ssh/scp before reporting a bug.
cp /lib/libnss_compat.so.2 /lib/libnsl.so.1 /lib/libnss_files.so.2 /lib/libcap.so.2 /lib/libnss_dns.so.2 ${JAILPATH}/lib/


# if you are using a 64 bit system and have strange problems with login comment
# the following lines in, perhaps it works then (motto: if you can't find the
# needed library just copy all of them)
#
#cp /lib/*.* ${JAILPATH}/lib/
#cp /lib/lib64/*.* ${JAILPATH}/lib/lib64/ 

# if you are using PAM you need stuff from /etc/pam.d/ in the jail,
echo "Copying files from /etc/pam.d/ to jail"
cp /etc/pam.d/* ${JAILPATH}/etc/pam.d/

# ...and of course the PAM-modules...
echo "Copying PAM-Modules to jail"
cp -r /lib/security ${JAILPATH}/lib/

# ...and something else useful for PAM
cp -r /etc/security ${JAILPATH}/etc/
cp /etc/login.defs ${JAILPATH}/etc/

if [ -f /etc/DIR_COLORS ] ; then
  cp /etc/DIR_COLORS ${JAILPATH}/etc/
fi 

# make git work
mkdir -p ${JAILPATH}/usr/share/
cp -r /usr/share/git-core ${JAILPATH}/usr/share/git-core


cp -r /etc/mc ${JAILPATH}/etc/mc
cp -r /usr/lib/mc ${JAILPATH}/usr/lib/mc
cp -r /usr/share/mc ${JAILPATH}/usr/share/mc


ln -s /var/run/mysqld/mysqld.pid ${JAILPATH}/var/run/mysqld/mysqld.pid
ln -s /var/run/mysqld/mysqld.sock ${JAILPATH}/var/run/mysqld/mysqld.sock
# make mc and nano work...
mkdir -p ${JAILPATH}/lib/terminfo/
cp -r /lib/terminfo/* ${JAILPATH}/lib/terminfo/.


# locale
mkdir -p ${JAILPATH}/usr/share/locale/ru/
mkdir ${JAILPATH}/etc/default/
cp /etc/locale.gen  ${JAILPATH}/etc/locale.gen
cp /etc/default/locale ${JAILPATH}/etc/default/locale
cp -r /usr/share/locale/ru/*  ${JAILPATH}/usr/share/locale/ru/.

cat /etc/hosts > ${JAILPATH}/etc/hosts
# Don't give more permissions than necessary
chown root.root ${JAILPATH}/bin/su
chmod 700 ${JAILPATH}/bin/su

exit

