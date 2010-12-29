#!/usr/bin/perl -w

# Walk through the records in a file, substitute iffy chars in all subfields

use MARC::File::USMARC;
use MARC::Record;
use MARC::Field;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use strict;
use warnings;
# use utf8;
binmode STDOUT, ":utf8";

# Get options
my ($input_file, $field, $position, $length) = get_options();

# Check that the file exists
if (!-e $input_file) {
  print "The file $input_file does not exist...\n";
  exit;
}

my $count = 0;
my $count_found = 0;
my %codes;

my $file = MARC::File::USMARC->in( $input_file );
while ( my $rec = $file->next() ) {

  if ($rec->field($field)) {
    if ($position) {
      # print , "\n";
      $codes{substr($rec->field($field)->data(), $position, $length)}++;
    } else {
      print $rec->field($field)->data(), "\n";
    }
    $count_found++;
  }
  $count++;
  
}

if ($position) {
  while ( my ($key, $value) = each(%codes) ) {
    print "$key => $value\n";
  }
}

print "Found subfield $field in $count_found of $count records.\n";

$file->close();
undef $file;

sub get_options {

  # Options
  my $input_file = '';
  my $field = '';
  my $position = '';
  my $length = 1;
  my $help = '';
  
  GetOptions (
    'i|infile=s' => \$input_file, 
    'f|field=s' => \$field, 
    'p|position=s' => \$position,
    'l|length=i' => \$length, 
    'h|?|help'  => \$help
  );

  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;
  pod2usage( -msg => "\nMissing Argument: -f, --field required\n", -exitval => 1) if !$field;

  return ($input_file, $field, $position, $length);

}

__END__

=head1 NAME
    
codes.pl - List concents of controlfields. 
        
=head1 SYNOPSIS
            
./codes.pl -i records.mrc -f 007
               
=head1 OPTIONS
              
=over 4
                                                   
=item B<-i, --infile>

Name of the MARC file to be read.

=item B<-f, --field>

Look for the given field. 

=item B<-p, --position>

Look for the given position. 

=item B<-l, --length>

How many positions should be taken into account. Default=1.

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut
