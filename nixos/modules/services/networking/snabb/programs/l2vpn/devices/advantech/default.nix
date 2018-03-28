{ config, ... }:

{
  imports = [ ./classes.nix ];

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
	advantech = {
	  FWA3230A = {
            classes = [ "FWA32xx" ];
	    interfaces = [
	      ## GigE interfaces in top row labelled MGMT0, MGMT1
	      {
		name = "GigE1/0";
		nicConfig = {
		  pciAddress = "0000:0c:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE1/1";
		nicConfig = {
		  pciAddress = "0000:0d:00.0";
		  driver = intel_mp;
		};
	      }
	      ## GigE interfaces in bottom row, labelled 1 through 6
	      {
		name = "GigE2/1";
		nicConfig = {
		  pciAddress = "0000:06:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2/2";
		nicConfig = {
		  pciAddress = "0000:07:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2/3";
		nicConfig = {
		  pciAddress = "0000:08:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2/4";
		nicConfig = {
		  pciAddress = "0000:09:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2/5";
		nicConfig = {
		  pciAddress = "0000:0a:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2/6";
		nicConfig = {
		  pciAddress = "0000:0b:00.0";
		  driver = intel_mp;
		};
	      }

	      ## TenGigE in left mezzanine slot labelled 1 and 2
	      {
		name = "TenGigE1/1";
		nicConfig = {
		  pciAddress = "0000:03:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "TenGigE1/2";
		nicConfig = {
		  pciAddress = "0000:03:00.1";
		 driver= intel_mp;
		};
	      }

	      ## TenGigE in right mezzanine slot labelled 1 and 2
	      {
		name = "TenGigE2/1";
		nicConfig = {
		  pciAddress = "0000:04:00.0";
		 driver= intel_mp;
		};
	      }
	      {
		name = "TenGigE2/2";
		nicConfig = {
		  pciAddress = "0000:04:00.1";
		 driver= intel_mp;
		};
	      }
	    ];
	  }; ## FWA3230A

	  FWA3230A_1 = {
            ## This model uses slightly different PCI addresses
            classes = [ "FWA32xx" ];
	    interfaces = [
	      ## GigE interfaces in top row labelled MGMT0, MGMT1
	      {
		name = "GigE1/0";
		nicConfig = {
		  pciAddress = "0000:0d:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE1/1";
		nicConfig = {
		  pciAddress = "0000:0e:00.0";
		  driver = intel_mp;
		};
	      }
	      ## GigE interfaces in bottom row, labelled 1 through 6
	      {
		name = "GigE2/1";
		nicConfig = {
		  pciAddress = "0000:07:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2/2";
		nicConfig = {
		  pciAddress = "0000:08:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2/3";
		nicConfig = {
		  pciAddress = "0000:09:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2/4";
		nicConfig = {
		  pciAddress = "0000:0a:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2/5";
		nicConfig = {
		  pciAddress = "0000:0b:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2/6";
		nicConfig = {
		  pciAddress = "0000:0c:00.0";
		  driver = intel_mp;
		};
	      }

	      ## TenGigE in left mezzanine slot labelled 1 and 2
	      {
		name = "TenGigE1/1";
		nicConfig = {
		  pciAddress = "0000:03:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "TenGigE1/2";
		nicConfig = {
		  pciAddress = "0000:03:00.1";
		 driver= intel_mp;
		};
	      }

	      ## TenGigE in right mezzanine slot labelled 1 and 2
	      {
		name = "TenGigE2/1";
		nicConfig = {
		  pciAddress = "0000:04:00.0";
		 driver= intel_mp;
		};
	      }
	      {
		name = "TenGigE2/2";
		nicConfig = {
		  pciAddress = "0000:04:00.1";
		 driver= intel_mp;
		};
	      }
	    ];
	  }; ## FWA3230A_1

          FWA3270A = {
            classes = [ "FWA32xx" ];
	    interfaces = [
	      ## Leftmost GigE interfaces MGMT1, MGMT2
	      {
		name = "Mgmt1";
		nicConfig = {
		  pciAddress = "0000:0e:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "Mgmt2";
		nicConfig = {
		  pciAddress = "0000:0f:00.0";
		  driver = intel_mp;
		};
	      }
	      ## GigE interfaces labelled 1 through 6
	      {
		name = "GigE1";
		nicConfig = {
		  pciAddress = "0000:08:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE2";
		nicConfig = {
		  pciAddress = "0000:09:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE3";
		nicConfig = {
		  pciAddress = "0000:0a:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE4";
		nicConfig = {
		  pciAddress = "0000:0b:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE5";
		nicConfig = {
		  pciAddress = "0000:0c:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "GigE6";
		nicConfig = {
		  pciAddress = "0000:0d:00.0";
		  driver = intel_mp;
		};
	      }

	      ## TenGigE in slot NMC2 (left mezzanine slot) labelled 1 and 2
	      {
		name = "TenGigE2/1";
		nicConfig = {
		  pciAddress = "0000:03:00.0";
		  driver = intel_mp;
		};
	      }
	      {
		name = "TenGigE2/2";
		nicConfig = {
		  pciAddress = "0000:03:00.1";
		 driver= intel_mp;
		};
	      }

	      ## TenGigE in slot NMC1 (right mezzanine slot) labelled 1 and 2
	      {
		name = "TenGigE1/1";
		nicConfig = {
		  pciAddress = "0000:04:00.0";
		 driver= intel_mp;
		};
	      }
	      {
		name = "TenGigE1/2";
		nicConfig = {
		  pciAddress = "0000:04:00.1";
		 driver= intel_mp;
		};
	      }
	    ];
	  }; ## FWA3270A
	};
      };
}
