FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        build-essential \
        ca-certificates \
        git \
        zlib1g-dev

WORKDIR /build

RUN git clone -n --depth=1 --filter=tree:0 https://github.com/cheat-engine/cheat-engine.git . \
    && git sparse-checkout set --no-cone "Cheat Engine/ceserver" \
    && git checkout \
    && make -C "Cheat Engine/ceserver/gcc"

FROM ubuntu:24.04

WORKDIR /app

COPY --from=build ["/build/Cheat Engine/ceserver/gcc/ceserver", "/app/"]

EXPOSE 52736

ENTRYPOINT ["/app/ceserver"]
