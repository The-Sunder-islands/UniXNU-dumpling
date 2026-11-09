// Bring-up stub for the native UFS root boot flag.
//
// The firmware leaves the MSM8998 UFS controller powered and clocked for the
// warm-link path. The full NativeUfs driver performs its own controller
// bring-up, so this stub only satisfies the bsd_init integration point; it is
// not the final PMGR implementation.
//
// The real PMGR archive (build-sheng-pmgr.py) replaces this object.  The
// shared B3 link-only globals live in BringupLinkStubs.c so both archive
// variants provide them.
void sheng_pmgr_run(void)
{
}
