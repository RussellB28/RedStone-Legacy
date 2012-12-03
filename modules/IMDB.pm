# Module: IMDB. See below for documentation.
# Copyright (C) 2012 [NAS]peter, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package M::IMDB;
use strict;
use warnings;
use API::Std qw(cmd_add cmd_del trans);
use API::IRC qw(privmsg);
use API::Log qw(slog dbug alog);

# Initialization subroutine.
sub _init {
	cmd_add('IMDB', 0, 0, \%M::IMDB::HELP_IMDB, \&M::IMDB::cmd_imdb) or return;
	# Success.
    return 1;
}

# Void subroutine.
sub _void {
	cmd_del('IMDB') or return;
	
    # Success.
    return 1;
}

our %HELP_IMDB = (
    en => "Will search IMDB for the parameter given. \2Syntax:\2 IMDB <Name of function>",
);

sub cmd_imdb {
    my ($src, @argv) = @_;
	if(!defined($argv[0])) {
		privmsg($src->{svr}, $src->{chan}, trans('Too little parameters').q{.});
        return;
	}
	
	my $var = join(' ',@argv[0 .. $#argv]);;
	$var =~ s/ /+/g;
	
	my $url = 'http://www.imdb.com/find?q=.'.$var.'&s=all';
	$Auto::http->request(
        url => $url,
        on_response => sub {
            my $response = shift;
        	if ($response->is_success) {
	        	my $content = $response->decoded_content;
	        	$content =~ s/\n//g;
	        	#<div class="findSection"><h3 class="findSectionHeader"><a name="tt"></a>Titles</h3><table class="findList"><tr class="findResult odd"> <td class="primary_photo"> <a href="/title/tt0081723/?ref_=fn_al_tt_1" ><img src="http://ia.media-imdb.com/images/G/01/imdb/images/nopicture/32x44/film-3119741174._V398911809_.png" height="44" width="32" /></a> </td> <td class="result_text"> <a href="/title/tt0081723/?ref_=fn_al_tt_1" >Violer er blå</a> (1975) </td> </tr><tr class="findResult even"> <td class="primary_photo"> <a href="/title/tt0106443/?ref_=fn_al_tt_2" ><img src="http://ia.media-imdb.com/images/M/MV5BMTQzODc3ODY2N15BMl5BanBnXkFtZTcwMDU2NDU4MQ@@._V1_SX32_CR0,0,32,44_.jpg" height="44" width="32" /></a> </td> <td class="result_text"> <a href="/title/tt0106443/?ref_=fn_al_tt_2" >De blå ulvene</a> (1993) </td> </tr><tr class="findResult odd"> <td class="primary_photo"> <a href="/title/tt0290475/?ref_=fn_al_tt_3" ><img src="http://ia.media-imdb.com/images/G/01/imdb/images/nopicture/32x44/film-3119741174._V398911809_.png" height="44" width="32" /></a> </td> <td class="result_text"> <a href="/title/tt0290475/?ref_=fn_al_tt_3" >Blå måndag</a> (2001) (Video) </td> </tr><tr class="findResult even"> <td class="primary_photo"> <a href="/title/tt0042902/?ref_=fn_al_tt_4" ><img src="http://ia.media-imdb.com/images/G/01/imdb/images/nopicture/32x44/film-3119741174._V398911809_.png" height="44" width="32" /></a> </td> <td class="result_text"> <a href="/title/tt0042902/?ref_=fn_al_tt_4" >Le roi du bla bla bla</a> (1951) </td> </tr><tr class="findResult odd"> <td class="primary_photo"> <a href="/title/tt2396624/?ref_=fn_al_tt_5" ><img src="http://ia.media-imdb.com/images/G/01/imdb/images/nopicture/32x44/film-3119741174._V398911809_.png" height="44" width="32" /></a> </td> <td class="result_text"> <a href="/title/tt2396624/?ref_=fn_al_tt_5" >Rune Klan - Det Blå Show</a> (2011) </td> </tr><tr class="findResult even"> <td class="primary_photo"> <a href="/title/tt0220284/?ref_=fn_al_tt_6" ><img src="http://ia.media-imdb.com/images/G/01/imdb/images/nopicture/32x44/film-3119741174._V398911809_.png" height="44" width="32" /></a> </td> <td class="result_text"> <a href="/title/tt0220284/?ref_=fn_al_tt_6" >Ärliga blå ögon</a> (1977) (TV Mini-Series) </td> </tr><tr class="findResult odd"> <td class="primary_photo"> <a href="/title/tt0274387/?ref_=fn_al_tt_7" ><img src="http://ia.media-imdb.com/images/G/01/imdb/images/nopicture/32x44/film-3119741174._V398911809_.png" height="44" width="32" /></a> </td> <td class="result_text"> <a href="/title/tt0274387/?ref_=fn_al_tt_7" >Det blå billede</a> (1967) </td> </tr><tr class="findResult even"> <td class="primary_photo"> <a href="/title/tt0389581/?ref_=fn_al_tt_8" ><img src="http://ia.media-imdb.com/images/G/01/imdb/images/nopicture/32x44/film-3119741174._V398911809_.png" height="44" width="32" /></a> </td> <td class="result_text"> <a href="/title/tt0389581/?ref_=fn_al_tt_8" >Blå gatan</a> (1966) (TV Mini-Series) </td> </tr><tr class="findResult odd"> <td class="primary_photo"> <a href="/title/tt0822421/?ref_=fn_al_tt_9" ><img src="http://ia.media-imdb.com/images/G/01/imdb/images/nopicture/32x44/film-3119741174._V398911809_.png" height="44" width="32" /></a> </td> <td class="result_text"> <a href="/title/tt0822421/?ref_=fn_al_tt_9" >Blå Barracuda</a> (2003) (TV Series) </td> </tr><tr class="findResult even"> <td class="primary_photo"> <a href="/title/tt0418213/?ref_=fn_al_tt_10" ><img src="http://ia.media-imdb.com/images/G/01/imdb/images/nopicture/32x44/film-3119741174._V398911809_.png" height="44" width="32" /></a> </td> <td class="result_text"> <a href="/title/tt0418213/?ref_=fn_al_tt_10" >Så kom de blå baretter</a> (2000) (TV Movie) </td> </tr></table>
				my $titles = $content;
				if($titles =~ /<h3 class="findSectionHeader"><a name="tt"><\/a>Titles<\/h3>/i) {
					$titles =~ s/Exact title matches<\/a><\/div>(.*)//g;
					$titles =~ s/(.*)<div class="findSection"><h3 class="findSectionHeader"><a name="tt"><\/a>Titles<\/h3><table class="findList"><tr class="findResult odd"> //g;
					$titles =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
					$titles =~ s/View:&nbsp; More title matches(.*)//;
					while($titles =~ /  /) {
						$titles =~ s/  /---/g;
					}
					while($titles =~ /------/) {
						$titles =~ s/------/---/g;
					}
					my $i = 0;
					my $tvar = "";
					while($titles =~ /(.+?)---/ && $i<5) {
						if($tvar eq "") {
							$tvar = $1;
							$i++;
							$titles =~ s/(.+?)---//;
						} else {
							$tvar .= ", ".$1;
							$i++;
							$titles =~ s/(.+?)---//;
						}
					}
					$tvar =~ s/---//g;
					privmsg($src->{svr},$src->{target},"\002Titles:\002 ".$tvar);
				}
				my $names = $content;
				if($names =~ /<h3 class="findSectionHeader"><a name="nm"><\/a>Names<\/h3>/i) {
					$names =~ s/Exact name matches<\/a><\/div>(.*)//g;
					$names =~ s/(.*)<div class="findSection"><h3 class="findSectionHeader"><a name="nm"><\/a>Names<\/h3><table class="findList"><tr class="findResult odd"> //g;
					$names =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
					$names =~ s/View:&nbsp; More name matches(.*)//;
					while($names =~ /  /) {
						$names =~ s/  /---/g;
					}
					while($names =~ /------/) {
						$names =~ s/------/---/g;
					}
					my $i = 0;
					my $tvar = "";
					while($names =~ /(.+?)---/ && $i<5) {
						if($tvar eq "") {
							$tvar = $1;
							$i++;
							$names =~ s/(.+?)---//;
						} else {
							$tvar .= ", ".$1;
							$i++;
							$names =~ s/(.+?)---//;
						}
					}
					$tvar =~ s/---//g;
					privmsg($src->{svr},$src->{target},"\002Names:\002 ".$tvar);
				}
				my $keywords = $content;
				if($keywords =~ /<h3 class="findSectionHeader"><a name="kw"><\/a>Keywords<\/h3>/i) {
					$keywords =~ s/Exact keyword matches<\/a><\/div>(.*)//g;
					$keywords =~ s/(.*)<\/div><\/div><div class="findSection"><h3 class="findSectionHeader"><a name="kw"><\/a>Keywords<\/h3><table class="findList"><tr class="findResult odd"> //g;
					$keywords =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
					$keywords =~ s/View:&nbsp; More keyword matches(.*)//;
					while($keywords =~ /  /) {
						$keywords =~ s/  /---/g;
					}
					while($keywords =~ /------/) {
						$keywords =~ s/------/---/g;
					}
					my $i = 0;
					my $tvar = "";
					while($keywords =~ /(.+?)---/ && $i<5) {
						if($tvar eq "") {
							$tvar = $1;
							$i++;
							$keywords =~ s/(.+?)---//;
						} else {
							$tvar .= ", ".$1;
							$i++;
							$keywords =~ s/(.+?)---//;
						}
					}
					$tvar =~ s/---//g;
					privmsg($src->{svr},$src->{target},"\002Keywords:\002 ".$tvar);
				}
				my $characters = $content;
				if($characters =~ /<h3 class="findSectionHeader"><a name="ch"><\/a>Characters<\/h3>/i) {
					$characters =~ s/Exact character matches<\/a><\/div>(.*)//g;
					$characters =~ s/(.*)<\/div><\/div><div class="findSection"><h3 class="findSectionHeader"><a name="ch"><\/a>Characters<\/h3><table class="findList"><tr class="findResult odd"> //g;
					$characters =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
					$characters =~ s/View:&nbsp; More character matches(.*)//;
					while($characters =~ /  /) {
						$characters =~ s/  /---/g;
					}
					while($characters =~ /------/) {
						$characters =~ s/------/---/g;
					}
					my $i = 0;
					my $tvar = "";
					while($characters =~ /(.+?)---/ && $i<5) {
						if($tvar eq "") {
							$tvar = $1;
							$i++;
							$characters =~ s/(.+?)---//;
						} else {
							$tvar .= ", ".$1;
							$i++;
							$characters =~ s/(.+?)---//;
						}
					}
					$tvar =~ s/---//g;
					privmsg($src->{svr},$src->{target},"\002Characters:\002 ".$tvar);
				}
				my $companies = $content;
				if($companies =~ /<h3 class="findSectionHeader"><a name="co"><\/a>Companies<\/h3>/i) {
					$companies =~ s/Exact company matches<\/a><\/div>(.*)//g;
					$companies =~ s/(.*)<\/div><\/div><div class="findSection"><h3 class="findSectionHeader"><a name="co"><\/a>Companies<\/h3><table class="findList"><tr class="findResult odd"> //g;
					$companies =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
					$companies =~ s/View:&nbsp; More company matches(.*)//;
					while($companies =~ /  /) {
						$companies =~ s/  /---/g;
					}
					while($companies =~ /------/) {
						$companies =~ s/------/---/g;
					}
					my $i = 0;
					my $tvar = "";
					while($companies =~ /(.+?)---/ && $i<5) {
						if($tvar eq "") {
							$tvar = $1;
							$i++;
							$companies =~ s/(.+?)---//;
						} else {
							$tvar .= ", ".$1;
							$i++;
							$companies =~ s/(.+?)---//;
						}
					}
					$tvar =~ s/---//g;
					privmsg($src->{svr},$src->{target},"\002Companies:\002 ".$tvar);
				}
        	} else {
        		privmsg($src->{svr}, $src->{target}, "An error occurred during the search.");
	        	return;
        	}
        },
        on_error => sub {
            my $error = shift;
            privmsg($src->{svr}, $src->{target}, "An error occurred during the search: $error");
        }
    );
    return 1;
}

# Start initialization.
API::Std::mod_init('IMDB', '[NAS]peter', '1.0', '3.0.0a11');
# build: perl=5.010000 cpan=

__END__

=head1 NAME

Spell - IRC interface to check for PHP functions

=head1 VERSION

 1.01
 
=head1 SYNOPSIS

 <Peter>   @php convert_uuencode
 <SomeBot> Function: convert_uuencode
 <SomeBot> Syntax: string convert_uuencode ( string $data ) convert_uuencode() encodes a string using the uuencode algorithm. Uuencode translates all strings (including binary&#039;s ones) 
 <SomeBot> Description: into printable characters, making them safe for network transmissions. Uuencoded data is about 35% larger than the original.  
 <SomeBot> URL: http://php.net/manual/en/function.convert-uuencode.php 

=head1 DESCRIPTION

This allows people to look up PHP functions

=head1 CONFIGURATION

No configurable options.

=head1 DEPENDENCIES

This module depends on the following CPAN modules:

=over

=back

=head1 AUTHOR

This module was written by [NAS]peter

=head1 LICENSE AND COPYRIGHT

This module is Copyright 2012 [NAS]peter.

Released under the same licensing terms as Auto itself.

=cut

# vim: set ai et sw=4 ts=4: