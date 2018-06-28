# irc-patch 0.15.25

**irc-patch** is an IRC bot that "patches" two (or more) IRC channels together.  Features include cross-server private messaging, multiple server and channel support, logging, XML support for patchfiles, user and channel management, and much more.  All chat on each channel, including CTCP "action" messages, will be passed on to all the other servers in the patch.  Basically, you can have the bot connect channels on any server to any other server, and all the chat messages will be passed on.

Setting for the relay are handled by XML files called *patchfiles*; they contain all the information needed for *irc-patch.pl* to connect any number of servers and channels together into a single network.  The root element for a patchfile is **patch**, and all other elements are children of the root.

[irc-patch.pl](https://github.com/danhetrick/ircpatch/blob/unstable/irc-patch.pl "irc-patch.pl") is the main program, a Perl script.  To use, either create a patchfile named *default.patch* in the same directory as the script, and run it, or create a patchfile with a different name and run *irc-patch.pl* with the patchfile's filename as the first (and only) argument.

[example.patch](https://github.com/danhetrick/ircpatch/blob/unstable/example.patch "example.patch") is an example of a patchfile:  every "server" element causes the bot to connect to a server, and every "channel" element causes the bot to join a channel.  Eached patched channel will only be able to "talk" to their identically named counterparts (so, "#mychannel" on EFnet and "#mychannel" on Undernet, if patched, will only have messages relayed to each other;  if "#otherchannel" is patched on both networks by the same bot, it will only be able to "talk" to "#otherchannel", and "#mychannel" will only be able to "talk" to "#mychannel").  Patchfiles are XML based, and feature a number of elements, some required, and some not:

* _Required patchfile elements_:
  * **channel** - Sets the channel to relay.  At least one channel element is required.
  * **server** - Sets an IRC server to connect to (in *server:port* format).  At least one server element is required.
  * **password** - Sets the password for administrative functions.
  * **nick** - Sets the relay's IRC nickname.
  * **alternate** - Sets the relay's alternate IRC nick if the first is already taken.
  
* _Optional patchfile elements_:
  * **verbose** - Turns verbose mode on and off.  Default: **on**.
  * **log** - Turns logging on and off.  Default: **off**.
  * **bot_chat** - Sets a symbol to be prepended to all relay chat.  Default: "*** ".
  * **ircname** - Sets the relay's username.  Default:  "irc-patch 0.15.25 IRC bot".
  * **motd** - Sets the relay's message of the day.  Default: "Welcome to %CHANNEL%, %NICK%!"
  * **private_messaging** - Turns private messaging on and off.  Default: **on**.
  * **timestamp** - Turns timestamping on and off.  Default: **on**.
  * **information** - Turns informational commands on and off.  Default: **on**.

*example.patch* is heavily commented, if there are further questions.

[minimal.patch](https://github.com/danhetrick/ircpatch/blob/unstable/minimal.patch "minimal.patch") is an example of a patchfile with the minimum number of elements for it to be a valid patchfile.  Many of the other bot settings are left to their default values, with only the elements necessary for a network connection and chat relay.  It will connect to a single server hosted on the same computer hosting *irc-patch*, and connect to a single channel, "#ircpatch":

    <?xml version="1.0" encoding="UTF-8"?>
    <patch>
        <channel>#ircpatch</channel>
        <server>localhost:6667</server>
        <password>changeme</password>
        <nick>irc-patch</nick>
        <alternate>irc-patch01525</alternate>
    </patch>

Once *irc-patch* is up and running, send `.help` as a private message to the bot to see what commands are available for use.  In one of the channels the bot is monitoring, you can also send `.help` as a public message to see what public commands are available for use.  To log into the bot, send `.password <your password>` as a private message.  Once logged in, you can mute individual channels by sending `.mute` as a public message in the channel you want to mute, and `.mute` again to un-mute it.  Each channel is only muted on the server the command is issued in;  if you have three channels linked, for example, sending a `.mute` public message will only mute the channel (on the server) the public message was issued on.  Muted channels will still receive chat text from other channels, their chat text will simply not be relayed to the rest of the network.

To send a private message to someone in any of the connected channels, send a private message to the bot with `.private <nick> <message>`, or `.p <nick> <message>`;  the message will be relayed by the bot to the appropriate user.  If more than one person is using the same nick, the bot will request that you specify what server the desired nick is using, with `.private <nick> <server> <message>`, or `.p <nick> <server> <message>`.

*Commands available in public chat:*
 * __*.help*__ - Displays help text.
 * __*.version*__ - Displays the bot's version.  Can be disabled via patchfile.
 * __*.who*__ - Displays a list of all remote users in the channel.  Can be disabled via patchfile.
 * __*.links*__ - Displays the servers the bot is connected to.  Can be disabled via patchfile.
 * __*.refresh*__ - Refreshes the remote user list.  Restricted to administrators.
 * __*.mute*__ - Mutes the channel (no public chat is relayed to the network).  Issue again to unmute.  Restricted to administrators.

*Commands availiable via private message:*
 * __*.help*__ - Displays help text.
 * __*.version*__ - Displays the bot's version.  Can be disabled via patchfile.
 * __*.who CHANNEL*__ - Displays a list of all remote users in a given channel.  Can be disabled via patchfile.
 * __*.links*__ - Displays the servers the bot is connected to.  Can be disabled via patchfile.
 * __*.admin PASSWORD*__ - Logs in to the bot for administration.
 * __*.logout*__ - Logs out of the bot.  Restricted to administrators.
 * __*.refresh*__ - Refreshes the remote user list.  Restricted to administrators.
 * __*.private NICK MESSAGE*__ or __*.private NICK SERVER MESSAGE*__ - Sends a private message to a user via the bot.  If more than one user shares the same nick, the bot will prompt the sender for the target's server.  Can be disabled via patchfile.
 * __*.p NICK MESSAGE*__ - The same as the __*.private*__ command.

Any questions not answered here can be answered by taking a look at the source code of *irc-patch.pl*.  It is heavily commented, and I tried to explain everything the bot does, and, more importantly, *why*.  If the source code doesn't answer your questions, feel free to drop me an email at [dhetrick@gmail.com](mailto:dhetrick@gmail.com).

*irc-patch* is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

__*Requires:  Perl, POE, and POE::Component::IRC.  Also includes XML::TreePP by Yusuke Kawasaki.*__
