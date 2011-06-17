root=1
rootok=1
netroot=xcat
clear
echo '[ -e $NEWROOT/proc ]' > /initqueue-finished/xcatroot.sh
udevd --daemon
udevadm trigger
mkdir -p /var/lib/dhclient/
if [ ! -z "$BOOTIF" ]; then
	BOOTIF=`echo $BOOTIF|sed -e s/01-// -e s/-/:/g`
	echo -n "Waiting for device with address $BOOTIF to appear.."
	gripeiter=300
	while [ -z "$bootnic" ]; do 
		bootnic=`ip link show|grep -B1 $BOOTIF|grep mtu|awk '{print $2}'`
		sleep 0.1
		if [ $gripeiter = 0 ]; then
			echo "ERROR"
			echo "Unable to find boot device (maybe the nbroot is missing the driver for your nic?)"
			while :; do sleep 365d; done
		fi
		gripeiter=$((gripeiter-1))
	done
fi
echo "Done"
if [ -z "$bootnic" ]; then
	echo "ERROR: BOOTIF missing, can't detect boot nic"
fi

if [ -r /sys/devices/virtual/dmi/id/product_uuid ]; then
	duid='default-duid "\\000\\004';
	for i in `sed -e s/-//g -e 's/\(..\)/\1 /g' /sys/devices/virtual/dmi/id/product_uuid`; do
		octnum="\\"`printf "\\%03o" 0x$i`
		duid=$duid$octnum
	done
	duid=$duid'";'
	echo $duid > /var/lib/dhclient/dhclient6.leases
fi
#/bin/dash
mkdir -p /etc/ssh
mkdir -p /var/empty/sshd
echo root:x:0:0::/:/bin/sh >> /etc/passwd
echo sshd:x:30:30:SSH User:/var/empty/sshd:/sbin/nologin >> /etc/passwd
ssh-keygen -q -t rsa -f /etc/ssh/ssh_host_rsa_key -C '' -N ''
ssh-keygen -q -t dsa -f /etc/ssh/ssh_host_dsa_key -C '' -N ''
echo 'Protocol 2' >> /etc/ssh/sshd_config
/usr/sbin/sshd
dhclient $bootnic &
dhclient -6 $bootnic -lf /var/lib/dhclient/dhclient6.leases &
gripeiter=101
echo -n "Acquiring network addresses.."
while ! ip addr show dev $bootnic|grep -v 'scope link'|grep -v 'dynamic'|grep -v  inet6|grep inet > /dev/null; do
	sleep 0.1
	if [ $gripeiter = 1 ]; then
		echo
		echo "It seems to be taking a while to acquire an IPv4 address, you may want to check spanning tree..."
	fi
	gripeiter=$((gripeiter-1))
done
echo -n "Acquired IPv4 address "
ip addr show dev $bootnic|grep -v 'scope link'|grep -v 'dynamic'|grep -v  inet6|grep inet|awk '{print $2}'


/bin/dash
