{ lib
, fetchurl
, kernel
, kernelPatches ? []
, patch
, ...
} @ args:

with lib;

let
	# commit = "17d44ed5e9b8e7b2a6dfe0cfe567302a02ced819";
	# diffHash = "1w0yx7ywbdwzakr5gwjk2h2zv6qgh8dkjf5g8rapcvm1vqk92jlw";
	shorthash = lib.strings.substring 0 7 patch.commit;
	kernelVersion = kernel.version;
	oldPatches = kernelPatches;
in
(kernel.override (args // {
	argsOverride = {

		version = "${kernelVersion}-bcachefs-unstable-${shorthash}";
		extraMeta.branch = versions.majorMinor kernelVersion;

	} // (args.argsOverride or { });

	kernelPatches = [{
		name = "bcachefs-${patch.commit}";
		inherit patch;
		extraConfig = "BCACHEFS_FS m";
	}] ++ oldPatches;
}))
