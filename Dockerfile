FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    yasm \
    make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /cos284p04

COPY . .

RUN make

CMD ["./main"]


