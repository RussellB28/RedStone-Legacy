# lib/Auto/Logger.pm - Logger.
# Copyright (C) 2010-2014 RedStone Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Auto::Logger;

use warnings;
use strict;
use base 'Auto::EventedObject';

# create a new logger object
sub new {
    bless { }, shift;
}

sub log {
    my ($obj, $level, $message) = @_;;
    my $caller = caller 0;
    $obj->fire($level => $message, $caller);
    $obj->fire(ALL    => $message, $caller);
    return 1;
}


1;

# vim: set ai et sw=4 ts=4:
