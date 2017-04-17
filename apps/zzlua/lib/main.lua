--[[ main ]]--

local function execute_chunk(chunk, err)
   if chunk then
      chunk()
   else
      error(err, 0)
   end
end

-- process options

local arg_index = 1
local opt_e = false
while arg_index <= #arg do
   if arg[arg_index] == '-e' then
      opt_e = true
      arg_index = arg_index + 1
      local script = arg[arg_index]
      execute_chunk(loadstring(script))
   else
      -- the first non-option arg is the path of the script to run
      break
   end
   arg_index = arg_index + 1
end

-- run script (from specified file or stdin)

local script_path = arg[arg_index]
local script_args = {}
for i=arg_index+1,#arg do
   table.insert(script_args, arg[i])
end
arg = script_args -- remove framework-specific options

-- save the path of the script to arg[0]
arg[0] = script_path

if opt_e and not script_path then
   -- if there was a script passed in via -e, but we didn't get a
   -- script path on the command line, then don't read from stdin
else
   execute_chunk(loadfile(script_path)) -- loadfile(nil) loads from stdin
end
