#!/bin/bash
##################################################################################################################################################################
###This utility will detect the amount of RAM in this system and make suggestions on the size of your java heap as well as the size of your innodb buffer pool.###
###If you choose, it will also make these changes to your zimbra install. NOTE: For the changes to be effective, a mailboxd restart is required.			   ###
###Written by: Tyler Fontaine																																   ###
###Date: 11-30-2014																																			   ###
###Requires Zimbra 8.0.x+																																	   ###
##################################################################################################################################################################
function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

echo "Checking total available ram"

#echo free human readable
cat /proc/meminfo |grep MemTotal

#get memory total in bytes for calculation:
MEMTOT=`cat /proc/meminfo |grep MemTotal |awk '{print $2}' 2>&1`

#memingig
MEMGB=`expr $MEMTOT / 1048576`

#echo "memeory total = "$MEMTOT
#echo "mem total gb = "$MEMGB


##From the wiki:
#    On a <8GB system, set Java heap size percent to 20 and mysql innodb buffer pool to 20% of system memory.
#    On a 8GB system, set Java heap size percent to 30 and mysql innodb buffer pool to 25% of system memory.
#    On a 16GB system, set Java heap size percent to 25 and mysql innodb buffer pool to 30% of system memory, monitor and then increase innodb buffer pool size.
#    On a 32GB system, set Java heap size percent to 20 and mysql innodb buffer pool to 35% of system memory, monitor and then increase innodb buffer pool size.
echo " "
#get values
if [ $MEMGB -lt 8 ]; then
	JAVAHEAP=`perl -E "say int(($MEMTOT/1024*.2)+0.5)"`
	INNODB=`perl -E "say int(($MEMTOT*1024*.2)+0.5)"`
fi
if [ $MEMGB -eq 8 ]; then
	JAVAHEAP=`perl -E "say int(($MEMTOT/1024*.3)+0.5)"`
	INNODB=`perl -E "say int(($MEMTOT*1024*.25)+0.5)"`
fi
if [ $MEMGB -ge 8 ] && [ $MEMGB -le 16 ]; then
	JAVAHEAP=`perl -E "say int(($MEMTOT/1024*.25)+0.5)"`
	INNODB=`perl -E "say int(($MEMTOT*1024*.3)+0.5)"`
fi
if [ $MEMGB -gt 16 ]; then
	JAVAHEAP=`perl -E "say int(($MEMTOT/1024*.2)+0.5)"`
	INNODB=`perl -E "say int(($MEMTOT*1024*.35)+0.5)"`
fi

echo "For your system, with $MEMGB gig of ram, these are your suggested values:"
echo "Java Heap size (in MB):  "$JAVAHEAP
echo "Innodb bufer (in bytes): "$INNODB

echo " "

if [[ "no" == $(ask_yes_or_no "Would You Like to Make these Changes?") || \
      "no" == $(ask_yes_or_no "Are you sure?") ]]; then
      echo "No changes have been made."
      exit 0
fi
echo " "

echo "Executing zmlocalconfig -e mailboxd_java_heap_size=$JAVAHEAP"
zmlocalconfig -e mailboxd_java_heap_size=$JAVAHEAP

echo "Creating copy of existing my.cnf, my.cnf.old"
cp /opt/zimbra/conf/my.cnf /opt/zimbra/conf/my.cnf.old
echo "Changing existing my.cnf"
cat /opt/zimbra/conf/my.cnf |sed "s/innodb_buffer_pool_size.*.\ =\ .*/innodb_buffer_pool_size\ \ \ \ \ \ =\ $INNODB/" > /tmp/my.cnf.new
mv -f /tmp/my.cnf.new /opt/zimbra/conf/my.cnf
rm -f /tmp/my.cnf.new
echo " "
echo "Changes completed"
if [[ "no" == $(ask_yes_or_no "Would You Like to restart mailboxd?") || \
      "no" == $(ask_yes_or_no "Are you sure?") ]]; then
      echo "You must restart mysql and mailboxd for changes to be effective"
      exit 0

fi
zmmailboxdctl stop
mysql.server stop
zmmailboxdctl start
mysql.server start

echo "Services restarted."
exit 0;
