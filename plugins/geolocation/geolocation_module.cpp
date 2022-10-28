#include "geolocation_module.h"
#include "geolocation.h"

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/config/engine.h"
#else
#include "core/engine.h"
#endif

Geolocation *geolocation;

void register_geolocation_types() {
    geolocation = memnew(Geolocation);
    Engine::get_singleton()->add_singleton(Engine::Singleton("Geolocation", geolocation));
}

void unregister_geolocation_types() {
    if (geolocation) {
        memdelete(geolocation);
    }
}
