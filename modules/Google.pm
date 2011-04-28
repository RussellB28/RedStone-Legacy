# Module: Google. See below for documentation.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Google;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use Google::Search;

# Initialization subroutine.
sub _init {
    # Create the GOOGLE command.
    cmd_add('GOOGLE', 0, 0, \%M::Google::HELP_GOOGLE, \&M::Google::cmd_google) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the GOOGLE command.
    cmd_del('GOOGLE');

    # Success.
    return 1;
}

# Help hash for GOOGLE.
our %HELP_GOOGLE = (
    en => "This command will return the results of your Google Web Search query. \2Syntax:\2 GOOGLE <query>",
);

# Callback for GOOGLE command.
sub cmd_google {
    my ($src, @argv) = @_;

    # At least one argument required.
    if (!defined $argv[0]) {
        notice($src->{svr}, $src->{nick}, trans('Not enough parameters').q{.});
        return;
    }

    # Get query.
    my $search = Google::Search->Web(join ' ', @argv);
    # Make a  buffer.
    my @buffer = ();

    # Get 5 results.
    for (0..4) {
        my $res = $search->next;
        if (!$res) { last }
        my $num = $res->rank + 1;
        push @buffer, "\2$num.\2 ".$res->uri;
    }

    # Return results.
    privmsg($src->{svr}, $src->{chan}, "\2Results:\2 ".join(' ', @buffer));

    return 1;
}

# Start initialization.
API::Std::mod_init('Google', 'Xelhua', '0.01', '3.0.0a11');
# build: cpan=Google::Search perl=5.010000

__END__

=head1 NAME

Google - Interface to Google Web Search

=head1 VERSION

 0.01

=head1 SYNOPSIS

 <starcoder|laptop> !google foo
 <blue> Results: 1. http://en.wikipedia.org/wiki/Foobar 2. http://www.foofighters.com/ 3. http://foo.com/ 4. http://www.urbandictionary.com/define.php?term=foo 5. http://www.foopets.com/

=head1 DESCRIPTION

This module creates the GOOGLE command which allows you to make queries on the
Google Web Search service using the Google::Search module.

NOTE: Google::Search uses a lot of RAM (~4MB), we need to write our own
efficient interface to Google's API.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<Google::Search>

This module provides the actual interface to Google's AJAX API.

=back

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2011 Xelhua Development Group.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
