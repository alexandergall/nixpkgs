{ lib }:

with lib;

let
  addressFamiliesModule = types.submodule {
          options = {
            ipv6 = mkOption {
              default = null;
              example = literalExample
                ''
                  {
                    ipv6 = {
                      address = "2001:db8:0:1::2";
                      nextHop = "2001:db8:0:1::1";
                    };
                  }
                '';
              description = ''
                An optional IPv6 configuration of the subinterface.
              '';
              type = types.nullOr (types.submodule {
                options = {
                  address = mkOption {
                    type = types.str;
                    description = ''
                      The IPv6 address assigned to the interface.
                      A netmask of /64 is implied.
                    '';
                  };
                  nextHop = mkOption {
                    type = types.str;
                    description = ''
                      The IPv6 address used as next-hop for all
                      packets sent outbound on the interface.
                      It must be part of the same subnet as the
                      local address.
                    '';
                  };
                  nextHopMacAddress = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = ''
                      The optional MAC address that belongs to the
                      <option>nextHop</option> address.  Setting
                      this option disables dynamic neighbor
                      discovery for the nextHop address on the
                      interface.
                    '';
                  };
                  enableInboundND = mkOption {
                    type = types.bool;
                    default = true;
                    description = ''
                      If the <option>nextHopMacAddress</option>
                      option is set, this option determines whether
                      neighbor solicitations for the local
                      interface address are processed.  If
                      disabled, the adjacent host must use a static
                      neighbor cache entry for the local IPv6
                      address in order to be able to deliver packets
                      destined for the interface.  If
                      <option>nextHopMacAddress</option> is not
                      set, this option is ignored.
                    '';
                  };
                };
              });
            }; # ipv6
          };
        };
in
{
  options = {
    name = mkOption {
      type = types.str;
      description = ''
        The name of the interface.  This can be an arbitrary
        string which uniquely identifies the interface in the
        list <option>services.snabb.interfaces</option>.  If
        VLAN-based sub-interfaces are used, the name must not
        contain any dots.  Otherwise, the operator is free to
        chose any suitable naming convention.  It is important
        to note that it is this name which is used to identify
        the interface within network management protocols such
        as SNMP (where the name is stored in the ifDescr and
        ifName objects) and not the PCI address. A persistent
        mapping of interface names to integers is created from
        the lists <option>services.snabb.interfaces</option>
        and <option>services.snabb.subInterfaces</option> by
        assigning numbers to subsequent interfaces in the
        list, starting with 1.  In the context of SNMP, these
        numbers are used as the ifIndex to identify each
        interface in the relevant MIBs.
      '';
    };
    description = mkOption {
      type = types.nullOr types.str;
      example = literalExample ''10GE-SFP+ link to foo'';
      description = ''
        An optional verbose description of the interface.  This string
        is exposed in the ifAlias object if SNMP is enabled for the
        interface.
      '';
    };
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
mtu = mkOption {
      type = types.int;
      default = 1514;
      description = ''
        The MTU of the interface in bytes, including the full Ethernet
        header.  In particular, if the interface is configured as
        VLAN trunk, the 4 bytes attributed to the VLAN tag must be
        included in the MTU.
      '';
    };
    addressFamilies = mkOption {
      default = null;
      description = ''
        An optional set of address family configurations.  Providing
        this option designates the physical interface as a L3 interface.
        Currently, only ipv6 is supported.  This option is only allowed
        if trunking is disabled.
      '';
      type = types.nullOr addressFamiliesModule;
    };
    trunk = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to configure the interface as a VLAN trunk.
        '';
      };
      encapsulation = mkOption {
        type = types.either (types.enum [ "dot1q" "dot1ad" ])
                            types.str;
        default = "dot1q";
        example = "0x9100";
        description = ''
          The encapsulation used on the VLAN trunk (ignored if
          trunking is disabled), either "dot1q" or "dot1ad" or an
          explicit ethertype.  The ethertypes for "dot1a" and "dot1ad"
          are set to 0x8100 and 0x88a8, respectivley.  An explicit
          ethertype must be specified as a string to allow
          hexadecimal values.  The value itself will be evaluated
          when the configuration is processed by Lua.
        '';
      };
      vlans = mkOption {
        default = [];
        example = literalExample
          ''
            [ { description = "VLAN100";
                vid = 100; }
              { description = "VLAN200";
                vid = 200;
                addressFamilies = {
                  ipv6 = {
                    address = "2001:db8:0:1::2";
                    nextHop = "2001:db8:0:1::1";
                  };
                }; }
             ]
          '';
        description = ''
          A list of vlan defintions.
        '';
        type = types.listOf (types.submodule {
          options = {
            description = mkOption {
              type = types.str;
              default = "";
              description = ''
                A verbose description of the interface.
              '';
            };
            vid = mkOption {
              type = types.int;
              default = 0;
              description = ''
                The VLAN ID assigned to the subinterface in the
                range 0-4094.  The ID 0 designates the subinterfaces
                to which all untagged packets are assigned.
              '';
            };
            addressFamilies = mkOption {
              default = null;
              description = ''
                An optional set of address family configurations.  Providing
                this option designates the sub-interface as a L3 interface.
                Currently, only ipv6 is supported.
              '';
              type = types.nullOr addressFamiliesModule;
            };
          }; # options
        });
      };
    };
  }; # options

}
