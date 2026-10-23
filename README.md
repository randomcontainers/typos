# typos

Container images with [typos](https://github.com/crate-ci/typos), a spell checker for source code. typos looks each word up in a list of known misspellings, such as `teh` for `the`, so names and terms it does not know pass without complaint. It splits identifiers such as `recieveData` and `max_lenght` into words first, so it finds misspellings in names as well as in comments and documentation, and it can fix them in place. The images build typos from the source of each typos release with a pinned Rust release. They are built on Ubuntu and Alpine for `linux/amd64` and `linux/arm64`, and rebuilt when typos publishes a release and when the base image changes.

This is an unofficial build, not affiliated with or endorsed by the typos project. Report problems with the image in this repository and problems with typos itself in the [typos issue tracker](https://github.com/crate-ci/typos/issues).

## Quick start

Check every file in the current directory and below:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" ghcr.io/randomcontainers/typos
```

The image has no default arguments, and without paths typos checks the working directory, `/work`. It prints each misspelling with its file, line and suggested correction, and exits with 2 when it found any and with 0 when it found none. An error, such as a file it cannot read or a mistake in its configuration, gives exit code 1 or another nonzero code in place of 2, even when it also found misspellings. Pass files or directories to check only those.

`--write-changes` (`-w`) writes the fixes into the files, and `--diff` prints them as a diff without changing anything:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" ghcr.io/randomcontainers/typos --write-changes
```

Only misspellings with a single suggestion are fixed. The others are still reported, and the exit code stays 2 until you fix or accept them. `--write-changes` also renames files whose names contain a misspelling it can fix.

Check text from standard input, without mounting anything; with `--write-changes`, typos prints the corrected text:

```sh
echo 'Fix teh bug.' | docker run --rm -i ghcr.io/randomcontainers/typos --write-changes -
```

`--format` chooses the output: `long` (the default, with the line and a marker under the word), `brief` (one line per misspelling), `json` (one JSON object per line) or `sarif`, which GitHub code scanning reads:

```sh
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" ghcr.io/randomcontainers/typos --format sarif > typos.sarif
```

## Which files are checked

typos skips binary files, hidden files and directories, and the files that `.ignore`, `.gitignore` and `.git/info/exclude` exclude. `--hidden` checks hidden files and directories, such as `.github`, as well. typos reads `.gitignore` only inside a git repository, so mount the root of the repository, where `.git` is, and not a subdirectory. It also checks the names of the files it reads. `--files` lists the files typos would check.

## Configuration

typos reads its configuration from `typos.toml`, `_typos.toml` or `.typos.toml`, from a `[tool.typos]` table in `pyproject.toml`, or from `[package.metadata.typos]` or `[workspace.metadata.typos]` in `Cargo.toml`. It looks for them in the directory of each path you pass, or in the working directory, and in their parents. In the container the parents of `/work` are the image's own directories, which is another reason to mount the root of the repository.

```toml
[files]
extend-exclude = ["vendor/", "*.min.js"]

[default]
locale = "en-gb"

[default.extend-words]
# A word mapped to itself is accepted: "ue" (user equipment) is not "use"
ue = "ue"
```

`extend-exclude` takes globs in `.gitignore` syntax. `extend-words` maps a word to its correction, and `extend-identifiers` does the same for whole identifiers. `locale` (or `--locale`) is `en`, `en-us`, `en-gb`, `en-ca` or `en-au`. With `en`, the default, typos accepts both American and British spellings; with the others it also reports the spellings of the other variants, such as `color` with `en-gb`. `--config` reads another file. Upstream's [reference](https://github.com/crate-ci/typos/blob/main/docs/reference.md) lists every key.

## CI and pre-commit

The image has a shell, so CI systems that run their scripts inside the job's image can use it. In GitLab CI, clear the entrypoint:

```yaml
typos:
  image:
    name: ghcr.io/randomcontainers/typos:<version>
    entrypoint: [""]
  script:
    - typos
```

A new typos release often adds words to the list of misspellings, so a job on a moving tag can start to fail without a change in your code. Replace `<version>`, here and below, with the newest exact version tag (see [Tags](#tags)), and update it by hand after each typos release.

pre-commit runs a `docker_image` hook with the repository mounted at `/src` as the working directory and, with rootful Docker, as your user:

```yaml
repos:
  - repo: local
    hooks:
      - id: typos
        name: typos
        language: docker_image
        entry: ghcr.io/randomcontainers/typos:<version>
        args: [--force-exclude]
        types: [text]
```

pre-commit passes the changed files by name, and `--force-exclude` makes typos skip the ones your configuration excludes. Add `--write-changes` to fix them in place. Docker reuses an image it has already pulled, so a moving tag such as `latest` would stay on the first version it pulled.

## typos or codespell

codespell, published by this project as `ghcr.io/randomcontainers/codespell` (see [randomcontainers/codespell](https://github.com/randomcontainers/codespell)), also works from a list of known misspellings. It reads an identifier such as `recieveData` as one word that is not in its lists, so it misses misspellings inside names, and it does not read `.gitignore`. Use codespell when your project already configures it, or for prose, where its optional `informal` and `usage` dictionaries suggest more formal words and recommended terms.

## What is in the image

- `typos` in `/usr/local/bin`, built from the release tag with upstream's release profile. That profile keeps line number information, so the binary is not stripped. It is linked against the distro's C library and libgcc_s: glibc on Ubuntu, musl on Alpine.
- The list of misspellings and the American, British, Canadian and Australian spellings from VarCon, both compiled into the binary.

Copying `/usr/local/bin/typos` into another image with `COPY --from` works only on a base with the same C library, at the same or a newer version, and libgcc_s. For a single file that runs on any Linux system, use the statically linked builds that typos attaches to each [release](https://github.com/crate-ci/typos/releases), `typos-v<version>-x86_64-unknown-linux-musl.tar.gz` and `typos-v<version>-aarch64-unknown-linux-musl.tar.gz`. typos's releases are immutable, and `gh release verify v<version> --repo crate-ci/typos` checks the release attestation that GitHub signs for them.

`/usr/local/share/randomcontainers/typos/buildinfo` has the commit, the Rust release with the URL and SHA-256 of each archive it was installed from, the output of `rustc -vV`, the cargo-auditable version, the version typos reports, and every crate the binary was built from, with its version, whether it is linked in or used only during the build, and its license.

## Default or slim

typos's default image adds no other tools, so `latest` and `slim` are the same image, with the contents listed above. Use `latest` to run it and the `slim` tags as a base for your own image.

## Tags

`<version>` is a typos release such as `1.51.1`. `<minor>` and `<major>` are its shorter forms, `1.51` and `1`, and follow the newest release in that series. Each row lists the default tag and its `slim` twin, which point to the same image.

| Tags | Base |
|---|---|
| `latest`, `slim` | Ubuntu |
| `<version>`, `<version>-slim` | Ubuntu |
| `<minor>`, `<minor>-slim`, `<major>`, `<major>-slim` | Ubuntu |
| `ubuntu`, `slim-ubuntu` | Ubuntu |
| `<version>-ubuntu`, `<version>-slim-ubuntu` | Ubuntu |
| `<minor>-ubuntu`, `<minor>-slim-ubuntu`, `<major>-ubuntu`, `<major>-slim-ubuntu` | Ubuntu |
| `<version>-ubuntu26.04`, `<version>-slim-ubuntu26.04` | Ubuntu 26.04 |
| `alpine`, `slim-alpine` | Alpine |
| `<version>-alpine`, `<version>-slim-alpine` | Alpine |
| `<minor>-alpine`, `<minor>-slim-alpine`, `<major>-alpine`, `<major>-slim-alpine` | Alpine |
| `<version>-alpine3.24`, `<version>-slim-alpine3.24` | Alpine 3.24 |

The images are currently built on Ubuntu 26.04 and Alpine 3.24. Tags without a distro version move to the next distro release when the project does; tags ending in `ubuntu26.04` or `alpine3.24` stay on that release and are no longer rebuilt once the project moves to the next one. Every tag of the current typos version, including the exact version, is rebuilt in place (see [Updates](#updates)), so pin a digest when you need the same bytes every time. In CI, pin at least the exact version (see [CI and pre-commit](#ci-and-pre-commit)).

## Platforms

`linux/amd64` and `linux/arm64`, for both Ubuntu and Alpine. Each image contains typos built for its own architecture and is built natively on GitHub-hosted runners, without emulation.

## Files and permissions

The working directory is `/work`. The image runs as UID 1000, and any other UID works too: `HOME` is then `/`, and caches go to `/cache`, which anyone can write to. typos only reads files unless you pass `--write-changes`, so without it the mount can be read-only (`-v "$PWD:/work:ro"`). It can read and fix only the files its UID has access to, so run it as your own user:

| Runtime | Flag |
|---|---|
| Docker on Linux (rootful), GitHub Actions | `--user "$(id -u):$(id -g)"` |
| Rootless Podman | `--userns=keep-id` |
| Rootless Docker | `--user 0:0` (root in the container is your user on the host) |
| Docker Desktop on macOS or Windows | none, file ownership is mapped for you |

## Extending the slim image

Use a `slim` tag as the base for your own image. `slim`, `slim-ubuntu` and `slim-alpine` move to each new typos release and are rebuilt when the base image changes. Switch to root to install more, then back. This adds `git`, for a script that checks only the files changed on a branch:

```dockerfile
FROM ghcr.io/randomcontainers/typos:slim-ubuntu@sha256:...
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*
USER 1000:1000
```

On Alpine, start from `slim-alpine` and use `apk add --no-cache git`. The entrypoint is `["tini", "--", "typos"]`; set your own `ENTRYPOINT` if your image runs a script. To pick up new typos releases and base image fixes, let Dependabot or Renovate update the digest in your `FROM` line.

Everything the image adds is under `/usr/local`. `/usr/local/share/randomcontainers/typos/` holds the version, the source URLs, the build details, the license files and `runtime-deps`, the list of distro packages typos needs at run time. It is empty on Ubuntu, and on Alpine it names musl and libgcc_s by their `so:` names.

## Verifying

Each image has a build provenance attestation from this repository's GitHub Actions run, signed by the shared build workflow in `randomcontainers/ci`:

```sh
gh attestation verify oci://ghcr.io/randomcontainers/typos:latest \
  --repo randomcontainers/typos --signer-repo randomcontainers/ci
```

Each platform image also carries an SPDX SBOM that lists every distro package with its version:

```sh
docker buildx imagetools inspect ghcr.io/randomcontainers/typos:latest --format '{{ json .SBOM }}'
```

typos is built with [cargo-auditable](https://github.com/rust-secure-code/cargo-auditable), which stores the list of crates compiled into it in the binary's `.dep-v0` section. Syft, Grype and Trivy read that list, so SBOM tools and image scanners see those crates. The Rust standard library is not in the list, and scanners do not report its advisories; `buildinfo` names the Rust release that built typos, and [Updates](#updates) says when it moves. Follow typos's [security advisories](https://github.com/crate-ci/typos/security) as well.

typos publishes no source tarball, so each version is pinned to the commit of its tag. The build clones the `v<version>` tag of [crate-ci/typos](https://github.com/crate-ci/typos) and stops unless the tag points to the commit recorded in `package.yml`. cargo downloads the crates in the tag's `Cargo.lock` and checks each against the checksum there, and the build that follows has no network access. It also stops when upstream's `.cargo/config.toml`, which applies to the build, differs from the SHA-256 pinned in `cargo-config.sha256`.

Rust comes from static.rust-lang.org. The release manifest named in `package.yml` is checked against the SHA-256 recorded there and against its signature, made with the Rust release key (fingerprint `108F 6620 5EAE B0AA A8DD 5E1C 85AB 96E6 FA1B E5FE`, kept in [keys/rust.gpg](keys/rust.gpg)). Each archive installed from it is checked against the SHA-256 that the manifest lists. cargo-auditable, which runs only during the build, is compiled from its crates.io crate, checked against the SHA-256 in `package.yml`, with the crates listed in its own `Cargo.lock`.

## Updates

The project checks the releases of [crate-ci/typos](https://github.com/crate-ci/typos/releases) every 15 minutes. A release is picked up once it is 24 hours old. The new version and the commit of its tag are then committed to `package.yml` and the images are rebuilt. Only the newest release is built; tags of older versions stay as they were last built.

The Rust release that builds typos follows Rust's stable channel. Each new stable release is committed to `package.yml` once it is 7 days old, and the images are rebuilt with it. cargo-auditable is pinned by hand. A typos release that needs a newer Rust than the pinned one does not build until the pin moves. A release also waits for a person when it adds a crate under a license that the image's label does not cover, adds a crate without a license file, changes the version of one of the five crates whose license texts this repository keeps (see [Licenses](#licenses)), or changes upstream's `.cargo/config.toml`.

The images of the current version are also rebuilt when the Ubuntu or Alpine base image changes and at least every 7 days, so distro security fixes reach the current tags.

## Building

```sh
docker build -f Dockerfile.ubuntu --target slim \
  --build-arg VERSION=<version> \
  --build-arg SOURCE_COMMIT=<commit from package.yml> \
  --build-arg RUST_TOOLCHAIN_VERSION=<rust-toolchain version from package.yml> \
  --build-arg RUST_TOOLCHAIN_SHA256=<rust-toolchain sha256 from package.yml> \
  --build-arg CARGO_AUDITABLE_VERSION=<cargo-auditable version from package.yml> \
  --build-arg CARGO_AUDITABLE_SHA256=<cargo-auditable sha256 from package.yml> \
  -t typos:local .
```

Use `Dockerfile.alpine`, with the same arguments, for the Alpine image. The build downloads 120 to 135 MB of Rust archives on Ubuntu and about 170 MB on Alpine, and the crates in `Cargo.lock`. `--build-arg JOBS=<n>` limits the number of crates cargo compiles in parallel. typos's release profile uses link-time optimization with a single code generation unit, so the final compile and link of typos uses one core.

## Licenses

typos is available under the MIT license or the Apache License 2.0, at your option (`MIT OR Apache-2.0`). The binary also contains the Rust crates typos depends on. Most of them are under `MIT OR Apache-2.0` or MIT, and the others offer a choice of licenses that includes MIT, except that supports-unicode is Apache-2.0 only, encoding_rs includes WHATWG data under BSD-3-Clause and unicode-ident includes Unicode data under Unicode-3.0. The Rust standard library and the crates it uses are linked in too. They are under `MIT OR Apache-2.0` or another choice that includes MIT, except compiler-builtins, which is under `MIT AND Apache-2.0 WITH LLVM-exception`. The spelling variants come from VarCon, under the permission notices of Kevin Atkinson and Benjamin Titze and the Ispell license of Geoff Kuenning, which have no SPDX identifier. typos converts VarCon's list into its own tables, so the copy in the binary is a modified version of VarCon.

The image's license label is `MIT AND Apache-2.0 AND BSD-3-Clause AND Unicode-3.0 AND Apache-2.0 WITH LLVM-exception AND LicenseRef-VarCon AND CC-BY-SA-3.0`, with MIT chosen wherever a crate offers it. The build stops when a crate linked into typos has a license that this label does not cover.

typos's list of misspellings started in 2019 as a copy of the list in [misspell](https://github.com/client9/misspell) (MIT), whose README says it began with a word list from Wikipedia. In 2023 and 2026 typos added entries from the dictionary of [codespell](https://github.com/codespell-project/codespell). That dictionary is a derivative work of English Wikipedia, and the codespell project releases it under the Creative Commons Attribution-ShareAlike 3.0 license (CC-BY-SA-3.0). On 2026-01-07 typos also took entries directly from Wikipedia's [list of common misspellings](https://en.wikipedia.org/wiki/Wikipedia:Lists_of_common_misspellings/For_machines) (commit `74e06603`). Wikipedia releases its text under CC BY-SA 4.0; text added before June 2023 was contributed under CC BY-SA 3.0. The same day typos took more entries from misspell, by then the [golangci/misspell](https://github.com/golangci/misspell) fork, whose license has the same text. Upstream ships the whole list under typos's own license, and what its Wikipedia origin means for that is an open question there ([crate-ci/typos#44](https://github.com/crate-ci/typos/issues/44)). The image's label adds CC-BY-SA-3.0 for the entries from codespell, and the image includes misspell's license, the CC BY-SA 3.0 text and a notice for each of codespell's dictionary and Wikipedia's list.

The license files are in `/usr/local/share/randomcontainers/typos/licenses/`: typos's `LICENSE-MIT` and `LICENSE-APACHE` from the release tag; `crates/<crate>-<version>/` with the license files of every crate that the binary records, including those used only while it is built, and `crates/CRATES.tsv`, which lists each of them with its license; `rust/` with the license files of rust-lang/rust, the standard library and the crates it vendors, from the `rust-src` archive of the Rust release that built typos (all of them except LLVM's libunwind, which the dynamically linked binary does not contain); and `varcon/COPYRIGHT`, the copyright section of VarCon's README in the typos repository. Four crates publish no license file (difflib, schemafy_core, schemafy_lib and Inflector), and the `COPYING` file of siphasher names license files that the crate does not include. This repository keeps the license texts of those five crates in [licenses](licenses), together with the files that neither the tag nor the archive has: misspell's license, the notices for the entries from codespell's dictionary and Wikipedia's list, the CC BY-SA 3.0 text and a notice that marks the VarCon data as modified. The build copies them into the image. Inflector (BSD-2-Clause) is used only by the build script of serde-sarif and is not in the binary, so the label leaves BSD-2-Clause out. The Ubuntu and Alpine packages in the image keep their own licenses.

The source for each image:

- typos: built from the `v<version>` tag of [crate-ci/typos](https://github.com/crate-ci/typos). `/usr/local/share/randomcontainers/typos/source` names the commit of that tag, the Rust release manifest, the `rust-src` archive with the source of the Rust standard library, and the cargo-auditable crate. The crates are on [crates.io](https://crates.io/) at the versions in that commit's `Cargo.lock`, and `buildinfo` lists those typos was built from.
- Build scripts: this repository at the commit in the image's `org.opencontainers.image.revision` label.
- Ubuntu packages: the source packages on [Launchpad](https://launchpad.net/ubuntu) for the versions listed in the SBOM. `apt-get source <package>=<version>` fetches a version that is still in the Ubuntu archive.
- Alpine packages: Alpine has no source packages. For the versions listed in the SBOM, the source is the APKBUILD and patches in [aports](https://gitlab.alpinelinux.org/alpine/aports/-/tree/3.24-stable), branch `3.24-stable`, and the archives on [distfiles.alpinelinux.org](https://distfiles.alpinelinux.org/distfiles/v3.24/).

The files in this repository are available under the MIT license, see [LICENSE](LICENSE), except the license texts in `licenses/`, which keep their own terms.

## Requesting a tool

To suggest another tool, use the [Request a tool](https://github.com/randomcontainers/.github/issues/new?template=tool-request.yml) form.
