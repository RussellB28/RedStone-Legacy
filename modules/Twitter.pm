# Module: Twitter. See below for documentation.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Twitter;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(conf_get err trans cmd_add cmd_del hook_add hook_del timer_add timer_del);
use API::IRC qw(notice privmsg cpart cjoin);
use API::Log qw(slog dbug alog);
use XML::RSS::Parser::Lite;
use LWP::Simple;
use Furl;
use HTML::Entities;
use TryCatch;
our $ENABLE_RUN = 0;
our $RUN_DELAY = 30;

# Initialization subroutine.
sub _init {
    # PostgreSQL is not supported, yet.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load Twitter: PostgreSQL is not supported.', 0); return }

    # Create `twitter` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS twitter (net TEXT, chan TEXT, user TEXT, lasturl TEXT)') or return;

    # Create our required hooks.
    hook_add('on_connect', 'twit.connect', \&M::Twitter::on_connect) or return;

    if (conf_get('twitter:feed_auto')) {
        $ENABLE_RUN = (conf_get('twitter:feed_auto'))[0][0];
    }

    if (!conf_get('twitter:feed_auto')) {
        err(2, "Twitter: Please verify that you have defined the auto feed value.", 0);
        return;
    } 

    if (conf_get('twitter:feed_delay')) {
        $RUN_DELAY = (conf_get('twitter:feed_delay'))[0][0];
    }

    if (!conf_get('twitter:feed_delay')) {
        err(2, "Twitter: Please verify that you have defined the feed delay value.", 0);
        return;
    }


    cmd_add('TWITTER', 0, 0, \%M::Twitter::HELP_TWITTER, \&M::Twitter::cmd_twitter) or return;

    if($ENABLE_RUN == 1)
    {
        my $delay = $RUN_DELAY*60;
        timer_add("autofeed", 2, $delay, \&M::Twitter::process_feed);
    }
    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the hooks.
    hook_del('on_connect', 'twit.connect') or return;

    # Delete the commands.
    cmd_del('TWITTER') or return;

    if($ENABLE_RUN == 1)
    {
        timer_del("autofeed") or return;
    }

    # Success.
    return 1;
}

# Help for TWITTER.

our %HELP_TWITTER = (
    en => "This command controls the Twitter module. \2Syntax:\2 TWITTER <ENABLE|DISABLE|INFO|RUN> [<#channel>[\@network]] [username]",
);

# Subroutine to check if logging for a channel is enabled.
sub check_status {
    my ($net, $chan) = @_;
    my $q = $Auto::DB->prepare('SELECT net FROM twitter WHERE net = ? AND chan = ?') or return 0;
    $q->execute(lc $net, lc $chan) or return 0;
    if ($q->fetchrow_array) {
        return 1;
    }
    return 0;
}

# Callback for the TWITTER command.
sub cmd_twitter {
    my ($src, @argv) = @_;

    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    my %data = (
                'nick' => $src->{nick},
                'user' => $src->{user},
                'host' => $src->{host}
               );

    given(uc $argv[0]) {
        when ('ENABLE') {
            if (!API::Std::has_priv(API::Std::match_user(%data), "twitter.admin")) {
                notice($src->{svr}, $src->{nick}, trans('Permission Denied').q{.});
                return;
            }

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
            notice($src->{svr}, $src->{nick}, "Twitter is already enabled for $chan\@$svr.") and return if check_status($svr, $chan);
            my $dbq = $Auto::DB->prepare('INSERT INTO twitter (net, chan, user, lasturl) VALUES (?, ?, ?, 0)');
            if ($dbq->execute($svr, lc $chan, $argv[2])) {
                $svr = fix_net($svr);
                privmsg($src->{svr}, $src->{chan}, "Twitter enabled for $chan\@$svr with username ".$argv[2].".");
                slog("[\2twitter\2] $src->{nick} enabled twitter for $chan\@$svr with username ".$argv[2].".");
                cjoin($svr, $chan);
            }
            else {
                privmsg($src->{svr}, $src->{chan}, 'Failed to enable twitter.');
            }

        }
        when ('DISABLE') {
            if (!API::Std::has_priv(API::Std::match_user(%data), "twitter.admin")) {
                notice($src->{svr}, $src->{nick}, trans('Permission Denied').q{.});
                return;
            }

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
            notice($src->{svr}, $src->{nick}, "Twitter is already disabled for $chan\@$svr.") and return if !check_status($svr, $chan);
            my $dbq = $Auto::DB->prepare('DELETE FROM twitter WHERE net = ? AND chan = ?');
            if ($dbq->execute($svr, lc $chan)) {
                $svr = fix_net($svr);
                privmsg($src->{svr}, $src->{chan}, "Twitter disabled for $chan\@$svr.");
                slog("[\2Twitter\2] $src->{nick} disabled twitter for $chan\@$svr.");
                cpart($svr, $chan, 'Unassigned by '. $src->{nick});
            }
            else {
                privmsg($src->{svr}, $src->{chan}, 'Failed to disable twitter.');
            }
        }
        when ('RUN') {
            if (!API::Std::has_priv(API::Std::match_user(%data), "twitter.admin")) {
                notice($src->{svr}, $src->{nick}, trans('Permission Denied').q{.});
                return;
            }

            privmsg($src->{svr}, $src->{chan}, "Processing Twitter Feeds...");
            process_feed();
            return;
        }
        when ('INFO') {
            if (!API::Std::has_priv(API::Std::match_user(%data), "twitter.admin")) {
                notice($src->{svr}, $src->{nick}, trans('Permission Denied').q{.});
                return;
            }

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
                privmsg($src->{svr}, $src->{chan}, "Twitter is \2ENABLED\2 for \2".$chan."\@".$svr."\2.");
            }
            else {
                privmsg($src->{svr}, $src->{chan}, "Twitter is  \2DISABLED\2 for \2$chan\@$svr\2.");
            }
        }
        default {
            # We don't know this command.
                try
                {
                    my $rp = new XML::RSS::Parser::Lite;
                    my $xml = get("http://twitter.com/statuses/user_timeline/$argv[0].rss");

                    if($rp->parse($xml))
                    {
                        if($rp->get(0))
                        {
                            my $it = $rp->get(0);
                            my $title = $it->get('title');
                            my $t_title = decode_entities($title);
                            my $t_url = decode_entities($it->get('url'));

                            my $tweet_url = "http://ur.cx/api/create.php?url=$t_url";
                            my $agent = Furl->new(agent => 'Auto IRC Bot', timeout => 5);

                            my $request = HTTP::Request->new(GET => $tweet_url);
                            my $result = $agent->request($request);

                            $result->is_success;

                            privmsg($src->{svr}, $src->{chan}, "Latest Tweet from $t_title");
                            privmsg($src->{svr}, $src->{chan}, "See ".$result->content." for more information.");
                        }
                        else
                        {
                            privmsg($src->{svr}, $src->{chan}, "Sorry, This Twitter Username does not exist.");
                        }
                    }
                    else
                    {
                        privmsg($src->{svr}, $src->{chan}, "Sorry, We could not retrieve the Latest Tweet at this time. Please try again later.");
                    }
                }
                catch
                {
                        privmsg($src->{svr}, $src->{chan}, "Sorry, We could not retrieve the Latest Tweet at this time. Please try again later.");

                }
            return;
        }
    }

   return 1;
}

sub on_connect {
    my ($svr) = @_;
    my $dbh = $Auto::DB->prepare('SELECT chan FROM twitter WHERE net = ?');
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
    my $dbh = $Auto::DB->prepare('SELECT net, chan, user, lasturl FROM twitter WHERE 1');
    $dbh->execute();
    my $i = 0;
    my @data = $dbh->fetchall_arrayref;
    foreach my $first (@data) {
        foreach my $second (@{$first}) {
                my $t_title;
                my $t_url;
                try
                {
                    my $rp = new XML::RSS::Parser::Lite;
                    my $xml = get("http://twitter.com/statuses/user_timeline/$second->[2].rss");

                    if($rp->parse($xml))
                    {
                        if($rp->get(0))
                        {
                            my $it = $rp->get(0);
                            my $title = $it->get('title');
                            #$title =~ s/$second->[2]: - //g;
                            $t_title = decode_entities($title);
                            $t_url = decode_entities($it->get('url'));
                        }
                        else
                        {
                            $t_title = "We were unable to retrieve the latest tweet from Twitter at this time.";
                            $t_url = "http://twitter.com/".$second->[2];
                        }
                    }
                    else
                    {
                        $t_title = "We were unable to retrieve the latest tweet from Twitter at this time.";
                        $t_url = "http://twitter.com/".$second->[2];
                    }

                    if($t_url ne $second->[3])  
                    {
                        my $lfm_url = "http://ur.cx/api/create.php?url=$t_url";
                        my $agent = Furl->new(agent => 'Auto IRC Bot', timeout => 5);

                        my $request = HTTP::Request->new(GET => $lfm_url);
                        my $result = $agent->request($request);

                        $result->is_success;

                        privmsg(fix_net($second->[0]), $second->[1], "[Twitter] Latest Tweet from $t_title");
                        privmsg(fix_net($second->[0]), $second->[1], "[Twitter] See ".$result->content." for more information.");
                        my $dbq = $Auto::DB->prepare('UPDATE twitter SET lasturl=? WHERE net = ? AND chan = ?');
                        $dbq->execute($t_url, lc $second->[0], $second->[1]);
                    }
                }
                catch
                {
                        $t_title = "We were unable to retrieve the latest tweet from Twitter at this time.";
                        $t_url = "http://twitter.com/".$second->[2];
                        privmsg(fix_net($second->[0]), $second->[1], "[Twitter] Latest Tweet from ".$second->[2].": $t_title");
                        privmsg(fix_net($second->[0]), $second->[1], "[Twitter] See $t_url for more information.");

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
API::Std::mod_init('Twitter', 'Xelhua', '1.00', '3.0.0a11');
# build: cpan=Furl,LWP::Simple,XML::RSS::Parser::Lite,HTML::Entities,TryCatch perl=5.010000

__END__

=head1 NAME

Twitter

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <user> !twitter enable #somechannel@SomeNetwork SomeTwitterUsername
 <auto> Twitter enabled for #somechannel@SomeNetwork with username SomeTwitterUsername.

 <user> !twitter disable #somechannel@SomeNetwork
 <auto> Twitter disabled for #somechannel@SomeNetwork.

 <user> !twitter info #somechannel@SomeNetwork
 <auto> Twitter is ENABLED for #somechannel@SomeNetwork.

 <user> !twitter run
 <auto> Processing Twitter Feeds...

 <user> !twitter SomeTwitterUsername
 <auto> Latest Tweet from SomeTwitterUsername: Tweet Message Here
 <auto> See http://short-twitter-url/bleh for more information.


=head1 DESCRIPTION

This module outputs the latest tweets from a specified username in a specifc
channel automatically at a set interval. It is also possible to retrieve the latest tweet or
from a Twitter User via command.

=head1 CONFIGURATION

Simply add the following to your configuration file in a block called twitter { }:

    twitter {
        feed_auto <0 or 1>;
        feed_delay <Number of minutes to check feeds>;
    }

=head2 Example

    twitter {
        feed_auto 1;
        feed_delay 10;
    };

=head2 Notes

Due to twitter limitations, only 150 requests can be made per hour. This means if you were
to have several feeds polling at a 10 minute interval, it may not work after a while. 


=head1 AUTHOR

This module was written by Russell Bradford.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Xelhua Development Group. All rights
reserved.

This module is released under the same licensing terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:

