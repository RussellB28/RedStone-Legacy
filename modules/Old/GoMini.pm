# Module: GoMini. See below for documentation.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::GoMini;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use Furl;

# Initialization subroutine.
sub _init {
    # Create the GOMINI command.
    cmd_add('GOMINI', 0, 0, \%M::GoMini::HELP_GOMINI, \&M::GoMini::cmd_gomini) or return;

    # Success.
    #return 1;

    # Until fixed fail to load.
    return 0;
}

# Void subroutine.
sub _void {
    # Delete the GOMINI command.
    cmd_del('GOMINI') or return;

    # Success.
    return 1;
}

# Help hash.
our %HELP_GOMINI = (
    en => "This command will return a shortend version of the URL specified using gomini.me \2Syntax:\2 GOMINI <long url>",
);

# Callback for GOMINI command.
sub cmd_gomini {
    my ($src, @argv) = @_;
   
    # One parameter is required.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }
    
    # Create an instance of Furl.
    my $ua = Furl->new(
        agent => 'Auto IRC Bot',
        timeout => 5,
    );

    # Get the GoMini shortened URL.
    my $rp = $ua->post('http://gomini.me/api/shorten', [], [ url => $argv[0], ]);

    if ($rp->is_success) {
        # If successful, get the content.
        my $url = $rp->content;
        
        # If there's an error, return it.
        if ($url eq 'FMT_ERROR') {
            privmsg($src->{svr}, $src->{chan}, "\2gomini.me:\2 Format Error: Check to make sure you include a valid HTTP prefix (e.g. http://).");
            return;
        }
        if ($url eq 'DB_ERROR') {
            privmsg($src->{svr}, $src->{chan}, "\2gomini.me:\2 Database Error: GoMini encountered a database error.");
            return;
        }

        # Return the shortend URL.
        privmsg($src->{svr}, $src->{chan}, "\2gomini.me:\2 $argv[0] -> $url");
    }
    else {
        # Otherwise, send an error message.
        privmsg($src->{svr}, $src->{chan}, 'An error occurred while creating the URL.');
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('GoMini', 'Xelhua', '1.00', '3.0.0a11');
# build: cpan=Furl perl=5.010000

__END__

=head1 NAME

GoMini - A module for making a gomini.me URL.

=head1 VERSION

 1.00

=head1 SYNOPSIS

 <starcoder> !gomini http://google.com
 <blue> gomini.me: http://google.com -> http://gomini.me/T

=head1 DESCRIPTION

This module creates the GOMINI command, which will make a shortened URL of a
specified long URL using gomini.me.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<Furl>

This is the HTTP agent used by this module.

=back

=head1 AUTHOR

This module was written by Matthew Barksdale.

This module is maintained by RedStone Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2014 RedStone Development Group.

Released under the same licensing terms as RedStone itself.

=cut

# vim: set ai et sw=4 ts=4:
