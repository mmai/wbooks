{ pkgs ? import <nixpkgs> {} }:

pkgs.callPackage ./front-derivation.nix {}
