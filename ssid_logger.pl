#!/usr/bin/perl -w

use Data::Dumper;
use MLDBM qw(DB_File);

$db_filename = 'networks.db';

# scan all available wifi networks
$iwlist = `iwlist scan 2> /dev/null`;

# open or create file to store last state
tie %all_networks, 'MLDBM', $db_filename
  or die "could not tie to $db_filename: $!";

# copy old state
%old_networks = %all_networks;

# remember and undef line separator
# to enable multi-line regexp
$sepsave = $/;
undef $/;

# update current state of all networks
$_ = $iwlist;
while (/Address: (.+)\n.+?ESSID:"(.+)"(\n.+?){3}\(Channel (\d+)\)(\n.+?)+?Quality=(\d+)\/.+?Signal level=(\d+)\//g) {
  print "$1; $4; $6; $7; $2\n";
  $data = {
    MACADDR => $1,
    SSID => $2,
    CHANNEL => $4,
    QUALITY => $6,
    SIGNALLEVEL => $7,
  };
  # add or update entry in db
  $all_networks{ $data->{MACADDR} } = $data;
}

# restore line separator
$/ = $sepsave;

# check for new networks
foreach (keys %all_networks) {
  print "new network: " . $all_networks{$_}->{SSID} . "(" . $all_networks{$_}->{MACADDR} . ")" . "\n"
    unless exists $old_networks{$_};
}

# check for "lost" networks
foreach (keys %old_networks) {
  print "lost network: " . $old_networks{$_}->{SSID} . "(" . $old_networks{$_}->{MACADDR} . ")" . "\n"
    unless exists $all_networks{$_};
}

# check for changed channel
#foreach (keys %all_networks) {
#  if( exists $old_networks{$_} ) {
#    $data_old = $old_networks{$_};
#    $data = $all_networks{$_};
#    if( $data_old->{CHANNEL} != $data->{CHANNEL} ) {
#      print "channel changed: " . $data->{SSID} . "(" . $data->{MACADDR} . "): " . $data_old->{CHANNEL} . " -> " . $data->{CHANNEL} . "\n"
#    }
#  }
#}
foreach (keys %all_networks) {
  if( exists $old_networks{$_} ) {
    if( $old_networks{$_}->{CHANNEL} != $all_networks{$_}->{CHANNEL} ) {
      print "channel changed: " . $all_networks{$_}->{SSID} . "(" . $all_networks{$_}->{MACADDR} . "): " . $old_networks{$_}->{CHANNEL} . " -> " . $all_networks{$_}->{CHANNEL} . "\n"
    }
  }
}

# print Dumper( \%all_networks );
# print Dumper( \%old_networks );

untie %all_networks;

