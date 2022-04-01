## Mirrors: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/tasks/filesystems/bcachefs.nix
## with changes to use flakes and import mount.bcachefs
{ config, lib, pkgs, utils, ... }:

with lib;

let

	bootFs = filterAttrs (n: fs: (fs.fsType == "bcachefs") && (utils.fsNeededForBoot fs)) config.fileSystems;
	cfg = config.filesystems.bcachefs;
in

{
	options.filesystems.bcachefs.packages.tools = lib.mkOption {
		description = "Which package to use to link in the bcachefs tools package";
		default = pkgs.bcachefs.tools;
		type = lib.types.package;
	};
	options.filesystems.bcachefs.packages.mount = lib.mkOption {
		description = "Which package to use to link in the bcachefs mount package";
		default = pkgs.bcachefs.mount;
		type = lib.types.package;
	};
	options.filesystems.bcachefs.packages.kernelPackages = lib.mkOption {
		description = "Which package to use to link in the kernel package to use";
		default = pkgs.bcachefs.kernelPackages;
		type = lib.types.attrs;

	};

	config = mkIf (elem "bcachefs" config.boot.supportedFilesystems) (mkMerge [
		{
			system.fsPackages = [ cfg.packages.tools cfg.packages.mount ];

			# use kernel package with bcachefs support until it's in mainline
			boot.kernelPackages = cfg.packages.kernelPackages;
		}

		(mkIf ((elem "bcachefs" config.boot.initrd.supportedFilesystems) || (bootFs != {})) {
			# chacha20 and poly1305 are required only for decryption attempts
			boot.initrd.availableKernelModules = [ "sha256" "chacha20" "poly1305" ];
			boot.initrd.kernelModules = [ "bcachefs" ];

			boot.initrd.extraUtilsCommands = ''
				copy_bin_and_libs ${cfg.packages.tools}/bin/bcachefs
				copy_bin_and_libs ${cfg.packages.mount}/bin/mount.bcachefs
			'';
			boot.initrd.extraUtilsCommandsTest = ''
				$out/bin/bcachefs version
				$out/bin/mount.bcachefs --version
			'';
		})
	]);
}
