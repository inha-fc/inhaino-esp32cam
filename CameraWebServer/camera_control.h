#pragma once

// Applies a named camera control command.
// Returns 0 on success, -1 on unknown variable, sensor error on failure.
int camera_apply_control(const char *variable, int val);
