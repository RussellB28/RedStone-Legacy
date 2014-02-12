# lib/Parser/Lang.pm - Language file parser.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Parser::Lang;
use strict;
use warnings;
use API::Log qw(dbug alog);


# Parser.
sub parse {
    my ($lang) = @_;
    
    # Check that the language file exists.
    if (!-e "$Auto::bin{lng}/$lang.alf") {
        # Otherwise, use English.
        dbug "Language '$lang' not found. Using English.";
        alog "Language '$lang' not found. Using English.";
        $lang = 'en';
    }
    
    # Open, read and close the file.
    open(my $FALF, '<', "$Auto::bin{lng}/$lang.alf") or return;
    my @fbuf = <$FALF>;
    close $FALF;
    
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
# vim: set ai et sw=4 ts=4:
