local M = {}

local DEFAULT_OPTS = {
	port = nil,
	reload_debouce = 500,
}

local data_path = vim.fn.stdpath("data") .. "/pdf-preview"
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

local function start_preview(pdf_filepath)
	-- Create the server directory (a temporary directory to serve)
	local server_root_path = vim.fn.tempname()
	vim.fn.mkdir(server_root_path, "p")

	-- Symlink the PDF file in the server directory
	local pdf_filename = vim.fs.basename(pdf_filepath)
	local server_pdf_filepath = ("%s/%s"):format(server_root_path, pdf_filename)
	if not vim.uv.fs_symlink(pdf_filepath, server_pdf_filepath, nil) then
		error("Failed to symlink PDF file: " .. server_pdf_filepath)
	end

	-- Create HTML page wrapping the PDF
	local html_filepath = server_root_path .. "/index.html"
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
		pdf_filename
	)
	local html_file = io.open(html_filepath, "w")
	if not html_file then
		error("Could not open file for writing: " .. html_filepath)
	end
	html_file:write(html_content)
	html_file:close()

	-- Start browser-sync server
	local command = {
		"npx",
		"browser-sync",
		"start",
		"--server",
		server_root_path,
		"--reload-debounce",
		tostring(M.opts.reload_debouce),
		"--watch",
		"--no-ui",
		"--no-open",
	}
	if M.opts.port then
		table.insert(command, "--port")
		table.insert(command, tostring(M.opts.port))
	end
	server_process = vim.fn.jobstart(command, {
		cwd = data_path,
		pty = true,
		on_stdout = function(_, data, _)
			-- The port can be different from the one configured in the options in two cases:
			-- * If the port is nil, browser-sync will choose a random available port.
			-- * If the configured port is already in use, browser-sync will increment the port until it finds one available.
			--
			-- So, to output the correct port, we need to parse the output.
			local port = nil
			for _, line in ipairs(data) do
				port = line:match("http://localhost:(%d+)")
				if port then
					vim.notify("PDF preview started")
					vim.notify("Connect at http://localhost:" .. port, vim.log.levels.INFO)
					break
				end
			end
		end,
	})
end

M.start_preview = function()
	if server_process then
		vim.notify("PDF preview is already running", vim.log.levels.INFO)
		return
	end

	local cwd = vim.fn.getcwd()
	vim.ui.input({
		prompt = ("Enter the PDF filepath: %s/"):format(cwd),
		completion = "file",
	}, function(input)
		if input then
			local pdf_filepath = cwd .. "/" .. input
			start_preview(pdf_filepath)
		end
	end)
end

M.stop_preview = function()
	if not server_process then
		vim.notify("PDF preview is not running", vim.log.levels.INFO)
		return
	end

	if server_process then
		vim.fn.jobstop(server_process)
		server_process = nil
	end

	vim.notify("PDF preview stopped", vim.log.levels.INFO)
end

M.toggle_preview = function()
	if server_process then
		M.stop_preview()
	else
		M.start_preview()
	end
end

M.setup = function(opts)
	M.opts = vim.tbl_deep_extend("force", DEFAULT_OPTS, opts or {})

	install_browser_sync()

	vim.api.nvim_create_user_command("PdfPreviewStart", M.start_preview, {})
	vim.api.nvim_create_user_command("PdfPreviewStop", M.stop_preview, {})
	vim.api.nvim_create_user_command("PdfPreviewToggle", M.toggle_preview, {})
end

return M
