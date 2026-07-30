# Media Library Maintenance

This document tracks periodic cleanup tasks for Jellyfin media after new downloads/imports.

## Goal

Keep imported media pleasant to use in Jellyfin without having to fix every playback issue manually.

Primary checks:

- English audio should be selected by default when an English track exists.
- Non-English tracks should not be marked as default unless intentionally preferred.
- Commentary tracks should not be selected as the default main audio track.
- Jellyfin should be able to reach the plugin catalog and other online metadata/plugin resources.

## When to run

Run this occasionally, especially:

- After importing a large batch of movies or shows.
- After seeing Jellyfin start playback in the wrong language.
- After grabbing releases from unfamiliar sources or uploaders.
- Before inviting other users to watch newly imported media.

A good lightweight cadence is monthly or after any large import batch.

## Audio default scan

Install required tools if needed:

```bash
sudo apt update
sudo apt install -y mkvtoolnix jq
```

Find MKV movie files that have English audio but default to a non-English track:

```bash
find /mnt/storage/media/movies -type f -iname "*.mkv" -print0 | while IFS= read -r -d '' file; do
  bad=$(mkvmerge -J "$file" | jq -r '
    def audios: [.tracks[] | select(.type=="audio")];
    {
      has_eng: (audios | any(.properties.language == "eng")),
      bad_default: (audios | any((.properties.default_track == true) and (.properties.language != "eng")))
    }
    | select(.has_eng and .bad_default)
    | "bad"
  ')
  if [ "$bad" = "bad" ]; then
    echo "$file"
  fi
done
```

For a detailed view of one file's audio tracks:

```bash
mkvmerge -J "/path/to/movie.mkv" | jq -r '
  .tracks[]
  | select(.type=="audio")
  | "track_id=\(.id) language=\(.properties.language // "unknown") default=\(.properties.default_track // false) name=\(.properties.track_name // "")"
'
```

## Fixing one MKV

Use `mkvpropedit` to adjust default flags without fully remuxing the movie.

Example pattern only; confirm track numbers before running:

```bash
mkvpropedit "/path/to/movie.mkv" \
  --edit track:a1 --set flag-default=0 \
  --edit track:a2 --set flag-default=1
```

Important: `track:a1`, `track:a2`, etc. refer to the audio track order in MKVToolNix, not necessarily the same stream index shown by ffprobe. Always inspect first.

## Known fixes already completed

The following issue pattern was confirmed and fixed:

- A movie had Russian marked as the default audio track while English existed but was not default.
- The file was fixed with `mkvpropedit` by setting the Russian audio default flag to `0` and the English audio default flag to `1`.

Examples fixed during initial cleanup:

- `The Dark Knight Rises (2012)` had Russian default and English not default; English was changed to default.
- `Zootopia 2` 1080p and 2160p files had Russian default and English not default; English was changed to default.

## Jellyfin after changing audio flags

After editing files, refresh Jellyfin:

```text
Jellyfin -> Dashboard -> Libraries -> Movies -> Scan Library
```

For one movie:

```text
Movie page -> three dots/menu -> Refresh metadata
```

If playback was already cached, stop playback completely, reopen the movie, and manually switch audio once if needed.

## Jellyfin plugin catalog DNS check

Jellyfin previously could not load plugins because the container could not resolve `repo.jellyfin.org`.

The fix was to add explicit DNS to the `jellyfin` service in Docker Compose:

```yaml
dns:
  - 192.168.10.135
```

Test from inside Jellyfin's network namespace:

```bash
docker run --rm --network=container:jellyfin curlimages/curl:latest \
  -I https://repo.jellyfin.org/files/plugin/manifest.json
```

A working result may return `HTTP/2 302` to a mirror, then `curl -L` should download the manifest JSON.

## Safety notes

- Do not mass-edit every MKV blindly.
- Confirm the English track is the real main audio track, not commentary or descriptive audio.
- Avoid changing commentary-only extras unless they actually need fixing.
- Do not edit files while Radarr/Sonarr/qBittorrent are actively importing the same file.
