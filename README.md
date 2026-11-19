# nginx_build

custom nginx docker builder

The VOD module uses the public `dio-az/nginx-vod-module` mirror because the
original Kaltura repository is unavailable. It is pinned to the original
submodule commit `26f06877b0f2a2336e59cda93a3de18d7b23a3e2`.

Run `bash tests/source_fetch.sh` to check source-fetch failure handling and
pinned/detached checkouts. Pull requests build both nginx tracks for amd64 and
arm64 without publishing images. Pushes to `main` and manual builds publish only
when all four repository Actions Secrets are configured:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `QUAY_USERNAME`
- `QUAY_TOKEN`

Without these Secrets, the full build matrix runs without registry login or
image publication. Automatic version checks use the built-in `GITHUB_TOKEN`
and explicitly start a build after committing an update; no personal access
token is required.

GeoIP databases are stored in Git LFS and included by the build checkout.
