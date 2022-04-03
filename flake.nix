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

			overlay = self.overlays.bcachefs;
			overlays.bcachefs = (final: prev: {
				inherit (self.packages.${final.system})
					bcachefs-tools;
			});
		}
		// utils.lib.eachSystem supportedSystems
			(system:
				let
					packages = self.packages.${system};
					pkgs = nixpkgs.legacyPackages.${system};
					inherit (nixpkgs) lib;

					latest-kernel-commit = readFileValue ./pins/bcachefs-kernel.latest.rev;

					getPatch = { commit, sha256, kernelVersion, ... }: pkgs.fetchurl {
						inherit sha256;
						passthru = { inherit commit; };
						name = "bcachefs-${commit}.diff";
						url = "https://evilpiepirate.org/git/bcachefs.git/rawdiff/?id=${commit}&id2=v${lib.versions.majorMinor kernelVersion}";
					};
				in
				{
					legacyPackages.kernelPackages = lib.recurseIntoAttrs (pkgs.linuxPackagesFor packages.kernel);
					legacyPackages.kernelPackages-latest = lib.recurseIntoAttrs (pkgs.linuxPackagesFor packages.kernel-latest);
					legacyPackages.patchedKernelPackages = lib.recurseIntoAttrs (pkgs.linuxPackagesFor packages.kernel-patched);
					legacyPackages.patchedKernelPackages-latest = lib.recurseIntoAttrs (pkgs.linuxPackagesFor packages.kernel-patched-latest);

					defaultPackage = packages.bcachefs-tools;
					packages = {
						bcachefs-tools = pkgs.callPackage ./bcachefs-tools.nix {
							src = bcachefs-tools;
							sourceInfo = bcachefs-tools;

							testWithValgrind = false;
						};

						bcachefs-tools-debug = packages.bcachefs-tools.override {
							testWithValgrind = true;
							debugMode = true;
						};

						# Kernels built from source
						kernel = pkgs.callPackage ./bcachefs-kernel.nix {
							commit = packages.bcachefs-tools.bcachefs_revision;
							kernelVersion = "5.16.0";
							sha256 = readFileValue ./pins/bcachefs-kernel.sha256;
							kernelPatches = [ ];
						};

						kernel-latest = pkgs.callPackage ./bcachefs-kernel.nix {
							commit = latest-kernel-commit;
							kernelVersion = "5.16.0";
							sha256 = readFileValue ./pins/bcachefs-kernel.latest.sha256;
							kernelPatches = [ ];
						};

						# Kernels built as a patch
						# Patch files
						bcachefs-kernel-patch = getPatch {
							commit = packages.bcachefs-tools.bcachefs_revision;
							sha256 = (readFileValue ./pins/bcachefs-kernel.patch.sha256);
							kernelVersion = pkgs.linuxKernel.kernels.linux_5_16.version;
						};

						bcachefs-kernel-latest-patch = getPatch {
							commit = latest-kernel-commit;
							sha256 = (readFileValue ./pins/bcachefs-kernel.patch.latest.sha256);
							kernelVersion = pkgs.linuxKernel.kernels.linux_5_16.version;
						};

						#Kernel Derivations
						kernel-patched = pkgs.callPackage ./bcachefs-kernel.patch.nix {
							kernel = pkgs.linuxKernel.kernels.linux_5_16;
							patch = packages.bcachefs-kernel-patch;
							kernelPatches = [ ];
						};

						kernel-patched-latest = pkgs.callPackage ./bcachefs-kernel.patch.nix {
							kernel = pkgs.linuxKernel.kernels.linux_5_16;
							patch = packages.bcachefs-kernel-latest-patch;
							kernelPatches = [ ];
						};


					};

					checks = { 
						inherit (packages) 
							bcachefs-tools-debug
							bcachefs-kernel-patch
							bcachefs-kernel-latest-patch;

						kernelSrc = packages.kernel.src;
					};
					
					hydraJobs = (
						self.checks.${system} //
						self.packages.${system}
					);

					devShell = self.devShells.${system}.bcachefs-tools;
					devShells.bcachefs-tools = packages.bcachefs-tools-debug.override { inShell = true; };
				});
}
