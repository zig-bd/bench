# zinc 0.3.0-beta.1 only builds on Zig 0.17 and its aio dep needs Linux fixes,
# so sources are fetched here, patched, and wired up directly in build.zig.
ARG ZIG_VER=0.17.0

FROM alpine:3.22 AS build
ARG ZIG_VER
RUN apk add --no-cache curl xz patch \
    && curl -fsSL "https://ziglang.org/download/${ZIG_VER}/zig-$(uname -m)-linux-${ZIG_VER}.tar.xz" \
        | tar -xJ -C /opt \
    && mv /opt/zig-$(uname -m)-linux-${ZIG_VER} /opt/zig \
    && ln -s /opt/zig/zig /usr/local/bin/zig

WORKDIR /build
COPY frameworks/shared frameworks/shared
COPY frameworks/zinc frameworks/zinc

WORKDIR /build/frameworks/zinc
RUN set -eux; mkdir -p deps; \
    for dep in zinc:0.3.0-beta.1 aio:0.2.0-alpha.2 url:0.2.0-alpha.2; do \
      name="${dep%%:*}"; ref="${dep#*:}"; \
      curl -fsSL "https://github.com/zon-dev/${name}/archive/refs/tags/${ref}.tar.gz" | tar -xz -C deps; \
      mv "deps/${name}-${ref}" "deps/${name}"; \
    done; \
    patch -p1 -d deps < zig017.patch
RUN zig build -Doptimize=ReleaseFast -Dcpu=baseline -Dtarget=$(uname -m)-linux-musl \
    && test -x zig-out/bin/bench_zinc

FROM alpine:3.22
COPY --from=build /build/frameworks/zinc/zig-out/bin/bench_zinc /bin/framework
EXPOSE 8081
ENTRYPOINT ["/bin/framework"]
