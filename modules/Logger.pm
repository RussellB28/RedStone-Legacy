# Module: Logger. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Logger;
use strict;
use warnings;
use feature qw(switch);
use API::Std qw(hook_add hook_del cmd_add cmd_del conf_get err trans);
use API::IRC qw(notice privmsg);
use API::Log qw(slog);
our $LPATH;
our $CURPATH;

# Initialization subroutine.
sub _init {
    # PostgreSQL is not supported, yet.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load Logger: PostgreSQL is not supported.', 0); return }

    # Create `logger` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS logger (net TEXT, chan TEXT)') or return;

    # Create our logging hooks.
    hook_add('on_cprivmsg', 'logger.msg', \&M::Logger::on_cprivmsg) or return;
    hook_add('on_kick', 'logger.kick', \&M::Logger::on_kick) or return;
    hook_add('on_nick', 'logger.nick', \&M::Logger::on_nick) or return;
    hook_add('on_rcjoin', 'logger.join', \&M::Logger::on_join) or return;
    hook_add('on_part', 'logger.part', \&M::Logger::on_part) or return;
    hook_add('on_notice', 'logger.notice', \&M::Logger::on_notice) or return;
    hook_add('on_topic', 'logger.topic', \&M::Logger::on_topic) or return;
    hook_add('on_cmode', 'logger.cmode', \&M::Logger::on_cmode) or return;
    hook_add('on_iquit', 'logger.quit', \&M::Logger::on_quit) or return;

    # Create our command.
    cmd_add('LOGGER', 2, 'logger.admin', \%M::Logger::HELP_LOGGER, \&M::Logger::cmd_logger) or return;

    # Do some checks.
    if (!conf_get('logger:path')) {
        err(2, 'Logger: Please verify that you have path defined in the logger configuration block.', 0);
        return;
    }
    ($LPATH) = (conf_get('logger:path'))[0][0];
    if (!-r $LPATH) {
        err(2, 'Logger: Your logging path is not readable by the user Auto is running as.', 0);
        return;
    }
    elsif (!-w $LPATH) {
        err(2, 'Logger: Your logging path is not writeable by the user Auto is running as.', 0);
        return;
    }
    elsif (!-d $LPATH) {
        err(2, 'Logger: Your logging path does not appear to be a directory.', 0);
        return;
    }

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the logging hooks.
    hook_del('on_cprivmsg', 'logger.msg') or return;
    hook_del('on_kick', 'logger.kick') or return;
    hook_del('on_nick', 'logger.nick') or return;
    hook_del('on_rcjoin', 'logger.join') or return;
    hook_del('on_part', 'logger.part') or return;
    hook_del('on_notice', 'logger.notice') or return;
    hook_del('on_topic', 'logger.topic') or return;
    hook_del('on_cmode', 'logger.cmode') or return;
    hook_del('on_iquit', 'logger.quit') or return;

    # Delete the command.
    cmd_del('LOGGER') or return;

    # Success.
    return 1;
}

# Help for LOGGER.
our %HELP_LOGGER = (
    en => "This command controls the Logger module. (You only need [<#channel>] in PM or for another channel) \2Syntax:\2 LOGGER <ENABLE|DISABLE|INFO> [<#channel>]",
);

# Subroutine to parse time for logging purposes.
sub timechk {
     my ($sec, $min, $hour, $mday, $mon, $year, undef, undef, undef) = localtime(time);
     # Dirty hacks.
     $min = "0$min" if length($min) != 2;
     $sec = "0$sec" if length($sec) != 2;
     $mon = $mon+1;
     $mon = "0$mon" if length($mon) != 2;
     $year = 1900+$year;
     # Return what we need.
     return ($sec, $min, $hour, $mday, $mon, $year);
}

# Subroutine to check if the path exists, if it doesn't creates it.
sub pathchk {
    my $svr = lc($_[0]);
    my $path = $LPATH . "/" . $svr;
    if (!-e $path) {
        mkdir $path;
    }
    my (undef, undef, undef, $d, $m, $y) = timechk;
    $path = $path . "/" . $m . $d . $y;
    if (!-e $path) {
        mkdir $path;
    }
    
    $CURPATH = $path . "/";

    return 1;
}

# Subrotuine to return a users highest status.
sub statuschk {
    my ($svr, $chan, $user) = @_;
    
    my $smodes;

    $smodes = $State::IRC::chanusers{$svr}{$chan}{lc($user)};

    my %prefixes = %{$Proto::IRC::csprefix{$svr}};
    my $status;
    my $prefix = '';
    if ($smodes =~ m/q/) { $status = "yellow"; $prefix = $prefixes{q}; }
    elsif ($smodes =~ m/a/) { $status = "grey"; $prefix = $prefixes{a}; }
    elsif ($smodes =~ m/o/) { $status = "red"; $prefix = $prefixes{o}; }
    elsif ($smodes =~ m/h/) { $status = "orange"; $prefix = $prefixes{h}; }
    elsif ($smodes =~ m/v/) { $status = "cyan"; $prefix = $prefixes{v}; }
    else { $status = "lawngreen"; }

    return ($prefix, $status);
}

# Callback for our on_cprivmsg hook.
sub on_cprivmsg {
    my ($src, $chan, @msg) = @_;

    pathchk($src->{svr});

    my $msg = join ' ', @msg;

    # Filter out CTCPs
    if (($msg =~ /^\001(.*)\001/) || ($msg =~ /^\001(.*) /)) {
        my $request = $1;
        $request =~ s/ (.*)//;
        my $txt = $1;
        if ($request eq 'ACTION') {
            $txt =~ s/ACTION//;
            on_action($src, $chan, $txt);
        }
        else {
            undef $txt;
            on_ctcp($src, $chan);
        }
        return 1;
    }
                   
    my ($second, $minute, $hour, $dom, $month, $year) = timechk;
    my ($prefix, $color) = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] <<span style='color:$color;'>$prefix$src->{nick}</span>> $msg <br />");

    return 1;
}

# Callback for our on_action routine.
sub on_action {
    my ($src, $chan, $msg) = @_;

    pathchk($src->{svr});

    my ($second, $minute, $hour, $dom, $month, $year) = timechk;
    my ($prefix, $color) = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] <span style='color:purple;'> * $prefix$src->{nick} $msg </span> <br />");

    return 1;
}

# Callback for our on_ctcp hook.
sub on_ctcp {
    my ($src, $chan) = @_;

    return 1;
}

# Callback for our on_cmode hook.
sub on_cmode {
    my ($src, $chan, $mstring) = @_;

    pathchk($src->{svr});

    my ($second, $minute, $hour, $dom, $month, $year) = timechk;

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] * <span style='color:lawngreen'> $src->{nick} set mode(s) $mstring </span> <br />");

    return 1;
}

# Callback for our on_kick hook.
sub on_kick {
    my ($src, $chan, $user, $reason) = @_;

    pathchk($src->{svr});

    my $r = ($reason ? $reason : 'No reason.');
    my ($second, $minute, $hour, $dom, $month, $year) = timechk;
    my ($prefix, $color) = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] * <span style='color:red;'> <span style='color:$color;'>$prefix$src->{nick}</span> kicked $user from $chan ($r). </span> </br>");

    return 1;
}

# Callback for our on_nick hook.
sub on_nick {
    my ($src, $nnick) = @_;

    pathchk($src->{svr});

    my ($second, $minute, $hour, $dom, $month, $year) = timechk;

    foreach my $ccu (keys %{ $State::IRC::chanusers{$src->{svr}}}) {
        if (defined $State::IRC::chanusers{$src->{svr}}{$ccu}{lc $nnick}) {
            log2file($ccu, $src->{svr}, "[$hour:$minute:$second] * <span style='color:lawngreen;'> $src->{nick} changed their nickname to $nnick. </span> </br>");
        }
    }

    return 1;
}

# Callback for our on_quit hook.
sub on_quit {
    my ($src, $chans, $reason) = @_;

    pathchk($src->{svr});

    my $r = ($reason ? $reason : 'No reason.');
    my ($second, $minute, $hour, $dom, $month, $year) = timechk;

    # TODO: Add prefix to QUIT.
    foreach my $ccu (keys %{ $chans }) {
       log2file($ccu, $src->{svr}, "[$hour:$minute:$second] * <span style='color:red;'> $src->{nick} left the network ($r).</span> </br>");
    }

    return 1;

}

# Callback for our on_rcjoin hook.
sub on_join {
    my ($src, $chan) = @_;

    pathchk($src->{svr});

    my ($second, $minute, $hour, $dom, $month, $year) = timechk;
    my ($prefix, undef) = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] * <span style='color:lawngreen;'> $prefix$src->{nick} joined the channel. </span> </br>");

    return 1;
}

# Callback for our on_part hook.
sub on_part {
    my ($src, $chan, $msg) = @_;

    pathchk($src->{svr});

    my $r = ($msg ? $msg : 'No reason.');
    my ($second, $minute, $hour, $dom, $month, $year) = timechk;
    my ($prefix, undef) = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] * <span style='color:red;'> $prefix$src->{nick} parted the channel ($r). </span> </br>");

    return 1;
}

# Callback for our on_notice hook.
sub on_notice {
    my ($src, $target, @msg) = @_;

    # Check if our target is a channel. If it's not, bail.
    return if $target !~ m/#/xsm;

    pathchk($src->{svr});

    my $msg = join ' ', @msg;
    my ($second, $minute, $hour, $dom, $month, $year) = timechk;

    log2file($target, $src->{svr}, "[$hour:$minute:$second] <span style='color:grey;'> -$src->{nick}\- $msg </span> </br>"); 

    return 1;
}

# Callback for our on_topic hook.
sub on_topic {
    my ($src, @ntopic) = @_;
    
    my $topic = join ' ', @ntopic;
    my $chan = $src->{chan};

    pathchk($src->{svr});

    my ($second, $minute, $hour, $dom, $month, $year) = timechk;
    my ($prefix, undef) = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] * <span style='color:lawngreen;'> $prefix$src->{nick} changed the channel topic to: </span> $topic </br>");

    return 1;
}

# Subroutine to convert irc color codes into html.
sub cc2html {
    my ($line) = @_;
 
    return $line;
}

# Subroutine to log to file.
sub log2file {
    my ($chan, $svr, $msg) = @_;

    # Don't log if it's not wanted.
    return if !check_log($svr, $chan);

    my $path = $CURPATH . "/" . $chan . ".html";
    if (!-e $path) {
        open(my $LOGF, q{>}, "$path");
        print $LOGF "<html>\n<title>$chan\@$svr Log by Auto</title>\n<body style='background-color:black; color:white;'>\n<h1 style='text-align:center;'>$chan\@$svr Logs by Auto</h1>\n<hr />";
        close $LOGF;
    }
    open(my $LOGF, q{>>}, "$path");
    print $LOGF "\n$msg";
    close $LOGF;

    return 1;
}

# Subroutine to check if logging for a channel is enabled.
sub check_log {
    my ($net, $chan) = @_;
    my $q = $Auto::DB->prepare('SELECT net FROM logger WHERE net = ? AND chan = ?') or return 0;
    $q->execute(lc $net, lc $chan) or return 0;
    if ($q->fetchrow_array) {
        return 1;
    }
    return 0;
}

# Callback for the LOGGER command.
sub cmd_logger {
    my ($src, @argv) = @_;

    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    my $resp = 'Something went wrong.';

    given(uc $argv[0]) {
        when ('ENABLE') {
            my $chan;
            if (!defined $argv[1] and !defined $src->{chan}) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            $chan = $src->{chan};
            $chan = $argv[1] if defined $argv[1];
            notice($src->{svr}, $src->{nick}, "Logging is already enabled for $chan\@$src->{svr}.") and return if check_log($src->{svr}, $chan);
            my $dbq = $Auto::DB->prepare('INSERT INTO logger (net, chan) VALUES (?, ?)');
            if ($dbq->execute(lc $src->{svr}, lc $chan)) {
                $resp = "Logging enabled for $chan\@$src->{svr}.";
                slog("[\2Logger\2] $src->{nick} enabled logging for $chan\@$src->{svr}.");
            }
            else {
                $resp = 'Failed to enable logging.';
            }

        }
        when ('DISABLE') {
            my $chan;
            if (!defined $argv[1] and !defined $src->{chan}) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            $chan = $src->{chan};
            $chan = $argv[1] if defined $argv[1];
            notice($src->{svr}, $src->{nick}, "Logging is already disabled for $chan\@$src->{svr}.") and return if !check_log($src->{svr}, $chan);
            my $dbq = $Auto::DB->prepare('DELETE FROM logger WHERE net = ? AND chan = ?');
            if ($dbq->execute(lc $src->{svr}, lc $chan)) {
                $resp = "Logging disabled for $chan\@$src->{svr}.";
                slog("[\2Logger\2] $src->{nick} disabled logging for $chan\@$src->{svr}.");
            }
            else {
                $resp = 'Failed to disable logging.';
            }
        }
        when ('INFO') {
            my $chan;
            if (!defined $argv[1] and !defined $src->{chan}) {
                notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
                return;
            }
            $chan = $src->{chan};
            $chan = $argv[1] if defined $argv[1];
            my (undef, undef, undef, $d, $m, $y) = timechk;
            my $path = $LPATH . "/" . lc($src->{svr}) . "/" . $m . $d . $y . "/" . $chan . ".html";
            if (check_log($src->{svr}, $chan)) {
                $resp = "Logging for \2$chan\@$src->{svr}\2 is \2ENABLED\2. Logs will be stored in $path.";
            }
            else {
                $resp = "Logging for \2$chan\@$src->{svr}\2 is \2DISABLED\2.";
            }
        }
        default {
            # We don't know this command.
            notice($src->{svr}, $src->{nick}, trans('Unknown action', $_).q{.});
            return;
        }
    }

    if (!defined $src->{chan}) {
        notice($src->{svr}, $src->{nick}, $resp);
    }
    else {
        privmsg($src->{svr}, $src->{chan}, $resp);
    }

   return 1;
}


# Start initialization.
API::Std::mod_init('Logger', 'Xelhua', '1.02', '3.0.0a11');
# build: perl=5.010000

