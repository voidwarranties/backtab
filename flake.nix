{
  description = "Flake for the bar tab backend server application (Backtab)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = {
    self,
    nixpkgs,
  } @ inputs: let
    # This list of architectures provides the supported systems to the wrapper function below.
    # It basically defines which architectures can build and run the Backtab application.
    supportedSystems = [
      "aarch64-darwin"
      "x86_64-linux"
    ];

    # This helper function is used to make the flake outputs below more DRY. It looks a bit intimidating but that's
    # mostly because of the functional programming nature of Nix. I recommend reading
    # [Nix language basics](https://nix.dev/tutorials/nix-language.html) and search online for resources about
    # functional programming paradigms.
    #
    # Basically this function makes it so that instead of declaring outputs for every architecture as the flake schema
    # expects, e.g.:
    #
    # packages = {
    #   "x86_64-linux" = {
    #     ...
    #   };
    #   "aarch64-darwin" = {
    #     ...
    #   };
    # };
    #
    # we can define each output below (package, formatter, ...) once for all the architectures / systems.
    #
    # See https://ayats.org/blog/no-flake-utils to learn more.
    #
    forAllSystems = function:
      nixpkgs.lib.genAttrs supportedSystems (system:
        function (import nixpkgs {
          inherit system;
        }));
  in {
    formatter = forAllSystems (pkgs: pkgs.alejandra);

    packages = forAllSystems (pkgs: {
      default = self.packages.${pkgs.system}.backtab;
      backtab = pkgs.python3Packages.buildPythonApplication rec {
        pname = "backtab";

        # Backtab does not have versioned releases. To still keep track of some sort of version (a Nix package requires
        # it and it's also convenient for debugging) and not having to make up something arbitrary like "1.0", we'll
        # use the Nix builtin substring function to extract the first 7 characters of the git commit hash that the
        # build of this package is based on and use that as the version indicator.
        # To avoid duplication or creating extra variables through let bindings, we'll make the attribute set passed to
        # the mkDerivation function above recursive by adding the `rec` keyword. This allows us to reference the
        # revision attribute in the fetchgit function below through `src.rev`.
        version = builtins.substring 0 7 src.rev;

        src = pkgs.fetchFromGitHub {
          owner = "voidwarranties";
          repo = "backtab";
          rev = "c39595e5764134864cab09408ba234db7f933501";
          hash = "sha256-/H7WPiZeAvLcp8ZjspwdCm0GG8Z/hk7zQgIuycIXkTQ=";
        };

        propagatedBuildInputs = [
          (pkgs.python3.withPackages (ps:
            with ps; [
              beancount
              bottle
              click
              pyyaml
              sdnotify
            ]))
        ];

        meta.mainProgram = "backtab-server";
      };
    });

    nixosModules.backtab = import ./nixos-module.nix;

    overlays.default = final: prev: {
      inherit (self.packages.${prev.system}) backtab;
    };
  };
}
