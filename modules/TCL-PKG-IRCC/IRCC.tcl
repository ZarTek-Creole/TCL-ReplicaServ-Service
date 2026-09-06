# irc.tcl --
#
#  irc implementation for Tcl.
#
# Copyright (c) 2001-2003 by David N. Welton <davidw@dedasys.com>.
# This code may be distributed under the same terms as Tcl.

# -------------------------------------------------------------------------

package require Tcl 8.6

# -------------------------------------------------------------------------

namespace eval ::IRCC {
  # counter used to differentiate connections
  variable conn                  0
  variable config
  variable pkg_vers             0.0.3
  variable pkg_vers_min_need_tcl  8.6
  variable pkg_vers_min_need_tls  1.7.16
  variable irctclfile           [info script]
  array set config  {
    debug                       0
    logger                      0
    name                        ""
  }
}

# ::IRCC::config --
#
# Set global configuration options.
#
# Arguments:
#
# key  name of the configuration option to change.
#
# value  value of the configuration option.

proc ::IRCC::config { args } {
  variable config
  if { [llength $args] == 0 } {
    return [array get config]
  } elseif { [llength $args] == 1 } {
    set key                     [lindex $args 0]
    return $config($key)
  } elseif { [llength $args] > 2 } {
    error "wrong # args: should be \"config key ?val?\""
  }
  set key                       [lindex $args 0]
  set value                     [lindex $args 1]
  foreach ns [namespace children] {
    if {
      [info exists config($key)]                                               \
        && [info exists ${ns}::config($key)]                                   \
        && [set ${ns}::config($key)] == $config($key)
    } {
      ${ns}::cmd-config $key $value
    }
  }
  set config($key)  $value
}

# ::IRCC::connections --
#
# Return a list of handles to all existing connections

proc ::IRCC::connections { } {
  set r  {}
  foreach ns [namespace children] {
    lappend r ${ns}::network
  }
  return $r
}

# ::IRCC::reload --
#
# Reload this file, and merge the current connections into
# the new one.

proc ::IRCC::reload { } {
  variable conn
  set oldconn  $conn
  namespace eval :: {
    source [set ::IRCC::irctclfile]
  }
  foreach ns [namespace children] {
    foreach var {sock logger host port} {
      set $var  [set ${ns}::$var]
    }
    array set dispatch  [array get ${ns}::dispatch]
    array set config  [array get ${ns}::config]
    # make sure our new connection uses the same namespace
    set conn      [string range $ns 10 end]
    ::IRCC::connection
    foreach var {sock logger host port} {
      set ${ns}::$var    [set $var]
    }
    array set ${ns}::dispatch  [array get dispatch]
    array set ${ns}::config    [array get config]
  }
  set conn  $oldconn
}
proc ::IRCC::num2name {numeric {deamonOrigin "global"}} {
  set deamonOrigin [string tolower $deamonOrigin]
  dict set numeric_mapping  "8"   "unrealircd"      "RPL_SNOMASK"
  dict set numeric_mapping  "10"  "unrealircd"      "RPL_REDIR"
  dict set numeric_mapping  "18"  "unrealircd"      "RPL_MAPUSERS"
  dict set numeric_mapping  "001" "global"          "RPL_WELCOME"
  dict set numeric_mapping  "001" "unrealircd"      "RPL_WELCOME"
  dict set numeric_mapping  "002" "global"          "RPL_YOURHOST"
  dict set numeric_mapping  "002" "unrealircd"      "RPL_YOURHOST"
  dict set numeric_mapping  "003" "global"          "RPL_CREATED"
  dict set numeric_mapping  "003" "unrealircd"      "RPL_CREATED"
  dict set numeric_mapping  "004" "global"          "RPL_MYINFO"
  dict set numeric_mapping  "004" "kineircd"        "RPL_MYINFO"
  dict set numeric_mapping  "004" "unrealircd"      "RPL_MYINFO"
  dict set numeric_mapping  "005" "global"          "RPL_BOUNCE"
  dict set numeric_mapping  "005" "global"          "RPL_ISUPPORT"
  dict set numeric_mapping  "005" "unknow"          "RPL_BOUNCE"
  dict set numeric_mapping  "005" "unrealircd"      "RPL_ISUPPORT"
  dict set numeric_mapping  "006" "global"          "RPL_MAP"

  #  New /MAP format. (UnrealIRCd)
  dict set numeric_mapping  "006" "unrealircd"      "RPL_MAP"
  dict set numeric_mapping  "610" "unrealircd"      "RPL_MAPMORE"
  dict set numeric_mapping  "007" "unrealircd"      "RPL_MAPEND"
  #  New /MAP format. (UnrealIRCd) END

  dict set numeric_mapping  "007" "global"          "RPL_MAPEND"
  dict set numeric_mapping  "008" "global"          "RPL_SNOMASK"
  dict set numeric_mapping  "008" "ircu"            "RPL_SNOMASK"
  dict set numeric_mapping  "009" "global"          "RPL_STATMEMTOT"
  dict set numeric_mapping  "009" "ircu"            "RPL_STATMEMTOT"
  dict set numeric_mapping  "010" "global"          "RPL_BOUNCE"
  dict set numeric_mapping  "010" "global"          "RPL_STATMEM"
  dict set numeric_mapping  "010" "ircu"            "RPL_STATMEM"
  dict set numeric_mapping  "014" "global"          "RPL_YOURCOOKIE"
  dict set numeric_mapping  "014" "ircnet"          "RPL_YOURCOOKIE"
  dict set numeric_mapping  "015" "global"          "RPL_MAP"
  dict set numeric_mapping  "015" "ircu"            "RPL_MAP"
  dict set numeric_mapping  "016" "global"          "RPL_MAPMORE"
  dict set numeric_mapping  "016" "ircu"            "RPL_MAPMORE"
  dict set numeric_mapping  "017" "global"          "RPL_MAPEND"
  dict set numeric_mapping  "017" "ircu"            "RPL_MAPEND"
  dict set numeric_mapping  "042" "global"          "RPL_YOURID"
  dict set numeric_mapping  "042" "ircnet"          "RPL_YOURID"
  dict set numeric_mapping  "043" "global"          "RPL_SAVENICK"
  dict set numeric_mapping  "043" "ircnet"          "RPL_SAVENICK"
  dict set numeric_mapping  "050" "aircd"           "RPL_ATTEMPTINGJUNC"
  dict set numeric_mapping  "050" "global"          "RPL_ATTEMPTINGJUNC"
  dict set numeric_mapping  "051" "aircd"           "RPL_ATTEMPTINGREROUTE"
  dict set numeric_mapping  "051" "global"          "RPL_ATTEMPTINGREROUTE"
  dict set numeric_mapping  "105" "unrealircd"      "RPL_REMOTEISUPPORT"
  #
  # Numberic replies from server commands.
  # These are currently in the range 200-399.
  #
  dict set numeric_mapping  "200" "global"          "RPL_TRACELINK"
  dict set numeric_mapping  "200" "unrealircd"      "RPL_TRACELINK"
  dict set numeric_mapping  "201" "global"          "RPL_TRACECONNECTING"
  dict set numeric_mapping  "201" "unrealircd"      "RPL_TRACECONNECTING"
  dict set numeric_mapping  "202" "global"          "RPL_TRACEHANDSHAKE"
  dict set numeric_mapping  "202" "unrealircd"      "RPL_TRACEHANDSHAKE"
  dict set numeric_mapping  "203" "global"          "RPL_TRACEUNKNOWN"
  dict set numeric_mapping  "203" "unrealircd"      "RPL_TRACEUNKNOWN"
  dict set numeric_mapping  "204" "global"          "RPL_TRACEOPERATOR"
  dict set numeric_mapping  "204" "unrealircd"      "RPL_TRACEOPERATOR"
  dict set numeric_mapping  "205" "global"          "RPL_TRACEUSER"
  dict set numeric_mapping  "205" "unrealircd"      "RPL_TRACEUSER"
  dict set numeric_mapping  "206" "global"          "RPL_TRACESERVER"
  dict set numeric_mapping  "206" "unrealircd"      "RPL_TRACESERVER"
  dict set numeric_mapping  "207" "global"          "RPL_TRACESERVICE"
  dict set numeric_mapping  "208" "global"          "RPL_TRACENEWTYPE"
  dict set numeric_mapping  "208" "unrealircd"      "RPL_TRACENEWTYPE"
  dict set numeric_mapping  "209" "global"          "RPL_TRACECLASS"
  dict set numeric_mapping  "209" "unrealircd"      "RPL_TRACECLASS"
  dict set numeric_mapping  "210" "aircd"           "RPL_STATS"
  dict set numeric_mapping  "210" "global"          "RPL_STATS"
  dict set numeric_mapping  "210" "global"          "RPL_TRACERECONNECT"
  dict set numeric_mapping  "210" "unrealircd"      "RPL_STATSHELP"
  dict set numeric_mapping  "211" "global"          "RPL_STATSLINKINFO"
  dict set numeric_mapping  "211" "unrealircd"      "RPL_STATSLINKINFO"
  dict set numeric_mapping  "212" "global"          "RPL_STATSCOMMANDS"
  dict set numeric_mapping  "212" "unrealircd"      "RPL_STATSCOMMANDS"
  dict set numeric_mapping  "213" "global"          "RPL_STATSCLINE"
  dict set numeric_mapping  "213" "unrealircd"      "RPL_STATSCLINE"
  dict set numeric_mapping  "214" "global"          "RPL_STATSNLINE"
  dict set numeric_mapping  "215" "global"          "RPL_STATSILINE"
  dict set numeric_mapping  "215" "unrealircd"      "RPL_STATSILINE"
  dict set numeric_mapping  "216" "global"          "RPL_STATSKLINE"
  dict set numeric_mapping  "217" "global"          "RPL_STATSPLINE"
  dict set numeric_mapping  "217" "global"          "RPL_STATSQLINE"
  dict set numeric_mapping  "217" "ircu"            "RPL_STATSPLINE"
  dict set numeric_mapping  "217" "unrealircd"      "RPL_STATSQLINE"
  dict set numeric_mapping  "218" "global"          "RPL_STATSYLINE"
  dict set numeric_mapping  "218" "unrealircd"      "RPL_STATSYLINE"
  dict set numeric_mapping  "219" "global"          "RPL_ENDOFSTATS"
  dict set numeric_mapping  "219" "unrealircd"      "RPL_ENDOFSTATS"
  dict set numeric_mapping  "220" "global"          "RPL_STATSBLINE"
  dict set numeric_mapping  "220" "global"          "RPL_STATSPLINE"
  dict set numeric_mapping  "220" "hybrid"          "RPL_STATSPLINE"
  dict set numeric_mapping  "221" "global"          "RPL_UMODEIS"
  dict set numeric_mapping  "221" "unrealircd"      "RPL_UMODEIS"
  dict set numeric_mapping  "222" "bahamut"         "RPL_STATSBLINE"
  dict set numeric_mapping  "222" "global"          "RPL_MODLIST"
  dict set numeric_mapping  "222" "global"          "RPL_SQLINE_NICK"
  dict set numeric_mapping  "222" "global"          "RPL_STATSBLINE"
  dict set numeric_mapping  "223" "bahamut"         "RPL_STATSELINE"
  dict set numeric_mapping  "223" "global"          "RPL_STATSGLINE"
  dict set numeric_mapping  "223" "unrealircd"      "RPL_STATSGLINE"
  dict set numeric_mapping  "224" "bahamut"         "RPL_STATSFLINE"
  dict set numeric_mapping  "224" "global"          "RPL_STATSTLINE"
  dict set numeric_mapping  "224" "hybrid"          "RPL_STATSFLINE"
  dict set numeric_mapping  "224" "unrealircd"      "RPL_STATSTLINE"
  dict set numeric_mapping  "225" "bahamut"         "RPL_STATSZLINE"
  dict set numeric_mapping  "225" "global"          "RPL_STATSDLINE"
  dict set numeric_mapping  "225" "global"          "RPL_STATSELINE"
  dict set numeric_mapping  "225" "global"          "RPL_STATSZLINE"
  dict set numeric_mapping  "225" "hybrid"          "RPL_STATSDLINE"
  dict set numeric_mapping  "226" "bahamut"         "RPL_STATSCOUNT"
  dict set numeric_mapping  "226" "global"          "RPL_STATSCOUNT"
  dict set numeric_mapping  "226" "global"          "RPL_STATSNLINE"
  dict set numeric_mapping  "226" "unrealircd"      "RPL_STATSNLINE"
  dict set numeric_mapping  "227" "bahamut"         "RPL_STATSGLINE"
  dict set numeric_mapping  "227" "global"          "RPL_STATSGLINE"
  dict set numeric_mapping  "227" "global"          "RPL_STATSVLINE"
  dict set numeric_mapping  "227" "unrealircd"      "RPL_STATSVLINE"
  dict set numeric_mapping  "228" "global"          "RPL_STATSQLINE"
  dict set numeric_mapping  "228" "ircu"            "RPL_STATSQLINE"
  dict set numeric_mapping  "228" "unrealircd"      "RPL_STATSBANVER"
  dict set numeric_mapping  "229" "unrealircd"      "RPL_STATSSPAMF"
  dict set numeric_mapping  "230" "unrealircd"      "RPL_STATSEXCEPTTKL"
  dict set numeric_mapping  "231" "global"          "RPL_SERVICEINFO"
  dict set numeric_mapping  "232" "global"          "RPL_ENDOFSERVICES"
  dict set numeric_mapping  "232" "global"          "RPL_RULES"
  dict set numeric_mapping  "232" "unrealircd"      "RPL_RULES"
  dict set numeric_mapping  "233" "global"          "RPL_SERVICE"
  dict set numeric_mapping  "233" "unrealircd"      "RPL_SERVICE"
  dict set numeric_mapping  "234" "global"          "RPL_SERVLIST"
  dict set numeric_mapping  "235" "global"          "RPL_SERVLISTEND"
  dict set numeric_mapping  "236" "global"          "RPL_STATSVERBOSE"
  dict set numeric_mapping  "236" "ircu"            "RPL_STATSVERBOSE"
  dict set numeric_mapping  "237" "global"          "RPL_STATSENGINE"
  dict set numeric_mapping  "237" "ircu"            "RPL_STATSENGINE"
  dict set numeric_mapping  "238" "global"          "RPL_STATSFLINE"
  dict set numeric_mapping  "238" "ircu"            "RPL_STATSFLINE"
  dict set numeric_mapping  "239" "global"          "RPL_STATSIAUTH"
  dict set numeric_mapping  "239" "ircnet"          "RPL_STATSIAUTH"
  dict set numeric_mapping  "240" "austhex"         "RPL_STATSXLINE"
  dict set numeric_mapping  "240" "global"          "RPL_STATSVLINE"
  dict set numeric_mapping  "240" "global"          "RPL_STATSXLINE"
  dict set numeric_mapping  "241" "global"          "RPL_STATSLLINE"
  dict set numeric_mapping  "241" "unrealircd"      "RPL_STATSLLINE"
  dict set numeric_mapping  "242" "global"          "RPL_STATSUPTIME"
  dict set numeric_mapping  "242" "unrealircd"      "RPL_STATSUPTIME"
  dict set numeric_mapping  "243" "global"          "RPL_STATSOLINE"
  dict set numeric_mapping  "243" "unrealircd"      "RPL_STATSOLINE"
  dict set numeric_mapping  "244" "global"          "RPL_STATSHLINE"
  dict set numeric_mapping  "244" "unrealircd"      "RPL_STATSHLINE"
  dict set numeric_mapping  "245" "bahamut"         "RPL_STATSSLINE"
  dict set numeric_mapping  "245" "global"          "RPL_STATSSLINE"
  dict set numeric_mapping  "245" "hybrid"          "RPL_STATSSLINE"
  dict set numeric_mapping  "245" "ircnet"          "RPL_STATSSLINE"
  dict set numeric_mapping  "246" "global"          "RPL_STATSPING"
  dict set numeric_mapping  "246" "global"          "RPL_STATSTLINE"
  dict set numeric_mapping  "246" "global"          "RPL_STATSULINE"
  dict set numeric_mapping  "246" "hybrid"          "RPL_STATSULINE"
  dict set numeric_mapping  "246" "ircu"            "RPL_STATSTLINE"
  dict set numeric_mapping  "247" "global"          "RPL_STATSBLINE"
  dict set numeric_mapping  "247" "global"          "RPL_STATSGLINE"
  dict set numeric_mapping  "247" "global"          "RPL_STATSXLINE"
  dict set numeric_mapping  "247" "hybrid"          "RPL_STATSXLINE"
  dict set numeric_mapping  "247" "ircu"            "RPL_STATSGLINE"
  dict set numeric_mapping  "247" "ptlink"          "RPL_STATSXLINE"
  dict set numeric_mapping  "247" "unrealircd"      "RPL_STATSXLINE"
  dict set numeric_mapping  "248" "global"          "RPL_STATSDEFINE"
  dict set numeric_mapping  "248" "global"          "RPL_STATSULINE"
  dict set numeric_mapping  "248" "ircnet"          "RPL_STATSDEFINE"
  dict set numeric_mapping  "248" "ircu"            "RPL_STATSULINE"
  dict set numeric_mapping  "248" "unrealircd"      "RPL_STATSULINE"
  dict set numeric_mapping  "249" "global"          "RPL_STATSDEBUG"
  dict set numeric_mapping  "249" "global"          "RPL_STATSULINE"
  dict set numeric_mapping  "249" "hybrid"          "RPL_STATSDEBUG"
  dict set numeric_mapping  "249" "unrealircd"      "RPL_STATSDEBUG"
  dict set numeric_mapping  "250" "global"          "RPL_STATSCONN"
  dict set numeric_mapping  "250" "global"          "RPL_STATSDLINE"
  dict set numeric_mapping  "250" "ircu"            "RPL_STATSCONN"
  dict set numeric_mapping  "250" "unrealircd"      "RPL_STATSCONN"
  dict set numeric_mapping  "251" "global"          "RPL_LUSERCLIENT"
  dict set numeric_mapping  "251" "unrealircd"      "RPL_LUSERCLIENT"
  dict set numeric_mapping  "252" "global"          "RPL_LUSEROP"
  dict set numeric_mapping  "252" "unrealircd"      "RPL_LUSEROP"
  dict set numeric_mapping  "253" "global"          "RPL_LUSERUNKNOWN"
  dict set numeric_mapping  "253" "unrealircd"      "RPL_LUSERUNKNOWN"
  dict set numeric_mapping  "254" "global"          "RPL_LUSERCHANNELS"
  dict set numeric_mapping  "254" "unrealircd"      "RPL_LUSERCHANNELS"
  dict set numeric_mapping  "255" "global"          "RPL_LUSERME"
  dict set numeric_mapping  "255" "unrealircd"      "RPL_LUSERME"
  dict set numeric_mapping  "256" "global"          "RPL_ADMINME"
  dict set numeric_mapping  "256" "unrealircd"      "RPL_ADMINME"
  dict set numeric_mapping  "257" "global"          "RPL_ADMINLOC1"
  dict set numeric_mapping  "257" "unrealircd"      "RPL_ADMINLOC1"
  dict set numeric_mapping  "258" "global"          "RPL_ADMINLOC2"
  dict set numeric_mapping  "258" "unrealircd"      "RPL_ADMINLOC2"
  dict set numeric_mapping  "259" "global"          "RPL_ADMINEMAIL"
  dict set numeric_mapping  "259" "unrealircd"      "RPL_ADMINEMAIL"
  dict set numeric_mapping  "261" "global"          "RPL_TRACELOG"
  dict set numeric_mapping  "261" "unrealircd"      "RPL_TRACELOG"
  dict set numeric_mapping  "262" "global"          "RPL_TRACEEND"
  dict set numeric_mapping  "262" "global"          "RPL_TRACEPING"
  dict set numeric_mapping  "263" "global"          "RPL_TRYAGAIN"
  dict set numeric_mapping  "263" "unrealircd"      "RPL_TRYAGAIN"
  dict set numeric_mapping  "265" "aircd"           "RPL_LOCALUSERS"
  dict set numeric_mapping  "265" "bahamut"         "RPL_LOCALUSERS"
  dict set numeric_mapping  "265" "global"          "RPL_LOCALUSERS"
  dict set numeric_mapping  "265" "hybrid"          "RPL_LOCALUSERS"
  dict set numeric_mapping  "265" "unrealircd"      "RPL_LOCALUSERS"
  dict set numeric_mapping  "266" "aircd"           "RPL_GLOBALUSERS"
  dict set numeric_mapping  "266" "bahamut"         "RPL_GLOBALUSERS"
  dict set numeric_mapping  "266" "global"          "RPL_GLOBALUSERS"
  dict set numeric_mapping  "266" "hybrid"          "RPL_GLOBALUSERS"
  dict set numeric_mapping  "266" "unrealircd"      "RPL_GLOBALUSERS"
  dict set numeric_mapping  "267" "aircd"           "RPL_START_NETSTAT"
  dict set numeric_mapping  "267" "global"          "RPL_START_NETSTAT"
  dict set numeric_mapping  "268" "aircd"           "RPL_NETSTAT"
  dict set numeric_mapping  "268" "global"          "RPL_NETSTAT"
  dict set numeric_mapping  "269" "aircd"           "RPL_END_NETSTAT"
  dict set numeric_mapping  "269" "global"          "RPL_END_NETSTAT"
  dict set numeric_mapping  "270" "global"          "RPL_PRIVS"
  dict set numeric_mapping  "270" "ircu"            "RPL_PRIVS"
  dict set numeric_mapping  "271" "global"          "RPL_SILELIST"
  dict set numeric_mapping  "271" "ircu"            "RPL_SILELIST"
  dict set numeric_mapping  "271" "unrealircd"      "RPL_SILELIST"
  dict set numeric_mapping  "272" "global"          "RPL_ENDOFSILELIST"
  dict set numeric_mapping  "272" "ircu"            "RPL_ENDOFSILELIST"
  dict set numeric_mapping  "272" "unrealircd"      "RPL_ENDOFSILELIST"
  dict set numeric_mapping  "273" "aircd"           "RPL_NOTIFY"
  dict set numeric_mapping  "273" "global"          "RPL_NOTIFY"
  dict set numeric_mapping  "274" "aircd"           "RPL_ENDNOTIFY"
  dict set numeric_mapping  "274" "global"          "RPL_ENDNOTIFY"
  dict set numeric_mapping  "274" "global"          "RPL_STATSDELTA"
  dict set numeric_mapping  "274" "ircnet"          "RPL_STATSDELTA"
  dict set numeric_mapping  "275" "global"          "RPL_STATSDLINE"
  dict set numeric_mapping  "275" "ircu"            "RPL_STATSDLINE"
  dict set numeric_mapping  "275" "ultimate"        "RPL_STATSDLINE"
  dict set numeric_mapping  "275" "unrealircd"      "RPL_STATSDLINE"
  dict set numeric_mapping  "276" "global"          "RPL_VCHANEXIST"
  dict set numeric_mapping  "276" "unrealircd"      "RPL_WHOISCERTFP"
  dict set numeric_mapping  "277" "global"          "RPL_VCHANLIST"
  dict set numeric_mapping  "278" "global"          "RPL_VCHANHELP"
  dict set numeric_mapping  "280" "global"          "RPL_GLIST"
  dict set numeric_mapping  "280" "ircu"            "RPL_GLIST"
  dict set numeric_mapping  "281" "global"          "RPL_ACCEPTLIST"
  dict set numeric_mapping  "281" "global"          "RPL_ENDOFGLIST"
  dict set numeric_mapping  "281" "ircu"            "RPL_ENDOFGLIST"
  dict set numeric_mapping  "282" "global"          "RPL_ENDOFACCEPT"
  dict set numeric_mapping  "282" "global"          "RPL_JUPELIST"
  dict set numeric_mapping  "282" "ircu"            "RPL_JUPELIST"
  dict set numeric_mapping  "283" "global"          "RPL_ALIST"
  dict set numeric_mapping  "283" "global"          "RPL_ENDOFJUPELIST"
  dict set numeric_mapping  "283" "ircu"            "RPL_ENDOFJUPELIST"
  dict set numeric_mapping  "284" "global"          "RPL_ENDOFALIST"
  dict set numeric_mapping  "284" "global"          "RPL_FEATURE"
  dict set numeric_mapping  "284" "ircu"            "RPL_FEATURE"
  dict set numeric_mapping  "285" "aircd"           "RPL_CHANINFO_HANDLE"
  dict set numeric_mapping  "285" "global"          "RPL_CHANINFO_HANDLE"
  dict set numeric_mapping  "285" "global"          "RPL_GLIST_HASH"
  dict set numeric_mapping  "285" "global"          "RPL_NEWHOSTIS"
  dict set numeric_mapping  "285" "quakenet"        "RPL_NEWHOSTIS"
  dict set numeric_mapping  "286" "aircd"           "RPL_CHANINFO_USERS"
  dict set numeric_mapping  "286" "global"          "RPL_CHANINFO_USERS"
  dict set numeric_mapping  "286" "global"          "RPL_CHKHEAD"
  dict set numeric_mapping  "286" "quakenet"        "RPL_CHKHEAD"
  dict set numeric_mapping  "287" "aircd"           "RPL_CHANINFO_CHOPS"
  dict set numeric_mapping  "287" "global"          "RPL_CHANINFO_CHOPS"
  dict set numeric_mapping  "287" "global"          "RPL_CHANUSER"
  dict set numeric_mapping  "287" "quakenet"        "RPL_CHANUSER"
  dict set numeric_mapping  "288" "aircd"           "RPL_CHANINFO_VOICES"
  dict set numeric_mapping  "288" "global"          "RPL_CHANINFO_VOICES"
  dict set numeric_mapping  "288" "global"          "RPL_PATCHHEAD"
  dict set numeric_mapping  "288" "quakenet"        "RPL_PATCHHEAD"
  dict set numeric_mapping  "289" "aircd"           "RPL_CHANINFO_AWAY"
  dict set numeric_mapping  "289" "global"          "RPL_CHANINFO_AWAY"
  dict set numeric_mapping  "289" "global"          "RPL_PATCHCON"
  dict set numeric_mapping  "289" "quakenet"        "RPL_PATCHCON"
  dict set numeric_mapping  "290" "aircd"           "RPL_CHANINFO_OPERS"
  dict set numeric_mapping  "290" "global"          "RPL_CHANINFO_OPERS"
  dict set numeric_mapping  "290" "global"          "RPL_DATASTR"
  dict set numeric_mapping  "290" "global"          "RPL_HELPHDR"
  dict set numeric_mapping  "290" "quakenet"        "RPL_DATASTR"
  dict set numeric_mapping  "291" "aircd"           "RPL_CHANINFO_BANNED"
  dict set numeric_mapping  "291" "global"          "RPL_CHANINFO_BANNED"
  dict set numeric_mapping  "291" "global"          "RPL_ENDOFCHECK"
  dict set numeric_mapping  "291" "global"          "RPL_HELPOP"
  dict set numeric_mapping  "291" "quakenet"        "RPL_ENDOFCHECK"
  dict set numeric_mapping  "292" "aircd"           "RPL_CHANINFO_BANS"
  dict set numeric_mapping  "292" "global"          "RPL_CHANINFO_BANS"
  dict set numeric_mapping  "292" "global"          "RPL_HELPTLR"
  dict set numeric_mapping  "293" "aircd"           "RPL_CHANINFO_INVITE"
  dict set numeric_mapping  "293" "global"          "RPL_CHANINFO_INVITE"
  dict set numeric_mapping  "293" "global"          "RPL_HELPHLP"
  dict set numeric_mapping  "294" "aircd"           "RPL_CHANINFO_INVITES"
  dict set numeric_mapping  "294" "global"          "RPL_CHANINFO_INVITES"
  dict set numeric_mapping  "294" "global"          "RPL_HELPFWD"
  dict set numeric_mapping  "295" "aircd"           "RPL_CHANINFO_KICK"
  dict set numeric_mapping  "295" "global"          "RPL_CHANINFO_KICK"
  dict set numeric_mapping  "295" "global"          "RPL_HELPIGN"
  dict set numeric_mapping  "296" "aircd"           "RPL_CHANINFO_KICKS"
  dict set numeric_mapping  "296" "global"          "RPL_CHANINFO_KICKS"
  dict set numeric_mapping  "299" "aircd"           "RPL_END_CHANINFO"
  dict set numeric_mapping  "299" "global"          "RPL_END_CHANINFO"
  dict set numeric_mapping  "300" "global"          "RPL_NONE"
  dict set numeric_mapping  "300" "unrealircd"      "RPL_NONE"
  dict set numeric_mapping  "301" "global"          "RPL_AWAY"
  dict set numeric_mapping  "301" "kineircd"        "RPL_AWAY"
  dict set numeric_mapping  "301" "unrealircd"      "RPL_AWAY"
  dict set numeric_mapping  "302" "global"          "RPL_USERHOST"
  dict set numeric_mapping  "302" "unrealircd"      "RPL_USERHOST"
  dict set numeric_mapping  "303" "global"          "RPL_ISON"
  dict set numeric_mapping  "303" "unrealircd"      "RPL_ISON"
  dict set numeric_mapping  "304" "global"          "RPL_TEXT"
  dict set numeric_mapping  "304" "unrealircd"      "RPL_TEXT"
  dict set numeric_mapping  "305" "global"          "RPL_UNAWAY"
  dict set numeric_mapping  "305" "unrealircd"      "RPL_UNAWAY"
  dict set numeric_mapping  "306" "global"          "RPL_NOWAWAY"
  dict set numeric_mapping  "306" "unrealircd"      "RPL_NOWAWAY"
  dict set numeric_mapping  "307" "austhex"         "RPL_SUSERHOST"
  dict set numeric_mapping  "307" "bahamut"         "RPL_WHOISREGNICK"
  dict set numeric_mapping  "307" "global"          "RPL_SUSERHOST"
  dict set numeric_mapping  "307" "global"          "RPL_USERIP"
  dict set numeric_mapping  "307" "global"          "RPL_WHOISREGNICK"
  dict set numeric_mapping  "307" "unrealircd"      "RPL_WHOISREGNICK"
  dict set numeric_mapping  "308" "aircd"           "RPL_NOTIFYACTION"
  dict set numeric_mapping  "308" "bahamut"         "RPL_WHOISADMIN"
  dict set numeric_mapping  "308" "global"          "RPL_NOTIFYACTION"
  dict set numeric_mapping  "308" "global"          "RPL_RULESSTART"
  dict set numeric_mapping  "308" "global"          "RPL_WHOISADMIN"
  dict set numeric_mapping  "308" "unrealircd"      "RPL_RULESSTART"
  dict set numeric_mapping  "309" "aircd"           "RPL_NICKTRACE"
  dict set numeric_mapping  "309" "austhex"         "RPL_WHOISHELPER"
  dict set numeric_mapping  "309" "bahamut"         "RPL_WHOISSADMIN"
  dict set numeric_mapping  "309" "global"          "RPL_ENDOFRULES"
  dict set numeric_mapping  "309" "global"          "RPL_NICKTRACE"
  dict set numeric_mapping  "309" "global"          "RPL_WHOISHELPER"
  dict set numeric_mapping  "309" "global"          "RPL_WHOISSADMIN"
  dict set numeric_mapping  "309" "unrealircd"      "RPL_ENDOFRULES"
  dict set numeric_mapping  "310" "austhex"         "RPL_WHOISSERVICE"
  dict set numeric_mapping  "310" "bahamut"         "RPL_WHOISSVCMSG"
  dict set numeric_mapping  "310" "global"          "RPL_WHOISHELPOP"
  dict set numeric_mapping  "310" "global"          "RPL_WHOISSERVICE"
  dict set numeric_mapping  "310" "global"          "RPL_WHOISSVCMSG"
  dict set numeric_mapping  "311" "global"          "RPL_WHOISUSER"
  dict set numeric_mapping  "311" "unrealircd"      "RPL_WHOISUSER"
  dict set numeric_mapping  "312" "global"          "RPL_WHOISSERVER"
  dict set numeric_mapping  "312" "unrealircd"      "RPL_WHOISSERVER"
  dict set numeric_mapping  "313" "global"          "RPL_WHOISOPERATOR"
  dict set numeric_mapping  "313" "unrealircd"      "RPL_WHOISOPERATOR"
  dict set numeric_mapping  "314" "global"          "RPL_WHOWASUSER"
  dict set numeric_mapping  "314" "unrealircd"      "RPL_WHOWASUSER"
  dict set numeric_mapping  "315" "global"          "RPL_ENDOFWHO"
  dict set numeric_mapping  "315" "unrealircd"      "RPL_ENDOFWHO"
  dict set numeric_mapping  "316" "global"          "RPL_WHOISCHANOP"
  dict set numeric_mapping  "317" "global"          "RPL_WHOISIDLE"
  dict set numeric_mapping  "317" "unrealircd"      "RPL_WHOISIDLE"
  dict set numeric_mapping  "318" "global"          "RPL_ENDOFWHOIS"
  dict set numeric_mapping  "318" "unrealircd"      "RPL_ENDOFWHOIS"
  dict set numeric_mapping  "319" "global"          "RPL_WHOISCHANNELS"
  dict set numeric_mapping  "319" "unrealircd"      "RPL_WHOISCHANNELS"
  dict set numeric_mapping  "320" "anothernet"      "RPL_WHOIS_HIDDEN"
  dict set numeric_mapping  "320" "austhex"         "RPL_WHOISVIRT"
  dict set numeric_mapping  "320" "global"          "RPL_WHOISSPECIAL"
  dict set numeric_mapping  "320" "global"          "RPL_WHOISVIRT"
  dict set numeric_mapping  "320" "global"          "RPL_WHOIS_HIDDEN"
  dict set numeric_mapping  "320" "unrealircd"      "RPL_WHOISSPECIAL"
  dict set numeric_mapping  "321" "global"          "RPL_LISTSTART"
  dict set numeric_mapping  "321" "unrealircd"      "RPL_LISTSTART"
  dict set numeric_mapping  "322" "global"          "RPL_LIST"
  dict set numeric_mapping  "322" "unrealircd"      "RPL_LIST"
  dict set numeric_mapping  "323" "global"          "RPL_LISTEND"
  dict set numeric_mapping  "323" "unrealircd"      "RPL_LISTEND"
  dict set numeric_mapping  "324" "global"          "RPL_CHANNELMODEIS"
  dict set numeric_mapping  "324" "unrealircd"      "RPL_CHANNELMODEIS"
  dict set numeric_mapping  "325" "global"          "RPL_CHANNELPASSIS"
  dict set numeric_mapping  "325" "global"          "RPL_UNIQOPIS"
  dict set numeric_mapping  "326" "global"          "RPL_NOCHANPASS"
  dict set numeric_mapping  "327" "global"          "RPL_CHPASSUNKNOWN"
  dict set numeric_mapping  "328" "austhex"         "RPL_CHANNEL_URL"
  dict set numeric_mapping  "328" "bahamut"         "RPL_CHANNEL_URL"
  dict set numeric_mapping  "328" "global"          "RPL_CHANNEL_URL"
  dict set numeric_mapping  "329" "bahamut"         "RPL_CREATIONTIME"
  dict set numeric_mapping  "329" "global"          "RPL_CREATIONTIME"
  dict set numeric_mapping  "329" "unrealircd"      "RPL_CREATIONTIME"
  # ircu/charybdis-family --nenolod
  dict set numeric_mapping  "330" "global"          "RPL_WHOISACCOUNT"
  dict set numeric_mapping  "330" "global"          "RPL_WHOWAS_TIME"
  dict set numeric_mapping  "330" "ircu"            "RPL_WHOISACCOUNT"
  dict set numeric_mapping  "330" "unrealircd"      "RPL_WHOISLOGGEDIN"
  dict set numeric_mapping  "331" "global"          "RPL_NOTOPIC"
  dict set numeric_mapping  "331" "unrealircd"      "RPL_NOTOPIC"
  dict set numeric_mapping  "332" "global"          "RPL_TOPIC"
  dict set numeric_mapping  "332" "unrealircd"      "RPL_TOPIC"
  dict set numeric_mapping  "333" "global"          "RPL_TOPICWHOTIME"
  dict set numeric_mapping  "333" "ircu"            "RPL_TOPICWHOTIME"
  dict set numeric_mapping  "333" "unrealircd"      "RPL_TOPICWHOTIME"
  dict set numeric_mapping  "334" "bahamut"         "RPL_COMMANDSYNTAX"
  dict set numeric_mapping  "334" "global"          "RPL_COMMANDSYNTAX"
  dict set numeric_mapping  "334" "global"          "RPL_LISTSYNTAX"
  dict set numeric_mapping  "334" "global"          "RPL_LISTUSAGE"
  dict set numeric_mapping  "334" "ircu"            "RPL_LISTUSAGE"
  dict set numeric_mapping  "334" "unrealircd"      "RPL_LISTSYNTAX"
  dict set numeric_mapping  "335" "global"          "RPL_WHOISBOT"
  dict set numeric_mapping  "335" "unrealircd"      "RPL_WHOISBOT"
  dict set numeric_mapping  "336" "unrealircd"      "RPL_INVITELIST"
  dict set numeric_mapping  "337" "unrealircd"      "RPL_ENDOFINVITELIST"
  dict set numeric_mapping  "338" "bahamut"         "RPL_WHOISACTUALLY"
  dict set numeric_mapping  "338" "global"          "RPL_CHANPASSOK"
  dict set numeric_mapping  "338" "global"          "RPL_WHOISACTUALLY"
  dict set numeric_mapping  "338" "ircu"            "RPL_WHOISACTUALLY"
  dict set numeric_mapping  "339" "global"          "RPL_BADCHANPASS"
  dict set numeric_mapping  "340" "global"          "RPL_USERIP"
  dict set numeric_mapping  "340" "ircu"            "RPL_USERIP"
  dict set numeric_mapping  "340" "unrealircd"      "RPL_USERIP"
  dict set numeric_mapping  "341" "global"          "RPL_INVITING"
  dict set numeric_mapping  "341" "unrealircd"      "RPL_INVITING"
  dict set numeric_mapping  "342" "global"          "RPL_SUMMONING"
  dict set numeric_mapping  "344" "unrealircd"      "RPL_WHOISCOUNTRY"
  dict set numeric_mapping  "345" "gamesurge"       "RPL_INVITED"
  dict set numeric_mapping  "345" "global"          "RPL_INVITED"
  dict set numeric_mapping  "346" "global"          "RPL_INVITELIST"
  dict set numeric_mapping  "346" "unrealircd"      "RPL_INVEXLIST"
  dict set numeric_mapping  "347" "global"          "RPL_ENDOFINVITELIST"
  dict set numeric_mapping  "347" "unrealircd"      "RPL_ENDOFINVEXLIST"
  dict set numeric_mapping  "348" "global"          "RPL_EXCEPTLIST"
  dict set numeric_mapping  "348" "unrealircd"      "RPL_EXLIST"
  dict set numeric_mapping  "349" "global"          "RPL_ENDOFEXCEPTLIST"
  dict set numeric_mapping  "349" "unrealircd"      "RPL_ENDOFEXLIST"
  dict set numeric_mapping  "351" "global"          "RPL_VERSION"
  dict set numeric_mapping  "351" "unrealircd"      "RPL_VERSION"
  dict set numeric_mapping  "352" "global"          "RPL_WHOREPLY"
  dict set numeric_mapping  "352" "unrealircd"      "RPL_WHOREPLY"
  dict set numeric_mapping  "353" "global"          "RPL_NAMREPLY"
  dict set numeric_mapping  "353" "unrealircd"      "RPL_NAMREPLY"
  dict set numeric_mapping  "354" "global"          "RPL_WHOSPCRPL"
  dict set numeric_mapping  "354" "ircu"            "RPL_WHOSPCRPL"
  dict set numeric_mapping  "355" "global"          "RPL_NAMREPLY_"
  dict set numeric_mapping  "355" "quakenet"        "RPL_NAMREPLY_"
  dict set numeric_mapping  "357" "austhex"         "RPL_MAP"
  dict set numeric_mapping  "357" "global"          "RPL_MAP"
  dict set numeric_mapping  "358" "austhex"         "RPL_MAPMORE"
  dict set numeric_mapping  "358" "global"          "RPL_MAPMORE"
  dict set numeric_mapping  "359" "austhex"         "RPL_MAPEND"
  dict set numeric_mapping  "359" "global"          "RPL_MAPEND"
  dict set numeric_mapping  "361" "global"          "RPL_KILLDONE"
  dict set numeric_mapping  "362" "global"          "RPL_CLOSING"
  dict set numeric_mapping  "362" "unrealircd"      "RPL_CLOSING"
  dict set numeric_mapping  "363" "global"          "RPL_CLOSEEND"
  dict set numeric_mapping  "363" "unrealircd"      "RPL_CLOSEEND"
  dict set numeric_mapping  "364" "global"          "RPL_LINKS"
  dict set numeric_mapping  "364" "unrealircd"      "RPL_LINKS"

  dict set numeric_mapping  "365" "global"          "RPL_ENDOFLINKS"
  dict set numeric_mapping  "365" "unrealircd"      "RPL_ENDOFLINKS"
  dict set numeric_mapping  "366" "global"          "RPL_ENDOFNAMES"
  # dict set numeric_mapping  "366" "unrealircd"      "RPL_ENDOFNAMES"
  # rpl_endofnames above (366) unrealircd
  dict set numeric_mapping  "367" "global"          "RPL_BANLIST"
  dict set numeric_mapping  "367" "unrealircd"      "RPL_BANLIST"
  dict set numeric_mapping  "368" "global"          "RPL_ENDOFBANLIST"
  dict set numeric_mapping  "368" "unrealircd"      "RPL_ENDOFBANLIST"
  # dict set numeric_mapping  "369" "unrealircd"      "RPL_ENDOFWHOWAS"
  # rpl_endofwhowas above (369) unrealircd
  dict set numeric_mapping  "369" "global"          "RPL_ENDOFWHOWAS"
  dict set numeric_mapping  "371" "global"          "RPL_INFO"
  dict set numeric_mapping  "371" "unrealircd"      "RPL_INFO"
  dict set numeric_mapping  "372" "global"          "RPL_MOTD"
  dict set numeric_mapping  "372" "unrealircd"      "RPL_MOTD"
  dict set numeric_mapping  "373" "global"          "RPL_INFOSTART"
  dict set numeric_mapping  "374" "global"          "RPL_ENDOFINFO"
  dict set numeric_mapping  "374" "unrealircd"      "RPL_ENDOFINFO"
  dict set numeric_mapping  "375" "global"          "RPL_MOTDSTART"
  dict set numeric_mapping  "375" "unrealircd"      "RPL_MOTDSTART"
  dict set numeric_mapping  "376" "global"          "RPL_ENDOFMOTD"
  dict set numeric_mapping  "376" "unrealircd"      "RPL_ENDOFMOTD"
  dict set numeric_mapping  "377" "aircd"           "RPL_KICKEXPIRED"
  dict set numeric_mapping  "377" "austhex"         "RPL_SPAM"
  dict set numeric_mapping  "377" "global"          "RPL_KICKEXPIRED"
  dict set numeric_mapping  "377" "global"          "RPL_SPAM"
  dict set numeric_mapping  "378" "aircd"           "RPL_BANEXPIRED"
  dict set numeric_mapping  "378" "austhex"         "RPL_MOTD"
  dict set numeric_mapping  "378" "global"          "RPL_BANEXPIRED"
  dict set numeric_mapping  "378" "global"          "RPL_MOTD"
  dict set numeric_mapping  "378" "global"          "RPL_WHOISHOST"
  dict set numeric_mapping  "378" "unrealircd"      "RPL_WHOISHOST"
  dict set numeric_mapping  "379" "aircd"           "RPL_KICKLINKED"
  dict set numeric_mapping  "379" "global"          "RPL_KICKLINKED"
  dict set numeric_mapping  "379" "global"          "RPL_WHOISMODES"
  dict set numeric_mapping  "379" "unrealircd"      "RPL_WHOISMODES"
  dict set numeric_mapping  "380" "aircd"           "RPL_BANLINKED"
  dict set numeric_mapping  "380" "austhex"         "RPL_YOURHELPER"
  dict set numeric_mapping  "380" "global"          "RPL_BANLINKED"
  dict set numeric_mapping  "380" "global"          "RPL_YOURHELPER"
  dict set numeric_mapping  "381" "global"          "RPL_YOUREOPER"
  dict set numeric_mapping  "381" "unrealircd"      "RPL_YOUREOPER"
  dict set numeric_mapping  "382" "global"          "RPL_REHASHING"
  dict set numeric_mapping  "382" "unrealircd"      "RPL_REHASHING"
  dict set numeric_mapping  "383" "global"          "RPL_YOURESERVICE"
  dict set numeric_mapping  "384" "global"          "RPL_MYPORTIS"
  dict set numeric_mapping  "385" "austhex"         "RPL_NOTOPERANYMORE"
  dict set numeric_mapping  "385" "global"          "RPL_NOTOPERANYMORE"
  dict set numeric_mapping  "385" "hybrid"          "RPL_NOTOPERANYMORE"
  dict set numeric_mapping  "386" "global"          "RPL_IRCOPS"
  dict set numeric_mapping  "386" "global"          "RPL_QLIST"
  dict set numeric_mapping  "386" "ultimate"        "RPL_IRCOPS"
  dict set numeric_mapping  "386" "unrealircd"      "RPL_QLIST"
  dict set numeric_mapping  "387" "global"          "RPL_ENDOFIRCOPS"
  dict set numeric_mapping  "387" "global"          "RPL_ENDOFQLIST"
  dict set numeric_mapping  "387" "ultimate"        "RPL_ENDOFIRCOPS"
  dict set numeric_mapping  "387" "unrealircd"      "RPL_ENDOFQLIST"
  dict set numeric_mapping  "388" "global"          "RPL_ALIST"
  dict set numeric_mapping  "388" "unrealircd"      "RPL_ALIST"
  dict set numeric_mapping  "389" "global"          "RPL_ENDOFALIST"
  dict set numeric_mapping  "389" "unrealircd"      "RPL_ENDOFALIST"
  dict set numeric_mapping  "391" "bdq-ircd"        "RPL_TIME"
  dict set numeric_mapping  "391" "global"          "RPL_TIME"
  dict set numeric_mapping  "391" "ircu"            "RPL_TIME"
  dict set numeric_mapping  "391" "unrealircd"      "RPL_TIME"
  dict set numeric_mapping  "392" "global"          "RPL_USERSSTART"
  dict set numeric_mapping  "392" "unrealircd"      "RPL_USERSSTART"
  dict set numeric_mapping  "393" "global"          "RPL_USERS"
  dict set numeric_mapping  "393" "unrealircd"      "RPL_USERS"
  dict set numeric_mapping  "394" "global"          "RPL_ENDOFUSERS"
  dict set numeric_mapping  "394" "unrealircd"      "RPL_ENDOFUSERS"
  dict set numeric_mapping  "395" "global"          "RPL_NOUSERS"
  dict set numeric_mapping  "395" "unrealircd"      "RPL_NOUSERS"
  dict set numeric_mapping  "396" "global"          "RPL_HOSTHIDDEN"
  dict set numeric_mapping  "396" "undernet"        "RPL_HOSTHIDDEN"
  dict set numeric_mapping  "396" "unrealircd"      "RPL_HOSTHIDDEN"
  dict set numeric_mapping  "400" "global"          "ERR_UNKNOWNERROR"
  dict set numeric_mapping  "401" "global"          "ERR_NOSUCHNICK"
  dict set numeric_mapping  "401" "unrealircd"      "ERR_NOSUCHNICK"
  dict set numeric_mapping  "402" "global"          "ERR_NOSUCHSERVER"
  dict set numeric_mapping  "402" "unrealircd"      "ERR_NOSUCHSERVER"
  dict set numeric_mapping  "403" "global"          "ERR_NOSUCHCHANNEL"
  dict set numeric_mapping  "403" "unrealircd"      "ERR_NOSUCHCHANNEL"
  dict set numeric_mapping  "404" "global"          "ERR_CANNOTSENDTOCHAN"
  dict set numeric_mapping  "404" "unrealircd"      "ERR_CANNOTSENDTOCHAN"
  dict set numeric_mapping  "405" "global"          "ERR_TOOMANYCHANNELS"
  dict set numeric_mapping  "405" "unrealircd"      "ERR_TOOMANYCHANNELS"
  dict set numeric_mapping  "406" "global"          "ERR_WASNOSUCHNICK"
  dict set numeric_mapping  "406" "unrealircd"      "ERR_WASNOSUCHNICK"
  dict set numeric_mapping  "407" "global"          "ERR_TOOMANYTARGETS"
  dict set numeric_mapping  "407" "unrealircd"      "ERR_TOOMANYTARGETS"
  dict set numeric_mapping  "408" "bahamut"         "ERR_NOCOLORSONCHAN"
  dict set numeric_mapping  "408" "global"          "ERR_NOCOLORSONCHAN"
  dict set numeric_mapping  "408" "global"          "ERR_NOSUCHSERVICE"
  dict set numeric_mapping  "409" "global"          "ERR_NOORIGIN"
  dict set numeric_mapping  "409" "unrealircd"      "ERR_NOORIGIN"
  dict set numeric_mapping  "410" "unrealircd"      "ERR_INVALIDCAPCMD"
  dict set numeric_mapping  "411" "global"          "ERR_NORECIPIENT"
  dict set numeric_mapping  "411" "unrealircd"      "ERR_NORECIPIENT"
  dict set numeric_mapping  "412" "global"          "ERR_NOTEXTTOSEND"
  dict set numeric_mapping  "412" "unrealircd"      "ERR_NOTEXTTOSEND"
  dict set numeric_mapping  "413" "global"          "ERR_NOTOPLEVEL"
  dict set numeric_mapping  "414" "global"          "ERR_WILDTOPLEVEL"
  dict set numeric_mapping  "415" "global"          "ERR_BADMASK"
  dict set numeric_mapping  "416" "global"          "ERR_QUERYTOOLONG"
  dict set numeric_mapping  "416" "global"          "ERR_TOOMANYMATCHES"
  dict set numeric_mapping  "416" "ircnet"          "ERR_TOOMANYMATCHES"
  dict set numeric_mapping  "416" "ircu"            "ERR_QUERYTOOLONG"
  dict set numeric_mapping  "416" "unrealircd"      "ERR_TOOMANYMATCHES"
  dict set numeric_mapping  "417" "unrealircd"      "ERR_INPUTTOOLONG"
  dict set numeric_mapping  "419" "aircd"           "ERR_LENGTHTRUNCATED"
  dict set numeric_mapping  "419" "global"          "ERR_LENGTHTRUNCATED"
  dict set numeric_mapping  "421" "global"          "ERR_UNKNOWNCOMMAND"
  dict set numeric_mapping  "421" "unrealircd"      "ERR_UNKNOWNCOMMAND"
  dict set numeric_mapping  "422" "global"          "ERR_NOMOTD"
  dict set numeric_mapping  "422" "unrealircd"      "ERR_NOMOTD"
  dict set numeric_mapping  "423" "global"          "ERR_NOADMININFO"
  dict set numeric_mapping  "423" "unrealircd"      "ERR_NOADMININFO"
  dict set numeric_mapping  "424" "global"          "ERR_FILEERROR"
  dict set numeric_mapping  "425" "global"          "ERR_NOOPERMOTD"
  dict set numeric_mapping  "425" "unrealircd"      "ERR_NOOPERMOTD"
  dict set numeric_mapping  "429" "bahamut"         "ERR_TOOMANYAWAY"
  dict set numeric_mapping  "429" "global"          "ERR_TOOMANYAWAY"
  dict set numeric_mapping  "429" "unrealircd"      "ERR_TOOMANYAWAY"
  dict set numeric_mapping  "430" "austhex"         "ERR_EVENTNICKCHANGE"
  dict set numeric_mapping  "430" "global"          "ERR_EVENTNICKCHANGE"
  dict set numeric_mapping  "431" "global"          "ERR_NONICKNAMEGIVEN"
  dict set numeric_mapping  "431" "unrealircd"      "ERR_NONICKNAMEGIVEN"
  dict set numeric_mapping  "432" "global"          "ERR_ERRONEUSNICKNAME"
  dict set numeric_mapping  "432" "unrealircd"      "ERR_ERRONEUSNICKNAME"
  dict set numeric_mapping  "433" "global"          "ERR_NICKNAMEINUSE"
  dict set numeric_mapping  "433" "unrealircd"      "ERR_NICKNAMEINUSE"
  dict set numeric_mapping  "434" "austhex"         "ERR_SERVICENAMEINUSE"
  dict set numeric_mapping  "434" "global"          "ERR_NORULES"
  dict set numeric_mapping  "434" "global"          "ERR_SERVICENAMEINUSE"
  dict set numeric_mapping  "434" "ultimate"        "ERR_NORULES"
  dict set numeric_mapping  "434" "unrealircd"      "ERR_NORULES"
  dict set numeric_mapping  "435" "bahamut"         "ERR_BANONCHAN"
  dict set numeric_mapping  "435" "global"          "ERR_BANONCHAN"
  dict set numeric_mapping  "435" "global"          "ERR_SERVICECONFUSED"
  dict set numeric_mapping  "436" "global"          "ERR_NICKCOLLISION"
  dict set numeric_mapping  "437" "global"          "ERR_BANNICKCHANGE"
  dict set numeric_mapping  "437" "global"          "ERR_UNAVAILRESOURCE"
  dict set numeric_mapping  "437" "ircu"            "ERR_BANNICKCHANGE"
  dict set numeric_mapping  "437" "unrealircd"      "ERR_BANNICKCHANGE"
  dict set numeric_mapping  "438" "global"          "ERR_DEAD"
  dict set numeric_mapping  "438" "global"          "ERR_NICKTOOFAST"
  dict set numeric_mapping  "438" "ircnet"          "ERR_DEAD"
  dict set numeric_mapping  "438" "ircu"            "ERR_NICKTOOFAST"
  dict set numeric_mapping  "438" "unrealircd"      "ERR_NCHANGETOOFAST"
  dict set numeric_mapping  "439" "global"          "ERR_TARGETTOOFAST"
  dict set numeric_mapping  "439" "ircu"            "ERR_TARGETTOOFAST"
  dict set numeric_mapping  "439" "unrealircd"      "ERR_TARGETTOOFAST"
  dict set numeric_mapping  "440" "bahamut"         "ERR_SERVICESDOWN"
  dict set numeric_mapping  "440" "global"          "ERR_SERVICESDOWN"
  dict set numeric_mapping  "440" "unrealircd"      "ERR_SERVICESDOWN"
  dict set numeric_mapping  "441" "global"          "ERR_USERNOTINCHANNEL"
  dict set numeric_mapping  "441" "unrealircd"      "ERR_USERNOTINCHANNEL"
  dict set numeric_mapping  "442" "global"          "ERR_NOTONCHANNEL"
  dict set numeric_mapping  "442" "unrealircd"      "ERR_NOTONCHANNEL"
  dict set numeric_mapping  "443" "global"          "ERR_USERONCHANNEL"
  dict set numeric_mapping  "443" "unrealircd"      "ERR_USERONCHANNEL"
  dict set numeric_mapping  "444" "global"          "ERR_NOLOGIN"
  dict set numeric_mapping  "445" "global"          "ERR_SUMMONDISABLED"
  dict set numeric_mapping  "446" "global"          "ERR_USERSDISABLED"
  dict set numeric_mapping  "447" "global"          "ERR_NONICKCHANGE"
  dict set numeric_mapping  "447" "unrealircd"      "ERR_NONICKCHANGE"
  dict set numeric_mapping  "448" "unrealircd"      "ERR_FORBIDDENCHANNEL"
  dict set numeric_mapping  "449" "global"          "ERR_NOTIMPLEMENTED"
  dict set numeric_mapping  "449" "undernet"        "ERR_NOTIMPLEMENTED"
  dict set numeric_mapping  "451" "global"          "ERR_NOTREGISTERED"
  dict set numeric_mapping  "451" "unrealircd"      "ERR_NOTREGISTERED"
  dict set numeric_mapping  "452" "global"          "ERR_IDCOLLISION"
  dict set numeric_mapping  "453" "global"          "ERR_NICKLOST"
  dict set numeric_mapping  "455" "global"          "ERR_HOSTILENAME"
  dict set numeric_mapping  "456" "global"          "ERR_ACCEPTFULL"
  dict set numeric_mapping  "457" "global"          "ERR_ACCEPTEXIST"
  dict set numeric_mapping  "458" "global"          "ERR_ACCEPTNOT"
  dict set numeric_mapping  "459" "global"          "ERR_NOHIDING"
  dict set numeric_mapping  "460" "global"          "ERR_NOTFORHALFOPS"
  dict set numeric_mapping  "460" "unrealircd"      "ERR_NOTFORHALFOPS"
  dict set numeric_mapping  "461" "global"          "ERR_NEEDMOREPARAMS"
  dict set numeric_mapping  "461" "unrealircd"      "ERR_NEEDMOREPARAMS"
  dict set numeric_mapping  "462" "global"          "ERR_ALREADYREGISTERED"
  dict set numeric_mapping  "462" "unrealircd"      "ERR_ALREADYREGISTRED"
  dict set numeric_mapping  "463" "global"          "ERR_NOPERMFORHOST"
  dict set numeric_mapping  "464" "global"          "ERR_PASSWDMISMATCH"
  dict set numeric_mapping  "464" "unrealircd"      "ERR_PASSWDMISMATCH"
  dict set numeric_mapping  "465" "global"          "ERR_YOUREBANNEDCREEP"
  dict set numeric_mapping  "465" "unrealircd"      "ERR_YOUREBANNEDCREEP"
  dict set numeric_mapping  "466" "global"          "ERR_YOUWILLBEBANNED"
  dict set numeric_mapping  "467" "global"          "ERR_KEYSET"
  dict set numeric_mapping  "468" "bahamut"         "ERR_ONLYSERVERSCANCHANGE"
  dict set numeric_mapping  "468" "global"          "ERR_INVALIDUSERNAME"
  dict set numeric_mapping  "468" "global"          "ERR_ONLYSERVERSCANCHANGE"
  dict set numeric_mapping  "468" "ircu"            "ERR_INVALIDUSERNAME"
  dict set numeric_mapping  "468" "unrealircd"      "ERR_ONLYSERVERSCANCHANGE"
  dict set numeric_mapping  "469" "global"          "ERR_LINKSET"
  dict set numeric_mapping  "470" "aircd"           "ERR_KICKEDFROMCHAN"
  dict set numeric_mapping  "470" "global"          "ERR_KICKEDFROMCHAN"
  dict set numeric_mapping  "470" "global"          "ERR_LINKCHANNEL"
  dict set numeric_mapping  "470" "unrealircd"      "ERR_LINKCHANNEL"
  dict set numeric_mapping  "471" "global"          "ERR_CHANNELISFULL"
  dict set numeric_mapping  "471" "unrealircd"      "ERR_CHANNELISFULL"
  dict set numeric_mapping  "472" "global"          "ERR_UNKNOWNMODE"
  dict set numeric_mapping  "472" "unrealircd"      "ERR_UNKNOWNMODE"
  dict set numeric_mapping  "473" "global"          "ERR_INVITEONLYCHAN"
  dict set numeric_mapping  "473" "unrealircd"      "ERR_INVITEONLYCHAN"
  dict set numeric_mapping  "474" "global"          "ERR_BANNEDFROMCHAN"
  dict set numeric_mapping  "474" "unrealircd"      "ERR_BANNEDFROMCHAN"
  dict set numeric_mapping  "475" "global"          "ERR_BADCHANNELKEY"
  dict set numeric_mapping  "475" "unrealircd"      "ERR_BADCHANNELKEY"
  dict set numeric_mapping  "476" "global"          "ERR_BADCHANMASK"
  dict set numeric_mapping  "477" "bahamut"         "ERR_NEEDREGGEDNICK"
  dict set numeric_mapping  "477" "global"          "ERR_NEEDREGGEDNICK"
  dict set numeric_mapping  "477" "global"          "ERR_NOCHANMODES"
  dict set numeric_mapping  "477" "ircu"            "ERR_NEEDREGGEDNICK"
  dict set numeric_mapping  "477" "unrealircd"      "ERR_NEEDREGGEDNICK"
  dict set numeric_mapping  "478" "global"          "ERR_BANLISTFULL"
  dict set numeric_mapping  "478" "unrealircd"      "ERR_BANLISTFULL"
  dict set numeric_mapping  "479" "global"          "ERR_BADCHANNAME"
  dict set numeric_mapping  "479" "global"          "ERR_LINKFAIL"
  dict set numeric_mapping  "479" "hybrid"          "ERR_BADCHANNAME"
  dict set numeric_mapping  "480" "austhex"         "ERR_NOULINE"
  dict set numeric_mapping  "480" "global"          "ERR_CANNOTKNOCK"
  dict set numeric_mapping  "480" "global"          "ERR_NOULINE"
  dict set numeric_mapping  "480" "unrealircd"      "ERR_CANNOTKNOCK"
  dict set numeric_mapping  "481" "global"          "ERR_NOPRIVILEGES"
  dict set numeric_mapping  "481" "unrealircd"      "ERR_NOPRIVILEGES"
  dict set numeric_mapping  "482" "global"          "ERR_CHANOPRIVSNEEDED"
  dict set numeric_mapping  "482" "unrealircd"      "ERR_CHANOPRIVSNEEDED"
  dict set numeric_mapping  "483" "global"          "ERR_CANTKILLSERVER"
  dict set numeric_mapping  "484" "bahamut"         "ERR_DESYNC"
  dict set numeric_mapping  "484" "global"          "ERR_ATTACKDENY"
  dict set numeric_mapping  "484" "global"          "ERR_DESYNC"
  dict set numeric_mapping  "484" "global"          "ERR_ISCHANSERVICE"
  dict set numeric_mapping  "484" "global"          "ERR_RESTRICTED"
  dict set numeric_mapping  "484" "hybrid"          "ERR_DESYNC"
  dict set numeric_mapping  "484" "ptlink"          "ERR_DESYNC"
  dict set numeric_mapping  "484" "undernet"        "ERR_ISCHANSERVICE"
  dict set numeric_mapping  "485" "global"          "ERR_CANTKICKADMIN"
  dict set numeric_mapping  "485" "global"          "ERR_ISREALSERVICE"
  dict set numeric_mapping  "485" "global"          "ERR_KILLDENY"
  dict set numeric_mapping  "485" "global"          "ERR_UNIQOPRIVSNEEDED"
  dict set numeric_mapping  "485" "ptlink"          "ERR_CANTKICKADMIN"
  dict set numeric_mapping  "485" "quakenet"        "ERR_ISREALSERVICE"
  dict set numeric_mapping  "485" "unrealircd"      "ERR_KILLDENY"
  dict set numeric_mapping  "486" "global"          "ERR_ACCOUNTONLY"
  dict set numeric_mapping  "486" "global"          "ERR_HTMDISABLED"
  dict set numeric_mapping  "486" "global"          "ERR_NONONREG"
  dict set numeric_mapping  "486" "quakenet"        "ERR_ACCOUNTONLY"
  dict set numeric_mapping  "487" "bahamut"         "ERR_MSGSERVICES"
  dict set numeric_mapping  "487" "global"          "ERR_CHANTOORECENT"
  dict set numeric_mapping  "487" "global"          "ERR_MSGSERVICES"
  dict set numeric_mapping  "487" "ircnet"          "ERR_CHANTOORECENT"
  dict set numeric_mapping  "487" "unrealircd"      "ERR_NOTFORUSERS"
  dict set numeric_mapping  "488" "global"          "ERR_TSLESSCHAN"
  dict set numeric_mapping  "488" "ircnet"          "ERR_TSLESSCHAN"
  dict set numeric_mapping  "489" "global"          "ERR_SECUREONLYCHAN"
  dict set numeric_mapping  "489" "global"          "ERR_VOICENEEDED"
  dict set numeric_mapping  "489" "undernet"        "ERR_VOICENEEDED"
  dict set numeric_mapping  "489" "unrealircd"      "ERR_SECUREONLYCHAN"
  dict set numeric_mapping  "491" "global"          "ERR_NOOPERHOST"
  dict set numeric_mapping  "491" "unrealircd"      "ERR_NOOPERHOST"
  dict set numeric_mapping  "492" "global"          "ERR_NOSERVICEHOST"
  dict set numeric_mapping  "493" "global"          "ERR_NOFEATURE"
  dict set numeric_mapping  "493" "ircu"            "ERR_NOFEATURE"
  dict set numeric_mapping  "494" "global"          "ERR_BADFEATURE"
  dict set numeric_mapping  "494" "ircu"            "ERR_BADFEATURE"
  dict set numeric_mapping  "495" "global"          "ERR_BADLOGTYPE"
  dict set numeric_mapping  "495" "ircu"            "ERR_BADLOGTYPE"
  dict set numeric_mapping  "496" "global"          "ERR_BADLOGSYS"
  dict set numeric_mapping  "496" "ircu"            "ERR_BADLOGSYS"
  dict set numeric_mapping  "497" "global"          "ERR_BADLOGVALUE"
  dict set numeric_mapping  "497" "ircu"            "ERR_BADLOGVALUE"
  dict set numeric_mapping  "498" "global"          "ERR_ISOPERLCHAN"
  dict set numeric_mapping  "498" "ircu"            "ERR_ISOPERLCHAN"
  dict set numeric_mapping  "499" "global"          "ERR_CHANOWNPRIVNEEDED"
  dict set numeric_mapping  "499" "unrealircd"      "ERR_CHANOWNPRIVNEEDED"
  dict set numeric_mapping  "500" "unrealircd"      "ERR_TOOMANYJOINS"
  dict set numeric_mapping  "501" "global"          "ERR_UMODEUNKNOWNFLAG"
  dict set numeric_mapping  "501" "unrealircd"      "ERR_UMODEUNKNOWNFLAG"
  dict set numeric_mapping  "502" "global"          "ERR_USERSDONTMATCH"
  dict set numeric_mapping  "502" "unrealircd"      "ERR_USERSDONTMATCH"
  dict set numeric_mapping  "503" "austhex"         "ERR_VWORLDWARN"
  dict set numeric_mapping  "503" "global"          "ERR_GHOSTEDCLIENT"
  dict set numeric_mapping  "503" "global"          "ERR_VWORLDWARN"
  dict set numeric_mapping  "503" "hybrid"          "ERR_GHOSTEDCLIENT"
  dict set numeric_mapping  "504" "global"          "ERR_USERNOTONSERV"
  dict set numeric_mapping  "511" "global"          "ERR_SILELISTFULL"
  dict set numeric_mapping  "511" "ircu"            "ERR_SILELISTFULL"
  dict set numeric_mapping  "511" "unrealircd"      "ERR_SILELISTFULL"
  dict set numeric_mapping  "512" "bahamut"         "ERR_TOOMANYWATCH"
  dict set numeric_mapping  "512" "global"          "ERR_TOOMANYWATCH"
  dict set numeric_mapping  "512" "unrealircd"      "ERR_TOOMANYWATCH"
  dict set numeric_mapping  "513" "global"          "ERR_BADPING"
  dict set numeric_mapping  "513" "ircu"            "ERR_BADPING"
  dict set numeric_mapping  "514" "bahamut"         "ERR_TOOMANYDCC"
  dict set numeric_mapping  "514" "global"          "ERR_INVALID_ERROR"
  dict set numeric_mapping  "514" "global"          "ERR_TOOMANYDCC"
  dict set numeric_mapping  "514" "ircu"            "ERR_INVALID_ERROR"
  dict set numeric_mapping  "514" "unrealircd"      "ERR_TOOMANYDCC"
  dict set numeric_mapping  "515" "global"          "ERR_BADEXPIRE"
  dict set numeric_mapping  "515" "ircu"            "ERR_BADEXPIRE"
  dict set numeric_mapping  "516" "global"          "ERR_DONTCHEAT"
  dict set numeric_mapping  "516" "ircu"            "ERR_DONTCHEAT"
  dict set numeric_mapping  "517" "global"          "ERR_DISABLED"
  dict set numeric_mapping  "517" "ircu"            "ERR_DISABLED"
  dict set numeric_mapping  "517" "unrealircd"      "ERR_DISABLED"
  dict set numeric_mapping  "518" "global"          "ERR_LONGMASK"
  dict set numeric_mapping  "518" "global"          "ERR_NOINVITE"
  dict set numeric_mapping  "518" "ircu"            "ERR_LONGMASK"
  dict set numeric_mapping  "518" "unrealircd"      "ERR_NOINVITE"
  dict set numeric_mapping  "519" "global"          "ERR_ADMONLY"
  dict set numeric_mapping  "519" "global"          "ERR_TOOMANYUSERS"
  dict set numeric_mapping  "519" "ircu"            "ERR_TOOMANYUSERS"
  dict set numeric_mapping  "520" "austhex"         "ERR_WHOTRUNC"
  dict set numeric_mapping  "520" "global"          "ERR_MASKTOOWIDE"
  dict set numeric_mapping  "520" "global"          "ERR_OPERONLY"
  dict set numeric_mapping  "520" "global"          "ERR_WHOTRUNC"
  dict set numeric_mapping  "520" "ircu"            "ERR_MASKTOOWIDE"
  dict set numeric_mapping  "520" "unrealircd"      "ERR_OPERONLY"
  dict set numeric_mapping  "521" "bahamut"         "ERR_LISTSYNTAX"
  dict set numeric_mapping  "521" "global"          "ERR_LISTSYNTAX"
  dict set numeric_mapping  "521" "unrealircd"      "ERR_LISTSYNTAX"
  dict set numeric_mapping  "522" "bahamut"         "ERR_WHOSYNTAX"
  dict set numeric_mapping  "522" "global"          "ERR_WHOSYNTAX"
  dict set numeric_mapping  "523" "bahamut"         "ERR_WHOLIMEXCEED"
  dict set numeric_mapping  "523" "global"          "ERR_WHOLIMEXCEED"
  dict set numeric_mapping  "523" "unrealircd"      "ERR_WHOLIMEXCEED"
  dict set numeric_mapping  "524" "global"          "ERR_OPERSPVERIFY"
  dict set numeric_mapping  "524" "global"          "ERR_QUARANTINED"
  dict set numeric_mapping  "524" "ircu"            "ERR_QUARANTINED"
  dict set numeric_mapping  "524" "unrealircd"      "ERR_OPERSPVERIFY"
  dict set numeric_mapping  "525" "global"          "ERR_REMOTEPFX"
  dict set numeric_mapping  "526" "global"          "ERR_PFXUNROUTABLE"
  dict set numeric_mapping  "531" "unrealircd"      "ERR_CANTSENDTOUSER"
  dict set numeric_mapping  "550" "global"          "ERR_BADHOSTMASK"
  dict set numeric_mapping  "550" "quakenet"        "ERR_BADHOSTMASK"
  dict set numeric_mapping  "551" "global"          "ERR_HOSTUNAVAIL"
  dict set numeric_mapping  "551" "quakenet"        "ERR_HOSTUNAVAIL"
  dict set numeric_mapping  "552" "global"          "ERR_USINGSLINE"
  dict set numeric_mapping  "552" "quakenet"        "ERR_USINGSLINE"
  dict set numeric_mapping  "553" "global"          "ERR_STATSSLINE"
  dict set numeric_mapping  "553" "quakenet"        "ERR_STATSSLINE"
  dict set numeric_mapping  "597" "unrealircd"      "RPL_REAWAY"
  dict set numeric_mapping  "598" "unrealircd"      "RPL_GONEAWAY"
  dict set numeric_mapping  "599" "unrealircd"      "RPL_NOTAWAY"

  # Numberic replies from server commands.
  # These are also in the range 600-799.
  dict set numeric_mapping  "600" "bahamut"         "RPL_LOGON"
  dict set numeric_mapping  "600" "global"          "RPL_LOGON"
  dict set numeric_mapping  "600" "unrealircd"      "RPL_LOGON"
  dict set numeric_mapping  "601" "bahamut"         "RPL_LOGOFF"
  dict set numeric_mapping  "601" "global"          "RPL_LOGOFF"
  dict set numeric_mapping  "601" "unrealircd"      "RPL_LOGOFF"
  dict set numeric_mapping  "602" "bahamut"         "RPL_WATCHOFF"
  dict set numeric_mapping  "602" "global"          "RPL_WATCHOFF"
  dict set numeric_mapping  "602" "unrealircd"      "RPL_WATCHOFF"
  dict set numeric_mapping  "603" "bahamut"         "RPL_WATCHSTAT"
  dict set numeric_mapping  "603" "global"          "RPL_WATCHSTAT"
  dict set numeric_mapping  "603" "unrealircd"      "RPL_WATCHSTAT"
  dict set numeric_mapping  "604" "bahamut"         "RPL_NOWON"
  dict set numeric_mapping  "604" "global"          "RPL_NOWON"
  dict set numeric_mapping  "604" "unrealircd"      "RPL_NOWON"
  dict set numeric_mapping  "605" "bahamut"         "RPL_NOWOFF"
  dict set numeric_mapping  "605" "global"          "RPL_NOWOFF"
  dict set numeric_mapping  "605" "unrealircd"      "RPL_NOWOFF"
  dict set numeric_mapping  "606" "bahamut"         "RPL_WATCHLIST"
  dict set numeric_mapping  "606" "global"          "RPL_WATCHLIST"
  dict set numeric_mapping  "606" "unrealircd"      "RPL_WATCHLIST"
  dict set numeric_mapping  "607" "bahamut"         "RPL_ENDOFWATCHLIST"
  dict set numeric_mapping  "607" "global"          "RPL_ENDOFWATCHLIST"
  dict set numeric_mapping  "607" "unrealircd"      "RPL_ENDOFWATCHLIST"
  dict set numeric_mapping  "608" "global"          "RPL_WATCHCLEAR"
  dict set numeric_mapping  "608" "ultimate"        "RPL_WATCHCLEAR"
  dict set numeric_mapping  "609" "unrealircd"      "RPL_NOWISAWAY"
  dict set numeric_mapping  "610" "global"          "RPL_ISOPER"
  dict set numeric_mapping  "610" "global"          "RPL_MAPMORE"
  dict set numeric_mapping  "610" "ultimate"        "RPL_ISOPER"
  # dict set numeric_mapping  "610" "unrealircd"      "RPL_MAPMORE" see 006
  dict set numeric_mapping  "611" "global"          "RPL_ISLOCOP"
  dict set numeric_mapping  "611" "ultimate"        "RPL_ISLOCOP"
  dict set numeric_mapping  "612" "global"          "RPL_ISNOTOPER"
  dict set numeric_mapping  "612" "ultimate"        "RPL_ISNOTOPER"
  dict set numeric_mapping  "613" "global"          "RPL_ENDOFISOPER"
  dict set numeric_mapping  "613" "ultimate"        "RPL_ENDOFISOPER"
  dict set numeric_mapping  "615" "global"          "RPL_MAPMORE"
  dict set numeric_mapping  "615" "global"          "RPL_WHOISMODES"
  dict set numeric_mapping  "615" "ptlink"          "RPL_MAPMORE"
  dict set numeric_mapping  "615" "ultimate"        "RPL_WHOISMODES"
  dict set numeric_mapping  "616" "global"          "RPL_WHOISHOST"
  dict set numeric_mapping  "616" "ultimate"        "RPL_WHOISHOST"
  dict set numeric_mapping  "617" "bahamut"         "RPL_DCCSTATUS"
  dict set numeric_mapping  "617" "global"          "RPL_DCCSTATUS"
  dict set numeric_mapping  "617" "global"          "RPL_WHOISBOT"
  dict set numeric_mapping  "617" "ultimate"        "RPL_WHOISBOT"
  dict set numeric_mapping  "617" "unrealircd"      "RPL_DCCSTATUS"
  dict set numeric_mapping  "618" "bahamut"         "RPL_DCCLIST"
  dict set numeric_mapping  "618" "global"          "RPL_DCCLIST"
  dict set numeric_mapping  "618" "unrealircd"      "RPL_DCCLIST"
  dict set numeric_mapping  "619" "bahamut"         "RPL_ENDOFDCCLIST"
  dict set numeric_mapping  "619" "global"          "RPL_ENDOFDCCLIST"
  dict set numeric_mapping  "619" "global"          "RPL_WHOWASHOST"
  dict set numeric_mapping  "619" "ultimate"        "RPL_WHOWASHOST"
  dict set numeric_mapping  "619" "unrealircd"      "RPL_ENDOFDCCLIST"
  dict set numeric_mapping  "620" "bahamut"         "RPL_DCCINFO"
  dict set numeric_mapping  "620" "global"          "RPL_DCCINFO"
  dict set numeric_mapping  "620" "global"          "RPL_RULESSTART"
  dict set numeric_mapping  "620" "ultimate"        "RPL_RULESSTART"
  dict set numeric_mapping  "620" "unrealircd"      "RPL_DCCINFO"
  dict set numeric_mapping  "621" "global"          "RPL_RULES"
  dict set numeric_mapping  "621" "ultimate"        "RPL_RULES"
  dict set numeric_mapping  "622" "global"          "RPL_ENDOFRULES"
  dict set numeric_mapping  "622" "ultimate"        "RPL_ENDOFRULES"
  dict set numeric_mapping  "623" "global"          "RPL_MAPMORE"
  dict set numeric_mapping  "623" "ultimate"        "RPL_MAPMORE"
  dict set numeric_mapping  "624" "global"          "RPL_OMOTDSTART"
  dict set numeric_mapping  "624" "ultimate"        "RPL_OMOTDSTART"
  dict set numeric_mapping  "625" "global"          "RPL_OMOTD"
  dict set numeric_mapping  "625" "ultimate"        "RPL_OMOTD"
  dict set numeric_mapping  "626" "global"          "RPL_ENDOFO"
  dict set numeric_mapping  "626" "ultimate"        "RPL_ENDOFO"
  dict set numeric_mapping  "630" "global"          "RPL_SETTINGS"
  dict set numeric_mapping  "630" "ultimate"        "RPL_SETTINGS"
  dict set numeric_mapping  "631" "global"          "RPL_ENDOFSETTINGS"
  dict set numeric_mapping  "631" "ultimate"        "RPL_ENDOFSETTINGS"
  dict set numeric_mapping  "640" "global"          "RPL_DUMPING"
  dict set numeric_mapping  "641" "global"          "RPL_DUMPRPL"
  dict set numeric_mapping  "642" "global"          "RPL_EODUMP"
  dict set numeric_mapping  "659" "unrealircd"      "RPL_SPAMCMDFWD"
  dict set numeric_mapping  "660" "global"          "RPL_TRACEROUTE_HOP"
  dict set numeric_mapping  "660" "kineircd"        "RPL_TRACEROUTE_HOP"
  dict set numeric_mapping  "661" "global"          "RPL_TRACEROUTE_START"
  dict set numeric_mapping  "661" "kineircd"        "RPL_TRACEROUTE_START"
  dict set numeric_mapping  "662" "global"          "RPL_MODECHANGEWARN"
  dict set numeric_mapping  "662" "kineircd"        "RPL_MODECHANGEWARN"
  dict set numeric_mapping  "663" "global"          "RPL_CHANREDIR"
  dict set numeric_mapping  "663" "kineircd"        "RPL_CHANREDIR"
  dict set numeric_mapping  "664" "global"          "RPL_SERVMODEIS"
  dict set numeric_mapping  "664" "kineircd"        "RPL_SERVMODEIS"
  dict set numeric_mapping  "665" "global"          "RPL_OTHERUMODEIS"
  dict set numeric_mapping  "665" "kineircd"        "RPL_OTHERUMODEIS"
  dict set numeric_mapping  "666" "global"          "RPL_ENDOF_GENERIC"
  dict set numeric_mapping  "666" "kineircd"        "RPL_ENDOF_GENERIC"
  dict set numeric_mapping  "670" "global"          "RPL_WHOWASDETAILS"
  dict set numeric_mapping  "670" "kineircd"        "RPL_WHOWASDETAILS"
  dict set numeric_mapping  "670" "unrealircd"      "RPL_STARTTLS"
  dict set numeric_mapping  "671" "global"          "RPL_WHOISSECURE"
  dict set numeric_mapping  "671" "kineircd"        "RPL_WHOISSECURE"
  dict set numeric_mapping  "671" "unrealircd"      "RPL_WHOISSECURE"
  dict set numeric_mapping  "672" "global"          "RPL_UNKNOWNMODES"
  dict set numeric_mapping  "672" "ithildin"        "RPL_UNKNOWNMODES"
  dict set numeric_mapping  "673" "global"          "RPL_CANNOTSETMODES"
  dict set numeric_mapping  "673" "ithildin"        "RPL_CANNOTSETMODES"
  dict set numeric_mapping  "678" "global"          "RPL_LUSERSTAFF"
  dict set numeric_mapping  "678" "kineircd"        "RPL_LUSERSTAFF"
  dict set numeric_mapping  "679" "global"          "RPL_TIMEONSERVERIS"
  dict set numeric_mapping  "679" "kineircd"        "RPL_TIMEONSERVERIS"
  dict set numeric_mapping  "682" "global"          "RPL_NETWORKS"
  dict set numeric_mapping  "682" "kineircd"        "RPL_NETWORKS"
  dict set numeric_mapping  "687" "global"          "RPL_YOURLANGUAGEIS"
  dict set numeric_mapping  "687" "kineircd"        "RPL_YOURLANGUAGEIS"
  dict set numeric_mapping  "688" "global"          "RPL_LANGUAGE"
  dict set numeric_mapping  "688" "kineircd"        "RPL_LANGUAGE"
  dict set numeric_mapping  "689" "global"          "RPL_WHOISSTAFF"
  dict set numeric_mapping  "689" "kineircd"        "RPL_WHOISSTAFF"
  dict set numeric_mapping  "690" "global"          "RPL_WHOISLANGUAGE"
  dict set numeric_mapping  "690" "kineircd"        "RPL_WHOISLANGUAGE"
  dict set numeric_mapping  "691" "unrealircd"      "ERR_STARTTLS"
  dict set numeric_mapping  "696" "unrealircd"      "ERR_INVALIDMODEPARAM"
  dict set numeric_mapping  "702" "global"          "RPL_MODLIST"
  dict set numeric_mapping  "702" "ratbox"          "RPL_MODLIST"
  dict set numeric_mapping  "703" "global"          "RPL_ENDOFMODLIST"
  dict set numeric_mapping  "703" "ratbox"          "RPL_ENDOFMODLIST"
  dict set numeric_mapping  "704" "global"          "RPL_HELPSTART"
  dict set numeric_mapping  "704" "ratbox"          "RPL_HELPSTART"
  dict set numeric_mapping  "705" "global"          "RPL_HELPTXT"
  dict set numeric_mapping  "705" "ratbox"          "RPL_HELPTXT"
  dict set numeric_mapping  "706" "global"          "RPL_ENDOFHELP"
  dict set numeric_mapping  "706" "ratbox"          "RPL_ENDOFHELP"
  dict set numeric_mapping  "708" "global"          "RPL_ETRACEFULL"
  dict set numeric_mapping  "708" "ratbox"          "RPL_ETRACEFULL"
  dict set numeric_mapping  "709" "global"          "RPL_ETRACE"
  dict set numeric_mapping  "709" "ratbox"          "RPL_ETRACE"
  dict set numeric_mapping  "710" "global"          "RPL_KNOCK"
  dict set numeric_mapping  "710" "ratbox"          "RPL_KNOCK"
  dict set numeric_mapping  "711" "global"          "RPL_KNOCKDLVR"
  dict set numeric_mapping  "711" "ratbox"          "RPL_KNOCKDLVR"
  dict set numeric_mapping  "712" "global"          "ERR_TOOMANYKNOCK"
  dict set numeric_mapping  "712" "ratbox"          "ERR_TOOMANYKNOCK"
  dict set numeric_mapping  "713" "global"          "ERR_CHANOPEN"
  dict set numeric_mapping  "713" "ratbox"          "ERR_CHANOPEN"
  dict set numeric_mapping  "714" "global"          "ERR_KNOCKONCHAN"
  dict set numeric_mapping  "714" "ratbox"          "ERR_KNOCKONCHAN"
  dict set numeric_mapping  "715" "global"          "ERR_KNOCKDISABLED"
  dict set numeric_mapping  "715" "ratbox"          "ERR_KNOCKDISABLED"
  dict set numeric_mapping  "716" "global"          "RPL_TARGUMODEG"
  dict set numeric_mapping  "716" "ratbox"          "RPL_TARGUMODEG"
  dict set numeric_mapping  "717" "global"          "RPL_TARGNOTIFY"
  dict set numeric_mapping  "717" "ratbox"          "RPL_TARGNOTIFY"
  dict set numeric_mapping  "718" "global"          "RPL_UMODEGMSG"
  dict set numeric_mapping  "718" "ratbox"          "RPL_UMODEGMSG"
  dict set numeric_mapping  "720" "global"          "RPL_OMOTDSTART"
  dict set numeric_mapping  "720" "ratbox"          "RPL_OMOTDSTART"
  dict set numeric_mapping  "721" "global"          "RPL_OMOTD"
  dict set numeric_mapping  "721" "ratbox"          "RPL_OMOTD"
  dict set numeric_mapping  "722" "global"          "RPL_ENDOFOMOTD"
  dict set numeric_mapping  "722" "ratbox"          "RPL_ENDOFOMOTD"
  dict set numeric_mapping  "723" "global"          "ERR_NOPRIVS"
  dict set numeric_mapping  "723" "ratbox"          "ERR_NOPRIVS"
  dict set numeric_mapping  "724" "global"          "RPL_TESTMARK"
  dict set numeric_mapping  "724" "ratbox"          "RPL_TESTMARK"
  dict set numeric_mapping  "725" "global"          "RPL_TESTLINE"
  dict set numeric_mapping  "725" "ratbox"          "RPL_TESTLINE"
  dict set numeric_mapping  "726" "global"          "RPL_NOTESTLINE"
  dict set numeric_mapping  "726" "ratbox"          "RPL_NOTESTLINE"
  dict set numeric_mapping  "730" "unrealircd"      "RPL_MONONLINE"
  dict set numeric_mapping  "731" "unrealircd"      "RPL_MONOFFLINE"
  dict set numeric_mapping  "732" "unrealircd"      "RPL_MONLIST"
  dict set numeric_mapping  "733" "unrealircd"      "RPL_ENDOFMONLIST"
  dict set numeric_mapping  "734" "unrealircd"      "ERR_MONLISTFULL"
  dict set numeric_mapping  "742" "unrealircd"      "ERR_MLOCKRESTRICTED"
  dict set numeric_mapping  "771" "global"          "RPL_XINFO"
  dict set numeric_mapping  "771" "ithildin"        "RPL_XINFO"
  dict set numeric_mapping  "773" "global"          "RPL_LOGGEDIN"
  dict set numeric_mapping  "773" "global"          "RPL_XINFOSTART"
  dict set numeric_mapping  "773" "ithildin"        "RPL_XINFOSTART"
  dict set numeric_mapping  "774" "global"          "RPL_XINFOEND"
  dict set numeric_mapping  "774" "ithildin"        "RPL_XINFOEND"
  dict set numeric_mapping  "900" "unrealircd"      "RPL_LOGGEDIN"
  dict set numeric_mapping  "901" "unrealircd"      "RPL_LOGGEDOUT"
  dict set numeric_mapping  "903" "unrealircd"      "RPL_SASLSUCCESS"
  dict set numeric_mapping  "904" "unrealircd"      "ERR_SASLFAIL"
  dict set numeric_mapping  "905" "unrealircd"      "ERR_SASLTOOLONG"
  dict set numeric_mapping  "906" "unrealircd"      "ERR_SASLABORTED"
  dict set numeric_mapping  "908" "unrealircd"      "RPL_SASLMECHS"
  dict set numeric_mapping  "972" "global"          "ERR_CANNOTDOCOMMAND"
  dict set numeric_mapping  "972" "unrealircd"      "ERR_CANNOTDOCOMMAND"
  dict set numeric_mapping  "973" "global"          "ERR_CANNOTCHANGEUMODE"
  dict set numeric_mapping  "973" "kineircd"        "ERR_CANNOTCHANGEUMODE"
  dict set numeric_mapping  "974" "global"          "ERR_CANNOTCHANGECHANMODE"
  dict set numeric_mapping  "974" "kineircd"        "ERR_CANNOTCHANGECHANMODE"
  dict set numeric_mapping  "974" "unrealircd"      "ERR_CANNOTCHANGECHANMODE"
  dict set numeric_mapping  "975" "global"          "ERR_CANNOTCHANGESERVERMODE"
  dict set numeric_mapping  "975" "kineircd"        "ERR_CANNOTCHANGESERVERMODE"
  dict set numeric_mapping  "976" "global"          "ERR_CANNOTSENDTONICK"
  dict set numeric_mapping  "976" "kineircd"        "ERR_CANNOTSENDTONICK"
  dict set numeric_mapping  "977" "global"          "ERR_UNKNOWNSERVERMODE"
  dict set numeric_mapping  "977" "kineircd"        "ERR_UNKNOWNSERVERMODE"
  dict set numeric_mapping  "979" "global"          "ERR_SERVERMODELOCK"
  dict set numeric_mapping  "979" "kineircd"        "ERR_SERVERMODELOCK"
  dict set numeric_mapping  "980" "global"          "ERR_BADCHARENCODING"
  dict set numeric_mapping  "980" "kineircd"        "ERR_BADCHARENCODING"
  dict set numeric_mapping  "981" "global"          "ERR_TOOMANYLANGUAGES"
  dict set numeric_mapping  "981" "kineircd"        "ERR_TOOMANYLANGUAGES"
  dict set numeric_mapping  "982" "global"          "ERR_NOLANGUAGE"
  dict set numeric_mapping  "982" "kineircd"        "ERR_NOLANGUAGE"
  dict set numeric_mapping  "983" "global"          "ERR_TEXTTOOSHORT"
  dict set numeric_mapping  "983" "kineircd"        "ERR_TEXTTOOSHORT"
  dict set numeric_mapping  "999" "bahamut"         "ERR_NUMERIC_ERR"
  dict set numeric_mapping  "999" "global"          "ERR_NUMERIC_ERR"

  # /* Numeric texts unrealircd */

  #define STR_RPL_WELCOME			/* 001 */	":Welcome to the %s IRC Network %s!%s@%s"
  #define STR_RPL_YOURHOST		/* 002 */	":Your host is %s, running version %s"
  #define STR_RPL_CREATED			/* 003 */	":This server was created %s"
  #define STR_RPL_MYINFO			/* 004 */	"%s %s %s %s"
  #define STR_RPL_ISUPPORT		/* 005 */	"%s :are supported by this server"
  #define STR_RPL_MAP			/* 006 */	":%s%s %s | Users: %*ld (%*.2f%%)%s"
  #define STR_RPL_MAPEND			/* 007 */	":End of /MAP"
  #define STR_RPL_SNOMASK			/* 008 */	"+%s :Server notice mask"
  #define STR_RPL_REDIR			/* 010 */	"%s %d :Please use this Server/Port instead"
  #define STR_RPL_MAPUSERS		/* 018 */	":%d server%s and %d user%s, average %.2f users per server"
  #define STR_RPL_REMOTEISUPPORT		/* 105 */	"%s :are supported by this server"
  #define STR_RPL_TRACELINK		/* 200 */	"Link %s%s %s %s"
  #define STR_RPL_TRACECONNECTING		/* 201 */	"Attempt %s %s"
  #define STR_RPL_TRACEHANDSHAKE		/* 202 */	"Handshaking %s %s"
  #define STR_RPL_TRACEUNKNOWN		/* 203 */	"???? %s %s"
  #define STR_RPL_TRACEOPERATOR		/* 204 */	"Operator %s %s [%s] %lld"
  #define STR_RPL_TRACEUSER		/* 205 */	"User %s %s [%s] %lld"
  #define STR_RPL_TRACESERVER		/* 206 */	"Server %s %dS %dC %s %s!%s@%s %lld"
  #define STR_RPL_TRACENEWTYPE		/* 208 */	"%s 0 %s"
  #define STR_RPL_TRACECLASS		/* 209 */	"Class %s %d"
  #define STR_RPL_STATSHELP		/* 210 */	":%s"
  #define STR_RPL_STATSCOMMANDS		/* 212 */	"%s %u %lu"
  #define STR_RPL_STATSCLINE		/* 213 */	"%c %s * %s %d %d %s"
  #define STR_RPL_STATSILINE		/* 215 */	"I %s %s %d %d %s %s %d"
  #define STR_RPL_STATSQLINE		/* 217 */	"%c %s %lld %lld %s :%s"
  #define STR_RPL_STATSYLINE		/* 218 */	"Y %s %d %d %d %d %d"
  #define STR_RPL_ENDOFSTATS		/* 219 */	"%c :End of /STATS report"
  #define STR_RPL_UMODEIS			/* 221 */	"%s"
  #define STR_RPL_STATSGLINE		/* 223 */	"%c %s %lld %lld %s :%s"
  #define STR_RPL_STATSTLINE		/* 224 */	"T %s %s %s"
  #define STR_RPL_STATSNLINE		/* 226 */	"n %s %s"
  #define STR_RPL_STATSVLINE		/* 227 */	"v %s %s %s"
  #define STR_RPL_STATSBANVER		/* 228 */	"%s %s"
  #define STR_RPL_STATSSPAMF		/* 229 */	"%c %s %s %s %lld %lld %lld %s %s :%s"
  #define STR_RPL_STATSEXCEPTTKL		/* 230 */	"%s %s %lld %lld %s :%s"
  #define STR_RPL_RULES			/* 232 */	":- %s"
  #define STR_RPL_STATSLLINE		/* 241 */	"%c %s * %s %d %d"
  #define STR_RPL_STATSUPTIME		/* 242 */	":Server Up %lld days, %lld:%02lld:%02lld"
  #define STR_RPL_STATSOLINE		/* 243 */	"%c %s * %s %s %s"
  #define STR_RPL_STATSHLINE		/* 244 */	"%c %s * %s %d %d"
  #define STR_RPL_STATSXLINE		/* 247 */	"X %s %d"
  #define STR_RPL_STATSULINE		/* 248 */	"U %s"
  #define STR_RPL_STATSDEBUG		/* 249 */	":%s"
  #define STR_RPL_STATSCONN		/* 250 */	":Highest connection count: %d (%d clients)"
  #define STR_RPL_LUSERCLIENT		/* 251 */	":There are %d users and %d invisible on %d servers"
  #define STR_RPL_LUSEROP			/* 252 */	"%d :operator(s) online"
  #define STR_RPL_LUSERUNKNOWN		/* 253 */	"%d :unknown connection(s)"
  #define STR_RPL_LUSERCHANNELS		/* 254 */	"%d :channels formed"
  #define STR_RPL_LUSERME			/* 255 */	":I have %d clients and %d servers"
  #define STR_RPL_ADMINME			/* 256 */	":Administrative info about %s"
  #define STR_RPL_ADMINLOC1		/* 257 */	":%s"
  #define STR_RPL_ADMINLOC2		/* 258 */	":%s"
  #define STR_RPL_ADMINEMAIL		/* 259 */	":%s"
  #define STR_RPL_TRACELOG		/* 261 */	"File %s %d"
  #define STR_RPL_TRYAGAIN		/* 263 */	"%s :Flooding detected. Please wait a while and try again."
  #define STR_RPL_LOCALUSERS		/* 265 */	"%d %d :Current local users %d, max %d"
  #define STR_RPL_GLOBALUSERS		/* 266 */	"%d %d :Current global users %d, max %d"
  #define STR_RPL_SILELIST		/* 271 */	"%s"
  #define STR_RPL_ENDOFSILELIST		/* 272 */	":End of Silence List"
  #define STR_RPL_STATSDLINE		/* 275 */	"%c %s %s"
  #define STR_RPL_WHOISCERTFP		/* 276 */	"%s :has client certificate fingerprint %s"
  #define STR_RPL_AWAY			/* 301 */	"%s :%s"
  #define STR_RPL_USERHOST		/* 302 */	":%s %s %s %s %s"
  #define STR_RPL_ISON			/* 303 */	":"
  #define STR_RPL_UNAWAY			/* 305 */	":You are no longer marked as being away"
  #define STR_RPL_NOWAWAY			/* 306 */	":You have been marked as being away"
  #define STR_RPL_WHOISREGNICK		/* 307 */	"%s :is identified for this nick"
  #define STR_RPL_RULESSTART		/* 308 */	":- %s Server Rules - "
  #define STR_RPL_ENDOFRULES		/* 309 */	":End of RULES command."
  #define STR_RPL_WHOISUSER		/* 311 */	"%s %s %s * :%s"
  #define STR_RPL_WHOISSERVER		/* 312 */	"%s %s :%s"
  #define STR_RPL_WHOISOPERATOR		/* 313 */	"%s :is %s"
  #define STR_RPL_WHOWASUSER		/* 314 */	"%s %s %s * :%s"
  #define STR_RPL_ENDOFWHO		/* 315 */	"%s :End of /WHO list."
  #define STR_RPL_WHOISIDLE		/* 317 */	"%s %lld %lld :seconds idle, signon time"
  #define STR_RPL_ENDOFWHOIS		/* 318 */	"%s :End of /WHOIS list."
  #define STR_RPL_WHOISCHANNELS		/* 319 */	"%s :%s"
  #define STR_RPL_WHOISSPECIAL		/* 320 */	"%s :%s"
  #define STR_RPL_LISTSTART		/* 321 */	"Channel :Users  Name"
  #define STR_RPL_LIST			/* 322 */	"%s %d :%s %s"
  #define STR_RPL_LISTEND			/* 323 */	":End of /LIST"
  #define STR_RPL_CHANNELMODEIS		/* 324 */	"%s %s %s"
  #define STR_RPL_CREATIONTIME		/* 329 */	"%s %lld"
  #define STR_RPL_WHOISLOGGEDIN		/* 330 */	"%s %s :is logged in as"
  #define STR_RPL_NOTOPIC			/* 331 */	"%s :No topic is set."
  #define STR_RPL_TOPIC			/* 332 */	"%s :%s"
  #define STR_RPL_TOPICWHOTIME		/* 333 */	"%s %s %lld"
  #define STR_RPL_LISTSYNTAX		/* 334 */	":%s"
  #define STR_RPL_WHOISBOT		/* 335 */	"%s :is a \2Bot\2 on %s"
  #define STR_RPL_INVITELIST		/* 336 */	":%s"
  #define STR_RPL_ENDOFINVITELIST		/* 337 */	":End of /INVITE list."
  #define STR_RPL_USERIP			/* 340 */	":%s %s %s %s %s"
  #define STR_RPL_INVITING		/* 341 */	"%s %s"
  #define STR_RPL_WHOISCOUNTRY		/* 344 */	"%s %s :is connecting from %s"
  #define STR_RPL_INVEXLIST		/* 346 */	"%s %s %s %lld"
  #define STR_RPL_ENDOFINVEXLIST		/* 347 */	"%s :End of Channel Invite List"
  #define STR_RPL_EXLIST			/* 348 */	"%s %s %s %lld"
  #define STR_RPL_ENDOFEXLIST		/* 349 */	"%s :End of Channel Exception List"
  #define STR_RPL_VERSION			/* 351 */	"%s.%s %s :%s%s%s [%s=%d]"
  #define STR_RPL_WHOREPLY		/* 352 */	"%s %s %s %s %s %s :%d %s"
  #define STR_RPL_NAMREPLY		/* 353 */	"%s"
  #define STR_RPL_CLOSING			/* 362 */	"%s :Closed. Status = %d"
  #define STR_RPL_CLOSEEND		/* 363 */	"%d: Connections Closed"
  #define STR_RPL_LINKS			/* 364 */	"%s %s :%d %s"
  #define STR_RPL_ENDOFLINKS		/* 365 */	"%s :End of /LINKS list."
  #define STR_RPL_ENDOFNAMES		/* 366 */	"%s :End of /NAMES list."
  #define STR_RPL_BANLIST			/* 367 */	"%s %s %s %lld"
  #define STR_RPL_ENDOFBANLIST		/* 368 */	"%s :End of Channel Ban List"
  #define STR_RPL_ENDOFWHOWAS		/* 369 */	"%s :End of WHOWAS"
  #define STR_RPL_INFO			/* 371 */	":%s"
  #define STR_RPL_MOTD			/* 372 */	":- %s"
  #define STR_RPL_ENDOFINFO		/* 374 */	":End of /INFO list."
  #define STR_RPL_MOTDSTART		/* 375 */	":- %s Message of the Day - "
  #define STR_RPL_ENDOFMOTD		/* 376 */	":End of /MOTD command."
  #define STR_RPL_WHOISHOST		/* 378 */	"%s :is connecting from %s@%s %s"
  #define STR_RPL_WHOISMODES		/* 379 */	"%s :is using modes %s %s"
  #define STR_RPL_YOUREOPER		/* 381 */	":You are now an IRC Operator"
  #define STR_RPL_REHASHING		/* 382 */	"%s :Rehashing"
  #define STR_RPL_QLIST			/* 386 */	"%s %s"
  #define STR_RPL_ENDOFQLIST		/* 387 */	"%s :End of Channel Owner List"
  #define STR_RPL_ALIST			/* 388 */	"%s %s"
  #define STR_RPL_ENDOFALIST		/* 389 */	"%s :End of Protected User List"
  #define STR_RPL_TIME			/* 391 */	"%s :%s"
  #define STR_RPL_HOSTHIDDEN		/* 396 */	"%s :is now your displayed host"
  #define STR_ERR_NOSUCHNICK		/* 401 */	"%s :No such nick/channel"
  #define STR_ERR_NOSUCHSERVER		/* 402 */	"%s :No such server"
  #define STR_ERR_NOSUCHCHANNEL		/* 403 */	"%s :No such channel"
  #define STR_ERR_CANNOTSENDTOCHAN	/* 404 */	"%s :%s (%s)"
  #define STR_ERR_TOOMANYCHANNELS		/* 405 */	"%s :You have joined too many channels"
  #define STR_ERR_WASNOSUCHNICK		/* 406 */	"%s :There was no such nickname"
  #define STR_ERR_TOOMANYTARGETS		/* 407 */	"%s :Too many targets. The maximum is %d for %s."
  #define STR_ERR_NOORIGIN		/* 409 */	":No origin specified"
  #define STR_ERR_INVALIDCAPCMD		/* 410 */	"%s :Invalid CAP subcommand"
  #define STR_ERR_NORECIPIENT		/* 411 */	":No recipient given (%s)"
  #define STR_ERR_NOTEXTTOSEND		/* 412 */	":No text to send"
  #define STR_ERR_TOOMANYMATCHES		/* 416 */	"%s :%s"
  #define STR_ERR_INPUTTOOLONG		/* 417 */	":Input line was too long"
  #define STR_ERR_UNKNOWNCOMMAND		/* 421 */	"%s :Unknown command"
  #define STR_ERR_NOMOTD			/* 422 */	":MOTD File is missing"
  #define STR_ERR_NOADMININFO		/* 423 */	"%s :No administrative info available"
  #define STR_ERR_NOOPERMOTD		/* 425 */	":OPERMOTD File is missing"
  #define STR_ERR_TOOMANYAWAY		/* 429 */	":Too Many aways - Flood Protection activated"
  #define STR_ERR_NONICKNAMEGIVEN		/* 431 */	":No nickname given"
  #define STR_ERR_ERRONEUSNICKNAME	/* 432 */	"%s :Nickname is unavailable: %s"
  #define STR_ERR_NICKNAMEINUSE		/* 433 */	"%s :Nickname is already in use."
  #define STR_ERR_NORULES			/* 434 */	":RULES File is missing"
  #define STR_ERR_BANNICKCHANGE		/* 437 */	"%s :Cannot change nickname while banned on channel"
  #define STR_ERR_NCHANGETOOFAST		/* 438 */	"%s :Nick change too fast. Please try again later."
  #define STR_ERR_TARGETTOOFAST		/* 439 */	"%s :Message target change too fast. Please wait %lld seconds"
  #define STR_ERR_SERVICESDOWN		/* 440 */	"%s :Services are currently down. Please try again later."
  #define STR_ERR_USERNOTINCHANNEL	/* 441 */	"%s %s :They aren't on that channel"
  #define STR_ERR_NOTONCHANNEL		/* 442 */	"%s :You're not on that channel"
  #define STR_ERR_USERONCHANNEL		/* 443 */	"%s %s :is already on channel"
  #define STR_ERR_NONICKCHANGE		/* 447 */	":Can not change nickname while on %s (+N)"
  #define STR_ERR_FORBIDDENCHANNEL	/* 448 */	"%s :Cannot join channel: %s"
  #define STR_ERR_NOTREGISTERED		/* 451 */	":You have not registered"
  #define STR_ERR_NOTFORHALFOPS		/* 460 */	":Halfops cannot set mode %c"
  #define STR_ERR_NEEDMOREPARAMS		/* 461 */	"%s :Not enough parameters"
  #define STR_ERR_ALREADYREGISTRED	/* 462 */	":You may not reregister"
  #define STR_ERR_PASSWDMISMATCH		/* 464 */	":Password Incorrect"
  #define STR_ERR_YOUREBANNEDCREEP	/* 465 */	":%s"
  #define STR_ERR_ONLYSERVERSCANCHANGE	/* 468 */	"%s :Only servers can change that mode"
  #define STR_ERR_LINKCHANNEL		/* 470 */	"%s %s :[Link] %s has become full, so you are automatically being transferred to the linked channel %s"
  #define STR_ERR_CHANNELISFULL		/* 471 */	"%s :Cannot join channel (+l)"
  #define STR_ERR_UNKNOWNMODE		/* 472 */	"%c :is unknown mode char to me"
  #define STR_ERR_INVITEONLYCHAN		/* 473 */	"%s :Cannot join channel (+i)"
  #define STR_ERR_BANNEDFROMCHAN		/* 474 */	"%s :Cannot join channel (+b)"
  #define STR_ERR_BADCHANNELKEY		/* 475 */	"%s :Cannot join channel (+k)"
  #define STR_ERR_NEEDREGGEDNICK		/* 477 */	"%s :You need a registered nick to join that channel."
  #define STR_ERR_BANLISTFULL		/* 478 */	"%s %s :Channel ban/ignore list is full"
  #define STR_ERR_CANNOTKNOCK		/* 480 */	":Cannot knock on %s (%s)"
  #define STR_ERR_NOPRIVILEGES		/* 481 */	":Permission Denied- You do not have the correct IRC operator privileges"
  #define STR_ERR_CHANOPRIVSNEEDED	/* 482 */	"%s :You're not channel operator"
  #define STR_ERR_KILLDENY		/* 485 */	":Cannot kill protected user %s."
  #define STR_ERR_NOTFORUSERS		/* 487 */	":%s is a server only command"
  #define STR_ERR_SECUREONLYCHAN		/* 489 */	"%s :Cannot join channel (Secure connection is required)"
  #define STR_ERR_NOOPERHOST		/* 491 */	":No O-lines for your host"
  #define STR_ERR_CHANOWNPRIVNEEDED	/* 499 */	"%s :You're not a channel owner"
  #define STR_ERR_TOOMANYJOINS		/* 500 */	"%s :Too many join requests. Please wait a while and try again."
  #define STR_ERR_UMODEUNKNOWNFLAG	/* 501 */	":Unknown MODE flag"
  #define STR_ERR_USERSDONTMATCH		/* 502 */	":Cant change mode for other users"
  #define STR_ERR_SILELISTFULL		/* 511 */	"%s :Your silence list is full"
  #define STR_ERR_TOOMANYWATCH		/* 512 */	"%s :Maximum size for WATCH-list is 128 entries"
  #define STR_ERR_TOOMANYDCC		/* 514 */	"%s :Your dcc allow list is full. Maximum size is %d entries"
  #define STR_ERR_DISABLED		/* 517 */	"%s :%s" /* ircu */
  #define STR_ERR_NOINVITE		/* 518 */	":Cannot invite (+V) at channel %s"
  #define STR_ERR_OPERONLY		/* 520 */	":Cannot join channel %s (IRCops only)"
  #define STR_ERR_LISTSYNTAX		/* 521 */	":Bad list syntax, type /quote list ? or /raw list ?"
  #define STR_ERR_WHOLIMEXCEED		/* 523 */	":Error, /who limit of %d exceeded. Please narrow your search down and try again"
  #define STR_ERR_OPERSPVERIFY		/* 524 */	":Trying to join +s or +p channel as an oper. Please invite yourself first."
  #define STR_ERR_CANTSENDTOUSER		/* 531 */	"%s :%s"
  #define STR_RPL_REAWAY			/* 597 */	"%s %s %s %lld :%s"
  #define STR_RPL_GONEAWAY		/* 598 */	"%s %s %s %lld :%s"
  #define STR_RPL_NOTAWAY			/* 599 */	"%s %s %s %lld :is no longer away"
  #define STR_RPL_LOGON			/* 600 */	"%s %s %s %lld :logged online"
  #define STR_RPL_LOGOFF			/* 601 */	"%s %s %s %lld :logged offline"
  #define STR_RPL_WATCHOFF		/* 602 */	"%s %s %s %lld :stopped watching"
  #define STR_RPL_WATCHSTAT		/* 603 */	":You have %d and are on %d WATCH entries"
  #define STR_RPL_NOWON			/* 604 */	"%s %s %s %lld :is online"
  #define STR_RPL_NOWOFF			/* 605 */	"%s %s %s %lld :is offline"
  #define STR_RPL_WATCHLIST		/* 606 */	":%s"
  #define STR_RPL_ENDOFWATCHLIST		/* 607 */	":End of WATCH %c"
  #define STR_RPL_NOWISAWAY		/* 609 */	"%s %s %s %lld :is away"
  #define STR_RPL_MAPMORE			/* 610 */	":%s%-*s --> *more*"
  #define STR_RPL_DCCSTATUS		/* 617 */	":%s has been %s your DCC allow list"
  #define STR_RPL_DCCLIST			/* 618 */	":%s"
  #define STR_RPL_ENDOFDCCLIST		/* 619 */	":End of DCCALLOW %s"
  #define STR_RPL_DCCINFO			/* 620 */	":%s"
  #define STR_RPL_SPAMCMDFWD		/* 659 */	"%s :Command processed, but a copy has been sent to ircops for evaluation (anti-spam) purposes. [%s]"
  #define STR_RPL_STARTTLS		/* 670 */	":STARTTLS successful, go ahead with TLS handshake" /* kineircd */
  #define STR_RPL_WHOISSECURE		/* 671 */	"%s :%s" /* our variation on the kineircd numeric */
  #define STR_ERR_STARTTLS		/* 691 */	":%s"
  #define STR_ERR_INVALIDMODEPARAM	/* 696 */	"%s %c %s :%s"
  #define STR_RPL_MONONLINE		/* 730 */	":%s!%s@%s"
  #define STR_RPL_MONOFFLINE		/* 731 */	":%s"
  #define STR_RPL_MONLIST			/* 732 */	":%s"
  #define STR_RPL_ENDOFMONLIST		/* 733 */	":End of MONITOR list"
  #define STR_ERR_MONLISTFULL		/* 734 */	"%d %s :Monitor list is full."
  #define STR_ERR_MLOCKRESTRICTED		/* 742 */	"%s %c %s :MODE cannot be set due to channel having an active MLOCK restriction policy"
  #define STR_RPL_LOGGEDIN		/* 900 */	"%s!%s@%s %s :You are now logged in as %s."
  #define STR_RPL_LOGGEDOUT		/* 901 */	"%s!%s@%s :You are now logged out."
  #define STR_RPL_SASLSUCCESS		/* 903 */	":SASL authentication successful"
  #define STR_ERR_SASLFAIL		/* 904 */	":SASL authentication failed"
  #define STR_ERR_SASLTOOLONG		/* 905 */	":SASL message too long"
  #define STR_ERR_SASLABORTED		/* 906 */	":SASL authentication aborted"
  #define STR_RPL_SASLMECHS		/* 908 */	"%s :are available SASL mechanisms"
  #define STR_ERR_CANNOTDOCOMMAND		/* 972 */	"%s :%s"
  #define STR_ERR_CANNOTCHANGECHANMODE	/* 974 */	"%c :%s"

  # recherche du code numerique
  if { [dict exists $numeric_mapping $numeric $deamonOrigin] } {
    # si le code numerique est dans la table de mapping on le retourne
    return [dict get $numeric_mapping $numeric $deamonOrigin]
  } else {

    # sinon on regarde si le code numerique est dans la table de mapping global
    if { $deamonOrigin != "global" && [dict exists $numeric_mapping $numeric global] } {
      #si oui on le retourne
      return [dict get $numeric_mapping $numeric global]
    }
    # sinon on retourne le code numerique
    return $numeric
  }
}

# ::IRCC::connection --
#
# Create an IRC connection namespace and associated commands.

proc ::IRCC::connection { args } {
  variable conn
  variable config

  # Create a unique namespace of the form irc$conn::$host

  set name  [format "%s::IRCC%s" [namespace current] $conn]

  namespace eval $name {
    variable sock
    variable dispatch
    variable linedata
    variable config

    set sock      {}
    array set dispatch  {}
    array set linedata  {}
    array set config  [array get ::IRCC::config]
    if { $config(logger) || $config(debug) } {
      if { [catch { package require logger }] } {
        # tcllib/logger optionnel — continue sans journalisation
        set config(logger) 0
        set config(debug) 0
      } else {
        variable logger
        set logger    [logger::init [namespace tail [namespace current]]]
        if { !$config(debug) } { ${logger}::disable debug }
      }
    }
    proc TLSSocketCallBack { level args } {
      set SOCKET_NAME  [lindex $args 0]
      set type    [lindex $args 1]
      set socketid  [lindex $args 2]
      set what    [lrange $args 3 end]
      cmd-log debug "Socket '$SOCKET_NAME' callback $type: $what"
      if { [string match -nocase "*certificate*verify*failed*" $what] } {
        cmd-log error "IRCC Socket erreur: Vous essayez de vous connecter a un serveur TLS auto-signé. ($what) [tls::status $socketid]"
      }
      if { [string match -nocase "*wrong*version*number*" $what] } {
        cmd-log error "IRCC Socket erreur: Vous essayez sans doute de connecter en SSL sur un port Non-SSL. ($what)"
      }
    }

    # ircsend --
    # send text to the IRC server
    proc ircsend { msg } {
      variable sock
      variable dispatch
      if { $sock eq "" } { return }
      cmd-log debug "ircsend: '$msg'"
      if { [catch {puts $sock $msg} err] } {
        catch { close $sock }
        set sock  {}
        if { [info exists dispatch(EOF)] } {
          eval $dispatch(EOF)
        }
        cmd-log error "Error in ircsend: $err"
      }
    }


    #########################################################
    # Implemented user-side commands, meaning that these commands
    # cause the calling user to perform the given action.
    #########################################################
    # cmd-config --
    #
    # Set or return per-connection configuration options.
    #
    # Arguments:
    #
    # key  name of the configuration option to change.
    #
    # value  value (optional) of the configuration option.

    proc cmd-config { args } {
      variable config
      variable logger

      if { [llength $args] == 0 } {
        return [array get config]
      } elseif { [llength $args] == 1 } {
        set key  [lindex $args 0]
        return $config($key)
      } elseif { [llength $args] > 2 } {
        error "wrong # args: should be \"config key ?val?\""
      }
      set key    [lindex $args 0]
      set value  [lindex $args 1]
      if { $key eq "debug" } {
        if {$value} {
          if { !$config(logger) } {
            if { [catch { cmd-config logger 1 }] } {
              set config(debug) 0
              return -code error "debug nécessite logger (tcllib)"
            }
          }
          if { [info exists logger] } { ${logger}::enable debug }
        } elseif { [info exists logger] } {
          ${logger}::disable debug
        }
      }
      if { $key eq "logger" } {
        if { $value && !$config(logger)} {
          if { [catch { package require logger } err] } {
            return -code error "logger indisponible (tcllib): $err"
          }
          set logger  [logger::init [namespace tail [namespace current]]]
        } elseif { [info exists logger] } {
          ${logger}::delete
          unset  logger
        }
      }
      set config($key)  $value
    }
    # cmd-getconfig --
    #
    # Return the value of a configuration option.
    #
    # Arguments:
    #
    # key  name of the configuration option to return.
    proc cmd-getconfig { key } {
      variable config
      return $config($key)
    }

    proc cmd-log {level text} {
      variable logger
      if { ![info exists logger] } return
      ${logger}::$level $text
    }

    proc cmd-logname { } {
      variable logger
      if { ![info exists logger] } return
      return $logger
    }

    # cmd-destroy --
    #
    # destroys the current connection and its namespace

    proc cmd-destroy { } {
      variable logger
      variable sock
      if { [info exists logger] } { ${logger}::delete }
      catch {close $sock}
      namespace delete [namespace current]
    }

    proc cmd-connected { } {
      variable sock
      if { $sock eq "" } { return 0 }
      return 1
    }

    # http://abcdrfc.free.fr/rfc-vf/rfc1459.html#412
    proc cmd-user { nickname username {userinfo {TCL PACKAGE IRCC - https://git.io/JY7tI}} } {
      ircsend "NICK $nickname"
      ircsend "USER $username * * :$userinfo"
    }

    proc cmd-nick { nk } {
      ircsend "NICK $nk"
    }

    proc cmd-ping { target } {
      ircsend "PRIVMSG $target :\001PING [clock seconds]\001"
    }

    proc cmd-serverping { } {
      ircsend "PING [clock seconds]"
    }

    proc cmd-ctcp { target line } {
      ircsend "PRIVMSG $target :\001$line\001"
    }

    proc cmd-join { chan {key {}} } {
      if { $key eq "" } {
        ircsend "JOIN $chan"
      } else {
        ircsend "JOIN $chan :$key"
      }
    }

    proc cmd-part { chan {msg {TCL PACKAGE IRCC - https://git.io/JY7tI}} } {
      if { $msg eq "" } {
        ircsend "PART $chan"
      } else {
        ircsend "PART $chan :$msg"
      }
    }

    proc cmd-quit { {msg {TCL PACKAGE IRCC - https://git.io/JY7tI}} } {
      ircsend "QUIT :$msg"
    }

    proc cmd-privmsg { target msg } {
      ircsend "PRIVMSG $target :$msg"
    }

    proc cmd-notice { target msg } {
      ircsend "NOTICE $target :$msg"
    }

    proc cmd-kick { chan target {msg {}} } {
      ircsend "KICK $chan $target :$msg"
    }

    proc cmd-mode { target args } {
      ircsend "MODE $target [join $args]"
    }

    proc cmd-topic { chan msg } {
      ircsend "TOPIC $chan :$msg"
    }

    proc cmd-invite { chan target } {
      ircsend "INVITE $target $chan"
    }

    proc cmd-send { line } {
      ircsend $line
    }

    proc cmd-peername { } {
      variable sock
      if { $sock eq "" } { return {} }
      return [fconfigure $sock -peername]
    }

    proc cmd-sockname { } {
      variable sock
      if { $sock eq "" } { return {} }
      return [fconfigure $sock -sockname]
    }

    proc cmd-socket { } {
      variable sock
      return $sock
    }

    proc cmd-disconnect { } {
      variable sock
      if { $sock eq "" } { return -1 }
      catch { close $sock }
      set sock  {}
      return 0
    }

    # Connect --
    # Create the actual tcp connection.
    # http://abcdrfc.free.fr/rfc-vf/rfc1459.html#41
    proc cmd-connect { IRC_HOSTNAME {IRC_PORT +6697} {IRC_PASSWORD ""} } {
      variable sock
      variable host
      variable port

      set host  $IRC_HOSTNAME
      set s_port  $IRC_PORT
      if { [string range $s_port 0 0] == "+" } {
        set secure  1;
        set port  [string range $s_port 1 end]
      } else {
        set secure  0;
        set port  $s_port
      }
      if { $secure == 1 } {
        package require tls $::IRCC::pkg_vers_min_need_tls
        set socket_binary  "::tls::socket -require 0 -request 0 -command \"[namespace current]::TLSSocketCallBack $sock\""
      } else {
        set socket_binary  ::socket
      }
      if { $sock eq "" } {
        set sock  [{*}$socket_binary $host $port]
        fconfigure $sock -translation crlf -buffering line
        fileevent $sock readable [namespace current]::GetEvent
        if { $IRC_PASSWORD != "" } {
          ircsend  "PASS $IRC_PASSWORD"
        }

      }
      return 0
    }

    # Callback API:

    # These are all available from within callbacks, so as to
    # provide an interface to provide some information on what is
    # coming out of the server.

    # action --

    # Action returns the action performed, such as KICK, PRIVMSG,
    # MODE etc, including numeric actions such as 001, 252, 353,
    # and so forth.

    proc action { } {
      variable linedata
      return $linedata(action)
    }

    proc numname { } {
      variable linedata
      return $linedata(numname)
    }


    # msg --

    # The last argument of the line, after the last ':'.

    proc msg { } {
      variable linedata
      return $linedata(msg)
    }

    # who --

    # Who performed the action.  If the command is called as [who address],
    # it returns the information in the form
    # nick!ident@host.domain.net

    proc who { {address 0} } {
      variable linedata
      if { $address == 0 } {
        return [lindex [split $linedata(who) !] 0]
      } else {
        return $linedata(who)
      }
    }

    # target --

    # To whom was this action done.

    proc target { } {
      variable linedata
      return $linedata(target)
    }

    proc rawline { } {
      variable linedata
      return $linedata(rawline)
    }

    # additional --

    # Returns any additional header elements beyond the target as a list.

    proc additional { } {
      variable linedata
      return $linedata(additional)
    }

    # header --

    # Returns the entire header in list format.

    proc header { } {
      variable linedata
      return [concat [list $linedata(who) $linedata(action) \
        $linedata(target)] $linedata(additional)]
    }

    # GetEvent --

    # Get a line from the server and dispatch it.

    proc GetEvent { } {
      variable linedata
      variable sock
      variable dispatch
      array set linedata  {}
      set line      "eof"
      if { [eof $sock] || [catch {gets $sock} line] } {
        close $sock
        set sock  {}
        cmd-log error "Error receiving from network: $line"
        if { [info exists dispatch(EOF)] } {
          if { [catch { eval $dispatch(EOF) } err] } {
            cmd-log error "EOF callback failed: $err"
          }
        }
        return
      }
      cmd-log debug "Recieved: $line"
      if { [set pos      [string first " :" $line]] > -1 } {
        set header      [string range $line 0 [expr {$pos - 1}]]
        set linedata(msg)  [string range $line [expr {$pos + 2}] end]
      } else {
        set header      [string trim $line]
        set linedata(msg)  {}
      }

      set headerWords [regexp -all -inline {\S+} $header]
      if { [string match :* $header] } {
        set header  [lreplace $headerWords 0 0 [string trimleft [lindex $headerWords 0] :]]
      } else {
        set header  [linsert $headerWords 0 {}]
      }
      set linedata(rawline)      [string trim $line];
      set linedata(who)          [string trim [lindex $header 0]];
      set linedata(action)      [string trim [lindex $header 1]];
      set linedata(target)      [string trim [lindex $header 2]];
      set linedata(additional)  [lrange $header 3 end];
      set linedata(numname)      [::IRCC::num2name [lindex $header 1]];
      if { [info exists dispatch($linedata(action))] } {
        set _cb $dispatch($linedata(action))
      } elseif { [info exists dispatch($linedata(numname))] } {
        set _cb $dispatch($linedata(numname))
      } elseif { [string match {[0-9]??} $linedata(action)] } {
        set _cb $dispatch(defaultnumeric)
      } elseif { $linedata(who) eq "" } {
        set _cb $dispatch(defaultcmd)
      } else {
        set _cb $dispatch(defaultevent)
      }
      if { [info exists _cb] && $_cb ne "" && $_cb ne "#" } {
        if { [catch { eval $_cb } err] } {
          cmd-log error "Callback $linedata(action) failed: $err"
        }
      }
    }

    # registerevent --

    # Register an event in the dispatch table.

    # Arguments:
    # evnt: name of event as sent by IRC server.
    # cmd: proc to register as the event handler

    proc cmd-registerevent { evnt cmd } {
      variable dispatch
      set dispatch($evnt)  $cmd
      if { $cmd eq "" } {
        unset dispatch($evnt)
      }
    }

    # getevent --

    # Return the currently registered handler for the event.

    # Arguments:
    # evnt: name of event as sent by IRC server.

    proc cmd-getevent { evnt } {
      variable dispatch
      if { [info exists dispatch($evnt)] } {
        return $dispatch($evnt)
      }
      return {}
    }

    # eventexists --

    # Return a boolean value indicating if there is a handler
    # registered for the event.

    # Arguments:
    # evnt: name of event as sent by IRC server.

    proc cmd-eventexists { evnt } {
      variable dispatch
      return [info exists dispatch($evnt)]
    }

    # network --

    # Accepts user commands and dispatches them.

    # Arguments:
    # cmd: command to invoke
    # args: arguments to the command

    proc network { cmd args } {
      if { [info proc [namespace current]::cmd-$cmd] == "" } {
        return "sub-cmd inconnu. List: [join [string map [list "[namespace current]::cmd-" ""] [info proc [namespace current]::cmd-*]] ", "]"
      } else {
        eval [linsert $args 0 [namespace current]::cmd-$cmd]
      }
    }

    # Create default handlers.

    set dispatch(PING)        {network send "PONG :[msg]"}
    set dispatch(defaultevent)    #
    set dispatch(defaultcmd)    #
    set dispatch(defaultnumeric)  #
  }

  set returncommand  [format "%s::IRCC%s::network" [namespace current] $conn]
  incr conn
  return $returncommand
}

# -------------------------------------------------------------------------

package provide IRCC $::IRCC::pkg_vers
package require Tcl $::IRCC::pkg_vers_min_need_tcl
package require tls $::IRCC::pkg_vers_min_need_tls

# -------------------------------------------------------------------------
return
