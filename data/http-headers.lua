err404_data = table.concat{
   "<!DOCTYPE html>\r\n",
   "<html lang=en>\r\n",
   "<meta charset=utf-8>\r\n",
   "<title>Error 404 (Not Found)!</title>\r\n",
   "  <p><b>404.</b> That’s an error.</p>\r\n",
   "  <p>The requested URL was not found on this server.</p>\r\n",
   "</html>\r\n"
}

err400_data = table.concat{
   "<!DOCTYPE html>\r\n",
   "<html lang=en>\r\n",
   "<meta charset=utf-8>\r\n",
   "<title>Error 400 (Bad Request)!</title>\r\n",
   "  <p><b>400.</b> That’s an error.</p>\r\n",
   "  <p>Your client has issued a malformed or illegal request.</p>\r\n",
   "</html>\r\n"
}

err403_data = table.concat{
   "<!DOCTYPE html>\r\n",
   "<html lang=en>\r\n",
   "<meta charset=utf-8>\r\n",
   "<title>Error 403 (Forbidden)!</title>\r\n",
   "  <p><b>403.</b> That’s an error.</p>\r\n",
   "  <p>Your don't have permission's access to that ressource.</p>\r\n",
   "</html>\r\n"
}

err409_data = table.concat{
   "<!DOCTYPE html>\r\n",
   "<html lang=en>\r\n",
   "<meta charset=utf-8>\r\n",
   "<title>Error 409 (Conflict)!</title>\r\n",
   "  <p><b>400.</b> That’s an error.</p>\r\n",
   "  <p>File already exist.</p>\r\n",
   "</html>\r\n"
}


http_header = {
   error = {
      [400] = {
         "HTTP/1.0 400 Bad Request\r\n",
         "Content-Type: text/html; charset=UTF-8\r\n",
         "Referrer-Policy: no-referrer\r\n",
         "Content-Length: " .. #err400_data .. "\r\n",
         "Date: ",
         "\r\n",
         err400_data
      },
      [403] = {
         "HTTP/1.1 403 Forbidden\r\n",
         "Content-Type: text/html; charset=UTF-8\r\n",
         "Referrer-Policy: no-referrer\r\n",
         "Content-Length: " .. #err403_data .. "\r\n",
         "Date: ",
         "\r\n"
      },
      [404] = {
         "HTTP/1.1 404 Not Found\r\n",
         "Content-Type: text/html; charset=UTF-8\r\n",
         "Referrer-Policy: no-referrer\r\n",
         "Content-Length: " .. #err404_data .. "\r\n",
         "Date: ",
         "\r\n"
      },
      [409] = {
         "HTTP/1.1 409 Conflict\r\n",
         "Content-Type: text/html; charset=UTF-8\r\n",
         "Referrer-Policy: no-referrer\r\n",
         "Content-Length: " .. #err409_data .. "\r\n",
         "Date: ",
         "\r\n"
      }
   },
   base = {
      "HTTP/1.1 200 OK\r\n",
      "Date: ",
      "Content-Type: data; charset=UTF-8\r\n",
      "Referrer-Policy: no-referrer\r\n",
      "Content-Length: ",
      "\r\n"
   }
}
