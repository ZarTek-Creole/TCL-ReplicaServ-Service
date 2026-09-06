#!/usr/bin/env tclsh
# AmiZone — lanceur tclsh pour ReplicaServ
set scriptDir [file dirname [file normalize [info script]]]
cd $scriptDir

# Stubs eggdrop
proc die {args} { puts stderr "\[ReplicaServ\] [join $args]"; exit 1 }
proc putlog {msg} { puts "\[ReplicaServ\] $msg" }
proc putloglev {level dest msg} { puts "\[ReplicaServ\] $msg" }
proc binds {args} { return {} }
proc unbind {args} {}
proc timers {} { return {} }
proc killtimer {args} {}

# Dépendances (ordre ClaraServ)
foreach {rel} {
	{modules TCL-ZCT ZCT.tcl}
	{modules TCL-PKG-IRCServices ircservices.tcl}
	{modules TCL-PKG-IRCC IRCC.tcl}
} {
	set f [file join $scriptDir {*}$rel]
	if {![file exists $f]} { puts stderr "Missing $f"; exit 1 }
	if {[catch {source $f} err]} { puts stderr "Load $f failed: $err"; exit 1 }
}

puts "ZCT [package require ZCT]"
puts "IRCServices [package require IRCServices]"
puts "IRCC [package require IRCC]"

source [file join $scriptDir ReplicaServ.tcl]
putlog "event loop running..."
vwait forever
