# sapl-nix

Nix flake for [SAPL](https://sapl.io): the SAPL Node PDP server and CLI, the
SAPL Language Server, and a NixOS module for running SAPL Node as a service.

All packages are the pre-built native binaries published on the
[sapl-policy-engine releases](https://github.com/heutelbeck/sapl-policy-engine/releases).
Supported systems: `x86_64-linux`, `aarch64-linux`.

## Try it

```bash
nix run github:heutelbeck/sapl-nix -- --version
nix run github:heutelbeck/sapl-nix#sapl-node-snapshot -- --version
```

## Packages

| Package | Contents | Channel |
|---|---|---|
| `sapl-node` (default) | `sapl` PDP server and CLI | latest release |
| `sapl-node-snapshot` | `sapl` PDP server and CLI | latest `master` build |
| `sapl-language-server` | `sapl-language-server` for IDEs | latest release |
| `sapl-language-server-snapshot` | `sapl-language-server` for IDEs | latest `master` build |

The flake also provides `overlays.default` (adds all four packages to `pkgs`)
and `nixosModules.default` (`services.sapl-node`).

## Release and snapshot channels

Versions and hashes live in `nix/sources/release.json` and
`nix/sources/snapshot.json`. The sapl-policy-engine CI rewrites them after
publishing: every `v*` release tag updates the release channel, every `master`
build updates the snapshot channel. Nothing is updated by hand.

Snapshot archives are overwritten on every `master` build. A pinned snapshot
keeps working while it is in your Nix store; after garbage collection or on a
fresh machine an old pin fails with a hash mismatch. Run
`nix flake update sapl-nix` to move to the current snapshot.

## Use in a flake

```nix
{
  inputs.sapl-nix.url = "github:heutelbeck/sapl-nix";

  outputs = { nixpkgs, sapl-nix, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            sapl-nix.packages.${pkgs.stdenv.hostPlatform.system}.sapl-node
          ];
        })
      ];
    };
  };
}
```

With Home Manager, add the same package references to `home.packages`.

## Run SAPL Node as a NixOS service

```nix
{
  imports = [ sapl-nix.nixosModules.default ];

  services.sapl-node = {
    enable = true;
    # Local development only: no TLS and no authentication.
    tls.enable = false;
    settings."io.sapl.node".allowNoAuth = true;
    policies.allow-read = ''
      policy "allow-read"
      permit action == "read";
    '';
  };
}
```

The service listens on `127.0.0.1:7443` by default. Inline `policies` are
packaged into a bundle at build time and deployed atomically on rebuild.
For production settings (TLS, authentication, signed bundles, remote bundle
sources, secrets via `extraSettingsFiles`) see the option documentation at the
top of [`nix/module.nix`](nix/module.nix). The default package is the release
channel; set `services.sapl-node.package` to `sapl-node-snapshot` to follow
`master`.

## Language server for editors

Put `sapl-language-server` (or `sapl-language-server-snapshot`) on the `PATH`
of your editor, for example via `programs.neovim.extraPackages` in Home
Manager. Editor configuration is described in the
[SAPL IDE setup documentation](https://sapl.io/docs/latest/9_0_IDESetup).

## License

Apache License 2.0, see [LICENSE](LICENSE).
