# Module: Replay. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Replay;
use strict;
use warnings;
use API::Std qw(hook_add hook_del cmd_add cmd_del conf_get err trans);
use API::IRC qw(notice);
our $LPATH;
our $CURPATH;
our $lines;

# Initialization subroutine.
sub _init {
    # PostgreSQL is not supported, yet.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load Replay: PostgreSQL is not supported.', 0); return }

    # Create our logging hooks.
    hook_add('on_cprivmsg', 'replay.msg', \&M::Replay::on_cprivmsg) or return;
    hook_add('on_nick', 'replay.nick', \&M::Replay::on_nick) or return;
    hook_add('on_rcjoin', 'replay.join', \&M::Replay::on_join) or return;
    hook_add('on_part', 'replay.part', \&M::Replay::on_part) or return;
    hook_add('on_topic', 'replay.topic', \&M::Replay::on_topic) or return;
    hook_add('on_iquit', 'replay.quit', \&M::Replay::on_quit) or return;

    # Create our command.
    cmd_add('REPLAY', 2, 0, \%M::Replay::HELP_REPLAY, \&M::Replay::cmd_replay) or return;
 
    $lines = (conf_get('replay:lines') ? (conf_get('replay:lines'))[0][0] : 25);
    
    # Do some checks.
    if (!conf_get('replay:dir')) {
        err(2, 'Replay: Please verify that you have path defined in the Replay configuration block.', 0);
        return;
    }
    ($LPATH) = (conf_get('replay:dir'))[0][0];
    if (!-r $LPATH) {
        slog('Replay: Your logging path is not readable by the user Auto is running as.');
        err(2, 'Replay: Your logging path is not readable by the user Auto is running as.', 0);
        return;
    }
    elsif (!-w $LPATH) {
        slog('Replay: Your logging path is not writeable by the user Auto is running as.');
        err(2, 'Replay: Your logging path is not writeable by the user Auto is running as.', 0);
        return;
    }
    elsif (!-d $LPATH) {
        slog('Replay: Your logging path does not appear to be a directory');
        err(2, 'Replay: Your logging path does not appear to be a directory.', 0);
        return;
    }

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the logging hooks.
    hook_del('on_cprivmsg', 'replay.msg') or return;
    hook_del('on_nick', 'replay.nick') or return;
    hook_del('on_rcjoin', 'replay.join') or return;
    hook_del('on_part', 'replay.part') or return;
    hook_del('on_topic', 'replay.topic') or return;
    hook_del('on_iquit', 'replay.quit') or return;

    # Delete the command.
    cmd_del('REPLAY') or return;

    # Success.
    return 1;
}

# Help for REPLAY.
our %HELP_REPLAY = (
    en => "This command replays channel history. \2Syntax:\2 REPLAY",
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
     if (length($mday) == 1) { $mday = "0$mday"; }
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

    if (!-e $path) {
        mkdir $path;
    }
    
    $CURPATH = $path . "/";

    return 1;
}

# Subroutine to validate a user.
sub is_user {
    my ($svr, $chan, $user) = @_;
    
    return 0 if !defined $State::IRC::chanusers{$svr}{$chan}{lc($user)};
    
    return 1;
}


# Subrotuine to return a users highest status.
sub statuschk {
    my ($svr, $chan, $user) = @_;

    return('') if !is_user($svr, $chan, $user);
    
    my $smodes;

    $smodes = $State::IRC::chanusers{$svr}{$chan}{lc($user)};

    my %prefixes = %{$Proto::IRC::csprefix{$svr}};
    my $prefix = '';
    if ($smodes =~ m/q/) { $prefix = $prefixes{q}; }
    elsif ($smodes =~ m/a/) { $prefix = $prefixes{a}; }
    elsif ($smodes =~ m/o/) { $prefix = $prefixes{o}; }
    elsif ($smodes =~ m/h/) { $prefix = $prefixes{h}; }
    elsif ($smodes =~ m/v/) { $prefix = $prefixes{v}; }
    return $prefix;
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
        return 1;
    }
                   
    my ($second, $minute, $hour, undef, undef, undef) = timechk;
    my $prefix = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] <$prefix$src->{nick}> $msg ");

    return 1;
}

# Callback for our on_action routine.
sub on_action {
    my ($src, $chan, $msg) = @_;

    pathchk($src->{svr});

    my ($second, $minute, $hour, undef, undef, undef) = timechk;
    my $prefix  = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] * $prefix$src->{nick} $msg");

    return 1;
}

# Callback for our on_nick hook.
sub on_nick {
    my ($src, $nnick) = @_;

    pathchk($src->{svr});

    my ($second, $minute, $hour, undef, undef, undef) = timechk;

    foreach my $ccu (keys %{ $State::IRC::chanusers{$src->{svr}}}) {
        if (defined $State::IRC::chanusers{$src->{svr}}{$ccu}{lc $nnick}) {
            log2file($ccu, $src->{svr}, "[$hour:$minute:$second] * $src->{nick} changed their nickname to $nnick.");
        }
    }

    return 1;
}

# Callback for our on_quit hook.
sub on_quit {
    my ($src, $chans, $reason) = @_;

    pathchk($src->{svr});

    my $r = ($reason ? $reason : 'No reason.');
    my ($second, $minute, $hour, undef, undef, undef) = timechk;

    # TODO: Add prefix to QUIT.
    foreach my $ccu (keys %{ $chans }) {
       log2file($ccu, $src->{svr}, "[$hour:$minute:$second] * $src->{nick} left the network ($r).");
    }

    return 1;

}

# Callback for our on_rcjoin hook.
sub on_join {
    my ($src, $chan) = @_;

    pathchk($src->{svr});

    my ($second, $minute, $hour, undef, undef, undef) = timechk;
    my $prefix = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] * $prefix$src->{nick} joined the channel.");

    return 1;
}

# Callback for our on_part hook.
sub on_part {
    my ($src, $chan, $msg) = @_;

    pathchk($src->{svr});

    my $r = ($msg ? $msg : 'No reason.');
    my ($second, $minute, $hour, undef, undef, undef) = timechk;
    my $prefix = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] * $prefix$src->{nick} parted the channel ($r).");

    return 1;
}

# Callback for our on_topic hook.
sub on_topic {
    my ($src, @ntopic) = @_;
    
    my $topic = join ' ', @ntopic;
    my $chan = $src->{chan};

    pathchk($src->{svr});

    my ($second, $minute, $hour, undef, undef, undef) = timechk;
    my $prefix = statuschk($src->{svr}, $chan, $src->{nick});

    log2file($chan, $src->{svr}, "[$hour:$minute:$second] * $prefix$src->{nick} changed the channel topic to: $topic ");

    return 1;
}

# Subroutine to log to file.
sub log2file {
    my ($chan, $svr, $msg) = @_;

    my $path = $CURPATH . "/" . $chan . ".log";
    open(my $LOGF, q{>>}, "$path");
    print $LOGF "$msg\n";
    close $LOGF;

    return 1;
}

sub cmd_replay {
    my ($src, undef) = @_;

    my $path = $CURPATH . "/" . $src->{chan} .".log";
    my $lines = `tail -n $lines $path`;

    my @line = split("\n", $lines);

    foreach my $l (@line) {
        notice($src->{svr}, $src->{nick}, $l);
    }

}

# Start initialization.
API::Std::mod_init('Replay', 'Ethrik', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

Replay - Replay channel history.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <starcoder> !replay
 -blue- lines here

=head1 INSTALL

Add the following to your configuration:
 replay {
    dir "/path/to/log/to";
    lines <number of lines to play>;
 }

=head1 DESCRIPTION

This module replays channel history similar to +H on inspircd.

=head1 AUTHOR

This module was written by Matthew Barksdale and Ren Shore.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group. All rights
reserved.

This module is released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et ts=4 sw=4:

