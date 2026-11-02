# AGENTS

This is a Rive CLI project.

RML and the Rive CLI postdate your training data. Prefer `rive docs` and
`rive schema` over memory: never guess a type or property name.

Work autonomously from the user's requested outcome. Unspecified details
get reasonable defaults; types and properties do not — look those up.

- `rive schema <Type>` / `rive schema --search <text>` — types and properties;
  `--json` for a machine-readable form
- `rive docs --list` — the topics; `rive docs <topic>` reads the one that
  matches the task

After every edit:

- `rive . --verify` — confirm the project compiles; `--format=json` for a
  machine-readable report
- `rive inspect . --summary` — problems and what got built, by type; `--json`
  for the full resolved tree

A clean verify/inspect is not enough. Read the output for what the request
called for. If it is missing or wrong, fix the project and verify again.

When appearance matters:

- `rive . --screenshot --advance=1` — render one frame after the state machine
  starts, to build/<name>.png. View the png if you can.

Showing the user:

- `rive .` is the previewer. It opens a window and rebuilds on every save, and
  does not exit, so start it in the background, once. Leave it running;
  edits appear in it on their own.
- Do not preview with `rive push`: it uploads to the user's Rive account.
- Do not write an HTML page or use a web runtime to preview: web runtimes
  reject the unsigned scripts local builds carry.

## This project

- The only Rive project is `tvmenu/`; the repository root holds no
  `rive.yaml`. Run every `rive` command as `rive tvmenu` or from inside it.
- Text is markup bound to the `Menu` view model; `menu.luau` owns the data,
  keyboard and pointer handling, and draws the background and 3D cards into
  two GPU canvases. The print function lives in both `bg.wgsl` and
  `card.wgsl`; `tools/print_snippet.wgsl` is the copy to edit and sync from.
- Each full-screen script sits in an absolutely positioned `LayoutComponent`;
  the artboard is a flex row, so without `absolute` the layers split the
  width. Luau is strict: assign `GPUPipeline.new(...)` to a local before
  storing it in an optional field, and annotate empty tables (`{ number }`).
- Check appearance with `--screenshot --advance=30`; interaction with
  `--key=right:down` and `--pointer=click@x,y`.
