#!/bin/bash
set -e

RED='\033[1;31m'
GREEN='\033[1;32m'
PURPLE='\033[0;35m'
GRAY='\033[0;33m'
NC='\033[0m'

SCRIPT=`basename ${BASH_SOURCE[0]}`

function program_is_installed {
	# set to 1 initially
	local return_=1
	# set to 0 if not found
	type $1 >/dev/null 2>&1 || { local return_=0; }
	# return value
	echo "$return_"
}

#Help function
function HELP {
  echo -e \\n"Help documentation for ${SCRIPT}."\\n
  echo -e "${NC}Basic usage: ${PURPLE}$SCRIPT ${GREEN}{source-env} ${GREEN}{target-env}"\\n
  echo -e "${NC}This will instruct the script to migrate the wordpress database "
  echo -e "${NC}from source env to target env. Please note, this operation is "
  echo -e "${RED}DESTRUCTIVE. ${NC}The appropriate enviornments must be configured "
  echo -e "${NC}in ${GRAY}wp-config.php${NC} using the ${GRAY}ENV${NC} defined constant. The"
  echo -e "${NC}supported values are: ( ${GRAY}dev${NC} | ${GRAY}staging${NC} | ${GRAY}production${NC} ).${NC}"\\n
  echo -e "-h  --Displays this help message"\\n
  echo -e "${GRAY}Example: $SCRIPT dev staging${NC}"\\n
  exit 1
}

if [ $(program_is_installed wp) != 1 ]; then
	echo -e "${RED}WP-CLI is required in order to use this command${NC}"
	exit 1
fi

if [ $(program_is_installed lftp) != 1 ]; then
	echo -e "${RED}LFTP is required in order to use this command${NC}"
	exit 1
fi

#Check the number of arguments. If none are passed, print help and exit.
NUMARGS=$#
if [ ! $NUMARGS -eq 2 ]; then
	echo -e "${RED}Minimum of 2 arguments required${NC}"
	HELP
fi

ARG_SOURCE=$1
ARG_DEST=$2

SOURCE_SCRPT=""
DEST_SCRPT=""

case "$ARG_SOURCE" in
	"staging")
		SOURCE_SCRPT="--require=/home/vagrant/Documents/bin/migrate_wp/env_staging.php "
		;;
	"production")
		SOURCE_SCRPT="--require=/home/vagrant/Documents/bin/migrate_wp/env_production.php "
		;;
	"dev")
		SOURCE_SCRPT="--require=/home/vagrant/Documents/bin/migrate_wp/env_dev.php "
		;;
	*)
		echo -e "${RED}Unrecognised argument${ARG_SOURCE}${NC}"
		HELP
		;;
esac

case "$ARG_DEST" in
	"staging")
		DEST_SCRPT="--require=/home/vagrant/Documents/bin/migrate_wp/env_staging.php "
		;;
	"production")
		DEST_SCRPT="--require=/home/vagrant/Documents/bin/migrate_wp/env_production.php "
		;;
	"dev")
		DEST_SCRPT="--require=/home/vagrant/Documents/bin/migrate_wp/env_dev.php "
		;;
	*)
		echo -e "${RED}Unrecognised argument ${ARG_DEST}${NC}"
		HELP
		;;
esac

if [ "$ARG_SOURCE" == "$ARG_DEST" ]
then
	echo -e "${RED}Source and destination can not be the same.${NC}"
	HELP
fi

if [ "$ARG_DEST" == 'production' ]
then
	echo -e "${RED}What are you doing Dave!! I'm afraid I can't let you do that Dave.${NC}"
	HELP
fi

#set -x
SRC_URL=$(wp ${SOURCE_SCRPT}db query "SELECT option_value FROM wp_options WHERE option_name='siteurl';")
SRC_URL=${SRC_URL/option_value[[:space:]]/}
echo "Source URL: "${SRC_URL}

DEST_URL=$(wp ${DEST_SCRPT}db query "SELECT option_value FROM wp_options WHERE option_name='siteurl';")
DEST_URL=${DEST_URL/option_value[[:space:]]/}
echo "Destination URL: "${DEST_URL}

SRC_DB_NAME=$(wp ${SOURCE_SCRPT}db query "SELECT DATABASE();")
SRC_DB_NAME=${SRC_DB_NAME/DATABASE\(\)[[:space:]]/}
echo "Source DB Name: "${SRC_DB_NAME}

DEST_DB_NAME=$(wp ${DEST_SCRPT}db query "SELECT DATABASE();")
DEST_DB_NAME=${DEST_DB_NAME/DATABASE\(\)[[:space:]]/}
echo "Destination DB Name: "${DEST_DB_NAME}
#set +x

SRC_DB_BCKUP=/tmp/src_db_$(date +"%Y%m%d%H%M")_${SRC_DB_NAME}.sql
DEST_DB_BCKUP=/tmp/dest_db_$(date +"%Y%m%d%H%M")_${DEST_DB_NAME}.sql

wp ${SOURCE_SCRPT}db export --add-drop-table ${SRC_DB_BCKUP}
wp ${DEST_SCRPT}db export --add-drop-table ${DEST_DB_BCKUP}

sed -i 's/utf8mb4/utf8/g' ${SRC_DB_BCKUP}

sed -i "1i USE ${DEST_DB_NAME};" ${SRC_DB_BCKUP}

wp ${DEST_SCRPT}db import ${SRC_DB_BCKUP}

wp ${DEST_SCRPT}search-replace "${SRC_URL}" "${DEST_URL}"




