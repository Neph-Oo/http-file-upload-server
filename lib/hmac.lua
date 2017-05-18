local sha2 = require("lsha2")

local function sha256sum (msg)
   return assert(sha2.hash256(msg))
end



local function xor_key (key)
   local str_i_keypad = ""
   local str_o_keypad = ""
   local ipad, opad = 0x36, 0x5c

   for i = 1, 64 do
      local i_keypad = ( (ipad | key[i]) & ~(ipad & key[i]) )
      local o_keypad = ( (opad | key[i]) & ~(opad & key[i]) )
      str_i_keypad = str_i_keypad .. string.char(i_keypad)
      str_o_keypad = str_o_keypad .. string.char(o_keypad)
   end

   return str_i_keypad, str_o_keypad
end



local function sha256_to_hex (msg)
   local hex_str = ""

   for i = 1, #msg, 2 do
      local str = "0x" .. string.sub(msg, i, i + 1)
      local hex_byte = tonumber(str)
      local hex_byte = string.format("%c", hex_byte)
      if hex_byte then
         hex_str = hex_str .. hex_byte
      end
   end

   return hex_str
end


--------------------------------------------------

--rfc2104
function hmac_sha256 (msg, key_str)
   local key = {}

   --if key greater than sha2 block size (512 bits), hash key
   if #key_str > 64 then
      key_str = sha256sum(key_str)
      key_str = sha256_to_hex(key_str)
   end

   --convert key_str to bytes array
   for i = 1, #key_str do
      key[i] = string.byte(key_str, i)
   end

   --pad key to sha2 block size with null
   if #key_str < 64 then
      for i = #key + 1, 64 do
         key[i] = 0x00
      end
   end

   --xor key with opad//ipad
   local i_keypad, o_keypad = xor_key(key)

   --concatenate i_keypad with msg
   --hash (i_keypad, msg) [1st pass]
   --concatenate o_keypad with hash
   --hash (o_keypad, hash) [2nd pass]
   msg = sha256sum(i_keypad .. msg)
   msg = sha256_to_hex(msg)
   msg = sha256sum(o_keypad .. msg)

   return msg
end
