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

	-- Create HTML page wrapping the PDF
	local server_path = vim.fn.tempname()
	vim.fn.mkdir(server_path, "p")
	local html_filepath = server_path .. "/index.html"
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
	local html_file = io.open(html_filepath, "w")
	if not html_file then
		error("Could not open file for writing: " .. html_filepath)
	end
	html_file:write(html_content)
	html_file:close()

	-- Start browser-sync server
	print(server_path)
	server_process = vim.fn.jobstart({
		"npx",
		"browser-sync",
		"start",
		"--server",
		server_path,
		"--files",
		M.opts.pdf_file,
		"--port",
		tostring(M.opts.port),
		"--reload-debounce",
		tostring(M.opts.reload_debouce),
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

	vim.api.nvim_create_user_command("PdfPreviewStart", M.start_preview, {})
	vim.api.nvim_create_user_command("PdfPreviewStop", M.stop_preview, {})
end

return M
