# nixos/variables.nix - All configuration variables
{
  networking = {
    gateway = "10.10.10.1";
    dns = [ "10.43.0.10" "1.1.1.1" "8.8.8.8" ];
    
    master = {
      ip = "10.10.10.50";
      hostname = "k3s-master";
      nvmeUuid = "4e4dbabb-14f9-4072-bd32-6fca86dfaaf2";
    };

    slave = {
      ip = "10.10.10.51";
      hostname = "k3s-slave";
      nvmeUuid = "90ec5d0f-85e7-4f2d-9f0a-0b019abc4793";
    };
  };

  k3s = {
    token = "K103d17789ac619d6ac2d7815eeabc893b05b966e5acae8eb315e30fcf17d34e6a5::server:bcec610bcb4fad37a5c07dabbbb66013";
  };

  ssh = {
    authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFRv1Kc600J9AoH8/Ecsu+yJifKaIPqC3OhVBmlrNEU4 homelab admin";
  };
}
