#!/usr/bin/perl
# ABSTRACT: Class for scripts
our $VERSION = 'v3.0.17';

##~ DIGEST : 1f3e86d9906839f9afbaf5177ce0dd4e
use strict;
use warnings;

package SlicerController::Class::FolderScript;

use v5.10;
use Moo;
use Carp;
use parent 'Moo::GenericRoleClass::CLI'; #provides  CLI, FileSystem, Common
with qw/
  SlicerController::Role::FolderScript
  Moo::Task::ControlByGui::Role::Linux
  /;
1;
