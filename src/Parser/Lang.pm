# Auto IRC Bot. An advanced, lightweight and powerful IRC bot.
# Copyright (C) 2010-2011 Xelhua Development Team (doc/CREDITS)
# This program is free software; rights to this code are stated in doc/LICENSE.
use strict;
use warnings;

# Language file parser.
package Parser::Lang;


# Parser.
sub parse
{
	my ($lang) = @_;
	
	# Check that the language file exists.
	unless (-e "$Auto::Bin/../lang/$lang.alf") {
		return 0;
	}
	
	# Open, read and close the file.
	open ALF, "<$Auto::Bin/../lang/$lang.alf" or return 0;
	my @fbuf = <ALF>;
	close ALF;
	
	# Iterate the file buffer.
	foreach my $buff (@fbuf) {
		if (defined $buff) {
			# Space buffer.
			my @sbuf = split(' ', $buff);
			
			# Check for all required values.
			if (!defined $sbuf[0] or !defined $sbuf[1] or !defined $sbuf[2]) {
				# Missing a value.
				next;
			}
			
			# Make sure the first value is "msge".
			if ($sbuf[0] ne "msge") {
				# It isn't.
				next;
			}
			
			my $id = $sbuf[1];
			my $val = $sbuf[2];
			
			# If the translation is multi-word, continue to parse.
			if (defined $sbuf[3]) {
				for (my $i = 3; $i < scalar(@sbuf); $i++) {
					$val .= " ".$sbuf[$i];
				}
			}
			
			# Save to memory.
			$id =~ s/"//g;
			$val =~ s/"//g;
			$API::Std::LANGE{$id} = $val;
		}
	}
	return 1;
}


1;