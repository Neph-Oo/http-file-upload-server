local lfs = require("lfs")
local headers = assert(string.gsub(string.gsub(arg[0], "bin", "data"), "file_upload.lua", "http-headers.lua"))
local libhmac = assert(string.gsub(string.gsub(arg[0], "bin", "lib"), "file_upload.lua", "hmac.lua"))
local init_headers = assert(loadfile(headers))
local init_hmac = assert(loadfile(libhmac))
init_headers()
init_hmac()

local function get_file_size (file)
   local old_pos = file:seek()
   local size = file:seek("end")
   file:seek("set", old_pos)
   return size
end


local function set_header_error (err)
   local error_base = http_header.error[err]
   error_base[5] = error_base[5] .. string.gsub(os.date(), "(%w+)(.+)", "%1,%2 GMT") .. "\r\n"
   return table.concat(error_base)
end


local function openfile (client, client_request, conf)
   local file = io.open(client_request.filename, "rb")
   if not file then
      client_request.header_answer = set_header_error(404)
      client_request.data_block_answer = err404_data
      return client_request
   end

   client_request.data_tot_length = get_file_size(file)
   http_header.base[5] = http_header.base[5] .. client_request.data_tot_length .. "\r\n"
   http_header.base[2] = http_header.base[2] .. string.gsub(os.date(), "(%w+)(.+)", "%1,%2 GMT") .. "\r\n"
   client_request.header_answer = table.concat(http_header.base)
   http_header.base[5] = "Content-Length: "
   http_header.base[2] = "Date: "
   client_request.file = file

   return client_request
end


local function verify_client_signature (client_request, conf)
   --get content length from header, else send error 400
   --verify client signature

   for i = 1, #client_request.header do
      local s, e = string.find(client_request.header[i], "Content%-Length: ")
      if s and e then
         s = e + 1
         client_request.data_tot_length =
            tonumber(string.sub(client_request.header[i], s, #client_request.header[i]))
         break
      end
   end
   if client_request.data_tot_length < 1 then
      client_request.header_answer = set_header_error(400)
      client_request.req_validity = "invalid"
      return client_request
   end

   --concat filename,space,data_length
   local data_concat = client_request.filename .. "\x20" .. tostring(client_request.data_tot_length)
   local data_sig = hmac_sha256(data_concat, conf.key)
   if data_sig ~= client_request.cl_sig then
      client_request.header_answer = set_header_error(403)
      client_request.data_block_answer = err403_data
      return client_request
   end

   return client_request
end


local function createfile (client_request, conf)
   --verify file doesn't exist, create file
   if not lfs.mkdir(client_request.upload_dir) then
      client_request.header_answer = set_header_error(409)
      client_request.data_block_answer = err409_data
      return client_request
   end

   local file = io.open(client_request.filename, "rb")
   if file then
      client_request.header_answer = set_header_error(409)
      client_request.data_block_answer = err409_data
      return client_request
   end
   client_request.file = io.open(client_request.filename, "wb")

   return client_request
end


local function remove_fucking_line_feed (data)
   local k = 1
   local newline = 0
   for i = 1, 4 do
      local byte = string.byte(data, i)
      if byte == 0x0D or byte == 0x0A then
         k = k + 1
         if byte == 0x0A then newline = newline + 1 end
         if newline >= 2 then break end
      end
   end
   data = string.sub(data, k, #data)

   return data
end


local function fetch_header (client_request)
   --fetch header
   local i = #client_request.header + 1
   for line in string.gmatch(client_request.data_tmp, "[\x20A-Za-z:0-9*;?,+()=./_-]+") do
      if i > 50 then break end
      if #line > 4096 then
         --denial of service, drop client
         client_request.req_validity = "invalid"
         return client_request
      end
      client_request.header[i] = line
      i = i + 1
   end

   return client_request
end


local function parse_get_head_req (client_request)
   client_request.upload_dir =
      string.match(client_request.header[1], "/[\x20A-Za-z:0-9;?,+()=_-]+/")
   if not client_request.upload_dir then
      client_request.req_validity = "invalid"
      return client_request
   end
   client_request.upload_dir = string.sub(client_request.upload_dir, 2, #client_request.upload_dir - 1)

   client_request.filename = string.match(client_request.header[1], "/[\x20A-Za-z:0-9;?,+()=._-]+ ")
   if not client_request.filename or string.match(client_request.filename, "%.%.$") then
      client_request.req_validity = "invalid"
      return client_request
   end
   client_request.filename = string.sub(client_request.filename, 2, #client_request.filename - 1)

   return client_request
end


local function parse_put_req (client_request)
   client_request.upload_dir =
      string.match(client_request.header[1], "/[\x20A-Za-z:0-9;?,+()=_-]+/")
   if not client_request.upload_dir then
      client_request.req_validity = "invalid"
      return client_request
   end
   client_request.upload_dir = string.sub(client_request.upload_dir, 2, #client_request.upload_dir - 1)

   client_request.filename =
      string.match(client_request.header[1], "[\x20A-Za-z:0-9;?,+()=._-]+?v=")
   if not client_request.filename or string.match(client_request.filename, "%.%.$") then
      client_request.req_validity = "invalid"
      return client_request
   end
   client_request.filename = string.sub(client_request.filename, 1, #client_request.filename - 3)

   client_request.cl_sig = string.find(client_request.header[1], "?") + 3
   if not client_request.cl_sig then
      client_request.req_validity = "invalid"
      return client_request
   end
   client_request.cl_sig =
      string.sub(client_request.header[1], client_request.cl_sig, client_request.cl_sig + 63)

   return client_request
end


local function parse_client_request (client, client_request)
   --check request validity
   if client_request.header[1] and client_request.req_type == "" then
      if string.match(client_request.header[1],
         "GET /[\x20A-Za-z:0-9;?,+()=_-]+/[\x20A-Za-z:0-9;?,+()=._-]+ HTTP/1.[0-1]") then

         client_request = parse_get_head_req(client_request)
         if client_request.req_validity == "invalid" then return client_request end

         client_request.req_type = "get"
      elseif string.match(client_request.header[1],
         "PUT /[\x20A-Za-z:0-9;?,+()=_-]+/[\x20A-Za-z:0-9;?,+()=._-]+ HTTP/1.[0-1]") then
         --get hmac signature and filename, else, invalid request
         --verify hmac with secret key and request header, else send 403 forbiden
         --if file/dir exist, send 409 conflict

         client_request = parse_put_req(client_request)
         if client_request.req_validity == "invalid" then return client_request end

         client_request.req_type = "put"
      elseif string.match(client_request.header[1],
         "HEAD /[\x20A-Za-z:0-9;?,+()=_-]+/[\x20A-Za-z:0-9;?,+()=._-]+ HTTP/1.[0-1]") then
         --check if file exist, else send error 404
         --send header and close connection

         client_request = parse_get_head_req(client_request)
         if client_request.req_validity == "invalid" then return client_request end

         client_request.req_type = "head"
      else
         --invalid request, send error 400 and return ??
         local err = set_header_error(400)
         if client then
            client:send(err)
         end
         client_request.req_validity = "invalid"
         return client_request
      end
   end

   return client_request
end


local function verify_header_validity (client, client_request, conf)
   --check header validity
   if string.match(client_request.data_tmp, ".*\r*\n\r*\n")
   or string.match(client_request.data_tmp, "^\r*\n") then
      --verify header, execute request (send header)
      if client then
         if client_request.req_type == "get" then
            client_request.filename = client_request.upload_dir .. "/" .. client_request.filename
            client_request = openfile(client, client_request, conf)
            client_request.req_validity = "valid"
            client:send(client_request.header_answer)
         elseif client_request.req_type == "head" then
            client_request.filename = client_request.upload_dir .. "/" .. client_request.filename
            client_request = openfile(client, client_request, conf)
            client_request.req_validity = "terminated"
            client:send(client_request.header_answer)
            if client_request.file then
               client_request.file:close()
            end
            client_request.file = nil
         elseif client_request.req_type == "put" then
            client_request.filename = client_request.upload_dir .. "/" .. client_request.filename
            client_request = verify_client_signature(client_request, conf)
            if client_request.req_validity ~= "invalid" then
               if client_request.data_block_answer == "" then
                  client_request = createfile(client_request, conf)
               end
               --remove header from data_tmp
               --copy and add length of data already received (can't be longer than 4096)
               client_request.req_validity = "continue"
               client_request.data_tmp = string.match(client_request.data_tmp, "\r*\n\r*\n.+")
               or string.match(client_request.data_tmp, "^\r*\n")
               --really hate fucking OVERcomplicated regex, so
               client_request.data_tmp = remove_fucking_line_feed(client_request.data_tmp)
            end
            --will be blank in case of success
            client:send(client_request.header_answer)
         end
      end
   end

   return client_request
end


local function send_data_to_client (client, client_request)
   local bytes_sent, err, last_idx =
      client:send(client_request.data_block_answer, 1, #client_request.data_block_answer)

   while bytes_sent ~= #client_request.data_block_answer do
      if err == "closed" then
         --fatal
         client_request.req_validity = "invalid"
         return client_request
      else
         --send last bytes
         bytes_sent, err, last_idx =
            client:send(client_request.data_block_answer, last_idx + 1, #client_request.data_block_answer)
      end
   end

   return client_request
end



local function exec_request (client, client_request, conf)
   if (client_request.req_validity == "valid" or client_request.req_validity == "continue") and client then
      if client_request.req_type == "get" then
         if client_request.file and client_request.data_length < client_request.data_tot_length then
            client_request.data_block_answer = client_request.file:read(conf.chunk_size)
            client_request.data_length = client_request.data_length + #client_request.data_block_answer
            client_request = send_data_to_client(client, client_request)
         else
            --client:send(client_request.data_block_answer)
            client_request.req_validity = "terminated"
            if client_request.file then
               client_request.file:close()
               client_request.file = nil
            end
         end
      elseif client_request.req_type == "put" then
         if client_request.file and client_request.data_length < client_request.data_tot_length then
            if client_request.data_tmp ~= "" then
               client_request.data_length = client_request.data_length + #client_request.data_tmp
               client_request.file:write(client_request.data_tmp)
            end
         else
            client:send("HTTP/1.1 200 OK\r\n\r\n")
            client_request.req_validity = "terminated"
            if client_request.file then
               client_request.file:close()
               client_request.file = nil
            end
         end
      end
   end

   return client_request
end





------------------------------------------------------------





function create_client_coroutine ()
   return coroutine.create(function (cl, cl_data)
            local time_elsapsed = 0
            ::start::
            local ret, cl_req = coroutine.yield(cl, cl_data)
            if ret then
               --if request is already valid, yield
               if cl_req and cl_req.req_validity == "valid" then
                  cl_data = ""
                  goto start
               end
               local data, error, partial = cl:receive(16384)
               if data then
                  --data length avail, return and continue reading block next time
                  cl_data = data
                  goto start
               else
                  --no data available, retry next time
                  --else, return partial read, continue next time
                  if partial == "" and error == "timeout" then
                     print("[DEBUG] timeout mark")
                     if time_elsapsed < 5 then
                        time_elsapsed = time_elsapsed + 1
                        cl_data = partial
                        goto start
                     end
                  elseif partial and error == "timeout" then
                     time_elsapsed = 0
                     cl_data = partial
                     goto start
                  end
               end
               cl:close()
               cl = nil
               return cl, partial
            else
               --connection interuption request
               if cl then cl:close() end
            end
         end)
end





function control_client_coroutine (cor, client_request, client, co_ctr, conf)
   if cor then
      --retrieve http header/request
      --if request isn't valid, drop client
      --else if length doesn't exceed max_length, exec request/read body
      if coroutine.status(cor) == "suspended" then
         local ret, client, data = coroutine.resume(cor, true, client_request)
         if not client_request then
            client_request = {
               data_tmp = "",
               request = "",
               req_validity = "incomplete",
               req_type = "",
               filename = "",
               upload_dir = "",
               header = {},
               header_answer = "",
               data_block_answer = "",
               data_length = 0,
               data_tot_length = 0,
               file = nil,
               cl_sig = ""
            }
         end
         client_request.data_tmp = data
         --verfify/parse data
         client_request = exec_client_request(client_request, client, conf)
         if client_request.req_validity == "invalid" or client_request.req_validity == "terminated" then
            coroutine.resume(cor, false)
         end
      elseif coroutine.status(cor) == "dead" then
         if client_request.file then
            client_request.file:close()
         end
         if client_request.req_type == "put" and client_request.data_length < client_request.data_tot_length then
            --remove file
            os.remove(conf.root_path .. client_request.filename)
         end
         client_request = nil
         cor = nil
         co_ctr = co_ctr + 1
      end
   end

   return cor, client_request, co_ctr
end





function exec_client_request (client_request, client, conf)
   if client_request.req_validity == "incomplete" then
      --denial of service, drop client
      if #client_request.header > 50 then
         client_request.req_validity = "invalid"
         return client_request
      end

      --fetch http header
      client_request = fetch_header(client_request)
      if client_request.req_validity == "invalid" then
         return client_request
      end

      client_request = parse_client_request(client, client_request)
      if client_request.req_validity == "invalid" then
         return client_request
      end

      client_request = verify_header_validity(client, client_request, conf)
   end

   client_request = exec_request(client, client_request, conf)

   --DEBUG
   --[[
   if client_request then
      for i = 1, #client_request.header do
         print(client_request.header[i])
      end
   end
   ]]

   return client_request
end
