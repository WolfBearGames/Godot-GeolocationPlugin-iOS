#ifndef GEOLOCATION_H
#define GEOLOCATION_H

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/object/class_db.h"
#else
#include "core/object.h"
#endif

#ifdef __OBJC__
@class GodotGeolocation;
#else
typedef void GodotGeolocation;
#endif

class Geolocation : public Object {

    GDCLASS(Geolocation, Object);

    static Geolocation *instance;
    static void _bind_methods();
    
    bool sendDebugLog;
    
    GodotGeolocation *godot_geolocation;

public:
 
    enum GeolocationAuthorizationStatus {
        PERMISSION_STATUS_UNKNOWN = 1 << 0,
        PERMISSION_STATUS_DENIED = 1 << 1,
        PERMISSION_STATUS_ALLOWED = 1 << 2,
        };
    
    //enum GeolocationAccuracyAuthorization {
    //    AUTHORIZATION_FULL_ACCURACY = 1 << 0,
    //    AUTHORIZATION_REDUCED_ACCURACY = 1 << 1,
    //}
    
    enum GeolocationDesiredAccuracyConstants {
        ACCURACY_BEST_FOR_NAVIGATION = 1 << 0,
        ACCURACY_BEST = 1 << 1,
        ACCURACY_NEAREST_TEN_METERS = 1 << 2,
        ACCURACY_HUNDRED_METERS = 1 << 3,
        ACCURACY_KILOMETER = 1 << 4,
        ACCURACY_THREE_KILOMETER = 1 << 5,
        ACCURACY_REDUCED = 1 << 6,
    };
    
    enum GeolocationErrorCodes {
        ERROR_DENIED = 1 << 0,
        ERROR_NETWORK = 1 << 1,
        ERROR_HEADING_FAILURE = 1 << 2,
        ERROR_LOCATION_UNKNOWN = 1 << 3,
        ERROR_TIMEOUT = 1 << 4,
        ERROR_UNSUPPORTED = 1 << 5,
        ERROR_LOCATION_DISABLED = 1 << 6,
        ERROR_UNKNOWN = 1 << 7
    };
    
    bool supports(String methodName);
    
    // permissions and status
    void request_permission();
    Geolocation::GeolocationAuthorizationStatus authorization_status();
    bool allows_full_accuracy();
    
    void request_location_capabilty(); // new-a -1
    
    bool should_show_permission_requirement_explanation(); // new-a -1
    
    bool should_check_location_capability();
    
    bool can_request_permissions();
    bool is_updating_location();
    bool is_updating_heading();
    
    // options
    void set_update_interval(int seconds); // not supported, noop
    void set_max_wait_time(int seconds); // not supported, noop
    void set_auto_check_location_capability(bool autocheck); // not supported, noop
    
    void set_distance_filter(float distance);
    void set_desired_accuracy(Geolocation::GeolocationDesiredAccuracyConstants desiredAccuracy);
    
    void set_debug_log_signal(bool send); // new-a -1
    void set_failure_timeout(int seconds); // new-a -1
    
    
    // property options
    void set_return_string_coordinates(bool returnStringCoordinates);
    //bool get_return_string_coordinates();
    
    // location
    void request_location();
    void start_updating_location();
    void stop_updating_location();
    
    void start_updating_heading();
    void stop_updating_heading();
    
    // signal sender methods
    void send_log_signal(String message, float number = 0);
    void send_error_signal(Geolocation::GeolocationErrorCodes errorCode);
    
    void send_authorization_changed_signal(Geolocation::GeolocationAuthorizationStatus status);
    void send_location_update_signal(Dictionary locationData);
    
    void send_heading_update_signal(Dictionary headingData);
    
    void send_location_capability_result(bool capable); // new-a -1
    
    
    static Geolocation *get_singleton();

    Geolocation();
    ~Geolocation();
};

VARIANT_ENUM_CAST(Geolocation::GeolocationAuthorizationStatus);
VARIANT_ENUM_CAST(Geolocation::GeolocationDesiredAccuracyConstants);
VARIANT_ENUM_CAST(Geolocation::GeolocationErrorCodes);

#endif
