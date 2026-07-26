---
name: dockerfile
description: >
  Dockerfile and container image authoring skill for production images.
  Covers: base image selection (alpine/slim/distroless/scratch), non-root users,
  BuildKit secret mounts, digest pinning, multi-stage builds, layer-cache ordering,
  cache mounts, image size reduction, process management, linting and scanning.
  Use when: writing or reviewing a Dockerfile, choosing a base image, hardening
  an image, speeding up builds, or shrinking image size.
  Priority order: security, build speed, image size.
  Sources: Docker docs (build best-practices, secrets, cache), OWASP Docker Security
  Cheat Sheet, Snyk, Sysdig, Google distroless, hadolint, pythonspeed.com.
version: 1.0.0
date: 2026-07-18
user-invocable: true
---

# Dockerfile

Authoring guidance for production container images, ordered by the priorities that matter most: **security first, then build speed, then image size**. Every recommendation traces to an authoritative source (Docker docs, OWASP, Snyk, Sysdig, Google distroless, hadolint).

The through-line: most "Docker best practices" are cargo-culted defaults that were right in one context and copied blindly into every other. Match the choice to the workload — the base image, the process model, and the size levers are all decisions, not dogmas.

> **Scope boundary:** This skill covers writing Dockerfiles and building images.
> - **Runtime hardening** (dropping capabilities, read-only rootfs, seccomp, `--privileged`, Kubernetes `securityContext`) is a *deployment* concern — flagged in §2.9 but set at `docker run`/compose/k8s, not in the Dockerfile.
> - **Application security** (auth, input validation, secrets management at runtime) → **`/web-security`**.
> - **Kubernetes manifests, Helm, orchestration** are out of scope.

Enable BuildKit features by starting the file with the syntax directive:

```dockerfile
# syntax=docker/dockerfile:1
```

`--mount=type=secret`, `--mount=type=cache`, `--mount=type=bind`, and `COPY --link` all require it. BuildKit is the default builder since Docker 23.

---

## 1. Choosing a base image

This is the foundational decision — it drives attack surface, build reliability, build speed, and final size at once. **Do not reflexively reach for "smallest."** The right question is: *does your build compile or link native code against glibc?*

### Decision: alpine vs slim vs distroless vs scratch

| Base                | Approx size | libc              | Shell / pkg mgr | Use when                                                |
| ------------------- | ----------- | ----------------- | --------------- | ------------------------------------------------------- |
| `scratch`           | 0           | none              | none            | Fully static binary, nothing else needed                |
| `distroless/static` | ~2 MiB      | none              | none            | Static binary needing TLS roots / tzdata                |
| `distroless/base`   | ~20 MiB     | glibc             | none            | Dynamically-linked **glibc** binary                     |
| `distroless/cc`     | ~20–25 MiB  | glibc + libstdc++ | none            | Rust (glibc), C/C++                                     |
| `alpine`            | ~5–7 MiB    | **musl**          | yes             | Need a shell / pkg mgr, and no glibc-linked native deps |
| `debian:*-slim`     | ~74–80 MiB  | glibc             | yes             | Prebuilt native artifacts, `apt` at build time          |
| `ubuntu:*`          | ~77 MiB     | glibc             | yes             | Maximum familiarity / compat                            |

Distroless numbers: `static` ≈ 2 MiB, **well under half** of alpine and **under 2%** of full debian (~124 MiB).

### The musl-vs-glibc reality (the alpine trap)

Alpine uses **musl** libc; almost every prebuilt binary artifact in the ecosystem — Python wheels, native node modules, most language release binaries — is built against **glibc**. On Alpine those either fail to install or fall back to **compiling from source**, which needs a full toolchain (`build-base`) and is dramatically slower.

Measured for a Python image with matplotlib + pandas: `python:3.8-slim` built in **~30s → 363 MB**; `python:3.8-alpine` built in **~1,557s → 851 MB** — **~52× slower and ~2.3× larger**. The "small base" was both slower *and* bigger once the native deps compiled.

```dockerfile
# WRONG — reflexive "smallest base" on a native-dep workload.
# pip finds no musl wheel, recompiles pandas/numpy from source: slow build, larger image.
FROM python:3.12-alpine
RUN pip install pandas matplotlib

# CORRECT — glibc slim base takes the prebuilt wheels directly.
FROM python:3.12-slim
RUN pip install pandas matplotlib
```

But the inverse dogma ("always prefer slim") is equally wrong. **Alpine keeps its legitimate lane:**

- **Statically-linked binaries** — Go with `CGO_ENABLED=0`, static Rust — where musl-vs-glibc is irrelevant because nothing links libc at runtime. (Often you skip a base OS entirely: build static, ship on `scratch` or `distroless/static`.)
- **Pure interpreted code with zero native extensions** — nothing to compile means no musl penalty.
- When you genuinely need a shell / package manager in a tiny image.

```
Do you install prebuilt native artifacts (wheels, native node modules, glibc release binaries)?
├── Yes → glibc base: debian *-slim (build) → distroless/base (runtime)
└── No  → is the output a single static binary?
          ├── Yes → build stage on golang/rust → ship on scratch or distroless/static
          └── No  → alpine is fine (pure interpreted, or you need a shell)
```

**Note the conflict:** Docker's generic best-practices page still recommends Alpine as a small base. That advice is fine for static binaries and misleading for interpreted stacks with native deps — follow the language-ecosystem source (e.g. pythonspeed.com) there.

Since PEP 656, `musllinux` wheels exist and NumPy/pandas/matplotlib increasingly ship them, so the worst case no longer hits every Python project — but any *one* uncovered dependency reverts to from-source compilation, so the risk is real until you've verified every native dep has a musl wheel.

Sources: [distroless](https://github.com/GoogleContainerTools/distroless) · [Docker best-practices](https://docs.docker.com/build/building/best-practices/) · [pythonspeed: alpine](https://pythonspeed.com/articles/alpine-docker-python/)

---

## 2. Security (priority 1)

### 2.1 Run as a non-root user

Never ship the default root. A container breakout as root maps toward root on the host — OWASP calls non-root "the best way to prevent privilege escalation attacks." Create a dedicated unprivileged user and switch with `USER`, using a **numeric UID** so orchestrators can verify non-root without resolving `/etc/passwd`.

```dockerfile
# Debian/Ubuntu — assign a fixed numeric UID so `USER` can reference it numerically
RUN groupadd -r app && useradd --no-log-init -r -u 10001 -g app app
USER 10001:10001
```

**Distroless:** the `:nonroot` variants ship a pre-created user at **UID 65532** — skip `useradd`. Use the numeric form; Kubernetes `runAsNonRoot: true` verifies numeric UIDs only, not names.

```dockerfile
FROM gcr.io/distroless/static-debian12:nonroot
USER 65532:65532
```

Sources: [OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) · [distroless](https://github.com/GoogleContainerTools/distroless)

### 2.2 Never bake secrets into layers — use secret mounts

`ARG` and `ENV` **both persist in the final image** (ENV in the runtime environment, ARG in build metadata). Layers are additive and immutable, so writing a secret to a file and `rm`-ing it in a later layer **still leaves it in the earlier layer's tarball** — `rm` only hides it from the final filesystem, not from `docker history`.

Use `RUN --mount=type=secret`: the secret is available only for that one `RUN` and is never written to a layer.

```dockerfile
# syntax=docker/dockerfile:1
# CORRECT — secret exists only during this RUN, never layered in.
RUN --mount=type=secret,id=token,env=API_TOKEN some-tool install
```

```bash
docker build --secret id=token,src=./token.txt .
# or from an env var:  docker build --secret id=token,env=API_TOKEN .
```

Default mount path is `/run/secrets/<id>`. For cloning private repos use `--mount=type=ssh` with `docker build --ssh default`.

```dockerfile
# WRONG — secret is now permanently in image history, retrievable by anyone who pulls it.
ARG API_TOKEN
RUN some-tool install && rm -rf ~/.token
```

Source: [Docker: build secrets](https://docs.docker.com/build/building/secrets/)

### 2.3 Minimize attack surface

Fewer packages = fewer CVEs and fewer tools an attacker can pivot with. A shell-less, package-manager-less image (distroless) removes the attacker's ability to `exec` a shell and install tooling after a breakout.

- Prefer minimal bases (slim / distroless / scratch per §1).
- Don't install what you don't need; drop `--no-install-recommends` transitive extras (§4.3).
- Don't `EXPOSE` ports you don't serve.

Sources: [Snyk](https://snyk.io/blog/10-docker-image-security-best-practices/) · [Sysdig](https://www.sysdig.com/learn-cloud-native/dockerfile-best-practices)

### 2.4 Pin base images by digest

Tags are **mutable** — `python:3.12-slim` can silently point at a new build tomorrow, by accident or by a compromised/re-pushed tag. A `@sha256:` digest guarantees a byte-identical base on every pull.

```dockerfile
FROM python:3.12-slim@sha256:<digest>
```

**Tradeoff — pin *and* automate:** a frozen digest also freezes out security patches. Pair digest pinning with Renovate/Dependabot so bumps happen deliberately, not never. hadolint flags unpinned bases via **DL3006/DL3007**.

Sources: [Snyk](https://snyk.io/blog/10-docker-image-security-best-practices/) · [Sysdig](https://www.sysdig.com/learn-cloud-native/dockerfile-best-practices)

### 2.5 COPY, not ADD

`ADD` has two footguns: it **auto-extracts local tar archives** (Zip-Slip path traversal / zip-bomb risk) and **fetches remote URLs** (opaque, unverified network fetch into the image). `COPY` copies local files verbatim. For a remote artifact, use an explicit, checksum-verifiable `RUN curl`. hadolint **DL3020**.

Source: [OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

### 2.6 `.dockerignore`: exclude everything, then allow-list

The entire build context is sent to the builder and can be pulled into layers by a broad `COPY . .`. Prefer a **default-deny** `.dockerignore`: exclude everything, then re-include only what the build needs. A new secret or artifact is then excluded *by default* — you can't leak it by forgetting to add a denylist entry.

```
# Exclude everything by default
*

# Re-include only what the build needs
!Dockerfile
!package.json
!package-lock.json
!src/**
```

Two `.dockerignore` gotchas — it is *not* `.gitignore`:

- **`*` matches top-level entries only**, not recursively. Re-include a directory's *contents* with `!dir/**`, not `!dir` (recursive exclusion would be `**`).
- **A child can be re-included even if its parent was excluded** — the opposite of `.gitignore`, and what makes the allow-list work at all. Last matching rule wins, so re-includes must come after the `*`.

Caveat: re-including a whole directory (`!src/**`) re-admits *anything* later dropped there, including a stray `.env` or key. Where secrets could land, allow-list specific files instead of a broad `dir/**`.

Sources: [Docker: build context](https://docs.docker.com/build/concepts/context/) · [.dockerignore as a whitelist](https://kevinpollet.dev/posts/how-to-use-your-dockerignore-as-a-whitelist/)

### 2.7 Multi-stage builds keep build tooling and credentials out of the final image

Compilers, dev dependencies, and any build-time credentials stay in a discarded stage. The final image contains only the runtime artifact.

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.23 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /bin/app ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /bin/app /bin/app
USER 65532:65532
ENTRYPOINT ["/bin/app"]
```

For actual secrets, still prefer `--mount=type=secret` (§2.2) over `COPY`-ing a secret into an intermediate stage — a cached or pushed intermediate stage can leak it.

Sources: [Docker best-practices](https://docs.docker.com/build/building/best-practices/) · [Snyk](https://snyk.io/blog/10-docker-image-security-best-practices/)

### 2.8 File-permission hygiene

Sources disagree; the stronger security argument (Sysdig) is to **not** blanket-`chown` to the app user. The app needs **execute**, not **ownership**. Keep binaries **root-owned and non-writable by the app user** so a compromised process can't rewrite its own binaries (persistence defense). Only `chown` the specific directories the app must write to. A fixed numeric UID (here `10001`) is the right default: it satisfies k8s `runAsNonRoot` (§2.1) and gives writable dirs a stable owner. It is **not** universal, though — arbitrary-UID platforms (OpenShift's restricted SCC) run the container as a *random* UID in group `0`, so ownership by `10001` buys nothing there. To stay portable across both, don't rely on the UID owning its dirs: make writable dirs **group-owned by GID 0 and group-writable**, and keep ephemeral state in `/tmp`.

```dockerfile
RUN mkdir /data && chown 10001:0 /data && chmod g+rwX /data
USER 10001:10001
```

Reach for `COPY --chown` only on genuinely writable dirs, not on executables.

Sources: [Sysdig](https://www.sysdig.com/learn-cloud-native/dockerfile-best-practices) · [Snyk](https://snyk.io/blog/10-docker-image-security-best-practices/)

### 2.9 Runtime hardening is mostly NOT a Dockerfile concern

The most-blurred distinction in Docker guides: **only `HEALTHCHECK` is a Dockerfile directive.** The rest are set at `docker run` / compose / Kubernetes, and belong in deployment config, not the Dockerfile.

| Control              | Where          | How                                                                       |
| -------------------- | -------------- | ------------------------------------------------------------------------- |
| HEALTHCHECK          | **Dockerfile** | `HEALTHCHECK CMD curl -f http://localhost:8080/health \|\| exit 1`        |
| Drop capabilities    | Runtime        | `--cap-drop ALL --cap-add CHOWN`; k8s `capabilities.drop: ["ALL"]`        |
| Read-only rootfs     | Runtime        | `--read-only --tmpfs /tmp`; k8s `readOnlyRootFilesystem: true`            |
| No new privileges    | Runtime        | `--security-opt=no-new-privileges`; k8s `allowPrivilegeEscalation: false` |
| Never `--privileged` | Runtime        | grants ALL capabilities — OWASP: do not use                               |

Baseline posture: drop ALL capabilities, add back only what's needed. **Kubernetes ignores the Dockerfile `HEALTHCHECK`** — use `livenessProbe`/`readinessProbe` there.

Source: [OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

### 2.10 SBOM, provenance, and attestations

Emit an **SBOM** (contents, SPDX) and **provenance** (SLSA-style build record) so consumers can verify the supply chain:

```bash
docker buildx build --sbom=true --provenance=mode=max -t img:tag --push .
```

`--provenance=mode=min` is on by default; `--sbom=true` must be opted in. **Critical caveat:** the default local image store does **not** persist attestations — they attach to the image index as a manifest, so they only stick when you **push to a registry** (or use the containerd image store). Building locally and expecting the attestation to be present is a common trap.

Source: [Docker: attestations](https://docs.docker.com/build/metadata/attestations/)

---

## 3. Build speed (priority 2)

### 3.1 Layer-cache ordering: dependencies before source

Layer order *is* your cache strategy. Docker reuses a layer until one of its inputs changes, then rebuilds it and everything after. Order steps **least- → most-frequently-changed**: copy dependency manifests and install *before* copying source, so a code edit doesn't invalidate the dependency-install layer.

```dockerfile
# CORRECT — deps layer survives code changes.
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build
```

```dockerfile
# WRONG — any source edit busts the cache and reruns npm ci every build.
COPY . .
RUN npm ci
RUN npm run build
```

Source: [Docker: optimize cache](https://docs.docker.com/build/cache/optimize/)

### 3.2 BuildKit cache mounts

`RUN --mount=type=cache` persists a package-manager cache across builds, independent of layer invalidation — even a cold layer reuses downloaded packages. Cache mounts are a speed optimization *only*: the build must still be correct with an empty cache.

```dockerfile
RUN --mount=type=cache,target=/root/.npm npm ci
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build go build -o /app
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/app/target cargo build --release
```

Do **not** add `pip install --no-cache-dir` alongside a pip cache mount — it tells pip not to populate the mount, defeating the point (and it doesn't shrink the image either way, since the cache lives in the mount, not a layer).

**apt is special** — Debian/Ubuntu images auto-delete downloaded `.deb`s, and apt takes exclusive locks, so disable the auto-clean and use `sharing=locked`:

```dockerfile
RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends gcc
```

Source: [Docker: optimize cache](https://docs.docker.com/build/cache/optimize/)

### 3.3 `.dockerignore` shrinks context transfer

The whole context is transferred to the builder *before* the build starts. Excluding `node_modules`, `.git`, logs, and artifacts cuts transfer time and prevents `COPY . .` from cache-busting on irrelevant files. `COPY . .` is not the anti-pattern — an unfiltered context is. See §2.6 for the file.

Source: [Docker: optimize cache](https://docs.docker.com/build/cache/optimize/)

### 3.4 Multi-stage parallelism and bind mounts

Independent stages build **concurrently** under BuildKit. `RUN --mount=type=bind` reads context or other-stage files during a RUN without adding a `COPY` layer:

```dockerfile
RUN --mount=type=bind,target=. go build -o /app/hello
```

Source: [Docker best-practices](https://docs.docker.com/build/building/best-practices/)

### 3.5 The alpine build-time cost

Covered in §1: on native-dep workloads Alpine can be ~52× slower to build because it recompiles from source. For build speed on interpreted stacks with native deps, this is the single biggest lever — pick the glibc base.

### 3.6 `COPY --link` (use judiciously)

`COPY --link` copies into an empty destination as an **independent layer** that isn't invalidated when earlier layers change — best for cross-stage artifact copies and copies onto a frequently-updated base, and reusable via `--cache-from`. Requires BuildKit + Dockerfile syntax ≥ 1.4.

Caveats: it can't read prior filesystem state (won't follow symlinks into pre-existing dirs), and it is **not** a universal speedup — apply it where it clearly helps, not blindly.

Source: [Docker reference](https://docs.docker.com/reference/dockerfile/)

---

## 4. Image size (priority 3)

### 4.1 Multi-stage: copy only artifacts

The biggest size lever. Build in a fat stage, copy only the runtime artifact into a minimal final stage (§2.7 snippet). Typical reductions: Go 90–99%, Node 70–90%, Python 50–70%.

Source: [Docker best-practices](https://docs.docker.com/build/building/best-practices/)

### 4.2 Pick the right final base

See the §1 table. For a static binary, `scratch` or `distroless/static` (~2 MiB) beats alpine (~5–7 MiB) and crushes debian-slim (~74 MiB). Distroless also ships no shell → smaller attack surface and cleaner scans, at the cost of no `exec` debugging (use the `:debug` variants, which add busybox, when you must shell in).

### 4.3 Clean apt cache in the same layer; `--no-install-recommends`

Combine `apt-get update` with `install` in one RUN (avoids stale-cache bugs) and delete the lists **in the same RUN** — a separate cleanup RUN leaves the bytes in the earlier layer. hadolint **DL3009** (clean lists), **DL3015** (`--no-install-recommends`).

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
```

Source: [Docker best-practices](https://docs.docker.com/build/building/best-practices/)

### 4.4 "Minimize layer count" is mostly obsolete

Under BuildKit, layers are content-addressed, compressed, and pulled in parallel — raw layer count barely affects size. What still matters:

- **Never create-then-delete across layers** — the bytes persist in the earlier layer regardless of a later `rm`. This (not layer count) is the real reason to combine a download+cleanup into one RUN.
- **Ordering** for cache hits (§3.1).

Don't chain unrelated commands with `&&` just to "reduce layers" — it hurts caching and readability.

Source: [Docker best-practices](https://docs.docker.com/build/building/best-practices/)

---

## 5. Process management — "one process per container"

**One process per container is a default, not a law.** Docker's own "Run multiple services in a container" page says "It's ok to have multiple processes" and documents supervisord as a sanctioned approach. nginx + app via supervisord is legitimate when you're **not** on an orchestrator — a single VM / `docker run` / compose, where no platform is supplying per-process scaling, restart, and log aggregation.

But the rule exists for real reasons. If you run multiple processes, handle these:

- **PID 1 signal handling.** The kernel gives PID 1 no default signal handlers. An app as PID 1 with no explicit SIGTERM handler **ignores SIGTERM**, so `docker stop` hangs 10s then SIGKILLs — no graceful shutdown.
- **Zombie reaping.** PID 1 must `wait()`-reap orphaned children; a normal app doesn't, so zombies accumulate.
- **Fix: run an init.** `docker run --init` (tini, built into Docker), or `tini`/`dumb-init` as ENTRYPOINT — they forward signals and reap zombies. Docker docs call `--init` "superior to a full-fledged init like systemd."
- **supervisord is a weak init** — a process *manager*, not a signal-forwarding reaper. Run it under tini/`--init`. Supervised services **must run in the foreground** with `autorestart=true`; self-daemonizing services (php-fpm defaults, apache) defeat supervision.

**Strongest reasons to still split:** you can't scale nginx and the app independently, and Docker's restart policy watches **PID 1 only** — if the app crashes but supervisord stays up, the container looks healthy and is never restarted.

**Bottom line:** at non-orchestrated scale, nginx + app via supervisord is Docker-sanctioned *provided* you (a) run an init for signals/reaping, (b) run every service in foreground with `autorestart=true`, and (c) accept the loss of per-process scaling and crash-restart visibility. **On Kubernetes, split them** — the platform supplies exactly the semantics the single-process model assumes.

Sources: [Docker: multi-service container](https://docs.docker.com/engine/containers/multi-service_container/) · [tini](https://github.com/krallin/tini)

---

## 6. Lint and scan in CI

Gate CI and fail the build on findings.

- **hadolint** — Dockerfile linter; enforces most rules in this skill by code (DL3006/DL3007 pinning, DL3008/DL3013/DL3016/DL3018 dependency pinning, DL3009 apt cleanup, DL3015 no-recommends, DL3020 ADD).
- **Trivy** (Aqua) — most-adopted scanner; daemon-less, all-in-one (CVEs + misconfig + secrets + SBOM), SARIF output. Good default: `trivy image --exit-code 1 --severity HIGH,CRITICAL myimage:tag`.
- **Grype** (Anchore) — fast pure-CVE scanner; pair with **Syft** for SBOMs.
- **Docker Scout** — Docker-native, remediation + base-image upgrade suggestions.
- **Snyk Container** — commercial; recommends less-vulnerable base images.

Source: [Snyk](https://snyk.io/blog/10-docker-image-security-best-practices/)

---

## 7. Anti-patterns

Common advice that is outdated, oversimplified, or wrong:

| Anti-pattern                                         | Why it's wrong                                                                    | Instead                                                                                  |
| ---------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| "Use alpine for small images" (always)               | musl forces from-source builds of glibc native deps — ~52× slower, often _larger_ | Match base to workload (§1): slim/distroless for native deps, alpine for static binaries |
| "Prefer slim" (always)                               | Inverse dogma — alpine is correct for static Go/Rust and pure-interpreted code    | Decide on "do you link native code against glibc?" (§1)                                  |
| `RUN rm secret` removes the secret                   | Persists in the earlier layer's tarball / `docker history`                        | `--mount=type=secret` (§2.2)                                                             |
| Secrets via `ARG`/`ENV`                              | Both persist in the final image                                                   | Secret mounts (§2.2)                                                                     |
| Pin base by tag (`:3.12`) for stability              | Tags are mutable                                                                  | Pin `@sha256:` digest + automate bumps (§2.4)                                            |
| `ADD` for convenience                                | Auto-extract + remote fetch are footguns                                          | `COPY` + explicit `RUN curl` (§2.5)                                                      |
| `COPY . .` then `RUN npm ci`                         | Every code edit busts the dependency layer                                        | Deps before source (§3.1)                                                                |
| `COPY . .` is inherently bad                         | The problem is an unfiltered context, not the copy                                | `.dockerignore` (§2.6, §3.3)                                                             |
| HEALTHCHECK/caps/read-only as "Dockerfile hardening" | Only HEALTHCHECK is a Dockerfile directive; rest are runtime                      | Set caps/read-only at run/compose/k8s (§2.9)                                             |
| "Minimize layer count" for size                      | Obsolete under BuildKit                                                           | Never create-then-delete across layers; order for cache (§4.4)                           |
| `pip install --no-cache-dir` with a cache mount      | Defeats the cache mount; doesn't shrink the image                                 | Drop `--no-cache-dir` when using `--mount=type=cache` (§3.2)                             |
| `COPY --chown` on executables                        | App user shouldn't own its binaries                                               | Root-owned binaries; chown only writable dirs (§2.8)                                     |
| App as PID 1 without an init                         | Ignores SIGTERM, leaks zombies                                                    | `--init` / tini / dumb-init (§5)                                                         |
| Expecting local `--sbom` to persist                  | Default local store drops attestations                                            | Push to a registry (§2.10)                                                               |
