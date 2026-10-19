#ifndef HEADROOM_SYSTEM_H
#define HEADROOM_SYSTEM_H
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    uint64_t bytes;
    uint64_t startTime;
} HRFootprint;

bool HRReadFootprint(int32_t pid, HRFootprint *result);
double HRContinuousSeconds(void);
#endif
