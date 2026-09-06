#############################################################################
#
#  Auteur  :
#    -> ZarTek (ZarTek.Creole@GMail.Com)
#
#  Website  :
#    -> github.com/ZarTek-Creole/TCL-ZCT
#
#  Support  :
#    -> github.com/ZarTek-Creole/TCL-ZCT/issues
#
#  Docs  :
#    -> github.com/ZarTek-Creole/TCL-ZCT/wiki
#
#   DONATE   :
#       -> https://github.com/ZarTek-Creole/DONATE
#
#  LICENSE :
#    -> Creative Commons Attribution 4.0 International
#    -> github.com/ZarTek-Creole/TCL-ZCT/blob/main/LICENSE.txt
#
#
#############################################################################
namespace eval ::ZCT {
  namespace export *

  variable packageData
  variable isEggdrop
  variable printProc
  variable exitOnError          1

  array set packageData {
    "version"                   "0.1.0"
    "name"                      "package ZCT"
    "author"                    "ZarTeK-Creole"
    "url"                       "https://github.com/ZarTek-Creole"
  }

  try {
    if { [info commands ::putlog] == "" } {
      set isEggdrop             0
      set printProc             "puts"
    } else {
      set isEggdrop             1
      set printProc             "putlog"
    }
  } on error {errMsg} {
    puts "An error occurred: $errMsg"
    return -code error $errMsg
  }
}


namespace eval ::ZCT::pkg {
}
# Chargeur de package en cas d'absence de celui-ci
# il indique comment le télécharger
#
# @param PKG_NAME Le nom exact du packages (obligatoire)
# @param PKG_VERSION La version minimal que le packages doit charger
# @param SCRIPT_NAME Le nom de votre script dans le quel vous voulez charger le package
# @param MISSING_MODE Comment afficher les erreur ? putlog, puts, die(par default) ?
# @return Le status charger ou erreur
proc ::ZCT::pkg::load { PKG_NAME {PKG_VERSION ""} {SCRIPT_NAME ""} {MISSING_MODE "die"} } {
  if { ${SCRIPT_NAME} == "" }  {
    set ERR_PREFIX              "\[Erreur\] Le script nécessite du package '${PKG_NAME}'"
    set OK_PREFIX               "\[OK\] Le script à chargé le package '${PKG_NAME}'"
  } else {
    set ERR_PREFIX              "\[Erreur\] Le script '${SCRIPT_NAME}' nécessite du package '${PKG_NAME}'"
    set OK_PREFIX               "\[OK\] Le script '${SCRIPT_NAME}' à chargé le package '${PKG_NAME}'"
  }
  if { ${PKG_VERSION} == "" } {
    if { [catch { set PKG_VERSION [package require ${PKG_NAME}]}] } {
      ${MISSING_MODE} "${ERR_PREFIX} pour fonctionner. [::ZCT::pkg::How_Download ${PKG_NAME}]"
    }
  } else {
    if { [catch { set PKG_VERSION [package require ${PKG_NAME} ${PKG_VERSION}]}] } {
      ${MISSING_MODE} "${ERR_PREFIX} version ${PKG_VERSION} ou supérieur pour fonctionner. [::ZCT::pkg::How_Download ${PKG_NAME}]"
    }
  }
  ${::ZCT::printProc} "${OK_PREFIX} avec la version ${PKG_VERSION} avec succès"
}


# La fonction est refactorisée pour améliorer la lisibilité, et utilise des constantes pour les valeurs qui ne changent pas
proc ::ZCT::pkg::howDownload { pkgName } {
  variable tclLibURL            "https://www.tcl.tk/software/tcllib/"
  variable ircServicesURL       "https://github.com/ZarTek-Creole/TCL-PKG-IRCServices"
  variable irccURL              "https://github.com/ZarTek-Creole/TCL-PKG-IRCC"
  variable zctURL               "https://github.com/ZarTek-Creole/TCL-ZCT"
  variable tclURL               "https://www.tcl.tk/software/tcltk/"
  variable noInfoMsg            "Aucune information sur %s, vous devez chercher sur internet"
  variable tcllibMsg            "Il fait partie de la gamme de tcllib.\n Téléchargement sur %s"
  variable downloadMsg          "Télécharger la dernière version sur %s"
  switch -nocase $pkgName {
    "Logger"                    { return [format $tcllibMsg $tclLibURL] }
    "IRCServices"               { return [format $downloadMsg $ircServicesURL] }
    "IRCC"                      { return [format $downloadMsg $irccURL] }
    "ZCT"                       { return [format $downloadMsg $zctURL] }
    "Tcl"                       { return [format $downloadMsg $tclURL] }
    default                     { return [format $noInfoMsg $pkgName] }
  }
}


# Verifications de presence de variables.
# Utile pour verifié que tout les variables ont bien été donné dans une fichier de configuration
# dans
# set VARS_LIST        [list "list1" "list2"];  #definitié les nom des arrayx
#  Le code verifie a partir de la les listes defini graces a
# set VARS_list1      [list "var1" "var2"]
# set VARS_list2      [list "var3" "var4"]
# Il verifiera la presence de ${list1(var1)}, ${list1(var2)}, ${list2(var3)} et ${list2(var4)}
#
# @param NAMESPACE Le nom de l'espace nom dans le quel rechercher
# @return NULL
proc ::ZCT::Is:ArrayList:Exists { NAMESPACE } {
  set ::TMP_NS_ArrayList ${NAMESPACE}
  namespace inscope ${NAMESPACE} {
    variable VARS_LIST
    if { ![info exists VARS_LIST] } {
      return -code error \
        [format "%s > La liste des ArrayLists a verifier '%s' est inexistant." ${::TMP_NS_ArrayList} "VARS_LIST"]
    }
    foreach LIST_NAME ${VARS_LIST} {
      ${::ZCT::printProc} [format "%s > Verification de la présence des variables : \$%s\(..)" ${::TMP_NS_ArrayList} ${LIST_NAME}]
      variable VARS_${LIST_NAME}
      if { ![info exists VARS_${LIST_NAME}] } {
        return -code error \
          [format "%s > Liste de variables '%s' est inexistant." ${::TMP_NS_ArrayList} "VARS_${LIST_NAME}"]
      }
      variable ${LIST_NAME}
      if { ![array exists ${LIST_NAME}] } {
        return -code error \
          [format "%s > '%s' n'est pas une liste Array." ${::TMP_NS_ArrayList} "${LIST_NAME}"]
      }
      foreach VAR_NAME [subst \$VARS_${LIST_NAME}] {
        if { ![info exists ${LIST_NAME}(${VAR_NAME})] } {
          return -code error \
            [format "%s > L'Array '%s' est inexistant." ${::TMP_NS_ArrayList} "${LIST_NAME}(${VAR_NAME})"]
        }
      }
    }
    unset  ::TMP_NS_ArrayList
  }

}
# Creer des couleurs pour le partyline
# par exemple pour du TEXT en rouge en partyline :
# putlog "[pcolor_red]mon text rouge[pcolors_end] et ici aucune couleur"
foreach {color_name value} { red 1 yellow 3 cyan 5 magenta 6 blue 4 green 2 } {
  proc ::ZCT::pcolor_${color_name} {} "return \033\\\[01\\;3${value}m"
}
proc ::ZCT::pcolors_end { } {
  return \033\[\;0m
}
# procedure qui retourne où il est appellé
# @param level le niveau de profondeur

proc ::ZCT::getCaller {level} {
  try {
    if {$level > 0} {
      return -code ok [lindex [info level $level] 0]
    } else {
      set scriptName [info script]
      if {[string length $scriptName] > 0} {
        return -code ok $scriptName
      } else {
        return -code ok [info nameofexecutable]
      }
    }
  } on error {errorMessage} {
    ${::ZCT::printProc} "Error occurred in getCaller: $errorMessage"
    return -code error
  }
}

proc ::ZCT::getError {args} {
  global errorInfo tcl_patchLevel tcl_platform
  variable exitOnError
  ${::ZCT::printProc} "--\[[::ZCT::pcolor_red]Error Info[::ZCT::pcolors_end]]------------------------------------------"
  ${::ZCT::printProc} "Tcl: $tcl_patchLevel"
  ${::ZCT::printProc} "Box: $tcl_platform(os) $tcl_platform(osVersion)"
  ${::ZCT::printProc} "Called by: [::ZCT::calledBy]"
  ${::ZCT::printProc} "--\[[::ZCT::pcolor_red]Error Message[::ZCT::pcolors_end]]--"
  foreach line [split $errorInfo "\n"] {${::ZCT::printProc} $line}
  ${::ZCT::printProc} "--------------------------------------------------------"
  if {$exitOnError} {
    exit 1  ;# exit with error
  }
}
# Function to fetch the calling entity's name.
# @return the name of the calling entity

proc ::ZCT::calledBy {} {
  set callLevel [expr {[info level] - 2}]
  return -code ok [::ZCT::getCaller $callLevel]
}

# Putlog amelioreé, avec des niveau (couleurs differentes) et type de text
if { ${::ZCT::isEggdrop} } {
  proc ::ZCT::putlog { text {level_name ""} {text_name ""} } {
    variable ::ZCT::SCRIPT
    set UP_LEVEL_NAME           [::ZCT::calledBy]
    if { ${text_name} == "" } {
      if { ${level_name} != "" } {
        set text_name           " - ${level_name}"
      } else {
        set text_name           ""
      }
    } else {
      set text_name             " - ${text_name}"
    }
    switch -nocase ${level_name} {
      "error"                   { ${::ZCT::printProc} "[pcolor_red]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
      "warning"                 { ${::ZCT::printProc} "[pcolor_yellow]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
      "notice"                  { ${::ZCT::printProc} "[pcolor_cyan]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
      "debug"                   { ${::ZCT::printProc} "[pcolor_magenta]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
      "info"                    { ${::ZCT::printProc} "[pcolor_blue]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
      "success"                 { ${::ZCT::printProc} "[pcolor_green]\[${UP_LEVEL_NAME}${text_name}\][pcolors_end] [pcolor_blue]${text}[pcolors_end]" }
      default                   { ${::ZCT::printProc} "\[${UP_LEVEL_NAME}${text_name}\] [pcolor_blue]${text}[pcolors_end]" }
    }
  }
  if { [info commands ::putlog.old] == "" } {
    rename ::putlog ::putlog.old
    # Évite la récursion infinite putlog → printProc → putlog
    set ::ZCT::printProc "::putlog.old"
    interp alias {} putlog {} ::ZCT::putlog
  }
}
# Procedure interne qui permet de creer les procs et les subprocs automatiquement
# https://forum.eggdrop.fr/Une-proc-qui-gere-lexploration-des-sous-commandes-par-les-namespaces-t-1951.html
#
# @param namespace Le nom d'espacement a suivre
# @return NULL - Cree des (SUB-)PROCS
proc ::ZCT::create_sub_procs { namespace } {
  # Boucle sur les namespaces enfants de $namespace (::example) retourne -> ::example::text; ::example::text2
  foreach child_name [namespace children ${namespace}] {
    # Création de procédure portant le nom des namespaces enfants ::example::text, ::example::text2
    proc ${child_name} { {subcommand ""} args } {
      # tout ce qui fais partie ici, sera exécuté lors de l'exécution de la proc créer
      # les variables, commandes
      # le  proc_path contient chemin de la proc (lors de sont exécution et non maintenant donc)
      set proc_path            [lindex [info level 0] 0]
      # Si la proc est appeler sans subcommand, nous signalons qu'elle nécessite une
      if { ${subcommand} == "" } {
        return  -code error     \
          "wrong # args: should be \"${proc_path} subcommand ?arg ...?\""
      }
      # Si la subcommand n'existe pas dans les procs enfants, ont prévois de retourner la liste des procs existante dans le namespace courant (celle de la proc appelé )
      if { [info commands ${proc_path}::${subcommand}] == "" } {
        set subcommands_list  [join [string map "${proc_path}:: \"\"" [info procs ${proc_path}::*]] ", "]
        return  -code error \
          "wrong ${proc_path} unknown or ambiguous subcommand \"${subcommand}\": must be ${subcommands_list}"
      }
      # si la subcommand existe, on l'execute avec les valeurs fournis
      ${proc_path}::${subcommand} {*}${args}
    }
    # ici nous sommes sorties de la création de la proc, et de retour dans la boucle enfant, nous allons exporté les proc
    namespace export *
    # Nous allons répéter ces opérations dans le niveau inferieur/enfants (dans ::example::text et ::example::text2)
    create_sub_procs ${child_name}
  }
  # fin de la boucle
}
namespace eval ::ZCT::TXT {
  namespace export *
}
namespace eval ::ZCT::Txt::Visuals {
  namespace export *
}
# Supprimer les accents dans une chaîne de caractères
# Utile par exemple pour effectuer une recherche de TEXT en ne tenant pas compte des caractères accentués.
# source : https://boulets.eggdrop.fr/tcl/routines/tcl-toolbox-0011.html
#
# @param TEXT Le TEXT dont les accents doivent être enlever
# @return Le TEXT sans accents, ni cédiles
# Remove accents from a string
proc ::ZCT::TXT::removeAccents {text} {
  variable AccentsMap           {
    "à" "a" "â" "a" "ä" "a" "ã" "a" "å" "a" "á" "a" "à" "a" "å" "a"
    "é" "e" "è" "e" "ê" "e" "ë" "e"
    "î" "i" "ï" "i" "î" "i" "í" "i" "ì" "i"
    "ô" "o" "ö" "o" "õ" "o" "ø" "o" "ò" "o" "ó" "o"
    "ù" "u" "û" "u" "ü" "u" "ú" "u"
    "ý" "y" "ÿ" "y"
    "ç" "c" "ð" "d" "ñ" "n" "š" "s" "ž" "z"
  }
  set sanitizedText             $text
  try {
    set sanitizedText           [::tcl::string::map -nocase $AccentsMap $sanitizedText]
    return $sanitizedText
  } on error {errorMessage} {
    ${::ZCT::printProc} "Error while removing accents: $errorMessage"
    return -code error $errorMessage
  }
}

# Utility function to get a padded number
proc ::ZCT::TXT::getNumberPadded {num} {
  set n [string trimleft $num 0]
  if { $n eq "" } { return 0 }
  return $n
}

# Supprimer les accents dans une chaîne de caractères
# Utile par exemple pour effectuer une recherche de TEXT en ne tenant pas compte des caractères accentués.
# source : https://boulets.eggdrop.fr/tcl/routines/tcl-toolbox-0011.html
#
# @param TEXT Le TEXT contenant des variables de subtitutions
# @param Channel Le salon pour remplacer %chan% (facultatif)
# @return Le TEXT avec les doonées de subtitutions replacer

# Main function to replace substitutions in a text
proc ::ZCT::TXT::REPLACE_SUBSTITUTE { TEXT {Channel ""} } {
  try {
    set timeNow                 [clock seconds]
    set botNick                 ""
    if { [info exists ::ClaraServ::config(service_nick)] } {
      set botNick               $::ClaraServ::config(service_nick)
    }
    set hours                   [clock format $timeNow -format %H]
    set minutes                 [clock format $timeNow -format %M]
    set seconds                 [clock format $timeNow -format %S]
    set day                     [string map -nocase {Mon lundi Tue mardi Wed mercredi Thu jeudi Fri vendredi Sat samedi Sun dimanche} [clock format $timeNow -format %a]]
    set month                   [string map {Jan janvier Feb février Mar mars Apr avril May mai Jun juin Jul juillet Aou août Sep septembre Oct octobre Nov novembre Dec décembre} [clock format $timeNow -format %b]]
    set year                    [clock format $timeNow -format %Y]
    set substitutions [list \
      %chan% $Channel \
      %botnick% $botNick \
      %hour% $hours \
      %hour_short% [::ZCT::TXT::getNumberPadded $hours] \
      %minutes% $minutes \
      %minutes_short% [::ZCT::TXT::getNumberPadded $minutes] \
      %seconds% $seconds \
      %seconds_short% [::ZCT::TXT::getNumberPadded $seconds] \
      %day_num% [clock format $timeNow -format %d] \
      %day% $day \
      %month_num% [clock format $timeNow -format %m] \
      %month% $month \
      %year% $year \
    ]
    return -code ok [string map $substitutions $TEXT]
  } on error {msg options} {
    ${::ZCT::printProc} "Exception: $msg"
    return -code error $msg
  }
}
# Center a TEXT with spaces on a given length
#
# @param TEXT The TEXT that needs to be centered
# @param LENGTH The desired length with spacings
# @return The centered TEXT with the number of spaces to have a length equal to LENGTH
proc ::ZCT::Txt::Visuals::centerWithSpaces { text length } {
  try {
    set trimmedText             [string trim ${text}]
    set textLength              [string length ${trimmedText}]
    if { ${textLength} >= ${length} } {
      return [string range ${trimmedText} 0 [expr {${length} - 1}]]
    }
    set spaceLength             [expr {(${length} - ${textLength}) / 2.0}]
    set spaceLengthComponents   [split ${spaceLength} .]

    set spaceLengthInteger      [lindex ${spaceLengthComponents} 0]
    set spaceLengthDecimal      [lindex ${spaceLengthComponents} 1]

    set spacePrefix             [string repeat " " ${spaceLengthInteger}]
    set spaceSuffix             [string repeat " " ${spaceLengthInteger}]

    if { ${spaceLengthDecimal} == 0 || ${spaceLengthDecimal} eq "" } {
      return "${spacePrefix}${trimmedText}${spaceSuffix}"
    } else {
      set spaceSuffix [string repeat " " [expr {${spaceLengthInteger} + 1}]]
      return "${spacePrefix}${trimmedText}${spaceSuffix}"
    }
  } on error {errMsg} {
    ${::ZCT::printProc} "Error occurred: $errMsg"
    return -code error $errMsg
  }
}

# Enleve les style visuals
#
# @param TEXT Le TEXT avec des codes style
# @return Le TEXT sans les codes styles
proc ::ZCT::Txt::Visuals::removeVisualStyles { text } {
  set stylePatterns             [list
  {<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>}
  {<b>|</b>}
  {<u>|</u>}
  {<i>|</i>}
  {<s>|</s>}
  ]
  try {
    foreach pattern $stylePatterns {
      set text                  [::ZCT::Txt::Visuals::removeStyle $text $pattern]
    }
    return -code ok $text
  } on error {errorMessage options} {
    ${::ZCT::printProc} "Error in removeVisualStyles: $errorMessage"
    return -code error $errorMessage
  }
}

# Utilise une autre procédure pour enlever un style spécifique
proc ::ZCT::Txt::Visuals::removeStyle { text pattern } {
  try {
    return -code ok [regsub -all -nocase $pattern $text {}]
  } on error {errorMessage options} {
    ${::ZCT::printProc} "Error in removeStyle: $errorMessage"
    return -code error $errorMessage
  }
}

##############################################################################
### Substitution des symboles couleur/gras/soulignement/...
###############################################################################
# Modification de la fonction de MenzAgitat
# <cXX> : Ajouter un Couleur avec le code XX : <c01>; <c02,01>
# </c>  : Enlever la Couleur (refermer la deniere declaration <cXX>) : </c>
# <b>   : Ajouter le style Bold/gras
# </b>  : Enlever le style Bold/gras
# <u>   : Ajouter le style Underline/souligner
# </u>  : Enlever le style Underline/souligner
# <i>   : Ajouter le style Italic/Italique
# <s>   : Enlever les styles precedent
##
# Noir        /  Black       = 00
# Blanc       /  White       = 01
# Bleu foncé  /  Dark Blue   = 02
# Vert        /  Green       = 03
# Rouge       /  Red         = 04
# Marron      /  Brown       = 05
# Violet      /  Purple      = 06
# Orange      /  Orange      = 07
# Jaune       /  Yellow      = 08
# Vert clair  /  Light Green = 09
# Cyan foncé  /  Dark Cyan   = 10
# Cyan clair  /  Light Cyan  = 11
# Bleu clair  /  Light Blue  = 12
# Rose        /  Pink        = 13
# Gris foncé  /  Dark Grey   = 14
# Gris clair  /  Light Grey  = 15
##
# @param textToProcess Text with style codes to replace with actual style codes (colors, bold..)
# @return Processed text with TCL style codes
proc ::ZCT::Txt::Visuals::apply { textToProcess } {
  variable tagPattern {
    "c"                         "<c([0-9]{0,2}(,[0-9]{0,2})?)?>|</c([0-9]{0,2}(,[0-9]{0,2})?)?>"
    "b"                         "<b>|</b>"
    "u"                         "<u>|</u>"
    "i"                         "<i>|</i>"
    "s"                         "<s>"
  }

  variable tagReplacement {
    "c"                         "\003\\1"
    "b"                         "\002"
    "u"                         "\037"
    "i"                         "\026"
    "s"                         "\017"
  }

  foreach {tag pat} [array get tagPattern] {
    set rep                     [dict get $tagReplacement $tag]
    regsub -all -nocase $pat $textToProcess $rep textToProcess
  }

  return $textToProcess
}


::ZCT::create_sub_procs ::ZCT



# ---------------------------------------------------------------------------
# Compatibilité ClaraServ / anciennes API (snake_case + TXT::visuals)
# ---------------------------------------------------------------------------
namespace eval ::ZCT::TXT::visuals {
  namespace export *
}

proc ::ZCT::TXT::remove_accents { TEXT } {
  return [::ZCT::TXT::removeAccents $TEXT]
}

proc ::ZCT::TXT::visuals::espace { TEXT LENGTH } {
  return [::ZCT::Txt::Visuals::centerWithSpaces $TEXT $LENGTH]
}

proc ::ZCT::TXT::visuals::apply { TEXT } {
  return [::ZCT::Txt::Visuals::apply $TEXT]
}

proc ::ZCT::TXT::visuals::remove { TEXT } {
  return [::ZCT::Txt::Visuals::removeVisualStyles $TEXT]
}

# Alias rétro-compatibilité (casse / anciens noms)
interp alias {} ::ZCT::calledby {} ::ZCT::calledBy
interp alias {} ::ZCT::pkg::How_Download {} ::ZCT::pkg::howDownload

package provide ZCT ${::ZCT::packageData(version)}
${::ZCT::printProc} "Le paquet ZCT version ${::ZCT::packageData(version)} par ${::ZCT::packageData(author)} a été chargé. Vous pouvez le trouver à l'adresse suivante : ${::ZCT::packageData(url)}."