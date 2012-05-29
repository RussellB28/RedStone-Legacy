# Module: Etymology. See below for documentation.
# Copyright (C) 2012 [NAS]peter, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Etymology;
use strict;
use warnings;
use Furl;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init {
	cmd_add('ETYMOLOGY', 0, 0, \%M::Etymology::HELP_ETYMOLOGY, \&M::Etymology::cmd_ety) or return;
	cmd_add('ETY', 0, 0, \%M::Etymology::HELP_ETYMOLOGY, \&M::Etymology::cmd_ety) or return;
	# Success.
    return 1;
}

# Void subroutine.
sub _void {
	cmd_del('ETYMOLOGY') or return;
	cmd_del('ETY') or return;
    # Success.
    return 1;
}

our %HELP_ETYMOLOGY = (
    en => "Will retrieve the etymology of a word. \2Syntax:\2 ETY <WORD>",
	#nl => "Haalt de etymologie op van een woord. \2Syntax:\2 ETY <WORD>",
);

sub cmd_ety {
    my ($src, @argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too little parameters').q{.});
        return;
	}
	if(defined($argv[1])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too many parameters').q{.});
        return;
	}
	# Create an instance of Furl.
	my $ua = Furl->new(
		agent => 'Auto IRC Bot',
		timeout => 5,
	);
	my $url = 'http://www.etymonline.com/index.php?allowed_in_frame=0&search='.$argv[0]."&searchmode=term";
	my $response = $ua->get($url);
	if ($response->is_success) {
		my $content = $response->content;
		$content =~ s/\n//g;
		if($content =~ /<dd class="highlight">(.*)<\/dd>/) {
			my $lol1 = $1;
			$lol1 =~ s/<span class="foreign">//g;
			$lol1 =~ s/<\/span>//g;
			$lol1 =~ s/<a href="(.+?)" class="(.+?)">//g;
			$lol1 =~ s/<\/a>//g;
			$lol1 =~ s/\+ -(.+?).//g;
			$lol1 =~ s/\(1\)//g;
			privmsg($src->{svr},$src->{chan},"$lol1");
		} else {
			privmsg($src->{svr},$src->{chan},"An error occurred while retrieving the etymology.");
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the etymology.");
		return;
	}
}

# Start initialization.
API::Std::mod_init('Etymology', '[NAS]peter', '1.00', '3.0.0a11');
# build: perl=5.010000 cpan=Furl

__END__

=head1 NAME

Etymology - IRC interface to retrieve the etymology of a word

=head1 VERSION

 1.00
 
=head1 SYNOPSIS



=head1 DESCRIPTION

This will fetch the etymology of a few words

=head1 CONFIGURATION

No configurable options.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=item L<Furl>

The HTTP agent used.

=back

=head1 AUTHOR

This module was written by [NAS]peter

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2012 [NAS]peter.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4:
