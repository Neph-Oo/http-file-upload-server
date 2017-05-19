#!/bin/lua
local socket = require("socket")
local libserver = assert(string.gsub(string.gsub(arg[0], "bin", "lib"), "file_upload.lua", "server.lua"))
local config = assert(string.gsub(string.gsub(arg[0], "bin", "conf"), "file_upload.lua", "server.conf"))
local init_config = assert(loadfile(config))
local init_server = assert(loadfile(libserver))
init_server()
init_config()


---------------------------------------------------

local server = assert(socket.tcp())
assert(server:bind("127.0.0.1", 1024))
assert(server:listen(10))
assert(server:settimeout(server_request_time))


local co_max = 5
local co_ctr = co_max
local co_list = {}
local client_request_array = {}
while 1 do
   --if co_max > 0, accept new client/create new coroutine
   if co_ctr == co_max then socket.sleep(0.1) end
   if co_ctr > 0 then
      local client = server:accept()

      --find first empty space for coroutine
      --create coroutine to handle new client
      --resume coroutine once (will yield immediately)
      if client then
         local curr_co = 1
         for i = 1, co_max do
            curr_co = i
            if not co_list[i] then break end
         end

         print("[DEBUG]value of curr_co: " .. curr_co)
         client:settimeout(client_request_time)
         co_list[curr_co] = create_client_coroutine()

         --init client coroutine
         coroutine.resume(co_list[curr_co], client)
         client = nil
         co_ctr = co_ctr - 1
      end
   end

   --if there is client pending request, resume it
   --if client isn't ready, yield immediatly and resume next client
   --remove dead coroutines
   for i = 1, co_max do
      co_list[i], client_request_array[i], co_ctr = control_client_coroutine(co_list[i],
                                                      client_request_array[i], client, co_ctr)
   end
   --print("[DEBUG]non blocking io")
end

server:close()

os.exit(0)
