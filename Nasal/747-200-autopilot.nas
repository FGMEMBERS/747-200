# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =========
# AUTOPILOT
# =========

Autopilot = {};

Autopilot.new = func {
   obj = { parents : [Autopilot],

           autothrottlesystem : nil,

           ap : nil,
           attitude : nil,
           autoflight : nil,
           locks : nil,
           settings : nil,
           waypoints : nil,

           AUTOPILOTSEC : 1.0,                           # refresh rate
           AUTOLANDSEC : 1.0,
           SAFESEC : 1.0,
           TOUCHSEC : 0.2,
           FLARESEC : 0.1,
       
           LANDINGLB : 630000.0,                          # max landing weight
           EMPTYLB : 376170.0,                            # empty weight

           TOUCHDEG : 3.0,                                # landing pitch
           FLAREDEG : 0.0,                                # avoids rebound by landing pitch

           AUTOLANDFEET : 1500.0,
# - instead of 100 ft, as catching glide makes nose down
# (bug in glide slope, or more sophisticated autopilot is required ?);
           GLIDEFEET : 200.0,                             # leaves glide slope
# - nav is supposed accurate until 0 ft.
# - bypass possible nav errors (example : KJFK 22L, EGLL 27R).
           NAVFEET : 200.0,                               # leaves nav
# a responsive vertical-speed-with-throttle reduces the rebound by ground effect
           GROUNDFEET : 20.0,                             # altimeter altitude

           CRUISEKT : 450.0,
           TRANSITIONKT : 250.0,
           VREFFULLKT : 154.0,
           VREFEMPTYKT : 120.0,

           TOUCHFPM : -750.0,                             # structural limit

           landheadingdeg : 0.0,                          # touch down without nav

           ROLLDEG : 2.0,                                 # roll to swap to next waypoint
           WPTNM : 3.0,                                   # distance to swap to next waypoint
           COEFVOR : 0.0,
           COEFWPT : 0.0
         };

   obj.init();

   return obj;
};

Autopilot.init = func {
   me.ap = props.globals.getNode("/controls/autoflight").getChildren("autopilot");
   me.attitude = props.globals.getNode("/orientation");
   me.autoflight = props.globals.getNode("/controls/autoflight");
   me.locks = props.globals.getNode("/autopilot/locks");
   me.settings = props.globals.getNode("/autopilot/settings");
   me.waypoints = props.globals.getNode("/autopilot/route-manager").getChildren("wp");

   # 3 NM at 450 kt 
   me.COEFWPT = me.WPTNM * constant.HOURTOSECOND / me.CRUISEKT;
   # 3 NM at 250 kt 
   me.COEFVOR = me.WPTNM * constant.HOURTOSECOND / me.TRANSITIONKT;

   # selectors
   me.aphorizontalexport();
}

Autopilot.set_relation = func( autothrottle ) {
   me.autothrottlesystem = autothrottle;
}

Autopilot.schedule = func {
   # user adds a waypoint
   if( me.is_waypoint() ) {
       if( me.is_lock_true() ) {
           # restore current mode
           if( !me.is_ins() or !me.is_engaged() ) {
               me.aphorizontalexport();
           }
       }
   }

   if( me.is_engaged() ) {
       # avoids strong bank
       if( me.is_ins() ) {
           me.waypointroll();
       }
       elsif( me.is_vor() ) {
           me.vorroll();
       }

       # heading changed by keyboard
       elsif( me.is_magnetic() ) {
           dialdeg = me.autoflight.getChild("dial-heading-deg").getValue();
           headingdeg = me.settings.getChild("heading-bug-deg").getValue();
           if( headingdeg != dialdeg ) {
               me.autoflight.getChild("dial-heading-deg").setValue(headingdeg);
           }
       }
   }
}

# avoid strong roll near a waypoint
Autopilot.waypointroll = func {
    distance = me.waypoints[0].getChild("dist").getValue();

    # next waypoint
    if( distance != nil ) {
        # 3 NM at 450 kt 
        speedkt = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
        speednmps =  speedkt / constant.HOURTOSECOND;
        rangenm = speednmps * me.COEFWPT;

        # restores after waypoint pop
        if( me.is_lock_magnetic() ) {
            wpt = me.waypoints[0].getChild("id").getValue();
            lastwpt = getprop("/systems/autopilot/state/waypoint");
            if( wpt != lastwpt ) {
                me.locktrue();
            }
        }

        # avoids strong roll
        elsif( distance < rangenm ) {
            # 2 time steps
            stepnm = speednmps * me.AUTOPILOTSEC;
            stepnm = stepnm * 2.0;

            # switches to heading hold
            rolldeg =  me.attitude.getChild("roll-deg").getValue();
            if( distance < stepnm or rolldeg < - me.ROLLDEG or rolldeg > me.ROLLDEG ) {
                if( me.is_lock_true() ) {
                    me.holdmagnetic();
                    wpt = me.waypoints[0].getChild("id").getValue();
                    setprop("/systems/autopilot/state/waypoint",wpt);
                }
            }
        }
    }
}

# avoid strong roll near a VOR
Autopilot.vorroll = func {
    # near VOR
    if( getprop("/instrumentation/dme[0]/in-range") ) {
        # 3 NM at 250 kt 
        speedkt = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt");
        speednmps =  speedkt / constant.HOURTOSECOND;
        rangenm = speednmps * me.COEFVOR;

        # restores after VOR
        if( getprop("/instrumentation/dme[0]/indicated-distance-nm") > rangenm ) {
            if( me.is_lock_magnetic() ) {
                me.locknav1();
            }

            setprop("/systems/autopilot/state/vor-engage",constant.FALSE);
        }

        # avoids strong roll
        else {
            # switches to heading hold
            if( me.is_lock_nav1() ) {
                # except if mode has just been engaged, leaving a VOR :
                # EGLL 27R, then leaving LONDON VOR 113.60 on its 260 deg radial (SID COMPTON 3).
                if( !getprop("/systems/autopilot/state/vor-engage") or
                    ( getprop("/systems/autopilot/state/vor-engage") and
                      getprop("/instrumentation/nav[0]/from-flag") ) ) { 
                    me.holdmagnetic();
                }
            }
        }
    }
}

Autopilot.clampweight = func ( vallanding, valempty ) {
    weightlb = getprop("/fdm/jsbsim/inertia/weight-lbs");
    if( weightlb > me.LANDINGLB ) {
        result = vallanding;
    }
    else {
        coef = ( me.LANDINGLB - weightlb ) / ( me.LANDINGLB - me.EMPTYLB );
        result = vallanding + coef * ( valempty - vallanding );
    }

    return result;
}

# adjust target speed with wind
Autopilot.targetwind = func {
   # VREF
   targetkt = me.clampweight( me.VREFFULLKT, me.VREFEMPTYKT );

   # wind increases lift
   windkt = getprop("/environment/wind-speed-kt");
   if( windkt > 0 ) {
       winddeg = getprop("/environment/wind-from-heading-deg");
       vordeg = getprop("/instrumentation/nav[0]/radials/target-radial-deg");
       offsetdeg = vordeg - winddeg;
       offsetdeg = constant.crossnorth( offsetdeg );

       # add head wind component; except tail wind (too much glide)
       if( offsetdeg > -constant.DEG90 and offsetdeg < constant.DEG90 ) {
           offsetrad = offsetdeg * constant.DEGTORAD;
           offsetkt = windkt * math.cos( offsetrad );

           # otherwise, VREF 154 kt + 30 kt head wind overspeeds the 180 kt of 30 deg flaps.
           offsetkt = offsetkt / 2;          
           if( offsetkt > 20 ) {
               offsetkt = 20;
           }
           elsif( offsetkt < 5 ) {
               offsetkt = 5;
           }

           targetkt = targetkt + offsetkt;
       }
   }

   # avoid infinite gliding
   me.settings.getChild("target-speed-kt").setValue(targetkt);
}

# reduces the rebound caused by ground effect
Autopilot.targetpitch = func( aglft ) {
   # counter the rebound of ground effect
   if( aglft > me.GLIDEFEET ) {
       targetdeg = me.FLAREDEG;
   }
   elsif( aglft < me.GROUNDFEET ) {
       targetdeg = me.TOUCHDEG;
   }
   else {
       coef = ( aglft - me.GROUNDFEET ) / ( me.GLIDEFEET - me.GROUNDFEET );
       targetdeg = me.TOUCHDEG + coef * ( me.FLAREDEG - me.TOUCHDEG );
   }
   
   me.holdpitch(targetdeg);
}

# cannot make a settimer on a member function
autolandcron = func {
   autopilotsystem.autoland();
}

Autopilot.is_landing = func {
   verticalmode = me.autoflight.getChild("heading").getValue();
   if( verticalmode == "autoland" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_land_armed = func {
   verticalmode = me.autoflight.getChild("heading").getValue();
   if( verticalmode == "autoland-armed" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_autoland = func {
   if( me.is_landing() or me.is_land_armed() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# autoland mode
Autopilot.autoland = func {
   if( me.is_engaged() ) {
       if( me.is_autoland() ) {

           rates = me.AUTOLANDSEC;
           aglft = getprop("/instrumentation/radio-altimeter/indicated-altitude-ft");

           # armed
           if( me.is_land_armed() ) {
               if( aglft <= me.AUTOLANDFEET ) {
                   me.autoflight.getChild("heading").setValue("autoland");
               }
           }

           # engaged
           if( me.is_landing() ) {
               # touch down
               if( aglft < Constantaero.AGLTOUCHFT ) {

                   # gently reduce pitch
                   if( me.attitude.getChild("pitch-deg").getValue() > 1.0 ) {
                       rates = me.TOUCHSEC;

                       # 1 deg / s
                       pitchdeg = me.settings.getChild("target-pitch-deg").getValue();
                       pitchdeg = pitchdeg - 0.2;
                       me.holdpitch( pitchdeg );
                   }

                   # safe on ground
                   else {
                       rates = me.SAFESEC;

                       # disable autopilot and autothrottle
                       me.autothrottlesystem.atdisable();
                       me.apdisableexport();

                       # reset trims
                       setprop("/controls/flight/elevator-trim",0.0);
                       setprop("/controls/flight/rudder-trim",0.0);
                       setprop("/controls/flight/aileron-trim",0.0);
                   }

                   # engine idles
                   me.autothrottlesystem.idle();
               }

               # triggers below 1500 ft
               elsif( aglft > me.AUTOLANDFEET ) {
                   me.autoflight.getChild("heading").setValue("autoland-armed");
               }

               # systematic forcing of speed modes
               else {
                   if( aglft < me.GLIDEFEET ) {
                       rates = me.FLARESEC;

                       # landing pitch (flare) : removes the rebound at touch down of vertical-speed-hold.
                       me.targetpitch( aglft );

                       # heading hold avoids roll outside the runway.
                       if( !me.autoflight.getChild("real-nav").getValue() ) {
                           if( aglft < me.NAVFEET ) {
                               if( !me.is_lock_magnetic() ) {
                                   me.landheadingdeg = getprop("/orientation/heading-magnetic-deg");
                               }
                               me.holdheading( me.landheadingdeg );
                           }
                       }

                       # pilot must activate autothrottle
                       me.settings.getChild("vertical-speed-fpm").setValue( me.TOUCHFPM );
                       me.autothrottlesystem.atenable("vertical-speed-with-throttle");

                   }

                   # glide slope : cannot go back when then aircraft climbs again (caused by landing pitch),
                   # otherwise will crash to catch the glide slope.
                   elsif( !me.autothrottlesystem.is_glide() ) {

                       # near VREF (no wind)
                       me.targetwind();

                       # pilot must activate autothrottle
                       me.autothrottlesystem.atsend();
                   }

                   # records attitude at flare
                   else {
                       me.FLAREDEG = me.attitude.getChild("pitch-deg").getValue();
                   }
               } 
           }
       }

       # re-schedule the next call
       if( me.is_autoland() ) {
           settimer(autolandcron, rates);
       }
   }
}

Autopilot.is_engaged = func {
   if( me.ap[0].getChild("engage").getValue() ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.engage = func( state ) {
   me.ap[0].getChild("engage").setValue( state );
}

Autopilot.apdisableexport = func {
   me.engage(constant.FALSE);
   me.autoflight.getChild("heading").setValue("");
   me.autoflight.getChild("altitude").setValue("");
   me.autoflight.getChild("vertical").setValue("");

   me.apengageexport();
}

Autopilot.is_altitude_select = func {
   altitudemode = me.autoflight.getChild("altitude").getValue();
   if( altitudemode == "altitude-select" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# toggle altitude select (ctrl-A)
Autopilot.aptogglealtitudeexport = func {
   if( !me.is_altitude_select() ) {
       me.engage(constant.TRUE);
       me.apaltitudeselectexport();
   }
   else {
       me.autoflight.getChild("altitude").setValue("");

       me.apverticalexport();
   }
}

Autopilot.apaltitudeselectexport = func {
   targetft = me.autoflight.getChild("dial-altitude-ft").getValue();
   me.settings.getChild("target-altitude-ft").setValue(targetft);
   me.autoflight.getChild("altitude").setValue("altitude-select");

   me.apengageexport();
}

Autopilot.is_altitude_hold = func {
   altitudemode = me.autoflight.getChild("altitude").getValue();
   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# toggle altitude hold (ctrl-T)
Autopilot.aptogglealtitudeholdexport = func {
   if( !me.is_altitude_hold() ) {
       me.engage(constant.TRUE);
       me.apaltitudeholdexport();
   }
   else {
       me.autoflight.getChild("altitude").setValue("");

       me.apverticalexport();
   }
}

Autopilot.apaltitudeholdexport = func {
   targetft = getprop("/instrumentation/altimeter/indicated-altitude-ft");
   me.settings.getChild("target-altitude-ft").setValue(targetft);
   me.autoflight.getChild("altitude").setValue("altitude-hold");

   me.apengageexport();
}

Autopilot.is_ils = func {
   headingmode = me.autoflight.getChild("heading").getValue();
   if( headingmode == "ils-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

# toggle glide slope (ctrl-G)
Autopilot.aptoggleglideexport = func {
   if( !me.is_ils() or ( me.is_ils() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.autoflight.getChild("horizontal-selector").setValue(1);
   }
   else {
       me.engage(constant.FALSE);
       me.autoflight.getChild("horizontal-selector").setValue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.is_waypoint = func {
   id = me.waypoints[0].getChild("id").getValue();
   if( id != nil and id != "" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_lock_true = func {
   headingmode = me.locks.getChild("heading").getValue();
   if( headingmode == "true-heading-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_magnetic = func {
   headingmode = me.autoflight.getChild("heading").getValue();
   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_lock_magnetic = func {
   headingmode = me.locks.getChild("heading").getValue();
   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.locktrue = func {
   me.locks.getChild("heading").setValue("true-heading-hold");
}

Autopilot.lockmagnetic = func {
   me.locks.getChild("heading").setValue("dg-heading-hold");
}

Autopilot.holdmagnetic = func {
   headingdeg = getprop("/orientation/heading-magnetic-deg");
   me.holdheading( headingdeg );
}

Autopilot.holdheading = func( headingdeg ) {
   me.settings.getChild("heading-bug-deg").setValue(headingdeg);
   me.lockmagnetic();
}

# toggle heading hold (ctrl-H)
Autopilot.aptoggleheadingexport = func {
   if( !me.is_magnetic() or ( me.is_magnetic() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.autoflight.getChild("horizontal-selector").setValue(-1);
   }
   else {
       me.engage(constant.FALSE);
       me.autoflight.getChild("horizontal-selector").setvalue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.is_nav1 = func {
   headingmode = me.autoflight.getChild("heading").getValue();
   if( headingmode == "nav1-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_lock_nav1 = func {
   headingmode = me.locks.getChild("heading").getValue();
   if( headingmode == "nav1-hold" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.locknav1 = func {
   me.locks.getChild("heading").setValue("nav1-hold");
}

# toggle vor loc (ctrl-N)
Autopilot.aptogglevorlocexport = func {
   if( !me.is_nav1() or ( me.is_nav1() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.autoflight.getChild("horizontal-selector").setValue(0);
   }
   else {
       me.engage(constant.FALSE);
       me.autoflight.getChild("horizontal-selector").setValue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.is_ins = func {
   horizontalselector = me.autoflight.getChild("horizontal-selector").getValue();

   if( horizontalselector == -2 ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.is_vor = func {
   horizontalselector = me.autoflight.getChild("horizontal-selector").getValue();

   if( horizontalselector == 0 ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autopilot.aphorizontalexport = func {
   horizontalselector = me.autoflight.getChild("horizontal-selector").getValue();

   if( horizontalselector == -2 ) {
       headingmode = "true-heading-hold";
   }
   elsif( horizontalselector == -1 ) {
       headingmode = "dg-heading-hold";
   }
   elsif( horizontalselector == 0 ) {
       headingmode = "nav1-hold";
   }
   elsif( horizontalselector == 1 ) {
       headingmode = "ils-hold";
   }
   elsif( horizontalselector == 2 ) {
       headingmode = "autoland-armed";
   }
   else {
       headingmode = "";
   }

   me.autoflight.getChild("heading").setValue(headingmode);

   me.apengageexport();
}

Autopilot.apverticalexport = func {
   verticalselector = me.autoflight.getChild("vertical-selector").getValue();

   if( verticalselector == -1 ) {
       verticalmode = "";
   }
   elsif( verticalselector == 0 ) {
       verticalmode = "vertical-speed-hold";
       verticalspeedfps = getprop("/instrumentation/inst-vertical-speed-indicator/indicated-speed-fps");
       verticalspeedfpm = verticalspeedfps * constant.MINUTETOSECOND;
       me.settings.getChild("vertical-speed-fpm").setValue(verticalspeedfpm);
   }
   else {
       verticalmode = "";
   }

   me.autoflight.getChild("vertical").setValue(verticalmode);

   me.apengageexport();
}

Autopilot.holdpitch = func( pitchdeg ) {
   me.settings.getNode("target-pitch-deg").setValue(pitchdeg);
   me.lockpitch();
}

Autopilot.lockpitch = func {
   me.locks.getChild("altitude").setValue("pitch-hold");
}

Autopilot.disabledexport = func {
}

Autopilot.apengageexport = func {
   if( me.is_engaged() ) {
       verticalmode = me.autoflight.getChild("vertical").getValue();
       altitudemode = me.autoflight.getChild("altitude").getValue();
       headingmode = me.autoflight.getChild("heading").getValue();

       if( me.is_altitude_select() ) {
           altitudemode = "altitude-hold";
       }

       # vertical speed has priority on altitude hold
       if( verticalmode != "" ) {
           altitudemode = verticalmode;
       }

       # approach has priority
       if( me.is_ils() or me.is_autoland() ) {
           headingmode = "nav1-hold";
           altitudemode = "gs1-hold";
       }
   }
   else {
       altitudemode = "";
       headingmode = "";
   }

   me.locks.getChild("altitude").setValue(altitudemode);
   me.locks.getChild("heading").setValue(headingmode);

   if( me.is_magnetic() ) {
       headingdeg = me.autoflight.getChild("dial-heading-deg").getValue();
       me.settings.getChild("heading-bug-deg").setValue(headingdeg);
   }

   me.autoland();
}


# ============
# AUTOTHROTTLE
# ============

Autothrottle = {};

Autothrottle.new = func {
   obj = { parents : [Autothrottle],

           autoflight : nil,
           engines : nil,
           locks : nil,
           settings : nil,

           AUTOMACHFEET : 0.0
         };

   obj.init();

   return obj;
};

Autothrottle.init = func {
   me.autoflight = props.globals.getNode("/controls/autoflight");
   me.engines = props.globals.getNode("/controls/engines").getChildren("engine");
   me.locks = props.globals.getNode("/autopilot/locks");
   me.settings = props.globals.getNode("/autopilot/settings");

   me.AUTOMACHFEET = me.autoflight.getChild("automach-ft").getValue();
}

Autothrottle.schedule = func {
   # automatic swaps between kt and Mach
   speedmode = me.locks.getChild("speed").getValue();
   if( speedmode != "" and speedmode != nil ) {
       me.atmode( speedmode );
   }
}

# speed of sound
Autothrottle.getsoundkt = func {
   # simplification
   speedkt = getprop("/velocities/airspeed-kt");
   speedmach = getprop("/velocities/mach");
   soundkt = speedkt / speedmach;

   return soundkt;
}

Autothrottle.is_vertical = func {
   speedmode = me.locks.getChild("speed").getValue();
   if( speedmode == "vertical-speed-with-throttle" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autothrottle.is_glide = func {
   speedmode = me.locks.getChild("speed").getValue();
   if( speedmode == "gs1-with-throttle" ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autothrottle.altmach = func {
   altft = constant.nonil( getprop("/instrumentation/altimeter/indicated-altitude-ft") );
   if( altft >= me.AUTOMACHFEET ) {
       result = constant.TRUE;
   }
   else {
       result = constant.FALSE;
   }

   return result;
}

Autothrottle.atmode = func( speedmode ) {
   if( !me.is_vertical() and !me.is_glide() ) {
       if( me.altmach() ) {
           if( speedmode != "mach-with-throttle" ) {
               speedkt = me.settings.getChild("target-speed-kt").getValue();
               speedmach = speedkt / me.getsoundkt();
               me.settings.getChild("target-mach").setValue(speedmach);
               me.autoflight.getChild("dial-mach").setValue(speedmach);
               me.locks.getChild("speed").setValue("mach-with-throttle");
           }
       }
       else {
           if( speedmode != "speed-with-throttle" ) {
               if( speedmode == "mach-with-throttle" ) {
                   speedmach = me.settings.getChild("target-mach").getValue();
                   speedkt = speedmach * me.getsoundkt();
                   me.settings.getChild("target-speed-kt").setValue(speedkt);
                   me.autoflight.getChild("dial-speed-kt").setValue(speedkt);
               }
               me.locks.getChild("speed").setValue("speed-with-throttle");
           }
       }
   }
}

# the autothrottle switch may be still activated
Autothrottle.atdisable = func {
   me.autoflight.getChild("autothrottle-engage").setValue(constant.FALSE);
   me.locks.getChild("speed").setValue("");
}

Autothrottle.atsend = func {
   speedmode = me.locks.getChild("speed").getValue();
   me.atenable(speedmode);
}

Autothrottle.atenable = func( mode ) {
   if( me.autoflight.getChild("autothrottle-engage").getValue() ) {
       me.locks.getChild("speed").setValue(mode);
   }
   else {
       me.atdisable();
   }
}

# toggle autothrottle (ctrl-S)
Autothrottle.attoggleexport = func {
   if( me.autoflight.getChild("autothrottle-engage").getValue() ) {
       me.atdisable();
   }
   else {
       me.autoflight.getChild("autothrottle-engage").setValue(constant.TRUE);

       if( me.altmach() ) {
           speedmach = me.autoflight.getChild("dial-mach").getValue();
           me.settings.getChild("target-mach").setValue(speedmach);
           me.locks.getChild("speed").setValue("mach-with-throttle");
       }
       else {
           speedkt = me.autoflight.getChild("dial-speed-kt").getValue();
           me.settings.getChild("target-speed-kt").setValue(speedkt);
           me.locks.getChild("speed").setValue("speed-with-throttle");
       }
   }
}

Autothrottle.idle = func {
   for(i=0; i<size(me.engines); i=i+1) {
       me.engines[i].getChild("throttle").setValue(0);
   }
}
