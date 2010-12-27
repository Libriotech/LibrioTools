#!/usr/bin/perl -w

# Use this to find characters that need to be replaced. 

use strict;
use Data::Dumper;
# binmode STDOUT, ":utf8";

my $killnext = 0;
my $prevchar = "";
my %chars;

while (<>) {
  while (/(.)/g) {

    $chars{$1 . ":" . ord($1)}++;

  }
}

while ( my ($key, $value) = each(%chars) ) {
  print "$key=$value ";
}

my @suspects
