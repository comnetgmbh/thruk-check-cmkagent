#
# Copyright 2018 Rika Lena Denia, comNET GmbH <rika.denia@comnetgmbh.com>
#
# This file is part of check_cmkagent.
#
# check_cmkagent is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# check_cmkagent is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with check_cmkagent.  If not, see <http://www.gnu.org/licenses/>.
#

package Thruk::Controller::CheckCmkAgent;

use strict;
use warnings;
use YAML;
use IO::File;
use IO::Dir;
use IO::Socket::INET;
use Monitoring::CheckMkAgent;

my $AGENT_DIR = '/var/lib/check_cmkagent';
my $NAGIOS_DIR = 'etc/naemon/conf.d/';

sub add_routes {
    my($self, $app, $routes) = @_;

    $routes->{'/thruk/cgi-bin/check_cmkagent.cgi'} = 'Thruk::Controller::CheckCmkAgent::index';
    $routes->{'/thruk/cgi-bin/check_cmkagent_add.cgi'} = 'Thruk::Controller::CheckCmkAgent::add';

    # add new view item
    Thruk::Utils::Menu::insert_item(
        System => {
            href => '/thruk/cgi-bin/check_cmkagent.cgi',
            name => 'check_cmkagent',
        }
    );

    return;
}

sub index {
    my $c = shift;

    my @hosts = ($c->req->parameters->{host}) // ();
    unless (@hosts) {
        @hosts = Monitoring::CheckMkAgent::list;
    }

    $c->stash->{hosts} = [ map({ Monitoring::CheckMkAgent->new(host => $_) } @hosts) ];
    $c->stash->{template} = 'check_cmkagent.tt';
}

sub add {
    my $c = shift;

    # Fetch arguments
    my $host = $c->req->parameters->{host};
    my $service = $c->req->parameters->{service};
    my $warn = $c->req->parameters->{warn};
    my $crit = $c->req->parameters->{crit};

    # Validate arguments
    #return unless $host =~ /$VALID_HOST_REGEX/;
    return unless $service =~ /^[a-zA-Z0-9_]+$/;
    return unless $warn =~ /^\d+$/;
    return unless $crit =~ /^\d+$/;

    # Fetch host
    my %hosts = collect_hosts($host);
    my %service = %{%hosts->{$host}->{services}->{$service}};

    # Write service config
    my $service_cfg = "$NAGIOS_DIR/cmkagent_${host}_$service.cfg";
    my $service_fh = IO::File->new($service_cfg, 'w');
    die("Can't open $service_cfg: $!\n") unless defined $service_fh;
    print($service_fh <<EOF
define service {
	use                     generic-service
	host_name               $host
	service_description     $service{section}: $service{entity}
	check_command           check_cmkagent_passive!$service{section}!$service{entity}!$warn!$crit
}
EOF
);

    # Reload core
    for (@{$c->{db}->{backends}}) {
        Thruk::Utils::External::cmd($c, { cmd => $_->{'config'}->{'configtool'}->{'obj_reload_cmd'}." 2>&1", 'background' => 1 });
    }

    # Notify user about added service
    $c->stash->{added} = { host => $host, service => \%service };

    # Render index
    return Thruk::Controller::CheckCmkAgent::index($c);
}

=pod

=head1 NAME

thruk-check_cmkagent

The 'Check_CMKAgent' plugin allows automatically configuring Check_MK agent-based services.

=head1 DESCRIPTION

thruk-check-cmkagent allows you to easily generate Nagios-compatible
configuration files from check_cmkagent_active Check_MK agent dumps.

=head1 INSTALLATION

Just copy the files in this directory to your Thruk I<plugins-available>
directory and enable thruk-check-cmkagent.

=head1 USAGE

=head2 GENERAL

You can get an overview of every discovered host in check_cmkagent.cgi. Please
note that you'll need to run check_cmkagent_active[1] for every host you want to
manage here.
To make things easier, you can use the cmkagent-host host template. This will
add an check_cmkagent action icon to your host, allowing you to quickly skip to
your host in check_cmkagent.

=head2 GENERATING RULES

=over

=item Open check_cmkagent.cgi

=item Select the host and service you wish to monitor

=item Modify the warning and critical thresholds to suit your needs

Note: In general, these are percentages given in the range from 0 to 100.
      This is NOT always the case; please refer to check_cmkagent_local's
      documentation for details on this.

=item Click generate. Your monitoring core will be reloaded automatically to apply
   your new configuration.

=back

=head1 COPYIGHT AND LICENSING

Copyright 2018 Rika Lena Denia, comNET GmbH <rika.denia@comnetgmbh.com>

=cut

1;
