# Module: Bitly. See below for documentation.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Bitly;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del conf_get err trans);
use API::IRC qw(privmsg notice);
use Furl;
use URI::Escape;

# Initialization subroutine.
sub _init {
    # Check for required configuration values.
    if (!conf_get('bitly:user') or !conf_get('bitly:key')) {
        err(2, 'Bitly: Please verify that you have bitly_user and bitly_key defined in your configuration file.', 0);
        return;
    }
    # Create the SHORTEN and REVERSE commands.
    cmd_add('SHORTEN', 0, 0, \%M::Bitly::HELP_SHORTEN, \&M::Bitly::cmd_shorten) or return;
    cmd_add('REVERSE', 0, 0, \%M::Bitly::HELP_REVERSE, \&M::Bitly::cmd_reverse) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the SHORTEN and REVERSE commands.
    cmd_del('SHORTEN') or return;
    cmd_del('REVERSE') or return;

    # Success.
    return 1;
}

# Help hashes.
our %HELP_SHORTEN = (
    en => "This command will shorten an URL using Bit.ly. \2Syntax:\2 SHORTEN <url>",
    de => "Dieser Befehl wird eine URL verkuerzen. \2Syntax:\2 SHORTEN <url>",
);
our %HELP_REVERSE = (
    en => "This command will expand a Bit.ly URL. \2Syntax:\2 REVERSE <url>",
    de => "Dieser Befehl wird eine URL erweitern. \2Syntax:\2 REVERSE <url>",
);

# Callback for SHORTEN command.
sub cmd_shorten {
    my ($src, @argv) = @_;

    # Create an instance of Furl.
    my $ua = Furl->new(
        agent => 'Auto IRC Bot',
        timeout => 5,
    );
    
    # Put together the call to the Bit.ly API. 
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').".");
        return;
    }
    my ($surl, $user, $key) = ($argv[0], (conf_get('bitly:user'))[0][0], (conf_get('bitly:key'))[0][0]);
    $surl = uri_escape($surl);
    my $url = "http://api.bit.ly/v3/shorten?version=3.0.1&longUrl=$surl&apiKey=$key&login=$user&format=txt";
    
    # Get the response via HTTP.
    my $response = $ua->get($url);

    if ($response->is_success) {
        # If successful, get the content.
        my $data = $response->content;
        chomp $data;
        # And send to channel.
        privmsg($src->{svr}, $src->{chan}, "URL: $data");
    }
    else {
        # Otherwise, send an error message.
        privmsg($src->{svr}, $src->{chan}, 'An error occurred while shortening your URL.');
    }

    return 1;
}

# Callback for REVERSE command.
sub cmd_reverse {
    my ($src, @argv) = @_;

    # Create an instance of Furl.
    my $ua = Furl->new(
        agent => 'Auto IRC Bot',
        timeout => 5,
    );

    # Put together the call to the Bit.ly API.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').".");
        return;
    }
    my ($surl, $user, $key) = ($argv[0], (conf_get('bitly:user'))[0][0], (conf_get('bitly:key'))[0][0]);
    $surl = uri_escape($surl);
    my $url = "http://api.bit.ly/v3/expand?version=3.0.1&shortURL=$surl&apiKey=$key&login=$user&format=txt";
    
    # Get the response via HTTP.
    my $response = $ua->get($url);

    if ($response->is_success) {
        # If successful, get the content.
        my $data = $response->content;
        chomp $data;
        # And send it to channel.
        if ($data ne 'NOT_FOUND') {
            privmsg($src->{svr}, $src->{chan}, "URL: $data");
        }
        else {
            privmsg($src->{svr}, $src->{chan}, 'URL not found.');
        }
    }
    else {
        # Otherwise, send an error message.
        privmsg($src->{svr}, $src->{chan}, 'An error occurred while reversing your URL.');
    }

    return 1;
}


# Start initialization.
API::Std::mod_init('Bitly', 'Xelhua', '1.01', '3.0.0a11');
# build: cpan=Furl,URI::Escape perl=5.010000

__END__

=head1 NAME

Bitly - A module for shortening/expanding URL's using Bit.ly

=head1 VERSION

 1.01

=head1 SYNOPSIS



=head1 DESCRIPTION

This module creates the SHORTEN and REVERSE commands for shortening/expanding
an URL using the Bit.ly shortening service API.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<Furl>

This is the HTTP agent used by this module.

=item L<URI::Escape>

This is used for escaping special letters from URL's.

=back

=head1 INSTALL

Add Bitly to module auto-load and the following to your configuration file:

  bitly {
    user "<bit.ly username>";
    key "<bit.ly API key>";
  }

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
