# cloudflared for FreeBSD / OPNsense

Up-to-date builds of [Cloudflare Tunnel (`cloudflared`)](https://github.com/cloudflare/cloudflared) for **FreeBSD amd64**, built from official Cloudflare release tags with a minimal set of FreeBSD compatibility fixes.

> **Unofficial.** These builds are not provided or supported by Cloudflare. The source is unmodified upstream code except for the three small fixes described below.

## Why this exists

Cloudflare publishes `cloudflared` binaries for Linux, macOS and Windows, but not for FreeBSD. OPNsense users get `cloudflared` through the FreeBSD ports tree, which can lag months behind upstream.

This became a real problem in October 2026, when eight eMudhra intermediate certificates were found to be compromised. Cloudflare's advisory (2026-10-20) required upgrading `cloudflared` to **2026.10.2 or later**, while the OPNsense package was still at **2026.2.0**. This repository provides a patched build until the official package catches up.

## Install on OPNsense

### Quick install (with automatic rollback)

```sh
fetch -o /tmp/install-opnsense.sh https://raw.githubusercontent.com/mateuszszponar/cloudflared-freebsd/main/install-opnsense.sh
daemon -f sh /tmp/install-opnsense.sh
tail -f /tmp/cloudflared-install.log
```

The script verifies the checksum, backs up the current binary, swaps it in and restarts the service. If the tunnel does not report ready within 3 minutes, it restores the previous binary automatically. Running it via `daemon` means it finishes even if your session drops, which matters when you manage the firewall through the tunnel you are upgrading.

### Manual install

From the OPNsense shell (console option `8` or SSH):

```sh
fetch -o /tmp/cloudflared https://github.com/mateuszszponar/cloudflared-freebsd/releases/latest/download/cloudflared-freebsd-amd64
fetch -o /tmp/SHA256SUMS  https://github.com/mateuszszponar/cloudflared-freebsd/releases/latest/download/SHA256SUMS
sha256 -c `awk '{print $1}' /tmp/SHA256SUMS` /tmp/cloudflared
```

If the checksum matches, stop the service in the GUI (**Services → Cloudflared**), then:

```sh
cp /usr/local/bin/cloudflared /usr/local/bin/cloudflared.bak
install -m 755 /tmp/cloudflared /usr/local/bin/cloudflared
cloudflared --version
```

Start the service again in the GUI and confirm the new version in the Cloudflare Zero Trust dashboard (**Networks → Tunnels**). The `os-cloudflared` plugin keeps working unchanged; it simply runs the new binary.

**Rollback:** `cp /usr/local/bin/cloudflared.bak /usr/local/bin/cloudflared` and restart the service.

**Note:** a later OPNsense firmware update may reinstall the older packaged binary. Check the tunnel version after each update until the official package reaches the required version.

## FreeBSD compatibility fixes

Upstream `cloudflared` does not build for FreeBSD because three platform-specific pieces only exist for Linux, macOS and Windows. `build.ps1` applies these fixes automatically:

| File | Change | Effect |
|---|---|---|
| `diagnostic/network/collector_unix.go` | Add `freebsd` to the build tag | Reuses the existing Unix network diagnostics |
| `diagnostic/system_collector_freebsd.go` | New stub | `cloudflared tunnel diag` reports system info as unsupported; tunnel operation is unaffected |
| `cmd/cloudflared/freebsd_token.go` | New file | Maps `createTokenFile` to the existing Unix implementation (token file created with `0600` permissions) |

None of these touch tunnel connectivity, TLS or certificate handling.

## Build it yourself

Requirements: Windows with [Go](https://go.dev/) and [Git](https://git-scm.com/) (`winget install GoLang.Go Git.Git`).

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Version 2026.10.3
```

The script clones the given upstream tag, applies the fixes, cross-compiles a static binary (`CGO_ENABLED=0`) and writes `dist/cloudflared-freebsd-amd64` plus `dist/SHA256SUMS`. It prints the upstream commit hash so you can compare it with the official release on GitHub.

## Known limitations

- ICMP proxying (ping through the tunnel) is not implemented upstream for FreeBSD. HTTP, TCP and private-network routing work normally.
- The QUIC receive-buffer warning on startup is harmless; it can be reduced by raising `kern.ipc.maxsockbuf` in **System → Settings → Tunables**.

## License

`cloudflared` is licensed under the [Apache License 2.0](https://github.com/cloudflare/cloudflared/blob/master/LICENSE) by Cloudflare, Inc. The build script and documentation in this repository are released under the same license.
