#!/usr/bin/perl
#    
#     _                             __       __  
#    (_)_________      ____  ____ _/ /______/ /_ 
#   / / ___/ ___/_____/ __ \/ __ `/ __/ ___/ __ \
#  / / /  / /__/_____/ /_/ / /_/ / /_/ /__/ / / /
# /_/_/   \___/     / .___/\__,_/\__/\___/_/ /_/ 
#                  /_/        v0.15.25 - "bamboo"
#
# IRC Network-to-Network Channel Link
#
# An IRC bot that can link channels on different IRC
# networks by using the bot as a relay;  chat from
# every linked channel is broadcast to every
# other linked channel, allowing users on
# different networks to chat to each other.
#
# Copyright 2018 Dan Hetrick
#
# Author:  Dan Hetrick (dhetrick@gmail.com)
#
# ====================================================================
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
# ====================================================================
#
# Also includes XML::TreePP by Yusuke Kawasaki (http://www.kawa.net/)
#
# =======================================================
# | XML::TreePP                                         |
# | By Yusuke Kawasaki                                  |
# | Copyright (c) 2006-2008 Yusuke Kawasaki.            |
# | All rights reserved. This program is free software; |
# | you can redistribute it and/or modify it under the  |
# | same terms as Perl itself.                          |
# =======================================================

# =================
# | MODULES BEGIN |
# =================

use strict;
use POE qw(Component::IRC);
use FindBin qw($Bin $RealBin);

# ===============
# | MODULES END |
# ===============

# ===================
# | CONSTANTS BEGIN |
# ===================

# User list
use constant USER_NICK 			=> 0;
use constant USER_CHANNEL 		=> 1;
use constant USER_SERVER 		=> 2;
use constant USER_IS_AN_OP 		=> 3;
use constant USER_IS_VOICED 	=> 4;
use constant USER_LAST_REFRESH 	=> 5;

# Blacklist
use constant BLACKLIST_HOSTNAME			=> 0;
use constant BLACKLIST_LOCKOUT			=> 1;
use constant BLACKLIST_LENGTH_MINIMUM	=> 60;
use constant BLACKLIST_LENGTH_MAXIMUM	=> 120;

# =================
# | CONSTANTS END |
# =================

# =================
# | GLOBALS BEGIN |
# =================

# -------
# Scalars
# -------
my $APPLICATION 		= "irc-patch.pl";
my $VERSION 			= "0.15.25";
my $RELEASE				= "bamboo";
my $DESCRIPTION			= "IRC network-channel relay bot";
my $TIME				= 0;

# ------
# Arrays
# ------
my @USERS		= ();			# User list for all channels/servers
my @NETWORK 	= ();			# List of POE objects for server/channel connections
my @ADMIN		= ( '','' );	# User who is logged in as admin
my @MUTE		= ();			# List of muted channels
my @BLACKLIST	= ();			# List of blacklisted users

# ------
# Hashes
# ------
my %servers = {};

# ============================
# | PATCHFILE SETTINGS BEGIN |
# ============================

# These scalars are set to values from the patchfile

my $VERBOSE 			= 0;
my $LOG 				= "";
my $NICKNAME 			= 'irc-patch' . $$;
my $ALTERNATE_NICK 		= 'irc-patch'. $$;
my $CURRENT_NICK		= $NICKNAME;
my $USERNAME  			= "$APPLICATION $RELEASE-$VERSION ($DESCRIPTION)";
my $ADMIN_PASSWORD 		="changeme";
my $MOTD				= '';
my $BOT_OUTPUT_SYMBOL	= '*** ';
my $PRIVATE_MESSAGE 	= 1;
my $TIMESTAMP 			= 1;
my $INFORMATION_CMDS	= 1;

# ==========================
# | PATCHFILE SETTINGS END |
# ==========================

# ===============
# | GLOBALS END |
# ===============

# ======================
# | MAIN PROGRAM BEGIN |
# ======================

# Default patchfile name
my $PATCHFILE 			= 'default.patch';

# If a patchfile file name is passed as the first argument, use it,
# else use the default, "default.patch"
if($#ARGV>=0){ $PATCHFILE=$ARGV[0]; }

# If no patchfile is found, display error and exit.
if((-e $PATCHFILE) && (-f $PATCHFILE)){} else {
	print "$APPLICATION $RELEASE-$VERSION ($DESCRIPTION)\n";
	print "Patchfile \"$PATCHFILE\" not found!\n";
	print "Usage: perl $0 FILENAME\n";
	exit 1;
}

# Load in the patchfile
load_patchfile($PATCHFILE);

# Display our banner if verbose is turned on
if($VERBOSE==1){
	my  $banner = banner_ascii_graphic();
	print $banner."$DESCRIPTION\n$APPLICATION (v$VERSION - \"$RELEASE\")\n";
	print "(c) Copyright Daniel Hetrick 2018\n\n";
}

# Create a POE object for each server we're connecting to
foreach my $server ( keys %servers ) {
	POE::Component::IRC->spawn(
		alias   => $server,
		nick    => $NICKNAME,
		ircname => $USERNAME,
	);
}

# Register which events we want to receive...
POE::Session->create(
	package_states =>
		[ 'main' => [qw(_start irc_registered irc_001 irc_public irc_msg irc_join irc_part irc_433 irc_ctcp_action irc_352 _beat)], ],
	heap => { config => \%servers },
);

# Start up!
$poe_kernel->run();
exit 0;

# ====================
# | MAIN PROGRAM END |
# ====================

# ====================
# | POE EVENTS BEGIN |
# ====================

# _start()
# irc_registered()
# irc_001()
# irc_join()
# irc_part()
# irc_msg()
# irc_public()
# irc_433()
# irc_ctcp_action()
# irc_352()
# _beat()

# ======
# _beat
# ======
# Triggered once a second.
sub _beat {
	my ( $kernel, $session ) = @_[ KERNEL, SESSION ];

	# Increment server time by one
	$TIME=$TIME+1;

	# Make sure the _beat is executed again, in one second
	$kernel->delay( _beat => 1 );

	# Remove users from the blacklist that have timed out
	clean_blacklist();

	undef;
}

# ======
# _start
# ======
# Triggered when the bot is initially started.
sub _start {
	my ( $kernel, $session ) = @_[ KERNEL, SESSION ];

	# Make sure that all POE objects get all signals
	$kernel->signal( $kernel, 'POCOIRC_REGISTER', $session->ID(), 'all' );

	# Start up the heartbeat
	$kernel->delay( _beat => 1 );

	# Display/log the bot startup
	display("Starting up IRC bot...\n");

	undef;
}

# ==============
# irc_registered
# ==============
# Triggered every time one of the POE objects is registered.
sub irc_registered {
	my ( $kernel, $heap, $sender, $irc_object ) =
		@_[ KERNEL, HEAP, SENDER, ARG0 ];
	my $alias = $irc_object->session_alias();

	my %conn_hash = (
		server => $alias,
		port   => $heap->{config}->{$alias}->{port},
	);

	# Connect the object to the IRC server...
	$kernel->post( $sender, 'connect', \%conn_hash );

	undef;
}

# ========
# irc_001
# ========
# Triggered every time the bot connects to an IRC server.
sub irc_001 {
	my ( $kernel, $heap, $sender ) = @_[ KERNEL, HEAP, SENDER ];
	my $poco_object = $sender->get_heap();

	# Display/log the successful connection
	display("Connected to ".$poco_object->server_name()."\n");

	# Add the POE object to the "network"
	my @entry = ($kernel,$sender);
	push(@NETWORK,\@entry);

	# Join channels named in the patchfile
	my $alias    = $poco_object->session_alias();
	my @channels = @{ $heap->{config}->{$alias}->{channels} };
	foreach my $c (@channels) {
		# Join the channel
		$kernel->post( $sender => join => $c);

		# Display/log the channel joined
		display("Joining channel \"$c\" on \"".$poco_object->server_name()."\"\n");

		# Update the internal user list
		update_user_list($poco_object->server_name(),$c,$kernel,$sender);
	}

	undef;
}

# ========
# irc_join
# ========
# Triggered every time the bot receives a JOIN message.
sub irc_join {
	my ( $kernel, $sender, $who, $where ) =
		@_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $poco = $sender->get_heap();
	my $server_name = $poco->server_name();

	# Don't do anything if the joining client is the bot
	if($nick eq $CURRENT_NICK){ return undef; }

	# Display/log and broadcast join information
	display("$nick joined channel $where ($server_name)\n");
	broadcast("$nick has joined the channel ($server_name)",$where,$server_name);

	# Update the internal user list
	update_user_list($server_name,$where,$kernel,$sender);

	# If there's an MOTD, prepare and send to the joining client as a notice
	if($MOTD ne ''){
		# Interpolate the MOTD from patchfile
		my $mg = $MOTD;
		$mg=~s/\%CHANNEL\%/$where/g;
		$mg=~s/\%SERVER\%/$server_name/g;
		$mg=~s/\%NICK\%/$nick/g;
		$mg=~s/\%HOSTMASK\%/$hostmask/g;

		my @s = get_server_list();  my $servers = join(', ',@s);
		$mg=~s/\%NETWORK\%/$servers/g;

		# Generate the channel remote user list
		my @ulist = get_channel_user_list($where);
		if($#ulist>=0){
			my $u = join(', ',@ulist);
			$mg=~s/\%USERS\%/$u/g;
		} else {
			$mg=~s/\%USERS\%/No users found/g;
		}

		# Send the MOTD to the joining client as a notice
		$kernel->post( $sender => notice => $nick => $mg );	
	}

	undef;
}

# ========
# irc_part
# ========
# Triggered every time the bot receives a PART message.
sub irc_part {
	my ( $kernel, $sender, $who, $where ) =
		@_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $poco = $sender->get_heap();
	my $server_name = $poco->server_name();

	# Display/log and broadcast part information
	display("$nick left channel $where ($server_name)\n");
	broadcast($BOT_OUTPUT_SYMBOL."$nick has left the channel ($server_name)",$where,$server_name);

	# Update the internal user list
	update_user_list($server_name,$where,$kernel,$sender);

	undef;
}

# =======
# irc_msg
# =======
# Triggered every time the bot receives a private message.
# Here's where bot commands are handled.
sub irc_msg {
	my ( $kernel, $sender, $who, $where, $what ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $poco = $sender->get_heap();
	my $channel = $where->[0];
	my $server_name = $poco->server_name();

	# .login PASSWORD
	# Logs in as the administrator.  If the user enters the wrong password, they
	# have to wait 60 seconds before they can try again.
	if ( my ($admin) = $what =~ /^\.login (.+)/ ) {

		# Is the user blacklisted?
		if(is_user_blacklisted($hostmask)==1){

			# Display/log/notify that the user is blacklisted, and tried to login.
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."Incorrect password entered.  Try again later." );
			display("$nick ($hostmask) tried to log into bot while blacklisted\n");

			return undef;
		}

		# Check to see if the entered password is correct, and if so, log the user in.
		if($admin eq $ADMIN_PASSWORD){
			if(($ADMIN[0] eq '')&&($ADMIN[1] eq '')) {
				$ADMIN[0] = $nick;
				$ADMIN[1] = $hostmask;

				# Display/log/notify the user that they've logged in successfully.
				$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."Logged in!" );
				display("$nick ($hostmask) logged into the bot\n");
			} else {

				# Display/log/notify the user that someone is already logged in.
				$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."Someone is already logged in as admin." );
				display("$nick ($hostmask) tried to log into bot but $ADMIN[0] ($ADMIN[1]) is already logged in\n");
			}
			return undef;
		} else {

			# Add user to blacklist;  users can only try one incorrect password a minute.
			my $timeout = add_user_to_blacklist($hostmask);

			# Display/log/notify the user that they entered the wrong password.
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."Login incorrect. Try again in $timeout seconds." );
			display("$nick ($hostmask) tried to log into bot with wrong password;  blacklisted for $timeout seconds\n");
			return undef;
		}
	}

	# .logout
	# If you're the admin, it logs you out.
	if( $what =~ /^\.logout$/ ) {
		if(($ADMIN[0] eq $nick)&&($ADMIN[1] eq $hostmask)){

			# Logout the user
			@ADMIN = ( '','' );

			# Display/log/notify the user that they logged out.
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."Logged out." );
			display("$nick ($hostmask) logged out of the bot\n");
			return undef;
		}
	}

	# .refresh
	# Refreshes the bot's internal user list manually.
	# Only available to admins.
	if( $what =~ /^\.refresh$/ ) {
		if(($ADMIN[0] eq $nick)&&($ADMIN[1] eq $hostmask)){
			update_user_list($server_name,$channel,$kernel,$sender);
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."User list refreshed." );
		}
		return undef;
	}

	# .private USERNAME MESSAGE -or- .private USERNAME SERVER MESSAGE
	# Sends a private message via the patch network.  This command can
	# also take three arguments;  if there's more than one client with
	# the same nick, the client will be asked to provide the server
	# that the desired target is one.  That variation of .private is
	# not handled here;  it's handled in private_message().
	if ( my ($private) = $what =~ /^\.private (.+)/ ) {

		if($PRIVATE_MESSAGE != 1){
			# Private messaging is turned off.
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."Private messaging has been turned off" );
			return undef;
		}

		# Parse out the command input.
		my @p = split(' ',$private);
		my $target = '';
		my $message = '';
		if($#p>=1){
			$target = shift @p;
			$message = join(' ',@p);
		} else {
			# No arguments passed to the .private command
			# Notify the client with command usage information.
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."USAGE: .private USERNAME MESSAGE" );
			return undef;
		}

		# Now we've got a private message to send, so send it.
		private_message($target,$message,$nick,$kernel,$sender);

		return undef;
	}

	# .p USERNAME MESSAGE
	# Sends a private message via the patch network.
	if ( my ($private) = $what =~ /^\.p (.+)/ ) {

		if($PRIVATE_MESSAGE != 1){
			# Private messaging is turned off.
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."Private messaging has been turned off" );
			return undef;
		}

		# Parse out the command input.
		my @p = split(' ',$private);
		my $target = '';
		my $message = '';
		if($#p>=1){
			$target = shift @p;
			$message = join(' ',@p);
		} else {
			# No arguments passed to the .p command
			# Notify the client with command usage information.
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."USAGE: .p USERNAME MESSAGE" );
			return undef;
		}

		# Now we've got a private message to send
		private_message($target,$message,$nick,$kernel,$sender);

		return undef;
	}

	# .help
	# Displays help text.
	if( $what =~ /^\.help$/ ) {

		# Non-admin commands.
		$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."$APPLICATION IRC Bot" );
		$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL.".help			Display this text" );
		$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL.".admin PASSWORD			Logs you in as a bot admin" );

		# Only display information commands if they are turned on.
		if($INFORMATION_CMDS==1){
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL.".version			Display software version" );
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL.".who CHANNEL			Display a list of users in CHANNEL" );
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL.".links			List the servers currently linked" );
		}

		# Only display private message commands if they are turned on.
		if($PRIVATE_MESSAGE == 1){
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL.".private USER MSG		Sends a private message via the link" );
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL.".p USER MSG			Sends a private message via the link" );
		}
		
		# Admin-only commands will only be displayed to users who are logged in as admins.
		if(($ADMIN[0] eq $nick)&&($ADMIN[1] eq $hostmask)){
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL.".refresh			Refreshes the internal user list" );
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL.".logout			Log out of the bot" );
		}
		return undef;
	}

	# Only allow information commands if they are turned on.
	if($INFORMATION_CMDS==1){
		# .version
		# Displays bot version
		if( $what =~ /^\.version$/ ) {
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."$APPLICATION $VERSION ($RELEASE)" );
			return undef;
		}

		# .links
		# Display what servers the bot is connected to
		if( $what =~ /^\.links$/ ) {
			my @s = get_server_list();
			$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."This channel is linked to ".join(", ",@s) );
			return undef;
		}

		# .who CHANNEL
		# Causes the bot to send a list of all users (on all
		# servers) in a channel via a private notice.
		if ( my ($target) = $what =~ /^\.who (.+)/ ) {

			# If the internal userlist is empty, display an error and tell the user to try again later.
			if($#USERS>=0){}else{
				$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."Error retrieving user list.  Please try again." );
				return undef;
			}

			# Compile the userlist for display. Op'd users get a "@" in front of their nick, and voice'd users get a "+" in
			# in front of their nick.
			my @ulist = get_channel_user_list($target);

			# Compiled userlist is empty, so let the user know (this probably won't happen;  empty user list should be caught by the
			# first conditional in this statement) and exit the statement
			if($#ulist>=0){}else{
				$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."No users found" );
				return undef;
			}

			# Send the compiled userlist to the user
			foreach my $ul (@ulist) {
				$kernel->post( $sender => privmsg => $nick => $BOT_OUTPUT_SYMBOL."$ul" );
			}

			return undef;
		}
	}
}

# ==========
# irc_public
# ==========
# Triggered whenever the bot receives a public message.
sub irc_public {
	my ( $kernel, $sender, $who, $where, $what ) =
		@_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick    = ( split /!/, $who )[0];
	my $hostmask    = ( split /!/, $who )[1];
	my $channel = $where->[0];
	my $poco = $sender->get_heap();
	my $server_name = $poco->server_name();

	# .refresh
	# Refreshes the bot's internal user list manually.
	# Only available to admins.
	if( $what =~ /^\.refresh$/ ) {
		if(($ADMIN[0] eq $nick)&&($ADMIN[1] eq $hostmask)){
			update_user_list($server_name,$channel,$kernel,$sender);
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."User list refreshed." );
		}
		return undef;
	}

	# .mute
	# "Mutes" a channel;  the channel on the server where this command is issued is the only one "muted".
	# Only available to admins.
	# "Muted" channels won't send chat or join/part text to the patch network.
	# Issued the "mute" channel again to "unmute".
	if( $what =~ /^\.mute$/ ) {
		if(($ADMIN[0] eq $nick)&&($ADMIN[1] eq $hostmask)){
			my @new = ();
			my $muted = 0;

			# Check the muted chanel list to see if this channel is in there.
			foreach my $m (@MUTE) {

				# Step through the mute list and look if the desired channel
				# is on it;  create a copy of the mute list that contains all
				# muted channels *except* for the desired channel.
				my @ma = @{$m};
				if(($ma[0] eq $channel)&&($ma[1] eq $server_name)){
					$muted = 1;
					next;
				}
				push(@new,$m);
			}

			# @new now contains a list of all muted channels *except* for the channel
			# being looked for.

			# Mute/unmute the channel and let the channel know.
			if($muted==1){
				# Channel was already muted;  unmute it.

				# Set the mute list to @new, since it's already been scrubbed of any
				# reference to the desired channel.
				@MUTE=@new;

				# Now that the channel is off the muted list, the broadcast will reach it.
				broadcast($BOT_OUTPUT_SYMBOL."Channel $channel on $server_name unmuted.",$channel,$server_name);

				# Display/log the action.
				display("$nick ($hostmask) unmuted $channel ($server_name)\n");
			} else {
				# Channel was not muted.  Mute it.

				# Send the broadcast *before* the channel is muted, so the broadcast will reach it.
				broadcast($BOT_OUTPUT_SYMBOL."Channel $channel on $server_name muted.",$channel,$server_name);

				# Add the channel and server to the mute list.
				my @entry = ($channel,$server_name);
				push(@MUTE,\@entry);

				# Display/log the action.
				display("$nick ($hostmask) muted $channel ($server_name)\n");
			}
			return undef;
		}
		return undef;
	}

	# .help
	# Displays help text via a private notice.
	if( $what =~ /^\.help$/ ) {

		# Non-admin commands.
		$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."$APPLICATION IRC Bot" );
		$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL.".help		Display this text" );

		# Only display information commands if they are turned on.
		if($INFORMATION_CMDS==1){
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL.".version		Display software version" );
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL.".who		Display a list of users in the channel" );
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL.".links		Display the servers this channel is linked to" );
		}

		# Admin-only commands will only be displayed to users who are logged in as admins.
		if(($ADMIN[0] eq $nick)&&($ADMIN[1] eq $hostmask)){
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL.".refresh		Manually refresh the internal user list" );
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL.".mute		Toggles channel muting" );
		}

		return undef;
	}

	# Only allow information commands if they are turned on.
	if($INFORMATION_CMDS==1){
		# .version
		# Displays bot version via a private notice.
		if( $what =~ /^\.version$/ ) {
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."$APPLICATION $VERSION ($RELEASE)" );
			return undef;
		}

		# .links
		# Display what servers the bot is connected to via a private notice.
		if( $what =~ /^\.links$/ ) {
			my @s = get_server_list();
			$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."This channel is linked to ".join(",",@s) );
			return undef;
		}

		# .who
		# Causes the bot to send a list of all users (on every
		# server but the caller's server) to the calling user via a private notice.
		if( $what =~ /^\.who$/ ) {

			# If the internal userlist is empty, display an error and tell the user to try again later.
			if($#USERS>=0){}else{
				$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."Error retrieving user list.  Please try again." );
			}

			# Compile the userlist for display. Op'd users get a "@" in front of their nick, and voice'd users get a "+" in
			# in front of their nick.
			my @ulist = get_channel_user_list($channel);

			# Compiled userlist is empty, so let the user know (this probably won't happen;  empty user list should be caught by the
			# first conditional in this statement) and exit the statement.
			if($#ulist>=0){}else{
				$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."No users found." );
				return undef;
			}

			# Send the compiled userlist to the user.
			foreach my $ul (@ulist) {
				$kernel->post( $sender => notice => $nick => $BOT_OUTPUT_SYMBOL."$ul" );
			}

			return undef;
		}
	}

	# Incoming chat doesn't contain a command, so pass the chat to the patch network and display to all users.
	broadcast($BOT_OUTPUT_SYMBOL."<$nick> $what",$channel,$server_name);

	# Display/log broadcasted chat
	display("$channel $server_name <$nick> $what\n");

	undef;
}

# =======
# irc_433
# =======
# Triggered whenever the bot's nick is already in use.
sub irc_433 {
	my ($kernel,$sender) = @_[KERNEL,SENDER];

	# Bot's initial nick is in use, so try the alternate nickname...
	if($CURRENT_NICK eq $NICKNAME) {
		display("Changing nick to \"$ALTERNATE_NICK\"...\n");
		$CURRENT_NICK=$ALTERNATE_NICK;
		foreach my $n (@NETWORK) {
			my @na = @{ $n };
			$na[0]->post( $na[1] => nick => $CURRENT_NICK );
		}

	# Bot's alternate nick is in use, so append a random number
	# to the altername nick and try again.
	}elsif($CURRENT_NICK eq $ALTERNATE_NICK){
		$CURRENT_NICK=$ALTERNATE_NICK.$$;
		display("Changing nick to \"$CURRENT_NICK\"...\n");
		foreach my $n (@NETWORK) {
			my @na = @{ $n };
			$na[0]->post( $na[1] => nick => $CURRENT_NICK );
		}
	}

}

# ===============
# irc_ctcp_action
# ===============
# Triggered whenever the server sends the client a CTCP 'action' message.
sub irc_ctcp_action {
	my ( $kernel, $sender, $who, $where, $msg ) = @_[ KERNEL, SENDER, ARG0, ARG1, ARG2 ];
	my $nick     = ( split /!/, $who )[0];
	my $hostmask = ( split /!/, $who )[1];
	my $channel  = $where->[0];
	my $poco = $sender->get_heap();
	my $server_name = $poco->server_name();

	broadcast($BOT_OUTPUT_SYMBOL."$nick $msg",$channel,$server_name);
}

# =======
# irc_352
# =======
# Triggered whenever 'who' data is received by the client.
sub irc_352 {
	my ( $kernel, $sender, $serv, $data ) = @_[ KERNEL, SENDER, ARG0, ARG1 ];
	my $poco_object = $sender->get_heap();
	my $chan = ( split / /, $data )[0];
	my $server = $poco_object->server_name();
	my $nick = ( split / /, $data )[4];
	my $code = ( split / /, $data )[5];

	# Bot's current username is left out of the list
	if($nick eq $CURRENT_NICK){ return undef; }

	# Check to see if the nick is voice'd or op'd, and add them
	# to the user list
	my $is_op = 0;
	my $is_v = 0;
	if ( $code =~ /\@/ ) { $is_op=1; }
	if ( $code =~ /\+/ ) { $is_v=1; }
	add_user_to_channel_user_list($nick,$chan,$server,$is_op,$is_v);
}

# ==================
# | POE EVENTS END |
# ==================

# =============================
# | SUPPORT SUBROUTINES START |
# =============================

# get_channel_user_list()
# load_patchfile()
# clean_blacklist()
# add_user_to_blacklist()
# is_user_blacklisted()
# banner_ascii_graphic()
# error()
# display()
# timestamp()
# broadcast()
# private_message()
# get_server_list()
# update_user_list()
# remove_channel_from_user_list()
# add_user_to_channel_user_list()

# get_channel_user_list()
# Syntax: get_channel_user_list($channel)
# Arguments: 1 (scalar)
# Returns:  Array
# Description: Builds a user list, on all networks, for a
#              specific channel.  List is "pretty";  it also contains whether
#              a user is op'd and/or voice'd.
sub get_channel_user_list {
	my $channel = shift;

	my @ulist = ();
	foreach my $u (@USERS) {
		my @ua = @{$u};
		if($ua[USER_CHANNEL] eq $channel) {
			my $n = $ua[USER_NICK];
			my $s = $ua[USER_SERVER];
			if($ua[USER_IS_VOICED]==1){ $n='+'.$n; }
			if($ua[USER_IS_AN_OP]==1){ $n='@'.$n; }
			push(@ulist,"$n ($s)" );
		}
	}

	return @ulist;
}

# load_patchfile()
# Syntax: load_patchfile($filename)
# Arguments: 1 (scalar)
# Returns:  Nothing
# Description: Loads and parses a patchfile, which contains all the settings needed for
#              the bot to operate.
sub load_patchfile {
	my $filename = shift;

	display("Loading patchfile \"$filename\"...\n");

	my @xchannels = ();
	my @xservers = ();
	my $password = '';
	my $motd = '';
	my $xnick = '';
	my $xinfo = '';
	my $xanick = '';

	# Load and parse XML patchfile
	my $tpp = XML::TreePP->new();
	my $tree = $tpp->parsefile( $filename );

	# ========================
	# | PATCHFILE TAGS BEGIN |
	# ========================

	# Verbose tag
	# Turns verbose mode on or off
	# Not required
	if(ref($tree->{patch}->{verbose}) eq 'ARRAY'){
		error("Only one verbose tag per patchfile.");
	}
	if($tree->{patch}->{verbose}){
		if( ($tree->{patch}->{verbose} eq "1") || (lc($tree->{patch}->{verbose}) eq "yes") || (lc($tree->{patch}->{verbose}) eq "on") ) {
			$VERBOSE = 1;
		}
	}

	# Private_messaging tag
	# Turns verbose mode on or off
	# Not required
	if(ref($tree->{patch}->{private_messaging}) eq 'ARRAY'){
		error("Only one private_messaging tag per patchfile.");
	}
	if($tree->{patch}->{private_messaging}){
		if( ($tree->{patch}->{private_messaging} eq "1") || (lc($tree->{patch}->{private_messaging}) eq "yes") || (lc($tree->{patch}->{private_messaging}) eq "on") ) {
			$PRIVATE_MESSAGE = 1;
		} elsif ( ($tree->{patch}->{private_messaging} eq "0") || (lc($tree->{patch}->{private_messaging}) eq "no") || (lc($tree->{patch}->{private_messaging}) eq "off") ) {
			$PRIVATE_MESSAGE = 0;
		}
	}

	# Information tag
	# Turns information commands on or off
	# Not required
	if(ref($tree->{patch}->{information}) eq 'ARRAY'){
		error("Only one information tag per patchfile.");
	}
	if($tree->{patch}->{information}){
		if( ($tree->{patch}->{information} eq "1") || (lc($tree->{patch}->{information}) eq "yes") || (lc($tree->{patch}->{information}) eq "on") ) {
			$INFORMATION_CMDS = 1;
		} elsif ( ($tree->{patch}->{information} eq "0") || (lc($tree->{patch}->{information}) eq "no") || (lc($tree->{patch}->{information}) eq "off") ) {
			$INFORMATION_CMDS = 0;
		}
	}

	# Timestamp tag
	# Turns timestamps on logging and verbose messages on or off
	# Not required
	if(ref($tree->{patch}->{timestamp}) eq 'ARRAY'){
		error("Only one timestamp tag per patchfile.");
	}
	if($tree->{patch}->{timestamp}){
		if( ($tree->{patch}->{timestamp} eq "1") || (lc($tree->{patch}->{timestamp}) eq "yes") || (lc($tree->{patch}->{timestamp}) eq "on") ) {
			$TIMESTAMP = 1;
		} elsif ( ($tree->{patch}->{timestamp} eq "0") || (lc($tree->{patch}->{timestamp}) eq "no") || (lc($tree->{patch}->{timestamp}) eq "off") ) {
			$TIMESTAMP = 0;
		}
	}

	# Log tag
	# Turns logging on or off
	# Not required
	if(ref($tree->{patch}->{log}) eq 'ARRAY'){
		error("Only one log tag per patchfile.");
	}
	if($tree->{patch}->{log}){
		$LOG = $tree->{patch}->{log};
	}

	# bot_chat_id tag
	# Sets a symbol that is prefaced on every bot chat text
	# Not required
	# Default:  "*** "
	if(ref($tree->{patch}->{bot_chat_id}) eq 'ARRAY'){
		error("Only one bot_chat_id tag per patchfile.");
	}
	if($tree->{patch}->{bot_chat_id}){
		$BOT_OUTPUT_SYMBOL = $tree->{patch}->{bot_chat_id};
		if(substr($BOT_OUTPUT_SYMBOL, -1) != " "){
			$BOT_OUTPUT_SYMBOL .= " ";
		}
	}

	# Channel tag(s)
	# Sets the IRC channel(s) to patch
	# Required
	if($tree->{patch}->{channel}){
		if(ref($tree->{patch}->{channel}) eq 'ARRAY'){
			foreach my $c (@{$tree->{patch}->{channel}}) {
				push(@xchannels,$c);
			}
		} else {
			push(@xchannels,$tree->{patch}->{channel});
		}
	} else {
		error("Patchfile is missing a channel tag.");
	}

	# Server tag(s)
	# Sets the IRC servers to patch, in "server:port" format
	# Required
	if($tree->{patch}->{server}){
		if(ref($tree->{patch}->{server}) eq 'ARRAY'){
			foreach my $c (@{$tree->{patch}->{server}}) {
				push(@xservers,$c);
			}
		} else {
			push(@xservers,$tree->{patch}->{server});
		}
	} else {
		error("Patchfile is missing a server tag.");
	}

	# Password tag
	# Sets the administration password
	# Required
	if(ref($tree->{patch}->{password}) eq 'ARRAY'){
		error("Only one password tag per patchfile.");
	}
	if($tree->{patch}->{password}){
		$password = $tree->{patch}->{password};
	} else {
		error("Patchfile is missing a password tag");
	}

	# Motd tag
	# Sets the MOTD, either in a file or a string
	# Not required
	if(ref($tree->{patch}->{motd}) eq 'ARRAY'){
		error("Only one MOTD tag per patchfile.");
	}
	if($tree->{patch}->{motd}){
		if((-e $tree->{patch}->{motd})&&(-f $tree->{patch}->{motd})){
			# MOTD is in a file;  load the file's contents as the MOTD
			open(FILE,"<$tree->{patch}->{motd}") or return undef;
			$motd = join('',<FILE>);
			close FILE;
		} else {
			# MOTD is in the element's text
			$motd = $tree->{patch}->{motd};
		}
	}

	# Nick tag
	# Sets the bot's default nick
	# Required
	if(ref($tree->{patch}->{nick}) eq 'ARRAY'){
		error("Only one nick tag per patchfile.");
	}
	if($tree->{patch}->{nick}){
		$xnick = $tree->{patch}->{nick};
	} else {
		error('Patchfile is missing a "nick" tag');
	}

	# Alternate tag
	# Sets the bot's alternate nick
	# Required
	if(ref($tree->{patch}->{alternate}) eq 'ARRAY'){
		error("Only one alternate tag per patchfile.");
	}
	if($tree->{patch}->{alternate}){
		$xanick = $tree->{patch}->{alternate};
	} else {
		error('Patchfile is missing a "alternate" tag');
	}

	# Ircname tag
	# Set the bot's username
	# Not required
	if(ref($tree->{patch}->{ircname}) eq 'ARRAY'){
		error("Only one ircname tag per patchfile.");
	}
	if($tree->{patch}->{ircname}){
		$xinfo = $tree->{patch}->{ircname};
	}

	# ======================
	# | PATCHFILE TAGS END |
	# ======================

	if($xnick ne ''){ $NICKNAME = $xnick;  $CURRENT_NICK= $NICKNAME; }
	if($xinfo ne ''){ $USERNAME = $xinfo; }
	if($xanick ne ''){ $ALTERNATE_NICK = $xanick; }

	$MOTD = $motd;

	$ADMIN_PASSWORD = $password;

	foreach my $s (@xservers) {
		my @e = split(':',$s);
		my $server = '';
		my $port = 6667;
		if($#e==1){
			$server = $e[0];
			$port = $e[1];
		} else {
			$server = $e[0];
		}
		my %entry = {};
		$entry{port} = $port;
		$entry{channels} = \@xchannels;
		$servers{$server} = \%entry;
	}
}

# clean_blacklist()
# Syntax: clean_blacklist()
# Arguments: 0
# Returns:  Nothing
# Description: Removes any clients from the blacklist that have timed out.
sub clean_blacklist {
	my @cleaned = ();
	foreach my $ent (@BLACKLIST){
		my @e = @{$ent};
		if ($e[BLACKLIST_LOCKOUT]<=$TIME){
			# remove from blacklist
			display($e[BLACKLIST_HOSTNAME]." removed from blacklist\n");
		}else{
			# keep on blacklist
			push(@cleaned,\@e);
		}
	}
	@BLACKLIST = @cleaned;
}

# add_user_to_blacklist()
# Syntax: my $time = add_user_to_blacklist($hostmask)
# Arguments: 1 (scalar)
# Returns:  The length of the blacklist time in seconds
# Description: Adds a user to the blacklist.  How long is a random amount of time,
#              from a minimum of BLACKLIST_LENGTH_MINIMUM to a maximum of
#              BLACKLIST_LENGTH_MAXIMUM, set in the constants at the beginning of
#              the script.  Current settings allow for a minimum of 60 seconds to
#              a maximum of 120 seconds.
sub add_user_to_blacklist {
	my $hostmask = shift;

	my $timeout = BLACKLIST_LENGTH_MINIMUM + int(rand(BLACKLIST_LENGTH_MAXIMUM - BLACKLIST_LENGTH_MINIMUM));

	if(is_user_blacklisted($hostmask)==0){
		my @e = ($hostmask,$TIME+$timeout);
		push(@BLACKLIST,\@e);
		display("$hostmask added to blacklist for ".$timeout." seconds)\n");
	}

	return $timeout;
}

# is_user_blacklisted()
# Syntax: is_user_blacklisted($hostmask)
# Arguments: 1 (scalar)
# Returns:  Scalar
# Description: Checks to see if a client is on the blacklist; returns 1 if they
#              are, 0 if not.
sub is_user_blacklisted {
	my $hostmask = shift;

	foreach my $ent (@BLACKLIST){
		my @e = @{$ent};
		if ($e[BLACKLIST_HOSTNAME] eq $hostmask) {
			return 1;
		}
	}
	return 0;
}

# banner_ascii_graphic()
# Syntax:  my $banner = banner_ascii_graphic()
# Arguments: 0
# Returns:  scalar
# Description:  Returns the ASCII graphic for the banner.
sub banner_ascii_graphic {
	my $banner = <<'BANNER';
    _                             __       __  
   (_)_________      ____  ____ _/ /______/ /_ 
  / / ___/ ___/_____/ __ \/ __ `/ __/ ___/ __ \
 / / /  / /__/_____/ /_/ / /_/ / /_/ /__/ / / /
/_/_/   \___/     / .___/\__,_/\__/\___/_/ /_/ 
                 /_/
BANNER
	return $banner;
}

# error()
# Syntax:  error("Here's my error text.");
# Arguments: 1 (scalar)
# Returns:  Nothing
# Description:  Displays the desired error message followed
#               by a newline, and exits.
sub error {
	my $text = shift;
	print "$text\n";
	exit 1;
}

# display()
# Syntax:  display("Here is some text\n");
# Arguments: 1 (scalar)
# Returns:  Nothing
# Description:  If verbose mode is turned on, it will print
#               any text passed to it to the console,
#               accompanied by a timestamp.
sub display {
	my $text = shift;
	if($VERBOSE==1){ 
		if($TIMESTAMP==1){
			print timestamp()." $text";
		} else {
			print "$text";
		}
	}
	if($LOG ne ""){
		open(FILE,">>$LOG") or die "Error writing to log file '$LOG'";
		if($TIMESTAMP==1){
			print FILE timestamp()." $text";
		} else {
			print FILE "$text";
		}
		close FILE;
	}
}

# timestamp()
# Syntax:  print timestamp()."\n";
# Arguments: 0
# Returns:  scalar
# Description:  Generates a timestamp for the current time/date,
#               and returns it, alond with the uptime, in seconds.
sub timestamp {
	my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = gmtime();
	my $year = 1900 + $yearOffset;
	return "[$hour:$minute:$second $month/$dayOfMonth/$year $TIME".'s'."]";
}

# broadcast()
# Syntax:  broadcast("Hello world!","#channel","irc.undernet.org");
# Arguments: 3 (scalar,scalar,scalar)
# Returns:  Nothing
# Description:  This will send a text message to the "link",
#               so that every channel/server in the network
#               receives it.  The first argument is the message
#               to send, the second is the channel to send it
#               to, and the third is the server where the message
#               originates from.
sub broadcast {
	my $message = shift;
	my $channel = shift;
	my $server = shift;
	
	foreach my $m (@MUTE) {
		my @mu = @{$m};
		if(($mu[0] eq $channel)&&($mu[1] eq $server)){ return; }
	}

	foreach my $n (@NETWORK) {
		my @ent = @{ $n };
		my $poco = $ent[1]->get_heap();
		my $name = $poco->server_name();
		if($name ne $server) {
			$ent[0]->post( $ent[1] => privmsg => $channel => "$message" );
		}
	}
}

# private_message()
# Syntax:  private_message($target,$message,$author,$kernel,$sender);
# Arguments:  5 (scalar,scalar,scalar,POE kernel,scalar)
# Returns:  Nothing
# Description:  Sends a private message to a specific user on the network.
#               If necessary, the user will be prompted for the target user's
#               server.
sub private_message {
	my $target = shift;
	my $message = shift;
	my $author = shift;
	my $kernel = shift;
	my $sender = shift;

	my $multiple_targets = -1;
	my $server = '';

	foreach my $u (@USERS) {
		my @ua = @{$u};
		if(lc($ua[0]) eq lc($target)){
			$multiple_targets=$multiple_targets+1;
			$server = $ua[2];
		}
	}

	my @s = split(' ',$message);
	if($#s>=1){
		foreach my $n (@NETWORK) {
			my @ent = @{ $n };
			my $poco = $ent[1]->get_heap();
			my $name = $poco->server_name();
			if(lc($s[0]) eq lc($name)){
				$multiple_targets = 0;
				$server = $name;
				shift @s;
				$message = join(' ',@s);
			}
		}
	}

	if($multiple_targets>=1){
		$kernel->post( $sender => notice => $author => $BOT_OUTPUT_SYMBOL."Multiple users named \"$target\" found." );
		$kernel->post( $sender => notice => $author => $BOT_OUTPUT_SYMBOL."Try \".private USERNAME SERVER MESSAGE" );
		return;
	}

	foreach my $n (@NETWORK) {
		my @ent = @{ $n };
		my $poco = $ent[1]->get_heap();
		my $name = $poco->server_name();
		if($name eq $server) {
			$ent[0]->post( $ent[1] => notice => $target => $BOT_OUTPUT_SYMBOL."$author -> $message" );
		}
	}
}

# get_server_list()
# Syntax:  my @server_list = get_server_list();
# Arguments:  0
# Returns:  array
# Description:  Builds and returns a list of all the servers the
#               bot is connected to.
sub get_server_list {
	my @s = ();
	foreach my $n (@NETWORK) {
		my @ent = @{ $n };
		my $poco = $ent[1]->get_heap();
		my $name = $poco->server_name();
		push(@s,$name);
	}
	return @s;
}

# update_user_list()
# Syntax:  update_user_list("irc.undernet.org","#channel",$kernel,$sender);
# Arguments:  4 (scalar,scalar,POE kernel,scalar)
# Returns:  Nothing
# Description:  "Refreshes" a channel's userlist (by deleting it and rebuilding it
#               with /whois data)
sub update_user_list {
	my $server = shift;
	my $channel = shift;
	my $kernel = shift;
	my $sender = shift;

	remove_channel_from_user_list($server,$channel);

	$kernel->post( $sender => who => $channel );
}

# remove_channel_from_user_list()
# Syntax:  remove_channel_from_user_list("irc.undernet.org","#channel");
# Arguments:  2 (scalar,scalar)
# Returns:  Nothing
# Description:  Removes all the users in a given channel from the user list.
sub remove_channel_from_user_list {
	my $server = shift;
	my $chan = shift;
	my @new = ();
	foreach my $e (@USERS) {
		my @ea = @{ $e };
		if(($ea[2] eq $server)&&($ea[1] eq $chan)){}else{ push(@new,$e); }
	}
	@USERS=@new;
}

# add_user_to_channel_user_list()
# Syntax:  add_user_to_channel_user_list($nick,"#channel","irc.undernet.org",0,1);
# Arguments:  4 (scalar,scalar,scalar,scalar (0 or 1),scalar (0 or 1))
# Returns:  Nothing
# Description:  Adds a user to the internal user list.
sub add_user_to_channel_user_list {
	my $nick = shift;
	my $channel = shift;
	my $server = shift;
	my $is_an_op = shift;
	my $is_voiced = shift;

	if($nick eq $CURRENT_NICK){ return; }

	my $counter = 0;
	foreach my $u (@USERS) {
		my @ua = @{ $u };
		if(($ua[0] eq $nick)&&($ua[1] eq $channel)&&($ua[2] eq $server)){
			my @entry = ( $nick,$channel,$server,$is_an_op,$is_voiced, $TIME );
			$USERS[$counter] = \@entry;
			return;
		}
		$counter=$counter+1;
	}

	my @entry = ( $nick,$channel,$server,$is_an_op,$is_voiced, $TIME );
	push(@USERS,\@entry);
}

# ===========================
# | SUPPORT SUBROUTINES END |
# ===========================

# =======================================================
# | XML::TreePP                                         |
# | By Yusuke Kawasaki                                  |
# | Copyright (c) 2006-2008 Yusuke Kawasaki.            |
# | All rights reserved. This program is free software; |
# | you can redistribute it and/or modify it under the  |
# | same terms as Perl itself.                          |
# =======================================================

package XML::TreePP;
use strict;
use Carp;
use Symbol;

use vars qw( $VERSION );
$VERSION = '0.33';

my $XML_ENCODING      = 'UTF-8';
my $INTERNAL_ENCODING = 'UTF-8';
my $USER_AGENT        = 'XML-TreePP/'.$VERSION.' ';
my $ATTR_PREFIX       = '-';
my $TEXT_NODE_KEY     = '#text';

sub new {
    my $package = shift;
    my $self    = {@_};
    bless $self, $package;
    $self;
}

sub die {
    my $self = shift;
    my $mess = shift;
    return if $self->{ignore_error};
    Carp::croak $mess;
}

sub warn {
    my $self = shift;
    my $mess = shift;
    return if $self->{ignore_error};
    Carp::carp $mess;
}

sub set {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;
    if ( defined $val ) {
        $self->{$key} = $val;
    }
    else {
        delete $self->{$key};
    }
}

sub get {
    my $self = shift;
    my $key  = shift;
    $self->{$key} if exists $self->{$key};
}

sub writefile {
    my $self   = shift;
    my $file   = shift;
    my $tree   = shift or return $self->die( 'Invalid tree' );
    my $encode = shift;
    return $self->die( 'Invalid filename' ) unless defined $file;
    my $text = $self->write( $tree, $encode );
    if ( $] >= 5.008001 && utf8::is_utf8( $text ) ) {
        utf8::encode( $text );
    }
    $self->write_raw_xml( $file, $text );
}

sub write {
    my $self = shift;
    my $tree = shift or return $self->die( 'Invalid tree' );
    my $from = $self->{internal_encoding} || $INTERNAL_ENCODING;
    my $to   = shift || $self->{output_encoding} || $XML_ENCODING;
    my $decl = $self->{xml_decl};
    $decl = '<?xml version="1.0" encoding="' . $to . '" ?>' unless defined $decl;

    local $self->{__first_out};
    if ( exists $self->{first_out} ) {
        my $keys = $self->{first_out};
        $keys = [$keys] unless ref $keys;
        $self->{__first_out} = { map { $keys->[$_] => $_ } 0 .. $#$keys };
    }

    local $self->{__last_out};
    if ( exists $self->{last_out} ) {
        my $keys = $self->{last_out};
        $keys = [$keys] unless ref $keys;
        $self->{__last_out} = { map { $keys->[$_] => $_ } 0 .. $#$keys };
    }

    my $tnk = $self->{text_node_key} if exists $self->{text_node_key};
    $tnk = $TEXT_NODE_KEY unless defined $tnk;
    local $self->{text_node_key} = $tnk;

    my $apre = $self->{attr_prefix} if exists $self->{attr_prefix};
    $apre = $ATTR_PREFIX unless defined $apre;
    local $self->{__attr_prefix_len} = length($apre);
    local $self->{__attr_prefix_rex} = defined $apre ? qr/^\Q$apre\E/s : undef;

    local $self->{__indent};
    if ( exists $self->{indent} && $self->{indent} ) {
        $self->{__indent} = ' ' x $self->{indent};
    }

    my $text = $self->hash_to_xml( undef, $tree );
    if ( $from && $to ) {
        my $stat = $self->encode_from_to( \$text, $from, $to );
        return $self->die( "Unsupported encoding: $to" ) unless $stat;
    }

    return $text if ( $decl eq '' );
    join( "\n", $decl, $text );
}

sub parsehttp {
    my $self = shift;

    local $self->{__user_agent};
    if ( exists $self->{user_agent} ) {
        my $agent = $self->{user_agent};
        $agent .= $USER_AGENT if ( $agent =~ /\s$/s );
        $self->{__user_agent} = $agent if ( $agent ne '' );
    } else {
        $self->{__user_agent} = $USER_AGENT;
    }

    my $http = $self->{__http_module};
    unless ( $http ) {
        $http = $self->find_http_module(@_);
        $self->{__http_module} = $http;
    }
    if ( $http eq 'LWP::UserAgent' ) {
        return $self->parsehttp_lwp(@_);
    }
    elsif ( $http eq 'HTTP::Lite' ) {
        return $self->parsehttp_lite(@_);
    }
    else {
        return $self->die( "LWP::UserAgent or HTTP::Lite is required: $_[1]" );
    }
}

sub find_http_module {
    my $self = shift || {};

    if ( exists $self->{lwp_useragent} && ref $self->{lwp_useragent} ) {
        return 'LWP::UserAgent' if defined $LWP::UserAgent::VERSION;
        return 'LWP::UserAgent' if &load_lwp_useragent();
        return $self->die( "LWP::UserAgent is required: $_[1]" );
    }

    if ( exists $self->{http_lite} && ref $self->{http_lite} ) {
        return 'HTTP::Lite' if defined $HTTP::Lite::VERSION;
        return 'HTTP::Lite' if &load_http_lite();
        return $self->die( "HTTP::Lite is required: $_[1]" );
    }

    return 'LWP::UserAgent' if defined $LWP::UserAgent::VERSION;
    return 'HTTP::Lite'     if defined $HTTP::Lite::VERSION;
    return 'LWP::UserAgent' if &load_lwp_useragent();
    return 'HTTP::Lite'     if &load_http_lite();
    return $self->die( "LWP::UserAgent or HTTP::Lite is required: $_[1]" );
}

sub load_lwp_useragent {
    return $LWP::UserAgent::VERSION if defined $LWP::UserAgent::VERSION;
    local $@;
    eval { require LWP::UserAgent; };
    $LWP::UserAgent::VERSION;
}

sub load_http_lite {
    return $HTTP::Lite::VERSION if defined $HTTP::Lite::VERSION;
    local $@;
    eval { require HTTP::Lite; };
    $HTTP::Lite::VERSION;
}

sub load_tie_ixhash {
    return $Tie::IxHash::VERSION if defined $Tie::IxHash::VERSION;
    local $@;
    eval { require Tie::IxHash; };
    $Tie::IxHash::VERSION;
}

sub parsehttp_lwp {
    my $self   = shift;
    my $method = shift or return $self->die( 'Invalid HTTP method' );
    my $url    = shift or return $self->die( 'Invalid URL' );
    my $body   = shift;
    my $header = shift;

    my $ua = $self->{lwp_useragent} if exists $self->{lwp_useragent};
    if ( ! ref $ua ) {
        $ua = LWP::UserAgent->new();
        $ua->timeout(10);
        $ua->env_proxy();
        $ua->agent( $self->{__user_agent} ) if defined $self->{__user_agent};
    } else {
        $ua->agent( $self->{__user_agent} ) if exists $self->{user_agent};
    }

    my $req = HTTP::Request->new( $method, $url );
    my $ct = 0;
    if ( ref $header ) {
        foreach my $field ( sort keys %$header ) {
            my $value = $header->{$field};
            $req->header( $field => $value );
            $ct ++ if ( $field =~ /^Content-Type$/i );
        }
    }
    if ( defined $body && ! $ct ) {
        $req->header( 'Content-Type' => 'application/x-www-form-urlencoded' );
    }
    $req->content($body) if defined $body;
    my $res = $ua->request($req);
    my $code = $res->code();
    my $text = $res->content();
    my $tree = $self->parse( \$text ) if $res->is_success();
    wantarray ? ( $tree, $text, $code ) : $tree;
}

sub parsehttp_lite {
    my $self   = shift;
    my $method = shift or return $self->die( 'Invalid HTTP method' );
    my $url    = shift or return $self->die( 'Invalid URL' );
    my $body   = shift;
    my $header = shift;

    my $http = HTTP::Lite->new();
    $http->method($method);
    my $ua = 0;
    if ( ref $header ) {
        foreach my $field ( sort keys %$header ) {
            my $value = $header->{$field};
            $http->add_req_header( $field, $value );
            $ua ++ if ( $field =~ /^User-Agent$/i );
        }
    }
    if ( defined $self->{__user_agent} && ! $ua ) {
        $http->add_req_header( 'User-Agent', $self->{__user_agent} );
    }
    $http->{content} = $body if defined $body;
    my $code = $http->request($url) or return;
    my $text = $http->body();
    my $tree = $self->parse( \$text );
    wantarray ? ( $tree, $text, $code ) : $tree;
}

sub parsefile {
    my $self = shift;
    my $file = shift;
    return $self->die( 'Invalid filename' ) unless defined $file;
    my $text = $self->read_raw_xml($file);
    $self->parse( \$text );
}

sub parse {
    my $self = shift;
    my $text = ref $_[0] ? ${$_[0]} : $_[0];
    return $self->die( 'Null XML source' ) unless defined $text;

    my $from = &xml_decl_encoding(\$text) || $XML_ENCODING;
    my $to   = $self->{internal_encoding} || $INTERNAL_ENCODING;
    if ( $from && $to ) {
        my $stat = $self->encode_from_to( \$text, $from, $to );
        return $self->die( "Unsupported encoding: $from" ) unless $stat;
    }

    local $self->{__force_array};
    local $self->{__force_array_all};
    if ( exists $self->{force_array} ) {
        my $force = $self->{force_array};
        $force = [$force] unless ref $force;
        $self->{__force_array} = { map { $_ => 1 } @$force };
        $self->{__force_array_all} = $self->{__force_array}->{'*'};
    }

    local $self->{__force_hash};
    local $self->{__force_hash_all};
    if ( exists $self->{force_hash} ) {
        my $force = $self->{force_hash};
        $force = [$force] unless ref $force;
        $self->{__force_hash} = { map { $_ => 1 } @$force };
        $self->{__force_hash_all} = $self->{__force_hash}->{'*'};
    }

    my $tnk = $self->{text_node_key} if exists $self->{text_node_key};
    $tnk = $TEXT_NODE_KEY unless defined $tnk;
    local $self->{text_node_key} = $tnk;

    my $apre = $self->{attr_prefix} if exists $self->{attr_prefix};
    $apre = $ATTR_PREFIX unless defined $apre;
    local $self->{attr_prefix} = $apre;

    if ( exists $self->{use_ixhash} && $self->{use_ixhash} ) {
        return $self->die( "Tie::IxHash is required." ) unless &load_tie_ixhash();
    }

    my $flat  = $self->xml_to_flat(\$text);
    my $class = $self->{base_class} if exists $self->{base_class};
    my $tree  = $self->flat_to_tree( $flat, '', $class );
    if ( ref $tree ) {
        if ( defined $class ) {
            bless( $tree, $class );
        }
        elsif ( exists $self->{elem_class} && $self->{elem_class} ) {
            bless( $tree, $self->{elem_class} );
        }
    }
    wantarray ? ( $tree, $text ) : $tree;
}

sub xml_to_flat {
    my $self    = shift;
    my $textref = shift;    # reference
    my $flat    = [];
    my $prefix = $self->{attr_prefix};
    my $ixhash = ( exists $self->{use_ixhash} && $self->{use_ixhash} );

    while ( $$textref =~ m{
        ([^<]*) <
        ((
            \? ([^<>]*) \?
        )|(
            \!\[CDATA\[(.*?)\]\]
        )|(
            \!DOCTYPE\s+([^\[\]<>]*(?:\[.*?\]\s*)?)
        )|(
            \!--(.*?)--
        )|(
            ([^\!\?\s<>](?:"[^"]*"|'[^']*'|[^"'<>])*)
        ))
        > ([^<]*)
    }sxg ) {
        my (
            $ahead,     $match,    $typePI,   $contPI,   $typeCDATA,
            $contCDATA, $typeDocT, $contDocT, $typeCmnt, $contCmnt,
            $typeElem,  $contElem, $follow
          )
          = ( $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13 );
        if ( defined $ahead && $ahead =~ /\S/ ) {
            $ahead =~ s/([^\040-\076])/sprintf("\\x%02X",ord($1))/eg;
            $self->warn( "Invalid string: [$ahead] before <$match>" );
        }

        if ($typeElem) {                        # Element
            my $node = {};
            if ( $contElem =~ s#^/## ) {
                $node->{endTag}++;
            }
            elsif ( $contElem =~ s#/$## ) {
                $node->{emptyTag}++;
            }
            else {
                $node->{startTag}++;
            }
            $node->{tagName} = $1 if ( $contElem =~ s#^(\S+)\s*## );
            unless ( $node->{endTag} ) {
                my $attr;
                while ( $contElem =~ m{
                    ([^\s\=\"\']+)=(?:(")(.*?)"|'(.*?)')
                }sxg ) {
                    my $key = $1;
                    my $val = &xml_unescape( $2 ? $3 : $4 );
                    if ( ! ref $attr ) {
                        $attr = {};
                        tie( %$attr, 'Tie::IxHash' ) if $ixhash;
                    }
                    $attr->{$prefix.$key} = $val;
                }
                $node->{attributes} = $attr if ref $attr;
            }
            push( @$flat, $node );
        }
        elsif ($typeCDATA) {    ## CDATASection
            if ( exists $self->{cdata_scalar_ref} && $self->{cdata_scalar_ref} ) {
                push( @$flat, \$contCDATA );    # as reference for scalar
            }
            else {
                push( @$flat, $contCDATA );     # as scalar like text node
            }
        }
        elsif ($typeCmnt) {                     # Comment (ignore)
        }
        elsif ($typeDocT) {                     # DocumentType (ignore)
        }
        elsif ($typePI) {                       # ProcessingInstruction (ignore)
        }
        else {
            $self->warn( "Invalid Tag: <$match>" );
        }
        if ( $follow =~ /\S/ ) {                # text node
            my $val = &xml_unescape($follow);
            push( @$flat, $val );
        }
    }
    $flat;
}

sub flat_to_tree {
    my $self   = shift;
    my $source = shift;
    my $parent = shift;
    my $class  = shift;
    my $tree   = {};
    my $text   = [];

    if ( exists $self->{use_ixhash} && $self->{use_ixhash} ) {
        tie( %$tree, 'Tie::IxHash' );
    }

    while ( scalar @$source ) {
        my $node = shift @$source;
        if ( !ref $node || UNIVERSAL::isa( $node, "SCALAR" ) ) {
            push( @$text, $node );              # cdata or text node
            next;
        }
        my $name = $node->{tagName};
        if ( $node->{endTag} ) {
            last if ( $parent eq $name );
            return $self->die( "Invalid tag sequence: <$parent></$name>" );
        }
        my $elem = $node->{attributes};
        my $forcehash = $self->{__force_hash_all} || $self->{__force_hash}->{$name};
        my $subclass;
        if ( defined $class ) {
            my $escname = $name;
            $escname =~ s/\W/_/sg;
            $subclass = $class.'::'.$escname;
        }
        if ( $node->{startTag} ) {              # recursive call
            my $child = $self->flat_to_tree( $source, $name, $subclass );
            next unless defined $child;
            my $hasattr = scalar keys %$elem if ref $elem;
            if ( UNIVERSAL::isa( $child, "HASH" ) ) {
                if ( $hasattr ) {
                    # some attributes and some child nodes
                    %$elem = ( %$elem, %$child );
                }
                else {
                    # some child nodes without attributes
                    $elem = $child;
                }
            }
            else {
                if ( $hasattr ) {
                    # some attributes and text node
                    $elem->{$self->{text_node_key}} = $child;
                }
                elsif ( $forcehash ) {
                    # only text node without attributes
                    $elem = { $self->{text_node_key} => $child };
                }
                else {
                    # text node without attributes
                    $elem = $child;
                }
            }
        }
        elsif ( $forcehash && ! ref $elem ) {
            $elem = {};
        }
        # bless to a class by base_class or elem_class
        if ( ref $elem && UNIVERSAL::isa( $elem, "HASH" ) ) {
            if ( defined $subclass ) {
                bless( $elem, $subclass );
            } elsif ( exists $self->{elem_class} && $self->{elem_class} ) {
                my $escname = $name;
                $escname =~ s/\W/_/sg;
                my $elmclass = $self->{elem_class}.'::'.$escname;
                bless( $elem, $elmclass );
            }
        }
        # next unless defined $elem;
        $tree->{$name} ||= [];
        push( @{ $tree->{$name} }, $elem );
    }
    if ( ! $self->{__force_array_all} ) {
        foreach my $key ( keys %$tree ) {
            next if $self->{__force_array}->{$key};
            next if ( 1 < scalar @{ $tree->{$key} } );
            $tree->{$key} = shift @{ $tree->{$key} };
        }
    }
    my $haschild = scalar keys %$tree;
    if ( scalar @$text ) {
        if ( scalar @$text == 1 ) {
            # one text node (normal)
            $text = shift @$text;
        }
        elsif ( ! scalar grep {ref $_} @$text ) {
            # some text node splitted
            $text = join( '', @$text );
        }
        else {
            # some cdata node
            my $join = join( '', map {ref $_ ? $$_ : $_} @$text );
            $text = \$join;
        }
        if ( $haschild ) {
            # some child nodes and also text node
            $tree->{$self->{text_node_key}} = $text;
        }
        else {
            # only text node without child nodes
            $tree = $text;
        }
    }
    elsif ( ! $haschild ) {
        # no child and no text
        $tree = "";
    }
    $tree;
}

sub hash_to_xml {
    my $self      = shift;
    my $name      = shift;
    my $hash      = shift;
    my $out       = [];
    my $attr      = [];
    my $allkeys   = [ keys %$hash ];
    my $fo = $self->{__first_out} if ref $self->{__first_out};
    my $lo = $self->{__last_out}  if ref $self->{__last_out};
    my $firstkeys = [ sort { $fo->{$a} <=> $fo->{$b} } grep { exists $fo->{$_} } @$allkeys ] if ref $fo;
    my $lastkeys  = [ sort { $lo->{$a} <=> $lo->{$b} } grep { exists $lo->{$_} } @$allkeys ] if ref $lo;
    $allkeys = [ grep { ! exists $fo->{$_} } @$allkeys ] if ref $fo;
    $allkeys = [ grep { ! exists $lo->{$_} } @$allkeys ] if ref $lo;
    unless ( exists $self->{use_ixhash} && $self->{use_ixhash} ) {
        $allkeys = [ sort @$allkeys ];
    }
    my $prelen = $self->{__attr_prefix_len};
    my $pregex = $self->{__attr_prefix_rex};

    foreach my $keys ( $firstkeys, $allkeys, $lastkeys ) {
        next unless ref $keys;
        my $elemkey = $prelen ? [ grep { $_ !~ $pregex } @$keys ] : $keys;
        my $attrkey = $prelen ? [ grep { $_ =~ $pregex } @$keys ] : [];

        foreach my $key ( @$elemkey ) {
            my $val = $hash->{$key};
            if ( !defined $val ) {
                push( @$out, "<$key />" );
            }
            elsif ( UNIVERSAL::isa( $val, 'ARRAY' ) ) {
                my $child = $self->array_to_xml( $key, $val );
                push( @$out, $child );
            }
            elsif ( UNIVERSAL::isa( $val, 'SCALAR' ) ) {
                my $child = $self->scalaref_to_cdata( $key, $val );
                push( @$out, $child );
            }
            elsif ( ref $val ) {
                my $child = $self->hash_to_xml( $key, $val );
                push( @$out, $child );
            }
            else {
                my $child = $self->scalar_to_xml( $key, $val );
                push( @$out, $child );
            }
        }

        foreach my $key ( @$attrkey ) {
            my $name = substr( $key, $prelen );
            my $val = &xml_escape( $hash->{$key} );
            push( @$attr, ' ' . $name . '="' . $val . '"' );
        }
    }
    my $jattr = join( '', @$attr );

    if ( defined $name && scalar @$out && ! grep { ! /^</s } @$out ) {
        # Use human-friendly white spacing
        if ( defined $self->{__indent} ) {
            s/^(\s*<)/$self->{__indent}$1/mg foreach @$out;
        }
        unshift( @$out, "\n" );
    }

    my $text = join( '', @$out );
    if ( defined $name ) {
        if ( scalar @$out ) {
            $text = "<$name$jattr>$text</$name>\n";
        }
        else {
            $text = "<$name$jattr />\n";
        }
    }
    $text;
}

sub array_to_xml {
    my $self  = shift;
    my $name  = shift;
    my $array = shift;
    my $out   = [];
    foreach my $val (@$array) {
        if ( !defined $val ) {
            push( @$out, "<$name />\n" );
        }
        elsif ( UNIVERSAL::isa( $val, 'ARRAY' ) ) {
            my $child = $self->array_to_xml( $name, $val );
            push( @$out, $child );
        }
        elsif ( UNIVERSAL::isa( $val, 'SCALAR' ) ) {
            my $child = $self->scalaref_to_cdata( $name, $val );
            push( @$out, $child );
        }
        elsif ( ref $val ) {
            my $child = $self->hash_to_xml( $name, $val );
            push( @$out, $child );
        }
        else {
            my $child = $self->scalar_to_xml( $name, $val );
            push( @$out, $child );
        }
    }

    my $text = join( '', @$out );
    $text;
}

sub scalaref_to_cdata {
    my $self = shift;
    my $name = shift;
    my $ref  = shift;
    my $data = defined $$ref ? $$ref : '';
    $data =~ s#(]])(>)#$1]]><![CDATA[$2#g;
    my $text = '<![CDATA[' . $data . ']]>';
    $text = "<$name>$text</$name>\n" if ( $name ne $self->{text_node_key} );
    $text;
}

sub scalar_to_xml {
    my $self   = shift;
    my $name   = shift;
    my $scalar = shift;
    my $copy   = $scalar;
    my $text   = &xml_escape($copy);
    $text = "<$name>$text</$name>\n" if ( $name ne $self->{text_node_key} );
    $text;
}

sub write_raw_xml {
    my $self = shift;
    my $file = shift;
    my $fh   = Symbol::gensym();
    open( $fh, ">$file" ) or return $self->die( "$! - $file" );
    print $fh @_;
    close($fh);
}

sub read_raw_xml {
    my $self = shift;
    my $file = shift;
    my $fh   = Symbol::gensym();
    open( $fh, $file ) or return $self->die( "$! - $file" );
    local $/ = undef;
    my $text = <$fh>;
    close($fh);
    $text;
}

sub xml_decl_encoding {
    my $textref = shift;
    return unless defined $$textref;
    my $args    = ( $$textref =~ /^(?:\s*\xEF\xBB\xBF)?\s*<\?xml(\s+\S.*)\?>/s )[0] or return;
    my $getcode = ( $args =~ /\s+encoding=(".*?"|'.*?')/ )[0] or return;
    $getcode =~ s/^['"]//;
    $getcode =~ s/['"]$//;
    $getcode;
}

sub encode_from_to {
    my $self   = shift;
    my $txtref = shift or return;
    my $from   = shift or return;
    my $to     = shift or return;

    unless ( defined $Encode::EUCJPMS::VERSION ) {
        $from = 'EUC-JP' if ( $from =~ /\beuc-?jp-?(win|ms)$/i );
        $to   = 'EUC-JP' if ( $to   =~ /\beuc-?jp-?(win|ms)$/i );
    }

    if ( $from =~ /^utf-?8$/i ) {
        $$txtref =~ s/^\xEF\xBB\xBF//s;         # UTF-8 BOM (Byte Order Mark)
    }

    my $setflag = $self->{utf8_flag} if exists $self->{utf8_flag};
    if ( $] < 5.008001 && $setflag ) {
        return $self->die( "Perl 5.8.1 is required for utf8_flag: $]" );
    }

    if ( $] >= 5.008 ) {
        &load_encode();
        my $check = ( $Encode::VERSION < 2.13 ) ? 0x400 : Encode::FB_XMLCREF();
        if ( $] >= 5.008001 && utf8::is_utf8( $$txtref ) ) {
            if ( $to =~ /^utf-?8$/i ) {
                # skip
            } else {
                $$txtref = Encode::encode( $to, $$txtref, $check );
            }
        } else {
            $$txtref = Encode::decode( $from, $$txtref );
            if ( $to =~ /^utf-?8$/i && $setflag ) {
                # skip
            } else {
                $$txtref = Encode::encode( $to, $$txtref, $check );
            }
        }
    }
    elsif ( (  uc($from) eq 'ISO-8859-1'
            || uc($from) eq 'US-ASCII'
            || uc($from) eq 'LATIN-1' ) && uc($to) eq 'UTF-8' ) {
        &latin1_to_utf8($txtref);
    }
    else {
        my $jfrom = &get_jcode_name($from);
        my $jto   = &get_jcode_name($to);
        return $to if ( uc($jfrom) eq uc($jto) );
        if ( $jfrom && $jto ) {
            &load_jcode();
            if ( defined $Jcode::VERSION ) {
                Jcode::convert( $txtref, $jto, $jfrom );
            }
            else {
                return $self->die( "Jcode.pm is required: $from to $to" );
            }
        }
        else {
            return $self->die( "Encode.pm is required: $from to $to" );
        }
    }
    $to;
}

sub load_jcode {
    return if defined $Jcode::VERSION;
    local $@;
    eval { require Jcode; };
}

sub load_encode {
    return if defined $Encode::VERSION;
    local $@;
    eval { require Encode; };
}

sub latin1_to_utf8 {
    my $strref = shift;
    $$strref =~ s{
        ([\x80-\xFF])
    }{
        pack( 'C2' => 0xC0|(ord($1)>>6),0x80|(ord($1)&0x3F) )
    }exg;
}

sub get_jcode_name {
    my $src = shift;
    my $dst;
    if ( $src =~ /^utf-?8$/i ) {
        $dst = 'utf8';
    }
    elsif ( $src =~ /^euc.*jp(-?(win|ms))?$/i ) {
        $dst = 'euc';
    }
    elsif ( $src =~ /^(shift.*jis|cp932|windows-31j)$/i ) {
        $dst = 'sjis';
    }
    elsif ( $src =~ /^iso-2022-jp/ ) {
        $dst = 'jis';
    }
    $dst;
}

sub xml_escape {
    my $str = shift;
    return '' unless defined $str;
    # except for TAB(\x09),CR(\x0D),LF(\x0A)
    $str =~ s{
        ([\x00-\x08\x0B\x0C\x0E-\x1F\x7F])
    }{
        sprintf( '&#%d;', ord($1) );
    }gex;
    $str =~ s/&(?!#(\d+;|x[\dA-Fa-f]+;))/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/'/&apos;/g;
    $str =~ s/"/&quot;/g;
    $str;
}

sub xml_unescape {
    my $str = shift;
    my $map = {qw( quot " lt < gt > apos ' amp & )};
    $str =~ s{
        (&(?:\#(\d+)|\#x([0-9a-fA-F]+)|(quot|lt|gt|apos|amp));)
    }{
        $4 ? $map->{$4} : &char_deref($1,$2,$3);
    }gex;
    $str;
}

sub char_deref {
    my( $str, $dec, $hex ) = @_;
    if ( defined $dec ) {
        return &code_to_utf8( $dec ) if ( $dec < 256 );
    }
    elsif ( defined $hex ) {
        my $num = hex($hex);
        return &code_to_utf8( $num ) if ( $num < 256 );
    }
    return $str;
}

sub code_to_utf8 {
    my $code = shift;
    if ( $code < 128 ) {
        return pack( C => $code );
    }
    elsif ( $code < 256 ) {
        return pack( C2 => 0xC0|($code>>6), 0x80|($code&0x3F));
    }
    elsif ( $code < 65536 ) {
        return pack( C3 => 0xC0|($code>>12), 0x80|(($code>>6)&0x3F), 0x80|($code&0x3F));
    }
    return shift if scalar @_;      # default value
    sprintf( '&#x%04X;', $code );
}
