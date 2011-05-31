# lib/Feat/Accounts.pm - Accounts system.
# Copyright (C) 2010-2011 Xelhua Development Group, et al.
# This program is free software; rights to this code are stated in doc/LICENSE.
package Feat::Accounts;
use strict;
use warnings;
use API::Std qw(cmd_add hook_add);
use API::Log qw(alog slog);
our %users;



1;
# vim: set ai et sw=4 ts=4:
