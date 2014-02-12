# Module: Twitter. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Twitter;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(conf_get err trans cmd_add cmd_del hook_add hook_del timer_add timer_del);
use API::IRC qw(notice privmsg cpart cjoin);
use API::Log qw(slog dbug alog);
use HTML::Entities qw(decode_entities);
use Net::Twitter;
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

    if (!conf_get('twitter:feed_auto')) {
        err(2, "Twitter: Please verify that you have defined the auto feed value.", 0);
        return;
    }

    if (!conf_get('twitter:feed_delay')) {
        err(2, "Twitter: Please verify that you have defined the feed delay value.", 0);
        return;
    }

    if (!conf_get('twitter:consumer_key')) {
        err(2, "Twitter: Please verify that you have defined the consumer key value.", 0);
        return;
    }

    if (!conf_get('twitter:consumer_secret')) {
        err(2, "Twitter: Please verify that you have defined the consumer secret value.", 0);
        return;
    }

    if (!conf_get('twitter:access_token')) {
        err(2, "Twitter: Please verify that you have defined the access token value.", 0);
        return;
    }

    if (!conf_get('twitter:access_secret')) {
        err(2, "Twitter: Please verify that you have defined the access secret value.", 0);
        return;
    }

    $ENABLE_RUN = (conf_get('twitter:feed_auto'))[0][0];
    $RUN_DELAY = (conf_get('twitter:feed_delay'))[0][0];

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
        when ('FOLLOWS') {

            if (!defined $argv[2] and !defined $src->{chan}) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }

            # When no authentication is required:
            my $nt = Net::Twitter->new(legacy => 0);

            # As of 13-Aug-2010, Twitter requires OAuth for authenticated requests
            my $nt = Net::Twitter->new(
                traits   => [qw/API::RESTv1_1/],
                consumer_key        => (conf_get('twitter:consumer_key'))[0][0],
                consumer_secret     => (conf_get('twitter:consumer_secret'))[0][0],
                access_token        => (conf_get('twitter:access_token'))[0][0],
                access_token_secret => (conf_get('twitter:access_secret'))[0][0],
                ssl                 => 1,
            );

            eval {
                my $follows = $nt->friendship_exists({ screen_name_a => $argv[1], screen_name_b => $argv[2] });
                if($follows == 1)
                {
                    privmsg($src->{svr}, $src->{chan}, "\002$argv[1]\002 is currently following \002$argv[2]\002");
                }
                else
                {
                    privmsg($src->{svr}, $src->{chan}, "\002$argv[1]\002 is not currently following \002$argv[2]\002");
                }
            };

            if ( my $err = $@ ) {
                if($err =~ "Not authorized")
                {
                    privmsg($src->{svr}, $src->{chan}, "Authentication Error Occured.");   
                    return 0;                 
                }
                elsif($err =~ "Could not determine source user")
                {
                    privmsg($src->{svr}, $src->{chan}, "User \002$argv[1]\002 does not exist.");   
                    return 0;                 
                }
                elsif($err =~ "Sorry, that page does not exist")
                {
                    privmsg($src->{svr}, $src->{chan}, "User \002$argv[2]\002 does not exist.");   
                    return 0;                 
                }
                elsif($err =~ "Could not authenticate you")
                {
                    privmsg($src->{svr}, $src->{chan}, "\002Error:\002 API Authentication Failed.");   
                    privmsg($src->{svr}, $src->{chan}, "This sometimes happens if you use special characters, check there are no hidden/special characters in either screen name.");  
                    return 0;                 
                }
                elsif($err =~ "Malformed UTF-8 character")
                {
                    privmsg($src->{svr}, $src->{chan}, "\002Error:\002 Malformed UTF-8 Character Detected. Please remove any special characters that may be causing this error.");   
                    return 0;                 
                }
                privmsg($src->{svr}, $src->{chan}, "An error occured: $@"); 
                return 0;

                # Left this in for debugging if we ever get problems in the future..
                #warn "HTTP Response Code: ", $err->code, "\n",
                #     "HTTP Message......: ", $err->message, "\n",
                #     "Twitter error.....: ", $err->error, "\n";
            }
        }
        default {
            # We don't know this command.
            # When no authentication is required:
            my $nt = Net::Twitter->new(legacy => 0);

            # As of 13-Aug-2010 and now that v1 of the API is deprecated, Twitter requires OAuth for authenticated requests
            my $nt = Net::Twitter->new(
                traits   => [qw/API::RESTv1_1/],
                consumer_key        => (conf_get('twitter:consumer_key'))[0][0],
                consumer_secret     => (conf_get('twitter:consumer_secret'))[0][0],
                access_token        => (conf_get('twitter:access_token'))[0][0],
                access_token_secret => (conf_get('twitter:access_secret'))[0][0],
                ssl                 => 1,
            );

            eval {
                my $statuses = $nt->user_timeline({ screen_name => $argv[0], count => 1 });
                for my $status ( @$statuses ) {
                    privmsg($src->{svr}, $src->{chan}, "\002$status->{user}{screen_name}:\002 ".decode_entities($status->{text})."");
                    privmsg($src->{svr}, $src->{chan}, "\002Tweeted:\002 $status->{created_at} :: \002Retweets:\002 $status->{retweet_count} :: \002Link:\002 https://twitter.com/".$argv[0]."/status/$status->{id}");
                }
            };

            if ( my $err = $@ ) {
                if($err =~ "Not authorized")
                {
                    privmsg($src->{svr}, $src->{chan}, "\002$argv[0]\002 has protected their tweets. We are therefore unable to retrieve the latest tweet.");   
                    return 0;                 
                }
                elsif($err =~ "Sorry, that page does not exist")
                {
                    privmsg($src->{svr}, $src->{chan}, "User \002$argv[0]\002 does not exist. Are you sure you have used the correct username or the user has not changed it?");   
                    return 0;                 
                }
                elsif($err =~ "Could not authenticate you")
                {
                    privmsg($src->{svr}, $src->{chan}, "\002Error:\002 API Authentication Failed.");   
                    privmsg($src->{svr}, $src->{chan}, "This sometimes happens if you use special characters, check there are no hidden/special characters in the screen name.");  
                    return 0;                 
                }
                elsif($err =~ "Malformed UTF-8 character")
                {
                    privmsg($src->{svr}, $src->{chan}, "\002Error:\002 Malformed UTF-8 Character Detected. Please remove any special characters that may be causing this error.");   
                    return 0;                 
                }
                privmsg($src->{svr}, $src->{chan}, "An error occured: $@"); 
                return 0;

                # Left this in for debugging if we ever get problems in the future..
                #warn "HTTP Response Code: ", $err->code, "\n",
                #     "HTTP Message......: ", $err->message, "\n",
                #     "Twitter error.....: ", $err->error, "\n";
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

                # As of 13-Aug-2010 and now that v1 of the API is deprecated, Twitter requires OAuth for authenticated requests
                my $nt = Net::Twitter->new(
                    traits   => [qw/API::RESTv1_1/],
                    consumer_key        => (conf_get('twitter:consumer_key'))[0][0],
                    consumer_secret     => (conf_get('twitter:consumer_secret'))[0][0],
                    access_token        => (conf_get('twitter:access_token'))[0][0],
                    access_token_secret => (conf_get('twitter:access_secret'))[0][0],
                    ssl                 => 1,
                );

            eval {
                my $statuses = $nt->user_timeline({ screen_name => $second->[2], count => 1 });
                for my $status ( @$statuses ) {
                    my $uriformat = "https://twitter.com/".$second->[2]."/status/$status->{id}";
                    if($uriformat ne $second->[3])
                    {
                        privmsg(fix_net($second->[0]), $second->[1], "\002$status->{user}{screen_name}:\002 ".decode_entities($status->{text})."");
                        privmsg(fix_net($second->[0]), $second->[1], "\002Tweeted:\002 $status->{created_at} :: \002Retweets:\002 $status->{retweet_count} :: \002Link:\002 https://twitter.com/".$second->[2]."/status/$status->{id}");
                        my $dbq = $Auto::DB->prepare('UPDATE twitter SET lasturl=? WHERE net = ? AND chan = ?');
                        $dbq->execute($uriformat, lc $second->[0], $second->[1]);
                    }
                }
            };

            if ( my $err = $@ ) {
                warn "Feed for ".$second->[2]." on ".$second->[1]." could not be processed\n",
                     "HTTP Response Code: ", $err->code, "\n",
                     "HTTP Message......: ", $err->message, "\n",
                     "Twitter error.....: ", $err->error, "\n";
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
API::Std::mod_init('Twitter', 'Russell M Bradford', '1.02', '3.0.0a11');
# build: cpan=Net::Twitter,HTML::Entities,TryCatch perl=5.010000

__END__

=head1 NAME

Twitter

=head1 VERSION

 1.01

=head1 SYNOPSIS

 <SomeUser> !twitter enable #somechannel@SomeNetwork SomeTwitterUsername
 <RedStone> Twitter enabled for #somechannel@SomeNetwork with username SomeTwitterUsername.

 <SomeUser> !twitter disable #somechannel@SomeNetwork
 <RedStone> Twitter disabled for #somechannel@SomeNetwork.

 <SomeUser> !twitter info #somechannel@SomeNetwork
 <RedStone> Twitter is ENABLED for #somechannel@SomeNetwork.

 <SomeUser> !twitter run
 <RedStone> Processing Twitter Feeds...

 <SomeUser> !twitter SomeTwitterUsername
 <RedStone> SomeTwitterUsername: Tweet Message Here
 <RedStone> Tweeted: Tue Jun 11 21:00:01 +0000 2013 :: Retweets: 27 :: Link: https://twitter.com/SomeTwitterUsername/status/123456789098765432

 <SomeUser> !twitter follows SomeTwitterUsername AnotherTwitterUsername
 <RedStone> SomeTwitterUsername is currently following AnotherTwitterUsername


=head1 DESCRIPTION

This module outputs the latest tweets from a specified username in a specifc
channel automatically at a set interval. It is also possible to retrieve the latest tweet or
from a Twitter User via command.

=head1 CONFIGURATION

Simply add the following to your configuration file in a block called twitter { }:

    twitter {
        feed_auto <0 or 1>;
        feed_delay <Number of minutes to check feeds>;
        consumer_key <Your Consumer Key>;
        consumer_secret <Your Consumer Secret>;
        access_token <Your Access Token>;
        access_secret <Your Access Secret>;
    }

=head2 Example

    twitter {
        feed_auto 1;
        feed_delay 10;
        consumer_key "GGTS9HyYydSSsSidRNynbfoug",
        consumer_secret "e2Z8k1PMeMBr1iansADqCTIUHbRDCumLoL209283",
        access_token "24507039-Z8LoLSaU33EIkmxATwUD4sD8wcp2fQVWGlLkKD1sl",
        access_secret "11q2XuKZuZaZu82AK6FtuxUCBWR4xPr0nW8WjvHWyzfY",
    };

=head2 Notes

You will need to create an application on Twitter by visiting https://dev.twitter.com/apps/new
This will give you a consumer key, consumer secret. Don't forget to click "Create Access Token" after
creating the Application in order to get your access token and access token secret. When creating the
application, Read Only permissions should be enough to work for this module at the moment.

Due to twitter limitations, only 180 requests can be made per hour. This means if you were
to have several feeds polling at a 10 minute interval, it may not work after a while. 


=head1 AUTHOR

This module was written by Russell M Bradford.

This module is maintained by Russell M Bradford.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2013-2014 RedStone Development Group. All rights
reserved.

This module is released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et ts=4 sw=4:


