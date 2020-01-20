default:
	cargo +nightly build
nix:
	nix build
vbox-destroy:
	nixops destroy -d wbooks-vbox
	nixops delete -d wbooks-vbox
vbox-create:
	nixops create ./deploy/logical.nix ./deploy/physical/virtualbox.nix -d wbooks-vbox
vbox-deploy:
	nixops deploy -d wbooks-vbox --allow-reboot
