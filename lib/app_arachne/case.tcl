#-----------------------------------------------------------------------
# TITLE:
#   case.tcl
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
#   Arachne case manager.  Each case is a distinct scenario.
#
#-----------------------------------------------------------------------

snit::type case {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info: Info Array
    #
    # scenarioDir  - Import/export directory for scenario files.

    typevariable info -array {
        scenarioDir ""
    }

    # cases array: tracks scenarios
    #
    # names               - The IDs of the different cases.
    # counter             - The case ID counter
    # sdb-$id             - The scenario object for $id 
    # longname-$id        - A one-line description of $id
    # source-$id          - Description of the original source of the $id

    typevariable cases -array {
        counter -1
        names {}
    }

    # webviews: List of temporary SQL files to be read by athenadb
    # Variable is initialized by init.

    typevariable webviews {
        web_scenario.sql
    }

    #-------------------------------------------------------------------
    # Initialization

    # init scenarioDir
    #
    # scenarioDir   - The external directory for scenario import/export.
    #
    # Initializes the module, creating an empty base case.

    typemethod init {scenarioDir} {
        # FIRST, get the initialization options.
        set info(scenarioDir) $scenarioDir

        # NEXT, add an empty base case
        $type clear
    }

    # clear
    #
    # Removes all scenarios except the basecase, and resets that one.

    typemethod clear {} {
        foreach id $cases(names) {
            $type remove $id
        }

        array unset cases
        set cases(counter) -1
        set cases(names)   {}

        $type new "" "Base Case"
        return
    }

    #-------------------------------------------------------------------
    # Case Management

    # names
    #
    # Returns the list of case names.

    typemethod names {} {
        return $cases(names)
    }

    # namedict
    #
    # Returns a dictionary of case names and long names.

    typemethod namedict {} {
        set namedict [dict create]

        foreach name $cases(names) {
            dict set namedict $name "$name: $cases(longname-$name)"
        }
        
        return $namedict
    }

    # exists id
    #
    # id  - A case ID
    #
    # Returns 1 if there's a case with this ID, and 0 otherwise.

    typemethod exists {id} {
        expr {$id in $cases(names)}
    }

    # validate id
    #
    # Validates the case id.

    typemethod validate {id} {
        if {![case exists $id]} {
            throw INVALID "Unknown scenario: \"$id\""
        }

        return $id
    }

    # get id
    #
    # id - A case name
    #
    # Returns the athena(n) object for the case.  
    #
    # TBD: If we were to implement caching, this is where it would
    # be done.

    typemethod get {id} {
        return $cases(sdb-$id)
    }

    # with id subcommand ...
    #
    # id - A case name
    #
    # Asks the case to execute the subcommand.
    #
    # TBD: If we implement caching, this would need to call "get"

    typemethod with {id args} {
        tailcall $cases(sdb-$id) {*}$args
    }

    # check id pdict
    #
    # id     - A case ID
    # pdict  - An order parmdict(n) object, including "order_"
    #
    # Checks the order for validity.  Can throw REJECT.

    typemethod check {id pdict} {
        set sdb [case get $id]

        $pdict prepare order_ -required -toupper \
            -with [mytypemethod OrderIsAvailable $sdb]

        if {![$pdict ok]} {
            throw REJECT [$pdict errors]
        }

        $pdict assign order_
        $pdict remove order_
        $sdb order check $order_ {*}[$pdict parms] 

        return
    } 

    # send id pdict
    #
    # id     - A case ID
    # pdict  - An order parmdict(n) object, including "order_"
    #
    # Attempts to send the order to the scenario.  Can throw REJECT.

    typemethod send {id pdict} {
        set sdb [case get $id]

        $pdict prepare order_ -required -toupper \
            -with [mytypemethod OrderIsAvailable $sdb]

        if {![$pdict ok]} {
            throw REJECT [$pdict errors]
        }

        set order [$pdict remove order_]
        set validparms [::athena::orders parms $order]

        foreach p [dict keys [$pdict parms]] {
            if {$p ni $validparms} {
                $pdict remove $p
            }
        }

        return [$sdb order senddict normal $order [$pdict parms]]
    } 

    # OrderIsAvailable sdb name
    #
    # sdb   - The scenario object
    # name  - An order name
    #
    # Validates that the order name is known and that the named order
    # is available to the scenario.

    typemethod OrderIsAvailable {sdb name} {
        set name [$sdb order validate $name]

        if {![$sdb order available $name]} {
            throw INVALID "Order $name is not available in state [$sdb state]."
        }

        return $name
    }

    # metadata id ?parm?
    #
    # id   - A case ID
    # parm - A metadata parameter
    #
    # Returns a dictionary of metadata about the case.  If parm
    # is given, returns just that parm.

    typemethod metadata {id {parm ""}} {
        dict set result id       $id
        dict set result longname $cases(longname-$id)
        dict set result state    [$type with $id state]
        dict set result tick     [$type with $id clock now]
        dict set result week     [$type with $id clock asString]
        dict set result source   $cases(source-$id)

        if {$parm ne ""} {
            return [dict get $result $parm]
        } else {
            return $result
        }
    }

    # new ?id? ?longname?
    #
    # id         - Optionally, an existing case ID
    # longname   - Optionally, a new longname.
    #
    # Creates a new, empty scenario, optionally giving it the longname,
    # or replaces an existing scenario with a new empty one.

    typemethod new {{id ""} {longname ""}} {
        app log normal $id "case new ($id) ($longname)"
        if {$id eq ""} {
            set id [NextID]
        }

        if {$id in $cases(names)} {
            case with $id reset
            app log normal $id "Reset case $id"
        } else {
            set sdb [$type NewScenario $id]

            lappend cases(names)    $id
            set cases(longname-$id) [DefaultLongname $id]
            set cases(sdb-$id)      $sdb
            
            app log normal $id "Created new case $id"
        }

        set cases(source-$id) "n/a"

        if {$longname ne ""} {
            set cases(longname-$id) $longname
        }

        return $id
    }

    # clone id ?newid? ?longname?
    #
    # id         - ID of case to clone
    # newid      - Optionally, an existing case ID
    # longname   - Optionally, a new longname.
    #
    # Creates a new, empty scenario, optionally giving it the longname,
    # or replaces an existing scenario with a new empty one; and then 
    # loads an existing case's data into it.

    typemethod clone {id {newid ""} {longname ""}} {
        set newid [case new $newid $longname]

        file mkdir [scratchdir join temp]
        set tempfile [scratchdir join temp clone.adb]

        case with $id savetemp $tempfile
        case with $newid loadtemp $tempfile
        app log normal $id "Cloned to case $newid"
        app log normal $newid "Cloned from case $id"

        set cases(source-$newid) $id

        return $newid
    }

    # import filename id longname
    #
    # filename  - An .adb or .tcl file name in -scenariodir
    # id        - An existing case ID, or ""
    # longname  - A longname, or ""
    #
    # Attempts to import the scenario into the application.  Throws
    # ARACHNE * on failure.

    typemethod import {filename id {longname ""}} {
        # FIRST, validate the inputs
        if {[file tail $filename] ne $filename} {
            throw {ARACHNE BADNAME} "Not a bare file name"
        }

        set ext [file extension $filename]
        if {$ext ni {.adb .tcl}} {
            throw {ARACHNE BADTYPE} "Cannot import files of type \"$ext\""
        }

        set filename [case scenariodir $filename]
        if {![file isfile $filename]} {
            throw {ARACHNE NOFILE} "No such scenario is available."
        }

        # NEXT, get the ID
        if {$id ne ""} {
            set theID $id
        } else {
            set theID [NextID]
        }

        # NEXT, make sure we can load the filename.
        set sdb [$type NewScenario $theID]

        if {$ext eq ".adb"} {
            try {
                $sdb load $filename
            } trap {ATHENA LOAD} {result} {
                $sdb destroy
                throw {ARACHNE IMPORT} $result
            }
        } else {
            try {
                $sdb executive call $filename
            } on error {result} {
                $sdb destroy
                throw {ARACHNE IMPORT} "Script error: $result"
            }
        }

        # NEXT, the import was successful.  Save the new data.
        if {$id ne ""} {
            $cases(sdb-$id) destroy
            set cases(sdb-$id) $sdb
            $cases(sdb-$id) log normal app "Re-imported from $filename"
        } else {
            set id $theID
            lappend cases(names) $id
            set cases(sdb-$id) $sdb
            if {$longname eq ""} {
                set longname [DefaultLongname $id]
            }
        }

        if {$longname ne ""} {
            set cases(longname-$id) $longname
        }

        set cases(source-$id) [file tail $filename]

        return $theID
    }

    # NewScenario case
    #
    # case  - The case ID.
    #
    # Creates a new, configured instance of athena(n).

    typemethod NewScenario {case} {
        # FIRST, get the list of SQL files to load.
        set viewlist [lmap x $webviews {
            file join $::app_arachne::library sql $x
        }]

        # NEXT, create the scenario object.
        set sdb [athena new \
            -subject      $case                       \
            -logdir       [scratchdir join log $case] \
            -tempsqlfiles [lmap x $webviews {
                              file join $::app_arachne::library sql $x
                          }]]

        # NEXT, track significant changes.  At present, we're interested
        # in changes to cases that have time advanced, not order changes.
        notifier bind $case <Time>    ::case [mytypemethod CaseUpdate $case]
        notifier bind $case <State>   ::case [mytypemethod CaseUpdate $case]
        notifier bind $case <Sync>    ::case [mytypemethod CaseUpdate $case]
        notifier bind $case <Destroy> ::case [mytypemethod CaseDelete $case]

        # NEXT, return the scenario
        return $sdb
    }

    # CaseUpdate case
    #
    # The case has changed significantly: its state has changed, or time
    # has been advanced, or a new scenario has been loaded over it in
    # some way.

    typemethod CaseUpdate {case} {
        notifier send ::case <Update> $case
    } 

    # CaseDelete case
    #
    # The case has been destroyed.

    typemethod CaseDelete {case} {
        notifier forget $case
        notifier send ::case <Delete> $case
    } 

    # export id filename
    #
    # id        - An existing case ID
    # filename  - An .adb or .tcl file name
    #
    # Exports the scenario into the scenario directory under the given
    # name and file type.  If there is no file type, appends ".adb".
    # Throws ARACHNE * on failure.  Returns the bare save file
    # name.

    typemethod export {id filename} {
        # FIRST, validate the inputs
        if {[file tail $filename] ne $filename} {
            throw {ARACHNE BADNAME} "Not a bare file name"
        }

        set ext [file extension $filename]

        if {$ext eq ""} {
            set ext ".adb"
            append filename $ext
        }

        if {$ext ni {.adb .tcl}} {
            throw {ARACHNE BADTYPE} "Cannot export files of type \"$ext\""
        }


        # NEXT, save the scenario.
        set fullname [case scenariodir $filename]

        try {
            switch -exact -- $ext {
                .adb { case with $id save $fullname }
                .tcl { case with $id export fromdata $fullname }
                default { error "Unknown file type: \"$ext\""}
            }
        } trap {SCENARIO SAVE} {result} {
            throw {ARACHNE EXPORT} $result
        }

        return [file tail $fullname]
    }

    # remove id
    #
    # id   - A case ID
    #
    # Destroys the case object and its log, and removes any related data
    # from disk.

    typemethod remove {id} {
        case with $id destroy

        array unset cases(*-$id)
        ldelete cases(names) $id
    }

    
    #-------------------------------------------------------------------
    # Utility Commands

    # scenariodir ?filename?
    #
    # Returns the name of the scenario directory, optionally joining
    # a file to it.

    typemethod scenariodir {{filename ""}} {
        if {$filename ne ""} {
            return [file join $info(scenarioDir) $filename]
        } else {
            return $info(scenarioDir)
        }
    }   

    #-------------------------------------------------------------------
    # Private Helpers

    # NextID
    #
    # Assigns the next case ID.
    proc NextID {} {
        format "case%02d" [incr cases(counter)]
    }

    # DefaultLongname id
    #
    # id  - A case ID
    #
    # Returns a default long name for the case.

    proc DefaultLongname {id} {
        set num [string range $id 4 end]
        return "Scenario #$num"
    }    
}

