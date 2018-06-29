# irc-patch 0.15.25

## Summary

**irc-patch** is an [IRC](https://en.wikipedia.org/wiki/Internet_Relay_Chat) [bot](https://en.wikipedia.org/wiki/IRC_bot) that "patches" two (or more) IRC [channels](https://en.wikipedia.org/wiki/Internet_Relay_Chat#Channels) together.  Features include cross-server private messaging, multiple server and channel support, logging, XML support for patchfiles, user and channel management, and much more.  All chat on each channel, including CTCP "action" messages, will be passed on to all the other servers in the patch.  Basically, you can have the bot connect channels on any server to any other server, and all the chat messages will be passed on.

## Requirements

__*Perl*__, __*POE*__, and __*POE::Component::IRC.*__

## Patchfiles

Setting for *irc-patch.pl* are handled by XML files called *patchfiles*; they contain all the information needed for bot to connect any number of servers and channels together into a single network.  The root element for a patchfile is **patch**, and all other elements are children of the root.

[irc-patch.pl](https://github.com/danhetrick/ircpatch/blob/unstable/irc-patch.pl "irc-patch.pl") is the main program, a Perl script.  To use, either create a patchfile named *default.patch* in the same directory as the script, and run it, or create a patchfile with a different name and run *irc-patch.pl* with the patchfile's filename as the first (and only) argument.

[example.patch](https://github.com/danhetrick/ircpatch/blob/unstable/example.patch "example.patch") is an example of a patchfile:  every "server" element causes the bot to connect to a server, and every "channel" element causes the bot to join a channel.  Eached patched channel will only be able to "talk" to their identically named counterparts (so, "#mychannel" on EFnet and "#mychannel" on Undernet, if patched, will only have messages relayed to each other;  if "#otherchannel" is patched on both networks by the same bot, it will only be able to "talk" to "#otherchannel", and "#mychannel" will only be able to "talk" to "#mychannel").  Patchfiles are XML based, and feature a number of elements, some required, and some not:

* _Required patchfile elements_:
  * `channel` - Sets the channel to relay.  At least one channel element is required.
  * `server` - Sets an IRC server to connect to (in *server:port* format).  At least one server element is required.
  * `password` - Sets the password for administrative functions.
  * `nick` - Sets the relay's IRC nickname.
  * `alternate` - Sets the relay's alternate IRC nick if the first is already taken.
  
* _Optional patchfile elements_:
  * `verbose` - Turns verbose mode on and off.  Default: **on**.
  * `log` - Turns logging on and off.  Default: **off**.
  * `bot_chat` - Sets a symbol to be prepended to all relay chat.  Default: "*** ".
  * `ircname` - Sets the relay's username.  Default:  "irc-patch 0.15.25 IRC bot".
  * `motd` - Sets the relay's message of the day, sent to users when they first join a channel, as a private notice.  Default: "Welcome to %CHANNEL%, %NICK%!"
  * `private_messaging` - Turns private messaging on and off.  Default: **on**.
  * `timestamp` - Turns timestamping on and off.  Default: **on**.
  * `information` - Turns informational commands(`.version`, `.who`, and `.links`) on and off.  Default: **on**.

*example.patch* is heavily commented, if there are further questions.

[minimal.patch](https://github.com/danhetrick/ircpatch/blob/unstable/minimal.patch "minimal.patch") is an example of a patchfile with the minimum number of elements for it to be a valid patchfile.  Many of the other bot settings are left to their default values, with only the elements necessary for a network connection and chat relay.  It will connect to a single server hosted on the same computer hosting *irc-patch*, and connect to a single channel, "#ircpatch":

    <?xml version="1.0" encoding="UTF-8"?>
    <patch>
        <!-- minimal.patch -->
        <channel>#ircpatch</channel>
        <server>localhost:6667</server>
        <password>changeme</password>
        <nick>irc-patch</nick>
        <alternate>irc-patch01525</alternate>
    </patch>

This patchfile, although valid, won't really do anything much;  as the bot isn't connected to any other servers, no chat will be broadcast, and private messaging won't function properly.

## Message of the Day (MOTD)

The message of the day features several symbols that be used to customize the greeting.  The symbols are interpolated right before they are sent, so you can customize your MOTD for every user!  The MOTD is sent to every user who joins a channel the bot is in.  There are six (6) symbols available for use:

* `%CHANNEL%` - Replaced with the name of the channel the MOTD recipient has joined.
* `%NICK%` - Replaced with the joining user's nick.
* `%HOSTMASK` - Replaced with the joining user's hostmask.
* `%SERVER%` - Replaced with the server the joining user's on.
* `%NETWORK%` - Replaced with a list of servers the bot's connected to.
* `%USERS%` - Replaced with a list of all remote users in the channel being joined.

## Administration

Once *irc-patch* is up and running, send `.help` as a private message to the bot to see what commands are available for use.  In one of the channels the bot is monitoring, you can also send `.help` as a public message to see what public commands are available for use.  To log into the bot, send `.password <your password>` as a private message.  Once logged in, you can mute individual channels by sending `.mute` as a public message in the channel you want to mute, and `.mute` again to un-mute it.  Each channel is only muted on the server the command is issued in;  if you have three channels linked, for example, sending a `.mute` public message will only mute the channel (on the server) the public message was issued on.  Muted channels will still receive chat text from other channels, their chat text will simply not be relayed to the rest of the network.

To send a private message to someone in any of the connected channels, send a private message to the bot with `.private NICK MESSAGE`, or `.p NICK MESSAGE`;  the message will be relayed by the bot to the appropriate user.  If more than one person is using the same nick, the bot will request that you specify what server the desired nick is using, with `.private NICK SERVER MESSAGE`, or `.p NICK SERVER MESSAGE`.

There are six (6) commands available via public message, and eight (8) commands available via private message.  All command output is relayed to the calling user via notice.  Many of the commands can be disabled via patchfile; disabled commands won't be displayed via `.help`.

*Commands available via public message:*
 * `.help` - Displays help text.
 * `.version` - Displays the bot's version.  Can be disabled via patchfile.
 * `.who` - Displays a list of all remote users in the channel.  Can be disabled via patchfile.
 * `.links` - Displays the servers the bot is connected to.  Can be disabled via patchfile.
 * `.refresh` - Refreshes the remote user list.  Restricted to administrators.
 * `.mute` - Mutes the channel (no public chat is relayed to the network).  Issue again to unmute.  Restricted to administrators.

*Commands availiable via private message:*
 * `.help` - Displays help text.
 * `.version` - Displays the bot's version.  Can be disabled via patchfile.
 * `.who CHANNEL` - Displays a list of all users in a given channel.  Can be disabled via patchfile.
 * `.links` - Displays the servers the bot is connected to.  Can be disabled via patchfile.
 * `.login PASSWORD` - Logs in to the bot for administration.  Only one user can be logged into the bot at a time.
 * `.logout` - Logs out of the bot.  Restricted to administrators.
 * `.refresh` - Refreshes the remote user list.  Restricted to administrators.
 * `.private NICK MESSAGE` or `.private NICK SERVER MESSAGE` - Sends a private message to a user via the bot.  If more than one user shares the same nick, the bot will prompt the sender for the target's server.  Can be disabled via patchfile.
 * `.p NICK MESSAGE` - The same as the `.private` command.

## Blacklist

If a user tries to log into the bot, and provides the wrong password, they'll be put on the *blacklist*.  Blacklisted users can't try to log in for a short time period, selected at random from between 60-120 seconds.  Once the user's "timeout" expires, they can log in like normal.  The blacklist *only* effects users that have provided a wrong password; other users can log in like normal.  Users on the blacklist can also issue other commands, they just can't log in.

## Contact

Any questions not answered here can be answered by taking a look at the source code of *irc-patch.pl*.  It is heavily commented, and I tried to explain everything the bot does, and, more importantly, *why*.  If the source code doesn't answer your questions, feel free to drop me an email at [dhetrick@gmail.com](mailto:dhetrick@gmail.com).

## License

*irc-patch* is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

Also includes XML::TreePP by Yusuke Kawasaki, built into the program rather than as a separate library.  It's licensed via the same license this program, and Perl, uses.
