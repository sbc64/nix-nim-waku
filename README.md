# [nim waku](waku.org) messaging protocol packaged with [nix](nixos.org)

## Build

```
# Needs to be built on an `amd64-linux` machine
nix-build
/nix/store/y3b2yjp8jv3126lln2yhridd9nq4kb2h-nim-waku-master
```

## Usage

Since it is already packaged with nix, it can be compiled into a `docker` image like this:

```bash
nix-build docker.nix
/nix/store/7y2rv19imcksfbxzl5xm7gj71b4pcdh9-wakunode.tar.gz
```

And load it into docker with

```bash
docker load image -t <image tag> < result
```
