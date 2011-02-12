#!/usr/bin/perl
# Cpanel bulk dns zone NS & SOA editor
# by Branko Toic <branko@toic.org>
# Script requires installed DNS::ZoneParse perl module
# You can get it here: http://search.cpan.org/~mschilli/DNS-ZoneParse/lib/DNS/ZoneParse.pm

# define new ns1 ns2 and soa contact
$ns1 = "ns1.domain.com.";
$ns2 = "ns2.domain.com.";
$contact = "mail.domain.com.";

#Do not edit from here

sub usage{
print "Usage: fixnsentires <list>\n";
print "Just provide list of dns zones to fix, one per line in file\n";
exit(1);
}

use IO::File;
use DNS::ZoneParse;
use Term::ANSIColor;

sub fixns {
$zonelist = $ARGV[0];

	if(!$zonelist){
	usage();
	}
	
	open(ZONELIST, $zonelist) || \&Terminate(" cannot read $zonelist\n");
		DOMAIN: foreach (<ZONELIST>){
			next DOMAIN if /(^#|^$|^\s)/;   # ignore comments, nulls, start with space/tab
			next DOMAIN if /\s(HOLD|DISCARD|WARN|LOCAL)/; # skip local tags
			@line = split(/\s/, $_);        # strip comments/tags
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
                	$domain = $_;
                	$zonefile = "/home/branko/radni/seljenje/ebit/var/named/$domain.db";
                		if (-e $zonefile){
					$z = DNS::ZoneParse->new($zonefile, $domain);
					$ns = $z->ns;
					$soa = $z->soa;
					$_->{host} = $ns1 for (@$ns[0]);
					$_->{host} = $ns2 for (@$ns[1]);
					$_->{primary} = $ns1 for ($soa);
					$_->{email} = $contact for ($soa);
					$z->new_serial();	
					$zf = new IO::File "$zonefile", "w" or die "error writing zonefile";
					print $zf $z->output();
					print "Zonfile $zonefile is updated with new NS and SOA records\n Syncing it with the rest of the cluster\n";
	                        	#system("/scripts/dnscluster synczone $domain");
	                        	printf "%s: Zonefile $zonefile synced\n", colored('SUCCESS','green');
					}
					else{
					printf "%s: zonefile $zonefile not present on this server\n", colored('REJECT','red');			
				}
		}	
}

fixns();
