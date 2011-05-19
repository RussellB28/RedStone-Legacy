# lib/State/IRC.pm - IRC state data.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package State::IRC;
use strict;
use warnings;
use API::Std qw(hook_add rchook_add);
our (%chanusers, %botinfo, @whox_wait);

# Create on_namesreply hook.
hook_add('on_namesreply', 'state.irc.names', sub {
    my ($svr, $chan, undef) = @_;

    # Ship off a WHOX and wait for data.
    Auto::socksnd($svr, "WHO $chan %cnf");
    push @whox_wait, lc $chan;

    return 1;
});

# Create a WHOX reply hook.
rchook_add('354', 'state.irc.whox', sub {
    my ($svr, @data) = @_;

    # Are we expecting WHOX data for this channel?
    if (lc $data[3] ~~ @whox_wait) {
        # Grab the server's prefixes.
        my @prefixes = values %{$Proto::IRC::csprefix{$svr}};
        # And this user's modes.
        my @umodes = split //, $data[5];

        # Iterate through their modes, saving channel status modes to memory.
        $chanusers{$svr}{lc $data[3]}{lc $data[4]} = q{};
        foreach my $mode (@umodes) {
            if ($mode ~~ @prefixes) {
                # Okay, so we've got some channel status, figure out the actual mode.
                my $amode;
                while (my ($pmod, $pfx) = each %{$Proto::IRC::csprefix{$svr}}) {
                    if ($pfx eq $mode) { $amode = $pmod }
                }

                # Great, now add it to their modes in memory.
                $chanusers{$svr}{lc $data[3]}{lc $data[4]} .= $amode;
            }
        }

        # If their modes are still empty, mark them as a normal user.
        if ($chanusers{$svr}{lc $data[3]}{lc $data[4]} eq q{}) {
            $chanusers{$svr}{lc $data[3]}{lc $data[4]} = 1;
        }
    }

    return 1;
});

# Create end of WHO hook.
rchook_add('315', 'state.irc.eow', sub {
    my ($svr, (undef, undef, undef, $chan, undef)) = @_;

    # If we're expecting WHOX data for this channel, stop expecting, provided we've gotten data at all.
    if (lc $chan ~~ @whox_wait and keys %{$chanusers{$svr}{lc $chan}} > 0) {
        for my $loc (0..$#whox_wait) {
            if ($whox_wait[$loc] eq lc $chan) { splice @whox_wait, $loc, 1; last }
        }
    }

    return 1;
});

1;
