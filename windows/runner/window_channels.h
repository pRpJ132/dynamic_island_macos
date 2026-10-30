#ifndef RUNNER_WINDOW_CHANNELS_H_
#define RUNNER_WINDOW_CHANNELS_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

void SetupWindowChannels(flutter::BinaryMessenger* messenger, HWND hwnd);

void TeardownWindowChannels();

#endif