#!/usr/bin/perl -w

# Walk through the records in a file, substitute iffy chars in all subfields

use MARC::File::USMARC;
use MARC::Record;
use MARC::Field;
use strict;
use warnings;
# use utf8;
binmode STDOUT, ":utf8";

my $filename = '/home/magnus/Dropbox/kunder/munkagard/import/2forsok/export2-ansel-ansi-2709-ejLinje-rettet';

my $count = 0;

my $file = MARC::File::USMARC->in( $filename );
while ( my $rec = $file->next() ) {
  
  foreach my $field ($rec->fields()) {

    if ($field->is_control_field()) {

      analyze_data($field->data());

    } else {

      my @subfields = $field->subfields();
      if ($subfields[0]) {
        while (my $subfield = pop(@subfields)) {
          my ($code, $data) = @$subfield;
          analyze_data($data);
        } 
      } 

    }

  }
  $count++;  
}

sub analyze_data {

  my $lookfor = 169;
  my $found = 0;

  my $data = shift;

  my $out = $data . " => ";
  while ($data =~ m/(.)/g) {
    if (ord($1) == $lookfor) {
      $found = 1;
      $out .= "**";
    }
    $out .= "$1:" . ord($1) . "|";
  }
  $out .= "\n";

  if ($found == 1) {
  # Use like this to look for lines that contain e.g. "oravsk":
  # if ($found == 1 || $data =~ m/oravsk/i) {
    print $out;
  }

}
