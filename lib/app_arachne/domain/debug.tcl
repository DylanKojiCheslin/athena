#-----------------------------------------------------------------------
# TITLE:
#   domain/debug.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   /debug: The smartdomain(n) for debugging
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# FIRST, define the domain.

oo::class create /debug {
    superclass ::projectlib::smartdomain

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next /debug

        # FIRST, define helpers
        hb configure \
            -cssfile   "/athena.css"         \
            -headercmd [mymethod htmlHeader] \
            -footercmd [mymethod htmlFooter]
    }            

    #-------------------------------------------------------------------
    # Header and Footer

    method htmlHeader {hb title} {
        $hb h1 -style "background: red;" \
            "&nbsp;Arachne: Athena Regional Stability Simulation"
    }

    method htmlFooter {hb} {
        $hb hr
        $hb putln "Athena Arachne [app version] - [clock format [clock seconds]]"
        $hb para
    }

    #-------------------------------------------------------------------
    # Helper Methods

    method dummy {} {
        # TBD: dummy method, to test mods.
    }

    # DebugNavBar 
    #
    # Debugging Navigation Bar

    method DebugNavBar {} {
        hb hr
        hb xref /index.html "Home"
        hb put " | "
        hb iref /index.html "Debug"
        hb put " | "
        hb iref /mods.html "Mods"
        hb hr
        hb para
    }


    # FormatLog logname logfile
    #
    # logname   - The log name, e.g., case00
    # logfile   - A logger(n) logfile, as used by Athena.
    #
    # Formats the log file for display

    method FormatLog {logname logfile} {
        # FIRST, Is this a scenario log?
        set gotWeek [string match "case*" $logname]

        # NEXT, set up the headres.
        set headers {
            "Wallclock Time" "Level" "Component" "Message"            
        }

        if {$gotWeek} {
            set headers [linsert $headers 1 "Week"]
        }

        # NEXT, read the log
        set lines [split [readfile $logfile] \n]

        # NEXT, format it.
        hb table -headers $headers {
            foreach line $lines {
                hb tr
                hb td -style {width: 20ch} "<tt>[lindex $line 0]</tt>"
                if {$gotWeek} {
                    hb td "<tt>[lindex $line 4]</tt>"
                }
                hb td "<tt>[lindex $line 1]</tt>"
                hb td "<tt>[lindex $line 2]</tt>"
                hb td "<tt>[lindex $line 3]</tt>"
                hb /tr
            }
        }
    }
}

#-------------------------------------------------------------------
# NEXT, define the content.

# /index.html
smarturl /debug /index.html {
    Index of debugging tools.
} {
    hb page "Debugging"
    hb h1 "Debugging"

    my DebugNavBar

    hb putln "The following tools are available:"
    hb para

    hb ul {
        hb li-with {
            hb iref /mods.html "Software Mods"
        }

        hb li-with {
            hb xref /scenario/urlschema.html "URL Schema: /scenario"
        }

        hb li-with {
            hb iref /urlschema.html "URL Schema: [my domain]"
        }

        set lognames [glob \
                        -nocomplain \
                        -directory [scratchdir join log] \
                        -tails \
                        *]

        foreach logname $lognames {
            hb li-with {
                hb iref /log/$logname/index.html "Log: $logname"
            }
        }
    }

    return [hb /page]
}

# /log/{logname}/index.html
smarturl /debug /log/{logname}/index.html {
    Displays the contents of the most recent log file in the given log.
} {
    hb page "Log: $logname"
    hb h1   "Log: $logname"

    my DebugNavBar

    set logdir [scratchdir join log $logname]

    if {![file isdirectory $logdir]} {
        throw NOTFOUND "Log $logdir is no longer available"
    }

    set logfiles [lsort [glob -nocomplain -directory $logdir -tails *.log]]

    if {[llength $logfiles] == 0} {
        hb putln "The log is empty."
        return [hb /page]
    }

    # NEXT, let them select a log.
    set logfile [qdict prepare logfile -default [lindex $logfiles end]]

    hb form
    hb label logfile "Log File:"
    hb enum logfile -selected $logfile $logfiles
    hb submit "Select"
    hb /form

    hb form
    hb hidden logfile ""
    hb submit "Latest"
    hb /form

    hb para

    hb h2 "File: $logfile"

    my FormatLog $logname [scratchdir join log $logname $logfile]

    return [hb /page]
}

# /mods.html
smarturl /debug /mods.html {
    Index of loaded software mods.  Allows mods to be reloaded,
    and also allows the developer to find the code to mod.
} {
    hb page "Software Mods"
    hb h1 "Software Mods"

    my DebugNavBar

    switch -- [qdict prepare op -tolower] {
        reload {
            try {
                mod load
                mod apply
            } trap MODERROR {result} {
                hb span -class error \
                    "Could not reload mods: $result"
                hb para
            }
        }
    }


    set table [mod list]

    if {[llength $table] == 0} {
        hb putln "No mods have been loaded or applied."
        hb para
        return [hb /page]
    }

    set t [clock format [mod modtime]]

    hb putln "The following mods were loaded at $t "
    hb iref /mods.html?op=reload "(Reload)"
    hb put ":"
    hb para
    hb table -headers {
        "Package" "Version" "Mod#" "Title" "Mod File"
    } {
        foreach row $table {
            hb tr {
                hb td [dict get $row package] 
                hb td [dict get $row version] 
                hb td [dict get $row num    ] 
                hb td [dict get $row title  ] 
                hb td [dict get $row modfile] 
            }
        }
    }
    hb para

    # Code Search
    hb hr
    hb para
    hb form
    hb label cmdline "Command:"
    hb entry cmdline -size 60
    hb submit "Search"
    hb /form
    hb para

    set cmdline [qdict prepare cmdline]

    if {$cmdline ne ""} {
        hb putln "<b>Command:</b> <tt>$cmdline</tt>"
        hb para

        set code [join [cmdinfo getcode $cmdline -related] \n]

        if {$code eq ""} {
            hb putln "No matching code found."
            hb para
        } else {
            hb pre -class example $code
        }
    }

    # For mod testing.
    my dummy

    return [hb /page]
}




