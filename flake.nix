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
			url = "github:koverstreet/bcachefs-tools";
			flake = false;
		};
	};



	outputs = { self, bcachefs-tools, nixpkgs, utils, ... }@inputs:
		let
			# System types to support.
			supportedSystems = [ "x86_64-linux" ];
		in
		utils.lib.eachSystem supportedSystems (system: 
		let 
			selfpkgs = self.packages.${system};
			pkgs = nixpkgs.legacyPackages.${system}; 
			inherit (pkgs) lib;
		in {
			defaultPackage = selfpkgs.bcachefs-tools;
			packages = {
				bcachefs-tools = pkgs.callPackage ./bcachefs-tools.nix {
					src = bcachefs-tools;
					sourceInfo = bcachefs-tools;
				};
			};
			devShell = self.devShells.${system}.tools;
			devShells.tools = selfpkgs.bcachefs-tools.override { inShell = true; };
		}) // {
			nixosModule = self.nixosModules.bcachefs;
			nixosModules.bcachefs = import ./nixos/module/bcachefs.nix;
			nixosModules.bcachefs-enable-boot = ({config, pkgs, lib, ... }:{
				# Disable Upstream NixOS Module when this is in use
				disabledModules = [ "tasks/filesystems/bcachefs.nix" ];

				# Add bcachefs to boot and kernel
				boot.initrd.supportedFilesystems = [ "bcachefs" ];
				boot.supportedFilesystems = [ "bcachefs" ];
			});
		};
}
