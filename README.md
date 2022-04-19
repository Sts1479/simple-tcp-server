Description:
A simple tcp echo server for messaging with n number of clients.
Usage:
You start the app with iex -S mix run
using telnet or nc you can create a client with port 7777, telnet 127.0.0.1 7777
You can enter simple messages that the server will send back. 
Additional commands: kill - terminate the connection to the server
workers - number of connected clients at the moment
time - server time at the moment

