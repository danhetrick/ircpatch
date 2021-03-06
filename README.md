![IRC Patch](https://github.com/danhetrick/ircpatch/blob/docs/ircpatch_logo.png?raw=true)

# IRC-Patch 0.15.25

## Summary

**IRC-Patch** is an [IRC](https://en.wikipedia.org/wiki/Internet_Relay_Chat) [bot](https://en.wikipedia.org/wiki/IRC_bot) that "patches" two (or more) IRC [channels](https://en.wikipedia.org/wiki/Internet_Relay_Chat#Channels) together.  Features include cross-server private messaging, multiple server and channel support, logging, XML support for patchfiles, user and channel management, and much more.  All chat on each channel, including [CTCP](https://tools.ietf.org/id/draft-oakley-irc-ctcp-01.html) "action" messages, will be passed on to all the other servers in the patch.  Basically, you can have the bot connect channels on any server to any other server, and all the chat messages will be passed on.

**IRC-Patch** will run on any platform that Perl and POE can run on.  Development was performed on both Windows 10 and Debian linux, as was testing.

## Table of Contents

  * [Requirements](#requirements)
  * [Terminology](#terminology)
  * [Usage](#usage)
  * [The Link](#the-link)
  * [Patchfiles](#patchfiles)
    * [example.patch](#example.patch)
      * [Required patchfile elements](#required-patchfile-elements)
      * [Optional patchfile elements](#optional-patchfile-elements)
    * [minimal.patch](#minimal.patch)
  * [Message of the Day](#message-of-the-day)
  * [Administration](#administration)
    * [Commands available via public message](#commands-available-via-public-message)
    * [Commands available via private message](#commands-available-via-private-message)
  * [Blacklist](#blacklist)
  * [Example Usage](#example-usage)
  * [Contact](#contact)
  * [Why](#why)
  * [License](#license)

## Requirements

__*Perl*__, __*POE*__, and __*POE::Component::IRC.*__

## Terminology

* **bot** - ["An IRC bot is...an independent program that connects to Internet Relay Chat as a client, and so appears to other IRC users as another user. An IRC bot differs from a regular client in that instead of providing interactive access to IRC for a human user, it performs automated functions."](https://en.wikipedia.org/wiki/IRC_bot).  **IRC-Patch** is a bot.
* **broadcast** - The action of sending text to all users in the *link* . *"All chat is broadcast to the network."*
* **channel** - Any number of IRC channels on different servers connected by the bot via the *link*, named after the IRC channel used.  All IRC channels in the *link* must have the same name.  
* **default.patch** - If **IRC-Patch** is executed with no arguments, the bot will try to load this *patchfile*.
* **link** - The network of IRC servers, using a specific IRC channel name, connected by an **IRC-Patch** bot. *"I'm going to throw up a bot to *link* #robotech."*
* **MOTD** - **M**essage **o**f **t**he **d**ay. If a *MOTD* is set in the *patchfile* for a *link*, it will be sent to every user that joins the *link* as a [private notice](https://en.wikipedia.org/wiki/List_of_Internet_Relay_Chat_commands#NOTICE).
* **network** - See *link*.
* **patchfile** - An XML document containing the settings necessary for **IRC-Patch** to create one or more *links*.  *"I used robotech.patch as my *patchfile*".*
* **private messaging** - User-to-user chat that is send via the *link*, rather than as an [IRC private message](https://en.wikipedia.org/wiki/List_of_Internet_Relay_Chat_commands#PRIVMSG).  This allows for cross-server private messaging.

## Usage

Execute `irc-patch.pl` with no arguments to load the default patchfile, *default.patch*, or with one argument, the filename of the patchfile to load:

    perl irc-patch.pl <FILENAME>

## The Link

The *link* is the network facilitated by **IRC-Patch**.  Each IRC channel "patched" is "linked" to identically named channels on all servers the bot is connected to. Even though **IRC-Patch** can "patch" multiple channels into multiple links, each channel operates individually from each other;  users on one link can't chat with users on another link.  A link is referred to by the name of the channel that it connects to multiple servers.

A link consists of at least two IRC servers, on different networks, connecting a single IRC channel on all connected IRC servers.

## Patchfiles

Settings for **IRC-Patch** are handled by [XML](https://en.wikipedia.org/wiki/XML) files called *patchfiles*; they contain all the information needed for bot to connect any number of servers and channels together;  each channel patched will be considered a single link.  Multiple links can be created in a single *patchfile*.  The root element for a patchfile is **patch**, and all other elements are children of the root.

### example.patch

[example.patch](https://github.com/danhetrick/ircpatch/blob/master/example.patch "example.patch") is an example of a patchfile:  every "server" element causes the bot to connect to a server, and every "channel" element causes the bot to join a channel (creating a link). Patchfiles are XML based, and feature a number of elements, some required, and some not:

### Required patchfile elements (marked as **LINK SETTINGS** in *example.patch*)
  * `channel` - Sets the channel to relay.  At least one channel element is required.
  * `server` - Sets an IRC server to connect to (in *server:port* format).  At least one server element is required.
  * `password` - Sets the password for administrative functions.
  * `nick` - Sets the relay's IRC nickname.
  * `alternate` - Sets the relay's alternate IRC nick if the first is already taken.
  
### Optional patchfile elements (marked as **OPTIONAL SETTINGS** in *example.patch*)
  * `verbose` - Turns verbose mode on and off.  Default: **on**.
  * `log` - Turns logging on and off.  Set to a filename to turn logging on; log data will be written to this file.  Default: **off**.
  * `bot_chat` - Sets a symbol to be prepended to all relay chat.  Default: "*** ".
  * `ircname` - Sets the relay's username.  Default:  "irc-patch 0.15.25 IRC bot".
  * `motd` - Sets the relay's message of the day, sent to users when they first join a channel, as a private notice.  Default: "Welcome to %CHANNEL%, %NICK%!"
  * `private_messaging` - Turns private messaging on and off.  Default: **on**.
  * `timestamp` - Turns timestamping on and off.  Default: **on**.
  * `information` - Turns informational commands(`.version`, `.who`, and `.links`) on and off.  Default: **on**.

*example.patch* is heavily commented, if there are further questions.

### minimal.patch

[minimal.patch](https://github.com/danhetrick/ircpatch/blob/master/minimal.patch "minimal.patch") is an example of a patchfile with the minimum number of elements for it to be a valid patchfile.  Many of the other bot settings are left to their default values, with only the elements necessary for a network connection and chat relay.  It will connect to a single server hosted on the same computer hosting *IRC-Patch*, and connect to a single channel, "#ircpatch":

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

## Message of the Day

The message of the day features several symbols that be used to customize the greeting.  The symbols are interpolated right before they are sent, so you can customize your MOTD for every user!  The MOTD is sent to every user who joins a channel the bot is in, via a notice.  There are six (6) symbols available for use:

* `%CHANNEL%` - Replaced with the name of the channel the MOTD recipient has joined.
* `%NICK%` - Replaced with the joining user's nick.
* `%HOSTMASK` - Replaced with the joining user's hostmask.
* `%SERVER%` - Replaced with the server the joining user's on.
* `%NETWORK%` - Replaced with a list of servers the bot's connected to.
* `%USERS%` - Replaced with a list of all remote users in the channel being joined.

## Administration

Once *IRC-Patch* is up and running, send `.help` as a private message to the bot to see what commands are available for use.  In one of the channels the bot is monitoring, you can also send `.help` as a public message to see what public commands are available for use.  To log into the bot, send `.password <your password>` as a private message.  Once logged in, you can mute individual channels by sending `.mute` as a public message in the channel you want to mute, and `.mute` again to un-mute it.  Each channel is only muted on the server the command is issued in;  if you have three servers linked, for example, sending a `.mute` public message will only mute the channel (on the server) the public message was issued on.  Muted channels will still receive chat text from other channels, their chat text will simply not be broadcasted.

To send a private message to a user via the link, send a private message to the bot with `.private NICK MESSAGE`, or `.p NICK MESSAGE`;  the message will be relayed by the bot to the appropriate user.  If more than one user on the link is using the same nick, the bot will request that you specify what server the desired user is using, with `.private NICK SERVER MESSAGE`, or `.p NICK SERVER MESSAGE`.

There are six (6) possible commands available via public message, and eight (8) possible commands available via private message.  All command output is relayed to the calling user via notice.  Many of the commands can be disabled via patchfile; disabled commands won't be displayed via `.help`.

### Commands available via public message

 * `.help` - Displays help text.
 * `.version` - Displays the bot's version.  Can be disabled via patchfile.
 * `.who` - Displays a list of all remote users in the channel.  Can be disabled via patchfile.
 * `.links` - Displays the servers the bot is connected to.  Can be disabled via patchfile.
 * `.refresh` - Refreshes the remote user list.  Restricted to administrators.
 * `.mute` - Mutes the channel (no public chat is relayed to the network).  Issue again to unmute.  Restricted to administrators.

### Commands available via private message

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

If a user tries to log into the bot, and provides the wrong password, they'll be put on the *blacklist*.  Blacklisted users can't try to log in for a short time period, selected at random from between 60-120 seconds.  Once the user's "timeout" expires, they can log in like normal.  The blacklist *only* effects users that have provided a wrong password; other users can log in like normal.  Users on the blacklist can also issue other commands, they just can't log in.  Blacklisted user's chat is still broadcasted.

## Example Usage

Let's create a patchfile that creates a link named "#patchnet", connecting [Undernet](http://www.undernet.org), [EFnet](http://www.efnet.org), and [GameSurge](https://gamesurge.net), three different, separate IRC networks.  Since I'm located in the US, I'm going to pick three servers located in the US (more specifically, in Chicago, IL), one on each network.  I've selected `Chicago.IL.US.Undernet.org` on the Undernet network, `irc.servercentral.net` on the EFnet network, and `VortexServers.IL.US.GameSurge.net` on the GameSurge network;  I'll use the default port `6667` on each server.  I want to use **IRC-Patch** with minimal functionality, so I'm going to disable the information commands, but leave private messaging turned on.  I also want to use logging, and will log to a file named `/home/dhetrick/ircpatch.txt`.  I'll set a short MOTD that welcomes new users to the channel:  "Welcome to %CHANNEL%, %NICK%!".  I'll set the administration password to `sc00byd00`, and the bot's nickname to `patchbot`.  I'm going to open up a file named `patchnet.patch`, and enter the following into it:

    <?xml version="1.0" encoding="UTF-8"?>
    <patch>
        <!-- patchnet.patch -->
        <channel>#patchnet</channel>
        <server>Chicago.IL.US.Undernet.org:6667</server>
        <server>irc.servercentral.net:6667</server>
        <server>VortexServers.IL.US.GameSurge.net:6667</server>
        <password>sc00byd00</password>
        <nick>patchbot</nick>
        <alternate>patchb0t</alternate>
        <information>off</information>
        <private_messaging>on</private_messaging>
        <log>/home/dhetrick/ircpatch.txt</log>
        <motd>Welcome to %CHANNEL%, %NICK%!</motd>
    </patch>

I save the patchfile to my home directory, `/home/dhetrick`, the same place I've saved `irc-patch.pl`.  I open up a terminal, and start up **IRC-Patch**:

    dhetrick@desktop:/home/dhetrick$ perl irc-patch.pl patchnet.patch
        _                             __       __
       (_)_________      ____  ____ _/ /______/ /_
      / / ___/ ___/_____/ __ \/ __ `/ __/ ___/ __ \
     / / /  / /__/_____/ /_/ / /_/ / /_/ /__/ / / /
    /_/_/   \___/     / .___/\__,_/\__/\___/_/ /_/
                     /_/
    IRC network-channel relay bot
    irc-patch.pl (v0.15.25 - "bamboo")
    (c) Copyright Daniel Hetrick 2018
    .
    [6:26:22 5/29/2018 0s] Starting up IRC bot...
    [6:26:25 5/29/2018 2s] Connected to Chicago.IL.US.Undernet.org
    [6:26:25 5/29/2018 2s] Connected to irc.servercentral.net
    [6:26:26 5/29/2018 3s] Connected to VortexServers.IL.US.GameSurge.net
    [6:26:26 5/29/2018 3s] Joining channel "#patchnet" on "Chicago.IL.US.Undernet.org"
    [6:26:26 5/29/2018 3s] Joining channel "#patchnet" on "irc.servercentral.net"
    [6:26:26 5/29/2018 3s] Joining channel "#patchnet" on "VortexServers.IL.US.GameSurge.net"

I fire up my IRC client, and join "#patchnet" on Undernet, and can see my action on **IRC-Patch**'s log:

    [6:29:29 5/29/2018 186s] wraithnix joined channel #patchnet (Chicago.IL.US.Undernet.org)

As soon as I enter the channel, the bot sends me a welcome message:

    <patchbot> Welcome to #patchnet, wraithnix!

Now, my link is up and running!  If any clients join "#patchnet" on Undernet, EFnet, or GameSurge, they'll be able to chat to each other, and send private messages to each other, via the link.  Everything displayed on the console will be written to `/home/dhetrick/ircpatch.txt` (with the exception of the ASCII art and version information in the startup banner).

## Contact

Any questions not answered here can be answered by taking a look at the source code of `irc-patch.pl`.  It is heavily commented, and I tried to explain everything the bot does, and, more importantly, *why*.  If the source code doesn't answer your questions, feel free to drop me an email at [dhetrick@gmail.com](mailto:dhetrick@gmail.com).

## Why

To be honest, I created **IRC-Patch** out of an unusual personal need.  I was trying to find some friends on IRC after not speaking to them for some time, and the server, network, and channel where we normally met had been changed.  I could hang out in random IRC channels, waiting to see who showed up, or I could figure out a way to watch a bunch of different channels on a bunch of different networks at the same time.  I used the first version of **IRC-Patch** to watch 10 different channels on 12 different networks;  eventually, I found my IRC friends, and shut down the bot.  Fast forward 10 years, and I found this script in one of my backup drives.  One thing led to another, and I decided to make this a *real* IRC bot, with a whole bunch of functionality that I found useful.  I uploaded the script to GitHub, and started fixing and updating the code:  **IRC-Patch** was born.

## License

**IRC-Patch** is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

Also includes XML::TreePP by Yusuke Kawasaki, built into the program rather than as a separate library.  It's licensed via the same license this program, and Perl, uses.
