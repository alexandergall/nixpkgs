{ lib }:

with lib;

{
  options = {
    pciAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "0000:01:00.0";
      description = ''
        The PCI address of the interface in standard
        "geographical notation"
        (<literal>&lt;domain&gt;:&lt;bus&gt;:&lt;device&gt;.&lt;function&gt;</literal>).
        This option is ignored if <option>literlConfig</option> is
        specified.
      '';
    };
    driver = {
      path = mkOption {
        type = types.str;
        example = "apps.intel.intel_app";
        description = ''
          The path of the Lua module in which the driver resides.
        '';
      };
      name = mkOption {
        type = types.str;
        example = "Intel82599";
        description = ''
          The name of the driver within the module referenced by path.
        '';
      };
      extraConfig = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = literalExample ''
          {
            wait_for_link = false,
            txq = 0,
            rxq = 0
          }
        '';
        description = ''
          A literal Lua expression that must define a table which
          will be merged with the default driver configuration,
          which is a table containing the PCI address and MTU.
          This allows the specification of driver-specific
          configuration options.
        '';
      };
      literalConfig = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = literalExample ''
          { pciaddr = "0000:01:00.0" }
        '';
        description = ''
          A literal Lua expression which will be passed to the
          constructor of the driver module. If specified, it
          replaces the default configuration which consists of
          the PCI address and MTU.
        '';
      };
    };
  };
}
