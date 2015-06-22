package pf::Switch::Alcatel;

=head1 NAME

pf::Switch::Alcatel - Object oriented module to access an Alcatel switch

=head1 SYNOPSIS

The pf::Switch::Alcatel module implements an object oriented interface
to access Alcatel switches.

=head1 STATUS

Tested on Alcatel-Lucent OS 8.1.1.497.R01

=head1 SUPPORTS

=head2 802.1X and MAC-Authentication with and without VoIP

Stacked switch support has not been tested.

=head1 BUGS AND LIMITATIONS

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;
use Try::Tiny;
use base ('pf::Switch');

sub description { 'Alcatel switch' }

# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::constants;
use pf::config;
use pf::node;
use pf::util::radius qw(perform_disconnect);
use pf::accounting qw(node_accounting_current_sessionid);

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
sub supportsRoleBasedEnforcement { return $TRUE; }
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }
sub isVoIPEnabled { return $_[0]->{_VoIPEnabled} }
sub supportsRadiusVoip { return $TRUE; }
# sub supportsRadiusVoip { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

=head2 getVoipVsa

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).
For now it returns the voiceRole untagged since Alcatel supports multiple untagged VLAN in the same interface

=cut

sub getVoipVsa{
    my ($this) = @_; 
    my $logger = Log::Log4perl::get_logger( ref($this) ); 
    my $voiceRole = $this->getRoleByName('voice');
    $logger->info("Accepting phone with untagged Access-Accept on role $voiceRole");
    
    # Return the normal response except we force the voiceVlan to be sent
    return (
      'Filter-Id' => $voiceRole,
    );
 
}

=head2 deauthenticateMacRadius

Method to deauth a wired node with CoA.

=cut

sub deauthenticateMacRadius {
    my ($this, $ifIndex,$mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));


    # perform CoA
    $this->radiusDisconnect($mac);
}

=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($this) = @_;

    return 'Filter-Id';
}

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques { 
   my ($this, $method, $connection_type) = @_;
   my $logger = Log::Log4perl::get_logger( ref($this) );

    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    elsif ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        ); 
        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    else{
        $logger->error("This authentication mode is not supported");
    }

}

=head2 radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Optionally you can provide other attributes as an hashref.

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut

# TODO consider whether we should handle retries or not?

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "[$self->{'_ip'}] Unable to perform RADIUS CoA-Request: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("[$self->{'_ip'}] Deauthenticating $mac");

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $management_network->tag('vip'),
        };

        $logger->debug("[$self->{'_ip'}] Network device supports roles. Evaluating role to be returned.");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        my $node_info = node_attributes($mac);
        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/://g;
        my $acctsessionid = node_accounting_current_sessionid($mac);
        $logger->info("mac : $mac");

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $attributes_ref = {
            %$attributes_ref,
        };
        $response = perform_disconnect($connection_info, $attributes_ref);
        use Data::Dumper;
        $logger->info("Disconnect reply : ".Dumper($response));
    } catch {
        chomp;
        $logger->warn("[$self->{'_ip'}] Unable to perform RADIUS Disconnect-Request: $_");
        $logger->error("[$self->{'_ip'}] Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'Disconnect-ACK');

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

