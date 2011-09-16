# Module: Logger. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Logger;
use strict;
use warnings;
use API::Std qw(hook_add hook_del conf_get err);
our $LPATH;
our $CURPATH;

# Initialization subroutine.
sub _init {
    # Create our logging hooks.
    hook_add('on_cprivmsg', 'logger.msg', \&M::Logger::on_cprivmsg) or return;
    hook_add('on_kick', 'logger.kick', \&M::Logger::on_kick) or return;
    hook_add('on_nick', 'logger.nick', \&M::Logger::on_nick) or return;
    hook_add('on_rcjoin', 'logger.join', \&M::Logger::on_join) or return;
    hook_add('on_part', 'logger.part', \&M::Logger::on_part) or return;
    hook_add('on_notice', 'logger.notice', \&M::Logger::on_notice) or return;
    hook_add('on_topic', 'logger.topic', \&M::Logger::on_topic) or return;
    hook_add('on_cmode', 'logger.cmode', \&M::Logger::on_cmode) or return;
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


    # Success.
    return 1;
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

    my $smodes = $State::IRC::chanusers{$svr}{$chan}{lc($user)};
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
    my ($prefix, undef) = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] * <span style='color:lawngreen'> $prefix$src->{nick} set mode(s) $mstring </span> <br />");

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
    my ($svr, $src, $nnick) = @_;
    pathchk($svr);

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

# Start initialization.
API::Std::mod_init('Logger', 'Xelhua', '1.01', '3.0.0a11');
# build: perl=5.010000

