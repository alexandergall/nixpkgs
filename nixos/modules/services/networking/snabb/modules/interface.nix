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
      default = null;
      example = literalExample ''10GE-SFP+ link to foo'';
      description = ''
        An optional verbose description of the interface.  This string
        is exposed in the ifAlias object if SNMP is enabled for the
        interface.
      '';
    };
    nicConfig = mkOption {
      type = types.nullOr (types.submodule
                            (import ./nic-config.nix
                                    { inherit lib; }));
      default = null;
      description = ''
        The low-level configuration of the interface.
      '';
    };
    mirror = mkOption {
      default = null;
      description = ''
        An optional configuration for mirroring traffic
        from/to the interface.
      '';
      type = types.nullOr (types.submodule {
        options = {
          rx = mkOption {
            type = types.either types.bool types.string;
            default = false;
            description = ''
              Whether to enable mirroring of the packets received
              by the interface.
            '';
          };
          tx = mkOption {
            type = types.either types.bool types.string;
            default = false;
            description = ''
              Whether to enable mirroring of the packets transmitted
              by the interface.
            '';
          };
          type = mkOption {
            type = types.enum [ "tap" "pcap" ];
            default = "tap";
            description = ''
              The type of the mirror mechanism to use. If set to tap,
              a Tap interface is created to receive the mirrored packets
              for each direction that is enabled.  If the corresponding
              option (<option>rx</option> or <option>tx</option>) is a
              boolean, the name of the Tap device is constructed from the
              name of the interface by replacing slashes by hyphens,
              truncating the name to 13 characters and appending the string
              "_rx" or "_tx" (i.e. the name will not exceed the system limit
              of 16 character for interface names on Linux). If the rx or
              tx option is a string, it will be used as the name of the
              Tap device instead.

              If the type is set to pcap, packets will be written to files
              in the pcap format.  If the tx/rx option is a boolean, the
              file name is constructed from the name of the interface by
              replacing slashes by hyphens and appending the string "_tx.pcap"
              or "_tx.pcap".  If the tx/rx option is a string, it is used
              as the file name instead.
            '';
          };
        };
      });
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
