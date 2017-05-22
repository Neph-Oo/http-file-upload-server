#!/bin/lua
local socket = require("socket")
local lfs = require("lfs")
local libserver = assert(string.gsub(string.gsub(arg[0], "bin", "lib"), "file_upload.lua", "server.lua"))
local config = assert(string.gsub(string.gsub(arg[0], "bin", "conf"), "file_upload.lua", "server.conf"))
local init_config = assert(loadfile(config))
local init_server = assert(loadfile(libserver))
init_server()
init_config()


local function get_conf ()
   if not listen_address or not max_clients or not server_root_path
   or not token_secret_key or not port then
      return nil
   end
   client_timeout_delay = client_timeout_delay or 23
   server_request_time = server_request_time or 0.001
   client_request_time = client_request_time or 0.5
   data_chunk_size = data_chunk_size or 16384

   --remove trailing slash
   if string.byte(server_root_path, #server_root_path) == "/" then
      server_root_path = string.sub(server_root_path, 1, #server_root_path - 1)
   end

   if not lfs.chdir(server_root_path) then
      io.stderr:write("Fatal: " .. ({lfs.chdir(server_root_path)})[2])
      os.exit(1)
   end
   return {
      host_addr = listen_address,
      host_port = port,
      co_max = max_clients,
      root_path = server_root_path,
      key = token_secret_key,
      timeout_delay = client_timeout_delay,
      server_req_time = server_request_time,
      client_req_time = client_request_time,
      chunk_size = data_chunk_size
   }
end

---------------------------------------------------

if delete_me then
   io.stderr:write("Rtfm-err: \"delete_me\" == " .. tostring(delete_me) .. "\nPlease edit server.conf\n")
   os.exit(1)
end

conf = get_conf()
if not conf then os.exit(1) end

local server = assert(socket.tcp())
assert(server:bind(conf.host_addr, conf.host_port))
assert(server:listen(30))
assert(server:settimeout(conf.server_req_time))


--local co_max = 5
local co_ctr = conf.co_max
local co_list = {}
local client_request_array = {}
while 1 do
   --if co_max > 0, accept new client/create new coroutine
   if co_ctr == conf.co_max then socket.sleep(0.1) end
   if co_ctr > 0 then
      local client = server:accept()

      --find first empty space for coroutine
      --create coroutine to handle new client
      --resume coroutine once (will yield immediately)
      if client then
         local curr_co = 1
         for i = 1, conf.co_max do
            curr_co = i
            if not co_list[i] then break end
         end

         print("[DEBUG]value of curr_co: " .. curr_co)
         client:settimeout(conf.client_req_time)
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
   for i = 1, conf.co_max do
      co_list[i], client_request_array[i], co_ctr = control_client_coroutine(co_list[i],
                                                      client_request_array[i], client, co_ctr, conf)
   end
end

server:close()

os.exit(0)
