# Speech Recognition Crash Fix

## 🔥 Problem Description

The app was crashing with a race condition in the `speech_to_text` plugin's audio engine initialization:

```
Thread 14: Installing audio tap (microphone recording)
Thread 22: Getting audio format (CRASHED)
```

**Root Cause**: Two threads were accessing the AVAudioEngine simultaneously, causing pointer authentication failure and memory corruption.

## ✅ Solution Implemented

Added **operation serialization** with a mutex-like flag and **strategic delays** to ensure audio engine operations don't overlap.

### Changes in `lib/services/speech_service.dart`:

1. **Added Operation Lock**:
```dart
bool _isOperationInProgress = false;
```

2. **Serialized `startListening()`**:
- Wait for any in-progress operation to complete
- Stop existing listening with 300ms delay for engine cleanup
- Start new listening session
- Wait 200ms for engine stabilization
- Release lock

3. **Serialized `stopListening()`**:
- Wait for any in-progress operation to complete
- Stop listening
- Wait 300ms for engine cleanup
- Release lock

## 🎯 Key Features of the Fix

### 1. **Operation Serialization**
```dart
while (_isOperationInProgress) {
  await Future.delayed(const Duration(milliseconds: 50));
}
_isOperationInProgress = true;
```
Ensures only one speech operation runs at a time.

### 2. **Audio Engine Cleanup Delays**
```dart
await _speech.stop();
await Future.delayed(const Duration(milliseconds: 300));
```
Gives AVAudioEngine time to fully shut down before new operations.

### 3. **Stabilization Delay**
```dart
await _speech.listen(...);
await Future.delayed(const Duration(milliseconds: 200));
```
Allows audio engine to stabilize after starting.

### 4. **Finally Blocks**
```dart
try {
  // ... operation
} finally {
  _isOperationInProgress = false;
}
```
Ensures lock is always released, even on errors.

## 📊 Expected Results

- ✅ No more crashes from concurrent audio engine access
- ✅ Smooth transitions between start/stop operations
- ✅ Proper cleanup between speech recognition sessions
- ⚡ Minimal performance impact (300-500ms delays only when switching states)

## 🧪 Testing Recommendations

1. **Rapid Button Pressing**: Press and release microphone button rapidly
2. **Game Switching**: Switch between games while speech recognition is active
3. **Background/Foreground**: Move app to background during speech recognition
4. **Long Sessions**: Play for extended periods to ensure no memory leaks

## 📝 Notes

- The delays (200-300ms) are necessary for iOS AVAudioEngine stability
- These delays only occur during state transitions (start/stop), not during active listening
- The mutex pattern prevents the race condition that was causing crashes
- All operations remain async and non-blocking

## 🔄 Rollback (if needed)

If this causes issues, revert the following lines in `speech_service.dart`:
- Remove `_isOperationInProgress` flag
- Remove `while` loops waiting for operation completion
- Remove `300ms` delays after stop
- Remove `200ms` delay after listen start
- Remove `finally` blocks

---

**Date**: 2024
**Severity**: CRITICAL - App crashing
**Status**: FIXED ✅
