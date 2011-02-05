# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
package m_FML;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg notice);
use LWP::UserAgent;

# Initialization subroutine.
sub _init 
{
    # Create the FML command.
	cmd_add("FML", 0, 0, \%m_FML::HELP_FML, \&m_FML::fml) or return 0;

    # Success.
    return 1;
}

# Void subroutine.
sub _void 
{
    # Delete the FML command.
	cmd_del("FML") or return 0;

    # Success.
	return 1;
}

# Help hash.
our %HELP_FML = (
    'en' => "This command will return a random FML quote. \002Syntax:\002 FML",
);

# Callback for FML command.
sub fml
{
	my (%data) = @_;

    # Create an instance of LWP::UserAgent.
	my $ua = LWP::UserAgent->new();
	$ua->agent('Auto IRC Bot');
	$ua->timeout(2);
    
    # Get the random FML via HTTP.
    my $rp = $ua->get("http://rscript.org/lookup.php?type=fml");

	if ($rp->is_success) {
        # If successful, decode the content.
        my $d = $rp->decoded_content;
		$d =~ s/(\n|\r)//g;

        # Get the FML.
        my (undef, $dfa) = split('Text: ', $d);
        my ($fml, undef) = split('Agree:', $dfa);

        # And send to channel.
		privmsg($data{svr}, $data{chan}, "\002Random FML:\002 ".$fml);
	}
    else {
        # Otherwise, send an error message.
        privmsg($data{svr}, $data{chan}, "An error occurred while retrieving the FML.");
    }

	return 1;
}


# Start initialization.
API::Std::mod_init("FML", "Xelhua", "1.00", "3.0.0d", __PACKAGE__);

__END__

=head1 FML

=head2 Description

=over

This module adds the FML command for retrieving a random FML quote.

=back

=head2 Examples

=over

<JohnSmith> !fml
<Auto> Random FML: Today, the girl I've had a crush on decided she 
wanted to see a movie with me. I tried to hold her hand during the 
movie and it was great for about 4 minutes. Then she said "Can I 
have my hand back?" FML 

=back

=head2 To Do

=over

* Add Spanish, French and German translations for the help hash.

=back

=head2 Technical

=over

This module adds an extra dependency: LWP::UserAgent. You can get it from
the CPAN <http://www.cpan.org>.

This module is compatible with Auto version 3.0.0a2+.

Ported from Auto 2.0.

=back
