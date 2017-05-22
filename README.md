# http-file-upload-server
Xmpp http-file-upload service implementation (xep-0363)

WIP

###TODO:
* add max file size setting
* add client queue setting
* add server root path setting //done
* optionnaly:
   - remove private metadata from uploaded file (png, jpg, avi, etc)
   - check magic number/filter
   - bandwidth setup
   - add favicon
   - add priority based on client bandwidth
   - add guard against timing attacks
   - add max file age setup
   - add history logs
   - ...


###Dependencies:
* pure lua lsha2 module
   - luarocks install lsha2
   - http://lua-users.org/wiki/SecureHashAlgorithm
* lua socket
* lua filesystem
