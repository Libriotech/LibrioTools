#!/usr/bin/perl -w

# This needs to point to the file Charset.pm from Koha (http://koha-community.org/)
# You probably need to change this line for the script to work on your system
require "/home/magnus/scripts/kohaclone/C4/Charset.pm";

# You will also need to set the PERL5LIB environment variable to the directory on your 
# system that contains the C4 directory of Koha

use MARC::File::USMARC;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use strict;
use warnings;
binmode STDOUT, ":utf8";

my ($input_file, $limit, $encoding_filter, $verbose) = get_options();

# Check that the file exists
if (!-e $input_file) {
  print "The file $input_file does not exist...\n";
  exit;
}

# $/ = "\r\n";
my $c = 0;
my %encodings;

my $marcfile = MARC::File::USMARC->in($input_file);
while ( my $record = $marcfile->next() ) {

  $c++;

  my ($new_record, $converted_from, $errors_arrayref) = C4::Charset::MarcToUTF8Record($record, 'NORMARC');
  # $new_record = C4::Charset::SetUTF8Flag($new_record);

  # Count the conversions
  $encodings{$converted_from}++;

  if ($encoding_filter && ($encoding_filter ne $converted_from)) {
    next;
  }

  if ($verbose) { 
    print $new_record->as_formatted(), "\n"; 
    if ($errors_arrayref->[0]) {
      print Dumper $errors_arrayref;
    }
    print "--- $c -- From: $converted_from ----------------------------------\n"; 
  } else {
    print $new_record->as_usmarc(), "\n";
  }

  if ($limit && ($c == $limit)) { last; }

}

if ($verbose) {

  if ($encoding_filter) {
    print "Filter: $encoding_filter\n";
  }
  while ( my ($key, $value) = each(%encodings) ) {
    print "$key => $value\n";
  }

}

sub get_options {

  # Options
  my $input_file = '';
  my $limit = '';
  my $encoding_filter = '';
  my $verbose = '';
  my $help = '';
  
  GetOptions (
    'i|infile=s' => \$input_file, 
    'l|limit=i' => \$limit,
    'e|encoding_filter=s' => \$encoding_filter,  
    'v|verbose' => \$verbose, 
    'h|?|help'  => \$help
  );

  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;

  return ($input_file, $limit, $encoding_filter, $verbose);

}

__END__

=head1 NAME
    
fixchar.pl - Try to fix bad encodings
        
=head1 SYNOPSIS
            
./fixchar.pl -i records.mrc > fixed.mrc
               
=head1 OPTIONS
              
=over 4
                                                   
=item B<-i, --infile>

Name of the MARC file to be read.

=item B<-l, --limit>

Only process the n first records.

=item B<-e, --encoding_filter>

Only output records that have the given encoding, e.g. UTF-8 or MARC-8.

=item B<-v --verbose>

Print records in mnemonic form. 

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut
