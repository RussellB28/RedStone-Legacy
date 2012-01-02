# Module: Karma. See below for documentation.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Karma;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del hook_add hook_del conf_get trans err);
use API::IRC qw(notice);
our %LASTUSE;

# Initialization subroutine.
sub _init {
    # Check the database format. Fail to load if it's PostgreSQL.
    if ($Auto::ENFEAT =~ /pgsql/) { err(2, 'Unable to load QDB: PostgreSQL is not supported.', 0); return }

    # Create our database table if doesn't exist.
    $Auto::DB->do('CREATE TABLE IF NOT EXISTS karma (user TEXT, score TEXT)') or return;
    
    # Create the KSCORE command.
    cmd_add('KSCORE', 2, 0, \%M::Karma::HELP_KSCORE, \&M::Karma::cmd_kscore) or return;
    # Create our on_cprivmsg hook.
    hook_add('on_cprivmsg', 'karma.check', \&M::Karma::on_cprivmsg) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the KSCORE command.
    cmd_del('KSCORE') or return;
    # Delete the on_cprivmsg hook.
    hook_del('on_cprivmsg', 'karma.check') or return;

    # Success.
    return 1;
}

# Help hash for the KSCORE command.
our %HELP_KSCORE = (
    en => "This command will return the current Karma score of a user. Returns the sender's score if [user] is not given. \2Syntax:\2 KSCORE [user]",
);

# Callback for KSCORE command.
sub cmd_kscore {
    my ($src, @argv) = @_;

    my $target;
    if (!defined $argv[0]) {
        $target = lc $src->{nick};
    }
    else {
        $target = lc $argv[0];
    }

    if ($Auto::DB->selectrow_array('SELECT * FROM karma WHERE user = "'.$target.'"')) {
        # Get their score.
        my $score = $Auto::DB->selectrow_array('SELECT score FROM karma WHERE user = "'.$target.'"');
        # Return it.
        notice($src->{svr}, $src->{nick}, "Score for \2$target\2: $score");
    }
    else {
        notice($src->{svr}, $src->{nick}, "No score for \2$target\2 found.");
    }

    return 1;
}

# Callback for our on_cprivmsg hook.
sub on_cprivmsg {
    my ($src, $chan, @msg) = @_;

    # Spam protection.
    my $rltime = 60;
    if (conf_get('karma_ratelimit')) { $rltime = (conf_get('karma_ratelimit'))[0][0] }
    if (exists $LASTUSE{$src->{svr}}{lc $src->{nick}}) {
        if (time - $LASTUSE{$src->{svr}}{lc $src->{nick}} <= $rltime) { return 1 }
    }

    if ($msg[0] =~ m/^(.+)\+\+;?$/xsm) {
        # Potential increment, check if the rest of the word is a user in the channel AND they're not trying to change their own score.
        if (exists $State::IRC::chanusers{$src->{svr}}{lc $chan}{lc $1} and lc $1 ne lc $src->{nick}) {
            my $score;
            if (!$Auto::DB->selectrow_array('SELECT * FROM karma WHERE user = "'.lc $1.'"')) {
                $Auto::DB->do('INSERT INTO karma (user, score) VALUES ("'.lc $1.'", 0)') or err(3, "Unable to update Karma score for $1!", 0);
                $score = 0;
            }
            else {
                $score = $Auto::DB->selectrow_array('SELECT score FROM karma WHERE user = "'.lc $1.'"') or err(3, "Unable to update Karma score for $1!", 0);
            }
            $Auto::DB->do('UPDATE karma SET score = '.++$score.' WHERE user = "'.lc $1.'"') or err(3, "Unable to update Karma score for $1!", 0);
            $LASTUSE{$src->{svr}}{lc $src->{nick}} = time;
            _chkmem();
        }
    }
    elsif ($msg[0] =~ m/^(.+)--;?$/xsm) {
        # Potential decrement, check if the rest of the word is a user in the channel AND they're not trying to change their own score.
        if (exists $State::IRC::chanusers{$src->{svr}}{lc $chan}{lc $1} and lc $1 ne lc $src->{nick}) {
            my $score;
            if (!$Auto::DB->selectrow_array('SELECT * FROM karma WHERE user = "'.lc $1.'"')) {
                $Auto::DB->do('INSERT INTO karma (user, score) VALUES ("'.lc $1.'", "0")') or err(3, "Unable to update Karma score for $1!", 0);
                $score = 0;
            }
            else {
                $score = $Auto::DB->selectrow_array('SELECT score FROM karma WHERE user = "'.lc $1.'"') or err(3, "Unable to update Karma score for $1!", 0);
            }
            $Auto::DB->do('UPDATE karma SET score = "'.--$score.'" WHERE user = "'.lc $1.'"') or err(3, "Unable to update Karma score for $1!", 0);
            $LASTUSE{$src->{svr}}{lc $src->{nick}} = time;
            _chkmem();
        }
    }

    return 1;
}

# Subroutine for keeping LASTUSE clean.
sub _chkmem {
    my $count;
    foreach my $key (keys %LASTUSE) {
        $count += keys %{$LASTUSE{$key}};
    }
    if ($count >= 1500) { %LASTUSE = () }
    
    return 1;
}

# Start initialization.
API::Std::mod_init('Karma', 'Xelhua', '1.00', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

Karma - A module for managing people's karma.

=head1 SYNOPSIS

 <starcoder> blue++
 <starcoder> .kscore blue
 -blue- Score for blue: 1
 <starcoder> blue--
 <starcoder> .kscore blue
 -blue- Score for blue: 0

=head1 DESCRIPTION

This module scans channel messages for changes to another user's karma, like:

<user>++ raises their score by 1
<user>-- lowers their score by 1

A user may not change their own score.

It also understands ++; and --;, as this is a common mistake made by
programmers.

You can then view someone's score with KSCORE <user>, or if <user> is not
given, your own score is returned. This can be used in PM or in channel.

It also includes self-ratelimit functionality, see below.

=head1 CONFIGURATION

You can optionally set the karma_ratelimit configuration option like so:

 karma_ratelimit <number of seconds>;

Where <number of seconds> is how often karma scores can be changed per user
per server.

Like so:

 karma_ratelimit 30;

If not set, this defaults to 60.

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
