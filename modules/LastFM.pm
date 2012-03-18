# Module: LastFM. See below for documentation.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::LastFM;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(conf_get err trans cmd_add cmd_del hook_add hook_del timer_add timer_del);
use API::IRC qw(notice privmsg cpart cjoin);
use API::Log qw(slog dbug alog);
use POSIX;
use LWP::UserAgent;
use XML::Simple;
our $ENABLE_RUN = 0;
our $RUN_DELAY = 30;

# Initialization subroutine.
sub _init {
    # PostgreSQL is not supported, yet.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load LastFM: PostgreSQL is not supported.', 0); return }


    # Create `lastfm` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS lastfm (net TEXT, chan TEXT, user TEXT, lastsong TEXT)') or return;

    # Create our required hooks.
    hook_add('on_connect', 'lastfm.connect', \&M::LastFM::on_connect) or return;


    if (conf_get('lastfm:feed_auto')) {
        $ENABLE_RUN = (conf_get('lastfm:feed_auto'))[0][0];
    }

    if (!conf_get('lastfm:feed_auto')) {
        err(2, "LastFM: Please verify that you have defined the auto feed value.", 0);
        return;
    } 

    if (conf_get('lastfm:feed_delay')) {
        $RUN_DELAY = (conf_get('lastfm:feed_delay'))[0][0];
    }

    if (!conf_get('lastfm:feed_delay')) {
        err(2, "LastFM: Please verify that you have defined the feed delay value.", 0);
        return;
    }

    cmd_add('NP', 0, 0, \%M::LastFM::HELP_NP, \&M::LastFM::cmd_np) or return;
    cmd_add('LASTFM', 0, 'lastfm.admin', \%M::LastFM::HELP_LASTFM, \&M::LastFM::cmd_lastfm) or return;

    if($ENABLE_RUN == 1)
    {
        my $delay = $RUN_DELAY*60;
        timer_add("lastfeed", 2, $delay, \&M::LastFM::process_feed);
    }
    # Success.

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the hooks.
    hook_del('on_connect', 'lastfm.connect') or return;

    # Delete the commands.
    cmd_del('NP') or return;
    cmd_del('LASTFM') or return;

    if($ENABLE_RUN == 1)
    {
        timer_del("lastfeed") or return;
    }

    # Success.
    return 1;
}

# Help for NP.

our %HELP_NP = (
    en => "This command shows the currently playing track or last playing track from LastFM. \2Syntax:\2 NP <LASTFM USERNAME>",
);

our %HELP_LASTFM = (
    en => "This command controls the LastFM Module. \2Syntax:\2 LASTFM <ENABLE|DISABLE|INFO|RUN> [<#channel>[\@network]] [username]",
);

# Subroutine to check if logging for a channel is enabled.
sub check_status {
    my ($net, $chan) = @_;
    my $q = $Auto::DB->prepare('SELECT net FROM lastfm WHERE net = ? AND chan = ?') or return 0;
    $q->execute(lc $net, lc $chan) or return 0;
    if ($q->fetchrow_array) {
        return 1;
    }
    return 0;
}

# Callback for the NP command.
sub cmd_np {
    my ($src, @argv) = @_;

    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    given(uc $argv[0]) {

        my $uname = $argv[0];

        my $xml = new XML::Simple;

        my $xml_url = "http://ws.audioscrobbler.com/2.0/user/".$uname."/recenttracks.xml";
        my $agent = LWP::UserAgent->new();
        $agent->agent('Auto IRC Bot');

        $agent->timeout(60);

        my $request = HTTP::Request->new(GET => $xml_url);
        my $result = $agent->request($request);

        if(!$result->is_success)
        {
            if(lc($result->content) =~ m/private/)
	        {
                privmsg($src->{svr}, $src->{chan}, "The LastFM user '$uname' has made their recent tracks private. You will need to login to LastFM and have access to view this users tracks.");
            }
            if(lc($result->content) =~ m/no user/)
	        {
                privmsg($src->{svr}, $src->{chan}, "There is no LastFM user with the username '$uname'.");
	        }
            return 1;
        }

        my $data = $xml->XMLin($result->content);

	    if($data->{'total'} eq "0")
	    {
            privmsg($src->{svr}, $src->{chan}, "$uname has never played anything.");
            return 1;
	    }

        my ($date, $track, $artist);


        foreach my $key ( keys %{$data->{'track'}} )
        {
		    if($data->{'track'}->{$key}->{'nowplaying'} eq "true")
		    {
                privmsg($src->{svr}, $src->{chan}, "$uname is now playing: $key - ".$data->{'track'}->{$key}->{'artist'}->{'content'});
                return 1;
		    }
            
		    elsif($date < $data->{'track'}->{$key}->{'date'}->{'uts'})
		    {
				$track = $key;
				$artist = $data->{'track'}->{$key}->{'artist'}->{'content'};
				$date = $data->{'track'}->{$key}->{'date'}->{'uts'};
		    }
		}

        my $played_time = scalar localtime ($date);
        privmsg($src->{svr}, $src->{chan}, "$uname is not playing anything at the moment but last played: '$track - $artist' on $played_time");
        return 1;

    }

   return 1;
}

# Callback for the LastFM command.
sub cmd_lastfm {
    my ($src, @argv) = @_;

    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    given(uc $argv[0]) {
        when ('ENABLE') {
            my $chan;
            my $svr = lc($src->{svr});
            if (!defined $argv[2]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            $chan = $src->{chan};
            if (defined $argv[1]) {
                if ($argv[1] =~ m/(#.*)\@(.*)/) {
                    $chan = $1;
                    $svr = lc($2);
                }
                else {
                    $chan = $argv[1];
                }                                                                              
            }
            if(!fix_net($svr)) {
                privmsg($src->{svr}, $src->{chan}, "I'm not configured for $svr.");
                return;
            }
            notice($src->{svr}, $src->{nick}, "LastFM is already enabled for $chan\@$svr.") and return if check_status($svr, $chan);
            my $dbq = $Auto::DB->prepare('INSERT INTO lastfm (net, chan, user, lastsong) VALUES (?, ?, ?, 0)');
            if ($dbq->execute($svr, lc $chan, $argv[2])) {
                $svr = fix_net($svr);
                privmsg($src->{svr}, $src->{chan}, "LastFM enabled for $chan\@$svr with username ".$argv[2].".");
                slog("[\2LastFM\2] $src->{nick} enabled lastfm for $chan\@$svr with username ".$argv[2].".");
                cjoin($svr, $chan);
            }
            else {
                privmsg($src->{svr}, $src->{chan}, 'Failed to enable lastfm.');
            }

        }
        when ('DISABLE') {
            my $chan;
            my $svr = lc($src->{svr});
            if (!defined $argv[1]) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            $chan = $src->{chan};
            if (defined $argv[1]) {
                if ($argv[1] =~ m/(#.*)\@(.*)/) {
                    $chan = $1;
                    $svr = lc($2);
                }   
                else {
                    $chan = $argv[1];
                }
            }
            if(!fix_net($svr)) {
                privmsg($src->{svr}, $src->{chan}, "I'm not configured for $svr.");
                return;
            }
            notice($src->{svr}, $src->{nick}, "LastFM is already disabled for $chan\@$svr.") and return if !check_status($svr, $chan);
            my $dbq = $Auto::DB->prepare('DELETE FROM lastfm WHERE net = ? AND chan = ?');
            if ($dbq->execute($svr, lc $chan)) {
                $svr = fix_net($svr);
                privmsg($src->{svr}, $src->{chan}, "LastFM disabled for $chan\@$svr.");
                slog("[\2LastFM\2] $src->{nick} disabled lastfm for $chan\@$svr.");
                cpart($svr, $chan, 'Unassigned by '. $src->{nick});
            }
            else {
                privmsg($src->{svr}, $src->{chan}, 'Failed to disable lastfm.');
            }
        }
        when ('RUN') {
            privmsg($src->{svr}, $src->{chan}, "Processing LastFM Feeds...");
            process_feed();
            return;
        }
        when ('INFO') {
            my $chan;
            my $svr = lc($src->{svr});
            if (!defined $argv[1] and !defined $src->{chan}) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            $chan = $src->{chan};
            if (defined $argv[1]) {
                if ($argv[1] =~ m/(#.*)\@(.*)/) {
                    $chan = $1;
                    $svr = lc($2);
                }
                else {
                    $chan = $argv[1];
                }
            }
            if(!fix_net($svr)) {
                privmsg($src->{svr}, $src->{chan}, "I'm not configured for $svr.");
                return;
            }
            my $mchan = substr($chan, 1);
            if (check_status($svr, $chan)) {
                privmsg($src->{svr}, $src->{chan}, "LastFM is \2ENABLED\2 for \2".$chan."\@".$svr."\2.");
            }
            else {
                privmsg($src->{svr}, $src->{chan}, "LastFM is  \2DISABLED\2 for \2$chan\@$svr\2.");
            }
        }
        default {
            # We don't know this command.
            notice($src->{svr}, $src->{nick}, trans('Unknown action', $_).q{.});
            return;
        }
    }

   return 1;
}

sub on_connect {
    my ($svr) = @_;
    my $dbh = $Auto::DB->prepare('SELECT chan FROM lastfm WHERE net = ?');
    $dbh->execute(lc $svr);
    my @data = $dbh->fetchall_arrayref;
    foreach my $first (@data) {
        foreach my $second (@{$first}) {
            foreach my $channel (@{$second}) {
                cjoin($svr, $channel);
            }
        }
    }
}

sub process_feed {
    my $dbh = $Auto::DB->prepare('SELECT net, chan, user, lastsong FROM lastfm WHERE 1');
    $dbh->execute();
    my $i = 0;
    my @data = $dbh->fetchall_arrayref;
    foreach my $first (@data) {
        foreach my $second (@{$first}) {


            my $xml = new XML::Simple;

            my $uname = $second->[2];
            my $xml_url = "http://ws.audioscrobbler.com/2.0/user/".$uname."/recenttracks.xml";
            my $agent = LWP::UserAgent->new();
            $agent->agent('Auto IRC Bot');

            $agent->timeout(60);

            my $request = HTTP::Request->new(GET => $xml_url);
            my $result = $agent->request($request);

            if(!$result->is_success)
            {
                if(lc($result->content) =~ m/private/)
	            {
                    privmsg(fix_net($second->[0]), $second->[1], "[LastFM] The LastFM user '$uname' has made their recent tracks private. You will need to login to LastFM and have access to view this users tracks.");
                }
                if(lc($result->content) =~ m/no user/)
	            {
                    privmsg(fix_net($second->[0]), $second->[1], "[LastFM] There is no LastFM user with the username '$uname'.");
	            }
                my $dbq = $Auto::DB->prepare('UPDATE lastfm SET lastsong=? WHERE net = ? AND chan = ?');
                $dbq->execute("NONE", lc $second->[0], $second->[1]);
            }

            my $data = $xml->XMLin($result->content);

	        if($data->{'total'} eq "0")
	        {
                privmsg(fix_net($second->[0]), $second->[1], "[LastFM] $uname has never played anything.");
                my $dbq = $Auto::DB->prepare('UPDATE lastfm SET lastsong=? WHERE net = ? AND chan = ?');
                $dbq->execute("NONE", lc $second->[0], $second->[1]);
	        }

            my ($date, $track, $artist);


            foreach my $key ( keys %{$data->{'track'}} )
            {
		        if($data->{'track'}->{$key}->{'nowplaying'} eq "true")
		        {
                    my $dbq = $Auto::DB->prepare('UPDATE lastfm SET lastsong=? WHERE net = ? AND chan = ?');
                    $dbq->execute($key." - ".$data->{'track'}->{$key}->{'artist'}->{'content'}, lc $second->[0], $second->[1]);
                    privmsg(fix_net($second->[0]), $second->[1], "[LastFM] $uname is now playing: $key - ".$data->{'track'}->{$key}->{'artist'}->{'content'});
		        }
		    }
        }
    }
}



sub fix_net {
    my ($net) = @_;
    my %servers = conf_get('server');
    foreach my $name (keys %servers) {
         if (lc($name) eq lc($net)) {
              return $name;
         }
    }
    return 0;
}

# Start initialization.
API::Std::mod_init('LastFM', 'Russell', '1.00', '3.0.0a11');
# build: perl=5.010000 cpan=LWP::UserAgent, XML::Simple

__END__

=head1 NAME

LastFM

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <user> !lastfm enable #somechannel@SomeNetwork LastFMUsername
 <auto> LastFM enabled for #somechannel@SomeNetwork with username LastFMUsername.

 <user> !lastfm disable #somechannel@SomeNetwork
 <auto> LastFM disabled for #somechannel@SomeNetwork.

 <user> !lastfm info #somechannel@SomeNetwork
 <auto> LastFM is ENABLED for #somechannel@SomeNetwork.

 <user> !lastfm run
 <auto> Processing LastFM Feeds...

 <user> !np LastFMUsername
 <auto> LastFMUsername is now playing: Track Name - Artist Name

=head1 DESCRIPTION

This module outputs the now playing song from LastFM from a specified username into a specifc
channel automatically at a set interval. It is also possible to retrieve the last played song or
the current playing song from a LastFM User via command.

=head1 CONFIGURATION

Simply add the following to your configuration file in a block called lastfm { }:

    lastfm {
        feed_auto <0 or 1>;
        feed_delay <Number of minutes to check each lastfm user>;
    }

=head2 Example

    lastfm {
        feed_auto 1;
        feed_delay 10;
    };

=head2 Notes

As far as im aware, LastFM does not limit the number of requests that can be made to the feeds that the information
is retrieved from. There may however be a limit so be warned that it may stop working if such a limit exists and is reached.


=head1 AUTHOR

This module was written by Russell Bradford.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Xelhua Development Group. All rights
reserved.

This module is released under the same licensing terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:

