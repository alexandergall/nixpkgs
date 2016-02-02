{ lib, ... }:

with lib;

{
  options = {
    driver = {
      path = mkOption {
        type = types.str;
        default = null;
        example = literalExample ''apps.intel.intel_app'';
        description = ''
          The path of the Lua module in which the driver resides.
        '';
      };
      name = mkOption {
        type = types.str;
        default = null;
        example = "Intel82599";
        description = ''
          The name of the driver within the module referenced by path.
        '';
      };
    };

    ## FIXME: separate generic and driver-specific configuration
    config = {
      pciAddress = mkOption {
        type = types.str;
        default = "";
        example = "0000:04:00.1";
        description = ''
          The PCI address of the interface.
        '';
      };
      mtu = mkOption {
        type = types.int;
        default = 1514;
        example = 9014;
        description = ''
          The MTU of the interface in bytes, including the Ethernet header.
        '';
      };
      snmpEnable = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = ''
          Whether to enable SNMP support in the driver.
        '';
      };
    };
  };
}
