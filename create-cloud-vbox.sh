CLOUDNAME=SlackCloud
SLACKWARECFG=./cfgs/slackware141-unattended.cfg
VMDISK="slackware-14.1-AMZ_base.vdi"
STOREAT="C:/Users/$(whoami)/Documents"
BASEPKGS="mpfr slackpkg gnupg ncurses diffutils openssh"
CLOUDPKGS="net-tools network-scripts"



CLDNAME=$(echo $CLOUDNAME | tr [:upper:] [:lower:])
VMBASENAME=$CLDNAME-base     # base server
WEBSERVER=$CLDNAME-web       # web server
DBSERVER=$CLDNAME-db         # database server
NAMESERVER=$CLDNAME-ns       # name server

CLOUDPATH=$STOREAT/$CLOUDNAME-CLOUD
DISKPATH=$CLOUDPATH/$VMBASENAME/disk
[[ ! -d "$DISKPATH" ]] && mkdir -p $DISKPATH
VMDISK=$DISKPATH/$VMDISK

HLINE='echo #######################'

export BASEFOLDER=$CLOUDPATH

$HLINE; echo "Creating cloud: $CLOUDNAME"; $HLINE

function vmbase() {
  # Create a base VM disk installation
  $HLINE; echo " -> Building $VMBASENAME"; $HLINE
  VMDISK=$VMDISK VMNAME="$VMBASENAME" sh create-slack-vbox.sh $SLACKWARECFG; sleep 4
  VMDISK=$VMDISK VMNAME="$VMBASENAME" sh create-slack-vbox.sh $SLACKWARECFG install ; sleep 4

  export PKGS="$BASEPKGS $CLOUDPKGS dhcpcd";
  VBoxManage.exe modifyvm $VMBASENAME --audio none
  VMNAME=$VMBASENAME create-slack-vbox.sh $SLACKWARECFG configure  
  md5sum $VMDISK > $VMDISK.md5
  sha1sum $VMDISK > $VMDISK.sha1
}


function cloned(){
  # clone
  VBoxManage.exe clonevm $VMBASENAME --name $WEBSERVER --register
  VBoxManage.exe clonevm $VMBASENAME --name $DBSERVER --register
  VBoxManage.exe clonevm $VMBASENAME --name $NAMESERVER --register
  VBoxManage.exe clonevm $VMBASENAME --name $NAMESERVER\2 --register
}

function snapshoted(){
  # Shared disk
  export VMDISK="$VMDISK"

  # snapshots
  VBoxManage.exe storageattach $VMBASENAME --storagectl "SATA Controller" --port 0 --device 0 --medium none
  VBoxManage.exe modifymedium $VMDISK --type multiattach

  $HLINE; echo " -> Creating $WEBSERVER instance"; $HLINE
  VMNAME=$WEBSERVER create-slack-vbox.sh $SLACKWARECFG              # create vm instance
  VBoxManage.exe snapshot $WEBSERVER take SNAP0 --description "$CLOUDNAME Cloud base disk"

  $HLINE; echo " -> Creating $DBSERVER instance"; $HLINE
  VMNAME=$DBSERVER  create-slack-vbox.sh $SLACKWARECFG               # create vm instance
  VBoxManage.exe snapshot $DBSERVER take SNAP0 --description "$CLOUDNAME Cloud base disk"

  export VMEM=256
  $HLINE; echo " -> Creating $NAMESERVER instance"; $HLINE
  VMNAME=$NAMESERVER create-slack-vbox.sh $SLACKWARECFG   # create vm instance
  VBoxManage.exe snapshot $NAMESERVER take SNAP0 --description "$CLOUDNAME Cloud base disk"

  $HLINE; echo " -> Creating $NAMESERVER\2 instance"; $HLINE
  VMNAME=$NAMESERVER\2 create-slack-vbox.sh $SLACKWARECFG # create vm instance
  VBoxManage.exe snapshot $NAMESERVER\2 take SNAP0 --description "$CLOUDNAME Cloud base disk"

}

function machinecfg(){
  $HLINE; echo " Configuring: $VMNAME - $VMHOSTNAME"; $HLINE  
  VMNAME=$1 \
  create-slack-vbox.sh $SLACKWARECFG configure
  sleep 4
}

######################
# Web server
######################
function webservercfg(){
  # apache requires: apr-util sqlite
  export VMNAME=$WEBSERVER
  BASICWEBSERVER="httpd php apr apr-util sqlite cyrus-sasl"
  PHPWEBSERVER="libmcrypt libxml2"
  export PKGS="$BASICWEBSERVER $PHPWEBSERVER";
  export VMHOSTNAME=$1
  export CMDFILE=$2

  machinecfg $VMNAME
}

######################
# Database server
######################
function dbservercfg(){
  export VMNAME=$DBSERVER
  export PKGS="mariadb libaio";
  export VMHOSTNAME=$1
  export CMDFILE=$2

  machinecfg $VMNAME
}

######################
# Name servers
######################
function nameservercfg(){
  export PKGS="bind libxml2 openssl idnkit";
  export CMDFILE=$2

  export VMNAME=$NAMESERVER
  export VMHOSTNAME=ns.$1
  machinecfg $VMNAME


  export VMNAME=$NAMESERVER\2
  export VMHOSTNAME=ns2.$1
  machinecfg $VMNAME
}


vmbase		# create base VM disk installation

if [[ "$1" == "clonedisk" ]]; then
  echo "Cloning mediums"
  cloned 	# use cloned medium
else
  echo "Creating snapshots"
  snapshoted 	# use snapshots
fi

sleep 2

webservercfg web.amz-host.vbox ~/slack-cloud/mccmds/web-host.cmds
dbservercfg db.amz-host.vbox mccmds/db-host.cmds
nameservercfg tadominado.vbox ~/slack-cloud/mccmds/ns-host.cmds
