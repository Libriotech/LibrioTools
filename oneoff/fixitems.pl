#!/usr/bin/perl

use strict;
use  C4::Context;
use C4::Items;
use C4::Biblio;

my $dbh=C4::Context->dbh;

my $rqbiblios=$dbh->prepare("SELECT biblionumber from biblioitems");
$rqbiblios->execute;
$|=1;
my $counter = 0;
while (my ($biblionumber)= $rqbiblios->fetchrow_array){

    my $record=GetMarcBiblio($biblionumber);
	
	# Only looking for 942$a = skskb
	if ($record->field('942') && $record->field('942')->subfield('a') && $record->field('942')->subfield('a') ne 'skskb') {
		next;	
	} 
	
	$counter++;
	print "$counter $biblionumber\n";
	
	# Loop through the items
    foreach my $field952 ($record->field('952')) {
    	
    	my $barcode = $field952->subfield('p');
    	my $itemnumber = GetItemnumberFromBarcode($barcode);
	    print "\t$barcode - $itemnumber\n";
	    
   		# Change 952$c from IKT to BOKL
		$field952->update(c => 'BOKL');
		
		# Add 952$y = LRM
		$field952->add_subfields('y' => 'LRM');
	    
    }
    
	# eval{ModItemFromMarc($record,$biblionumber,$itemfield->subfield('9'));};
	# if ($@){
	# 	warn "$biblionumber : $@";
	# 	warn $record->as_formatted;
	# }    

}