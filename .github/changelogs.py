from itertools import product
import json
import os
import re
import subprocess
import tempfile
import time
from collections import defaultdict
from typing import Any
import sys

REGISTRY = "ghcr.io/venefilyn/"
COSIGN_KEY = (
    "https://raw.githubusercontent.com/Venefilyn/veneos/refs/heads/main/cosign.pub"
)

IMAGE_MATRIX = {
    "veneos": ["stable", "testing"],
    "veneos-server": ["stable", "testing"],
}

RETRIES = 3
RETRY_WAIT = 5
FEDORA_PATTERN = re.compile(r"\.fc\d\d")
EPOCH_PATTERN = re.compile(r"^\d+:")
START_PATTERN = lambda target: re.compile(rf"{target}-\d\d\d+")

PATTERN_ADD = "\n| ✨ | {name} | | {version} |"
PATTERN_CHANGE = "\n| 🔄 | {name} | {prev} | {new} |"
PATTERN_REMOVE = "\n| ❌ | {name} | {version} | |"
PATTERN_PKGREL_CHANGED = "{prev} ➡️ {new}"
PATTERN_PKGREL = "{version}"
COMMON_PAT = "### All Images\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n"
OTHER_NAMES = {
    "stable": "### Stable Images\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n",
    "testing": "### Testing Images\n| | Name | Previous | New |\n| --- | --- | --- | --- |{changes}\n\n",
}

COMMITS_FORMAT = (
    "### Commits\n| Hash | Subject | Author |\n| --- | --- | --- |{commits}\n\n"
)
COMMIT_FORMAT = "\n| **[{short}](https://github.com/Venefilyn/veneos/commit/{githash})** | {subject} | {author} |"

CHANGELOG_TITLE = "{image}:{tag} - {pretty}"
CHANGELOG_FORMAT_SERVER = """\
{handwritten}

From previous `{target}` version `{prev}` there have been the following changes. **One package per new version shown.**

### Major packages
| Name | Version |
| --- | --- |
| **Kernel** | {pkgrel:kernel} |
| **Podman** | {pkgrel:podman} |

### How to rebase
For current users, type the following to rebase to this version:
```bash
# For this Stream
sudo bootc switch --enforce-container-sigpolicy ghcr.io/venefilyn/{image}:{target}

# For this Specific Image:
sudo bootc switch --enforce-container-sigpolicy ghcr.io/venefilyn/{image}:{curr}
```
"""
CHANGELOG_FORMAT_GNOME = """\
{handwritten}

From previous `{target}` version `{prev}` there have been the following changes. **One package per new version shown.**

### Major packages
| Name | Version |
| --- | --- |
| **Kernel** | {pkgrel:kernel} |
| **GNOME** | {pkgrel:gnome-session} |
| **Podman** | {pkgrel:podman} |

### How to rebase
For current users, type the following to rebase to this version:
```bash
# For this Stream
sudo bootc switch --enforce-container-sigpolicy ghcr.io/venefilyn/{image}:{target}

# For this Specific Image:
sudo bootc switch --enforce-container-sigpolicy ghcr.io/venefilyn/{image}:{curr}
```
"""
HANDWRITTEN_PLACEHOLDER = """\
This is an automatically generated changelog for release `{curr}`."""

BLOCKLIST_VERSIONS = [
    "kernel",
    "gnome-session",
    "mesa-filesystem",
    "podman",
]


def get_images():
    return IMAGE_MATRIX.keys()


def get_manifest(img: str, tag: str):
    out = {}
    output = None
    print(f"Getting {img}:{tag} manifest.")
    for i in range(RETRIES):
        try:
            output = subprocess.run(
                ["skopeo", "inspect", f"docker://{REGISTRY}{img}:{tag}"],
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
            break
        except subprocess.CalledProcessError:
            print(
                f"Failed to get {img}:{tag}, retrying in {RETRY_WAIT} seconds ({i + 1}/{RETRIES})"
            )
            time.sleep(RETRY_WAIT)
    if output is None:
        print(f"Failed to get {img}:{tag}")
    out[img] = json.loads(output)
    return out


def get_tags(target: str, manifests: dict[str, Any]):
    """
    >>> imgs = lambda tags: {"veneos": {"RepoTags": tags}}

    When bare and indexed on the same day, indexed wins:
    >>> get_tags("stable", imgs(["stable-20260602.1", "stable-20260609", "stable-20260609.1"]))
    ('stable-20260602.1', 'stable-20260609.1')

    When multiple builds on the same day, highest index wins:
    >>> get_tags("stable", imgs(["stable-20260602.1", "stable-20260609.1", "stable-20260609.2"]))
    ('stable-20260602.1', 'stable-20260609.2')

    Most recent tags as of today:
    >>> get_tags("stable", imgs(["stable-20260526", "stable-20260602", "stable-20260602.1", "stable-20260609", "stable-20260609.1"]))
    ('stable-20260602.1', 'stable-20260609.1')
    """
    # Matches bare date tags (stable-20260609) and indexed tags (stable-20260609.1)
    tag_pattern = re.compile(rf"^{target}\.((\d{{4}})(-\d{{2}}){{2}})$")

    def parse_tag(tag):
        m = tag_pattern.match(tag)
        return (m.group(1), int(m.group(2) or 0)) if m else None

    all_tags = set()
    first = next(iter(manifests.values()))
    for tag in first["RepoTags"]:
        # Tags ending with .0 should not exist
        if tag.endswith(".0"):
            continue
        if parse_tag(tag):
            all_tags.add(tag)

    for manifest in manifests.values():
        for tag in list(all_tags):
            if tag not in manifest["RepoTags"]:
                all_tags.remove(tag)

    # Group by date, keep the highest-indexed tag per date
    by_date = defaultdict(list)
    for tag in all_tags:
        date, idx = parse_tag(tag)
        by_date[date].append((idx, tag))

    flattened = [max(entries)[1] for entries in by_date.values()]
    tags = sorted(flattened, key=parse_tag)

    if len(tags) < 2:
        print("No current and previous tags found")
        sys.exit(1)
    return tags[-2], tags[-1]


def get_image_digest(image: str, tag: str) -> str:
    """Get image digest using skopeo."""
    result = subprocess.run(
        ["skopeo", "inspect", f"docker://{image}:{tag}"],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)["Digest"]


def get_sbom(image: str, digest: str) -> dict:
    """Fetch SBOM using ORAS."""
    full_ref = f"{image}@{digest}"

    # Find the SBOM referrer attached to this image
    result = subprocess.run(
        ["oras", "discover", "--format", "json", full_ref],
        capture_output=True,
        text=True,
        check=True,
    )
    discovered = json.loads(result.stdout)

    sbom_digest = None
    for referrer in discovered.get("referrers", []):
        if "spdx+json" in referrer.get("artifactType", ""):
            sbom_digest = referrer["digest"]
            break

    if sbom_digest is None:
        raise RuntimeError(f"No SBOM referrer found for {full_ref}")

    sbom_ref = f"{image}@{sbom_digest}"

    with tempfile.TemporaryDirectory() as tmpdir:
        subprocess.run(
            ["oras", "pull", sbom_ref],
            capture_output=True,
            check=True,
            cwd=tmpdir,
        )

        for fname in os.listdir(tmpdir):
            fpath = os.path.join(tmpdir, fname)
            if fname.endswith(".zst"):
                result = subprocess.run(
                    ["zstd", "-d", fpath, "--stdout"],
                    capture_output=True,
                    check=True,
                )
                return json.loads(result.stdout)
            elif fname.endswith(".json"):
                with open(fpath) as f:
                    return json.load(f)

    raise RuntimeError(f"No SBOM file found after pulling {sbom_ref}")


def parse_sbom_packages(sbom: dict) -> dict[str, str]:
    packages = {}
    for artifact in sbom.get("artifacts", []):
        # Only process RPM packages
        if artifact.get("type") != "rpm":
            continue
        name = artifact.get("name")
        version = artifact.get("version")
        if name and version:
            # If we see the same package, keep the one with epoch (more specific)
            if name not in packages or (":" in version and ":" not in packages[name]):
                packages[name] = version
    return packages


def get_packages(target: str, img: tuple[str, str, str]):
    packages = {}
    print(f"Getting packages for {img}:{target} via SBOM")
    try:
        full_image = f"{REGISTRY}{img}"
        digest = get_image_digest(full_image, target)
        sbom = get_sbom(full_image, digest)
        packages[img] = parse_sbom_packages(sbom)
        print(f"  Found {len(packages[img])} packages")
    except Exception as e:
        print(f"  Failed to get packages for {img}:{target}: {e}")
        raise e
    return packages


def get_package_groups(image: str, prev_tag: str, curr_tag: str):
    common = set()
    others = {k: set() for k in OTHER_NAMES}

    print(f"\nFetching current packages for {curr_tag}...")
    npkg = get_packages(curr_tag, image)
    print(f"\nFetching previous packages for {prev_tag}...")
    ppkg = get_packages(prev_tag, image)

    keys = set(npkg.keys()) | set(ppkg.keys())
    pkg = defaultdict(set)
    for k in keys:
        pkg[k] = set(npkg.get(k, {})) | set(ppkg.get(k, {}))

    # Find common packages
    first = True
    for img in get_images():
        if img not in pkg:
            continue

        if first:
            for p in pkg[img]:
                common.add(p)
        else:
            for c in common.copy():
                if c not in pkg[img]:
                    common.remove(c)

        first = False

    # Find other packages
    for t, other in others.items():
        first = True
        for img in get_images():
            if img not in pkg:
                continue

            if first:
                for p in pkg[img]:
                    if p not in common:
                        other.add(p)
            else:
                for c in other.copy():
                    if c not in pkg[img]:
                        other.remove(c)

            first = False

    return sorted(common), {k: sorted(v) for k, v in others.items()}, npkg, ppkg


def get_versions(packages: dict[str, dict[str, str]]):
    """Extract version info from packages dict, stripping epoch prefix and Fedora suffix."""
    versions = {}
    for img_pkgs in packages.values():
        for pkg, v in img_pkgs.items():
            # Strip epoch prefix (e.g., "1:25.2.7-1" -> "25.2.7-1")
            v = re.sub(EPOCH_PATTERN, "", v)
            # Strip Fedora version suffix (e.g., ".fc43")
            v = re.sub(FEDORA_PATTERN, "", v)
            versions[pkg] = v
    return versions


def calculate_changes(pkgs: list[str], prev: dict[str, str], curr: dict[str, str]):
    added = []
    changed = []
    removed = []

    blocklist_ver = {curr.get(v, None) for v in BLOCKLIST_VERSIONS}

    for pkg in pkgs:
        # Clearup changelog by removing mentioned packages
        if pkg in BLOCKLIST_VERSIONS:
            continue
        if pkg in curr and curr.get(pkg, None) in blocklist_ver:
            continue
        if pkg in prev and prev.get(pkg, None) in blocklist_ver:
            continue

        if pkg not in prev:
            added.append(pkg)
        elif pkg not in curr:
            removed.append(pkg)
        elif prev[pkg] != curr[pkg]:
            changed.append(pkg)

        blocklist_ver.add(curr.get(pkg, None))
        blocklist_ver.add(prev.get(pkg, None))

    out = ""
    for pkg in added:
        out += PATTERN_ADD.format(name=pkg, version=curr[pkg])
    for pkg in changed:
        out += PATTERN_CHANGE.format(name=pkg, prev=prev[pkg], new=curr[pkg])
    for pkg in removed:
        out += PATTERN_REMOVE.format(name=pkg, version=prev[pkg])
    return out


def get_commits(prev_manifests, manifests, workdir: str):
    try:
        start = next(iter(prev_manifests.values()))["Labels"][
            "org.opencontainers.image.revision"
        ]
        finish = next(iter(manifests.values()))["Labels"][
            "org.opencontainers.image.revision"
        ]

        commits = subprocess.run(
            [
                "git",
                "-C",
                workdir,
                "log",
                "--pretty=format:%H|%h|%an|%s",
                f"{start}..{finish}",
            ],
            check=True,
            stdout=subprocess.PIPE,
        ).stdout.decode("utf-8")

        out = ""
        for commit in commits.split("\n"):
            if not commit:
                continue
            parts = commit.split("|")
            if len(parts) < 4:
                continue
            githash, short, author, subject = parts

            if subject.lower().startswith("merge"):
                continue
            if subject.lower().startswith("chore"):
                continue

            out += (
                COMMIT_FORMAT.replace("{short}", short)
                .replace("{subject}", subject)
                .replace("{githash}", githash)
                .replace("{author}", author)
            )

        if out:
            return COMMITS_FORMAT.format(commits=out)
        return ""
    except Exception as e:
        print(f"Failed to get commits:\n{e}")
        return ""


def generate_changelog(
    handwritten: str | None,
    image: str,
    tag: str,
    pretty: str | None,
    workdir: str,
    prev_tag: str,
    curr_tag: str,
    prev_manifest,
    manifest,
):
    common, others, curr_packages, prev_packages = get_package_groups(
        image, prev_tag, curr_tag
    )
    versions = get_versions(curr_packages)
    prev_versions = get_versions(prev_packages)

    prev, curr = prev_tag, curr_tag

    if not pretty:
        # Generate pretty version since we dont have it
        try:
            finish: str = next(iter(manifest.values()))["Labels"][
                "org.opencontainers.image.revision"
            ]
        except Exception as e:
            print(f"Failed to get finish hash:\n{e}")
            finish = ""
        try:
            linux: str = next(iter(manifest.values()))["Labels"]["ostree.linux"]
            start = linux.find(".fc") + 3
            fedora_version = linux[start : start + 2]
        except Exception as e:
            print(f"Failed to get linux version:\n{e}")
            fedora_version = ""

        # Remove .0 from curr
        curr_pretty = re.sub(r"\.\d{1,2}$", "", curr)
        # Remove target- from curr
        curr_pretty = re.sub(r"^[a-z]+-|^[0-9]+-", "", curr_pretty)
        if not fedora_version + "." in curr_pretty:
            curr_pretty = fedora_version + "." + curr_pretty
        pretty = tag.capitalize()
        pretty += " (F" + curr_pretty
        if finish:
            pretty += ", #" + finish[:7]
        pretty += ")"

    title = CHANGELOG_TITLE.format_map(defaultdict(str, image=image, tag=curr, pretty=pretty))

    if image == "veneos":
        changelog = CHANGELOG_FORMAT_GNOME
    elif image == "veneos-server":
        changelog = CHANGELOG_FORMAT_SERVER

    changelog = (
        changelog.replace(
            "{handwritten}", handwritten if handwritten else HANDWRITTEN_PLACEHOLDER
        )
        .replace("{target}", tag)
        .replace("{prev}", prev)
        .replace("{curr}", curr)
        .replace("{image}", image)
    )

    for pkg, v in versions.items():
        if pkg not in prev_versions or prev_versions[pkg] == v:
            changelog = changelog.replace(
                "{pkgrel:" + pkg + "}", PATTERN_PKGREL.format(version=v)
            )
        else:
            changelog = changelog.replace(
                "{pkgrel:" + pkg + "}",
                PATTERN_PKGREL_CHANGED.format(prev=prev_versions[pkg], new=v),
            )

    changes = ""
    changes += get_commits(prev_manifest, manifest, workdir)
    common = calculate_changes(common, prev_versions, versions)
    if common:
        changes += COMMON_PAT.format(changes=common)
    for k, v in others.items():
        chg = calculate_changes(v, prev_versions, versions)
        if chg:
            changes += OTHER_NAMES[k].format(changes=chg)

    changelog = changelog.replace("{changes}", changes)

    return title, changelog


def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("image", help="Target tag")
    parser.add_argument("tag", help="Target tag")
    parser.add_argument("output", help="Output environment file")
    parser.add_argument("changelog", help="Output changelog file")
    parser.add_argument("--pretty", help="Subject for the changelog")
    parser.add_argument("--workdir", help="Git directory for commits")
    parser.add_argument("--handwritten", help="Handwritten changelog")
    args = parser.parse_args()

    # Remove refs/tags, refs/heads, refs/remotes e.g.
    # Tags cannot include / anyway.
    image = args.image
    tag = args.tag.split("/")[-1]

    if tag in ["main", "latest"]:
        tag = "stable"

    manifest = get_manifest(image, tag)
    prev, curr = get_tags(tag, manifest)
    print(f"Previous tag: {prev}")
    print(f" Current tag: {curr}")

    prev_manifest = get_manifest(image, prev)
    title, changelog = generate_changelog(
        args.handwritten,
        image,
        tag,
        args.pretty,
        args.workdir,
        prev,
        curr,
        prev_manifest,
        manifest,
    )

    print(f"Changelog:\n# {title}\n{changelog}")
    print(f'\nOutput:\nTITLE="{title}"\nTAG={curr}')

    with open(args.changelog, "w") as f:
        f.write(changelog)

    with open(args.output, "w") as f:
        f.write(f'TITLE="{title}"\nTAG={curr}\n')


if __name__ == "__main__":
    main()
