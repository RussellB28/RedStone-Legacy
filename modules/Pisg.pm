# Module: Pisg. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Pisg;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(rchook_add rchook_del conf_get err trans cmd_add cmd_del hook_add hook_del timer_add);
use API::IRC qw(notice privmsg cpart cjoin);
use API::Log qw(slog dbug alog);
use Time::HiRes qw(gettimeofday);
our $LASTRUN = "It has never been ran.";
our $HALTRUN = 0;
our $DISABLE_RUN = 0;
our $RUN_DELAY = 30;
our ($PDIR, $LDIR, $WDIR, $UBASE, $RSCRIPT);

# Initialization subroutine.
sub _init {
    # PostgreSQL is not supported, yet.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load Pisg: PostgreSQL is not supported.', 0); return }

    # Create `pisg` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS pisg (net TEXT, chan TEXT)') or return;

    # Create our logging hooks.
    rchook_add('PRIVMSG', 'plog.msg', \&M::Pisg::on_event) or return;
    rchook_add('KICK', 'plog.kick', \&M::Pisg::on_event) or return;
    rchook_add('TOPIC', 'plog.topic', \&M::Pisg::on_event) or return;
    rchook_add('JOIN', 'plog.join', \&M::Pisg::on_event) or return;
    rchook_add('PART', 'plog.part', \&M::Pisg::on_event) or return;
    hook_add('on_connect', 'plog.connect', \&M::Pisg::on_connect) or return;
    rchook_add('MODE', 'plog.mode', \&M::Pisg::on_event) or return;
    hook_add('on_rehash', 'plog.rehash', \&M::Pisg::on_rehash) or return;

 
   # Do some checks.
    if (!conf_get('pisg:dir')) {
        err(2, "Pisg: Please verify that you have defined the path to your Pisg installation [pisg:dir].", 0);
        return;
    }
    $PDIR = (conf_get('pisg:dir'))[0][0];
    if (!check_permissions($PDIR, 'Pisg installation')) { return; }

    if (!conf_get('pisg:www_dir')) {
        err(2, "Pisg: Please verify that you have defined the path to your webserver (for outputting stats files) [pisg:www_dir].", 0);
        return;
    }
    $WDIR = (conf_get('pisg:www_dir'))[0][0];
    if (!check_permissions($WDIR, 'webserver')) { return; }

    if (!conf_get('pisg:url_base')) {
        err(2, "Pisg: Please verify that you have defined the URL that reflects pisg:www_dir (for informing of stats location) [pisg:url_base].", 0);
        return;
    }

    $UBASE = (conf_get('pisg:url_base'))[0][0];

    if (!conf_get('pisg:run_script')) {
        dbug("Pisg: Please verify that you have defined the run script (ran when stats regeneration is requested) [pisg:run_script]. Disabling RUN until resolved...");
        alog("Pisg: Please verify that you have defined the run script (ran when stats regeneration is requested) [pisg:run_script]. Disabling RUN until resolved...");
        $DISABLE_RUN = 1;
    }
    $RSCRIPT = (conf_get('pisg:run_script'))[0][0] if !$DISABLE_RUN;
    if (!$DISABLE_RUN and (!-r $RSCRIPT or !-e $RSCRIPT)) { 
        dbug('Pisg: Run script not able to be read. Disabling RUN...');
        alog('Pisg: Run script not able to be read. Disabling RUN...');
        $DISABLE_RUN = 1;
    }

    if (conf_get('pisg:run_delay')) {
        $RUN_DELAY = (conf_get('pisg:run_delay'))[0][0];
    }

    if (!conf_get('pisg:log_dir')) {
        err(2, "Pisg: Please verify that you have defined the path to your desired log directory [pisg:log_dir].", 0);
        return;
    }
    $LDIR = (conf_get('pisg:log_dir'))[0][0];
    if (!check_permissions($LDIR, 'logging')) { return; }


    cmd_add('PISG', 0, 'pisg.admin', \%M::Pisg::HELP_PISG, \&M::Pisg::cmd_pisg) or return;
    cmd_add('STATS', 0, 0, \%M::Pisg::HELP_STATS, \&M::Pisg::cmd_stats) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the logging hooks.
    hook_del('on_connect', 'plog.connect') or return;
    hook_del('on_rehash', 'plog.rehash') or return;
    rchook_del('PRIVMSG', 'plog.msg') or return;
    rchook_del('KICK', 'plog.kick') or return;
    rchook_del('TOPIC', 'plog.topic') or return;
    rchook_del('JOIN', 'plog.join') or return;
    rchook_del('PART', 'plog.part') or return;
    rchook_del('MODE', 'plog.mode') or return;

    # Delete the commands.
    cmd_del('PISG') or return;
    cmd_del('STATS') or return;

    # Success.
    return 1;
}

sub on_rehash {
  
    $DISABLE_RUN = 0;

    if (!conf_get('pisg:run_script')) {
        dbug("Pisg: Please verify that you have defined the run script (ran when stats regeneration is requested) [pisg:run_script]. Disabling RUN until resolved...");
        alog("Pisg: Please verify that you have defined the run script (ran when stats regeneration is requested) [pisg:run_script]. Disabling RUN until resolved...");
        $DISABLE_RUN = 1;
    }

    $RSCRIPT = (conf_get('pisg:run_script'))[0][0] if !$DISABLE_RUN;
    if (!$DISABLE_RUN and (!-r $RSCRIPT or !-e $RSCRIPT)) {
        dbug('Pisg: Run script not able to be read. Disabling RUN...');
        alog('Pisg: Run script not able to be read. Disabling RUN...');
        $DISABLE_RUN = 1;
    }

    if ((conf_get('pisg:url_base'))[0][0] ne $UBASE) { $UBASE = (conf_get('pisg:url_base'))[0][0]; }

    if (conf_get('pisg:run_delay')) {
        $RUN_DELAY = (conf_get('pisg:run_delay'))[0][0];
    }


    return 1;
}

# Help for PISG.
our %HELP_PISG = (
    en => "This command controls the Pisg module. (You only need [<#channel>[\@network]] in PM or for another channel) \2Syntax:\2 PISG <ENABLE|DISABLE|INFO|RUN> [<#channel>[\@network]]",
);
our %HELP_STATS = (
    en => "This command manages pisg stats. \2Syntax:\2 STATS [RUN]",
);

# Permission checker.
sub check_permissions {
    my ($dir, $desc) = @_;

    if (!-d $dir) {
        slog("Pisg: Your $desc directory does not appear to exist.");
        err(2, "Pisg: Your $desc directory does not appear to exist.", 0);
        return 0;
    }
    elsif (!-r $dir) {
        slog("Pisg: Your $desc directory is not readable by the user Auto is running as.");
        err(2, "Pisg: Your $desc directory is not readable by the user Auto is running as.", 0);
        return 0;
    }
    elsif (!-w $dir) {
        slog("Pisg: Your $desc directory is not writeable by the user Auto is running as.");
        err(2, "Pisg: Your $desc directory is not writeable by the user Auto is running as.", 0);
        return 0;
    }
    else {
        return 1;
    }

}

# Subroutine to parse time for logging purposes.
sub timechk {
     my ($sec, $min, $hour, $mday, $mon, $year, undef, undef, undef) = localtime(time);
     # Dirty hacks.
     $min = "0$min" if length($min) != 2;
     $sec = "0$sec" if length($sec) != 2;
     $mon = $mon+1;
     $mon = "0$mon" if length($mon) != 2;
     $year = 1900+$year;
     if (length($mday) == 1) { $mday = "0$mday"; }
     # Return what we need.
     return ($sec, $min, $hour, $mday, $mon, $year);
}

sub on_event {
    my ($svr, @raw) = @_;
    my $line = join(' ', @raw);
    if (!check_log($svr, $raw[2])) {
        return;
    }
    log2file($svr, $raw[2], $line);
    return 1;
}

# Subroutine to log to file.
sub log2file {
    my ($svr, $chan, $msg) = @_;

    $chan = substr(lc($chan), 1);
    $svr = lc($svr);
    my $path = "$LDIR/$svr/$chan.log";
    if (!-d "$LDIR/$svr") {
        mkdir "$LDIR/$svr";
    }
    open(my $LOGF, q{>>}, "$path");
    my $ts = int((gettimeofday())*1000);
    print $LOGF $ts." ".$msg."\n";
    close $LOGF;

    return 1;
}

# Subroutine to check if logging for a channel is enabled.
sub check_log {
    my ($net, $chan) = @_;
    my $q = $Auto::DB->prepare('SELECT net FROM pisg WHERE net = ? AND chan = ?') or return 0;
    $q->execute(lc $net, lc $chan) or return 0;
    if ($q->fetchrow_array) {
        return 1;
    }
    return 0;
}

# Callback for the PISG command.
sub cmd_pisg {
    my ($src, @argv) = @_;

    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    given(uc $argv[0]) {
        when ('ENABLE') {
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
            notice($src->{svr}, $src->{nick}, "Statistics is already enabled for $chan\@$svr.") and return if check_log($svr, $chan);
            my $dbq = $Auto::DB->prepare('INSERT INTO pisg (net, chan) VALUES (?, ?)');
            if ($dbq->execute($svr, lc $chan)) {
                $svr = fix_net($svr);
                privmsg($src->{svr}, $src->{chan}, "Statistics enabled for $chan\@$svr.");
                slog("[\2pisg\2] $src->{nick} enabled statistics for $chan\@$svr.");
                make_conf();
                cjoin($svr, $chan);
                if (conf_get('pisg:notify_msg') && (conf_get('pisg:notify_msg'))[0][0]) {
                    privmsg($svr, $chan, "Hi. I joined because a bot administrator assigned me here. If you have any questions or concerns regarding me please contact a bot administrator.");
                }
            }
            else {
                privmsg($src->{svr}, $src->{chan}, 'Failed to enable statistics.');
            }

        }
        when ('DISABLE') {
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
            notice($src->{svr}, $src->{nick}, "Statistics is already disabled for $chan\@$svr.") and return if !check_log($svr, $chan);
            my $dbq = $Auto::DB->prepare('DELETE FROM pisg WHERE net = ? AND chan = ?');
            if ($dbq->execute($svr, lc $chan)) {
                $svr = fix_net($svr);
                privmsg($src->{svr}, $src->{chan}, "Statistics disabled for $chan\@$svr.");
                slog("[\2Statistics\2] $src->{nick} disabled statistics for $chan\@$svr.");
                make_conf();
                if (conf_get('pisg:notify_msg') && (conf_get('pisg:notify_msg'))[0][0]) {
                    privmsg($svr, $chan, "I have been unassigned. If you have any questions or concerns, or if you'd like me back, please contact a bot administrator.");
                }
                cpart($svr, $chan, 'Unassigned.');
            }
            else {
                privmsg($src->{svr}, $src->{chan}, 'Failed to disable statistics.');
            }
        }
        when ('RUN') {
            privmsg($src->{svr}, $src->{chan}, 'RUN is disabled.') and return if $DISABLE_RUN;
            privmsg($src->{svr}, $src->{chan}, "Running stats. Please allow up to 2 minutes for the update.");
            `$RSCRIPT`;
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
            if (check_log($svr, $chan)) {
                privmsg($src->{svr}, $src->{chan}, "Statistics for \2".$chan."\@".$svr."\2 is \2ENABLED\2. Stats are accessible online at ".$UBASE."/".$svr."/".$mchan.".html");
            }
            else {
                privmsg($src->{svr}, $src->{chan}, "Statistics for \2$chan\@$svr\2 is \2DISABLED\2.");
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
    my $dbh = $Auto::DB->prepare('SELECT chan FROM pisg WHERE net = ?');
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

sub make_conf {
    my $dbh = $Auto::DB->prepare('SELECT * FROM pisg');
    $dbh->execute;
    my $data = $dbh->fetchall_arrayref;
    my @lines;
    foreach my $r (@$data) {
        my $net = $r->[0];
        my $channel = $r->[1];
        my $nnet = fix_net($net);
        push(@lines, "<channel=\"".$channel."\">");
        push(@lines, "  Network=\"".$nnet."\"");
        $channel = substr($channel, 1);
        if (!-e $LDIR."/".$net."/".$channel.".log") {
            open(my $CHAN, q{>}, $LDIR."/".$net."/".$channel.".log");
            close $CHAN;
        }
        push(@lines, "  Logfile=\"".$LDIR."/".$net."/".$channel.".log\"");
        if (!-d "$WDIR/$net") {
            mkdir "$WDIR/$net";
        }
        push(@lines, "  OutputFile=\"".$WDIR."/".$net."/".$channel.".html\"");
        push(@lines, "</channel>");
    }
    open(my $CCONF, q{>}, $PDIR."/channels.conf");
    close $CCONF;
    open(my $CONF, q{>>}, $PDIR."/channels.conf");
    foreach (@lines) {
         print $CONF $_."\n";
    }
    close $CONF;    
}

# Callback for the STATS command.
sub cmd_stats {
    my ($src, @argv) = @_;
    
    my $svr = lc($src->{svr});

    if (!defined $argv[0]) {
        my $chan = substr(lc($src->{chan}), 1);
        if (check_log($svr, lc($src->{chan}))) {
            privmsg($src->{svr}, $src->{chan}, "Channel stats can be found at ".$UBASE."/".$svr."/".$chan.".html");
        }
        else {
            privmsg($src->{svr}, $src->{chan}, "I am not configured for stats in \2$src->{chan}\2.");
        }
        return;
    }

    given(uc $argv[0]) {
        when ('RUN') {
             privmsg($src->{svr}, $src->{chan}, 'RUN is disabled.') and return if $DISABLE_RUN;
             if ($HALTRUN) { privmsg($src->{svr}, $src->{chan}, "RUN can only be ran every $RUN_DELAY minutes. $LASTRUN"); }
             else {
                 privmsg($src->{svr}, $src->{chan}, "Running stats. Please allow up to 2 minutes for the update.");
                 $HALTRUN = 1;
                 my (undef, $min, $hour, $mday, $mon, $year) = timechk;
                 $LASTRUN = "It was last ran at ".$hour.":".$min." on ".$mon."/".$mday."/".$year.".";
                 `$RSCRIPT`;
                 global("Stats started by $src->{nick} in $src->{chan}\@$src->{svr}");
                 my $delay = $RUN_DELAY*60;
                 timer_add("statsrun", 1, $delay, \&M::Pisg::unset_halt);
             }
        }
        default {
            my $chan = substr(lc($src->{chan}), 1);
            privmsg($src->{svr}, $src->{chan}, "Channel stats can be found at ".$UBASE."/".$svr."/".$chan.".html");
        }
   }
        return 1;
}

sub unset_halt { $HALTRUN = 0; }

sub global {
    my ($msg) = @_;
    my $dbh = $Auto::DB->prepare('SELECT * FROM pisg');
    $dbh->execute;
    my $data = $dbh->fetchall_arrayref;
    foreach my $r (@$data) {
        my $net = $r->[0];
        my $chan = $r->[1];
        return if !fix_net($net);
        privmsg(fix_net($net), $chan, $msg);
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
API::Std::mod_init('Pisg', 'Xelhua', '1.01', '3.0.0a11');
# build: perl=5.010000 cpan=Time::HiRes

__END__

=head1 NAME

Pisg

=head1 VERSION

 1.01

=head1 SYNOPSIS

 <starcoder> !pisg enable #xelhua@Thinstack
 <blue> Statistics enabled for #xelhua@Thinstack.

 <starcoder> !pisg disable #xelhua
 <blue> Statistics disabled for #xelhua@Thinstack.

 <starcoder> !pisg info #xelhua@AlphaChat
 <blue> Statistics for #xelhua@AlphaChat is DISABLED.

 <starcoder> !pisg run
 <blue> Running stats. Please allow up to 2 minutes for the update.

=head1 DESCRIPTION

This module writes logs in a Pisg-compatible format (pircbot) and automates 
the process of stats generation.

=head1 CONFIGURATION

Simply add the following to your configuration file in a block called pisg { }:

 pisg {
     dir "<path to the pisg directory>";
     log_dir "<path to the desired logging directory>";
     www_dir "<path to the output (www) directory>";
     url_base "<URL that reflects www_dir>";
 };

Optinally, append the following:

 pisg {
     ...
     run_script "<path to a script to run upon request of stats regeneration>";
     notify_msg <0 or 1>;
     run_delay <number of minutes between allowing RUN to be ran again>;
 }

=head2 Optional

 * run_script: It is advised that you use the provided script, scripts/run-stats.pl. Be sure to edit it before running it.

 * notify_msg: This enables or disables messaging the channel upon being assigned or unassigned from that channel. Defaults to 0.

 * run_delay: This determines how many minutes Auto waits before allowing RUN to be ran again. Defaults to 30 Minutes.

=head2 Example

 pisg {
     dir "/home/xelhua/pisg-0.72";
     log_dir "/home/xelhua/Auto/logs";
     www_dir "/var/www/chanstats";
     url_base "http://xelhua.org/chanstats";
     run_script "/home/xelhua/Auto/scripts/run-stats.pl";
     notify_msg 0;
     run_delay 15;
 }

=head2 pisg

 As far as pisg goes, all you need to is include channels.conf in pisg:dir and set the format to pircbot.
 For example:
    <set Format="pircbot">
    <include="/home/xelhua/pisg-0.72/channels.conf">

=head2 Notes

It is very important that the user Auto is running as has access to all of these.
Also, it is important that you don't append a trailing slash to any paths.


=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group. All rights
reserved.

This module is released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et ts=4 sw=4:

