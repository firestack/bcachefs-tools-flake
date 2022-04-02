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
		}
		// utils.lib.eachSystem supportedSystems
			(system:
				let
					packages = self.packages.${system};
					pkgs = nixpkgs.legacyPackages.${system};
					inherit (nixpkgs) lib;
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
