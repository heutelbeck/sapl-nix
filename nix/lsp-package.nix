# SAPL Language Server binary package
#
# Fetches the pre-built sapl-language-server native binary from GitHub
# releases. The binary implements the Language Server Protocol (LSP)
# for .sapl policy files and .sapltest test files.
#
# Platform differences are the same as sapl-node: fully static on
# x86_64-linux (musl), glibc-linked on aarch64-linux (autoPatchelf).
#
# Updating hashes:
#
#   The CI publish job automatically computes SRI hashes after uploading
#   release archives and commits updated hashes to nix/lsp-hashes.json.
#   To compute hashes manually:
#
#     nix hash file --sri sapl-language-server-<version>-linux-amd64.tar.gz
#     nix hash file --sri sapl-language-server-<version>-linux-arm64.tar.gz

{ lib, stdenv, fetchurl, autoPatchelfHook, glibc, installShellFiles }:

let
  version = "4.0.0-SNAPSHOT";

  # Maps Nix system identifiers to release archive platform suffixes.
  platformMap = {
    "x86_64-linux" = "linux-amd64";
    "aarch64-linux" = "linux-arm64";
  };

  # SRI hashes for each platform archive, loaded from lsp-hashes.json.
  # The CI publish job updates lsp-hashes.json automatically after each release.
  hashes = builtins.fromJSON (builtins.readFile ./lsp-hashes.json);

  platform = platformMap.${stdenv.hostPlatform.system}
    or (throw "sapl-language-server: unsupported platform ${stdenv.hostPlatform.system}");

  # The x86_64 binary is fully static (musl). No ELF patching needed.
  # The aarch64 binary links glibc dynamically and needs autoPatchelfHook.
  isFullyStatic = platform == "linux-amd64";

in
stdenv.mkDerivation {
  pname = "sapl-language-server";
  inherit version;

  src = fetchurl {
    url = "https://github.com/heutelbeck/sapl-policy-engine/releases/download/snapshot/sapl-language-server-${version}-${platform}.tar.gz";
    sha256 = hashes.${platform};
  };

  # The archive contains files at the top level (sapl-language-server, LICENSE, README.md),
  # not inside a subdirectory.
  sourceRoot = ".";

  nativeBuildInputs = [ installShellFiles ]
    ++ lib.optionals (!isFullyStatic) [ autoPatchelfHook ];
  buildInputs = lib.optionals (!isFullyStatic) [ glibc ];

  installPhase = ''
    install -Dm755 sapl-language-server $out/bin/sapl-language-server
    if [ -f sapl-language-server.1 ]; then
      installManPage sapl-language-server.1
    fi
  '';

  # GraalVM native images should not be stripped.
  dontStrip = true;

  meta = {
    description = "SAPL Language Server for IDE integration";
    homepage = "https://github.com/heutelbeck/sapl-policy-engine";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames platformMap;
    mainProgram = "sapl-language-server";
  };
}
