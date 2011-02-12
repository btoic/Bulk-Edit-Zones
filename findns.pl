#!/usr/bin/perl
# Cpanel bulk dns zone NS finder
# by Branko Toic <branko@toic.org>
# Script requires installed DNS::ZoneParse perl module
# You can get it here: http://search.cpan.org/~mschilli/DNS-ZoneParse/lib/DNS/ZoneParse.pm

# define new ns1 ns2
$ns1 = "ns1.domain.com.";
$ns2 = "ns2.domain.com.";

#scripti will find all zones in list that do not match namservers listed above.


#Do not edit from here

sub usage{
print "Usage: fixnsentires <list>\n";
print "Just provide list of dns zones to fix, one per line in file\n";
exit(1);
}


	$p=0;
        $|=1;
        sub tick {
                print substr(qq{|/-\\|/-\\}, $p++, 1), "\b";
                $p=0 if ($p > 8);
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
		$counter = 0;
		%namservers = ();
		print "processing:\n";
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
                	$zonefile = "/var/named/$domain.db";
                		if (-e $zonefile){
					$z = DNS::ZoneParse->new($zonefile, $domain);
					$ns = $z->ns;
					$soa = $z->soa;
					$zns1 = $_->{host} for (@$ns[0]);
					$zns2 = $_->{host} for (@$ns[1]);
					
						if ($zns1 ne $ns1 or $zns2 ne $ns2){
							tick();
							push(@{ $nameservers{$zns1}}, $domain);
							$counter += 1;
						}
					}
		}
		print "\n";	
		for $key (keys %nameservers){
			print "----------------------------------------\n";
			printf "nameserver: %s\n", colored($key, 'red');
			for $exdomain (0 .. $#{ $nameservers{$key}}){
				print "$nameservers{$key}[$exdomain]\n";
			}
		} 
}

fixns();
