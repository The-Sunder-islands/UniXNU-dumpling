// Link-only definitions for the B3 bring-up kernel.
//
// The H103 owner-Data diagnostics and the H117 panic flush are compiled in
// even when the owner Data mount is disabled.  They reference these globals,
// so every PMGR archive variant must provide inert definitions.  The real
// PMGR runtime lives in DumplingPlatformPower.cpp; this file deliberately
// contains no ApplePMGR code and no hardware access.
#include <sys/types.h>

volatile int native_owner_data_status = -1;
volatile int native_owner_data_readonly = -1;
volatile dev_t native_owner_data_device = -1;

void native_panic_flush(void)
{
}
