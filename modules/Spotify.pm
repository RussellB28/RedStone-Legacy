# Module: Spotify. See below for documentation.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Spotify;
use strict;
use warnings;
use Net::Spotify;
use XML::TreePP;
use API::Std qw(hook_add hook_del);
use API::IRC qw(privmsg);
use API::Log qw(dbug);

# Initialization subroutine.
sub _init {
    # Create the on_cprivmsg hook.
    hook_add('on_cprivmsg', 'spotify.info', \&M::Spotify::on_privmsg) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the hook we created.
    hook_del('on_cprivmsg', 'spotify.info') or return;

    # Success.
    return 1;
}

# Hook callback.
sub on_privmsg {
    my ($src, $chan, @msg) = @_;

    my $spotify = Net::Spotify->new;
    my $xmlp = XML::TreePP->new;

    # Check if the message contains a spotify url.
    foreach my $smw (@msg) {
        if ($smw =~ m{^(spotify:(artist|album|track):\w+)$}gmx) {
            my ($uri, $type) = ($1, $2);
            my $xml = $spotify->lookup(uri => $uri);
            if (my $tree = $xmlp->parse($xml)) {
                if ($type eq 'artist') {
                    privmsg($src->{svr}, $chan, sprintf("\2%s\2: Artist: %s", $uri, $tree->{artist}->{name}));
                }
                elsif ($type eq 'album') {
                    privmsg($src->{svr}, $chan, sprintf("\2%s\2: Album: %s, Artist: %s, Year: %s", $uri, $tree->{album}->{name}, $tree->{album}->{artist}->{name}, $tree->{album}->{released}));
                }
                elsif ($type eq 'track') {
                    my $artists;
                    if (ref($tree->{track}->{artist}) eq 'ARRAY') {
                       foreach (@{$tree->{track}->{artist}}) {
                            $artists = $_->{name} and next if !$artists;
                            $artists .= ", ".$_->{name};
                        }
                    }
                    else {
                        $artists = $tree->{track}->{artist}->{name};
                    }
                    privmsg($src->{svr}, $chan, sprintf("\2%s\2: Track: %s, Album: %s, Artist(s): %s", $uri, $tree->{track}->{name}, $tree->{track}->{album}->{name}, $artists));
                }
            }
        }
    }
    return 1;
}

# Start initialization.
API::Std::mod_init('Spotify', 'Ethrik', '1.00', '3.0.0a11');
# build: cpan=XML:TreePP,Net::Spotify perl=5.010000

__END__

=head1 NAME

Spotify - A module for returning information on a spotify URI.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <starcoder> spotify:track:7sOBuRK26Ov7CR5fRSR7Om
 <blue> spotify:track:7sOBuRK26Ov7CR5fRSR7Om: Track: Surf Rider - LP Version, Album: Surf Rider!, Artist: The Lively Ones

=head1 DESCRIPTION

This module will make Auto parse all spotify URIs sent to a channel. When a URI is
detected, Auto will find information pertaining to it.

=head1 DEPENDENCIES

This module is dependent on two modules from the CPAN.

=over

=item L<Net::Spotify>

This module is used for getting the information.

=item L<XML::TreePP>

This module is used for parsing the information.

=back

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by Ethrik Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Ethrik Development Group. All rights
reserved.

This module is released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
