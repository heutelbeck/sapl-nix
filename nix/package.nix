# SAPL Node binary package
#
# Fetches the pre-built sapl-node native binary from GitHub releases.
# `channel` selects the source: "release" (latest tagged release) or
# "snapshot" (latest master build, published under the moving
# snapshot-node tag). Version, release tag and hashes come from
# sources/<channel>.json.
# The binary serves dual purpose: PDP server and CLI tool for bundle
# management and credential generation.
#
# Platform differences:
#
#   x86_64-linux   Fully static binary linked against musl libc.
#                  No runtime dependencies. Works on any Linux distro
#                  including NixOS without patching.
#
#   aarch64-linux  Static binary except for libc (--static-nolibc).
#                  Links dynamically against glibc because GraalVM does
#                  not yet ship musl static JDK libraries for aarch64.
#                  autoPatchelfHook patches the ELF interpreter and RPATH
#                  for NixOS compatibility.
#
# Updating sources:
#
#   The sapl-policy-engine CI rewrites sources/release.json on every release
#   tag and sources/snapshot.json on every master snapshot build, using the
#   hashes of the archives as published on GitHub. To compute a hash
#   manually:
#
#     nix store prefetch-file --json <archive url>

{ lib, stdenv, fetchurl, autoPatchelfHook, glibc, channel ? "release" }:

let
  source = builtins.fromJSON (builtins.readFile ./sources/${channel}.json);
  inherit (source) version;

  # Maps Nix system identifiers to release archive platform suffixes.
  platformMap = {
    "x86_64-linux" = "linux-amd64";
    "aarch64-linux" = "linux-arm64";
  };

  platform = platformMap.${stdenv.hostPlatform.system}
    or (throw "sapl-node: unsupported platform ${stdenv.hostPlatform.system}");

  # The x86_64 binary is fully static (musl). No ELF patching needed.
  # The aarch64 binary links glibc dynamically and needs autoPatchelfHook.
  isFullyStatic = platform == "linux-amd64";

in
stdenv.mkDerivation {
  pname = "sapl-node";
  inherit version;

  src = fetchurl {
    url = "https://github.com/heutelbeck/sapl-policy-engine/releases/download/${source.node.tag}/sapl-${version}-${platform}.tar.gz";
    hash = source.node.hashes.${platform};
  };

  # The archive contains files at the top level (sapl, LICENSE, README.md),
  # not inside a subdirectory.
  sourceRoot = ".";

  nativeBuildInputs = lib.optionals (!isFullyStatic) [ autoPatchelfHook ];
  buildInputs = lib.optionals (!isFullyStatic) [ glibc ];

  installPhase = ''
    install -Dm755 sapl $out/bin/sapl
    install -Dm644 -t $out/share/man/man1 man/*.1
    install -Dm644 completion/sapl.bash $out/share/bash-completion/completions/sapl
  '';

  # GraalVM native images should not be stripped.
  dontStrip = true;

  meta = {
    description = "SAPL Node PDP server and policy management CLI";
    homepage = "https://github.com/heutelbeck/sapl-policy-engine";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames platformMap;
    mainProgram = "sapl";
  };
}
