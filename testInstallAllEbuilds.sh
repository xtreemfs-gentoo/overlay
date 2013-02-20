#!/bin/bash
#
#	Tests whether the Gentoo ebuilds are configured properly or not.
#	Run this script in the packaging directory!
#	This script acts as a helper script for the Gentoo package maintainer
#	and is not relevant for the end user.
#
#	Author: Patrick Hieber <p@trickhieber.de> (2013)

CID=101
CONTNAME="funtoo-current-generic_32-openvz-latest"
VEXEC="vzctl exec ${CID} "
#STABLE="1.4"
REVLIST=$(ls net-fs/xtreemfs/*.ebuild | cut -d/ -f3 | sed -e 's/\.ebuild$//g;')
MNTDIR="/mnt/temp"
SUCCESS=

if [ "${REVLIST}" = "" ]; then
	echo 'Cannot determine ebuild revisions. Please ensure that you execute this script in the correct directory!' >&2
	exit 1
fi

testXtreemFSMount() {
	if \
		${VEXEC} "mkdir -p ${MNTDIR}" && \
		${VEXEC} 'mount.xtreemfs demo.xtreemfs.org/demo '${MNTDIR} && \
		${VEXEC} "touch ${MNTDIR}/me" && \
		${VEXEC} "rm ${MNTDIR}/me" && \
		#${VEXEC} "dd if=/dev/zero of=${MNTDIR}/42.dd bs=1M count=1" && \
		${VEXEC} "touch ${MNTDIR}/42.dd" && \
		${VEXEC} "cp ${MNTDIR}/42.dd /tmp/" && \
		${VEXEC} "rm ${MNTDIR}/42.dd" && \
		${VEXEC} "test -e $SUCCESS || test $SUCCESS -eq 1" ; then
		SUCCESS=1
		echo tested $1 successfuly
	else
		echo error in $1 ... >&2
	fi
	${VEXEC} "umount ${MNTDIR}"
}

wget -O /vz/template/cache/${CONTNAME}.tar.xz http://ftp.heanet.ie/mirrors/funtoo/funtoo-current/openvz/x86-32bit/${CONTNAME}.tar.xz

for revision in ${REVLIST}; do
	vzctl stop $CID
	vzctl destroy $CID

	vzctl create ${CID} --ostemplate ${CONTNAME}
	vzctl set ${CID} --diskspace 8G:10G  --save
	vzctl set ${CID} --diskinodes 700000:1000000 --save
	vzctl set ${CID} --ram 512M --save
	vzctl set ${CID} --swappages=100:100 --save
	vzctl set ${CID} --privvmpages 165000:165000 --save
	vzctl set ${CID} --devnodes fuse:rw --save
	vzctl set ${CID} --netif_add eth0,,,,br0 --save
	vzctl start ${CID}
	sleep 20

	${VEXEC} '/etc/init.d/dhcpcd start'
	sleep 20
	${VEXEC} 'emerge --sync && emerge -uDN world'
	${VEXEC} 'USE="git" emerge layman'
	${VEXEC} 'layman -L && layman -a xtreemfs'
	${VEXEC} 'echo "source /var/lib/layman/make.conf" >> /etc/make.conf'
	${VEXEC} 'mkdir -p /etc/portage/package.mask'
	${VEXEC} "echo \">net-fs/${revision}\" >> /etc/portage/package.mask/xtreemfs"
	${VEXEC} 'emerge -v sys-fs/fuse xtreemfs'

	testXtreemFSMount $revision
done

# vim:ts=2:ai
