# $HeadURL$
# $Revision$
# $Date$
# $Author$

=head1 NAME

Octopussy::DeviceGroup - Octopussy DeviceGroup Module

=cut

package Octopussy::DeviceGroup;

use strict;
use warnings;
use Readonly;

use List::MoreUtils qw(any uniq);

use AAT::Utils qw( ARRAY );
use AAT::XML;
use Octopussy::Device;
use Octopussy::FS;

Readonly my $FILE_DEVICEGROUPS => 'devicegroups';
Readonly my $XML_ROOT          => 'octopussy_devicegroups';

=head1 FUNCTIONS

=head2 Add($conf_dg)

Add a new Device Group

=cut

sub Add
{
  my $conf_dg = shift;
  my @dgs     = ();

  my $file = Octopussy::FS::File($FILE_DEVICEGROUPS);
  my $conf = AAT::XML::Read($file);
  if (any { $_->{dg_id} eq $conf_dg->{dg_id} } ARRAY($conf->{devicegroup}))
  {
    return ('_MSG_DEVICEGROUP_ALREADY_EXISTS');
  }
  push @{$conf->{devicegroup}}, $conf_dg;
  AAT::XML::Write($file, $conf, $XML_ROOT);

  return (undef);
}

=head2 Remove($devicegroup)

Removes devicegroup '$devicegroup'

=cut

sub Remove
{
  my $devicegroup = shift;

  my $file = Octopussy::FS::File($FILE_DEVICEGROUPS);
  my $conf = AAT::XML::Read($file);
  my @dgs =
    grep { $_->{dg_id} ne $devicegroup } ARRAY($conf->{devicegroup});
  $conf->{devicegroup} = \@dgs;
  AAT::XML::Write($file, $conf, $XML_ROOT);

  return (undef);
}

=head2 List()

Get List of Device Group

=cut

sub List
{
  my @dgs = AAT::XML::File_Array_Values(Octopussy::FS::File($FILE_DEVICEGROUPS),
    'devicegroup', 'dg_id');

  return (@dgs);
}

=head2 Configuration($devicegroup)

Get the configuration for the devicegroup '$devicegroup'

=cut

sub Configuration
{
  my $devicegroup = shift;

  my $conf = AAT::XML::Read(Octopussy::FS::File($FILE_DEVICEGROUPS));
  foreach my $dg (ARRAY($conf->{devicegroup}))
  {
    return ($dg) if ($dg->{dg_id} eq $devicegroup);
  }

  return (undef);
}

=head2 Configurations($sort)

Get the configuration for all devicegroups

=cut

sub Configurations
{
  my $sort = shift || 'dg_id';
  my (@configurations, @sorted_configurations) = ((), ());
  my @dgs = List();

  my @dc = Octopussy::Device::Configurations();
  foreach my $dg (@dgs)
  {
    my $conf = Configuration($dg);
    if ($conf->{type} eq 'dynamic')
    {
      @{$conf->{device}} = ();
      foreach my $d (@dc)
      {
        my $match = 1;
        foreach my $c (ARRAY($conf->{criteria}))
        {
          $match = 0
            if ((defined $d->{$c->{field}})
            && ($d->{$c->{field}} !~ $c->{pattern}));
        }
        push @{$conf->{device}}, $d->{name} if ($match);
      }
    }
    push @configurations, $conf;
  }
  foreach my $c (sort { $a->{$sort} cmp $b->{$sort} } @configurations)
  {
    push @sorted_configurations, $c;
  }

  return (@sorted_configurations);
}

=head2 Devices($devicegroup)

Get Devices for the devicegroup '$devicegroup'

=cut

sub Devices
{
  my $devicegroup = shift;

  my $conf    = AAT::XML::Read(Octopussy::FS::File($FILE_DEVICEGROUPS));
  my @devices = ();

  foreach my $dg (ARRAY($conf->{devicegroup}))
  {
    if ($dg->{dg_id} eq $devicegroup)
    {
      if ($dg->{type} eq 'dynamic')
      {
        my @dc = Octopussy::Device::Configurations();
        foreach my $d (@dc)
        {
          my $match     = 1;
          my @criterias = ARRAY($dg->{criteria});
          foreach my $c (@criterias)
          {
            $match = 0
              if ((defined $d->{$c->{field}})
              && ($d->{$c->{field}} !~ $c->{pattern}));
          }
          push @devices, $d->{name} if ($match);
        }
      }
      else { @devices = ARRAY($dg->{device}); }
    }
  }

  return (@devices);
}

=head2 Remove_Device($device)

Removes Device '$device' from all DeviceGroups

=cut

sub Remove_Device
{
  my $device = shift;
  my $file   = Octopussy::FS::File($FILE_DEVICEGROUPS);
  my $conf   = AAT::XML::Read($file);
  my @dgs    = ();
  foreach my $dg (ARRAY($conf->{devicegroup}))
  {
    my @devices = ();
    foreach my $d (ARRAY($dg->{device}))
    {
      push @devices, $d if ($d ne $device);
    }
    $dg->{device} = \@devices;
    push @dgs, $dg;
  }
  $conf->{devicegroup} = \@dgs;
  AAT::XML::Write($file, $conf, $XML_ROOT);

  return (scalar @dgs);
}

=head2 Services($devicegroup_name)

Get Services for the DeviceGroup '$devicegroup_name'

=cut

sub Services
{
  my $devicegroup_name = shift;
  my @services = uniq(Octopussy::Device::Services(Devices($devicegroup_name)));

  return (sort @services);
}

1;

=head1 AUTHOR

Sebastien Thebert <octo.devel@gmail.com>

=cut
