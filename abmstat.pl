#!/usr/bin/perl -w

use strict;
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/kohalib.pl" };
}
use C4::Context;
use Template;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

# Configure the Template Toolkit
my $config = {
    INCLUDE_PATH => 'tt2',  # or list ref
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 0,               # cleanup whitespace 
};
# create Template object
my $tt2 = Template->new($config) || die Template->error(), "\n";

# Get command line options
my ($homebranch, $year, $outfile, $verbose) = get_options();

if ($verbose) {
	print "This is abmstat.pl, running in verbose mode.\n";
	print "Getting data for branch $homebranch.\n";
}

# Get database connection
my $dbh   = C4::Context->dbh;

# Config
my @itemtypes = ({
	name       => 'Bøker og periodika (antall bind)',
	itypes     => ["BOK", "LRM"],
	holdings   => 0,
	holdings_n => '007',
	added      => 0,
	added_n    => '008',
	deleted    => 0, 
	deleted_n  => '009'
}, 	{
	name       => 'AV-dokumenter',
	itypes     => ["DVD", "LBOK", "VID"],
	holdings   => 0,
	holdings_n => '023',
	added      => 0,
	added_n    => '024',
	deleted    => 0, 
	deleted_n  => '025'
},	{
	name       => 'Annet bibliotekmateriale',
	itypes     => ["X"],
	holdings   => 0,
	holdings_n => '035',
	added      => 0,
	added_n    => '036',
	deleted    => 0, 
	deleted_n  => '037'
}, 	{
	name       => 'Andre digitale dokumenter',
	itypes     => ["DIG"],
	holdings   => 0,
	holdings_n => '047',
	added      => 0,
	added_n    => '048',
	deleted    => 0, 
	deleted_n  => '049'
});

my $count = scalar(@itemtypes);

for (my $i=0; $i < $count; $i++) {

	# Holdings
        # FIXME This actually gives us the status of holdings right now, not at the end of the given year
        # It could be done with this number minus the number of additions since the end of the given year..
	my $hold_query = "SELECT count(*)
					FROM items 
					WHERE homebranch = '" . $homebranch . "'
					AND " . orify('itype', @{$itemtypes[$i]{'itypes'}});
	my $hold_sth = $dbh->prepare($hold_query);
	$hold_sth->execute();
	my $hold_count = $hold_sth->fetchrow;
	$itemtypes[$i]{'holdings'} = $hold_count;
	
	# Additions
	my $acq_query = "SELECT count(*)
					FROM items 
					WHERE YEAR(dateaccessioned) = $year
					AND homebranch = '" . $homebranch . "'
					AND " . orify('itype', @{$itemtypes[$i]{'itypes'}});
	my $acq_sth = $dbh->prepare($acq_query);
	$acq_sth->execute();
	my $acq_count = $acq_sth->fetchrow;
	if (!$acq_count) { $acq_count = 0; }
	$itemtypes[$i]{'added'} = $acq_count;
	
	# Deletions
	my $del_query = "SELECT count(*) 
	                 FROM deleteditems
	                 WHERE YEAR(timestamp) = $year 
	                 AND homebranch = '" . $homebranch . "'
					 AND " . orify('itype', @{$itemtypes[$i]{'itypes'}});
	my $del_sth = $dbh->prepare($del_query);
	$del_sth->execute();
	my $del_count = $del_sth->fetchrow;
	if (!$del_count) { $del_count = 0; }
	$itemtypes[$i]{'deleted'} = $del_count;
	
	if ($verbose) {
		print $itemtypes[$i]{'name'}, ": $hold_count\t+$acq_count\t-$del_count\n";
	}

}

# Periodicals - TODO! 
my @peri = (
	{
	name => 'Unike titler', 
	holdings => 0, 
	holdings_n => '062', 
	added => 0, 
	added_n => '063', 
	deleted => 0, 
	deleted_n => '064'
	}, {
	name => 'Trykte', 
	holdings => 0, 
	holdings_n => '065', 
	added => 0, 
	added_n => '066', 
	deleted => 0, 
	deleted_n => '067'
	}, {
	name => 'Elektroniske', 
	holdings => 0, 
	holdings_n => '068', 
	added => 0, 
	added_n => '069', 
	deleted => 0, 
	deleted_n => '070'
	}
);

my $peri_query = "select count(*) from subscription where branchcode = '$homebranch'";
my $peri_sth = $dbh->prepare($peri_query);
$peri_sth->execute();
my $peri_count = $peri_sth->fetchrow;
if (!$peri_count) { $peri_count = 0; }
$peri[0]{'holdings'} = $peri_count;
$peri[1]{'holdings'} = $peri_count;

# Circulation
my @circ = ({
	name         => 'Originaldokumenter',
	type         => "issue",
	internal     => 0,
	internal_n   => '081',
	internal_sql => ["ELE", "KAD", "VER", "ANS", "BIB"], 
	external     => 0,
	external_n   => '082', 
	external_sql => ["EKS", "BIBLIOTEK"]
}, {
	name       => 'herav fornyelser',
	type       => "renew",
	internal   => 0,
	internal_n => '150',
	internal_sql => ["ELE", "KAD", "VER", "ANS", "BIB"], 
	external   => 0,
	external_n => '151', 
	external_sql => ["EKS", "BIBLIOTEK"]
});

my $circ_count = scalar(@circ);

for (my $i=0; $i < $circ_count; $i++) {

	$circ[$i]{'internal'} = get_value(
		"SELECT count(*) 
		FROM statistics as s, borrowers as b
		WHERE s.borrowernumber = b.borrowernumber 
		AND s.branch = '" . $homebranch . "' 
		AND type = '" . $circ[$i]{'type'} . "'
		AND YEAR(s.datetime) = $year 
		AND " . orify('b.categorycode', @{$circ[$i]{'internal_sql'}})
	);
	$circ[$i]{'external'} = get_value(
		"SELECT count(*) 
		FROM statistics as s, borrowers as b
		WHERE s.borrowernumber = b.borrowernumber 
		AND s.branch = '" . $homebranch . "' 
		AND type = '" . $circ[$i]{'type'} . "'
		AND YEAR(s.datetime) = $year 
		AND " . orify('b.categorycode', @{$circ[$i]{'external_sql'}})
	);
	
	# if ($verbose) {
	# 	print $itemtypes[$i]{'name'}, ": $hold_count\t+$acq_count\t-$del_count\n";
	# }

}

# Add the renewals to the issues - that's how they want it...
$circ[0]{'internal'} = $circ[0]{'internal'} + $circ[1]{'internal'};
$circ[0]{'external'} = $circ[0]{'external'} + $circ[1]{'external'};

# ILL
my $ill_total = get_value("SELECT count(*) 
							FROM statistics as s, borrowers as b 
							WHERE s.borrowernumber = b.borrowernumber 
							AND s.branch = 'sksk' 
							AND type = 'issue' 
							AND YEAR(s.datetime) = $year
							AND b.categorycode = 'BIBLIOTEK'");
my $ill_domestic = get_value("SELECT count(*) 
							FROM statistics as s, borrowers as b 
							WHERE s.borrowernumber = b.borrowernumber 
							AND s.branch = 'sksk' 
							AND type = 'issue' 
							AND YEAR(s.datetime) = $year
							AND b.categorycode = 'BIBLIOTEK' 
							AND (b.country = 'Norge' OR b.country = '')");

my @ill = ({
	name      => "Utsendte originaldokumenter", 
	dom_n     => '089', 
	dom_value => $ill_domestic, 
	int_n     => '090', 
	int_value => $ill_total - $ill_domestic
});

# Administrativia

my @admin = ({
 	name  => 'Totalt antall studenter og ansatte i underv.inst.',
 	n     => '003', 
 	sql   => "SELECT COUNT(*) FROM borrowers WHERE " . orify('categorycode', @{["ELE", "KAD", "VER", "ANS", "BIB"]}), 
 	value => 0
}, {
	name  => 'Antall aktive lånere i reapporteringsåret',
	n     => '006', 
	sql   => "SELECT COUNT(DISTINCT borrowernumber) FROM statistics WHERE YEAR(datetime) > $year", 
	value => 0
});

my $admin_count = scalar(@admin);
for (my $i=0; $i < $admin_count; $i++) {
	$admin[$i]{'value'} = get_value($admin[$i]{'sql'});
}
 
# Output
my $template = 'abmstat.tt2';
my $vars = {
        'year'        => $year, 
	'holdings'    => \@itemtypes,
	'periodicals' => \@peri, 
	'circ'        => \@circ,
	'admin'       => \@admin,
	'ill'         => \@ill
};
$tt2->process($template, $vars, $outfile) || die $tt2->error();
print "Go have a look at $outfile \n";

# Takes a string of SQL and returns an integer
sub get_value {
	my $sql = shift;
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	return $sth->fetchrow;	
}

# Takes the name of a column and an array of values and creates a list of ORed values: 
# In: orify('i.itype', ['DVD', 'LBOK', 'VID']);
# Out: "(i.itype = 'DVD' OR i.itype = 'LBOK' OR i.itype = 'VID')"
sub orify {
	my $column = shift;
	my @values = @_;
	my $count = 0;
	my $out = '(';
	for my $value (@values) {
		if ($count > 0) {
			$out .= " OR ";
		}
		$out .= "$column = '" . $value . "'";
		$count++; 
	}
	$out .= ')';
	return $out;
}

# Get commandline options
sub get_options {
  my $homebranch = '';
  my $year = '';
  my $outfile = '/tmp/abmstat.html';
  my $verbose = '';
  my $help = '';

  GetOptions("b|homebranch=s" => \$homebranch, 
             "y|year=i"       => \$year, 
             'o|outfile=s'    => \$outfile, 
             "v|verbose!"     => \$verbose,
             'h|?|help'       => \$help
             );
  
  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -b, --homebranch required\n", -exitval => 1) if !$homebranch;
  pod2usage( -msg => "\nMissing Argument: -y, --year required\n", -exitval => 1) if !$year;

  return ($homebranch, $year, $outfile, $verbose);
}       

__END__

=head1 NAME
    
abmstat.pl - Collect statistics for the Norwegian library authorities.
      
=head1 SYNOPSIS
            
abmstat.pl -b mybranch -y 2011
               
=head1 OPTIONS
              
=over 8

=item B<-b, --homebranch>

Restrict results to one branch. 

=item B<-y --year>

What year to get the stats for. 

=item B<-o --outfile>

File to write the results to
              
=item B<-v, --verbose>

Run in verbose mode, with extra output. 

=item B<-h, -?, --help>

Prints this help message and exits.

=back

=cut
