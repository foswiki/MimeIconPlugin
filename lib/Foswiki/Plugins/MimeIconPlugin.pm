# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# MimeIconPlugin is Copyright (C) 2010-2025 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::MimeIconPlugin;

use strict;
use warnings;

=begin TML

---+ package MimeIconPlugin

=cut

use Foswiki::Func ();

our $VERSION = '4.20';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'Icon sets for mimetypes';
our $LICENSECODE = '%$LICENSECODE%';
our $NO_PREFS_IN_TOPIC = 1;
our %cache = ();

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

=cut

sub initPlugin {

  Foswiki::Func::registerTagHandler('MIMEICON', \&MIMEICON);

  Foswiki::Func::registerRESTHandler(
    'get',
    \&handleREST,
    authenticate => 0,
    validate => 0,
    http_allow => 'GET,POST',
  );

  return 1;
}

=begin TML

--++ handleREST

returns the url to a mime icon

=cut

sub handleREST {
  my ($session, $subject, $verb, $response) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $file = $query->param("file") || '';

  $file =~ s/^.*\.//;
  $file =~ s/^\s+|\s+$//g;

  my $size = $query->param("size") || '48';
  my $theme = $query->param("theme");

  $theme = $Foswiki::cfg{Plugins}{MimeIconPlugin}{Theme} || 'papirus'
    unless defined $theme;

  $size = getBestSize($theme, $size);

  my (undef, $iconPath) = getIcon($file, $theme, $size);

  $response->header(-cache_control => "max-age=" . (8 * 60 * 60));    # 8 hours in seconds
  Foswiki::Func::redirectCgiQuery($query, $iconPath);

  return "";
}

=begin TML

---++ MIMEICON

handler for the MIMEICON macro

=cut

sub MIMEICON {
  my ($session, $params) = @_;

  my $extension = lc($params->{_DEFAULT} || '');
  my $size = $params->{size} || '48';
  my $theme = $params->{theme};
  my $format = $params->{format};
  my $class = $params->{class};

  $format = "<img src='\$url' class='\$class' width='\$size' height='\$size' alt='\$name' />"
    unless defined $format;

  $theme = $Foswiki::cfg{Plugins}{MimeIconPlugin}{Theme} || 'papirus'
    unless defined $theme;

  $extension =~ s/^.*\.//;
  $extension =~ s/^\s+|\s+$//g;

  my $bestSize = getBestSize($theme, $size);
  my ($iconName, $iconPath) = getIcon($extension, $theme, $bestSize);

  $size = $cache{$theme . ':scalable'} ? $size : $bestSize;

  return "<span class='foswikiAlert'>Error: can't even find a fallback mime-icon</span>"
    unless defined $iconName;

  my @class = ();
  push @class, "foswikiIcon";
  push @class, split(/\s*,\s*/, $class) if defined $class;
  push @class, $theme;

  my $iconNameClass = $iconName;
  $iconNameClass =~ s/^(.*)\.(?:.*?)$/$1/;

  push @class, $iconNameClass;
  $class = join(" ", @class);

  # formatting result
  my $result = $format;
  $result =~ s/(%NAME%|\$name\b)/$iconName/g;
  $result =~ s/(%URL%|\$url\b)/$iconPath/g;
  $result =~ s/(%SIZE%|\$size\b)/$size/g;
  $result =~ s/\$class\b/$class/g;

  print STDERR "MimeIconPlugin - extension=$extension, icon=$iconName, iconPath=$iconPath\n"
    if $Foswiki::cfg{Plugins}{MimeIconPlugin}{Debug};

  return $result;
}

=begin TML

returns the name and path of an icon given an extension.

=cut

sub getIcon {
  my ($extension, $theme, $size, $fromFallback) = @_;

  $theme ||= $Foswiki::cfg{Plugins}{MimeIconPlugin}{Theme} || 'papirus';

  readIconMapping($theme);

  my $iconName = $cache{$theme . ':' . $extension};
  my $iconPath = $cache{$theme . ':' . $extension . ':' . $size};

  return ($iconName, $iconPath) if defined $iconName && defined $iconPath;

  unless ($iconName) {

    # even 'unknown' is unknown
    if ($extension eq 'unknown') {
      print STDERR "ERROR: no default icon when asking for $fromFallback\n";
      return;
    }

    # try 'unknown'
    return getIcon("unknown", $theme, $size, $extension);
  }

  # found mapping, now get iconPath

  # checking physical presence
  my $pubDir = $Foswiki::cfg{PubDir} . '/' . $Foswiki::cfg{SystemWebName} . '/MimeIconPlugin/' . $theme;
  my $pubPath = $Foswiki::cfg{PubUrlPath} . '/' . $Foswiki::cfg{SystemWebName} . '/MimeIconPlugin/' . $theme;

  my $iconDir = $pubDir . '/' . $size . 'x' . $size . '/' . $iconName;
  $iconPath = $pubPath . '/' . $size . 'x' . $size . '/' . $iconName;

  unless (-f $iconDir) {
    print STDERR "MimeIconPlugin - $iconName not found at $iconDir ... checking lower resolutions\n"
      if $Foswiki::cfg{Plugins}{MimeIconPlugin}{Debug};

    # fallback to lower size
    my $state = 0;
    foreach my $s (@{$cache{$theme . ':sizes'}}) {
      print STDERR "MimeIconPlugin - ... checking $s\n"
        if $Foswiki::cfg{Plugins}{MimeIconPlugin}{Debug};
      if ($state == 0) {
        next unless $s eq $size;
        $state = 1;
        next;
      }
      if ($state == 1) {
        $iconDir = $pubDir . '/' . $s . 'x' . $s . '/' . $iconName;
        $iconPath = $pubPath . '/' . $s . 'x' . $s . '/' . $iconName;
        if (-f $iconDir) {
          $state = 2;
          last;
        }
      }
    }
    if ($state < 2) {

      # no icon found
      if ($extension eq 'unknown') {
        print STDERR "ERROR: no default icon when asking for '$fromFallback'\n";
        return;
      }

      return getIcon("unknown", $theme, $size, $extension);
    }
  }

  # caching
  $extension = $fromFallback if defined $fromFallback;
  $cache{$theme . ':' . $extension . ':' . $size} = $iconPath;

  return ($iconName, $iconPath);
}

=begin TML

---++ getBestSize()

returns the closest icon size available for a theme

=cut

sub getBestSize {
  my ($theme, $size) = @_;

  readIconMapping($theme);

  if (defined $cache{$theme . ':knownsizes'}{$size}) {
    return $size;
  } else {
    my $bestSize = 16;
    foreach my $s (@{$cache{$theme . ':sizes'}}) {
      if ($size >= $s) {
        $bestSize = $s;
        last;
      }
    }
    #print STDERR "bestSize=$bestSize size=$size\n";
    return $bestSize;
  }
}

=begin TML

---++ finishPlugin()

=cut

sub finishPlugin {

  my $keep = $Foswiki::cfg{Plugins}{MimeIconPlugin}{MemoryCache};
  $keep = 1 unless defined $keep;

  undef %cache unless $keep;
}

=begin TML

---++ readIconMapping() 

=cut

sub readIconMapping {
  my ($theme) = shift;

  return if defined $cache{$theme . ':sizes'};

  print STDERR "MimeIconPlugin - readIconMapping($theme)\n"
    if $Foswiki::cfg{Plugins}{MimeIconPlugin}{Debug};

  my $mappingFile = $Foswiki::cfg{PubDir} . '/' . $Foswiki::cfg{SystemWebName} . '/MimeIconPlugin/' . $theme . '/mapping.txt';

  my $IN_FILE;
  open($IN_FILE, '<', $mappingFile) || return '';

  while (my $line = <$IN_FILE>) {
    $line =~ s/#.*$//;
    $line =~ s/^\s+|\s+$//g;
    next if $line =~ /^$/;

    if ($line =~ /^(.*?)\s*=\s*(.*?)$/) {
      my $key = $1;
      my $val = $2;

      if ($key eq 'scalable') {
        $cache{$theme . ':scalable'} = Foswiki::Func::isTrue($val);
      } elsif ($key eq 'sizes') {
        $cache{$theme . ':sizes'} = [reverse split(/\s*,\s*/, $val)];
      } else {
        $cache{$theme . ':' . $key} = $val;
      }
    }
  }
  close($IN_FILE);

  $cache{$theme . ':sizes'} = ['16'] unless defined $cache{$theme . ':sizes'};
  %{$cache{$theme . ':knownsizes'}} = map { $_ => 1 } @{$cache{$theme . ':sizes'}};
}

1;
