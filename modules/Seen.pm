# Module: Seen. See below for documentation.
# Copyright (C) 2010-2012 Ethrik Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Seen;
use strict;
use warnings;
use API::Std qw(hook_add hook_del cmd_add cmd_del err trans);
use API::IRC qw(notice privmsg);

# Initialization subroutine.
sub _init {
    # PostgreSQL is not supported, yet.
    if ($Auto::ENFEAT =~ /pgsql/) { err(3, 'Unable to load Seen: PostgreSQL is not supported.', 0); return }

    # Create `seen` table.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS seen (net TEXT, user TEXT, last TEXT, time TEXT)') or return;

    # Create our logging hooks.
    hook_add('on_cprivmsg', 'seen.msg', \&M::Seen::on_cprivmsg) or return;
    hook_add('on_kick', 'seen.kick', \&M::Seen::on_kick) or return;
    hook_add('on_nick', 'seen.nick', \&M::Seen::on_nick) or return;
    hook_add('on_rcjoin', 'seen.join', \&M::Seen::on_join) or return;
    hook_add('on_part', 'seen.part', \&M::Seen::on_part) or return;
    hook_add('on_notice', 'seen.notice', \&M::Seen::on_notice) or return;
    hook_add('on_topic', 'seen.topic', \&M::Seen::on_topic) or return;
    hook_add('on_cmode', 'seen.cmode', \&M::Seen::on_cmode) or return;
    hook_add('on_iquit', 'seen.quit', \&M::Seen::on_quit) or return;

    # Create our command.
    cmd_add('SEEN', 2, 0, \%M::Seen::HELP_SEEN, \&M::Seen::cmd_seen) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the seen hooks.
    hook_del('on_cprivmsg', 'seen.msg') or return;
    hook_del('on_kick', 'seen.kick') or return;
    hook_del('on_nick', 'seen.nick') or return;
    hook_del('on_rcjoin', 'seen.join') or return;
    hook_del('on_part', 'seen.part') or return;
    hook_del('on_notice', 'seen.notice') or return;
    hook_del('on_topic', 'seen.topic') or return;
    hook_del('on_cmode', 'seen.cmode') or return;
    hook_del('on_iquit', 'seen.quit') or return;

    # Delete the command.
    cmd_del('SEEN') or return;

    # Success.
    return 1;
}

# Help for SEEN.
our %HELP_SEEN = (
    en => "This command checks the last time a user was seen. \2Syntax:\2 SEEN <nickname>",
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

# Subroutine to return a users highest status.
sub statuschk {
    my ($svr, $chan, $user) = @_;

    return '' if !defined $State::IRC::chanusers{$svr}{$chan}{lc($user)};

    my $smodes = $State::IRC::chanusers{$svr}{$chan}{lc($user)};
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
                   
    my $prefix = statuschk($src->{svr}, $chan, $src->{nick});

    update_seen($src->{svr}, $src->{nick}, "Their last words in $chan were: <$prefix$src->{nick}> $msg", timechk());

    return 1;
}

# Callback for our on_action routine.
sub on_action {
    my ($src, $chan, $msg) = @_;

    my $prefix = statuschk($src->{svr}, $chan, $src->{nick});

    update_seen($src->{svr}, $src->{nick}, "Their last words in $chan were: * $prefix$src->{nick} $msg", timechk());

    return 1;
}

# Callback for our on_cmode hook.
sub on_cmode {
    my ($src, $chan, $mstring) = @_;

    update_seen($src->{svr}, $src->{nick}, "They were last setting mode(s) $mstring in $chan", timechk());

    return 1;
}

# Callback for our on_kick hook.
sub on_kick {
    my ($src, $chan, $user, $reason) = @_;

    update_seen($src->{svr}, $user, "They were last seen being kicked from $chan", timechk());
    update_seen($src->{svr}, $src->{nick}, "They were last seen kicking $user from $chan", timechk());

    return 1;
}

# Callback for our on_nick hook.
sub on_nick {
    my ($src, $nnick) = @_;

    update_seen($src->{svr}, $src->{nick}, "They were last seen changing their nickname to $nnick", timechk());

    return 1;
}

# Callback for our on_quit hook.
sub on_quit {
    my ($src, $chans, $reason) = @_;

    my $r = ($reason ? $reason : 'No reason.');

    update_seen($src->{svr}, $src->{nick}, "They were last seen quitting with the message $r", timechk());

    return 1;
}

# Callback for our on_rcjoin hook.
sub on_join {
    my ($src, $chan) = @_;

    update_seen($src->{svr}, $src->{nick}, "They were last seen joining $chan", timechk());

    return 1;
}

# Callback for our on_part hook.
sub on_part {
    my ($src, $chan, $msg) = @_;

    my $r = ($msg ? $msg : 'No reason.');

    update_seen($src->{svr}, $src->{nick}, "They were last seen parting $chan with the message $msg", timechk());

    return 1;
}

# Callback for our on_notice hook.
sub on_notice {
    my ($src, $target, @msg) = @_;

    # Check if our target is a channel. If it's not, bail.
    return 0 if $target !~ m/#/xsm;

    my $msg = join ' ', @msg;

    update_seen($src->{svr}, $src->{nick}, "They were last seen noticing $target with the message $msg", timechk());

    return 1;
}

# Callback for our on_topic hook.
sub on_topic {
    my ($src, @ntopic) = @_;

    my $chan = $src->{chan};

    update_seen($src->{svr}, $src->{nick}, "They were last seen changing the topic in $chan", timechk());

    return 1;
}

# Subroutine to check if a user exists in the seen database.
sub in_db {
    my ($svr, $user) = @_;
    my $dbh = $Auto::DB->prepare('SELECT * FROM seen WHERE net = ? and user = ?') or return 0;
    $dbh->execute(lc $svr, lc $user) or return 0;
    if ($dbh->fetchrow_array) {
        return 1;
    }
    return 0;
}

# Subroutine to update the seen database.
sub update_seen {
    my ($svr, $user, $last, undef, $minute, $hour, $mday, $month, $year) = @_;

    $svr = lc $svr;
    $user = lc $user;
    my $time = "at $hour:$minute on $month\/$mday\/$year";

    if (in_db($svr, $user)) {
        # They're already in the database, we can just update.
        my $q = "UPDATE seen SET last = '".$last."' WHERE net = '".$svr."' AND user = '".$user."'";
        $Auto::DB->do($q);
        $q = "UPDATE seen SET time = '".$time."' WHERE net = '".$svr."' AND user = '".$user."'";
        $Auto::DB->do($q);
    }
    else {
        # They're not already in the database, we need to create it.
        my $q = "INSERT INTO seen (net, user, last, time) VALUES ('".$svr."', '".$user."', '".$last."', '".$time."')";
        $Auto::DB->do($q);
    }
    return 1;
}

# Callback for the SEEN command.
sub cmd_seen {
    my ($src, @argv) = @_;

    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    if (lc $argv[0] eq lc $src->{nick}) {
        privmsg($src->{svr}, $src->{chan}, "Looking for yourself, huh?");
        return;
    }
    elsif (lc $argv[0] eq lc $State::IRC::botinfo{$src->{svr}}{nick}) {
        privmsg($src->{svr}, $src->{chan}, "Hello? I'm right here.");
        return;
    }
    elsif (!in_db($src->{svr}, $argv[0])) {
        privmsg($src->{svr}, $src->{chan}, "\2$argv[0]\2 is not in my seen database.");
        return;
    }
    else {
        my $dbh = $Auto::DB->prepare('SELECT * FROM seen WHERE net = ? and user = ?');
        $dbh->execute(lc $src->{svr}, lc $argv[0]);
        my $data = $dbh->fetchrow_hashref;
        privmsg($src->{svr}, $src->{chan}, "I last saw ".$argv[0]." ".$data->{time}.". ".$data->{last}.".");
    }

   return 1;
}


# Start initialization.
API::Std::mod_init('Seen', 'Ethrik', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

Seen

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <starcoder> !seen starcoder
 <blue> Looking for youself, huh?

 <starcoder> !seen matthew
 <blue> I last saw matthew at 12:00 on 02/24/2012. Thier last words in #xelhua were: <!matthew> hi.

=head1 DESCRIPTION

This module keeps records of users activity in order to provide a seen command
with last activity.

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by Ethrik Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Ethrik Development Group. All rights
reserved.

This module is released under the same licensing terms as Auto itself.

=cut

# vim: set ai et ts=4 sw=4:

