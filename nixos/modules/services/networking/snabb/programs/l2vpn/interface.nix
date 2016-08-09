{ lib }:

with lib;

let
  addressFamiliesModule = types.submodule {
          options = {
            ipv6 = mkOption {
              default = null;
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
    foo = mkOption {
      type = types.bool;
      default = null;
      description = "";
    };
    name = mkOption {
      type = types.str;
      default = null;
      example = literalExample ''name = "0000:03:00.1"'';
      description = ''
        The system-wide unique name of the interface.  On conventional
        network devices, this is typicially something like
        <literal>&lt;type&gt;&lt;slot&gt;/&lt;number&gt;</literal>,
        e.g. TenGigabitEthernet3/2.  By convention, the Snabb system
        currently uses the full PCI address of the NIC.  However, the
        name is not derived from the actual PCI address as used in the
        configuration of the driver to accomodate futurue conventions,
        which might not be tied to the PCI address.  An error is thrown
        if the name does not occur in the list of option
        <option>services.snabb.interfaces</option>.  That list is used
        to generate a persistent mapping of interface names to interface
        indices used, for example, for SNMP.  This implies that the name
        is stored in the ifDesc SNMP object.
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
    driver = {
      path = mkOption {
        type = types.str;
        example = literalExample ''apps.intel.intel_app'';
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
      config = {
        snmpEnable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to enable SNMP support in the driver.
          '';
        };
      };
    };
    mtu = mkOption {
      type = types.int;
      default = 1514;
      example = 9014;
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
        if tunking is disabled.
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
        example = literalExample ''encapsulation = "0x9100";'';
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
    macAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = literalExample ''"00:00:00:01:02:03"'';
      description = ''
        The physical MAC address of the interface.  This is
        currently required if L3 subinterfaces are present
         (it should be automatically read from the NIC).
      '';
    };
  }; # options

}
