# Module: IsItUp. See below for documentation.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::IsItUp;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use Furl;

# Initialization subroutine.
sub _init {
    # Create the ISITUP command.
    cmd_add('ISITUP', 0, 0, \%M::IsItUp::HELP_ISITUP, \&M::IsItUp::cmd_isitup) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the ISITUP command.
    cmd_del('ISITUP') or return;

    # Success.
    return 1;
}

# Help hashes.
our %HELP_ISITUP = (
    en => "This command will check if a website appears up or down to the bot. \2Syntax:\2 ISITUP <url>",
    fr => "Cette commande va vérifier si un site Web semble être vers le haut ou vers le bas pour le bot. \2Syntaxe:\2 ISITUP <url>",
);

# Callback for ISITUP command.
sub cmd_isitup {
    my ($src, @argv) = @_;

    # Create an instance of Furl.
    my $ua = Furl->new(
        agent => 'Auto IRC Bot',
        timeout => 5,
    );

    # Do we have enough parameters?
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }
    my $curl = $argv[0];
    # Does the URL start with http(s)?
    if ($curl !~ m/^http/) {
        $curl = 'http://'.$curl;
    }

    # Get the response via HTTP.
    my $response = $ua->get($curl);

    if ($response->is_success) {
        # If successful, it's up.
        privmsg($src->{svr}, $src->{chan}, "$curl appears to be up from here.");
    }
    else {
        # Otherwise, it's down.
        privmsg($src->{svr}, $src->{chan}, "$curl appears to be down from here.");
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('IsItUp', 'Xelhua', '1.01', '3.0.0a11');
# build: cpan=Furl perl=5.010000

__END__

=head1 NAME

IsItUp - Check if a website is online

=head1 VERSION

 1.01

=head1 SYNOPSIS

 <starcoder> !isitup google.com
 <blue> http://google.com appears to be up from here.

=head1 DESCRIPTION

This module creates the ISITUP command for checking if website appears to be
online or offline to Auto (or rather, the system he's running on).

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<Furl>

This is the HTTP agent this module uses.

=back

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
