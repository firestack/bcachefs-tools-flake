{
	description = "Flake providing bcachefs-tools and bcachefs kernel";

	inputs = {
		# Nixpkgs / NixOS version to use.
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

		utils.url = "github:numtide/flake-utils";

		flake-compat = {
			url = github:edolstra/flake-compat;
			flake = false;
		};

		bcachefs-tools = {
			type = "github";
			owner = "koverstreet";
			repo = "bcachefs-tools";
			# ref = "format-security";
			flake = false;
		};
	};



	outputs = { self, bcachefs-tools, nixpkgs, utils, ... }@inputs:
		let
			readFileValue = filePath: let inherit (nixpkgs) lib;
				removeLineFeeds = str: lib.lists.foldr (lib.strings.removeSuffix) str [ "\r" "\n" ];
				file = builtins.readFile filePath;
			in removeLineFeeds file;
			# System types to support.
			supportedSystems = [ "x86_64-linux" ];
		in
		{
			nixosModule = self.nixosModules.bcachefs;
			nixosModules.bcachefs = import ./nixos/module/bcachefs.nix {
				selfpkgs = system: (self.packages.${system} // self.legacyPackages.${system});
			};
			nixosModules.bcachefs-enable-boot = ({ config, pkgs, lib, ... }: {
				# Disable Upstream NixOS Module when this is in use
				disabledModules = [ "tasks/filesystems/bcachefs.nix" ];

				# Add bcachefs to boot and kernel
				boot.initrd.supportedFilesystems = [ "bcachefs" ];
				boot.supportedFilesystems = [ "bcachefs" ];
			});

			nixosConfigurations.netboot-bcachefs = self.systems.netboot-bcachefs "x86_64-linux";
			systems.netboot-bcachefs = system: (nixpkgs.lib.nixosSystem {
				inherit system; modules = [
				self.nixosModule
				self.nixosModules.bcachefs-enable-boot
				("${nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix")
				({ lib, pkgs, config, ... }: {
					# installation disk autologin
					services.getty.autologinUser = lib.mkForce "root";
					users.users.root.initialPassword = "toor";

					# Symlink everything together
					system.build.netboot = pkgs.symlinkJoin {
						name = "netboot";
						paths = with config.system.build; [
							netbootRamdisk
							kernel
							netbootIpxeScript
						];
						preferLocalBuild = true;
					};
				})
			];
			});
		}
		// utils.lib.eachSystem supportedSystems
			(system:
				let
					packages = self.packages.${system};
					pkgs = nixpkgs.legacyPackages.${system};
					inherit (nixpkgs) lib;

					getPatch = { commit, sha256, kernelVersion, ... }: pkgs.fetchurl {
						inherit sha256;
						passthru = { inherit commit; };
						name = "bcachefs-${commit}.diff";
						url = "https://evilpiepirate.org/git/bcachefs.git/rawdiff/?id=${commit}&id2=v${lib.versions.majorMinor kernelVersion}";
					};
				in
				{
					defaultPackage = packages.bcachefs-tools;
					packages = {
						bcachefs-tools = pkgs.callPackage ./bcachefs-tools.nix {
							src = bcachefs-tools;
							sourceInfo = bcachefs-tools;

							testWithValgrind = false;
						};
					};
				});
}
