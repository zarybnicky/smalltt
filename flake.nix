{
  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [self.overlay];
    };
    src = pkgs.nix-gitignore.gitignoreSourcePure [./.gitignore] ./.;
    hsPkgs = pkgs.haskell.packages.ghc884;
  in {
    overlay = final: prev: {
      haskell = prev.haskell // {
        packageOverrides = prev.lib.composeExtensions (prev.haskell.packageOverrides or (_: _: {})) (hself: hsuper: {
          smalltt = hself.callCabal2nix "smalltt" src {};
          primdata = prev.haskell.lib.dontHaddock (hself.callCabal2nix "primdata" "${src}/primdata" {});
          dynamic-array = hself.callCabal2nix "dynamic-array" "${src}/dynamic-array" {};
        });
      };
    };

    devShell.x86_64-linux = hsPkgs.shellFor {
      withHoogle = false;
      packages = p: [ p.smalltt ];
      buildInputs = [
        hsPkgs.cabal-install
        hsPkgs.hie-bios
        hsPkgs.haskell-language-server
      ];
    };
  };
}
