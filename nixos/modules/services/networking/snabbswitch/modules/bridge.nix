{ lib }:

with lib;

let
  flooding = "flooding";
  learning = "learning";
in {
  options = {
    type = mkOption {
      type = types.enum [ flooding learning ];
      default = learning;
      description = ''
        bridge type
      '';
    };
    config.${learning} = {
      macTable = mkOption {
        type = types.submodule (import ./mac_table.nix { inherit lib; });
	default = {};
	example = literalExample ''{ verbose = true; timeout = 60; }'';
	description = ''
	  Configuration of the MAC address table assoiciated with the
	  learning bridge.
	'';
      };
    };
  };
}
