# lib/Auto/Attributes.pm
# Copyright (C) 2010-2012 Ethrik Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Auto::Attributes;

use warnings;
use strict;

sub import {
    my $package = caller;
    no strict 'refs';
    foreach my $name (@_[1..$#_]) {
        *{$package.q(::).$name} = sub { shift->{$name} };
    }
}

1;

# vim: set ai et sw=4 ts=4:
