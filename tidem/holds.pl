#!/usr/bin/perl -w 

# tidem/holds.pl
# Copyright 2009 Magnus Enger Libriotech

# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

use Getopt::Long;
use Pod::Usage;
use File::Slurp;
use MARC::File::USMARC;
use Data::Dumper;
use Template;
use strict;

## get command line options
my ($marc_file, $m2, $m3, $borrowers_file, $holds_file) = get_options();

if (!-e $marc_file) {
	die "Couldn't find input file $marc_file\n";
}
if ($m2 && !-e $m2) {
	die "Couldn't find input file $m2\n";
}
if ($m3 && !-e $m3) {
	die "Couldn't find input file $m3\n";
}
if (!-e $borrowers_file) {
	die "Couldn't find input file $borrowers_file\n";
}
if (!-e $holds_file) {
	die "Couldn't find input file $holds_file\n";
}

my @out_holds;

# Get the mapping between bookid and barcode
my %books;
my $batch = MARC::File::USMARC->in($marc_file);
while (my $record = $batch->next()) {
	my @field099s = $record->field('099');
	# DEBUG my $size = @field099s;
	# DEBUG print "*** $size\n";
    foreach my $field099 (@field099s) {
    	if ($field099->subfield('a') && $field099->subfield('k')) {
	    	my $bookid = $field099->subfield('a');
	    	my $barcode = $field099->subfield('k');
	    	$books{$bookid} = $barcode;
	    	# DEBUG print "$bookid->$barcode\n";
    	}
    }
}

# There's probably a more elegant way to do this...
if ($m2) {
	# DEBUG print "m2: $m2\n";
	my $batch = MARC::File::USMARC->in($m2);
	while (my $record = $batch->next()) {
		my @field099s = $record->field('099');
	    foreach my $field099 (@field099s) {
	    	if ($field099->subfield('a') && $field099->subfield('k')) {
		    	my $bookid = $field099->subfield('a');
		    	my $barcode = $field099->subfield('k');
		    	$books{$bookid} = $barcode;
	    	}
	    }
	}
}
if ($m3) {
	# DEBUG print "m3: $m3\n";
	my $batch = MARC::File::USMARC->in($m3);
	while (my $record = $batch->next()) {
		my @field099s = $record->field('099');
		# DEBUG my $size = @field099s;
		# DEBUG print "*** $size\n";
	    foreach my $field099 (@field099s) {
	    	if ($field099->subfield('a') && $field099->subfield('k')) {
		    	my $bookid = $field099->subfield('a');
		    	my $barcode = $field099->subfield('k');
		    	$books{$bookid} = $barcode;
		    	# DEBUG print "$bookid->$barcode\n";
	    	}
	    }
	}
}

# Get the mapping between patronid and cardnumber
my @patrons = read_file($borrowers_file);
my %borrowers; 
foreach my $patron (@patrons) {
	my ($key, $value) = split(/\t/, $patron);
	$value =~ s/\n//;
	$borrowers{$key} = $value;
}

my @holds = read_file($holds_file);
foreach my $line (@holds) {
	if (substr($line, 0, 6) eq '<tr bg') {
		my %patron;
		$line =~ m|^<tr .*?>
					\s*?<td .*?>(.*?)</td> #  1 ex (eksemplarnøkkel)			
					\s*?<td .*?>(.*?)</td> #  2 title (tittelnøkkel)
					\s*?<td .*?>(.*?)</td> #  3 person (personnøkkel)
					\s*?<td .*?>(.*?)</td> #  4 reservert dato
					.*?$|gix;
		
		# bookid must be transformed to book barcode
		my $book_barcode = $books{$1} ? $books{$1} : 'undef:' . $1;
		
		# patronid must be transformed to patron barcode
		my $patron_barcode = $borrowers{$3} ? $borrowers{$3} : 'undef:' . $3;
		
		# borrowdate must be transformed to correct format
		my ($day, $month, $year) = split(/\./, $4);
		my $borrowdate = "$year-$month-$day 00:00:00 0";
		
		if ($books{$1}) {
			print "$borrowdate\t$patron_barcode\t$book_barcode\n";
		}
	}

}

### OUTPUT ###

# Configure the Template Toolkit
my $config = {
    INCLUDE_PATH => 'tt2',  # or list ref
    INTERPOLATE  => 1,      # expand "$var" in plain text
    POST_CHOMP   => 0,      # cleanup whitespace 
};
# create Template object
my $tt2 = Template->new($config) || die Template->error(), "\n";
my $template = 'holds.tt2';
my $vars = {
	'holds'  => \@out_holds, 
};
# $tt2->process($template, $vars) || die $tt2->error();

### SUBROUTINES ###

# Get commandline options
sub get_options {
	my $marc_file = '';
	my $m2 = '';
	my $m3 = '';
	my $borrowers_file = '';
	my $holds_file = '';
	my $help = '';
	
	GetOptions("m|marc=s" => \$marc_file,
	            'm2=s' => \$m2, 
	            'm3=s' => \$m3, 
				'b|borrowers=s' => \$borrowers_file, 
				'r|reserves=s' => \$holds_file, 
	           	'h|?|help'   => \$help
	           );
	
	pod2usage(-exitval => 0) if $help;
	pod2usage( -msg => "\nMissing Argument: -m, --marc required\n", -exitval => 1) if !$marc_file;
	pod2usage( -msg => "\nMissing Argument: -b, --borrowers required\n", -exitval => 1) if !$borrowers_file;
	pod2usage( -msg => "\nMissing Argument: -h, --holds required\n", -exitval => 1) if !$holds_file;
	
	return ($marc_file, $m2, $m3, $borrowers_file, $holds_file);
}       

__END__

=head1 NAME
    
tidem/holds.pl - Combine data from the MARC dump, the borrowers table and the holds exported from Tidemann, in order to create a file with current holds, based on barcodes. 
        
=head1 SYNOPSIS
            
holds.pl -m marcdump.mrc -b borrowers.csv -h holds.html > holds.txt
               
=head1 OPTIONS
              
=over 8
                                                   
=item B<-m, --marc>

The MARC dump from Tidemann, in ISO format. 

=item B<-m2, --m3>

Additional, optional MARC dumps. 

=item B<-b, --borrowers>

Data from the borrowers table, produced with SQL like: select borrowernumber, cardnumber from borrowers into outfile '/tmp/borrower_card.txt';

=item B<-r, --reserves>

Holds as exported from Tidemann, in HTML format(!).

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut