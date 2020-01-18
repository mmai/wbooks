# { lib, rustPlatform, pkgconfig, openssl }:
# rustPlatform.buildRustPackage rec {
{ lib, fetchFromGitHub, makeRustPlatform, pkgs, pkgconfig, openssl, postgresql, sqlite, gettext}:
let
  mozRepo = fetchFromGitHub {
    owner = "mozilla";
    repo = "nixpkgs-mozilla";
    rev = "b5f2af80f16aa565cef33d059f27623d258fef67";
    sha256 = "0s552nwnxcn6nnzrqaazhdgx5mm42qax9wy1gh5n6mxfaqi6dvbr";
  };
  # `mozPkgs` is the package set of `mozRepo`; this differs from their README
  # where they use it as an overlay rather than a separate package set
  mozPkgs = import "${mozRepo}/package-set.nix" { inherit pkgs; };
  channel = mozPkgs.rustChannelOf { channel = "stable"; };
  # channel = mozPkgs.rustChannelOf { date = "2019-11-29"; channel = "nightly"; };
  mozRustPlatform = makeRustPlatform {
    rustc = channel.rust;
    cargo = channel.cargo;
  };
in

mozRustPlatform.buildRustPackage rec {
  pname = "wbooks";
  version = "0.1.0";
  cargoSha256 = "15mwhfs7s71zv0n45g9hggq31a9pdgsi5wc93ni1h1yli0plj2kr";
  src = ./.;

  buildInputs = [
    pkgconfig
    openssl
  ];

  meta = {
    description = "Books management";
    maintainers = with lib.maintainers; [ mmai ];
  };
}
