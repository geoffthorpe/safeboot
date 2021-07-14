#!/bin/bash

# Parameters;
#   $1 = < "image" | "network" | "volume" | "file" | "submodule" >
#   $2 = < name of image/network/volume/file/submodule >

set -e

function cleanup_image {
	cid=`docker container ls --quiet --filter label=$1 --filter status=running`
	if [[ -n $cid ]]; then
		for i in $cid; do
			echo "Image $1 is running (cid=$i)"
			echo "  running: docker container kill $i"
			docker container kill $i
		done
	else
		echo "Image $1 is not running"
	fi
	cid=`docker container ls --quiet --filter label=$1 --filter status=created`
	if [[ -n $cid ]]; then
		for i in $cid; do
			echo "Image $1 is created but not running (cid=$i)"
			echo "  running: docker container rm $i"
			docker container rm $i
		done
	else
		echo "Image $1 is not running"
	fi
	cid=`docker container ls --quiet --filter label=$1 --filter status=exited`
	if [[ -n $cid ]]; then
		for i in $cid; do
			echo "Image $1 is waiting to be reaped (cid=$i)"
			echo "  running: docker container rm $i"
			docker container rm $i
		done
	else
		echo "Image $1 is not waiting to be reaped"
	fi
}

function cleanup_network {
	nid=`docker network ls --quiet --filter name=$1`
	if [[ -n $nid ]]; then
		echo "Network $1 is running (nid=$nid)"
		echo "  running: docker network rm $nid"
		docker network rm $nid
	else
		echo "Network $1 is not running"
	fi
}

function cleanup_volume {
	if [[ -d $1 ]]; then
		echo "volume $2 needs cleaning up"
		echo "  running: docker run -i --rm -v $1:/foo $UTIL_IMAGE /bin/bash -O dotglob -c \"rm -rf /foo/*\""
		docker run -i --rm -v $1:/foo $UTIL_IMAGE /bin/bash -O dotglob -c "rm -rf /foo/*"
		rmdir $1
	else
		echo "volume $2 doesn't need cleaning up"
	fi

}

function cleanup_file {
	if [[ -a $1 ]]; then
		echo "file $2 needs cleaning up"
		echo "  running: rm $1"
		rm $1
	else
		echo "file $2 doesn't need cleaning up"
	fi
}

# $1==path, $2==basename, $3==ref-file
function cleanup_submodule {
	if [[ -f $1/$3 ]]; then
		echo "submodule $2 getting cleaned up"
		echo "  running: docker run -i --rm -v $1:/foo $UTIL_IMAGE /bin/bash -O dotglob -c \"chown -R --reference=/foo/$3 /foo/*\""
		docker run -i --rm -v $1:/foo $UTIL_IMAGE /bin/bash -O dotglob -c "chown -R --reference=/foo/$3 /foo/*"
		if [[ -z "$DISABLE_SUBMODULE_RESET" ]]; then
			(cd $1 && git reset --hard && git clean -f -d -x)
		fi
	else
		echo "submodule $2 not getting cleaned up"
	fi

}

case $1 in
	image)
		cleanup_image $2
		exit 0
		;;
	network)
		cleanup_network $2
		exit 0
		;;
	volume)
		cleanup_volume $2 `basename $2`
		exit 0
		;;
	file)
		cleanup_file $2 `basename $2`
		exit 0
		;;
	submodule)
		# Usage: assist_cleanup.sh submodule <path> <ref-file>
		cleanup_submodule $2 `basename $2` $3
		exit 0
		;;
esac

echo "Error: unrecognized object type ($1)"
exit 1
