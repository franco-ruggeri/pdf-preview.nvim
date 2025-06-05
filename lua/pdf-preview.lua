-- TODO: test again that the process stops when existing nvim, I removed the handler, but it should still work
local M = {}

local data_path = vim.fn.stdpath("data") .. "/pdf-preview"

M.opts = {
	pdf_file = "main.pdf",
	port = 5000,
	reload_debouce = 500,
}

local server_process = nil

local function install_browser_sync()
	local result = nil

	-- Ensure the data directory exists
	vim.fn.mkdir(data_path, "p")

	-- Initialize npm
	if not vim.uv.fs_stat(data_path .. "/package.json") then
		result = vim.system({ "npm", "init", "-y" }, { cwd = data_path }):wait()
		if result.code ~= 0 then
			error("Failed to initialize npm: " .. result.stderr)
		end
	end

	-- Check if browser-sync is already installed
	result = vim.system({ "npm", "list", "browser-sync" }, { cwd = data_path }):wait()
	if result.code == 0 then
		return
	end

	-- Install browser-sync
	result = vim.system({ "npm", "install", "browser-sync" }, { cwd = data_path }):wait()
	if result.code ~= 0 then
		error("Failed to install browser-sync: " .. result.stderr)
	else
		vim.notify("Browser-sync successfully installed", vim.log.levels.INFO)
	end
end

M.running = false

M.start_preview = function()
	if M.running then
		vim.notify("LaTeX preview is already running", vim.log.levels.INFO)
		return
	end

	-- Get root directory from LSP client
	local lsp_clients = vim.lsp.get_clients()
	if #lsp_clients == 0 then
		error("No LSP client found.")
	end
	local root_dir = lsp_clients[1].root_dir

	-- Start browser-sync server
	-- TODO: need to store index.html somewhere in the data dir, but pointing to the pdf file
	local server_path = root_dir .. "/" .. M.opts.build_dir
	vim.fn.mkdir(server_path, "p")
	server_process = vim.fn.jobstart({
		"npx",
		"browser-sync",
		"start",
		"--server",
		server_path,
		"--files",
		M.opts.pdf_file,
		"--port",
		string(M.opts.port),
		"--reload-debounce",
		string(M.opts.reload_debouce),
		"--watch",
		"--no-ui",
		"--no-open",
	}, {
		cwd = data_path,
		pty = true,
		on_stdout = function(_, data, _)
			-- If the configured port is already in use, browser-sync increments the port until it finds one available
			-- To output the correct port, we need to parse the output
			local port = nil
			for _, line in ipairs(data) do
				port = line:match("http://localhost:(%d+)")
				if port then
					vim.notify("Connect at http://localhost:" .. port, vim.log.levels.INFO)
					break
				end
			end
		end,
	})

	-- Create HTML page wrapping the PDF
	local html_file = M.opts.build_dir .. "/index.html"
	if not vim.uv.fs_stat(html_file) then
		local html_content = string.format(
			[[
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>PDF Preview</title>
  <style>
    html, body { margin: 0; height: 100%%; overflow: hidden; }
    iframe { width: 100%%; height: 100%%; border: none; }
  </style>
</head>
<body>
  <iframe src="%s"></iframe>
</body>
</html>
]],
			M.opts.pdf_file
		)
		local file = io.open(html_file, "w")
		if not file then
			error("Could not open file for writing: " .. html_file)
		end
		file:write(html_content)
		file:close()
	end

	M.running = true
	vim.notify("LaTeX preview server")
end

M.stop_preview = function()
	if not M.running then
		vim.notify("LaTeX preview is not running", vim.log.levels.INFO)
		return
	end

	if server_process then
		vim.fn.jobstop(server_process)
		server_process = nil
	end

	M.running = false
	vim.notify("LaTeX preview server stopped", vim.log.levels.INFO)
end

M.setup = function(opts)
	M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})

	install_browser_sync()

	vim.api.nvim_create_user_command("LatexPreviewStart", M.start_preview, {})
	vim.api.nvim_create_user_command("LatexPreviewStop", M.stop_preview, {})
end

return M
