# nixos/util/load-env.nix - Load environment variables
{ lib, ... }:

let
  # Function to read and parse .env file
  readEnvFile = file:
    let
      content = builtins.readFile file;
      lines = lib.filter (line: line != "" && !(lib.hasPrefix "#" line))
        (lib.splitString "\n" content);
      parseLine = line:
        let
          parts = lib.splitString "=" line;
          key = lib.elemAt parts 0;
          value = lib.concatStringsSep "=" (lib.drop 1 parts);
        in
        { name = key; value = lib.removePrefix "\"" (lib.removeSuffix "\"" value); };
    in
    builtins.listToAttrs (map parseLine lines);

  # Load environment variables (../../.env because we're in nixos/util/)
  env = readEnvFile ../../.env;
in
{
  # Export the environment variables as options
  options = {
    env = lib.mkOption {
      type = lib.types.attrs;
      default = env;
      description = "Environment variables loaded from .env file";
    };
  };
}
