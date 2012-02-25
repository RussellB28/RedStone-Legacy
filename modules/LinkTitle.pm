# Module: LinkTitle. See below for documentation.
# Copyright (C) 2010-2012 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::LinkTitle;
use strict;
use warnings;
use URI::Title qw(title);
use API::Std qw(hook_add hook_del);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init {
    # Create the on_cprivmsg hook.
    hook_add('on_cprivmsg', 'privmsg.html.returntitle', \&M::LinkTitle::gettitle) or return;

    # Success.
    return 1;
}

# Void subroutine.
sub _void {
    # Delete the hook we created.
    hook_del('on_cprivmsg', 'privmsg.html.returntitle') or return;

    # Success.
    return 1;
}

# Hook callback.
sub gettitle {
    my ($src, $chan, @msg) = @_;

    # Check if the message contains a URL.
    foreach my $smw (@msg) {
        if ($smw =~ m{^(http|https)://.*\..*}xsm) {
            # Get data.
            my $title = title($smw);
            return if length($title) == 0;
            privmsg($src->{svr}, $chan, "\2Title:\2 $title");
        }
    }

    return 1;
}

# Start initialization.
API::Std::mod_init('LinkTitle', 'Xelhua', '3.00', '3.0.0a11');
# build: cpan=URI::Title,Encode::Detect::Detector perl=5.010000

__END__

=head1 NAME

LinkTitle - A module for returning the page title of links.

=head1 VERSION

 3.00

=head1 SYNOPSIS

 <starcoder> http://xelhua.org/auto.php 
 <blue> Title: Xelhua / Projects / Auto

=head1 DESCRIPTION

This module will make Auto parse all links sent to a channel. When a link is
detected, Auto will connect to it and get the page title by scanning for the
<title> tag and returning its contents to the channel.

=head1 DEPENDENCIES

This module is dependent on two modules from the CPAN.

=over

=item L<URI::TItle>

This module is used for getting the URLs title.

=item L<Encode::Detect::Detector>

Dependency of URI::Title.

=back

=head1 AUTHOR

This module was written by Elijah Perrault.

This module is maintained by Xelhua Development Group.

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2010-2012 Xelhua Development Group. All rights
reserved.

This module is released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
