-- Agent <-> DaVinci Resolve mailbox bridge for the FREE edition (21.1+).
-- Free 21.1 blocks external scripting and Scripts-menu/Python scripts; the Lua Console still runs Lua with the
-- full scripting API, but has no io/os.execute/require, and bmd.readstring/writestring are (de)serializers,
-- not file I/O. So requests and replies go through files via LuaJIT ffi + libc.
-- Start (Workspace > Console, Lua tab):  dofile(os.getenv("HOME").."/resolve-bridge/bridge.lua")
-- Client: rv 'lua code'  (print() output and the return value come back). Stop: rv 'stop()'
-- ponytail: polls a file every 100 ms instead of a socket; ffi sockets if latency ever matters.
local C = ffi.C
pcall(ffi.cdef, [[
typedef struct FILE FILE;
FILE *fopen(const char *, const char *);
size_t fread(void *, size_t, size_t, FILE *);
size_t fwrite(const void *, size_t, size_t, FILE *);
int fclose(FILE *);
int rename(const char *, const char *);
int remove(const char *);
]])

local dir = os.getenv("HOME") .. "/resolve-bridge/"
local req, res = dir .. "req.lua", dir .. "res.txt"
resolve = resolve or Resolve()
-- Fusion only scans /usr/share/fonts; without this, Text+ with a user-installed font renders nothing
pcall(function() resolve:Fusion().FontManager:ScanDir(os.getenv("HOME") .. "/.local/share/fonts/") end)

local function read(p)
  local f = C.fopen(p, "rb")
  if f == nil then return nil end
  local buf, out = ffi.new("char[65536]"), {}
  repeat
    local n = tonumber(C.fread(buf, 1, 65536, f))
    out[#out + 1] = ffi.string(buf, n)
  until n < 65536
  C.fclose(f)
  return table.concat(out)
end

local function write(p, s)  -- tmp + rename so the reader never sees a half-written reply
  local f = C.fopen(p .. ".tmp", "wb")
  C.fwrite(s, 1, #s, f)
  C.fclose(f)
  C.rename(p .. ".tmp", p)
end

local function dump(v, d)
  d = d or 0
  if type(v) ~= "table" or d > 4 then return tostring(v) end
  local out, pad = {}, string.rep("  ", d + 1)
  for k, x in pairs(v) do out[#out + 1] = pad .. tostring(k) .. " = " .. dump(x, d + 1) end
  return "{\n" .. table.concat(out, "\n") .. "\n" .. string.rep("  ", d) .. "}"
end

local function reload()
  local ok, lib = pcall(dofile, dir .. "lib.lua")
  if not ok then print("lib.lua failed: " .. tostring(lib)) return R end
  return lib
end
R = reload()

C.remove(req)  -- never replay a request left over from a past session
local running = true
print("resolve bridge: listening on " .. req)
while running do
  local src = read(req)
  if src then
    C.remove(req)
    local id = src:match("^%-%- id:(%S+)") or "?"
    local buf = {}
    local env = setmetatable({
      print = function(...)
        local t = {}
        for i = 1, select("#", ...) do t[i] = dump((select(i, ...))) end
        buf[#buf + 1] = table.concat(t, "\t")
      end,
      stop = function() running = false; return "bridge stopped" end,
      reload = function() R = reload(); return R end,
    }, { __index = _G })
    local f, err = loadstring(src, "req")
    local r = {n = 2, false, err}
    if f then setfenv(f, env); r = (function(...) return {n = select("#", ...), ...} end)(pcall(f)) end
    local t = {}  -- every return value, tab-separated like print (R.render returns status, seconds, path)
    for i = 2, r.n do t[#t + 1] = dump(r[i]) end
    if r.n > 2 or r[2] ~= nil then buf[#buf + 1] = (r[1] and "" or "ERROR: ") .. table.concat(t, "\t") end
    for _, w in ipairs(R.warnings or {}) do buf[#buf + 1] = "WARN " .. w end  -- R.warn: never print() from lib code
    R.warnings = {}
    write(res, "-- id:" .. id .. "\n" .. table.concat(buf, "\n"))
  end
  bmd.wait(0.1)
end
print("resolve bridge: stopped")
