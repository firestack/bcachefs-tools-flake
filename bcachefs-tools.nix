{ lib

	# Version and Source info
, src
, sourceInfo ? null
, rev-string ? (sourceInfo.shortRev or sourceInfo.lastModifiedDate)
, git-tag ? "v0.1"

	# NixOS dependencies
, stdenv
, pkg-config
, attr
, libuuid
, libsodium
, keyutils

	# Explicit BCacheFS dependencies
, liburcu
, zlib
, libaio
, udev
, zstd
, lz4

	# Check & Test dependencies
, python39
, python39Packages
, docutils
, nixosTests

, inShell ? false
, debugMode ? inShell

, testWithValgrind ? true
, valgrind

, fuseSupport ? false
, fuse3 ? null
}:

assert fuseSupport -> fuse3 != null;
assert testWithValgrind -> valgrind != null;

let
	version = "${git-tag}-flake-${rev-string}";
in
stdenv.mkDerivation {
	# error: format not a string literal and no format arguments [-Werror=format-security]
	#       Issue: https://github.com/koverstreet/bcachefs/issues/398
	#  Workaround: https://github.com/koverstreet/bcachefs-tools/pull/114
	# Resolved by: https://github.com/koverstreet/bcachefs/commit/ab3b6e7dd69c5cd5dfd96fd265ade6897720f671
	hardeningEnable = [ "format" ];

	pname = "bcachefs-tools";

	inherit version src;
	VERSION = version;

	postPatch = "patchShebangs --build doc/macro2rst.py";

	nativeBuildInputs = [
		# used to find dependencies
		## see ./INSTALL
		pkg-config
	];
	buildInputs = [
		# bcachefs explicit dependencies
		## see ./INSTALL
		libaio
		
		# libblkid
		keyutils # libkeyutils
		lz4 # liblz4
		
		libsodium
		liburcu
		libuuid
		zstd # libzstd
		zlib # zlib1g
		valgrind

		# unspecified dependencies
		attr
		udev

		# documentation depenedencies
		docutils
		python39Packages.pygments
	] ++ (lib.optional fuseSupport fuse3)
	++ (lib.optional testWithValgrind valgrind);

	makeFlags = [
		"PREFIX=${placeholder "out"}"
	] ++ lib.optional debugMode "EXTRA_CFLAGS=-ggdb";

	installFlags = [
		"INITRAMFS_DIR=${placeholder "out"}/etc/initramfs-tools"
	];

	doCheck = true; # needs bcachefs module loaded on builder

	checkInputs = [
		python39Packages.pytest
		python39Packages.pytest-xdist
	] ++ lib.optional testWithValgrind valgrind;

	checkFlags = [
		"BCACHEFS_TEST_USE_VALGRIND=${if testWithValgrind then "yes" else "no"}"
		# cannot escape spaces within make flags, quotes are stripped
		"PYTEST_CMD=pytest" # "PYTEST_ARGS='-n4 --version'"
	];

	preCheck =
		''
			makeFlagsArray+=(PYTEST_ARGS="--verbose -n2")
		'' +
		lib.optionalString fuseSupport ''
			rm tests/test_fuse.py
		'';

	dontStrip = debugMode == true;
	passthru = {
		bcachefs_revision =
			let
				file = builtins.readFile "${src}/.bcachefs_revision";
				removeLineFeeds = str: lib.lists.foldr (lib.strings.removeSuffix) str [ "\r" "\n" ];
			in
			removeLineFeeds file;

		tests = {
			smoke-test = nixosTests.bcachefs;
		};
	};

	enableParallelBuilding = true;
	meta = with lib; {
		description = "Userspace tools for bcachefs";
		homepage = http://bcachefs.org;
		license = licenses.gpl2;
		platforms = platforms.linux;
		maintainers = [ ];

	};
}
