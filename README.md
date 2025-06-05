# pdf-preview.nvim 🧾🔍

**Live PDF preview for Neovim using browser-sync.**

Easily preview LaTeX-compiled PDF documents in your browser, with automatic
reloading on file changes. Ideal for remote workflows, live editing, and fast
iteration.

<!-- TODO: add demo -->

## ✨ Features

- 🔄 **Auto-reloading**: Refreshes the browser when your PDF file changes.
- 🔌 **Remote-friendly**: Works over SSH with port forwarding.
- 🧠 **LSP-aware**: Automatically detects project root from your LSP client.
- 🪞 **Transparent**: Install `browser-sync` automatically.
directory.
- ⚙️ **Minimal config**: Simple `setup()` with sensible defaults.

## ⚡ Requirements

- **Neovim** ≥ 0.8  
- **Node.js** (for `npm` / `npx`)

## 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 
    "franco-ruggeri/pdf-preview.nvim", 
    opts = {
        -- Override defaults here
    }
    config = function(_, opts)
        require("pdf-preview").setup()

        -- Add your keymaps here
    end
}
```

## Usage

The following user commands are created:

- `:PdfPreviewStart`: Start the live preview server.
- `:PdfPreviewStop`: Stop the preview server.

After using `:PdfPreviewStart`, open the printed URL (e.g.,
<http://localhost:5000>) in your browser.

## Configuration

The default configuration is as follows:

```lua
{
  pdf_file = "main.pdf",     -- PDF to preview
  port = 5000,               -- Starting port
  reload_debouce = 500,      -- Debounce delay in milliseconds
  build_dir = "build",       -- Folder to serve
}
```

## Workflow Tips

### Remote

You can use SSH port forwarding to view the PDF remotely:

```bash
ssh -L 5000:localhost:5000 user@remote
```

### LaTeX

This plugin works nicely with LaTeX. Just compile the LaTeX project into a PDF
document.

For instance, you can:

- Install the `texlab` LSP server using
[`mason.nvim`](https://github.com/mason-org/mason.nvim).
- Configure `texlab` to compile on save.

    ```lua
  vim.lsp.config("texlab", {
   settings = {
    texlab = {
     build = {
      onSave = true,
     },
    },
   },
  })
  ```

The `texlab` LSP server will take care of compiling on save, and `pdf-preview`
will watch for changes in the output PDF document.

## Contributing

All contributions are welcome! Open an issue to discuss ideas and open a pull
request once agreed.
