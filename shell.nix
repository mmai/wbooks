with import <nixpkgs> { };

stdenv.mkDerivation rec {
  name = "wbooks-env";
  buildInputs = with pkgs; [ 
    # rustup
    openssl pkgconfig # needed for installing various cargo packages
    gettext
  ];
}
