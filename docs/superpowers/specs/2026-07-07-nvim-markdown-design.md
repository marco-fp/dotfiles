# Beautiful, editable in-editor Markdown for Neovim

Date: 2026-07-07
Status: implemented (marksman pending user rebuild)

## Context

Marco does a lot of markdown review and authoring and wants markdown to render
richly *inside* Neovim (headings, code blocks, callouts, tables, checkboxes)
while staying live-editable, with raw syntax revealed on the line being edited.
No browser, no separate preview. The prior config had a clean lazy.nvim setup
(Nord, snacks, oil, neogit, gitsigns) but zero markdown support.

## Decisions

- Renderer: **render-markdown.nvim**. Both it and markview.nvim were prototyped on
  branches and compared live. markview's insert-mode hybrid re-rendering (raw on
  the cursor line while the rest stays rendered) felt janky during editing;
  render-markdown's default -- render in normal mode with the cursor line shown
  raw via anti-conceal, plain raw text while in insert -- was smoother. Chosen.
- Extras: **editing ergonomics**, **table editing**, **cross-file nav (marksman LSP)**.
  Distraction-free writing (zen-mode) was declined.

## Environment findings that shaped the build

Exploration overturned the initial version assumption:

- Two neovim binaries existed. An **undeclared homebrew nvim (0.10.2)** shadowed
  the **nix-managed nvim** on PATH. `home.nix` already declares `neovim`, so the
  homebrew one was cruft. Resolved by `brew uninstall neovim`; `nvim` now resolves
  to the nix build.
- The nix-managed neovim is **0.12.3** and **bundles the `markdown` +
  `markdown_inline` treesitter parsers** (verified: both parse out of the box).
  So **nvim-treesitter is not needed** -- render-markdown works straight off the
  built-in parse tree. No runtime parser compilation, no branch pinning.
- No flake bump was required; the pinned nixpkgs already provides 0.12.3.

## Final stack

| Layer | Plugin / package | Role |
|---|---|---|
| Runtime | neovim 0.12.3 (nix, already installed) | bundles md parsers; native LSP completion + default LSP keymaps |
| Renderer | `MeanderingProgrammer/render-markdown.nvim` | in-editor rendering, cursor-line anti-conceal |
| Editing | `tadmccorkle/markdown.nvim` | toggle emphasis, follow links, list continue, TOC |
| Tables | `dhruvasagar/vim-table-mode` | align pipes as you type, Tab between cells |
| Navigation | `marksman` LSP via `neovim/nvim-lspconfig` | definitions, references, rename, hover, anchor completion |

render-markdown uses its tuned defaults (`opts = {}`). Effect: normal mode renders
fully (for review) with the cursor line shown raw so you edit in place; insert mode
shows raw text. To also render while editing, set `render_modes = { 'n', 'c', 'i' }`.

marksman is wired with the native 0.11+ API (`vim.lsp.config` + `vim.lsp.enable`),
not the deprecated `lspconfig.setup()`. 0.12 already maps `grn`/`gra`/`K` on
attach, so only anchor completion (`vim.lsp.completion.enable`, autotrigger) and a
snacks-consistent `grr` (references) are added. `gd` stays mapped to the snacks
picker in `navigation.lua` (unchanged).

nvim-treesitter is intentionally omitted. A `FileType markdown` autocmd calls
`vim.treesitter.start()` so the raw text left visible (cursor line, inline code)
gets treesitter highlighting from the bundled parsers.

## Files

- `home/.config/nvim/lua/plugins/markdown.lua` (new) -- the four-plugin lazy spec
  plus the marksman LSP setup and the treesitter-start autocmd. Symlinked
  edit-in-place, so a nvim restart picks it up; no rebuild.
- `home.nix` -- add `marksman` to `home.packages`. This is the only piece needing
  `./rebuild.sh`.
- No change to `navigation.lua`; `gd` already routes to the snacks picker.

## Rebuild boundary

- Lua plugins are already installed (via `:Lazy install`) and work now on 0.12.3.
- `marksman` (the LSP binary) needs `./rebuild.sh` (user's sudo run). Until then
  the LSP config loads but the server does not attach (verified: no errors, just
  no attach).

## Verification

Both renderers were tested headless against nvim 0.12.3 on a sample markdown file;
render-markdown (the chosen one) reported:

- render-markdown loaded and placed 27 render extmarks on the buffer; no errors in
  `:messages`.
- `markdown.nvim` loaded; `:TableModeToggle` and `:RenderMarkdown` commands present.
- treesitter highlighting active on the markdown buffer (bundled parser).
- `lsp/marksman.lua` present on runtimepath; marksman degrades gracefully while
  the binary is absent.

Manual confirmation for the user after `./rebuild.sh` + nvim restart:

- Open a `.md`: headings, code blocks, callouts, tables, checkboxes render; the
  cursor line shows raw markdown so you can edit it in place.
- `:TableModeToggle`, type a row -> pipes auto-align; Tab moves between cells.
- `gd` on `[link](other.md)` jumps files; typing `#` offers heading-anchor
  completion; `grr`/`grn`/`K` work.

## Known limitations

- Code fences of languages other than markdown get render-markdown's block styling
  but no inner syntax highlighting (only markdown parsers are bundled). Add
  nvim-treesitter (`main` branch) + specific parsers later if wanted.

## Rollback

- Revert the commit; `git checkout` the changed files.
- Restore the old editor if desired: `brew reinstall neovim`.
