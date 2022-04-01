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



	outputs = { self, nixpkgs, utils, ... }@inputs:
		let
			# System types to support.
			supportedSystems = [ "x86_64-linux" ];
		in
		utils.lib.eachSystem supportedSystems (system: 
		let 
			pkgs = nixpkgs.legacyPackages.${system}; 
			inherit (pkgs) lib;
		in {
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
