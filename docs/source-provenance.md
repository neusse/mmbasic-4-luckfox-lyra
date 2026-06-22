# Source Provenance

## Upstream Source

This project uses MMB4L as its Linux MMBasic base.

- Repository: https://github.com/thwill1000/mmb4l
- Local path: `mmb4l/`
- Integration method: Git submodule
- Current pinned commit: `20367c75b74987bcb0e7051070325d0b61fab495`

MMB4L is authored by Thomas Hugo Williams and upstream contributors. This
project should preserve that attribution in public documentation, release notes,
and any future fork.

## Nested Source

MMB4L includes `sptools` as a nested submodule.

- Repository: https://github.com/thwill1000/mmbasic-sptools
- Local path: `mmb4l/sptools/`
- Current pinned commit: `99c18569ee3438dbf09c3e8571add1fd53052398`

## Verification Commands

```powershell
git submodule status --recursive
git -C .\mmb4l remote -v
git -C .\mmb4l log -1 --oneline
git -C .\mmb4l\sptools remote -v
git -C .\mmb4l\sptools log -1 --oneline
```

The clone should not be shallow. Resolve Git's actual storage directories first
because submodules may use either a `.git` directory or a gitdir pointer:

```powershell
$mmb4lGit = git -C .\mmb4l rev-parse --git-dir
$sptoolsGit = git -C .\mmb4l\sptools rev-parse --git-dir
Test-Path (Join-Path .\mmb4l $mmb4lGit 'shallow')
Test-Path (Join-Path .\mmb4l\sptools $sptoolsGit 'shallow')
```

Both commands should return `False` or the path should not exist.

## Local Changes Policy

Do not edit upstream source in `mmb4l/` without also capturing the change as a
repeatable patch under `patches/mmb4l/`.

Short-term model:

1. Keep `mmb4l/` pinned to a known upstream commit.
2. Store project changes as patch files in `patches/mmb4l/`.
3. Apply patches during setup/build.
4. Document each patch's purpose and upstream status.

Long-term model:

If this project needs ongoing source development, create a fork of MMB4L, point
the submodule at that fork, and keep the original upstream attribution.

## Licenses

The upstream licenses live inside the submodule and continue to govern upstream
source:

- `mmb4l/LICENSE`
- `mmb4l/LICENSE.MIT`
- `mmb4l/LICENSE.MMBasic`
- `mmb4l/sptools/LICENSE`

Do not remove or rewrite those license files.
