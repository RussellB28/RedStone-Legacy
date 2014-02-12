# Module: Spotify. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Spotify;
use strict;
use warnings;
use Net::Spotify;
use XML::TreePP;
use URI::Encode qw(uri_encode);
use JSON -support_by_pp;
use Furl;
use API::Std qw(hook_add hook_del cmd_add cmd_del conf_get);
use API::IRC qw(privmsg notice);
our $spotify;
our $xmlp;
our $json;
our $RLimit = 30;
our $LastSpotify;

# Initialization subroutine.
sub _init {
    # Create the on_cprivmsg hook.
    hook_add('on_cprivmsg', 'spotify.info', \&M::Spotify::on_privmsg) or return;
    # Create the SPOTIFY command.
    cmd_add('SPOTIFY', 0, 0, \%M::Spotify::HELP_SPOTIFY, \&M::Spotify::cmd_spotify) or return;
    # Create instances.
    $spotify = Net::Spotify->new;
    $xmlp = XML::TreePP->new;
    $json = JSON->new;
    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the hook we created.
    hook_del('on_cprivmsg', 'spotify.info') or return;
    # Delete the command we created.
    cmd_del('SPOTIFY') or return;
    # Success.
    return 1;
}

# HELP hashes.
our %HELP_SPOTIFY = (
    en => "This command provides a way to search for songs on Spotify. \2Syntax:\2 SPOTIFY <search string>",
);

# Command callback.
sub cmd_spotify {
    my ($src, @args) = @_;
	if(eval(time()-$LastSpotify) >= $RLimit) {
		notice($src->{svr}, $src->{chan}, "Invalid parameters. \2Syntax:\2 SPOTIFY <search string>") and return if !@args;
		my $search = uri_encode(join ' ', @args);
		my $furl = Furl->new;
		my $res = $furl->get("http://ws.spotify.com/search/1/track.json?q=$search");
		privmsg($src->{svr}, $src->{chan}, 'Request failed.') and return if !$res->is_success; 
		my $data = $json->allow_nonref->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($res->content);
		privmsg($src->{svr}, $src->{chan}, "Query returned no results.") and return if $data->{info}->{num_results} == 0;
		my $i = 0;
		my $max = (conf_get('spotify:max') ? (conf_get('spotify:max'))[0][0] : 5);
		privmsg($src->{svr}, $src->{chan}, "Got ".$data->{info}->{num_results}." results. Displaying top ".$max."...");
		foreach (@{$data->{tracks}}) {
			$i++;
			my $artists;
			foreach my $artist (@{$_->{artists}}) {
				$artists = $artist->{name} and next if !$artists;
				$artists = $artists. ", ".$artist->{name} if $artists;
			}
			privmsg($src->{svr}, $src->{chan}, "$i. \2URI:\2 ".$_->{href}." \2Name:\2 ".$_->{name}." \2Artist:\2 ".$artists);
			privmsg($src->{svr}, $src->{chan}, 'Reached max output. Stopping.') and last if $i >= $max;
		}
		$LastSpotify = time();
	}
    return 1;
}

# Hook callback.
sub on_privmsg {
    my ($src, $chan, @msg) = @_;
	if(eval(time()-$LastSpotify) >= $RLimit) {
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
						my $id;
						if ($uri =~ m/spotify:track:(\w+)/) {
							$id = $1;
						}
						if (ref($tree->{track}->{artist}) eq 'ARRAY') {
						   foreach (@{$tree->{track}->{artist}}) {
								$artists = $_->{name} and next if !$artists;
								$artists .= ", ".$_->{name};
							}
						}
						else {
							$artists = $tree->{track}->{artist}->{name};
						}
						privmsg($src->{svr}, $chan, sprintf("\2%s\2: Track: %s, Album: %s, Artist(s): %s URL: http://open.spotify.com/track/%s", $uri, $tree->{track}->{name}, $tree->{track}->{album}->{name}, $artists, $id));
					}
				}
			}
		}
		$LastSpotify = time();
	}
    return 1;
}

# Start initialization.
API::Std::mod_init('Spotify', 'Ethrik', '1.00', '3.0.0a11');
# build: cpan=XML:TreePP,Net::Spotify,Furl,URI::Encode perl=5.010000

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

=head1 CONFIGURATION

  spotify {
     max 5;
  }
  
  max defines the maximum number of results to return.

=head1 DEPENDENCIES

This module is dependent on two modules from the CPAN.

=over

=item L<Net::Spotify>

This module is used for getting the information.

=item L<XML::TreePP>

This module is used for parsing the information.

=item L<Furl>

This module is used for getting information from spotify.

=item L<URI::Encode>

This module is used for encoding search queries.

=back

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group. All rights
reserved.

This module is released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
