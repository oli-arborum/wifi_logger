#!/usr/bin/perl -w

use Data::Dumper;
use MLDBM qw(DB_File);
use Time::localtime;

$db_filename = 'networks.db';
$log_filename = 'networks_history.log';

# scan all available wifi networks
$iwlist = `iwlist scan 2> /dev/null`;

# open or create log file
open( LOG, ">> $log_filename" ) or die $!;

# open or create file to store last state
tie %all_networks, 'MLDBM', $db_filename
  or die "could not tie to $db_filename: $!";

# copy old state
%old_networks = %all_networks;

#print Dumper( \%all_networks );

# reset FOUND flag for each network
foreach $macaddr (keys %all_networks) {
  $data = $all_networks{ $macaddr };
  $data->{FOUND} = 0;
  $all_networks{ $macaddr } = $data;
}

#print Dumper( \%all_networks );

# generate timestamp string
$tm = localtime;
$timestamp = sprintf( "[%04d-%02d-%02d %02d:%02d:%02d]",
  $tm->year+1900, $tm->mon+1, $tm->mday,
  $tm->hour, $tm->min, $tm->sec );

# remember and undef line separator
# to enable multi-line regexp
$sepsave = $/;
undef $/;

# update current state of all networks
$_ = $iwlist;
while (/Address: (.+)\n.+?ESSID:"(.+)"(\n.+?){3}\(Channel (\d+)\)(\n.+?)+?Quality=(\d+)\/.+?Signal level=(\d+)\//g) {
  $ssid = $2;
  $ssid =~ s/([\";])/\\$1/g;
  print LOG "$timestamp $1; $4; $6; $7; $ssid\n";
  $data = {
    MACADDR => $1,
    SSID => $2,
    CHANNEL => $4,
    QUALITY => $6,
    SIGNALLEVEL => $7,
    FOUND => 1
  };
  # add or update entry in db
  $all_networks{ $data->{MACADDR} } = $data;
}

# restore line separator
$/ = $sepsave;

# print Dumper( \%all_networks );

# remove all networks that were not found from %all_networks
foreach $macaddr (keys %all_networks) {
  delete $all_networks{ $macaddr }
    unless $all_networks{ $macaddr }->{FOUND} == 1;
}

# print Dumper( \%all_networks );

# check for new networks
foreach (keys %all_networks) {
  print "$timestamp new network: " . $all_networks{$_}->{SSID} . " (" . $all_networks{$_}->{MACADDR} . ")" . "\n"
    unless exists $old_networks{$_};
}

# check for "lost" networks
foreach (keys %old_networks) {
  print "$timestamp lost network: " . $old_networks{$_}->{SSID} . " (" . $old_networks{$_}->{MACADDR} . ")" . "\n"
    unless exists $all_networks{$_};
}

# check for changed channel
foreach (keys %all_networks) {
  if( exists $old_networks{$_} ) {
    if( $old_networks{$_}->{CHANNEL} != $all_networks{$_}->{CHANNEL} ) {
      print "$timestamp channel changed: " . $all_networks{$_}->{SSID} . " (" . $all_networks{$_}->{MACADDR} . "): " . $old_networks{$_}->{CHANNEL} . " -> " . $all_networks{$_}->{CHANNEL} . "\n"
    }
  }
}

# print Dumper( \%all_networks );
# print Dumper( \%old_networks );

untie %all_networks;
close LOG;

