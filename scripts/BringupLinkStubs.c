// Link-only definitions for the B3 bring-up kernel.
//
// The H103 owner-Data diagnostics and the H117 panic flush are compiled in
// even when the owner Data mount is disabled.  They reference these globals,
// so every PMGR archive variant must provide inert definitions.  The real
// PMGR runtime lives in DumplingPlatformPower.cpp; this file deliberately
// contains no ApplePMGR code and no hardware access.
#include <sys/types.h>
#include <stdint.h>

__attribute__((weak)) volatile int native_owner_data_status = -1;
__attribute__((weak)) volatile int native_owner_data_readonly = -1;
__attribute__((weak)) volatile dev_t native_owner_data_device = -1;

__attribute__((weak)) void native_panic_flush(void)
{
}

/*
 * Optional B5 GPU / legacy-display probes referenced by NativeUfsProbe's
 * heartbeat and diagnostic timer.  The first UFS root test does not enable
 * those probes; these weak no-ops keep the archive linkable without pulling
 * in the Adreno or legacy framebuffer archives.
 */
__attribute__((weak)) int native_iogpu_accel_probe(void)
{
	return 0;
}

__attribute__((weak)) int native_legacy_test_pattern(void)
{
	return 0;
}

__attribute__((weak)) void native_legacy_heartbeat_cell(void)
{
}

__attribute__((weak)) int sheng_gpucc_next(unsigned *index, uint32_t *value)
{
	(void)index;
	(void)value;
	return 0;
}

__attribute__((weak)) int sheng_gpu_power_step(void)
{
	return 0;
}

__attribute__((weak)) volatile uint32_t native_legacy_client_calls = 0;
__attribute__((weak)) volatile uint32_t native_legacy_transfer_calls = 0;
__attribute__((weak)) volatile uint32_t native_legacy_frame_count = 0;
__attribute__((weak)) volatile uint32_t native_legacy_frame_kind[32] = { 0 };
__attribute__((weak)) volatile uint64_t native_legacy_frame_stats[32][5] = { { 0 } };
