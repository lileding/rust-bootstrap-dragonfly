#!/bin/sh

RUSTC_BOOTSTRAP_VERSION=1.84.1
CARGO_BOOTSTRAP_VERSION=1.84.1
RUST_VERSION=1.85.1

CONFIGURE_CARGO_STATIC_FLAGS="--enable-cargo-native-static"

export OPENSSL_DIR="/usr/local"
export RUST_BACKTRACE=1
export RUSTC_LINK_STD_INTO_RUSTC_DRIVER=0

DISTFILES_DIR=${DISTFILES_DIR:-${HOME}/rust/distfiles}
BASE=`pwd`
DEST=$1
LLVM_ROOT=""

if [ -x /usr/local/bin/gdb ]; then
	case "${ADDITIONAL_CONFIGURE_FLAGS}" in
	*build.gdb=*) ;;
	*) ADDITIONAL_CONFIGURE_FLAGS="${ADDITIONAL_CONFIGURE_FLAGS} --set build.gdb=/usr/local/bin/gdb" ;;
	esac
fi

. ../checksums.sh
. ../common.sh

STAMP_DIR=${STAMP_DIR:-${DEST}/.dragonfly-bootstrap-stamps}

download() {
	file=`echo $1 | tr ".-" "_"`
	eval "local expected_cksum=\$SHA256_${file}"
	if [ "${expected_cksum}" = "" ]; then
		echo -n "no sha256 checksum found for $2/$1."
		if [ "${MAKE_CHECKSUM}" = "" ]; then
			echo " aborting"
			exit 1
		fi
		echo " continue"
	fi

	mkdir -p "$3" "${DISTFILES_DIR}"
	if [ -f "$3/$1" ]; then
		echo "$1 exists in $3"
	elif [ -f "${DISTFILES_DIR}/$1" ]; then
		echo "$1 exists in ${DISTFILES_DIR}"
		cp "${DISTFILES_DIR}/$1" "$3/$1"
	elif [ -f "$2/$1" ]; then
		echo "$1 exists in $2"
		cp "$2/$1" "$3/$1"
	else
		echo "download: $1 from $4 and store into $3"
		fetch -o "$3/$1" "$4/$1"
	fi

	cksum=`sha256 -q "$3/$1"`
	if [ "${expected_cksum}" = "" ]; then
		[ "${MAKE_CHECKSUM}" != "" ] && echo "SHA256_${file}=${cksum}" >> ../checksums.sh
	elif [ "${cksum}" = "${expected_cksum}" ]; then
		echo "checksum ok for $1"
	else
		echo "checksum mismatch. expected: ${expected_cksum}. given: ${cksum}"
		exit 1
	fi

	if [ ! -f "${DISTFILES_DIR}/$1" ]; then
		cp "$3/$1" "${DISTFILES_DIR}/$1"
	fi
}

fixup-vendor() {
	fixup-vendor-patch openssl-src-111.28.2+1.1.1w src/lib.rs || exit 1
}

info() {
	echo Base: $BASE
	echo Release-Channel: $RELEASE_CHANNEL
	echo Dest: $DEST
	echo BOOTSTRAP_COMPILER_BASE: ${BOOTSTRAP_COMPILER_BASE}
	echo Distfiles: ${DISTFILES_DIR}
	echo Stamps: ${STAMP_DIR}
	echo Path: $PATH
}

run_once() {
	stamp="${STAMP_DIR}/$1.done"
	[ -f "${stamp}" ] && echo "skip $1: ${stamp}" && return 0
	echo "-------------------------------------------"
	echo $1
	echo "-------------------------------------------"
	eval "$1 || exit 1"
	touch "${stamp}"
}

RUN_LOCAL() {
	for action in $*; do
		run_once "${action}"
	done
}

[ "${CLEAN}" != "" ] && [ "${CLEAN}" != "0" ] && clean
mkdir -p "${STAMP_DIR}"
info
RUN_LOCAL extract prepatch fixup-vendor config xbuild xdist inst 2>&1
