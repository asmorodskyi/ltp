#!/bin/sh
# Copyright (c) 2018 SUSE Linux GmbH
# Copyright (c) 2016 Oracle and/or its affiliates. All Rights Reserved.
# Copyright (c) International Business Machines  Corp., 2000
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it would be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# Test basic functionality of 'arp' and 'ip neigh'.

NUMLOOPS=${NUMLOOPS:-50}
TST_TESTFUNC=do_test
TST_SETUP=do_setup
TST_OPTS="c:"
TST_PARSE_ARGS="parse_args"
TST_USAGE="usage"
TST_NEEDS_ROOT=1
. tst_net.sh

do_setup()
{
	tst_check_cmds $CMD ping$TST_IPV6
}

usage()
{
	echo "-c [ arp | ip ] Test command"
}

parse_args()
{
	case $1 in
	c) CMD="$2" ;;
	esac
}

do_test()
{
	local rhost=$(tst_ipaddr rhost)
	case $CMD in
	ip)
		local show_cmd="ip neigh show"
		local del_cmd="ip neigh del $rhost dev $(tst_iface)"
		;;
	arp)
		if [ -n "$TST_IPV6" ]; then
			tst_res TCONF "'arp cmd doesn't support IPv6, skipping test-case"
			return 1
		fi
		local show_cmd="arp -a"
		local del_cmd="arp -d $rhost"
		;;
	*)
		tst_res TBROK "-c is missing or have value not from list [ arp | ip ]"
		return 1
		;;
	esac

	local entry_name="ARP"
	[ "$TST_IPV6" ] && entry_name="NDISC"

	tst_res TINFO "Stress auto-creation of $entry_name cache entry $NUMLOOPS times"

	for i in $(seq 1 $NUMLOOPS); do

		ping$TST_IPV6 -q -c1 $rhost > /dev/null

		local k
		local ret=1
		for k in $(seq 1 30); do
			$show_cmd | grep -q $rhost
			if [ $? -eq 0 ]; then
				ret=0
				break;
			fi
			tst_sleep 100ms
		done

		[ "$ret" -ne 0 ] && \
			tst_brk TFAIL "$entry_name entry '$rhost' not listed"
		$del_cmd || tst_brk TFAIL "fail to delete entry"

		$show_cmd | grep -q "${rhost}.*$(tst_hwaddr rhost)" && \
			tst_brk TFAIL "'$del_cmd' failed, entry has " \
				"$(tst_hwaddr rhost)' $i/$NUMLOOPS"
	done

	tst_res TPASS "verified adding/removing of $entry_name cache entry"
}

tst_run
