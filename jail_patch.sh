#!/bin/bash

if ! [ -z $1 ] ; then 
	PATCH_FILE=$1
else
	echo "You must specify patchfile..."
	exit 1
fi
JAIL_DIR=`cat jail_backup/jail_dir`

function copy_to_jail {
	file=$1
	if [ -f $file ] ; then 
		# регуляркой отрезаем имя файла от пути (любые символы отличные от / в конце строки )
		#PARENT_DIR=` echo $file | sed 's/[^\/]*$//g'`
		PARENT_DIR=`dirname $file`
		echo -e "\tCreating directory $JAIL_DIR/$PARENT_DIR"
		mkdir -p "$JAIL_DIR/$PARENT_DIR"
		echo -e "\tCopying file $file"
		#if ! [ -e "$JAIL_DIR/$file" ] ; then
			cp "$file" "$JAIL_DIR/$file"
		#else 
		#	echo "ERR: Destination file $JAIL_DIR/$file already exists"
		#fi
	elif [ -d $file ] ; then
		# регуляркой отрезаем имя файла от пути (любые символы отличные от / в конце строки )
		#PARENT_DIR=` echo $file | sed 's/[^\/]*$//g'`
		PARENT_DIR=`dirname $file`
		echo -e "\tCreating directory $JAIL_DIR/$PARENT_DIR"
		mkdir -p "$JAIL_DIR/$PARENT_DIR"
		echo -e "\tCopying directory $file "
		cp -r "$file" "$JAIL_DIR/$file"
	else
		echo "ERR: File $file does not exist"
	fi
}
# magic...%) сначала игнорируем все строки с каментами, фильтуем все строки начинающиеся с app, потом с dir, потом регуляркой грохаем слово fil в начале
files=`cat $PATCH_FILE|sed '/#/ c\'|sed '/app/ c\'|sed '/dir/ c\'|sed 's/fil //'`
# аналогично
dirs=`cat $PATCH_FILE|sed '/#/ c\'|sed '/app/ c\'|sed '/fil/ c\'|sed 's/dir //'`
apps=`cat $PATCH_FILE|sed '/#/ c\'|sed '/dir/ c\'|sed '/fil/ c\'|sed 's/app //'`
echo "Copying files..."
for file in $files ;  do
	copy_to_jail $file
done 
echo "Copying directories..."
for dir in $dirs ;  do
	copy_to_jail $dir
done 
echo "Copying applications..."
for app in $apps ;  do
	echo "Adding application $app"
	copy_to_jail $app
	cp -r "$app" "$JAIL_DIR/$app"
	echo -e "\tAdding necessary libraries"
	for lib in `ldd $app` ; do
		if [ `echo $lib | cut -c1` = "/" ] ; then
			copy_to_jail $lib
		fi
	done
done 
