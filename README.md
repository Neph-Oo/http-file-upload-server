# http-file-upload-server
Xmpp http-file-upload service implementation (xep-0363)

*WIP*

###TODO:
* add max file size setting
* add client queue setting
* add server root path setting
* optionnaly:
   - remove private metadata from uploaded file (png, jpg, avi, etc)
   - check magic number/filter files ?
   -


###Dependencies:
* pure lua lsha2 module from develCuy
   - luarocks install lsha2
   - http://lua-users.org/wiki/SecureHashAlgorithm
