# Module: Translate. See below for documentation.
# Copyright (C) 2012 [NAS]peter, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::Translate;
use strict;
use warnings;
use URI::Escape;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init {
	cmd_add('translate', 0, 0, \%M::Spell::HELP_TRANSLATE, \&M::Translate::cmd_translate) or return;
	cmd_add('tr', 0, 0, \%M::Spell::HELP_TRANSLATE, \&M::Translate::cmd_translate) or return;
	# Success.
    return 1;
}

# Void subroutine.
sub _void {
	cmd_del('translate') or return;
	cmd_del('tr') or return;
	
    # Success.
    return 1;
}

our %HELP_TRANSLATE = (
    en => "Will translate a given sentence to the given language. \2Syntax:\2 TRANSLATE <COUNTRY CODE> <TEXT TO TRANSLATE>",
	#nl => "Vertaalt een ingegeven tekst naar de ingegeven taal. \2Syntax:\2 TRANSLATE <LANDCODE> <TEKST OM TE VERTALEN>",
);

sub cmd_translate {
    my ($src, @argv) = @_;
	if(!defined($argv[1])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too little parameters').q{.});
        return;
	}
	
	my $text = join(' ',@argv);
	$text =~ s/$argv[0] //;
	$text =~ s/ /\+/g;

	my $url = "http://translate.google.com/?hl=en&tl=".uri_escape($argv[0])."&text=".uri_escape($text);
	$Auto::http->request(
		url => $url,
		on_response => sub {
			my $response = shift;
			if (!$response->is_success) {
				privmsg($src->{svr}, $src->{chan}, "An error occured while retrieving the data.");
				return;
			}
			my $content = $response->content;
			$content =~ s/<span title="(.+?)" onmouseover="this\.style\.backgroundColor='#ebeff9'" onmouseout="this\.style\.backgroundColor='#fff'">//g;
			$content =~ s/<\/span>//g;
			if($content =~ /<span id=result_box class="long_text">(.+?)<\/div><\/div><div id=spell-place-holder style="display:none"><\/div><div id=gt-res-tools>/) {
				my $var = $1;
				$var =~ s/&quot;/"/g;
				$var =~ s/ \+//g;
				$var =~ s/\+/ /g;
				$text =~ s/\+/ /g;
				privmsg($src->{svr}, $src->{chan}, "'\2".$text."\2' translated into '\2".$argv[0]."\2' gave: '\2".$var."\2'");
			} elsif($content =~ /<span id=result_box class="short_text">(.+?)<\/div><\/div><div id=spell-place-holder style="display:none"><\/div><div id=gt-res-tools>/) {
				my $var = $1;
				$var =~ s/&quot;/"/g;
				$var =~ s/ \+//g;
				$var =~ s/\+/ /g;
				$text =~ s/\+/ /g;
				privmsg($src->{svr}, $src->{chan}, "'\2".$text."\2' translated into '\2".$argv[0]."\2' gave: '\2".$var."\2'");
			}
		},
		on_error => sub {
			privmsg($src->{svr}, $src->{chan}, "An error occured while retrieving the data.");
			return;
		}
	);
}

# Start initialization.
API::Std::mod_init('Translate', '[NAS]peter', '1.01', '3.0.0a11');
# build: perl=5.010000

__END__

=head1 NAME

Translate - This module will translate a given text.

=head1 VERSION

 1.01
 
=head1 SYNOPSIS

 <~[nas]peter> ^tr en Hoe gaat het ermee?
 <&StatsBot> 'Hoe gaat het ermee?' translated into 'en' gave: 'How is the it?'
 

=head1 DESCRIPTION

This module will add a translate function, that uses google translate.

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
