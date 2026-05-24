# SWAN MATCH — MOBILE NETWORK & BATTERY PERFORMANCE AUDITING
*A step-by-step developer guide to profiling network resource usage, testing connection loss recovery behavior, and auditing battery drain on iOS & Android to maintain a premium, high-efficiency client experience.*

---

## 1. Network Profile Auditing (Avoiding Excessive Payload Waste)
Our app utilizes Firebase Firestore, Cloud Storage, and Stripe REST APIs. To ensure the app remains lightweight on user data, follow these profiling workflows:

### A. iOS Network Profiling (Xcode Instruments)
1. Connect your physical iOS test device to your macOS workstation via USB.
2. Open the Flutter project folder in Xcode: `open ios/Runner.xcworkspace`.
3. In the Xcode menu, select **Product > Profile** (or press `Cmd + I`).
4. Select the **Network** template tool from the list.
5. Click **Record** and launch the Swan Match app on your device.
6. **Swipe Profile:** Go through the Explore feed and swipe on 20 profiles.
7. **Observe Bandwidth Consumption:** Check if total bandwidth spikes or if images are being fetched repeatedly. (Our local image caching ensures that cached photos consume **zero** redundant network requests!).

### B. Android Network Profiling (Android Studio Profiler)
1. Open the project in Android Studio.
2. Build and run the app on a physical device in Profile mode:
   ```bash
   flutter run --profile
   ```
3. Open the **Profiler** tab at the bottom of Android Studio.
4. Select the active device/process and click the **Network** timeline.
5. Zoom in to analyze precise REST request headers, HTTP response sizes, and Firestore connection data rates.

---

## 2. Connection Loss Recovery Auditing (Offline Capabilities)
Dating apps are frequently used on the go under poor network conditions (LTE transitions, subways, weak Wi-Fi). To verify the app recovers gracefully:

### A. Simulating Weak Network Latency & Packet Loss
1. **iOS Developer Settings:** Go to **Settings > Developer > Network Link Conditioner**. Enable it and select a profile:
   - **Very Bad Network:** (10% Packet Loss, 500ms Delay)
   - **DSL / 3G:** (Limited bandwidth)
2. **Android Emulator Controls:** Open the emulator extended controls (three dots), navigate to **Network**, and set the **Network speed** to `GSM` or `GPRS`, and **Signal strength** to `Poor`.
3. **Verify App Behaviors:**
   - Confirm that loading indicators (shimmer states) display smoothly.
   - Verify that chat messages sent offline show a "pending" status and are successfully retried and synchronized once connection is restored (Firestore's native offline cache handles this automatically!).

---

## 3. Battery Drain & CPU Auditing (Preventing Overheating)
Excessive battery drain kills app retention instantly. Auditing CPU and GPU cycles ensures the app runs cool.

### A. iOS Energy Diagnostic Audits
1. In the Xcode Instruments menu, select **Energy Log**.
2. Run the app and execute high-compute flows:
   - Swipe continuously for 2 minutes.
   - Upload a new photo and trigger photo hashing duplicate detection.
   - Type in the Chat Conversation page.
3. Check the **Energy Impact** timeline. It should remain in the `Low` or `Medium` green zones. Any spikes into the red zone indicate CPU bottlenecks or runaway infinite animation loops.

### B. Android Studio CPU & Memory Profiler
1. In Android Studio Profiler, select the **CPU** timeline.
2. Choose **System Trace** and click **Record**.
3. Perform swipes, open profile details, and trigger chat notifications.
4. Analyze the thread call stacks. Verify that heavy image operations are run on background threads using Dart Isolates, ensuring the Main UI thread remains locked at a buttery-smooth **60/120 FPS**.
