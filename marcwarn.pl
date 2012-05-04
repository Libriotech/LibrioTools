#!/usr/bin/perl -w

use MARC::File::USMARC;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Modern::Perl;
binmode STDOUT, ":utf8";

my ($input_file, $limit, $verbose, $debug) = get_options();
my $c = 0;

# Check that the file exists
if (!-e $input_file) {
  print "The file $input_file does not exist...\n";
  exit;
}

my $marcfile = MARC::File::USMARC->in($input_file);
while ( my $record = $marcfile->next() ) {

  $c++;
  
  my @warnings = $record->warnings();
  my $num_warnings = @warnings;
  print "Record $c - $num_warnings warnings\n";
  
  if ( $verbose ) { 
    foreach my $warn ( @warnings ) { 
      if ( $warn =~ m/Invalid indicator "\^" forced to blank/ ) {
        print "+";
      } else {
        print "$warn\n";
      }
    }
    print "\n";
  }
  
  print Dumper @warnings, "\n" if $debug;
  
  if ($limit && ($c == $limit)) { last; }

}

print "$c records processed\n";

sub get_options {

  # Options
  my $input_file = '';
  my $limit = '';
  my $verbose = '';
  my $debug = '';
  my $help = '';
  
  GetOptions (
    'i|infile=s' => \$input_file, 
    'l|limit=i'  => \$limit,
    'v|verbose'  => \$verbose, 
    'd|debug'  => \$debug, 
    'h|?|help'   => \$help
  );

  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;

  return ($input_file, $limit, $verbose, $debug);

}

__END__

=head1 NAME
    
marcwarn.pl - Read an ISO2709 file and output results from MARC::File::warnings
        
=head1 SYNOPSIS
            
./marcwarn.pl -i records.mrc 
               
=head1 OPTIONS
              
=over 4
                                                   
=item B<-i, --infile>

Name of the MARC file to be read.

=item B<-l, --limit>

Only process the n first records.

=item B<-v --verbose>

Be more verbose

=item B<-v --debug>

Dump some extra info.

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut
