{ stdenv, lib }:

stdenv.mkDerivation {
  name = "wbooks-front";
  version = "0.1.0";
  src = ./public;

  installPhase = ''
    mkdir $out
    cp -R ./* $out
    '';

  meta = with lib; {
    description = "Web front-end for wbooks";
    license = licenses.agpl3;
    maintainers = with maintainers; [ mmai ];
  };
 }
