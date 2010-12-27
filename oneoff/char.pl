#!/usr/bin/perl -w

# Use this to find characters that need to be replaced. 

use strict;
# binmode STDOUT, ":utf8";

my $killnext = 0;
my $prevchar = "";

while (<>) {
  while (/(.)/g) {

    if ($killnext == 1) {
      $killnext = 0;
      # next;
    }

    if (
      (ord($1) == 111 && ord($prevchar) == 232) ||
      (ord($1) == 97 && ord($prevchar) == 232) ||
      (ord($1) == 65 && ord($prevchar) == 234) ||    
      (ord($1) == 65 && ord($prevchar) == 232) || 
      (ord($1) == 101 && ord($prevchar) == 226) || 
      (ord($1) == 97 && ord($prevchar) == 226) || 
      (ord($1) == 79 && ord($prevchar) == 232) ||
      (ord($prevchar) == 178) ||
      (ord($1) == 97 && ord($prevchar) == 234)) {
        print "x|";
        # die;
        $prevchar = '';
    } else {
      print $prevchar, ord($prevchar), "|";
      $prevchar = $1;
    }

    if (ord($1) == 232) {
      # print " => ä *** ", ord('ä');
      # print "ä";
      $killnext = 1;
    } elsif (ord($1) == 234) {
      # print " => å *** ", ord('å');
      # print "å";
      $killnext = 1;
    } 
    # else {
    #   print $1;
    # }

    # print "\n";

  }
}
