{ config, ... }:

{
  config.services.snabb.devices =
      let
        intel_mp = {
          path = "apps.intel_mp.intel_mp";
          name = "Intel";
          extraConfig = ''
            {
              wait_for_link = false,
              rxq = 0,
              txq = 0,
            }'';
        };
      in
      {
        superMicro = {
          ## Naming convention for Supermicro models: <boardID>_<slot0>..._<slotn>
          ## <boardID> is the product ID of the mainboard with hyphens removed.
          ## The slot descriptors specify the number and type of interfaces present
          ## in the slot, e.g. a 2x10GE card would be "2T", a 4xGE card would be "4G".

          ## The X11SSWF is in a 1RU chassis with two front-facing PCI slots.  The
          ## on-board NICs are slot0, the lower PCI slot is #1 and the upper slot is #2
          X11SSWF_2G_2T = {
            interfaces = [
              ## Left on-board GE
              {
                name = "GigE0/0";
                nicConfig = {
                  pciAddress = "0000:03:00.0";
                  driver = intel_mp;
                };
              }
              ## Right on-board GE
              {
                name = "GigE0/1";
                nicConfig = {
                  pciAddress = "0000:04:00.0";
                  driver = intel_mp;
                };
              }
              ## Left 10GE in slot 1
              {
                name = "TenGigE1/0";
                nicConfig = {
                  pciAddress = "0000:02:00.1";
                  driver = intel_mp;
                };
              }
              ## Right 10GE in slot 1
              {
                name = "TenGigE1/1";
                nicConfig = {
                  pciAddress = "0000:02:00.0";
                  driver = intel_mp;
                };
              }
            ];
          }; ## X11SSWF_2G_2T
          
          X11SSWF_2G_4G = {
            interfaces = [
              ## Left on-board GE
              {
                name = "GigE0/0";
                nicConfig = {
                  pciAddress = "0000:03:00.0";
                  driver = intel_mp;
                };
              }
              ## Right on-board GE
              {
                name = "GigE0/1";
                nicConfig = {
                  pciAddress = "0000:04:00.0";
                  driver = intel_mp;
                };
              }
              ## Leftmost GE in slot 1
              {
                name = "GigE1/0";
                nicConfig = {
                  pciAddress = "0000:02:00.3";
                  driver = intel_mp;
                };
              }
              {
                name = "GigE1/1";
                nicConfig = {
                  pciAddress = "0000:02:00.2";
                  driver = intel_mp;
                };
              }
              {
                name = "GigE1/2";
                nicConfig = {
                  pciAddress = "0000:02:00.1";
                  driver = intel_mp;
                };
              }
              {
                name = "GigE1/3";
                nicConfig = {
                  pciAddress = "0000:02:00.0";
                  driver = intel_mp;
                };
              }
            ];
          }; ## X11SSWF_2G_4G
          
          X11SSWF_2G_2T_2T = {
            interfaces = [
              ## Left on-board GE
              {
                name = "GigE0/0";
                nicConfig = {
                  pciAddress = "0000:03:00.0";
                  driver = intel_mp;
                };
              }
              ## Right on-board GE
              {
                name = "GigE0/1";
                nicConfig = {
                  pciAddress = "0000:04:00.0";
                  driver = intel_mp;
                };
              }
              ## Left 10GE in slot 1
              {
                name = "TenGigE1/0";
                nicConfig = {
                  pciAddress = "0000:02:00.1";
                  driver = intel_mp;
                };
              }
              ## Right 10GE in slot 1
              {
                name = "TenGigE1/1";
                nicConfig = {
                  pciAddress = "0000:02:00.0";
                  driver = intel_mp;
                };
              }
              ## Left 10GE in slot 2
              {
                name = "TenGigE2/0";
                nicConfig = {
                  pciAddress = "0000:01:00.1";
                  driver = intel_mp;
                };
              }
              ## Right 10GE in slot 1
              {
                name = "TenGigE2/1";
                nicConfig = {
                  pciAddress = "0000:01:00.0";
                  driver = intel_mp;
                };
              }
            ];
          }; ## X11SSWF_2G_2T_2T

        };
      };
}
