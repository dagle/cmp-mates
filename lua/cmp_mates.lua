local Job = require("plenary.job")

if vim.fn.executable("mates") ~= 1 then
	vim.api.nvim_err_writeln("Error can't found the mates executable, needed for cmp-mates")
	return
end

local completion_pattern =  "\\c^\\(Resent-\\)\\?\\(To\\|B\\?Cc\\|Reply-To\\|From\\|Mail-Followup-To\\|Mail-Copies-To\\):"

local defaults = {
  line_pattern = completion_pattern,
}

local source = {}

source.new = function()
	return setmetatable({ cache = {} }, {
		__index = source,
	})
end

---Return this source is available in current context or not. (Optional)
---@return boolean
function source:is_available()
	return vim.bo.filetype == "mail"
end

---Return the debug name of this source. (Optional)
---@return string
function source:get_debug_name()
	return "notmuch_vcard"
end

---Return keyword pattern for triggering completion. (Optional)
---If this is ommited, nvim-cmp will use default keyword pattern. See |cmp-config.completion.keyword_pattern|
---@return string
function source:get_keyword_pattern(params)
	local opts = vim.tbl_deep_extend('keep', params.option, defaults)
	return [[\K\+]]
end

---Return trigger characters for triggering completion. (Optional)
-- can we make this work, so @ is part of the match?
-- function source:get_trigger_characters()
-- 	return { '@' }
-- end

---Invoke completion. (Required)
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(params, callback)
	local bufnr = vim.api.nvim_get_current_buf()
	local opts = vim.tbl_deep_extend('keep', params.option, defaults)

	if not (vim.fn.match(params.context.cursor_before_line, opts.line_pattern) >= 0) then
		return
	end

	if not self.cache[bufnr] then
		Job
			:new({
				command = "mates",
				args = {
					"email-query",
				},
				on_exit = function(j, ret_val)
					if ret_val ~= 0 then
						callback(nil)
						return
					end
					local ret = j:result()
					local tbl = {}
					for _, mbox in ipairs(ret) do
						table.insert(tbl, {
							label = mbox,
						})
					end
					self.cache[bufnr] = tbl
					callback(self.cache[bufnr])
				end,
			})
			:start()
	else
		callback(self.cache[bufnr])
	end
end

---Resolve completion item. (Optional)
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:resolve(completion_item, callback)
	callback(completion_item)
end

---Execute command after item was accepted.
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:execute(completion_item, callback)
	callback(completion_item)
end

return source
