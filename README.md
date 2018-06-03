# ircpatch

A bot that "patches" two (or more) IRC channels together.  Features include private messaging between IRC servers, XML support for patch files, user and channel management, and much more.  All chat on each channel, including CTCP "action" messages, will be passed on to all the other channels in the patch.  Basically, you can have the bot connect channels on any server to any other server, and all the chat messages will be passed on.

"example.patch" is an example of a patchfile:  every "server" tag causes the bot to connect to a server.  Multiple "channel" tags are also supported, so this bot can connect multiple channels on multiple servers.

Warning:  if you use this bot a lot on servers, the admins will notice.

Requires:  Perl, POE, and POE::Compenent::IRC.
