#include "HeadroomSystem.h"
#include <libproc.h>
#include <sys/resource.h>
#include <mach/mach_time.h>
#include <mach/kern_return.h>
#include <math.h>
#include <stddef.h>

bool HRReadFootprint(int32_t pid, HRFootprint *result) {
    if (pid <= 0 || result == NULL) return false;
    struct rusage_info_v0 usage = {0};
    // libproc.h takes rusage_info_t* (void**); the buffer is the struct itself,
    // not a pointer stored inside it. Keep this Darwin ABI cast in C.
    if (proc_pid_rusage(pid, RUSAGE_INFO_V0, (rusage_info_t *)&usage) != 0 ||
        usage.ri_proc_start_abstime == 0 || usage.ri_proc_exit_abstime != 0) return false;
    result->bytes = usage.ri_phys_footprint;
    result->startTime = usage.ri_proc_start_abstime;
    return true;
}

double HRContinuousSeconds(void) {
    mach_timebase_info_data_t timebase;
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || timebase.denom == 0) return NAN;
    // Continuous time advances during sleep; wall-clock changes cannot affect rates.
    return (double)mach_continuous_time() * (double)timebase.numer /
           (double)timebase.denom / 1e9;
}
