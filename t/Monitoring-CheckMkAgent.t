#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

use_ok('Monitoring::CheckMkAgent');
is_deeply([ Monitoring::CheckMkAgent->list(store_dir => 't/dumps') ], [ qw/windows10/ ], 'list works');

#is_deeply([ Monitoring::CheckMkAgent->valid_sections ], [ qw/df mem/ ], 'valid_sections works');

use Data::Dumper;
#print(
#    Dumper(
#        Monitoring::CheckMkAgent->from_agent_output(
#            host => 'windows10',
#        )
#    )
#);

my $cmka = Monitoring::CheckMkAgent->from_agent_output(
    host => 'windows10',
);
is($cmka->host, 'windows10', 'host');
is($cmka->sections->[0]->name, 'df', 'df section');
is($cmka->sections->[1]->name, 'mem', 'mem section');

