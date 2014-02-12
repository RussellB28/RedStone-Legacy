# lib/Core/IRC/Users.pm - IRC user tracking.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Core::IRC::Users;
use strict;
use warnings;
use API::Std qw(hook_add);
our %users;

# Initialize the ircusers_create and ircusers_delete events.
API::Std::event_add('ircusers_create');
API::Std::event_add('ircusers_delete');

# Create the on_rcjoin hook.
hook_add('on_rcjoin', 'ircusers.onjoin', sub {
    my ($src, $chan) = @_;

    # Add the user to the users hash, if not already defined.
    if (!$users{$src->{svr}}{lc $src->{nick}}) {
        $users{$src->{svr}}{lc $src->{nick}} = $src->{nick};
        API::Std::event_run('ircusers_create', ($src->{svr}, $src->{nick}));
    }

    return 1;
}, 1);

# Create the on_whoreply hook.
hook_add('on_whoreply', 'ircusers.who', sub {
    my ($svr, $nick, undef) = @_;

    # Ensure it is not us.
    if (lc $nick ne lc $State::IRC::botinfo{$svr}{nick}) {
        # It is not. Check if they're already in the users hash.
        if (!$users{$svr}{lc $nick}) {
            # They are not; add them.
            $users{$svr}{lc $nick} = $nick;
        }
    }

    return 1;
}, 1);

# Create the on_nick hook.
hook_add('on_nick', 'ircusers.onnick', sub {
    my ($src, $newnick) = @_;

    # Modify the user's entry in the users hash.
    if ($users{$src->{svr}}{lc $src->{nick}}) {
        delete $users{$src->{svr}}{lc $src->{nick}};
        $users{$src->{svr}}{lc $newnick} = $newnick;
    }

    return 1;
}, 1);

# Create the on_kick hook.
hook_add('on_kick', 'ircusers.onkick', sub {
    my ($src, $kchan, $user, undef) = @_;

    # Ensure there is a users hash entry for this user.
    if ($users{$src->{svr}}{lc $user}) {
        # Figure out if the user is in any other channel we're in.
        my $ri = 0;
        foreach my $chan (keys %{$State::IRC::chanusers{$src->{svr}}}) {
            if ($chan ne $kchan) {
                if (defined $State::IRC::chanusers{$src->{svr}}{$chan}{lc $user}) { $ri++; last }
            }
        }
        if (!$ri) {
            # They are not, delete them.
            delete $users{$src->{svr}}{lc $user};
            API::Std::event_run('ircusers_delete', ($src->{svr}, $user));
        }
    }

    return 1;
}, 1);

# Create the on_part hook.
hook_add('on_part', 'ircusers.onpart', sub {
    my ($src, $pchan, undef) = @_;

    # Ensure there is a users hash entry for this user.
    if ($users{$src->{svr}}{lc $src->{nick}}) {
        # Figure out if the user is in any other channel we're in.
        my $ri = 0;
        foreach my $chan (keys %{$State::IRC::chanusers{$src->{svr}}}) {
            if ($chan ne $pchan) {
                if (defined $State::IRC::chanusers{$src->{svr}}{$chan}{lc $src->{nick}}) { $ri++; last }
            }
        }
        if (!$ri) {
            # They are not, delete them.
            delete $users{$src->{svr}}{lc $src->{nick}};
            API::Std::event_run('ircusers_delete', ($src->{svr}, $src->{nick}));
        }
    }

    return 1;
}, 1);

# Create the on_quit hook.
hook_add('on_quit', 'ircusers.onquit', sub {
    my ($src, undef) = @_;

    # Delete the user's entry from the users hash.
    if ($users{$src->{svr}}{lc $src->{nick}}) {
        delete $users{$src->{svr}}{lc $src->{nick}};
    }

    return 1;
}, 1);


1;
# vim: set ai et sw=4 ts=4:
