#!/bin/bash

# This file is part of migration-framework.
# Copyright (C) 2015 RWTH Aachen University - ACS
#
# This file is licensed under the GNU Lesser General Public License Version 3
# Version 3, 29 June 2007. For details see 'LICENSE.md' in the root directory.
#

n=1
memory=1024
verbose=false
verbose_output="/dev/null"

while getopts A:B:V:n:m:h opt; do
	case $opt in
	A)
		server_a="$OPTARG"
		;;
	B)
		server_b="$OPTARG"
		;;
	V)
		vm_name="$OPTARG"
		;;
	n)
		n="$OPTARG"
		;;
	m)
		memory="$OPTARG"
		;;
	v)
		verbose="$OPTARG"
		verbose_output="&1"
		;;
	h)
		echo -e "Usage: `basename $0` -A serverA -B serverB -V vm-name [-n N] [-m memory]

		-A serverA
		Hostname of first server to start migfra on.

		-B serverB
		Hostname of second server to start migfra on.
		
		-V vm-name
		Name of the virtual machine to use.
		
		-n N (=1)
		Repeat migration ping pong N times.
		Default value 1.
		
		-m memory (=1024)
		The RAM in MiB to assign to vm.
		Default value 1024
		
		-v verbose (=false)
		Specify if benchmark should run in verbose mode.
		Not implemented yet." | sed 's/^\s\s*//g'

		exit 0
		;;
	esac
done

(( memory *= 1024 ))

if [ -z "$server_a" ] && [ -z "$server_b" ]; then
	echo "No scheduler and server hosts passed as arguments."
elif [ -n "$server_a" ] && [ -n "$server_b" ]; then
	if [ -z "$vm_name" ]; then
		echo "No vm-name passed as argument."
		exit 1
	fi
	# start migfra on servers using ssh in background
	echo "Start migfra on servers."
	ssh -f "$server_a" "`realpath $0` -A $server_a"
	ssh -f "$server_b" "`realpath $0` -B $server_b"

	# start migration benchmark
	`dirname $0`/../../build/migfra_benchmark -n $n -V "$vm_name" -t "." -H devon -A "$server_a" -B "$server_b" -m "$memory"

	# quit migfra on servers
	echo "Stop migfra on servers"
	mosquitto_pub -t "fast/migfra/$server_a/task" -h devon -q 2 -f "`dirname $0`/quit_task.yaml"
	mosquitto_pub -t "fast/migfra/$server_b/task" -h devon -q 2 -f "`dirname $0`/quit_task.yaml"

elif [ -n "$server_a" ] || [ -n "$server_b" ]; then
	if [ -n "$server_a" ]; then
		server="$server_a"
	else
		server="$server_b"
	fi
	echo "Starting migfra on $server"
	cd `dirname $0`
	cd ../../build
	if [ -f "./migfra" ]; then
		./migfra & disown
	else
		echo "Cannot find migfra executable on $server."
		exit 1
	fi
else
	echo "Please specify hosts for server A and server B."
	echo "-h to show usage."
	exit 1
fi
