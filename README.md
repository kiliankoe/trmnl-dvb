# trmnl-dvb

A [TRMNL](https://trmnl.com) private plugin that shows upcoming departures for a stop in Dresden's public transport network (DVB/VVO).

TRMNL polls the [VVO departure monitor](https://github.com/kiliankoe/vvo/blob/main/documentation/webapi.md) and renders the Liquid templates in `src/`. The device refreshes about every 15 minutes, so the board shows absolute departure times instead of countdowns. Cancelled departures are struck through.

The plugin has two views, picked in its settings:

- **Grouped by line** (default) shows one row per line and direction with its next four departures, using real-time data where VVO has it. Rows are ordered by their soonest departure. Several times per row keep the board useful even when its first departures have already left.
- **Chronological list** shows one row per departure, with a small `+N` for the delay in minutes.

An optional walking time hides departures you can't reach anymore. It counts from when TRMNL renders the board, which is the time in the bottom bar.

The full and half-horizontal views open a second column only when the content does not fit in one; the narrow views always use one. Rows that do not fit are dropped from the end.

## Finding a stop ID

The plugin needs the numeric VVO stop ID. Look it up with the pointfinder endpoint:

```sh
curl "https://webapi.vvo-online.de/tr/pointfinder?query=albertplatz&stopsOnly=true&format=json"
```

The first field of each entry in `Points` is the ID, e.g. `33000013` for Albertplatz.

## Development

The nix flake provides Ruby, ImageMagick and geckodriver. Firefox comes from the system because nixpkgs has no cached macOS build. With direnv:

```sh
direnv allow
bundle install
bundle exec trmnlp serve   # preview at http://localhost:4567
bundle exec trmnlp test    # renders every view in Firefox against tests/fixtures
bundle exec trmnlp lint
```

`.trmnlp.yml` sets the stop for the local preview. The templates convert times by adding `trmnl.user.utc_offset`, following [TRMNL's documented pattern](https://help.trmnl.com/en/articles/10693981-advanced-liquid). That pattern assumes TRMNL renders in UTC, so the dev shell sets `TZ=UTC` to match.

## Deploying

```sh
bundle exec trmnlp login
bundle exec trmnlp push
```

The first push creates the plugin on TRMNL and rewrites `src/settings.yml` with the server's copy, which includes the new plugin `id`. Commit that change, otherwise the next push creates another plugin. Then set the stop ID in the plugin's settings on TRMNL and add the plugin to a playlist.
