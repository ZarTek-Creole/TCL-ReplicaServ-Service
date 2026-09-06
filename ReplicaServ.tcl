#############################################################################
##-->						TCL ReplicaServ Service						<--##
#---------------------------------------------------------------------------#
## Auteur	: ZarTek
## Website	: github.com/ZarTek-Creole/TCL-ReplicaServ-Service
## Support	: github.com/ZarTek-Creole/TCL-ReplicaServ-Service/issues
##
## Greet	:
##		-> DJ-Philo,Averell & NiCkOoS pour versions tclsh 'Les poupées linkeuses'
##		-> pchevee de www.eggdrop.fr pour la demande de mise à jour
##		-> MenzAgitat de www.eggdrop.fr pour ses astuces/conseils
##		-> CrazyCat de www.eggdrop.fr pour sa communauté eggdrop français
#############################################################################
if { [catch { package require IRCServices 0.1.0 }] } { putloglev o * "\00304\[ReplicaServ - erreur\]\003 ReplicaServ nécessite le package IRCServices 0.1.0 (ou plus) pour fonctionner, Télécharger sur 'github.com/ZarTek-Creole/TCL-PKG-IRCServices'. Le chargement du script a été annulé." ; die }
if { [catch { package require IRCC 0.0.3 }] } { putloglev o * "\00304\[ReplicaServ - erreur\]\003 ReplicaServ nécessite le package IRCC 0.0.3 (ou plus) pour fonctionner, Télécharger sur 'github.com/ZarTek-Creole/TCL-PKG-IRCC'. Le chargement du script a été annulé." ; die }
if {[info commands ::ReplicaServ::uninstall] eq "::ReplicaServ::uninstall" } { ::ReplicaServ::uninstall }
namespace eval ReplicaServ {
	variable config
	variable SERVICEBOT_PIPELINE	""
	variable SERVICE_PIPELINE		""
	variable IRCC_DATA
	variable RUNTIME
	variable LINK_CACHE
	array set IRCC_DATA				{}
	array set RUNTIME				{}
	array set LINK_CACHE			{}

	set config(scriptname)		"ReplicaServ Service"
	set config(version)			"1.2.20260906"
	set config(auteur)			"ZarTek"

	set config(init)			0

	set config(path_script)		[file dirname [info script]];

	set config(db_list)			[list	\
				"link.db"				\
				"network.db"
	];

	# Défauts replica_* (surchargeables dans ReplicaServ.conf)
	set config(replica_sync_users)			1
	set config(replica_sync_messages)		1
	set config(replica_sync_topics)			1
	set config(replica_sync_modes)			1
	set config(replica_sjoin_interval_ms)	50
	set config(replica_network_stagger_ms)	5000
	set config(replica_channel_stagger_ms)	10000
	set config(replica_nick_suffix)			1
	set config(replica_topic_prefix)		""
	set config(replica_remote_gecos)		"40 M Replica"

	set config(vars_list)		[list	\
					"uplink_host"		\
					"uplink_ssl"		\
					"uplink_port"		\
					"uplink_password"	\
					"serverinfo_name"	\
					"serverinfo_descr"	\
					"serverinfo_id"		\
					"uplink_useprivmsg"	\
					"uplink_debug"		\
					"service_nick"		\
					"service_user"		\
					"service_host"		\
					"service_gecos"		\
					"service_modes"		\
					"service_channel"	\
					"service_chanmodes"	\
					"service_usermodes"	\
					"admin_password"	\
					"admin_console"		\
					"replica_sync_users"			\
					"replica_sync_messages"			\
					"replica_sync_topics"			\
					"replica_sync_modes"			\
					"replica_sjoin_interval_ms"		\
					"replica_network_stagger_ms"	\
					"replica_channel_stagger_ms"	\
					"replica_nick_suffix"			\
					"replica_topic_prefix"			\
					"replica_remote_gecos"			\
					"scriptname"		\
					"version"			\
					"auteur"
	];
	proc uninstall {args} {
		variable config

		putlog "Désallocation des ressources de \002[set config(scriptname)]\002..."

		foreach binding [lsearch -inline -all -regexp [binds *[set ns [::tcl::string::range [namespace current] 2 end]]*] " \{?(::)?$ns"] {
			unbind [lindex $binding 0] [lindex $binding 1] [lindex $binding 2] [lindex $binding 4]
		}
		# Arrêt des timers en cours.
		foreach running_timer [timers] {
			if { [::tcl::string::match "*[namespace current]::*" [lindex $running_timer 1]] } { killtimer [lindex $running_timer 2] }
		}
		
		if { [info exists config(idx)] } { 
			close $config(idx)
		}
		namespace delete ::ReplicaServ
	}
}
proc ::ReplicaServ::INIT { } {
	variable config
	variable database
	#######################
	# ReplicaServ Fichier #
	#######################
	if { ![file isdirectory "[::ReplicaServ::Get:ScriptDir "db"]"] } { file mkdir "[::ReplicaServ::Get:ScriptDir "db"]" }
	::ReplicaServ::DB:INIT $config(db_list)

	######################
	# ReplicaServ Source #
	######################
	if { [file exists [::ReplicaServ::Get:ScriptDir]ReplicaServ.conf] } {
		source [::ReplicaServ::Get:ScriptDir]ReplicaServ.conf
		::ReplicaServ::Check:Config
	} else {
		if { [file exists [::ReplicaServ::Get:ScriptDir]ReplicaServ.Example.conf] } {
			putlog "Editez, configurer et renomer 'ReplicaServ.Example.conf' en 'ReplicaServ.conf' dans '[::ReplicaServ::Get:ScriptDir]'"
			exit "ReplicaServ quit"
		} else {
			putlog "Fichier de configuration '[::ReplicaServ::Get:ScriptDir]ReplicaServ.conf' manquant."
			exit "ReplicaServ quit"
		}
	}

	::ReplicaServ::INIT:SERVICE

	set config(putlog) "[set config(scriptname)] v[set config(version)] par [set config(auteur)]"
}
proc ::ReplicaServ::INIT:SERVICE {} {
	variable config
	variable SERVICE_PIPELINE

	#############################
	# ReplicaServ Services init #
	#############################
	if { $config(uplink_ssl)	== 1	} { set config(uplink_port) "+$config(uplink_port)" }
	if { $config(serverinfo_id)	!= ""	} { set config(uplink_ts6) 1 } else { set config(uplink_ts6) 0 }
	
	set SERVICE_PIPELINE	[::IRCServices::connection]; # Creer une instance services
	$SERVICE_PIPELINE connect $config(uplink_host) $config(uplink_port) $config(uplink_password) $config(uplink_ts6) $config(serverinfo_name) $config(serverinfo_id); # Connexion de l'instance service

	if { $config(uplink_debug) == 1} { $SERVICE_PIPELINE config logger 1; $SERVICE_PIPELINE config debug 1; }
	::ReplicaServ::INIT:BOTSERVICE

}
proc ::ReplicaServ::INIT:BOTSERVICE {} {
	variable config
	variable SERVICE_PIPELINE
	variable SERVICEBOT_PIPELINE
	
	set SERVICEBOT_PIPELINE		[$SERVICE_PIPELINE bot]; #Creer une instance bot dans linstance services
	
	$SERVICEBOT_PIPELINE create $config(service_nick) $config(service_user) $config(service_host) $config(service_gecos) $config(service_modes); # Creation d'un bot service

	
	if { $config(service_channel) != "" } { 
		$SERVICEBOT_PIPELINE join $config(service_channel)
		$SERVICEBOT_PIPELINE mode $config(service_channel) $config(service_chanmodes)
		if { $config(service_usermodes) != "" } { 
			$SERVICEBOT_PIPELINE mode $config(service_channel) $config(service_usermodes) $config(service_nick)
		}
	}
	

	$SERVICEBOT_PIPELINE registerevent SERVER {
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Initialisation ...."
		::ReplicaServ::IRC:LOAD:NETWORKS
	}
	$SERVICEBOT_PIPELINE registerevent PRIVMSG {
		# Parsing sûr (évite [lindex] sur chaînes non-listes Tcl)
		set rawmsg	[string trim [msg]]
		set words	[regexp -all -inline {\S+} $rawmsg]
		if { [llength $words] == 0 } { return }
		set cmd		[string tolower [lindex $words 0]]
		set data	[lrange $words 1 end]
		set sender	[who2]
		##########################
		#--> Commandes Privés <--#
		##########################
		if { [string index [target] 0] != "#" } {
			if { $cmd eq "help" } {
				::ReplicaServ::IRC:CMD:PRIV:HELP $sender [target] $cmd $data
			} elseif { $cmd eq "network" } {
				if { ![::ReplicaServ::AUTH:ADMIN $sender $data] } { return }
				# data sans le mot de passe admin (dernier arg si auth OK)
				set data [::ReplicaServ::AUTH:STRIP $data]
				::ReplicaServ::IRC:CMD:PRIV:NETWORK $sender [target] $cmd $data
			} elseif { $cmd eq "link" } {
				if { ![::ReplicaServ::AUTH:ADMIN $sender $data] } { return }
				set data [::ReplicaServ::AUTH:STRIP $data]
				::ReplicaServ::IRC:CMD:PRIV:LINK $sender [target] $cmd $data
			} elseif { $cmd eq "set" } {
				if { ![::ReplicaServ::AUTH:ADMIN $sender $data] } { return }
				set data [::ReplicaServ::AUTH:STRIP $data]
				::ReplicaServ::IRC:CMD:PRIV:SET $sender [target] $cmd $data
			} else {
				::ReplicaServ::IRC:CMD:PRIV:HELP $sender [target] $cmd $data
			}
		}
		##########################
		#--> Commandes Salons <--#
		##########################
		if { [string index [target] 0] == "#" } {
			if { $cmd eq "!help" } {
				::ReplicaServ::IRC:CMD:PUB:HELP $sender [target] $cmd $data
			}
		}
	}; # Creer un event sur PRIVMSG
	
}

#########################
# ReplicaServ fonctions #
#########################
proc ::ReplicaServ::IRC:LOAD:NETWORKS {} {
	variable config
	variable IRCC_DATA
	# Éviter double-chargement si SERVER renvoyé
	if { [info exists IRCC_DATA(NETWORKS_LOADED)] && $IRCC_DATA(NETWORKS_LOADED) } {
		putlog "ReplicaServ: NETWORKS already loaded"
		return
	}
	set IRCC_DATA(NETWORKS_LOADED) 1
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Chargement des réseaux IRC..."
	set fichier(network) "[::ReplicaServ::Get:ScriptDir "db"]/network.db"
	set fp [open $fichier(network) "r"]
	set net_delay 0
	set stagger 5000
	if { [info exists config(replica_network_stagger_ms)] } {
		set stagger $config(replica_network_stagger_ms)
	}
	while {![eof $fp]} {
		set data [gets $fp]
		if {$data eq ""} { continue }
		set IRC_NAME		[lindex $data 0]
		set IRC_NICKNAME	[lindex $data 1]
		set IRC_USERNAME	[lindex $data 2]
		set addr_field		[lindex $data 3]
		set servers			[::ReplicaServ::DB:NETWORK:PARSE:ADDRS $addr_field]
		if { [llength $servers] == 0 } {
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Adresse(s) réseau invalide(s) pour $IRC_NAME: $addr_field"
			putlog "ReplicaServ: bad network addr $IRC_NAME <$addr_field>"
			continue
		}
		set first			[lindex $servers 0]
		set IRC_HOST		[lindex $first 0]
		set IRC_PORT		[lindex $first 1]
		set nserv			[llength $servers]
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Chargement du réseau IRC $IRC_NAME → $IRC_HOST:$IRC_PORT ($nserv serveur(s), dans ${net_delay}ms)..."
		putlog "ReplicaServ: schedule connect $IRC_NAME $IRC_HOST:$IRC_PORT ($nserv servers) in ${net_delay}ms"
		after $net_delay [list ::ReplicaServ::IRC:Connexion $IRC_NAME $addr_field $IRC_NICKNAME $IRC_USERNAME]
		incr net_delay $stagger
	}
	close $fp
}

proc ::ReplicaServ::Get:ScriptDir { {DIR ""} } {
	variable config
	return "[file normalize $config(path_script)/$DIR]/"
}

# Namespace IRCServices (sans le suffixe ::network du handle)
proc ::ReplicaServ::SERVICE:NS {} {
	variable SERVICE_PIPELINE
	return [string map [list "::network" ""] $SERVICE_PIPELINE]
}

# Cache des liens réseau→salons (évite open() à chaque user virtuel)
# LINK_CACHE(net,dist) = {local flags_list}
proc ::ReplicaServ::DB:LINK:RELOAD {} {
	variable LINK_CACHE
	array unset LINK_CACHE
	array set LINK_CACHE {}
	set FILE(LINK)	"[::ReplicaServ::Get:ScriptDir "db"]/link.db"
	if { ![file exists $FILE(LINK)] } { return }
	set FILE_PIPE	[open $FILE(LINK) "r"]
	while { ![eof $FILE_PIPE] } {
		set FILE_LINE	[gets $FILE_PIPE]
		if { $FILE_LINE eq "" } { continue }
		set F_NAME	[lindex $FILE_LINE 0]
		set F_LOCAL	[lindex $FILE_LINE 1]
		set F_DIST	[lindex $FILE_LINE 2]
		set F_FLAGS	[lrange $FILE_LINE 3 end]
		set LINK_CACHE([string tolower $F_NAME],[string tolower $F_DIST]) [list $F_LOCAL $F_FLAGS]
	}
	close $FILE_PIPE
}

# Cherche le salon local lié à un salon distant (match exact, pas de glob)
proc ::ReplicaServ::DB:LINK:LOCAL { IRC_NAME IRC_CHANNEL } {
	variable LINK_CACHE
	if { ![info exists LINK_CACHE] || [array size LINK_CACHE] == 0 } {
		::ReplicaServ::DB:LINK:RELOAD
	}
	set key	"[string tolower $IRC_NAME],[string tolower $IRC_CHANNEL]"
	if { [info exists LINK_CACHE($key)] } {
		return [lindex $LINK_CACHE($key) 0]
	}
	return ""
}

proc ::ReplicaServ::DB:LINK:FLAGS { IRC_NAME IRC_CHANNEL } {
	variable LINK_CACHE
	if { ![info exists LINK_CACHE] || [array size LINK_CACHE] == 0 } {
		::ReplicaServ::DB:LINK:RELOAD
	}
	set key	"[string tolower $IRC_NAME],[string tolower $IRC_CHANNEL]"
	if { [info exists LINK_CACHE($key)] } {
		return [lindex $LINK_CACHE($key) 1]
	}
	return [list]
}

proc ::ReplicaServ::DB:LINK:HAS:FLAG { IRC_NAME IRC_CHANNEL FLAG } {
	set FLAG [string tolower $FLAG]
	foreach f [::ReplicaServ::DB:LINK:FLAGS $IRC_NAME $IRC_CHANNEL] {
		if { [string equal -nocase $f $FLAG] } { return 1 }
	}
	return 0
}

# Topic sync : notopic force off ; topic force on ; sinon global replica_sync_topics
proc ::ReplicaServ::LINK:TOPIC:ENABLED { IRC_NAME IRC_CHANNEL } {
	if { [::ReplicaServ::DB:LINK:HAS:FLAG $IRC_NAME $IRC_CHANNEL notopic] } { return 0 }
	if { [::ReplicaServ::DB:LINK:HAS:FLAG $IRC_NAME $IRC_CHANNEL topic] } { return 1 }
	return [::ReplicaServ::CFG:ON replica_sync_topics]
}

# Met à jour le 4e champ (flags) d'une ligne link.db
proc ::ReplicaServ::DB:LINK:SET:FLAGS { IRC_NAME CHAN_LOCAL CHAN_DISTANT FLAGS } {
	set DB_FILE "[::ReplicaServ::Get:ScriptDir "db"]/link.db"
	if { ![file exists $DB_FILE] } { return 0 }
	set fp [open $DB_FILE r]
	set out [list]
	set found 0
	while { ![eof $fp] } {
		set line [gets $fp]
		if { $line eq "" } { continue }
		if { [string equal -nocase [lindex $line 0] $IRC_NAME] \
			&& [string equal -nocase [lindex $line 1] $CHAN_LOCAL] \
			&& [string equal -nocase [lindex $line 2] $CHAN_DISTANT] } {
			set found 1
			set newline [list $IRC_NAME $CHAN_LOCAL $CHAN_DISTANT {*}$FLAGS]
			lappend out $newline
		} else {
			lappend out $line
		}
	}
	close $fp
	if { !$found } { return 0 }
	set fp [open $DB_FILE w+]
	foreach l $out { puts $fp $l }
	close $fp
	::ReplicaServ::DB:LINK:RELOAD
	return 1
}

proc ::ReplicaServ::Check:Config { } {
	variable config
	# Clés autorisées vides
	set allow_empty [list serverinfo_id replica_topic_prefix]
	foreach CONF $config(vars_list) {
		if { ![info exists config($CONF)] } {
			putlog "\[ Erreur \] Configuration de ReplicaServ Service Incorrecte... '$CONF' Paramettre manquant"
			exit "ReplicaServ quit"
		}
		if { $config($CONF) == "" && [lsearch -exact $allow_empty $CONF] < 0 } {
			putlog "\[ Erreur \] Configuration de ReplicaServ Service Incorrecte... '$CONF' Valeur vide"
			exit "ReplicaServ quit"
		}
	}
	# Bornes rate-limit
	if { ![string is integer -strict $config(replica_sjoin_interval_ms)] || $config(replica_sjoin_interval_ms) < 20 } {
		set config(replica_sjoin_interval_ms) 200
	}
	if { ![string is integer -strict $config(replica_network_stagger_ms)] || $config(replica_network_stagger_ms) < 0 } {
		set config(replica_network_stagger_ms) 60000
	}
	if { ![info exists config(replica_channel_stagger_ms)] \
		|| ![string is integer -strict $config(replica_channel_stagger_ms)] \
		|| $config(replica_channel_stagger_ms) < 500 } {
		set config(replica_channel_stagger_ms) 10000
	}
}

# Helper : toggle replica_* (1/true/on/yes) — RUNTIME surcharge la conf
proc ::ReplicaServ::CFG:ON { key } {
	variable config
	variable RUNTIME
	if { [info exists RUNTIME($key)] } {
		set v [string tolower [string trim $RUNTIME($key)]]
	} elseif { [info exists config($key)] } {
		set v [string tolower [string trim $config($key)]]
	} else {
		return 0
	}
	return [expr {$v eq "1" || $v eq "true" || $v eq "on" || $v eq "yes"}]
}

proc ::ReplicaServ::CFG:SET:RUNTIME { key value } {
	variable RUNTIME
	variable config
	set value [string tolower [string trim $value]]
	if { $value eq "1" || $value eq "true" || $value eq "on" || $value eq "yes" } {
		set RUNTIME($key) 1
	} elseif { $value eq "0" || $value eq "false" || $value eq "off" || $value eq "no" } {
		set RUNTIME($key) 0
	} else {
		return 0
	}
	# Miroir conf en mémoire (sans réécrire le fichier)
	set config($key) $RUNTIME($key)
	return 1
}

proc ::ReplicaServ::JOIN { CHANNEL } {
	variable SERVICEBOT_PIPELINE
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Je join le salon $CHANNEL"
	$SERVICEBOT_PIPELINE	join $CHANNEL
}
proc ::ReplicaServ::IRC:JOIN { IRC_NAME CHANNEL } {
	variable IRCC_DATA
	set CHANNEL [string tolower $CHANNEL]
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Je join le salon $CHANNEL sur le réseau $IRC_NAME"
	set IRCC_DATA($IRC_NAME,NAMES,$CHANNEL) [list]
	set IRCC_DATA($IRC_NAME,WHO_DELAY) 0
	$IRCC_DATA($IRC_NAME,PIPELINE) join $CHANNEL
}
proc ::ReplicaServ::SENT:NOTICE { DEST MSG } {
	variable SERVICEBOT_PIPELINE
	$SERVICEBOT_PIPELINE	notice $DEST [::ReplicaServ::apply_visuals $MSG]
}

proc ::ReplicaServ::SENT:PRIVMSG { DEST MSG } {
	variable SERVICEBOT_PIPELINE
	$SERVICEBOT_PIPELINE	privmsg $DEST [::ReplicaServ::apply_visuals $MSG]
}
proc ::ReplicaServ::VPRIVMSG { IRC_NAME IRC_CHANNEL IRC_USER IRC_MSG } {
	variable SERVICEBOT_PIPELINE
	if { ![::ReplicaServ::CFG:ON replica_sync_messages] } { return }
	# Ignorer les messages hors salon / hors link
	if { [string index $IRC_CHANNEL 0] ne "#" } { return }
	if { [::ReplicaServ::DB:LINK:HAS:FLAG $IRC_NAME $IRC_CHANNEL nomsg] } { return }
	set CHANNEL_LOCAL	[::ReplicaServ::DB:LINK:LOCAL $IRC_NAME $IRC_CHANNEL]
	if { $CHANNEL_LOCAL eq "" } { return }
	set NS	[::ReplicaServ::SERVICE:NS]
	# UID_GET crée un UID fantôme s'il n'existe pas → n'envoyer que si l'user virtuel existe
	if { ![${NS}::UID_EXIST $IRC_USER] } { return }
	set USER_UID	[${NS}::UID_GET $IRC_USER]
	if { $USER_UID eq "" } { return }
	$SERVICEBOT_PIPELINE	 send ":$USER_UID PRIVMSG $CHANNEL_LOCAL :$IRC_MSG"
}
proc ::ReplicaServ::VNOTICE { IRC_NAME IRC_CHANNEL IRC_USER IRC_MSG } {
	variable SERVICEBOT_PIPELINE
	if { ![::ReplicaServ::CFG:ON replica_sync_messages] } { return }
	if { [string index $IRC_CHANNEL 0] ne "#" } { return }
	if { [::ReplicaServ::DB:LINK:HAS:FLAG $IRC_NAME $IRC_CHANNEL nomsg] } { return }
	set CHANNEL_LOCAL	[::ReplicaServ::DB:LINK:LOCAL $IRC_NAME $IRC_CHANNEL]
	if { $CHANNEL_LOCAL eq "" } { return }
	set NS	[::ReplicaServ::SERVICE:NS]
	if { ![${NS}::UID_EXIST $IRC_USER] } { return }
	set USER_UID	[${NS}::UID_GET $IRC_USER]
	if { $USER_UID eq "" } { return }
	$SERVICEBOT_PIPELINE	 send ":$USER_UID NOTICE $CHANNEL_LOCAL :$IRC_MSG"
}

# Topic distant → salon local lié
proc ::ReplicaServ::IRC:VIRTUAL:TOPIC { IRC_NAME CHANNEL_DISTANT TOPIC_TEXT } {
	variable SERVICEBOT_PIPELINE
	variable IRCC_DATA
	variable config
	if { $CHANNEL_DISTANT eq "" } { return }
	if { ![::ReplicaServ::LINK:TOPIC:ENABLED $IRC_NAME $CHANNEL_DISTANT] } { return }
	set CHANNEL_LOCAL	[::ReplicaServ::DB:LINK:LOCAL $IRC_NAME $CHANNEL_DISTANT]
	if { $CHANNEL_LOCAL eq "" } { return }
	set text $TOPIC_TEXT
	if { [info exists config(replica_topic_prefix)] && $config(replica_topic_prefix) ne "" } {
		set text "$config(replica_topic_prefix)$text"
	}
	# Anti-spam : ignorer si inchangé
	set tkey [string tolower $CHANNEL_DISTANT]
	if { [info exists IRCC_DATA($IRC_NAME,TOPIC,$tkey)] \
		&& $IRCC_DATA($IRC_NAME,TOPIC,$tkey) eq $text } {
		return
	}
	set IRCC_DATA($IRC_NAME,TOPIC,$tkey) $text
	# Préférer TOPIC S2S (SID) — plus fiable qu’un TOPIC client
	if { [catch { ::ReplicaServ::SENT "TOPIC $CHANNEL_LOCAL :$text" } err] } {
		catch { $SERVICEBOT_PIPELINE topic $CHANNEL_LOCAL $text }
		if { $err ne "" } {
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "TOPIC $CHANNEL_LOCAL échoué: $err"
		}
	}
}
proc ::ReplicaServ::SENT { DATA } {
	variable SERVICEBOT_PIPELINE
	variable config
	$SERVICEBOT_PIPELINE	send ":$config(serverinfo_id) $DATA"
}
proc ::ReplicaServ::SENT:MSG:TO:USER { DEST MSG } {
	variable config
	# Ignore les lignes vides / seulement balises couleur
	set plain [regsub -all {<[^>]+>} $MSG ""]
	if { [string trim $plain] eq "" } { return }
	if { $config(uplink_useprivmsg) == 1 } {
		::ReplicaServ::SENT:PRIVMSG $DEST $MSG;
	} else {
		::ReplicaServ::SENT:NOTICE $DEST $MSG;
	}
}
proc ::ReplicaServ::SENT:MSG:TO:CHAN:LOG { MSG } {
	variable config
	::ReplicaServ::SENT:PRIVMSG $config(service_channel) $MSG;
}

proc ::ReplicaServ::DB:INIT { LISTDB } {
	foreach DB_FILE_NAME [split $LISTDB] {
		if { ![file exists "[::ReplicaServ::Get:ScriptDir "db"]${DB_FILE_NAME}"] } {
			set FILE_PIPE	[open "[::ReplicaServ::Get:ScriptDir "db"]${DB_FILE_NAME}" a+];
			close $FILE_PIPE
		}
	}
}
###############################################################################
### Substitution des symboles couleur/gras/soulignement/...
###############################################################################
# Modification de la fonction de MenzAgitat
# <cXX> : Ajouter un Couleur avec le code XX : <c01>; <c02,01>
# </c> : Enlever la Couleur (refermer la deniere declaration <cXX>) : </c>
# <b> : Ajouter le style Bold/gras
# </b> : Enlever le style Bold/gras
# <u> : Ajouter le style Underline/souligner
# </u> : Enlever le style Underline/souligner
# <i> : Ajouter le style Italic/Italique
# <s> : Enlever les styles precedent
proc ::ReplicaServ::apply_visuals { data } {
	regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} $data "\003\\1" data
	regsub -all -nocase {<b>|</b>} $data "\002" data
	regsub -all -nocase {<u>|</u>} $data "\037" data
	regsub -all -nocase {<i>|</i>} $data "\026" data
	return [regsub -all -nocase {<s>} $data "\017"]
}
proc ::ReplicaServ::Remove_visuals { data } {
	regsub -all -nocase {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>} $data "" data
	regsub -all -nocase {<b>|</b>} $data "" data
	regsub -all -nocase {<u>|</u>} $data "" data
	regsub -all -nocase {<i>|</i>} $data "" data
	return [regsub -all -nocase {<s>} $data ""]
}

proc ::ReplicaServ::TXT:ESPACE:DISPLAY { text length } {
	set text			[string trim $text]
	set text_length		[string length $text]
	# Évite string repeat négatif (crash) si texte trop long
	if { $text_length >= $length } {
		return [string range $text 0 [expr {$length - 1}]]
	}
	set espace_length	[expr {($length - $text_length) / 2.0}]
	set ESPACE_TMP		[split $espace_length .]
	set ESPACE_ENTIER	[lindex $ESPACE_TMP 0]
	set ESPACE_DECIMAL	[lindex $ESPACE_TMP 1]
	if { $ESPACE_DECIMAL == 0 } {
		set espace_one			[string repeat " " $ESPACE_ENTIER]
		set espace_two			[string repeat " " $ESPACE_ENTIER]
		return "$espace_one$text$espace_two"
	} else {
		set espace_one			[string repeat " " $ESPACE_ENTIER]
		set espace_two			[string repeat " " [expr {$ESPACE_ENTIER + 1}]]
		return "$espace_one$text$espace_two"
	}
}

proc ::ReplicaServ::IRC:QUIT { IRC_NAME MSG } {
	variable config
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Fermeture du Socket IRC :<c04> $IRC_NAME <c11>raison<c04> $MSG"
	::ReplicaServ::IRC:Sent $IRC_NAME "QUIT $MSG"
}
proc ::ReplicaServ::IRC:Sent { IRC_NAME arg } {
	variable config
	if { $config(uplink_debug) == 1 } {
		putlog "ReplicaServ IRC $IRC_NAME Sent: $arg"
	}
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC :<c04> $IRC_NAME <c11>Sent<c04> $arg"
	puts $config(idx_$IRC_NAME) $arg
}
proc ::ReplicaServ::Socket:Sent { arg } {
	variable config
	if { $config(uplink_debug) == 1 } {
		putlog "ReplicaServ Socket Sent: $arg"
	}
	puts $config(idx) $arg
}

proc ::ReplicaServ::CMD:LOG { cmd sender } {
	variable config
	# Ne jamais renvoyer le mot de passe admin dans #Services
	set safe $cmd
	if { [info exists config(admin_password)] && $config(admin_password) ne "" } {
		set safe [string map [list $config(admin_password) "***"] $safe]
	}
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Commandes :<c04> $safe <c12>par<c04> $sender"
}

proc ::ReplicaServ::CMD:SHOW:LIST { DEST } {
	set max				8;
	set l_espace		13;
	set CMD_LIST		""
	foreach CMD [::ReplicaServ::DB:CMD:LIST] {
		lappend CMD_LIST	"<c04>[::ReplicaServ::TXT:ESPACE:DISPLAY $CMD $l_espace]<c12>"
		if { [incr i] > $max-1 } {
			unset i
		::ReplicaServ::SENT:MSG:TO:USER $DEST [join $CMD_LIST " | "];
			set CMD_LIST	""
		}
	}
	::ReplicaServ::SENT:MSG:TO:USER $DEST [join $CMD_LIST " | "];
	::ReplicaServ::SENT:MSG:TO:USER $DEST "<c>";
}
proc ::ReplicaServ::DB:NETWORK:EXIST { DATA } {
	set DB_FILE		"[::ReplicaServ::Get:ScriptDir "db"]/network.db"
	if { ![file exist $DB_FILE] } { return "-1"; }
	set FILE_PIPE	[open $DB_FILE r];
	while { ![eof $FILE_PIPE] } {
		gets $FILE_PIPE FILE_DATA;
		if { [string equal -nocase $DATA [lindex $FILE_DATA 0]] } {
			close $FILE_PIPE;
			return 1;
		}
	}
	close $FILE_PIPE;
	return 0;
}

# Parse une adresse host:+port[:password] → {host port password} ou {}
proc ::ReplicaServ::DB:NETWORK:PARSE:ADDR { addr } {
	set addr [string trim $addr]
	if { $addr eq "" } { return [list] }
	if { ![regexp {^([^:]+):(\+?\d+)(?::(.*))?$} $addr -> host port password] } {
		return [list]
	}
	if { ![info exists password] } { set password "" }
	return [list $host $port $password]
}

# Plusieurs adresses séparées par des virgules
# Ex: irc.libera.chat:+6697,irc.eu.libera.chat:+6697
proc ::ReplicaServ::DB:NETWORK:PARSE:ADDRS { field } {
	set out [list]
	foreach piece [split $field ,] {
		set one [::ReplicaServ::DB:NETWORK:PARSE:ADDR $piece]
		if { [llength $one] == 0 } { continue }
		lappend out $one
	}
	return $out
}

# Affichage sans mot de passe
proc ::ReplicaServ::DB:NETWORK:ADDR:MASK { addr } {
	set one [::ReplicaServ::DB:NETWORK:PARSE:ADDR $addr]
	if { [llength $one] == 0 } { return $addr }
	set host [lindex $one 0]
	set port [lindex $one 1]
	set pass [lindex $one 2]
	if { $pass ne "" } { return "$host:$port:***" }
	return "$host:$port"
}

proc ::ReplicaServ::DB:NETWORK:ADDRS:MASK { field } {
	set parts [list]
	foreach piece [split $field ,] {
		set piece [string trim $piece]
		if { $piece eq "" } { continue }
		lappend parts [::ReplicaServ::DB:NETWORK:ADDR:MASK $piece]
	}
	return [join $parts ,]
}

# Formate host/port/pass → host:+port[:pass]
proc ::ReplicaServ::DB:NETWORK:ADDR:FMT { host port {password ""} } {
	set a "$host:$port"
	if { $password ne "" } { append a ":$password" }
	return $a
}

# Lit/écrit la ligne network.db pour un réseau
proc ::ReplicaServ::DB:NETWORK:GET:LINE { IRC_NAME } {
	set DB_FILE "[::ReplicaServ::Get:ScriptDir "db"]/network.db"
	if { ![file exists $DB_FILE] } { return "" }
	set fp [open $DB_FILE r]
	set found ""
	while { ![eof $fp] } {
		set line [gets $fp]
		if { $line eq "" } { continue }
		if { [string equal -nocase [lindex $line 0] $IRC_NAME] } {
			set found $line
			break
		}
	}
	close $fp
	return $found
}

proc ::ReplicaServ::DB:NETWORK:SET:ADDRS { IRC_NAME addr_field } {
	set DB_FILE "[::ReplicaServ::Get:ScriptDir "db"]/network.db"
	set line [::ReplicaServ::DB:NETWORK:GET:LINE $IRC_NAME]
	if { $line eq "" } { return 0 }
	set nick [lindex $line 1]
	set user [lindex $line 2]
	set new_line "$IRC_NAME $nick $user $addr_field"
	set fp [open $DB_FILE r]
	set out [list]
	while { ![eof $fp] } {
		set l [gets $fp]
		if { $l eq "" } { continue }
		if { [string equal -nocase [lindex $l 0] $IRC_NAME] } {
			lappend out $new_line
		} else {
			lappend out $l
		}
	}
	close $fp
	set fp [open $DB_FILE w+]
	foreach l $out { puts $fp $l }
	close $fp
	return 1
}

# Stocke la liste de serveurs + index courant dans IRCC_DATA
proc ::ReplicaServ::IRC:SERVERS:APPLY { IRC_NAME addr_field {reset_idx 1} } {
	variable IRCC_DATA
	set servers [::ReplicaServ::DB:NETWORK:PARSE:ADDRS $addr_field]
	if { [llength $servers] == 0 } { return 0 }
	set IRCC_DATA($IRC_NAME,ADDRS) $addr_field
	set IRCC_DATA($IRC_NAME,SERVERS) $servers
	if { $reset_idx || ![info exists IRCC_DATA($IRC_NAME,SERVER_IDX)] } {
		set IRCC_DATA($IRC_NAME,SERVER_IDX) 0
	} elseif { $IRCC_DATA($IRC_NAME,SERVER_IDX) >= [llength $servers] } {
		set IRCC_DATA($IRC_NAME,SERVER_IDX) 0
	}
	::ReplicaServ::IRC:SERVER:SELECT $IRC_NAME 0
	return 1
}

# advance=0 → serveur courant ; advance=1 → suivant (failover)
proc ::ReplicaServ::IRC:SERVER:SELECT { IRC_NAME {advance 0} } {
	variable IRCC_DATA
	if { ![info exists IRCC_DATA($IRC_NAME,SERVERS)] || [llength $IRCC_DATA($IRC_NAME,SERVERS)] == 0 } {
		return 0
	}
	set n [llength $IRCC_DATA($IRC_NAME,SERVERS)]
	if { ![info exists IRCC_DATA($IRC_NAME,SERVER_IDX)] } {
		set IRCC_DATA($IRC_NAME,SERVER_IDX) 0
	}
	if { $advance } {
		set IRCC_DATA($IRC_NAME,SERVER_IDX) [expr { ($IRCC_DATA($IRC_NAME,SERVER_IDX) + 1) % $n }]
	}
	set cur [lindex $IRCC_DATA($IRC_NAME,SERVERS) $IRCC_DATA($IRC_NAME,SERVER_IDX)]
	set IRCC_DATA($IRC_NAME,HOST) [lindex $cur 0]
	set IRCC_DATA($IRC_NAME,PORT) [lindex $cur 1]
	set IRCC_DATA($IRC_NAME,PASSWORD) [lindex $cur 2]
	return 1
}

proc ::ReplicaServ::DB:DATA:EXIST { DB DATA } {
	set DB_FILE		"[::ReplicaServ::Get:ScriptDir "db"]/${DB}.db"
	if { ![file exist $DB_FILE] } { return "-1"; }
	set FILE_PIPE	[open $DB_FILE r];
	while { ![eof $FILE_PIPE] } {
		gets $FILE_PIPE FILE_DATA;
		if { [string match -nocase $DATA $FILE_DATA] } {
			close $FILE_PIPE;
			return 1;
		}
	}
	close $FILE_PIPE;
	return 0;
}

proc ::ReplicaServ::DB:DISTANT:LINK:CONNECT { IRC_NAME CHAN_LOCAL CHAN_DISTANT } {
	variable config
	::ReplicaServ::Socket:Sent ":$config(service_nick) JOIN $CHAN_LOCAL"
	::ReplicaServ::IRC:Sent $IRC_NAME "JOIN $CHAN_DISTANT"
}
proc ::ReplicaServ::DB:DISTANT:ADD:LINK { NETWORK_NAME CHAN_LOCAL CHAN_DISTANT } {
	if { [string index $CHAN_LOCAL 0] != "#" } { return 0; }
	if { [string index $CHAN_DISTANT 0] != "#" } { return 0; }
	if { ![::ReplicaServ::DB:NETWORK:EXIST $NETWORK_NAME] } { return 0; }
	set DATA [list $NETWORK_NAME $CHAN_LOCAL $CHAN_DISTANT]
	if { [::ReplicaServ::DB:DATA:EXIST "channel_distant" $DATA] == 0 } {
		set DB_FILE		"[::ReplicaServ::Get:ScriptDir "db"]/channel_distant.db"
		set FILE_PIPE	[open $DB_FILE a];
		puts $FILE_PIPE $DATA;
		close $FILE_PIPE;
		::ReplicaServ::DB:LINK:RELOAD
		::ReplicaServ::DB:DISTANT:LINK:CONNECT $NETWORK_NAME $CHAN_LOCAL $CHAN_DISTANT
		return 1;
	} else {
		return -1;
	}
}

proc ::ReplicaServ::DB:DATA:REMOVE { DB DATA } {
	set DB_FILE			"[::ReplicaServ::Get:ScriptDir "db"]/${DB}.db"
	if { ![file exist $DB_FILE] } { return "-1"; }

	set FILE_PIPE		[open $DB_FILE r];
	set STATE			0;
	set FILE_NEW_DATA	[list];
	while { ![eof $FILE_PIPE] } {
		gets $FILE_PIPE FILE_DATA;
		if { [string match -nocase $DATA $FILE_DATA] } {
			set STATE		1;
		} elseif { $FILE_DATA != "" } {
			lappend FILE_NEW_DATA $FILE_DATA;
		}
	}
	close $FILE_PIPE
	set FILE_PIPE		[open $DB_FILE w+];
	foreach LINE_NEW $FILE_NEW_DATA { puts $FILE_PIPE $LINE_NEW }
	close $FILE_PIPE
	if { $DB eq "link" } { ::ReplicaServ::DB:LINK:RELOAD }
	return $STATE;
}
####################
#--> Procedures <--#
####################
proc ::ReplicaServ::IRC:AUTO:JOIN { IRC_NAME IRC_NICKNAME } {
	variable config
	::ReplicaServ::DB:LINK:RELOAD
	set FILE(LINK)	"[::ReplicaServ::Get:ScriptDir "db"]/link.db";
	set FILE_PIPE	[open $FILE(LINK) "r"];
	set delay_join	0
	set stagger 10000
	if { [info exists config(replica_channel_stagger_ms)] } {
		set stagger $config(replica_channel_stagger_ms)
	}
	while { ![eof $FILE_PIPE] } {
		set FILE_LINE	[gets $FILE_PIPE];
		if { $FILE_LINE != "" } {
			set F_IRC_NAME		[lindex $FILE_LINE 0];
			set F_CHAN_LOCAL	[lindex $FILE_LINE 1];
			set F_CHAN_DISTANT	[lindex $FILE_LINE 2];
			set F_FLAGS			[lrange $FILE_LINE 3 end]
			# equal -nocase (pas string match → évite les globs)
			if { [string equal -nocase $F_IRC_NAME $IRC_NAME] } {
				after $delay_join [list ::ReplicaServ::JOIN $F_CHAN_LOCAL]
				after $delay_join [list ::ReplicaServ::IRC:JOIN $IRC_NAME $F_CHAN_DISTANT]
				after $delay_join [list ::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>$IRC_NICKNAME LINK $IRC_NAME :<c04> $F_CHAN_LOCAL <c12>à<c04> $F_CHAN_DISTANT <c11>\[$F_FLAGS\]"]
				incr delay_join $stagger
			}
		}
	}
	close $FILE_PIPE
}

proc ::ReplicaServ::IRC:Reconnect { IRC_NAME {advance 1} } {
	variable IRCC_DATA
	variable config
	if { ![info exists IRCC_DATA($IRC_NAME,PIPELINE)] } { return }
	if { ![info exists IRCC_DATA($IRC_NAME,SERVERS)] && ![info exists IRCC_DATA($IRC_NAME,HOST)] } { return }
	# Failover : essayer le serveur suivant de la liste
	if { [info exists IRCC_DATA($IRC_NAME,SERVERS)] } {
		if { $advance && [llength $IRCC_DATA($IRC_NAME,SERVERS)] > 1 } {
			::ReplicaServ::IRC:SERVER:SELECT $IRC_NAME 1
		} else {
			::ReplicaServ::IRC:SERVER:SELECT $IRC_NAME 0
		}
	}
	if { ![info exists IRCC_DATA($IRC_NAME,HOST)] } { return }
	set PIPELINE	$IRCC_DATA($IRC_NAME,PIPELINE)
	set gecos "40 M Replica"
	if { [info exists config(replica_remote_gecos)] && $config(replica_remote_gecos) ne "" } {
		set gecos $config(replica_remote_gecos)
	}
	set idx 0
	set nsrv 1
	if { [info exists IRCC_DATA($IRC_NAME,SERVER_IDX)] } { set idx $IRCC_DATA($IRC_NAME,SERVER_IDX) }
	if { [info exists IRCC_DATA($IRC_NAME,SERVERS)] } { set nsrv [llength $IRCC_DATA($IRC_NAME,SERVERS)] }
	::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Reconnexion IRC '$IRC_NAME' → $IRCC_DATA($IRC_NAME,HOST):$IRCC_DATA($IRC_NAME,PORT) (serveur [expr {$idx+1}]/$nsrv)..."
	putlog "ReplicaServ: reconnect $IRC_NAME $IRCC_DATA($IRC_NAME,HOST):$IRCC_DATA($IRC_NAME,PORT)"
	set IRCC_DATA($IRC_NAME,AUTOJOINED) 0
	if { [catch {
		$PIPELINE connect $IRCC_DATA($IRC_NAME,HOST) $IRCC_DATA($IRC_NAME,PORT) $IRCC_DATA($IRC_NAME,PASSWORD)
		$PIPELINE user $IRCC_DATA($IRC_NAME,NICK) $IRCC_DATA($IRC_NAME,USER) $gecos
	} err] } {
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Reconnexion '$IRC_NAME' échouée: $err — prochain serveur dans 5s"
		putlog "ReplicaServ: reconnect fail $IRC_NAME: $err"
		after 5000 [list ::ReplicaServ::IRC:Reconnect $IRC_NAME 1]
	}
}

# IRC:Connexion name addrs nick user
# addrs = "host:+port[,host2:+port2...]"  (rétrocompat: anciens appels host port pass nick user ignorés via overload)
proc ::ReplicaServ::IRC:Connexion { IRC_NAME args } {
	variable config
	variable IRCC_DATA
	set IRC_NICKNAME ""
	set IRC_USERNAME ""
	set addr_field ""
	# Nouveau: Connexion name addrs nick user
	# Ancien:  Connexion name host port ?pass? ?nick? ?user?
	if { [llength $args] >= 3 && [string first ":" [lindex $args 0]] >= 0 } {
		set addr_field		[lindex $args 0]
		set IRC_NICKNAME	[lindex $args 1]
		set IRC_USERNAME	[lindex $args 2]
	} elseif { [llength $args] >= 2 } {
		set IRC_HOST		[lindex $args 0]
		set IRC_PORT		[lindex $args 1]
		set IRC_PASSWORD	""
		if { [llength $args] >= 3 } { set IRC_PASSWORD [lindex $args 2] }
		if { [llength $args] >= 4 } { set IRC_NICKNAME [lindex $args 3] }
		if { [llength $args] >= 5 } { set IRC_USERNAME [lindex $args 4] }
		set addr_field [::ReplicaServ::DB:NETWORK:ADDR:FMT $IRC_HOST $IRC_PORT $IRC_PASSWORD]
	} else {
		putlog "ReplicaServ: IRC:Connexion bad args for $IRC_NAME: $args"
		return
	}
	if { ![::ReplicaServ::IRC:SERVERS:APPLY $IRC_NAME $addr_field 0] } {
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Adresse(s) invalide(s) pour $IRC_NAME: $addr_field"
		return
	}
	set IRC_HOST		$IRCC_DATA($IRC_NAME,HOST)
	set IRC_PORT		$IRCC_DATA($IRC_NAME,PORT)
	set IRC_PASSWORD	$IRCC_DATA($IRC_NAME,PASSWORD)
	putlog "ReplicaServ: IRC:Connexion start $IRC_NAME $IRC_HOST $IRC_PORT ([llength $IRCC_DATA($IRC_NAME,SERVERS)] servers)"
	if { ![info exists IRCC_DATA($IRC_NAME,PIPELINE)] || $IRCC_DATA($IRC_NAME,PIPELINE) eq "" } {
		if { [catch { set IRCC_DATA($IRC_NAME,PIPELINE) [::IRCC::connection] } err] } {
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "IRCC::connection échoué ($IRC_NAME): $err"
			putlog "ReplicaServ: IRCC::connection fail $IRC_NAME: $err"
			after 30000 [list ::ReplicaServ::IRC:Connexion $IRC_NAME $addr_field $IRC_NICKNAME $IRC_USERNAME]
			return
		}
	}
	set IRCC_DATA($IRC_NAME,NICK)		$IRC_NICKNAME
	set IRCC_DATA($IRC_NAME,USER)		$IRC_USERNAME
	set IRCC_DATA($IRC_NAME,AUTOJOINED)	0
	set PIPELINE $IRCC_DATA($IRC_NAME,PIPELINE)
	if { [info exists config(uplink_debug)] && $config(uplink_debug) == 1 } {
		if { [catch { $PIPELINE config logger 1; $PIPELINE config debug 1 } err] } {
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Debug IRCC indisponible ($IRC_NAME): $err"
		}
	}

	# IMPORTANT: enregistrer les events AVANT connect/user (sinon 001 peut être manqué)
	$PIPELINE registerevent defaultevent {
		# silencieux hors debug
	}
	$PIPELINE registerevent defaultcmd {
	}
	$PIPELINE registerevent defaultnumeric {
	}
	$PIPELINE registerevent 001 "
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG \"Connexion IRC '$IRC_NAME' OK (001) → \$::ReplicaServ::IRCC_DATA($IRC_NAME,HOST):\$::ReplicaServ::IRCC_DATA($IRC_NAME,PORT)\"
		putlog \"ReplicaServ: 001 $IRC_NAME\"
		::ReplicaServ::IRC:AUTO:JOIN:ONCE $IRC_NAME $IRC_NICKNAME
	"
	$PIPELINE registerevent 376 "
		# Fin MOTD → filet de sécu si 001 déjà passé sans JOIN
		::ReplicaServ::IRC:AUTO:JOIN:ONCE $IRC_NAME $IRC_NICKNAME
	"
	$PIPELINE registerevent 422 "
		::ReplicaServ::IRC:AUTO:JOIN:ONCE $IRC_NAME $IRC_NICKNAME
	"
	# RPL_TOPIC (332) au JOIN + TOPIC live
	$PIPELINE registerevent 332 "
		set _add \[additional\]
		set _chan \"\"
		foreach _a \$_add {
			if { \[string index \$_a 0\] eq \"#\" } { set _chan \$_a; break }
		}
		if { \$_chan eq \"\" } { set _chan \[lindex \$_add 0\] }
		if { \$_chan eq \"\" } { set _chan \[target\] }
		::ReplicaServ::IRC:VIRTUAL:TOPIC $IRC_NAME \$_chan \[msg\]
	"
	$PIPELINE registerevent TOPIC "
		::ReplicaServ::IRC:VIRTUAL:TOPIC $IRC_NAME \[target\] \[msg\]
	"

	# EVENTS UTILISER
	$PIPELINE registerevent 353 "
		# Cache NAMES — format 353: (=/@/*) #chan :nicks  OU  #chan :nicks
		set _add \[additional\]
		set IRC_CHANNEL \"\"
		foreach _a \$_add {
			if { \[string index \$_a 0\] eq \"#\" } {
				set IRC_CHANNEL \[string tolower \$_a\]
				break
			}
		}
		if { \$IRC_CHANNEL eq \"\" } {
			set IRC_CHANNEL \[string tolower \[lindex \$_add end\]\]
		}
		if { \$IRC_CHANNEL eq \"\" || \[string index \$IRC_CHANNEL 0\] ne \"#\" } { return }
		set IRC_USERS_LIST	\[msg\]
		if { !\[info exists ::ReplicaServ::IRCC_DATA($IRC_NAME,NAMES,\$IRC_CHANNEL)\] } {
			set ::ReplicaServ::IRCC_DATA($IRC_NAME,NAMES,\$IRC_CHANNEL) \[list\]
		}
		foreach _u \[split \$IRC_USERS_LIST\] {
			set _mode \"\"
			while { \[regexp {^\[~&@%+\]} \$_u\] } {
				append _mode \[string index \$_u 0\]
				set _u \[string range \$_u 1 end\]
			}
			if { \$_u ne \"\" } {
				lappend ::ReplicaServ::IRCC_DATA($IRC_NAME,NAMES,\$IRC_CHANNEL) \$_u
				set ::ReplicaServ::IRCC_DATA($IRC_NAME,NMODE,\$IRC_CHANNEL,\$_u) \$_mode
			}
		}
	"
	$PIPELINE registerevent 352 "
		# 352: #chan ident host server nick flags :hop realname
		set _add \[additional\]
		set channel \[string tolower \[lindex \$_add 0\]\]
		if { \[string index \$channel 0\] ne \"#\" } {
			foreach _a \$_add {
				if { \[string index \$_a 0\] eq \"#\" } {
					set channel \[string tolower \$_a\]
					break
				}
			}
		}
		set ident		\[lindex \$_add 1\]
		set host		\[lindex \$_add 2\]
		set user		\[lindex \$_add 4\]
		set flags		\[lindex \$_add 5\]
		set realname	\[msg\]
		if { \[regexp {^\\d+\\s+(.*)$} \$realname -> _rn\] } { set realname \$_rn }
		if { \$user eq \"\" || \$channel eq \"\" } { return }
		after 0 \[list ::ReplicaServ::IRC:VIRTUAL:USER:ENQUEUE $IRC_NAME \$channel \$user \$ident \$host \$realname \$flags\]
	"
	$PIPELINE registerevent 315 "
		set channel \[string tolower \[lindex \[additional\] 0\]\]
		if { \$channel eq \"\" } { set channel \[string tolower \[lindex \[msg\] 0\]\] }
		after 500 \[list ::ReplicaServ::IRC:NAMES:BACKFILL $IRC_NAME \$channel\]
	"
	$PIPELINE registerevent 366 "
		set channel \[string tolower \[lindex \[additional\] 0\]\]
		if { \$channel eq \"\" } { set channel \[string tolower \[join \[additional\]\]\] }
		set ::ReplicaServ::IRCC_DATA($IRC_NAME,TMP_CHAN)	\$channel
		set ::ReplicaServ::IRCC_DATA($IRC_NAME,CHAN_STATE)	1
		putlog \"ReplicaServ: 366 $IRC_NAME \$channel names=[llength \$::ReplicaServ::IRCC_DATA($IRC_NAME,NAMES,\$channel)]\"
		$PIPELINE send \"WHO \$channel\"
		# BACKFILL immédiat + rappel (WHO peut omettre des +i)
		after 500 \[list ::ReplicaServ::IRC:NAMES:BACKFILL $IRC_NAME \$channel\]
		after 5000 \[list ::ReplicaServ::IRC:NAMES:BACKFILL $IRC_NAME \$channel\]
		after 30000 \[list ::ReplicaServ::IRC:NAMES:BACKFILL $IRC_NAME \$channel\]
	"
	$PIPELINE registerevent 433 "
		set _cur \$::ReplicaServ::IRCC_DATA($IRC_NAME,NICK)
		if { \[string equal -nocase \[lindex \[additional\] 0\] \$_cur\] } {
			set nicknew	\"\[string trimright \$_cur 0123456789\]\[string range \[expr {rand()}\] end-2 end\]\"
			cmd-send \"NICK \$nicknew\"
			set ::ReplicaServ::IRCC_DATA($IRC_NAME,NICK) \$nicknew
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG \"Le NICK '\$_cur' est utilisé sur $IRC_NAME.. je prend \$nicknew\"
		}
	"
	$PIPELINE registerevent PRIVMSG "
		::ReplicaServ::VPRIVMSG $IRC_NAME \[target\] \[who\] \[msg\]
	"
	$PIPELINE registerevent NOTICE "
		::ReplicaServ::VNOTICE $IRC_NAME \[target\] \[who\] \[msg\]
	"
	$PIPELINE registerevent JOIN "
		set _mask \[who 1\]
		set _nick \[lindex \[split \$_mask !\] 0\]
		set _ih   \[lindex \[split \$_mask !\] 1\]
		set _ident \[lindex \[split \$_ih @\] 0\]
		set _host  \[lindex \[split \$_ih @\] 1\]
		if { \$_ident eq \"\" } { set _ident \"~$IRC_NAME\" }
		if { \$_host eq \"\" } { set _host \"$IRC_NAME.remote\" }
		::ReplicaServ::IRC:VIRTUAL:USER:ENQUEUE $IRC_NAME \[target\] \$_nick \$_ident \$_host \"Remote user\"
	"
	$PIPELINE registerevent PART "
		::ReplicaServ::IRC:VIRTUAL:USER:PART $IRC_NAME \[target\] \[who\] \[msg\]
	"
	$PIPELINE registerevent QUIT "
		::ReplicaServ::IRC:VIRTUAL:USER:QUIT $IRC_NAME \[who\] \[msg\]
	"
	$PIPELINE registerevent KICK "
		::ReplicaServ::IRC:VIRTUAL:USER:PART $IRC_NAME \[target\] \[lindex \[additional\] 0\] \[msg\]
	"
	$PIPELINE registerevent NICK "
		::ReplicaServ::IRC:VIRTUAL:USER:NICK $IRC_NAME \[who\] \[msg\]
	"
	
	$PIPELINE registerevent EOF "
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG \"Deconnexion du IRC $IRC_NAME — reconnexion dans 5s\"
		putlog \"ReplicaServ: EOF $IRC_NAME\"
		set ::ReplicaServ::IRCC_DATA($IRC_NAME,AUTOJOINED) 0
		after 5000 \[list ::ReplicaServ::IRC:Reconnect $IRC_NAME\]
	"

	set gecos "40 M Replica"
	if { [info exists config(replica_remote_gecos)] && $config(replica_remote_gecos) ne "" } {
		set gecos $config(replica_remote_gecos)
	}
	if { [catch {
		$PIPELINE connect	$IRC_HOST $IRC_PORT $IRC_PASSWORD
		$PIPELINE user		$IRC_NICKNAME $IRC_USERNAME $gecos
	} err] } {
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Échec connexion IRC '$IRC_NAME' ($IRC_HOST:$IRC_PORT): $err — failover 5s"
		putlog "ReplicaServ: connect fail $IRC_NAME: $err"
		# Avancer l’index pour le prochain essai (Reconnect sans re-avancer)
		::ReplicaServ::IRC:SERVER:SELECT $IRC_NAME 1
		after 5000 [list ::ReplicaServ::IRC:Reconnect $IRC_NAME 0]
		return
	}
	putlog "ReplicaServ: connect+user sent $IRC_NAME → $IRC_HOST:$IRC_PORT"
}

proc ::ReplicaServ::IRC:AUTO:JOIN:ONCE { IRC_NAME IRC_NICKNAME } {
	variable IRCC_DATA
	if { [info exists IRCC_DATA($IRC_NAME,AUTOJOINED)] && $IRCC_DATA($IRC_NAME,AUTOJOINED) } {
		return
	}
	set IRCC_DATA($IRC_NAME,AUTOJOINED) 1
	putlog "ReplicaServ: AUTO:JOIN $IRC_NAME"
	::ReplicaServ::IRC:AUTO:JOIN $IRC_NAME $IRC_NICKNAME
}

	
proc ::ReplicaServ::IRC:VIRTUAL:USER:ENQUEUE { args } {
	variable IRCC_DATA
	# args: IRC_NAME CHANNEL USERNAME ...
	set IRC_NAME [lindex $args 0]
	set CHANNEL  [string tolower [lindex $args 1]]
	set USERNAME [lindex $args 2]
	if { $IRC_NAME eq "" || $CHANNEL eq "" || $USERNAME eq "" } { return }
	set qkey [string tolower "$IRC_NAME|$CHANNEL|$USERNAME"]
	if { [info exists IRCC_DATA(QMARK,$qkey)] } { return }
	if { [info exists IRCC_DATA(VUSER_IN,$IRC_NAME,$CHANNEL,$USERNAME)] } { return }
	set IRCC_DATA(QMARK,$qkey) 1
	if { ![info exists IRCC_DATA(SJOIN_Q)] } {
		set IRCC_DATA(SJOIN_Q) [list]
	}
	# Normaliser le channel en minuscules dans la queue
	set args [lreplace $args 1 1 $CHANNEL]
	lappend IRCC_DATA(SJOIN_Q) $args
	if { ![info exists IRCC_DATA(SJOIN_BUSY)] || !$IRCC_DATA(SJOIN_BUSY) } {
		set IRCC_DATA(SJOIN_BUSY) 1
		after 50 [list ::ReplicaServ::IRC:VIRTUAL:USER:DRAIN]
	}
}

proc ::ReplicaServ::IRC:VIRTUAL:USER:DRAIN {} {
	variable IRCC_DATA
	variable config
	if { ![info exists IRCC_DATA(SJOIN_Q)] || [llength $IRCC_DATA(SJOIN_Q)] == 0 } {
		set IRCC_DATA(SJOIN_BUSY) 0
		return
	}
	set args [lindex $IRCC_DATA(SJOIN_Q) 0]
	set IRCC_DATA(SJOIN_Q) [lrange $IRCC_DATA(SJOIN_Q) 1 end]
	if { [catch { ::ReplicaServ::IRC:VIRTUAL:USER:CREATE {*}$args } err] } {
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "CREATE queue err: $err | $args"
	}
	set iv 200
	if { [info exists config(replica_sjoin_interval_ms)] } {
		set iv $config(replica_sjoin_interval_ms)
	}
	after $iv [list ::ReplicaServ::IRC:VIRTUAL:USER:DRAIN]
}

proc ::ReplicaServ::NICK:SANITIZE { nick } {
	# Unreal : A-Za-z0-9[]\`_^{|}- ; 1er char non numérique
	set nick [string range $nick 0 29]
	regsub -all {[^A-Za-z0-9\[\]\\`_^{|}-]} $nick {_} nick
	if { $nick eq "" } { return "" }
	if { [regexp {^[0-9-]} $nick] } {
		set nick "u$nick"
		set nick [string range $nick 0 29]
	}
	return $nick
}

proc ::ReplicaServ::IDENT:SANITIZE { ident IRC_NAME } {
	if { $ident eq "" } { set ident "~$IRC_NAME" }
	regsub -all {[^A-Za-z0-9._~-]} $ident {_} ident
	set ident [string range $ident 0 9]
	if { $ident eq "" } { set ident "replica" }
	return $ident
}

proc ::ReplicaServ::IRC:VIRTUAL:USER:CREATE { IRC_NAME CHANNEL_DISTANT USERNAME USERIDENT USERHOST REALNAME {FLAGS ""} } {
	variable SERVICE_PIPELINE
	variable SERVICEBOT_PIPELINE
	variable IRCC_DATA
	variable config
	if { ![::ReplicaServ::CFG:ON replica_sync_users] } { return }
	if { [::ReplicaServ::DB:LINK:HAS:FLAG $IRC_NAME $CHANNEL_DISTANT nousers] } { return }
	set CHANNEL_DISTANT [string tolower $CHANNEL_DISTANT]
	set USERNAME [::ReplicaServ::NICK:SANITIZE $USERNAME]
	if { $USERNAME eq "" } { return }
	set USERIDENT [::ReplicaServ::IDENT:SANITIZE $USERIDENT $IRC_NAME]
	if { $USERHOST eq "" } { set USERHOST "$IRC_NAME.remote" }
	# Host trop long (Unreal ~63) 
	if { [string length $USERHOST] > 63 } {
		set USERHOST [string range $USERHOST 0 62]
	}
	if { $REALNAME eq "" } { set REALNAME "Remote user" }
	if { [string length $REALNAME] > 50 } {
		set REALNAME [string range $REALNAME 0 49]
	}
	# Ne pas cloner notre propre bot distant
	if { [info exists IRCC_DATA($IRC_NAME,NICK)] && [string equal -nocase $USERNAME $IRCC_DATA($IRC_NAME,NICK)] } {
		return
	}
	set CHANNEL_LOCAL	[::ReplicaServ::DB:LINK:LOCAL $IRC_NAME $CHANNEL_DISTANT]
	if { $CHANNEL_LOCAL eq "" } { return }

	set NS	[::ReplicaServ::SERVICE:NS]
	set create_nick	$USERNAME
	# Collision avec un nick déjà présent (autre réseau / user local) → suffixe réseau
	if { [${NS}::UID_EXIST $create_nick] } {
		if { ![info exists IRCC_DATA(VUSER,$create_nick)] || $IRCC_DATA(VUSER,$create_nick) ne $IRC_NAME } {
			if { ![::ReplicaServ::CFG:ON replica_nick_suffix] } {
				return
			}
			set create_nick	"${USERNAME}_$IRC_NAME"
			# Unreal nick max ~30
			if { [string length $create_nick] > 30 } {
				set create_nick [string range $create_nick 0 29]
			}
			set create_nick [::ReplicaServ::NICK:SANITIZE $create_nick]
			if { $create_nick eq "" } { return }
		}
	}

	if { [${NS}::UID_EXIST $create_nick] } {
		set USERUID	[${NS}::UID_GET $create_nick]
	} else {
		if { [catch {
			set USERUID	[$SERVICE_PIPELINE vusercreate $create_nick $USERIDENT $USERHOST $REALNAME]
		} err] } {
			putlog "ReplicaServ: vusercreate fail $create_nick ($IRC_NAME): $err"
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "vusercreate $create_nick ($IRC_NAME/$USERNAME) échoué: $err"
			return
		}
		set IRCC_DATA(VUSER,$create_nick) $IRC_NAME
		set IRCC_DATA(VUSER_ORIG,$IRC_NAME,$USERNAME) $create_nick
	}
	if { $USERUID eq "" } { return }
	# Préfixe SJOIN Unreal : ~ owner, & admin, @ op, % halfop, + voice
	set sjoin_pfx ""
	if { [::ReplicaServ::CFG:ON replica_sync_modes] \
		&& ![::ReplicaServ::DB:LINK:HAS:FLAG $IRC_NAME $CHANNEL_DISTANT nomodes] } {
		set pfx_src $FLAGS
		if { [info exists IRCC_DATA($IRC_NAME,NMODE,$CHANNEL_DISTANT,$USERNAME)] \
			&& $IRCC_DATA($IRC_NAME,NMODE,$CHANNEL_DISTANT,$USERNAME) ne "" } {
			set pfx_src $IRCC_DATA($IRC_NAME,NMODE,$CHANNEL_DISTANT,$USERNAME)
		}
		if { [string first "~" $pfx_src] >= 0 } {
			set sjoin_pfx "~"
		} elseif { [string first "&" $pfx_src] >= 0 } {
			set sjoin_pfx "&"
		} elseif { [string first "@" $pfx_src] >= 0 } {
			set sjoin_pfx "@"
		} elseif { [string first "%" $pfx_src] >= 0 } {
			set sjoin_pfx "%"
		} elseif { [string first "+" $pfx_src] >= 0 } {
			set sjoin_pfx "+"
		}
	}
	if { [catch {
		::ReplicaServ::SENT "SJOIN [clock seconds] $CHANNEL_LOCAL + :${sjoin_pfx}$USERUID"
	} err] } {
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "SJOIN $create_nick → $CHANNEL_LOCAL échoué: $err"
		return
	}
	set IRCC_DATA(VUSER_IN,$IRC_NAME,$CHANNEL_DISTANT,$USERNAME) 1
	catch { unset IRCC_DATA(QMARK,[string tolower "$IRC_NAME|$CHANNEL_DISTANT|$USERNAME"]) }
	# Forcer les modes canal après SJOIN (préfixe parfois ignoré)
	if { $sjoin_pfx ne "" && [::ReplicaServ::CFG:ON replica_sync_modes] } {
		set _m ""
		switch -exact -- $sjoin_pfx {
			"~" { set _m "q" }
			"&" { set _m "a" }
			"@" { set _m "o" }
			"%" { set _m "h" }
			"+" { set _m "v" }
		}
		if { $_m ne "" } {
			after 250 [list ::ReplicaServ::SENT "MODE $CHANNEL_LOCAL +$_m $USERUID"]
			after 400 [list ::ReplicaServ::SENT "MODE $CHANNEL_LOCAL +$_m $create_nick"]
		}
	}
}

proc ::ReplicaServ::IRC:NAMES:BACKFILL { IRC_NAME CHANNEL_DISTANT } {
	variable IRCC_DATA
	set CHANNEL_DISTANT [string tolower $CHANNEL_DISTANT]
	# Tolérer clés avec casse différente
	set names [list]
	if { [info exists IRCC_DATA($IRC_NAME,NAMES,$CHANNEL_DISTANT)] } {
		set names $IRCC_DATA($IRC_NAME,NAMES,$CHANNEL_DISTANT)
	} else {
		foreach k [array names IRCC_DATA "$IRC_NAME,NAMES,*"] {
			set ch [lindex [split $k ,] 2]
			if { [string equal -nocase $ch $CHANNEL_DISTANT] } {
				set names $IRCC_DATA($k)
				break
			}
		}
	}
	if { [llength $names] == 0 } { return }
	# Dédupliquer
	set seen [dict create]
	foreach nick $names {
		set nk [string tolower $nick]
		if { [dict exists $seen $nk] } { continue }
		dict set seen $nk 1
		if { [info exists IRCC_DATA($IRC_NAME,NICK)] && [string equal -nocase $nick $IRCC_DATA($IRC_NAME,NICK)] } {
			continue
		}
		if { [info exists IRCC_DATA(VUSER_IN,$IRC_NAME,$CHANNEL_DISTANT,$nick)] } {
			continue
		}
		# VUSER_IN peut être sous une autre casse de nick
		set skip 0
		foreach vk [array names IRCC_DATA "VUSER_IN,$IRC_NAME,$CHANNEL_DISTANT,*"] {
			set vn [lindex [split $vk ,] 3]
			if { [string equal -nocase $vn $nick] } { set skip 1; break }
		}
		if { $skip } { continue }
		::ReplicaServ::IRC:VIRTUAL:USER:ENQUEUE $IRC_NAME $CHANNEL_DISTANT $nick "~$IRC_NAME" "$IRC_NAME.remote" "Remote user (names)"
	}
}

proc ::ReplicaServ::IRC:VIRTUAL:USER:PART { IRC_NAME CHANNEL_DISTANT USERNAME {REASON ""} } {
	variable SERVICEBOT_PIPELINE
	variable IRCC_DATA
	if { $USERNAME eq "" } { return }
	set CHANNEL_LOCAL	[::ReplicaServ::DB:LINK:LOCAL $IRC_NAME $CHANNEL_DISTANT]
	if { $CHANNEL_LOCAL eq "" } { return }
	catch { unset IRCC_DATA(VUSER_IN,$IRC_NAME,$CHANNEL_DISTANT,$USERNAME) }
	set NS	[::ReplicaServ::SERVICE:NS]
	if { ![${NS}::UID_EXIST $USERNAME] } { return }
	set USER_UID	[${NS}::UID_GET $USERNAME]
	if { $REASON eq "" } {
		$SERVICEBOT_PIPELINE send ":$USER_UID PART $CHANNEL_LOCAL"
	} else {
		$SERVICEBOT_PIPELINE send ":$USER_UID PART $CHANNEL_LOCAL :$REASON"
	}
}

proc ::ReplicaServ::IRC:VIRTUAL:USER:QUIT { IRC_NAME USERNAME {REASON "Quit"} } {
	variable SERVICEBOT_PIPELINE
	variable IRCC_DATA
	if { $USERNAME eq "" } { return }
	if { [info exists IRCC_DATA($IRC_NAME,NICK)] && [string equal -nocase $USERNAME $IRCC_DATA($IRC_NAME,NICK)] } {
		return
	}
	set NS	[::ReplicaServ::SERVICE:NS]
	if { ![${NS}::UID_EXIST $USERNAME] } { return }
	set USER_UID	[${NS}::UID_GET $USERNAME]
	$SERVICEBOT_PIPELINE send ":$USER_UID QUIT :$REASON"
	# Retirer du cache UID (nick + uid)
	catch { unset ${NS}::UID_DB([string toupper $USERNAME]) }
	catch { unset ${NS}::UID_DB([string toupper $USER_UID]) }
}

proc ::ReplicaServ::IRC:VIRTUAL:USER:NICK { IRC_NAME OLDNICK NEWNICK } {
	variable SERVICEBOT_PIPELINE
	variable IRCC_DATA
	if { $OLDNICK eq "" || $NEWNICK eq "" } { return }
	if { [info exists IRCC_DATA($IRC_NAME,NICK)] && [string equal -nocase $OLDNICK $IRCC_DATA($IRC_NAME,NICK)] } {
		set IRCC_DATA($IRC_NAME,NICK) $NEWNICK
		return
	}
	set NS	[::ReplicaServ::SERVICE:NS]
	if { ![${NS}::UID_EXIST $OLDNICK] } { return }
	set USER_UID	[${NS}::UID_GET $OLDNICK]
	$SERVICEBOT_PIPELINE send ":$USER_UID NICK $NEWNICK [clock seconds]"
	catch { unset ${NS}::UID_DB([string toupper $OLDNICK]) }
	set ${NS}::UID_DB([string toupper $NEWNICK]) $USER_UID
	set ${NS}::UID_DB([string toupper $USER_UID]) $NEWNICK
}

proc ::ReplicaServ::IRC:Event { IRC_NAME } {
	variable config
	if { [eof $config(idx_$IRC_NAME)] } {
		fileevent $config(idx_$IRC_NAME) readable "";
		::ReplicaServ::IRC:QUIT $IRC_NAME "fermeture par le serveur"
		putlog "Socket IRC $IRC_NAME closed\n";
		close $config(idx_$IRC_NAME)
		unset config(idx_$IRC_NAME);
		::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC:<c04> closed <c12>de<c04> $IRC_NAME";
		return
	}
	gets $config(idx_$IRC_NAME) arg
	set arg [split $arg]

	#::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC :<c04> $IRC_NAME <c12>Receive<c04> $arg"
	putlog "[lindex $arg 0] ::IRC:Event recoi $arg"
	switch -exact [lindex $arg 0] {
		"PING" {
			::ReplicaServ::IRC:Sent $IRC_NAME "PONG [lindex $arg 1]"
		}
		"ERROR" {
			set MSG_ERR [string trim [lrange $arg 1 end] :]
			putlog "::ReplicaServ IRC $IRC_NAME error : $MSG_ERR"
			exit "ReplicaServ quit"
		}
	}
	switch -exact [lindex $arg 1] {
		"ERROR"	{
			set MSG_ERR [string trim [lrange $arg 1 end] :]
			putlog "::ReplicaServ IRC $IRC_NAME error : $MSG_ERR"
			exit "ReplicaServ quit"
		}
		"352" {
			# 352 ZarTek2 #feral ~limnoria 2607:5300:60:814::1 sinisalo.freenode.net feralbot2 H :0 Limnoria Limnoria 2016.12.08
			# 352 ZarTek2 #feral ~joshua 185.21.216.160 beckett.freenode.net _Lemon_ H :0 Unknown
			# 352 ZarTek2 #feral EpicKitty unaffiliated/epickitty wilhelm.freenode.net EpicKitty H :0 Richard Bowey
			# 352 ZarTek2 #feral ~epollyon 185.21.216.154 beckett.freenode.net ant1mony_ H :0 Unknown
			set channel		[lindex $arg 3]
			set ident		[lindex $arg 4]
			set host		[lindex $arg 5]
			set user		[lindex $arg 7]
			set realname	[join [lrange $arg 10 end]]
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "------------> $channel ->> $user!$ident@$host"
			#poupee::creer "$user!$ident@$host" [rvv $proxy::salon] $realname	1
			::ReplicaServ::IRC:VIRTUAL:USER:CREATE "$user!$ident@$host" $channel $realname	1
			#if [regexp {\*} [lindex $arg 8]] { puts $::socket(poupee) ":$user MODE $user +o"; print "ircop depuis 332" }
			# Who
			
		}
		"353"	{
			# 353 ZarTek2 = #feral :ZarTek2 ZarTek ozymandias_ ant1mony_ EpicKitty _Lemon_ feralbot2 knv2[m] 
			regexp {^\S+ \d+ \S+ \S (\S+) :(.+)$} [join $arg] - IRC_CHANNEL IRC_USERS_LIST
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC :<c04> $IRC_NAME <c11>$IRC_CHANNEL<c04> $IRC_USERS_LIST"
			# /NAMES
		}
		"366"	{
			# 366 ZarTek2 #feral :End of /NAMES list.
			regexp {^\S+ \d+ \S+ (\S+)} [join $arg] - IRC_CHANNEL
			# poupee::classer $IRC_CHANNEL
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC :<c04> $IRC_NAME <c11>FIN DE /NAMES<c04> $IRC_CHANNEL"
			::ReplicaServ::IRC:Sent $IRC_NAME		"WHO $IRC_CHANNEL"
			# if {$proxy::who == "1"} { puts $::socket(proxy) "WHO $proxy::salon" }
			# Fin de /NAMES
		}
		"372"	{
			# 372 ZarTek2 :- Welcome to barjavel.freenode.net in Paris, FR, EU. {}
			# 372 ZarTek2 :- Thanks to Bearstech (www.bearstech.com) for sponsoring
		}
		"375"	{
			# 375 ZarTek2 :- barjavel.freenode.net Message of the Day - {}
		}
		"376"	{
			# 376 ZarTek2 :End of /MOTD command.
		}
		"433"	{
			# 433 * RepliBoy :Nickname is already in use.'
			# Nickname already in use
			set nick [lindex $arg 3]
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Pseudo deja utiliser<c04> $nick <c11>sur<c04> $IRC_NAME"
			
			::ReplicaServ::IRC:QUIT $IRC_NAME "Pseudo '$nick' deja utiliser"
		}
		default {
			putlog "ReplicaServ IRC $IRC_NAME Received: ([lindex $arg 1]) '$arg'" 
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "<c12>Socket IRC :<c04> $IRC_NAME <c11>Received<c04> $arg"
		}
	}
}

proc ::ReplicaServ::Socket:Event { } {
	variable config
	global ::ReplicaServ::UID_DB
	if [eof $config(idx)] {
		fileevent $config(idx) readable ""
		close $config(idx)
		putlog "Socket closed\n"
		return
	}

	gets $config(idx) arg
	set arg [split $arg]

	if { $config(uplink_debug) == 1 } { 
		putlog "ReplicaServ Socket Received: '$arg'" 
		
	}
	switch -exact [lindex $arg 0] {
		"ERROR" {
			set MSG_ERR [string trim [lrange $arg 1 end] :]
			putlog "::ReplicaServ Socket error : $MSG_ERR"
			exit "ReplicaServ quit"
		}
		"PING" {
			::ReplicaServ::Socket:Sent "PONG [lindex $arg 1]"
		}
		"NETINFO" {
			set config(netinfo)		[lindex $arg 4]
			set config(network)		[lindex $arg 8]
			::ReplicaServ::Socket:Sent "NETINFO 0 [unixtime] 0 $config(netinfo) 0 0 0 $config(network)"
		}
		"SQUIT" {
			set serv		[lindex $arg 1]
			::ReplicaServ::SENT:MSG:TO:CHAN:LOG "Unlink: $serv"
		}
		"SERVER" {
			# Received: SERVER irc.xxx.net 1 :U5002-Fhn6OoEmM-001 Serveur networkname
			if { $config(init) == 1 } {
				::ReplicaServ::Server:Connexion
			}
		}
	}
}


# --> Auth admin (mot de passe en DERNIER argument des commandes NETWORK/LINK)
proc ::ReplicaServ::AUTH:ADMIN { sender data } {
	variable config
	set pass [lindex $data end]
	if { $pass eq "" || $pass ne $config(admin_password) } {
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>Accès refusé. Syntaxe : /msg $config(service_nick) <commande> ... <mot_de_passe_admin>"
		return 0
	}
	return 1
}
proc ::ReplicaServ::AUTH:STRIP { data } {
	# Retire le dernier mot (mot de passe)
	if { [llength $data] == 0 } { return $data }
	return [lrange $data 0 end-1]
}

#######################
# --> Commandes <-- #
#######################

proc ::ReplicaServ::IRC:CMD:PRIV:LINK { sender destination cmd data } {
	variable config
	variable IRCC_DATA
	variable SERVICEBOT_PIPELINE
	set sub_cmd		[string tolower [lindex $data 0]];
	set cmd_data	[lrange $data 1 end];
	set DB_FILE		"[::ReplicaServ::Get:ScriptDir "db"]/link.db"
	if { $sub_cmd == "add" } {
		if { [lindex $cmd_data 2] == "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide d'ajout de link<c04> :."
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd $sub_cmd <réseau> <#local> <#distant> \[flags...\]"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> Flags:<c04> notopic topic nomodes nousers nomsg"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> Exemple:<c04> /msg $config(service_nick) $cmd $sub_cmd entrechat #!accueil! #!accueil! notopic"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			return 0;
		}
		set IRC_NAME		[lindex $cmd_data 0]
		set CHAN_LOCAL		[lindex $cmd_data 1];
		set CHAN_DISTANT	[lindex $cmd_data 2];
		set FLAGS			[lrange $cmd_data 3 end]
		if { [string index $CHAN_LOCAL 0] ne "#" || [string index $CHAN_DISTANT 0] ne "#" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Les salons doivent commencer par #."
			return 0
		}
		if { ![info exists IRCC_DATA($IRC_NAME,PIPELINE)] } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Réseau '$IRC_NAME' non connecté."
			return 0
		}
		if { ![::ReplicaServ::DB:NETWORK:EXIST $IRC_NAME] } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Aucun réseau '$IRC_NAME'."
			return 0
		}
		set FILE_PIPE		[open $DB_FILE "r"]
		set state			0
		while {![eof $FILE_PIPE]} {
			set FILE_LINE	[gets $FILE_PIPE]
			if { $FILE_LINE != "" } {
				if { [string equal -nocase [lindex $FILE_LINE 0] $IRC_NAME] \
					&& [string equal -nocase [lindex $FILE_LINE 1] $CHAN_LOCAL] \
					&& [string equal -nocase [lindex $FILE_LINE 2] $CHAN_DISTANT] } { set state 1 }
			}
		}
		close $FILE_PIPE
		if { $state == 1 } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Link existe deja."
			return 0
		}
		set FILE_PIPE		[open $DB_FILE a]
		puts $FILE_PIPE		[concat $IRC_NAME $CHAN_LOCAL $CHAN_DISTANT $FLAGS]
		close $FILE_PIPE
		::ReplicaServ::DB:LINK:RELOAD
		::ReplicaServ::JOIN $CHAN_LOCAL
		::ReplicaServ::IRC:JOIN $IRC_NAME $CHAN_DISTANT
		::ReplicaServ::SENT:MSG:TO:USER $sender "Link ajouté $IRC_NAME $CHAN_LOCAL ↔ $CHAN_DISTANT \[$FLAGS\]"

	} elseif { $sub_cmd == "topic" } {
		# LINK TOPIC on|off <réseau> <#local> <#distant>
		set onoff [string tolower [lindex $cmd_data 0]]
		set IRC_NAME [lindex $cmd_data 1]
		set CHAN_LOCAL [lindex $cmd_data 2]
		set CHAN_DISTANT [lindex $cmd_data 3]
		if { $onoff eq "" || $IRC_NAME eq "" || $CHAN_LOCAL eq "" || $CHAN_DISTANT eq "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd topic on|off <réseau> <#local> <#distant>"
			return 0
		}
		set flags [::ReplicaServ::DB:LINK:FLAGS $IRC_NAME $CHAN_DISTANT]
		if { [::ReplicaServ::DB:LINK:LOCAL $IRC_NAME $CHAN_DISTANT] eq "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Link introuvable."
			return 0
		}
		# Retirer topic/notopic existants
		set newflags [list]
		foreach f $flags {
			if { ![string equal -nocase $f topic] && ![string equal -nocase $f notopic] } {
				lappend newflags $f
			}
		}
		if { $onoff eq "on" || $onoff eq "1" || $onoff eq "yes" } {
			lappend newflags topic
		} elseif { $onoff eq "off" || $onoff eq "0" || $onoff eq "no" } {
			lappend newflags notopic
		} else {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Utilisez on ou off."
			return 0
		}
		if { ![::ReplicaServ::DB:LINK:SET:FLAGS $IRC_NAME $CHAN_LOCAL $CHAN_DISTANT $newflags] } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Échec mise à jour flags."
			return 0
		}
		::ReplicaServ::SENT:MSG:TO:USER $sender "Topic sync $onoff pour $IRC_NAME $CHAN_LOCAL ↔ $CHAN_DISTANT"

	} elseif { $sub_cmd == "list" } {
		set FILE_PIPE	[open $DB_FILE "r"]
		set space	15
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>-------------------------------------------------------"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c12>[::ReplicaServ::TXT:ESPACE:DISPLAY RESEAU $space] <c04>|<c12> LOCAL <c04>|<c12> DISTANT <c04>|<c12> FLAGS"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>-------------------------------------------------------"
		while {![eof $FILE_PIPE]} {
			set FILE_LINE	[gets $FILE_PIPE]
			if { $FILE_LINE != "" } {
				set IRC_NAME		[::ReplicaServ::TXT:ESPACE:DISPLAY [lindex $FILE_LINE 0] $space];
				set CHANNEL_LOCAL	[lindex $FILE_LINE 1];
				set CHANNEL_DISTANT	[lindex $FILE_LINE 2];
				set FLAGS			[lrange $FILE_LINE 3 end]
				::ReplicaServ::SENT:MSG:TO:USER $sender "<c07>$IRC_NAME <c04>|<c07> $CHANNEL_LOCAL <c04>|<c07> $CHANNEL_DISTANT <c04>|<c07> $FLAGS"
			}
		}
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>-------------------------------------------------------"
		close $FILE_PIPE
	} elseif { $sub_cmd == "remove" } {
		if { [lindex $cmd_data 2] == "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide de supression de Link<c04> :."
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd $sub_cmd <réseau> <CHANNEL_LOCAL> <CHANNEL_DISTANT>"
			return 0;
		}
		set IRC_NAME		[lindex $cmd_data 0]
		set CHANNEL_LOCAL	[lindex $cmd_data 1]
		set CHANNEL_DISTANT	[lindex $cmd_data 2]

		set FILE_PIPE		[open $DB_FILE r];
		set STATE			0;
		set FILE_NEW_DATA	[list];
		while { ![eof $FILE_PIPE] } {
			gets $FILE_PIPE FILE_DATA;
			if { [string equal -nocase [lindex $FILE_DATA 0] $IRC_NAME] \
				&& [string equal -nocase [lindex $FILE_DATA 1] $CHANNEL_LOCAL] \
				&& [string equal -nocase [lindex $FILE_DATA 2] $CHANNEL_DISTANT] } {
				set STATE		1;
			} elseif { $FILE_DATA != "" } {
				lappend FILE_NEW_DATA $FILE_DATA;
			}
		}
		close $FILE_PIPE
		set FILE_PIPE		[open $DB_FILE w+];
		foreach LINE_NEW $FILE_NEW_DATA { puts $FILE_PIPE $LINE_NEW }
		close $FILE_PIPE
		::ReplicaServ::DB:LINK:RELOAD
		if { $STATE } {
			set IRC_PIPELINE	"$IRCC_DATA($IRC_NAME,PIPELINE)"
			::ReplicaServ::CMD:LOG "Suppression du link $IRC_NAME de $CHANNEL_DISTANT à $CHANNEL_LOCAL réussi.." $sender
			catch { $IRC_PIPELINE part $CHANNEL_DISTANT }
			catch { $SERVICEBOT_PIPELINE part $CHANNEL_LOCAL }
			::ReplicaServ::SENT:MSG:TO:USER $sender "Suppression du link $IRC_NAME de $CHANNEL_DISTANT à $CHANNEL_LOCAL réussi.."
			return 1
		} else {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Link  $IRC_NAME de $CHANNEL_DISTANT à $CHANNEL_LOCAL  non trouver.."
		}
		return 0
	} else {
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide Link<c04> :."
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Link Add" 15]<c12>- <c06>Ajoute un Link (+ flags optionnels)"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Link Remove" 15]<c12>- <c06>Suprime un Link"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Link List" 15]<c12>- <c06>Liste des Links"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Link Topic" 15]<c12>- <c06>on|off topic sync pour un link"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
	}
	::ReplicaServ::CMD:LOG "$cmd $sub_cmd $cmd_data" $sender
}
proc ::ReplicaServ::IRC:CMD:PRIV:NETWORK { sender destination cmd data } {
	variable config
	variable IRCC_DATA
	set sub_cmd		[string tolower [lindex $data 0]];
	set cmd_data	[lrange $data 1 end];
	set DB_FILE		"[::ReplicaServ::Get:ScriptDir "db"]/network.db"
	if { $sub_cmd == "add" } {
		if { [lindex $cmd_data 3] == "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide d'ajout de réseau<c04> :."
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd $sub_cmd <nom> <nickname> <username> <host:<\[+\]port>\[,host2:<\[+\]port>...\]>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> Exemple:<c04> /msg $config(service_nick) $cmd $sub_cmd libera AmiZoneRS1 services irc.libera.chat:+6697,irc.eu.libera.chat:+6697"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			return 0;
		}
		set IRC_NAME		[lindex $cmd_data 0]
		set IRC_NICKNAME	[lindex $cmd_data 1]; # nick irc
		set IRC_USERNAME	[lindex $cmd_data 2]; # ident
		set IRC_ADDRESS		[lindex $cmd_data 3]; # host:port[,host2:port2...][:password par adresse]

		set servers [::ReplicaServ::DB:NETWORK:PARSE:ADDRS $IRC_ADDRESS]
		if { [llength $servers] == 0 } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Adresse(s) invalide(s). Format: host:+port[,host2:+port2...]"
			return 0
		}
		set first [lindex $servers 0]
		set IRC_HOST [lindex $first 0]
		set IRC_PORT [lindex $first 1]
		set IRC_PASSWORD [lindex $first 2]
		
		set FILE_PIPE	[open $DB_FILE "r"]
		set fc	-1

		while {![eof $FILE_PIPE]} {
			set FILE_LINE	[gets $FILE_PIPE]
			incr fc
			if { $FILE_LINE != "" } {
				set F_IRC_NAME	[lindex $FILE_LINE 0]
				if { [string match -nocase $IRC_NAME $F_IRC_NAME] } {
					::ReplicaServ::SENT:MSG:TO:USER $sender "Le réseau $F_IRC_NAME existe déjà."
					close $FILE_PIPE
					return 0
				}
			}
			unset FILE_LINE
		}
		close $FILE_PIPE
		set FILE_PIPE		[open $DB_FILE a]
		puts $FILE_PIPE		"$IRC_NAME $IRC_NICKNAME $IRC_USERNAME $IRC_ADDRESS"
		close $FILE_PIPE
		::ReplicaServ::SENT:MSG:TO:USER $sender "IRC ajouté ([llength $servers] serveur(s))! Connexion à $IRC_NAME ..."
		::ReplicaServ::IRC:Connexion $IRC_NAME $IRC_ADDRESS $IRC_NICKNAME $IRC_USERNAME
		
	} elseif { $sub_cmd == "server" || $sub_cmd == "servers" } {
		set srv_cmd [string tolower [lindex $cmd_data 0]]
		set IRC_NAME [lindex $cmd_data 1]
		if { $srv_cmd eq "" || $IRC_NAME eq "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd server add <réseau> <host:<\[+\]port>>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd server del <réseau> <host:<\[+\]port>>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd server list <réseau>"
			return 0
		}
		set line [::ReplicaServ::DB:NETWORK:GET:LINE $IRC_NAME]
		if { $line eq "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Réseau $IRC_NAME introuvable."
			return 0
		}
		set cur_addrs [lindex $line 3]
		set servers [::ReplicaServ::DB:NETWORK:PARSE:ADDRS $cur_addrs]
		if { $srv_cmd eq "list" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c12>Serveurs de $IRC_NAME ([llength $servers]):"
			set i 0
			foreach s $servers {
				incr i
				set mark ""
				if { [info exists IRCC_DATA($IRC_NAME,SERVER_IDX)] && $IRCC_DATA($IRC_NAME,SERVER_IDX) == [expr {$i-1}] } {
					set mark " <c03>(actif)"
				}
				::ReplicaServ::SENT:MSG:TO:USER $sender "<c07>  $i. [lindex $s 0]:[lindex $s 1]$mark"
			}
			return 1
		}
		set new_addr [lindex $cmd_data 2]
		if { $new_addr eq "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Précisez host:+port"
			return 0
		}
		set parsed [::ReplicaServ::DB:NETWORK:PARSE:ADDR $new_addr]
		if { [llength $parsed] == 0 } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Adresse invalide: $new_addr"
			return 0
		}
		set new_host [string tolower [lindex $parsed 0]]
		set new_port [lindex $parsed 1]
		if { $srv_cmd eq "add" } {
			foreach s $servers {
				if { [string equal -nocase [lindex $s 0] $new_host] && [string equal [lindex $s 1] $new_port] } {
					::ReplicaServ::SENT:MSG:TO:USER $sender "Ce serveur est déjà dans la liste."
					return 0
				}
			}
			set pieces [list]
			foreach piece [split $cur_addrs ,] {
				set piece [string trim $piece]
				if { $piece ne "" } { lappend pieces $piece }
			}
			lappend pieces $new_addr
			set new_field [join $pieces ,]
			::ReplicaServ::DB:NETWORK:SET:ADDRS $IRC_NAME $new_field
			if { [info exists IRCC_DATA($IRC_NAME,PIPELINE)] } {
				::ReplicaServ::IRC:SERVERS:APPLY $IRC_NAME $new_field 0
			}
			::ReplicaServ::SENT:MSG:TO:USER $sender "Serveur ajouté à $IRC_NAME: $new_host:$new_port ([expr {[llength $servers]+1}] total)"
			return 1
		} elseif { $srv_cmd eq "del" || $srv_cmd eq "remove" } {
			if { [llength $servers] <= 1 } {
				::ReplicaServ::SENT:MSG:TO:USER $sender "Impossible de supprimer le dernier serveur."
				return 0
			}
			set pieces [list]
			set removed 0
			foreach piece [split $cur_addrs ,] {
				set piece [string trim $piece]
				if { $piece eq "" } { continue }
				set one [::ReplicaServ::DB:NETWORK:PARSE:ADDR $piece]
				if { [llength $one] && [string equal -nocase [lindex $one 0] $new_host] && [string equal [lindex $one 1] $new_port] } {
					set removed 1
					continue
				}
				lappend pieces $piece
			}
			if { !$removed } {
				::ReplicaServ::SENT:MSG:TO:USER $sender "Serveur non trouvé dans $IRC_NAME."
				return 0
			}
			set new_field [join $pieces ,]
			::ReplicaServ::DB:NETWORK:SET:ADDRS $IRC_NAME $new_field
			if { [info exists IRCC_DATA($IRC_NAME,PIPELINE)] } {
				::ReplicaServ::IRC:SERVERS:APPLY $IRC_NAME $new_field 1
			}
			::ReplicaServ::SENT:MSG:TO:USER $sender "Serveur retiré de $IRC_NAME: $new_host:$new_port"
			return 1
		} else {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Sous-commande server inconnue (add|del|list)."
			return 0
		}

	} elseif { $sub_cmd == "nick" } {
		# NETWORK NICK <réseau> <nouveau_nick>
		set IRC_NAME [lindex $cmd_data 0]
		set NEW_NICK [lindex $cmd_data 1]
		if { $IRC_NAME eq "" || $NEW_NICK eq "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd nick <réseau> <nickname>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> Exemple:<c04> /msg $config(service_nick) $cmd nick entrechat MayMiow"
			return 0
		}
		set NEW_NICK [::ReplicaServ::NICK:SANITIZE $NEW_NICK]
		if { $NEW_NICK eq "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Nickname invalide."
			return 0
		}
		set line [::ReplicaServ::DB:NETWORK:GET:LINE $IRC_NAME]
		if { $line eq "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Réseau $IRC_NAME introuvable."
			return 0
		}
		set user [lindex $line 2]
		set addrs [lindex $line 3]
		set new_line "$IRC_NAME $NEW_NICK $user $addrs"
		set fp [open $DB_FILE r]
		set out [list]
		while { ![eof $fp] } {
			set l [gets $fp]
			if { $l eq "" } { continue }
			if { [string equal -nocase [lindex $l 0] $IRC_NAME] } {
				lappend out $new_line
			} else {
				lappend out $l
			}
		}
		close $fp
		set fp [open $DB_FILE w+]
		foreach l $out { puts $fp $l }
		close $fp
		set old ""
		if { [info exists IRCC_DATA($IRC_NAME,NICK)] } { set old $IRCC_DATA($IRC_NAME,NICK) }
		set IRCC_DATA($IRC_NAME,NICK) $NEW_NICK
		if { [info exists IRCC_DATA($IRC_NAME,PIPELINE)] } {
			catch { $IRCC_DATA($IRC_NAME,PIPELINE) send "NICK $NEW_NICK" }
		}
		::ReplicaServ::SENT:MSG:TO:USER $sender "Nick $IRC_NAME : $old → $NEW_NICK (persisté dans network.db)"

	} elseif { $sub_cmd == "list" } {
		set FILE_PIPE	[open $DB_FILE "r"]
		set fc	-1
		set space 15
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>---------------------------------------------------------------------------------------------"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c12>[::ReplicaServ::TXT:ESPACE:DISPLAY RESEAU $space] <c04>|<c12> [::ReplicaServ::TXT:ESPACE:DISPLAY NICK $space] <c04>|<c12> [::ReplicaServ::TXT:ESPACE:DISPLAY IDENT $space] <c04>|<c12> ADRESSES"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>---------------------------------------------------------------------------------------------"
		while {![eof $FILE_PIPE]} {
			set FILE_LINE	[gets $FILE_PIPE]
			incr fc
			if { $FILE_LINE != "" } {
				set IRC_NAME	[::ReplicaServ::TXT:ESPACE:DISPLAY [lindex $FILE_LINE 0] $space];
				set USER_NICK	[::ReplicaServ::TXT:ESPACE:DISPLAY [lindex $FILE_LINE 1] $space];
				set USER_IDENT	[::ReplicaServ::TXT:ESPACE:DISPLAY [lindex $FILE_LINE 2] $space];
				set IRC_ADRESS	[::ReplicaServ::DB:NETWORK:ADDRS:MASK [lindex $FILE_LINE 3]];
				::ReplicaServ::SENT:MSG:TO:USER $sender "<c07>$IRC_NAME <c04>|<c07> $USER_NICK <c04>|<c07> $USER_IDENT <c04>|<c07> $IRC_ADRESS"
			}
			unset FILE_LINE
		}
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>---------------------------------------------------------------------------------------------"
		close $FILE_PIPE
	} elseif { $sub_cmd == "remove" } {
		if { [lindex $cmd_data 0] == "" } {
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide de supression de réseau<c04> :."
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd $sub_cmd <réseau>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> Exemple:<c04> /msg $config(service_nick) $cmd $sub_cmd epiknet"
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
			return 0;
		}
		set IRC_NAME		[lindex $cmd_data 0]
		set USER_NICK		[lindex $cmd_data 1]; # nick irc
		set USER_IDENT		[lindex $cmd_data 2]; # ident

		set FILE_PIPE		[open [::ReplicaServ::Get:ScriptDir "db"]/link.db r]
		while { ![eof $FILE_PIPE] } {
			gets $FILE_PIPE FILE_DATA;
			if { [string equal -nocase [lindex $FILE_DATA 0] $IRC_NAME] } {
				::ReplicaServ::SENT:MSG:TO:USER $sender "Impossible de suprimer un réseau si un LINK existe encore... /msg $config(service_nick) link"
				close $FILE_PIPE
				return 0
			}
		}
		close $FILE_PIPE
		
		set FILE_PIPE		[open $DB_FILE r];
		set STATE			0;
		set FILE_NEW_DATA	[list];
		while { ![eof $FILE_PIPE] } {
			gets $FILE_PIPE FILE_DATA;
			if { [string equal -nocase [lindex $FILE_DATA 0] $IRC_NAME] } {
				set STATE		1;
			} elseif { $FILE_DATA != "" } {
				lappend FILE_NEW_DATA $FILE_DATA;
			}
		}
		close $FILE_PIPE
		set FILE_PIPE		[open $DB_FILE w+];
		foreach LINE_NEW $FILE_NEW_DATA { puts $FILE_PIPE $LINE_NEW }
		close $FILE_PIPE
		if { $STATE } {
			set IRC_PIPELINE	"$IRCC_DATA($IRC_NAME,PIPELINE)"
			::ReplicaServ::CMD:LOG "Suppression du réseau $IRC_NAME réussi.." $sender
			$IRC_PIPELINE destroy
			::ReplicaServ::SENT:MSG:TO:USER $sender "Suppression du réseau $IRC_NAME réussi.."
			return 1
		} else {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Réseau $IRC_NAME non trouver.."
		}
		return 0

	} else {
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide réseau<c04> :."
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Network Add" 15]<c12>- <c06> Ajoute un réseau (adresses séparées par ,)"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Network Remove" 15]<c12>- <c06> Suprime un réseau"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Network List" 15]<c12>- <c06> Liste des réseaux"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Network Server" 15]<c12>- <c06> add|del|list serveurs d'un réseau"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Network Nick" 15]<c12>- <c06> Change le nick distant (persisté)"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c04>"
	}
	::ReplicaServ::CMD:LOG "$cmd $sub_cmd $cmd_data" $sender
}
proc ::ReplicaServ::IRC:CMD:PRIV:SET { sender destination cmd data } {
	variable config
	variable RUNTIME
	set sub [string tolower [lindex $data 0]]
	set val [string tolower [lindex $data 1]]
	if { $sub eq "" || $sub eq "status" || $sub eq "list" } {
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c12>Sync runtime / conf :"
		foreach k {replica_sync_topics replica_sync_users replica_sync_messages replica_sync_modes} {
			set src conf
			if { [info exists RUNTIME($k)] } { set src runtime }
			set onoff off
			if { [::ReplicaServ::CFG:ON $k] } { set onoff on }
			::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $k = $onoff <c04>($src)"
		}
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> sjoin_interval_ms=$config(replica_sjoin_interval_ms) channel_stagger_ms=$config(replica_channel_stagger_ms)"
		::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> $cmd topics|users|messages|modes on|off"
		return 1
	}
	set key ""
	switch -exact -- $sub {
		topics - topic { set key replica_sync_topics }
		users - user { set key replica_sync_users }
		messages - message - msg { set key replica_sync_messages }
		modes - mode { set key replica_sync_modes }
		default {
			::ReplicaServ::SENT:MSG:TO:USER $sender "Clé inconnue. Utilisez: topics users messages modes"
			return 0
		}
	}
	if { $val eq "" } {
		set onoff off
		if { [::ReplicaServ::CFG:ON $key] } { set onoff on }
		::ReplicaServ::SENT:MSG:TO:USER $sender "$key = $onoff"
		return 1
	}
	if { ![::ReplicaServ::CFG:SET:RUNTIME $key $val] } {
		::ReplicaServ::SENT:MSG:TO:USER $sender "Valeur invalide (on|off)."
		return 0
	}
	set onoff off
	if { [::ReplicaServ::CFG:ON $key] } { set onoff on }
	::ReplicaServ::SENT:MSG:TO:USER $sender "$key → $onoff (runtime, jusqu'au restart ; conf fichier inchangée)"
	::ReplicaServ::CMD:LOG "$cmd $sub $val" $sender
	return 1
}
proc ::ReplicaServ::IRC:CMD:PRIV:HELP { sender destination cmd data } {
	::ReplicaServ::IRC:CMD:PUB:HELP $sender $destination $cmd $data
}
proc ::ReplicaServ::IRC:CMD:PUB:HELP { sender destination cmd data } {
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide publique<c04> :."
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "!Help" 15]<c12>- <c06> Affiche cette aide"
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c04> .: <c12>Aide privé<c04> :."
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Network" 15]<c12>- <c06> Gestion des réseaux IRC (+ nick, servers)"
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Link" 15]<c12>- <c06> Liens (+ flags notopic, topic on|off)"
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Set" 15]<c12>- <c06> topics|users|messages|modes on|off"
	::ReplicaServ::SENT:MSG:TO:USER $sender "<c07> [::ReplicaServ::TXT:ESPACE:DISPLAY "Help <Commande>" 15]<c12>- <c06> Affiche l'aide de <Commande>"
	::ReplicaServ::CMD:LOG $cmd $sender
}
##########################################
# --> Procedures des Commandes Privés <--#
##########################################

ReplicaServ::INIT
