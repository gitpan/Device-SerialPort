#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
/* include our configure-created config file */
#include "config.h"

/* First step: include all the files we think we may need to
   get all the silly serial and modem bits defined.  This should
   be exactly the same as what's in the autoconf scripts. */
#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif
#ifdef HAVE_SYS_IOCTL_H
# include <sys/ioctl.h>
#endif
#ifdef HAVE_TERMIOS_H
# include <termios.h>
#endif
#ifdef HAVE_SYS_TERMIOX_H
# include <sys/termiox.h>
#endif
#ifdef HAVE_SYS_TERMIOS_H
# include <sys/termios.h>
#endif
#ifdef HAVE_SYS_TTYCOM_H
# include <sys/ttycom.h>
#endif
#ifdef HAVE_SYS_MODEM_H
# include <sys/modem.h>
#endif

#define ADD_TO_HASH(v)	{ 				\
	key = #v;					\
	value = newSViv(v);				\
	hv_store(hv, key, strlen(key), value, 0);	\
}

// Hide this junk in the "Bits" namespace
MODULE = Device::SerialPort		PACKAGE = Device::SerialPort::Bits

SV *
get_hash()
PREINIT:
	HV *	hv;
	char *	key;
	SV *	value;
PROTOTYPE:
CODE:
	// initialize the hash
	hv = newHV();
#ifdef _SC_CLK_TCK
	ADD_TO_HASH(_SC_CLK_TCK)
#endif
#ifdef TIOCMBIS
	ADD_TO_HASH(TIOCMBIS)
#endif
#ifdef TIOCMBIC
	ADD_TO_HASH(TIOCMBIC)
#endif
#ifdef TIOCMGET
	ADD_TO_HASH(TIOCMGET)
#endif
#ifdef CRTSCTS
	ADD_TO_HASH(CRTSCTS)
#endif
#ifdef OCRNL
	ADD_TO_HASH(OCRNL)
#endif
#ifdef ONLCR
	ADD_TO_HASH(ONLCR)
#endif
#ifdef ECHOKE
	ADD_TO_HASH(ECHOKE)
#endif
#ifdef ECHOCTL
	ADD_TO_HASH(ECHOCTL)
#endif
#ifdef TIOCM_CAR
	ADD_TO_HASH(TIOCM_CAR)
#endif
#ifdef TIOCM_CD
	ADD_TO_HASH(TIOCM_CD)
#endif
#ifdef TIOCM_RNG
	ADD_TO_HASH(TIOCM_RNG)
#endif
#ifdef TIOCM_RI
	ADD_TO_HASH(TIOCM_RI)
#endif
#ifdef TIOCM_CTS
	ADD_TO_HASH(TIOCM_CTS)
#endif
#ifdef TIOCM_DSR
	ADD_TO_HASH(TIOCM_DSR)
#endif
#ifdef TIOCINQ
	ADD_TO_HASH(TIOCINQ)
#endif
#ifdef TIOCOUTQ
	ADD_TO_HASH(TIOCOUTQ)
#endif
#ifdef TIOCSER_TEMT
	ADD_TO_HASH(TIOCSER_TEMT)
#endif
#ifdef TIOCM_LE
	ADD_TO_HASH(TIOCM_LE)
#endif
#ifdef TIOCSERGETLSR
	ADD_TO_HASH(TIOCSERGETLSR)
#endif
#ifdef TIOCSDTR
	ADD_TO_HASH(TIOCSDTR)
#endif
#ifdef TIOCCDTR
	ADD_TO_HASH(TIOCCDTR)
#endif
#ifdef TIOCM_RTS
	ADD_TO_HASH(TIOCM_RTS)
#endif
#ifdef TIOCM_DTR
	ADD_TO_HASH(TIOCM_DTR)
#endif
#ifdef CTSXON
	ADD_TO_HASH(CTSXON)
#endif
#ifdef RTSXOFF
	ADD_TO_HASH(RTSXOFF)
#endif
#ifdef TCGETX
	ADD_TO_HASH(TCGETX)
#endif
#ifdef TCSETX
	ADD_TO_HASH(TCSETX)
#endif
	RETVAL = newRV_noinc((SV*)hv);
OUTPUT:
	RETVAL
