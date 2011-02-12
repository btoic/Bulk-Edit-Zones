#!/usr/bin/perl

# Cpanel bulk dns zone ttl editor
# by Branko Toic <branko@toic.org>
# Script requires installed DNS::ZoneParse perl module
# You can get it here: http://search.cpan.org/~mschilli/DNS-ZoneParse/lib/DNS/ZoneParse.pm


use strict;
use IO::File;
use DNS::ZoneParse;
use Term::ANSIColor;

my $action = $ARGV[0];
my $zone = $ARGV[1];
my $ttl = $ARGV[2];




if ($action eq "zone"){
fixzone($zone,$ttl);
} elsif ($action eq "list"){
fixlist($zone,$ttl);
} else {
usage();
}
exit(0);

sub usage {

print "Usage:editzonettl <action> <zone|file> <ttl>\n";
print "Actions:\n";
print "		zone <zone> <ttl> - edits single zone ttl times.\n";
print "		After editing it sync that zone with rest of cpanel dns cluster\n\n";
print "		list <file> <ttl> - edits list of zones defined in file \n";
print "		with new ttl values. Filename should contain single FQDN \n";
print "		per line. After each edit in list script syncs that\n";
print "		dns zone with rest of the cpanel dns cluster\n";
exit(1);
}

sub fixzone {
my ($zone) = $_[0];
if ($_[1] =~ /\D/){ 
print "\n\t\t!!! ERROR: Ttl is not a number !!!\n\n";
usage();
}

my ($ttl) = $_[1];
my ($zonefile) = "/var/named/$zone.db";

if(!$zone || !$ttl){
usage();
}

if (-e $zonefile){

	my $z = DNS::ZoneParse->new($zonefile, $zone);
	my $ns = $z->ns;
	$_->{ttl} = $ttl for (@$ns);
	my $mx = $z->mx;
	$_->{ttl} = $ttl for (@$mx);
	my $a = $z->a;
	$_->{ttl} = $ttl for (@$a);
	my $cname = $z->cname;
	$_->{ttl} = $ttl for (@$cname);
	my $soa = $z->soa;
	$_->{ttl} = $ttl for ($soa);
	$z->new_serial();

	my $zf = new IO::File "$zonefile", "w"
		or die "error writing zonefile: $!";
	print $zf $z->output();
			print "Zonfile $zonefile is updated with ttl $ttl\n Syncing it with the rest of the cluster\n";
			system("/scripts/dnscluster synczone $zone"); 
			printf "%s: Zonefile $zonefile synced\n", colored('SUCCESS','green');
	}else{
	print "Zonefile $zonefile not present on this server\n";
	}
}



sub fixlist {
my ($zonelist) = $_[0];
if ($_[1] =~ /\D/){ 
print "\n\t\t!!! ERROR: Ttl is not a number !!!\n\n";
usage();
}
my ($ttl) = $_[1];

if(!$zonelist || !$ttl){
usage();
}

open(ZONELIST, $zonelist) || \&Terminate ("	Cannot read $zonelist\n");
	DOMAIN: foreach (<ZONELIST>) {

		#### parse source file ####
		next DOMAIN if /(^#|^$|^\s)/;   # ignore comments, nulls, start with space/tab
		next DOMAIN if /\s(HOLD|DISCARD|WARN|LOCAL)/; # skip local tags
		my @line = split(/\s/, $_);        # strip comments/tags
		tr/A-Z/a-z/;                    # to lower case
		$_ = $line[0];
		chomp;
		s/^\.+//;                       # strip leading dots
		s/\.+$//;                       # and trailing dots

		#### validate FQDN syntax ####
		if ( /[^a-z0-9-\.]/ || /\.-/ || /-\./ || /---/ || /\.\./ || /^-/ || /-$/ ) {
			#### illegal chars, sequential dots/dashes, leading/trailing dashes
			print "REJECT:  $_  is not a valid host or domain name.\n";
			next DOMAIN
		}
		
		my $domain = $_;
		my ($zonefile) = "/var/named/$domain.db";

		if (-e $zonefile){

			my $z = DNS::ZoneParse->new($zonefile, $domain);
			my $ns = $z->ns;
			$_->{ttl} = $ttl for (@$ns);
			my $mx = $z->mx;
			$_->{ttl} = $ttl for (@$mx);
			my $a = $z->a;
			$_->{ttl} = $ttl for (@$a);
			my $cname = $z->cname;
			$_->{ttl} = $ttl for (@$cname);
			my $soa = $z->soa;
			$_->{ttl} = $ttl for ($soa);
			$z->new_serial();

			my $zf = new IO::File "$zonefile", "w"
				or die "error writing zonefile: $!";
			print $zf $z->output();
			print "------------------------------------------------------------------------------------------------\n";
			print "Zonfile $zonefile is updated with ttl $ttl\n Syncing it with the rest of the cluster\n";
			#system("/scripts/dnscluster synczone $domain");
			sleep(1);
			printf "%s: Zonefile $zonefile synced\n", colored('SUCCESS','green');
			}else{
			printf "%s: Zonefile $zonefile not present on this server\n", colored('REJECT','red');
			}
	
	
	}

}
