package Thruk::Controller::CheckCmkAgent;

use strict;
use warnings;
use YAML;
use IO::File;
use IO::Dir;
use IO::Socket::INET;

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

my $AGENT_DIR = "/tmp/agent";

sub collect_hosts {
    my %hosts;

    my $dh = IO::Dir->new($AGENT_DIR);
    return unless defined $dh;

    while (my $entry = $dh->read) {
        my $path = "$AGENT_DIR/$entry";
        next unless -f $path;

        $hosts{$entry} = {
            name => $entry,
            services => { collect_host_services($path) },
        };
    }

    return %hosts;
}

sub parse_cmkagent {
    my $path = shift;
    my @sections;

    my $fh = IO::File->new($path, 'r');
    while (my $line = $fh->getline) {
        if ($line =~ /^\s*<<<([^>:]+)(?::[^>]+)?/) {
            push(@sections, { section => $1, content => [] });
        }
        elsif ($line =~ /^\s*[[]([^]]+)_(?:start|end)[]]$/) {
            $sections[-1]->{specialization} = $1;
        }
        else {
            push(@{$sections[-1]->{content}}, $line);
        }
    }

    return @sections;
}

#push(@{$section->{mountpoints}}, [split(/\s/, $line)]->[-1])
sub collect_host_services {
    my $path = shift;
    my %services;

    my @sections = parse_cmkagent($path);
    for my $section (@sections) {
        my %service = (
            %{$section},
            id => join('_', $section->{section}, ($section->{specialization} // '')),
        );
        my @services = ( \%service );

        if ($section->{section} eq 'df') {
            my $i = 0;
            @services = ();
            for my $line (@{$section->{content}}) {
                push(@services, {
                    %service,
                    content => $line,
                    entity => [split(/\s/, $line)]->[-1],
                    id => $service{id} . '_' . $i,
                });
                $i++;
            }
        }

        for (@services) {
            $services{$_->{id}} = $_;
        }
    }

    return %services;
}

sub index {
    my $c = shift;

    $c->stash->{hosts} = { collect_hosts };
    $c->stash->{template} = 'check_cmkagent.tt';
}

my $NAGIOS_DIR = '/opt/omd/sites/foobar/etc/naemon/conf.d/';
sub add {
    my $c = shift;

    my $host_name = $c->req->parameters->{host_name};
    my $service_id = $c->req->parameters->{service_id};
    my %services = collect_host_services("$AGENT_DIR/$host_name");
    my %service = %{$services{$service_id}};

    # Write host config
    my $host_cfg = "$NAGIOS_DIR/host_$host_name.cfg";
    my $host_fh = IO::File->new($host_cfg, 'w');
    die("Can't open $host_cfg: $!\n") unless defined $host_fh;
    print($host_fh <<EOF
define host {
	use             generic-host
	host_name       $host_name
	alias           Some Remote Host
	address         $host_name
}
EOF
);

    # Write service config
    my $service_cfg = "$NAGIOS_DIR/host_${host_name}_$service_id.cfg";
    my $service_fh = IO::File->new($service_cfg, 'w');
    die("Can't open $service_cfg: $!\n") unless defined $service_fh;
    print($service_fh <<EOF
define service {
	use                     generic-service
	host_name               $host_name
	service_description     $service{section}: $service{entity}
	check_command           check_cmkagent
}
EOF
);

    $c->stash->{template} = 'check_cmkagent.tt';
}

1;

