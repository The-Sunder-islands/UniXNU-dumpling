// Bring-up stub for the native UFS root boot flag.
//
// The firmware leaves the MSM8998 UFS controller powered and clocked for the
// warm-link path. The full NativeUfs driver performs its own controller
// bring-up, so this stub only satisfies the bsd_init integration point; it is
// not the final PMGR implementation.
//
// B3 also links the H103 owner-Data diagnostics and the H117 panic flush even
// when XNU_OWNER_DATA_MOUNT=0.  Provide inert definitions so the first-boot
// kernel links without the B5 NativeUfs/Data runtime.
#include <sys/types.h>

volatile int native_owner_data_status = -1;
volatile int native_owner_data_readonly = -1;
volatile dev_t native_owner_data_device = -1;

void native_panic_flush(void)
{
}

void sheng_pmgr_run(void)
{
}
