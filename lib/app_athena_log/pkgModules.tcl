#-----------------------------------------------------------------------
# TITLE:
#    pkgModules.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    app_athena_log(n) package modules file
#
#    Generated by Kite.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Definition

# -kite-provide-start  DO NOT EDIT THIS BLOCK BY HAND
package provide app_athena_log 6.3.0a10
# -kite-provide-end

#-----------------------------------------------------------------------
# Required Packages

# Add 'package require' statements for this package's external 
# dependencies to the following block.  Kite will update the versions 
# numbers automatically as they change in project.kite.

# -kite-require-start ADD EXTERNAL DEPENDENCIES
package require projectlib
package require marsgui 3.0.16
# -kite-require-end

namespace import ::projectlib::* marsgui::*

#-----------------------------------------------------------------------
# Namespace definition

namespace eval ::app_athena_log:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Modules

source [file join $::app_athena_log::library main.tcl]
source [file join $::app_athena_log::library app.tcl]