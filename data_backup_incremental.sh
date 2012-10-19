#!/bin/bash

BACKUP_DRIVE=/dev/md0
BACKUP_DIR=/mnt/md0/backup
BACKUP_DIR_PREFIX="backuped_on_"
LOG_FILE="/var/log/rsync.log"
MYSQL_PW=""
DISK_CAPA=50
BACKUP_DIRS=("/home/" "/etc/" "/usr/local/bin/")
BACKUP_EXCLUDES=("" "" "")
BACKUP_TO=("/home/" "/etc/" "/bin/")



echo -e "\n===============================" >> ${LOG_FILE}
date >> ${LOG_FILE}

#現在存在するバックアップフォルダを読み込み
I=0
cd ${BACKUP_DIR}
for DIR in $(ls -rd -1 ${BACKUP_DIR_PREFIX}*)
do
	DIRS[${I}]=${DIR}
	I=$(( ${I} + 1 ))
done

LAST_BACKUP_DIR=${DIRS[0]}
echo "remain "`df | grep ${BACKUP_DRIVE} | tr -s ' ' ' ' | cut -f4 -d' '` >> ${LOG_FILE}

LINK_DST="--link-dest=../../${LAST_BACKUP_DIR}"
if [ -z "${LAST_BACKUP_DIR}" ];
then
	LINK_DST=""
else
	#空き容量が一定以上になるまで過去の世代から消していく
	#全部消えちゃう・・・
	for dir in $(ls -d -1 ${BACKUP_DIR_PREFIX}*)
	do
		echo `df | grep ${BACKUP_DRIVE} | tr -s ' ' ' ' | cut -f4 -d' '`"<->"`echo "${DISK_CAPA} * 2^20" | bc` >> ${LOG_FILE}
		if [ `df | grep ${BACKUP_DRIVE} | tr -s ' ' ' ' | cut -f4 -d' '` -gt `echo "${DISK_CAPA} * 2^20" | bc` ];
		then
			break;
		fi
		echo "!!!---Remove Directory : \""${dir}"\" ---!!!" >> ${LOG_FILE}
		rm -rf ${dir}
	done
fi

#今回バックアップ先となるディレクトリを作成
BACKUP_DIR_CURRENT=${BACKUP_DIR}/${BACKUP_DIR_PREFIX}`date +"%Y_%m_%d"`
mkdir ${BACKUP_DIR_CURRENT}

for (( I = 0; I < ${#BACKUP_DIRS[@]}; ++I ))
do
	OPT_EXCS="--exclude-from ${BACKUP_EXCLUDES[$I]}"
	if [ -z "${BACKUP_EXCLUDES[$I]}" ];then
		OPT_EXCS=""
	fi
	OPT_LD=${LINK_DST}${BACKUP_TO[$I]}
	if [ -z "${LINK_DST}" ];then
		OPT_LD=""
	fi
	env LANG=ja_JP.UTF-8 rsync -va --delete ${OPT_EXCS} ${OPT_LD} "${BACKUP_DIRS[$I]}" "${BACKUP_DIR_CURRENT}${BACKUP_TO[$I]}" >> ${LOG_FILE} 2>&1
done

#mysqlのバックアップ
mkdir ${BACKUP_DIR_CURRENT}/mysql
mysqldump -u root -p${MYSQL_PW} -x --all-databases > ${BACKUP_DIR_CURRENT}/mysql/all.sql

#インストール済みのdebパッケージのリストのバックアップ
dpkg --get-selections > ${BACKUP_DIR_CURRENT}/package_list.txt

#cronのリストをバックアップ
crontab -l > ${BACKUP_DIR_CURRENT}/crontab_-l.txt

if [ -n ${LINK_DST} ];
then
	#空き容量が一定以上になるまで過去の世代から消していく
	#全部消えちゃう・・・
	for dir in $(ls -d -1 ${BACKUP_DIR_PREFIX}*)
	do
		echo `df | grep ${BACKUP_DRIVE} | tr -s ' ' ' ' | cut -f4 -d' '`"<->"`echo "${DISK_CAPA} * 2^20" | bc` >> ${LOG_FILE}
		if [ `df | grep ${BACKUP_DRIVE} | tr -s ' ' ' ' | cut -f4 -d' '` -gt `echo "${DISK_CAPA} * 2^20" | bc` ];
		then
			break;
		fi
		echo "!!!---Remove Directory : \""${dir}"\" ---!!!" >> ${LOG_FILE}
		rm -rf ${dir}
	done
fi

echo "End Backup:"$(date) >> ${LOG_FILE}

