#import "geolocation.h"

#if VERSION_MAJOR == 4
#import "platform/ios/app_delegate.h"
#else
#import "platform/iphone/app_delegate.h"
#endif

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#if VERSION_MAJOR == 4
typedef PackedByteArray GodotByteArray;
#define GODOT_FLOAT_VARIANT_TYPE Variant::FLOAT
#define GODOT_BYTE_ARRAY_VARIANT_TYPE Variant::PACKED_BYTE_ARRAY
#else
typedef PoolByteArray GodotByteArray;
#define GODOT_FLOAT_VARIANT_TYPE Variant::REAL
#define GODOT_BYTE_ARRAY_VARIANT_TYPE Variant::POOL_BYTE_ARRAY
#endif


/*
 * Geolocation Objective C Class
 */
@interface GodotGeolocation : NSObject <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager* locationManager;

@property BOOL returnCoordinatesAsString;
@property BOOL onlySendLatestLocation;

@property BOOL isUpdatingLocation;
@property BOOL isUpdatingHeading;

@property Dictionary lastLocationData;
@property Dictionary lastHeadingData;

@property BOOL failureTimeoutRunning; // -timeout
@property BOOL useFailureTimeout; // -timeout
@property (nonatomic) double failureTimeout; // -timeout

- (void)initialize;

- (bool)supportsMethod:(String)methodName;

- (Geolocation::GeolocationAuthorizationStatus)authorizationStatus;

- (void)requestLocation;
- (void)startWatch;

- (void)sendLocationUpdate:(CLLocation *) location;

// LocationManager Delegate methods
- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations;
- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error;
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager;
- (void)locationManager:(CLLocationManager *)manager
       didUpdateHeading:(CLHeading *)newHeading;

- (void)startFailureTimeout; // -timeout
- (void)stopFailureTimeout; // -timeout
- (void)onFailureTimeout; // -timeout
//- (void)setFailureTimeout; // -timeout

@end


@implementation GodotGeolocation

@synthesize locationManager;

- (void)initialize
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self; // Tells the location manager to send updates to this object
    
    self.failureTimeout = 20; // -timeout
    
    
    self.returnCoordinatesAsString = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"GeolocationReturnCoordinatesAsString"] boolValue];
    self.onlySendLatestLocation = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"GeolocationOnlySendLatestLocation"] boolValue];
}

- (bool)supportsMethod:(String)methodName
{
    static NSArray *supportedMethods = @[@"request_permission", @"authorization_status", @"allows_full_accuracy",
                              @"can_request_permissions",@"is_updating_location",@"is_updating_heading",
                              @"set_distance_filter",@"set_desired_accuracy",@"set_return_string_coordinates",
                              @"request_location",@"start_updating_location",@"stop_updating_location",
                              @"start_updating_heading",@"stop_updating_heading",@"request_location_capabilty",
                              @"set_debug_log_signal",@"set_failure_timeout",@"should_check_location_capability"];
    NSString* methodNameString = [[NSString alloc] initWithUTF8String:methodName.utf8().get_data()];
    BOOL contains = [supportedMethods containsObject:methodNameString];
    return contains;
}

- (void)setFailureTimeout:(double)seconds // setter
{
    Geolocation::get_singleton()->send_log_signal("setFailureTimeout",seconds);
    self.useFailureTimeout = (seconds > 0);
    _failureTimeout = seconds;
}

- (void)startFailureTimeout // -timeout
{
    if(!self.useFailureTimeout) return;
    Geolocation::get_singleton()->send_log_signal("a startFailureTimeout START");
    
    [self performSelector:@selector(onFailureTimeout) withObject: self afterDelay: self.failureTimeout];
    self.failureTimeoutRunning = true;
}

- (void)stopFailureTimeout // -timeout
{
    if(!self.useFailureTimeout) return;
    Geolocation::get_singleton()->send_log_signal("a stopFailureTimeout STOP");
    
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(onFailureTimeout) object: self];
    self.failureTimeoutRunning = false;
}

- (void)onFailureTimeout // -timeout
{
    Geolocation::get_singleton()->send_log_signal("a onFailureTimeout ERROR TIMEOUT");
    Geolocation::get_singleton()->send_error_signal(Geolocation::ERROR_TIMEOUT);
    self.failureTimeoutRunning = false;
    // stop location updates
    if(self.isUpdatingLocation)
    {
        [self.locationManager stopUpdatingLocation];
    }
}


- (Geolocation::GeolocationAuthorizationStatus)authorizationStatus
{
    NSUInteger code;
    
    if (@available(iOS 14.0, *)) {
        code = self.locationManager.authorizationStatus;
    } else {
        // Fallback on earlier versions
        code = [CLLocationManager authorizationStatus]; // old
    }
    
    switch(code){
        case kCLAuthorizationStatusNotDetermined:
            return Geolocation::PERMISSION_STATUS_UNKNOWN;
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusDenied:
            return Geolocation::PERMISSION_STATUS_DENIED;
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return Geolocation::PERMISSION_STATUS_ALLOWED;
    }
    
    return Geolocation::PERMISSION_STATUS_DENIED;
}

- (void) setDistanceFilter:(CLLocationDistance)distance // in meters
{
    if(distance == 0)
    {
        self.locationManager.distanceFilter = kCLDistanceFilterNone;
    } else {
        self.locationManager.distanceFilter = distance;
    }
}

- (void) setDesiredAccuracy:(CLLocationAccuracy)accuracy
{
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
}

- (void)requestLocation
{
    if([self authorizationStatus] != Geolocation::PERMISSION_STATUS_ALLOWED)
    {
        Geolocation::get_singleton()->send_error_signal(Geolocation::ERROR_DENIED);
        return;
    }
    
    [self.locationManager requestLocation];
    [self startFailureTimeout]; // -timeout
}

- (void)startWatch
{
    if([self authorizationStatus] != Geolocation::PERMISSION_STATUS_ALLOWED)
    {
        Geolocation::get_singleton()->send_error_signal(Geolocation::ERROR_DENIED);
        return;
    }
    
    [self.locationManager startUpdatingLocation];
    self.isUpdatingLocation = YES;
    [self startFailureTimeout]; // -timeout
}

- (void) sendLocationUpdate:(CLLocation *) location
{
    //NSLog(@"Single element: %@", location);
    
    //Dictionary locationData;
    self.lastLocationData["latitude"] = location.coordinate.latitude;
    self.lastLocationData["longitude"] = location.coordinate.longitude;
    self.lastLocationData["accuracy"] = location.horizontalAccuracy;

    if(self.returnCoordinatesAsString)
    {
        char latString[20];
        snprintf(latString,20,"%.15f", location.coordinate.latitude);
        self.lastLocationData["latitude_string"] = latString;
        
        char lonString[20];
        snprintf(lonString,20,"%.15f", location.coordinate.longitude);
        self.lastLocationData["longitude_string"] = lonString;
    }
    
    self.lastLocationData["altitude"] = location.altitude;  
    self.lastLocationData["altitude_accuracy"] = location.verticalAccuracy;
    self.lastLocationData["course"] = location.course;
    
    if (@available(iOS 13.4, *)) {
        self.lastLocationData["course_accuracy"] = location.courseAccuracy;
    } else {
        // Fallback on earlier versions
        self.lastLocationData["course_accuracy"] = -1.0;
    }
    
    self.lastLocationData["speed"] = location.speed; // m/s
    self.lastLocationData["speed_accuracy"] = location.speedAccuracy;
    self.lastLocationData["timestamp"] = (int)location.timestamp.timeIntervalSince1970;
    
    Geolocation::get_singleton()->send_location_update_signal(self.lastLocationData);
}

// location manager delegate methods

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
    Geolocation::GeolocationAuthorizationStatus authorizationStatus = [self authorizationStatus];
    Geolocation::get_singleton()->send_authorization_changed_signal(authorizationStatus);
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    // -timeout
    if(self.failureTimeoutRunning)
    {
        [self stopFailureTimeout];
    }
    
    if(self.onlySendLatestLocation)
    {
        [self sendLocationUpdate:locations.lastObject];
    } else
    {
        for (CLLocation *location in locations) {
            [self sendLocationUpdate:location];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    Geolocation::GeolocationErrorCodes errorCode;
    
    self.isUpdatingLocation = false;
    
    switch(error.code)
    {
        case kCLErrorDenied:
        case kCLErrorPromptDeclined:
            errorCode = Geolocation::ERROR_DENIED;
            break;
        case kCLErrorNetwork:
            errorCode = Geolocation::ERROR_NETWORK;
            break;
        case kCLErrorHeadingFailure:
            errorCode = Geolocation::ERROR_HEADING_FAILURE;
            self.isUpdatingHeading = false;
            break;
        default:
            errorCode = Geolocation::ERROR_UNKNOWN;
    }
      
    Geolocation::get_singleton()->send_error_signal(errorCode);
    //Geolocation::get_singleton()->send_log_signal([error.localizedFailureReason UTF8String],error.code);
}

- (void)locationManager:(CLLocationManager *)manager
       didUpdateHeading:(CLHeading *)newHeading
{
    self.lastHeadingData["magnetic_heading"] = newHeading.magneticHeading;
    self.lastHeadingData["true_heading"] = newHeading.trueHeading;
    self.lastHeadingData["heading_accuracy"] = newHeading.headingAccuracy;
    self.lastHeadingData["timestamp"] = (int)newHeading.timestamp.timeIntervalSince1970;
    
    Geolocation::get_singleton()->send_heading_update_signal(self.lastHeadingData);
}


@end

Geolocation *Geolocation::instance = NULL;

Geolocation *Geolocation::get_singleton() {
    return instance;
};


/*
 * Bind plugin's public interface
 */
void Geolocation::_bind_methods() {
    
    ClassDB::bind_method(D_METHOD("supports"), &Geolocation::supports);
    // authorization
    ClassDB::bind_method(D_METHOD("request_permission"), &Geolocation::request_permission);
    ClassDB::bind_method(D_METHOD("authorization_status"), &Geolocation::authorization_status);
    ClassDB::bind_method(D_METHOD("allows_full_accuracy"), &Geolocation::allows_full_accuracy);
    ClassDB::bind_method(D_METHOD("can_request_permissions"), &Geolocation::can_request_permissions);
    ClassDB::bind_method(D_METHOD("is_updating_location"), &Geolocation::is_updating_location);
    ClassDB::bind_method(D_METHOD("is_updating_heading"), &Geolocation::is_updating_heading);
    
    ClassDB::bind_method(D_METHOD("request_location_capabilty"), &Geolocation::request_location_capabilty);
    ClassDB::bind_method(D_METHOD("should_show_permission_requirement_explanation"), &Geolocation::should_show_permission_requirement_explanation);
    ClassDB::bind_method(D_METHOD("should_check_location_capability"), &Geolocation::should_check_location_capability);
    
    // options
    ClassDB::bind_method(D_METHOD("set_update_interval","seconds"), &Geolocation::set_update_interval); // not supported, noop
    ClassDB::bind_method(D_METHOD("set_max_wait_time","seconds"), &Geolocation::set_max_wait_time); // not supported, noop
    ClassDB::bind_method(D_METHOD("set_auto_check_location_capability","autocheck"), &Geolocation::set_auto_check_location_capability); // not supported, noop
    

    ClassDB::bind_method(D_METHOD("set_distance_filter","meters"), &Geolocation::set_distance_filter);
    ClassDB::bind_method(D_METHOD("set_desired_accuracy","accuracy"), &Geolocation::set_desired_accuracy);
    // return value configuration (also possible in info.plist so this might be not needed
    ClassDB::bind_method(D_METHOD("set_return_string_coordinates", "value"), &Geolocation::set_return_string_coordinates);
    
    ClassDB::bind_method(D_METHOD("set_debug_log_signal","send"), &Geolocation::set_debug_log_signal);
    ClassDB::bind_method(D_METHOD("set_failure_timeout","seconds"), &Geolocation::set_failure_timeout);
    
    // location
    ClassDB::bind_method(D_METHOD("request_location"), &Geolocation::request_location);
    ClassDB::bind_method(D_METHOD("start_updating_location"), &Geolocation::start_updating_location);
    ClassDB::bind_method(D_METHOD("stop_updating_location"), &Geolocation::stop_updating_location);
    
    //heading
    ClassDB::bind_method(D_METHOD("start_updating_heading"), &Geolocation::start_updating_heading);
    ClassDB::bind_method(D_METHOD("stop_updating_heading"), &Geolocation::stop_updating_heading);
    
    //ClassDB::bind_method(D_METHOD("get_return_string_coordinates"), &Geolocation::get_return_string_coordinates);
    //ADD_PROPERTY(PropertyInfo(Variant::BOOL, "return_string_coordinates"), "set_return_string_coordinates", "get_return_string_coordinates");
    
    // signals
    ADD_SIGNAL(MethodInfo("log", PropertyInfo(Variant::STRING, "message"), PropertyInfo(Variant::REAL, "number")));
    ADD_SIGNAL(MethodInfo("error", PropertyInfo(Variant::INT, "errorCode")));
    ADD_SIGNAL(MethodInfo("location_update", PropertyInfo(Variant::DICTIONARY, "locationData")));
    ADD_SIGNAL(MethodInfo("authorization_changed", PropertyInfo(Variant::INT, "status")));
    ADD_SIGNAL(MethodInfo("heading_update", PropertyInfo(Variant::DICTIONARY, "headingData")));
    
    ADD_SIGNAL(MethodInfo("location_capability_result", PropertyInfo(Variant::BOOL, "capable")));
        
    // Enums / Constants
    
    // Authorization
    BIND_ENUM_CONSTANT(PERMISSION_STATUS_UNKNOWN);
    BIND_ENUM_CONSTANT(PERMISSION_STATUS_DENIED);
    BIND_ENUM_CONSTANT(PERMISSION_STATUS_ALLOWED);
    
    // Accuracy Authorization (get only)
    //BIND_ENUM_CONSTANT(AUTHORIZATION_FULL_ACCURACY);
    //BIND_ENUM_CONSTANT(AUTHORIZATION_REDUCED_ACCURACY);
    
    // Accuracy (set only)
    BIND_ENUM_CONSTANT(ACCURACY_BEST_FOR_NAVIGATION);
    BIND_ENUM_CONSTANT(ACCURACY_BEST);
    BIND_ENUM_CONSTANT(ACCURACY_NEAREST_TEN_METERS);
    BIND_ENUM_CONSTANT(ACCURACY_HUNDRED_METERS);
    BIND_ENUM_CONSTANT(ACCURACY_KILOMETER);
    BIND_ENUM_CONSTANT(ACCURACY_THREE_KILOMETER);
    BIND_ENUM_CONSTANT(ACCURACY_REDUCED);
    
    // Error Codes
    BIND_ENUM_CONSTANT(ERROR_DENIED);
    BIND_ENUM_CONSTANT(ERROR_NETWORK);
    BIND_ENUM_CONSTANT(ERROR_HEADING_FAILURE);
    BIND_ENUM_CONSTANT(ERROR_LOCATION_UNKNOWN);
    BIND_ENUM_CONSTANT(ERROR_TIMEOUT);
    BIND_ENUM_CONSTANT(ERROR_UNSUPPORTED);
    BIND_ENUM_CONSTANT(ERROR_LOCATION_DISABLED);
    BIND_ENUM_CONSTANT(ERROR_UNKNOWN);
    
};

bool Geolocation::supports(String methodName)
{
    return [godot_geolocation supportsMethod:methodName];
}

void Geolocation::request_permission() {
    // if we can't request permission anymore, at least trigger authorization_changed
    // so we get any answer
    if(can_request_permissions())
    {
        [godot_geolocation.locationManager requestAlwaysAuthorization];
    } else
    {
        //send_log_signal("a request_permission not possible send denied");
        send_authorization_changed_signal([godot_geolocation authorizationStatus]);
    }
};

Geolocation::GeolocationAuthorizationStatus Geolocation::authorization_status() {
    return [godot_geolocation authorizationStatus];
};

bool Geolocation::allows_full_accuracy()
{
    if (@available(iOS 14.0, *)) {
        switch(godot_geolocation.locationManager.accuracyAuthorization)
        {
            case CLAccuracyAuthorizationFullAccuracy:
                return true;
            case CLAccuracyAuthorizationReducedAccuracy:
                return false;
        }
    } else {
        return false; // just say no on iOS < 14
    }
}

void Geolocation::request_location_capabilty()
{
    // execute async because it blocks main thread (and is async on Android anyway)
    send_log_signal("a request_location_capabilty");
        
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
        //Background Thread
        bool capable = [CLLocationManager locationServicesEnabled];
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            send_location_capability_result(capable);
        });
    });
}

bool Geolocation::can_request_permissions()
{
    return ([godot_geolocation authorizationStatus] == PERMISSION_STATUS_UNKNOWN);
}


bool Geolocation::should_show_permission_requirement_explanation()
{
    // should send error, that this is not suppported?
    send_log_signal("a should_show_permission_requirement_explanation NOT SUPPORTED");
    return false;
}

bool Geolocation::should_check_location_capability()
{
    // not needed on ios, because authorization will be "denied" when locartion services are disabled
    return false;
}

bool Geolocation::is_updating_location()
{
    return godot_geolocation.isUpdatingLocation;
}

bool Geolocation::is_updating_heading()
{
    return godot_geolocation.isUpdatingHeading;
}


void Geolocation::set_update_interval(int seconds)
{
    send_log_signal("a set_update_interval NOT SUPPORTED");
    // not implemented on iOS
}

void Geolocation::set_max_wait_time(int seconds)
{
    send_log_signal("a set_max_wait_time NOT SUPPORTED");
    // not implemented on iOS
}

void Geolocation::set_auto_check_location_capability(bool autocheck)
{
    send_log_signal("a set_auto_check_location_capability NOT SUPPORTED");
    // not implemented on iOS
}

void Geolocation::set_distance_filter(float distance)
{
    [godot_geolocation setDistanceFilter:distance];
    //emit_signal("log", "new Distance set", distance);
}

void Geolocation::set_desired_accuracy(Geolocation::GeolocationDesiredAccuracyConstants desiredAccuracy)
{
    switch(desiredAccuracy)
    {
        case ACCURACY_BEST_FOR_NAVIGATION:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyBestForNavigation];
            break;
        case ACCURACY_BEST:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
            break;
        case ACCURACY_NEAREST_TEN_METERS:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
            break;
        case ACCURACY_HUNDRED_METERS:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyHundredMeters];
            break;
        case ACCURACY_KILOMETER:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyKilometer];
            break;
        case ACCURACY_THREE_KILOMETER:
            [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyThreeKilometers];
            break;
        case ACCURACY_REDUCED:
            if (@available(iOS 14.0, *)) {
                [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyReduced];
            } else {
                [godot_geolocation.locationManager setDesiredAccuracy:kCLLocationAccuracyThreeKilometers];
            }
            break;
    }
}

void Geolocation::set_return_string_coordinates(bool returnStringCoordinates)
{
    godot_geolocation.returnCoordinatesAsString = returnStringCoordinates;
}

//bool Geolocation::get_return_string_coordinates()
//{
//    return godot_geolocation.returnCoordinatesAsString;
//}

void Geolocation::set_debug_log_signal(bool send)
{
    sendDebugLog = send;
    send_log_signal("a set_debug_log_signal set");
}

void Geolocation::set_failure_timeout(int seconds)
{
    send_log_signal("a set_failure_timeout");
    godot_geolocation.failureTimeout = seconds; // is setter method
    
    //godot_geolocation.failureTimeout = (double)seconds;
    //godot_geolocation.useFailureTimeout = (seconds > 0);
    
}

void Geolocation::request_location() {
    //[godot_geolocation.locationManager requestLocation];
    [godot_geolocation requestLocation];
};

void Geolocation::start_updating_location() {
    //[godot_geolocation.locationManager startUpdatingLocation];
    [godot_geolocation startWatch];
};

void Geolocation::stop_updating_location() {
    [godot_geolocation.locationManager stopUpdatingLocation];
    godot_geolocation.isUpdatingLocation = false;
};

void Geolocation::start_updating_heading() {
    [godot_geolocation.locationManager  startUpdatingHeading];
    godot_geolocation.isUpdatingHeading = true;
};

void Geolocation::stop_updating_heading() {
    [godot_geolocation.locationManager  stopUpdatingHeading];
    godot_geolocation.isUpdatingHeading = false;
};


// signals

void Geolocation::send_log_signal(String message, float number) {
    if(!sendDebugLog) return; // only log when enabled
    emit_signal("log", message, number);
};

void Geolocation::send_error_signal(Geolocation::GeolocationErrorCodes errorCode) {
    emit_signal("error", errorCode);
};

void Geolocation::send_authorization_changed_signal(Geolocation::GeolocationAuthorizationStatus status) {
    emit_signal("authorization_changed", status);
};

void Geolocation::send_location_update_signal(Dictionary locationData) {
    emit_signal("location_update", locationData);
};

void Geolocation::send_heading_update_signal(Dictionary headingData) {
    emit_signal("heading_update", headingData);
};

void Geolocation::send_location_capability_result(bool capable) {
    emit_signal("location_capability_result", capable);
};

Geolocation::Geolocation() {
    ERR_FAIL_COND(instance != NULL);
    instance = this;
    godot_geolocation = [[GodotGeolocation alloc] init];
    [godot_geolocation initialize];
    
    sendDebugLog = false;
    
    NSLog(@"initialize object");
}

Geolocation::~Geolocation() {
    instance = NULL;
    NSLog(@"deinitialize object");
    godot_geolocation = nil;
}
