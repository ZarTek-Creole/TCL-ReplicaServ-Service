<span class="badge-opencollective"><a href="https://github.com/ZarTek-Creole/DONATE" title="Donate to this project"><img src="https://img.shields.io/badge/open%20collective-donate-yellow.svg" alt="Open Collective donate button" /></a></span>
[![CC BY 4.0][cc-by-shield]][cc-by]

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg

Version eggdrop du script "Les poupées linkeuses". Permet de répliqué sur votre IRCD les users/messages d'un ircd/salon distance


lors de la connexion du services effectuer au irc :

	chargement de network.db pour creer les connexion aux IRC ::ReplicaServ::IRC:Connexion

	Format network.db (plusieurs serveurs séparés par des virgules, failover circulaire) :
		libera AmiZoneRS1 services irc.libera.chat:+6697,irc.eu.libera.chat:+6697
		entrechat MayMiow services irc.entrechat.net:+6677
		chaat  AmiZoneRS2 services irc.chaat.fr:+6697

	Commandes :
		Network Server add|del|list <réseau> …
		Network Nick <réseau> <nick>     — nick distant configurable (persisté)
		Link Add <réseau> #local #distant [flags…]
		  flags: notopic topic nomodes nousers nomsg
		Link Topic on|off <réseau> #local #distant
		Set topics|users|messages|modes on|off   — toggles runtime
		Set status

	Format link.db :
		libera #linux #linux
		entrechat #!accueil! #!accueil! notopic
	
		lors du signal 001 (RPL_WELCOME) utilisateur reconnu par IRC : 
		
		Verification link.db pour joindre les salons
