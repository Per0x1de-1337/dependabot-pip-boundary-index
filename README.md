# Dependabot pip boundary validation fixture

This repository is a static PEP 503 index for a benign, isolated Dependabot validation.

Enable GitHub Pages from the `main` branch repository root. The expected simple-index URL is:

`https://per0x1de-1337.github.io/dependabot-pip-boundary-index/simple/`

Copy `victim/.github/dependabot.yml` and `victim/pip/` into the separate victim repository. The dependency group is intentional: Dependabot processes `group.dependencies` in parsed manifest order, so the candidate is evaluated before the ordinary host update without relying on the ungrouped-update shuffle.

`victim-cross-scope/` is the stronger variant. It places the attacker-controlled candidate only in `00-requirements-dev.*`, while the ordinary host and injected runtime package land in `99-requirements.*`. The numeric filenames make the parsed/group order explicit. A production install of `99-requirements.txt` never includes the original candidate package.

Expected result if the boundary crossing survives the hosted API:

- `db-boundary-candidate` 1.0.1 fails and is absent from the PR.
- `db-boundary-host` updates from 1.0.0 to 1.0.1.
- `pip/requirements.txt` unexpectedly gains `db-boundary-runtime==1.0.0`, annotated as if it were transitive.
- `pip/requirements.in` does not contain `db-boundary-runtime`.

The runtime package only writes a benign marker when `DEPENDABOT_PRODUCTION_MARKER` is explicitly set.
