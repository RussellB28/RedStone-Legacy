# Module: YouTube. See below for documentation.
# Copyright (C) 2012 [NAS]peter, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::YouTube;
use strict;
use warnings;
use Furl;
use URI::Escape;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg);

# Initialization subroutine.
sub _init {
	cmd_add('youtube', 0, 0, \%M::YouTube::HELP_YOUTUBE, \&M::YouTube::cmd_spell) or return;
	# Success.
    return 1;
}

# Void subroutine.
sub _void {
	cmd_del('youtube') or return;
	
    # Success.
    return 1;
}

our %HELP_SPELL = (
    en => "",
	#nl => "",
);

sub cmd_spell {
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
	my $msg = join(' ',@argv);
	my $url = 'http://www.youtube.com/results?search_query='.uri_escape($msg);
	my $response = $ua->get($url);
	if ($response->is_success) {
		my $content = $response->content;
		$content =~ s/\n//g;
		my ($lol1,$lol2);
		$content =~ s/    //g;
		$content =~ s/  //g;
		
		$content =~ s/(.*)<\/div><div class="result-item-main-content"><h3 dir="ltr"><a href="\/redirect\?q=(.+?)" title="" class="yt-uix-tile-link">//;
		$content =~ s/<\/span><\/p><p class="facets"><span class="ads-by" dir="ltr">(.+?) <a href="\/user\/(.+?)">(.+?)<\/a><\/span>(.*)//;
		$content =~ s/<\/a><\/h3><p class="search-ad-description"><span dir="ltr">/------/;
		
		if($content =~ /(.*)------(.*)/) {
			my $lol1 = $1;
			my $lol2 = $2;
			privmsg($src->{svr},$src->{chan},"\x0307\2Title\2: ".$lol1."\x0305 \2Description\2: ".$lol2."");
		}
	} else {
		privmsg($src->{svr}, $src->{chan}, "An error occurred while retrieving the spelling.");
		return;
	}
}

# Start initialization.
API::Std::mod_init('YouTube', '[NAS]peter', '1.00', '3.0.0a11');
# build: perl=5.010000 cpan=Furl

__END__

=head1 NAME

Spell - IRC interface to check the spelling of certain words

=head1 VERSION

 1.00
 
=head1 SYNOPSIS

 <~[nas]peter> ^spell sxy
 <&StatsBot> sxy is spelled incorrectly.
 <&StatsBot> Suggestions: sexy, Sky, sky, Say, Sly, say, sly, soy, spy, sty, Sax, sax, sex, six, shy.

=head1 DESCRIPTION

This creates several ShoutCast specific commands, that can check the spelling of a single word.

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
