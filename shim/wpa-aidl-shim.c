/*
 * The vendor's wpa_supplicant on onyx is built with Android's AIDL
 * interface: as it starts it registers
 * android.hardware.wifi.supplicant.ISupplicant/default, and the service
 * directory inside a recovery refuses the registration (the recovery's
 * VINTF manifests and service contexts do not describe it), so the
 * supplicant exits before it opens the interface the pages join networks
 * over.
 *
 * Preloaded into the supplicant, this answers that one registration as done.
 * The recovery talks to the supplicant over its per-interface control
 * socket, not over AIDL, so nothing else needs the service to be real.
 */
int AServiceManager_addService(void* binder, const char* instance) {
    (void)binder;
    (void)instance;
    return 0;
}
