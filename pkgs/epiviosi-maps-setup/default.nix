{
  writeShellApplication,
  util-linux,
  gptfdisk,
  exfatprogs,
  gawk,
  gnugrep,
  coreutils,
  systemd,
}:
writeShellApplication {
  name = "epiviosi-maps-setup";
  runtimeInputs = [
    util-linux
    gptfdisk
    exfatprogs
    gawk
    gnugrep
    coreutils
    systemd
  ];
  text = builtins.readFile ./epiviosi-maps-setup.sh;
}
