#!/bin/bash
ERROR_FLAG=1

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "---------------------------------------------"
echo "Upon pull origin/master: processing merge ..."

cat .git/refs/heads/master > .git/info/LAST_ORIGIN_PULL #store merge SHA
echo -e "local merge commit [${GREEN}" $(cat .git/info/LAST_ORIGIN_PULL) " ${NC}] stored in .git/info/LAST_ORIGIN_PULL"

cat .git/refs/remotes/origin/master > .git/info/MERGE_SIDE #store the origin/master side of merge (parent) 
echo -e "origin/master remote merge side commit [${GREEN}" $(cat .git/info/MERGE_SIDE) " ${NC}] stored in .git/info/MERGE_SIDE"

LAST_ORIGIN_PULL=$(cat .git/info/LAST_ORIGIN_PULL)
git diff $LAST_ORIGIN_PULL | grep -e "---" -e "+++" | cut -d'/' -f2-1000 > .git/info/$LAST_ORIGIN_PULL.change #obtain list of files changed by this merge
echo "obtained list of files in working tree affected by this merge ->" .git/info/$LAST_ORIGIN_PULL.change

git log | grep Merge: | cut -d' ' -f2 | grep $(head -c 7 .git/info/MERGE_SIDE) #use -m1
if [ $? = 0 ]
then #grep found something
    echo -e "origin/master side of merge found to be ${GREEN} first parent ${NC} "
    CHERRY_PICK=-m1
    ERROR_FLAG=0
fi

git log | grep Merge: | cut -d' ' -f3 | grep $(head -c 7 .git/info/MERGE_SIDE) #use -m2
if [ $? = 0 ]
then #grep found something
    echo -e "origin/master side of merge found to be ${GREEN} second parent ${NC} "
    CHERRY_PICK=-m2
    ERROR_FLAG=0
fi

echo "switching to dev branch ..."
git checkout dev #checkout working branch on dev 

find . -path ./.git -prune -o -print | cut -d'/' -f2-1000 > .git/info/DEV_FILES.tmp #list of all files on dev

grep -F -x -f .git/info/DEV_FILES.tmp .git/info/$LAST_ORIGIN_PULL.change > .git/info/DEV_FILES.change #find those changed by merge which are also part of dev
if [ $? = 0 ]
then #add merge to cherry pick
    echo -e "   ${CYAN}Merge is to be included in next cherry pick from master onto dev. ${NC} "
    echo "   Because some files on dev are now changed on origin/master."
    echo "   List of changed files is stored in .git/info/DEV_FILES.change"
     
    CHERRY_PICK=$CHERRY_PICK" "$LAST_ORIGIN_PULL" "
    if [ $ERROR_FLAG = 1 ]
    then
        echo "ERROR: could not find origin/master side of the merge!"
        exit
    fi
    ERROR_FLAG=0
    echo $CHERRY_PICK > .git/info/CHERRY_PICK_COMMITS
else
    echo "   Merge did not affect any files on dev so will not be included in next cherry pick."
fi

cat .git/info/CHERRY_PICK_COMMITS
echo "---------------------------------------------"

