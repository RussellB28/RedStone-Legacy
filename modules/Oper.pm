# Module: Oper.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Oper;
use strict;
use warnings;
use API::Std qw(hook_add hook_del rchook_add rchook_del conf_get trans cmd_add cmd_del);
use API::Log qw(alog dbug);

my %SCHAN;

# Initialization subroutine.
sub _init {
    # Add a hook for when we connect to a network.
    hook_add('on_connect', 'Oper.onconnect', \&M::Oper::on_connect) or return;
	#Add a hook for checking connect notices
	hook_add('on_notice', 'Oper.onnotice', \&M::Oper::on_notice) or return;
    # Add a hook for when we get numeric 491 (ERR_NOOPERHOST)
    rchook_add('491', 'Oper.on491', \&M::Oper::on_num491) or return;
	
	#OPER commands:
	cmd_add('ZLINE', 0, 'auto.ircoperator', \%M::Oper::HELP_ZLINE, \&M::Oper::cmd_zline) or return;
	cmd_add('GLINE', 0, 'auto.ircoperator', \%M::Oper::HELP_GLINE, \&M::Oper::cmd_gline) or return;
	cmd_add('SPAMFILTER', 0, 'auto.ircoperator', \%M::Oper::HELP_SPAMFILTER, \&M::Oper::cmd_spamfilter) or return;
	
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the hooks.
    hook_del('on_connect', 'Oper.onconnect') or return;
	hook_del('on_notice', 'Oper.onnotice') or return;
    rchook_del('491', 'Oper.on491') or return;
	
	cmd_del('ZLINE') or return;
	cmd_del('GLINE') or return;
	cmd_del('SPAMFILTER') or return;
    return 1;
}

our %HELP_ZLINE = (
    en => "Will use an IRC zline command. \2SYNTAX:\2 ZLINE [TIME] [MASK USER\@HOST] [REASON]",
	#nl => "Voert het IRC zline commando uit. \2SYNTAX:\2 ZLINE [TIJD] [MASKER GEBRUIKER@HOST] [REDEN]",
);
our %HELP_GLINE = (
    en => "Will use an IRC gline command. \2SYNTAX:\2 GLINE [TIME] [MASK USER\@HOST] [REASON]",
	#nl => "Voert het IRC gline commando uit. \2SYNTAX:\2 GLINE [TIJD] [MASKER GEBRUIKER@HOST] [REDEN]",
);
our %HELP_SPAMFILTER = (
    en => "Will use an IRC spamfilter command. \2SYNTAX:\2 SPAMFILTER [ADD|DEL|REMOVE|+|-] [c|p|n|N|P|q|d|a|t|u] [kill|tempshun|shun|kline|gline|zline|gzline|block|dccblock|viruschan|warn] [tkltime] [reason] [regex]",
	#nl => "Voert het IRC spamfilter commando uit. \2SYNTAX:\2 SPAMFILTER [ADD|DEL|REMOVE|+|-] [c|p|n|N|P|q|d|a|t|u] [kill|tempshun|shun|kline|gline|zline|gzline|block|dccblock|viruschan|warn] [tkltime] [REDEN] [regex]",
);

# On connect subroutine.
sub on_connect {
    my ($svr) = @_;
    # Get the configuration values.
    my $u = (conf_get("server:$svr:oper_username"))[0][0] if conf_get("server:$svr:oper_username");
    my $p = (conf_get("server:$svr:oper_password"))[0][0] if conf_get("server:$svr:oper_password");
	my $SCHAN{uc($svr)} = (conf_get("server:$svr:oper_channel"))[0][0] if conf_get("server:$svr:oper_channel");
    # They don't exist - don't continue.
    return if !$u or !$p;
    # Send the OPER command.
    oper($svr, $u, $p);
    return 1;
}

sub on_notice {
	my ($src, $target, @msg) = @_;
	
	my $m = join(' ',@msg);
	if($m =~ /^\*\*\* Notice -- Client exiting at (.+?): (.+?)!(.+?)@(.+?) \((.+?)\)$/i) {
		my $DisconnectServer = $1;
		my $DisconnectUser = $2;
		my $DisconnectIdent = $3;
		my $DisconnectIP = $4;
		my $DisconnectReason = $5;
		dbug "$DisconnectUser disconnected from $DisconnectServer (".$DisconnectIdent."@".$DisconnectIP.") [".$DisconnectReason."]";
		if(defined($SCHAN{uc($src->{svr})})) {
			privmsg($src->{svr},$SCHAN{uc($src->{svr}),"$DisconnectUser disconnected from $DisconnectServer (".$DisconnectIdent."@".$DisconnectIP.") [".$DisconnectReason."]");
		}
	}
	if($m =~ /^\*\*\* Notice -- Client connecting at (.+?): (.+?) \((.+?)@(.+?)\)/i) {
		my $ConnectServer = $1;
		my $ConnectUser = $2;
		my $ConnectIdent = $3;
		my $ConnectIP = $4;
		dbug "$ConnectUser connected to $ConnectServer (".$ConnectIdent."@".$ConnectIP.")";
		if(defined($SCHAN{uc($src->{svr})})) {
			privmsg($src->{svr},$SCHAN{uc($src->{svr}),"$ConnectUser connected to $ConnectServer (".$ConnectIdent."@".$ConnectIP.")");
		}
	}
}

# On 491 subroutine
sub on_num491 {
    my ($svr, @ex) = @_;
    my $reason = join ' ', @ex[3 .. $#ex];
    $reason =~ s/://xsm;
    alog("FAILED OPER on ".$svr.": ".$reason);
    return 1;
}

# A subroutine to check if we are opered on a server
sub is_opered {
    my ($svr) = @_;
    # Auto is not opered.
    return if $State::IRC::botinfo{$svr}{modes} !~ m/o/xsm;
    # Auto is opered.
    return 1 if $State::IRC::botinfo{$svr}{modes} =~ m/o/xsm;
    return;
}

# Start of the API

# Sends the OPER command to the specified server.
sub oper {
    my ($svr, $user, $pass) = @_;
    Auto::socksnd($svr, "OPER $user $pass");
    return 1;
}

# Deopers Auto on the specified server.
sub deoper {
    my ($svr) = @_;
    Auto::socksnd($svr, "MODE $State::IRC::botinfo{$svr}{nick} -o");
    return 1;
}

# Kills a user.
sub kill {
    my ($svr, $user, $reason) = @_;
    return if !is_opered($svr);
    if (defined $reason) {
        Auto::socksnd($svr, "KILL $user :$reason");
    }
    else {
        Auto::socksnd($svr, "KILL $user :Killed.");
    }
    return 1;
}

sub cmd_zline {
	my ($src, @argv) = @_;
	if(!defined($argv[2])) {
		privmsg($src->{svr},$src->{chan},trans('Not enough parameters').q{.});
		privmsg($src->{svr},$src->{chan},trans('SYNTAX: ZLINE [TIME] [MASK USER@HOST] [REASON]').q{.});
		return;
	}
	
	my $msg = join(' ',@argv[2 .. $#argv]);
	Auto::socksnd($src->{svr}, "ZLINE ".$argv[1]." ".$argv[0]." ".$msg);
	return 1;
}

sub cmd_gline {
	my ($src, @argv) = @_;
	if(!defined($argv[2])) {
		privmsg($src->{svr},$src->{chan},trans('Not enough parameters').q{.});
		privmsg($src->{svr},$src->{chan},trans('SYNTAX: GLINE [TIME] [MASK USER@HOST] [REASON]').q{.});
		return;
	}
	
	my $msg = join(' ',@argv[2 .. $#argv]);
	Auto::socksnd($src->{svr}, "GLINE ".$argv[1]." ".$argv[0]." ".$msg);
	return 1;
}

sub cmd_spamfilter {
	my ($src, @argv) = @_;
	if(!defined($argv[5])) {
		privmsg($src->{svr},$src->{chan},trans('Not enough parameters').q{.});
		return;
	}
	if($argv[0] =~ /^(add|del|remove|\+|-)$/i) {
		if($argv[1] =~ /^(c|p|n|N|P|q|d|a|t|u)$/) {
			if($argv[2] =~ /^(kill|tempshun|shun|kline|gline|zline|gzline|block|dccblock|viruschan|warn)$/i) {
				if(defined($argv[5])) {
					my $msg = join(' ',@argv);
					Auto::socksnd($src->{svr}, "SPAMFILTER ".$msg);
					return 1;
				} else {
					privmsg($src->{svr},$src->{chan},"Please specify all parameters");
					return;
				}
			} else {
				privmsg($src->{svr},$src->{chan},"Please use the correct action");
				return;
			}
		} else {
			privmsg($src->{svr},$src->{chan},"Please use the correct type");
			return;
		}
	} else {
		privmsg($src->{svr},$src->{chan},"Please use add del remove + -");
		return;
	}
	return 1;
}

# End of the API

# Start initialization.
API::Std::mod_init('Oper', 'Xelhua & Peter Selten/[nas]peter', '1.02', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

Oper - Auto oper-on-connect module.

=head1 VERSION

 1.02

=head1 SYNOPSIS

 zline
 gline
 spamfilter

=head1 DESCRIPTION

This module adds the ability for Auto to oper on networks he is
configured to do so on. And it adds a few commands that can be 
used by people configured in the config. Before being able
to use the commands in this module, you must give people
the permission: 'auto.ircoperator'

=head1 INSTALL

Before using Oper,  add the following to the server block in your
configuration file, only for servers you wish for Auto to oper on
though:

 oper_username <username>;
 oper_password <password>;
 oper_channel <channel>;

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by Xelhua Development Group.

This module was updated by Peter Selten/[nas]peter and currently maintained by RedStone development group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
