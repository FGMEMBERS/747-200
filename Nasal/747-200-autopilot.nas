# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =========
# AUTOPILOT
# =========

Autopilot = {};

Autopilot.new = func {
   var obj = { parents : [Autopilot,System],

               autothrottlesystem : nil,

               PREDICTIONSEC : 6.0,
               STABLESEC : 3.0,
               AUTOPILOTSEC : 3.0,                            # refresh rate
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
               GLIDEFEET : 250.0,                             # leaves glide slope
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
               OSCTRACKDEG : 0.5,                             # gap between track heading and prediction filter, before oscillations
               OSCNAVDEG : 0.5,                               # gap between nav hold and prediction filter, before oscillations

               PIDSUPERSONIC : 1,
               PIDSUBSONIC : 0,
           
               routeactive : constant.FALSE,

               WPTNM : 3.0,                                   # distance to swap to next waypoint
               VORNM : 3.0                                    # distance to inhibate VOR
         };

   obj.init();

   return obj;
};

Autopilot.init = func {
   me.inherit_system("/systems/autopilot");

   # selectors
   me.aphorizontalexport();
}

Autopilot.set_relation = func( autothrottle ) {
   me.autothrottlesystem = autothrottle;
}

Autopilot.adjustexport = func( sign ) {
   var result = constant.FALSE;

   if( me.has_lock_altitude() ) {
       var value = 0.0;

       result = constant.TRUE;

       # 10 or 100 ft/min per key
       if( me.is_lock_vertical() ) {
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 100.0 * sign;
           }
           else {
               value = 100.0 * sign;
           }
       }
       # 10 or 100 ft per key
       elsif( me.is_lock_altitude() ) {
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 100.0 * sign;
           }
           else {
               value = 100.0 * sign;
           }
       }
       # default (touches cursor)
       else {
           value = 0.0;
       }

       if( me.is_lock_vertical() ) {
           var targetfpm = me.itself["settings"].getChild("vertical-speed-fpm").getValue();

           if( targetfpm == nil ) {
               targetfpm = 0.0;
           }
           targetfpm = targetfpm + value;
           me.itself["settings"].getChild("vertical-speed-fpm").setValue(targetfpm);
       }
       elsif( me.is_lock_altitude() ) {
           var targetft = me.itself["settings"].getChild("target-altitude-ft").getValue();

           targetft = targetft + value;
           me.itself["settings"].getChild("target-altitude-ft").setValue(targetft);
       }
   }

   return result;
}

Autopilot.schedule = func {
   var activation = constant.FALSE;
   var id = ["", "", ""];


   # TEMPORARY work around for 2.0.0
   if( me.route_active() ) {
       activation = constant.TRUE;

       # each time, because the route can change
       var wp = me.itself["route"].getChildren("wp");
       var current_wp = me.itself["route-manager"].getChild("current-wp").getValue();
       var nb_wp = size(wp);

       # route manager doesn't update these fields
       if( nb_wp >= 1 ) {
           id[0] = wp[current_wp].getChild("id").getValue();

           # defaut
           id[1] = "";
           id[2] = id[0];
       }

       if( nb_wp >= 2 ) {
           id[1] = wp[current_wp + 1].getChild("id").getValue();
       }

       if( nb_wp > 0 ) {
           id[2] = wp[nb_wp-1].getChild("id").getValue();
       }
   }

   me.itself["waypoint"][0].getChild("id").setValue( id[0] );
   me.itself["waypoint"][1].getChild("id").setValue( id[1] );
   # property is not created at startup
   me.itself["route-manager"].getNode("wp-last").getNode("id",1).setValue( id[2] );


   # user adds a waypoint
   if( me.is_waypoint() ) {
       # real behaviour : INS input doesn't toggle autopilot
       if( !me.itself["autoflight"].getChild("fg-waypoint").getValue() ) {
           # keep current heading mode, if any
           if( !me.is_lock_true() ) {
               me.aphorizontalexport();
           }

           # already in true heading mode : keep display coherent
           elsif( !me.is_ins() ) {
               me.aptoggleinsexport();
           }
       }

       # Feedback requested by user : activation of route toggles autopilot
       elsif( !me.routeactive ) {
           # only when route is being activated (otherwise cannot leave INS mode)
           if( !me.is_ins() ) {
               me.aptoggleinsexport();
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
           var dialdeg = me.itself["autoflight"].getChild("dial-heading-deg").getValue();
           var headingdeg = me.itself["settings"].getChild("heading-bug-deg").getValue();
           if( headingdeg != dialdeg ) {
               me.itself["autoflight"].getChild("dial-heading-deg").setValue(headingdeg);
           }
       }
   }


   # more sensitive at supersonic speed
   me.sonicheadingmode();


   me.routeactive = activation;
}

# avoid strong roll near a waypoint
Autopilot.waypointroll = func {
    var distancenm = me.itself["waypoint"][0].getChild("dist").getValue();

    # next waypoint
    if( distancenm != nil ) {
        var lastnm = me.itself["state"].getChild("waypoint-nm").getValue();

        # avoids strong roll
        if( distancenm < me.WPTNM ) {
            var rolldeg =  me.noinstrument["roll"].getValue();

            # switches to heading hold
            if( distancenm > lastnm or math.abs(rolldeg) > me.ROLLDEG ) {
                if( me.is_lock_true() ) {
                    setprop("/autopilot/route-manager/input","@DELETE0");
                    me.resetprediction( "true-heading-hold1" );
                }
            }
        }

        # new waypoint
        elsif( distancenm > lastnm ) {
            me.resetprediction( "true-heading-hold1" );
        }

        me.itself["state"].getChild("waypoint-nm").setValue(distancenm);
    }
}

# avoid strong roll near a VOR
Autopilot.vorroll = func {
    # near VOR
    if( getprop("/instrumentation/dme[0]/in-range") ) {
        # restores after VOR
        if( getprop("/instrumentation/dme[0]/indicated-distance-nm") > me.VORNM ) {
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
    var weightlb = 0.0;
    var result = 0.0;

    weightlb = getprop("/fdm/jsbsim/inertia/weight-lbs");
    if( weightlb > me.LANDINGLB ) {
        result = vallanding;
    }
    else {
        var coef = ( me.LANDINGLB - weightlb ) / ( me.LANDINGLB - me.EMPTYLB );

        result = vallanding + coef * ( valempty - vallanding );
    }

    return result;
}

Autopilot.is_engaged = func {
   var result = constant.FALSE;

   if( me.itself["channel"][0].getChild("engage").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.engage = func( state ) {
   me.itself["channel"][0].getChild("engage").setValue( state );
}

Autopilot.apdisableexport = func {
   me.apdisable();

   me.apengageexport();
}

Autopilot.apdisable = func {
   me.engage(constant.FALSE);

   me.itself["autoflight"].getChild("heading").setValue("");
   me.itself["autoflight"].getChild("altitude").setValue("");
   me.itself["autoflight"].getChild("vertical").setValue("");

   me.itself["locks"].getChild("heading").setValue("");
   me.itself["locks"].getChild("altitude").setValue("");
}

Autopilot.disabledexport = func {
}

Autopilot.apengageexport = func {
   var altitudemode = "";
   var headingmode = "";

   if( me.is_engaged() ) {
       var verticalmode = me.itself["autoflight"].getChild("vertical").getValue();

       altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
       headingmode = me.itself["autoflight"].getChild("heading").getValue();

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

   me.itself["locks"].getChild("altitude").setValue(altitudemode);
   me.itself["locks"].getChild("heading").setValue(headingmode);

   if( me.is_magnetic() ) {
       var headingdeg = me.itself["autoflight"].getChild("dial-heading-deg").getValue();

       me.itself["settings"].getChild("heading-bug-deg").setValue(headingdeg);
   }

   me.autoland();
}


# ---------------
# HORIZONTAL MODE
# ---------------

Autopilot.is_waypoint = func {
   var result = constant.FALSE;

   if( me.route_active() ) {
       var id = me.itself["waypoint"][0].getChild("id").getValue();
       if( id != nil and id != "" ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Autopilot.route_active = func {
   var result = constant.FALSE;

   # autopilot/route-manager/wp is updated only once airborne
   if( me.itself["route-manager"].getChild("active").getValue() and
       me.itself["route-manager"].getChild("airborne").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_nav1 = func {
   var result = constant.FALSE;
   var headingmode = me.itself["autoflight"].getChild("heading").getValue();

   if( headingmode == "nav1-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_lock_nav1 = func {
   var result = constant.FALSE;
   var headingmode = me.itself["locks"].getChild("heading").getValue();

   if( headingmode == "nav1-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.locknav1 = func {
   me.itself["locks"].getChild("heading").setValue("nav1-hold");
}

# toggle vor loc (ctrl-N)
Autopilot.aptogglevorlocexport = func {
   if( !me.is_nav1() or ( me.is_nav1() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(0);
   }
   else {
       me.engage(constant.FALSE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.is_ins = func {
   var result = constant.FALSE;

   var horizontalselector = me.itself["autoflight"].getChild("horizontal-selector").getValue();

   if( horizontalselector == -2 ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.aptoggleinsexport = func {
   if( !me.is_ins() or ( me.is_ins() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-2);
   }
   else {
       me.engage(constant.FALSE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.is_vor = func {
   var result= constant.FALSE;

   var horizontalselector = me.itself["autoflight"].getChild("horizontal-selector").getValue();

   if( horizontalselector == 0 ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.aphorizontalexport = func {
   var headingmode = "";

   var horizontalselector = me.itself["autoflight"].getChild("horizontal-selector").getValue();

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

   me.itself["autoflight"].getChild("heading").setValue(headingmode);

   me.apengageexport();
}


# ------------
# HEADING MODE
# ------------

Autopilot.is_lock_true = func {
   var result = constant.FALSE;

   var headingmode = me.itself["locks"].getChild("heading").getValue();

   if( headingmode == "true-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_magnetic = func {
   var result = constant.FALSE;

   var headingmode = me.itself["autoflight"].getChild("heading").getValue();

   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_lock_magnetic = func {
   var result = constant.FALSE;

   var headingmode = me.itself["locks"].getChild("heading").getValue();

   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.locktrue = func {
   me.itself["locks"].getChild("heading").setValue("true-heading-hold");
}

Autopilot.lockmagnetic = func {
   me.itself["locks"].getChild("heading").setValue("dg-heading-hold");
}

Autopilot.holdmagnetic = func {
   var headingdeg = getprop("/orientation/heading-magnetic-deg");

   me.holdheading( headingdeg );
}

Autopilot.holdheading = func( headingdeg ) {
   me.itself["settings"].getChild("heading-bug-deg").setValue(headingdeg);
   me.lockmagnetic();
}

# toggle heading hold (ctrl-H)
Autopilot.aptoggleheadingexport = func {
   if( !me.is_magnetic() or ( me.is_magnetic() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-1);
   }
   else {
       me.engage(constant.FALSE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.sonicpid = func {
   var mode = me.PIDSUBSONIC;

   return mode;
}

Autopilot.is_supersonicpid = func( mode ) {
   var result = constant.FALSE;

   if( mode == me.PIDSUPERSONIC ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_subsonicpid = func( mode ) {
   var result = constant.FALSE;

   if( mode == me.PIDSUBSONIC ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.sonicheadingmode = func {
   var magpid = constant.FALSE;
   var truepid = constant.FALSE;
   var navpid = constant.FALSE;

   if( me.is_lock_magnetic() ) {
       me.sonicmagneticheading();
       magpid = constant.TRUE;
   }

   elsif( me.is_lock_true() ) {
       me.sonictrueheading();
       truepid = constant.TRUE;
   }

   elsif( me.is_lock_nav1() ) {
       me.sonicnavheading();
       navpid = constant.TRUE;
   }

   if( !magpid ) {
       me.resetprediction( "dg-heading-hold1" );
   }
   if( !truepid ) {
       me.resetprediction( "true-heading-hold1" );
   }
   if( !navpid ) {
       me.resetprediction( "nav-hold1" );
   }
}

# sonic true mode
Autopilot.sonictrueheading = func {
   var name = "true-heading-hold1";
   var node = me.itself["pid"].getNode(name);
   var mode = me.sonicpid();

   # prediction filter may bank into the opposite direction, when engaged
   me.predictioncorrection( name, node, mode, me.OSCTRACKDEG );
}

# sonic magnetic mode
Autopilot.sonicmagneticheading = func {
   var name = "dg-heading-hold1";
   var node = me.itself["pid"].getNode(name);
   var mode = me.sonicpid();

   # prediction filter amplifies oscillations
   if( me.is_autoland() ) {
       me.resetprediction( name );
   }

   else {
       me.predictioncorrection( name, node, mode, me.OSCTRACKDEG );
   }
}

# sonic nav mode
Autopilot.sonicnavheading = func {
   var name = "nav-hold1";
   var node = me.itself["pid"].getNode(name);
   var mode = me.sonicpid();

   # prediction filter amplifies oscillations
   if( me.is_autoland() or me.is_ils() ) {
       me.resetprediction( name );
   }

   else {
       me.predictioncorrection( name, node, mode, me.OSCNAVDEG );
   }
}

# correction of prediction filter oscillations
Autopilot.predictioncorrection = func( name, node, mode, mindeg ) {
   # disabled, when it amplifies oscillations :
   # - speed up.
   if( !me.itself["pid"].getChild("prediction-filter").getValue() or
       me.noinstrument["speed-up"].getValue() > 1.0 ) {
       me.resetprediction( name );
   }


   else {
       var erroraheaddeg = 0.0;
       var errordeg = 0.0;
       var offsetdeg = 0.0;
       var deltastablesec = 0.0;
       var deltalaunchsec = 0.0;
       var path = "";


       var filter = node.getChild("prediction-filter").getValue();

       var stablesec = node.getChild("stable-sec").getValue();
       var launchsec = node.getChild("launch-sec").getValue();
       var timesec = me.noinstrument["time"].getValue();

       if( stablesec > 0.0 ) {
           deltastablesec = timesec - stablesec;
       }
       if( launchsec > 0.0 ) {
           deltalaunchsec = timesec - launchsec;
       }


       path = me.itself["config"][me.PIDSUPERSONIC].getNode(name).getChild("input").getValue();
       erroraheaddeg = props.globals.getNode(path).getValue();

       path = me.itself["config"][me.PIDSUBSONIC].getNode(name).getChild("input").getValue();
       errordeg = props.globals.getNode(path).getValue();

       offsetdeg = errordeg - erroraheaddeg;
       offsetdeg = math.abs( offsetdeg );


       # would bank into the opposite direction, when engaged
       if( deltalaunchsec <= me.PREDICTIONSEC ) {
           deltastablesec = 0.0;

           # enable filter later on a plausible prediction
           mode = me.PIDSUPERSONIC;
       }

       # filter amplifies oscillations, once in cruise
       elsif( offsetdeg < mindeg and deltastablesec > me.STABLESEC ) {
           # disable filter in cruise
           mode = me.PIDSUPERSONIC;
       }

       # hysteresis, once stable
       elsif( !filter and offsetdeg < ( 2 * mindeg ) and deltastablesec > me.STABLESEC ) {
           # will enable filter on a higher offset
           mode = me.PIDSUPERSONIC;
       }

       # filter not yet stable
       else {
           deltastablesec = 0.0;
       }


       me.setprediction( name, node, mode );


       # reset timers
       if( deltastablesec <= 0.0 ) {
           me.setpredictionstability( node, timesec );
       }

       if( deltalaunchsec <= 0.0 ) {
           me.setpredictionlaunch( node, timesec );
       }
   }
}

Autopilot.setprediction = func( name, node, mode ) {
   var result = constant.FALSE;
   var child = node.getChild("input");
   var currentpath = child.getAliasTarget().getPath();
   var path = me.itself["config"][mode].getNode(name).getChild("input").getValue();

   # update only on change
   if( currentpath != path ) {
       child.unalias();
       child.alias( path );

       # feedback on filter activity
       node.getChild("prediction-filter").setValue( me.is_subsonicpid( mode ) );

       result = constant.TRUE;
   }

   return result;
}

Autopilot.resetprediction = func( name ) {
   var node = me.itself["pid"].getNode(name);

   if( me.setprediction( name, node, me.PIDSUPERSONIC ) ) {
       me.setpredictionstability( node, 0.0 );
       me.setpredictionlaunch( node, 0.0 );
   }
}

Autopilot.setpredictionstability = func( node, stablesec ) {
   node.getChild("stable-sec").setValue( stablesec );
}

Autopilot.setpredictionlaunch = func( node, launchsec ) {
   node.getChild("launch-sec").setValue( launchsec );
}


# -------------
# VERTICAL MODE
# -------------

# adjust target speed with wind
Autopilot.targetwind = func {
   var targetkt = 0.0;
   var windkt = 0.0;

   # VREF
   targetkt = me.clampweight( me.VREFFULLKT, me.VREFEMPTYKT );

   # wind increases lift
   windkt = getprop("/environment/wind-speed-kt");
   if( windkt > 0 ) {
       var winddeg = getprop("/environment/wind-from-heading-deg");
       var vordeg = getprop("/instrumentation/nav[0]/radials/target-radial-deg");
       var offsetdeg = vordeg - winddeg;

       offsetdeg = constant.crossnorth( offsetdeg );

       # add head wind component; except tail wind (too much glide)
       if( offsetdeg > -constant.DEG90 and offsetdeg < constant.DEG90 ) {
           var offsetrad = offsetdeg * constant.DEGTORAD;
           var offsetkt = windkt * math.cos( offsetrad );

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
   me.itself["settings"].getChild("target-speed-kt").setValue(targetkt);
}

# reduces the rebound caused by ground effect
Autopilot.targetpitch = func( aglft ) {
   var targetdeg = 0.0;

   # counter the rebound of ground effect
   if( aglft > me.GLIDEFEET ) {
       targetdeg = me.FLAREDEG;
   }
   elsif( aglft < me.GROUNDFEET ) {
       targetdeg = me.TOUCHDEG;
   }
   else {
       var coef = ( aglft - me.GROUNDFEET ) / ( me.GLIDEFEET - me.GROUNDFEET );

       targetdeg = me.TOUCHDEG + coef * ( me.FLAREDEG - me.TOUCHDEG );
   }
   
   me.holdpitch(targetdeg);
}

Autopilot.is_landing = func {
   var result = constant.FALSE;

   var verticalmode = me.itself["autoflight"].getChild("heading").getValue();

   if( verticalmode == "autoland" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_land_armed = func {
   var result = constant.FALSE;

   var verticalmode = me.itself["autoflight"].getChild("heading").getValue();

   if( verticalmode == "autoland-armed" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_autoland = func {
   var result = constant.FALSE;

   if( me.is_landing() or me.is_land_armed() ) {
       result = constant.TRUE;
   }

   return result;
}

# autoland mode
Autopilot.autoland = func {
   if( me.is_engaged() ) {
       if( me.is_autoland() ) {
           var rates = me.AUTOLANDSEC;
           var aglft = getprop("/instrumentation/radio-altimeter/indicated-altitude-ft");

           # armed
           if( me.is_land_armed() ) {
               if( aglft <= me.AUTOLANDFEET ) {
                   me.itself["autoflight"].getChild("heading").setValue("autoland");
               }
           }

           # engaged
           if( me.is_landing() ) {
               # touch down
               if( aglft < constantaero.AGLTOUCHFT ) {

                   # gently reduce pitch
                   if( me.noinstrument["pitch"].getValue() > 1.0 ) {
                       rates = me.TOUCHSEC;

                       # 1 deg / s
                       var pitchdeg = me.itself["settings"].getChild("target-pitch-deg").getValue();

                       pitchdeg = pitchdeg - 0.2;
                       me.holdpitch( pitchdeg );
                   }

                   # safe on ground
                   else {
                       rates = me.SAFESEC;

                       # disable autopilot and autothrottle
                       me.autothrottlesystem.atdisable();
                       me.apdisable();

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
                   me.itself["autoflight"].getChild("heading").setValue("autoland-armed");
               }

               # systematic forcing of speed modes
               else {
                   if( aglft < me.GLIDEFEET ) {
                       rates = me.FLARESEC;

                       # landing pitch (flare) : removes the rebound at touch down of vertical-speed-hold.
                       me.targetpitch( aglft );

                       # heading hold avoids roll outside the runway.
                       if( !me.itself["autoflight"].getChild("real-nav").getValue() ) {
                           if( aglft < me.NAVFEET ) {
                               if( !me.is_lock_magnetic() ) {
                                   me.landheadingdeg = getprop("/orientation/heading-magnetic-deg");
                               }
                               me.holdheading( me.landheadingdeg );
                           }
                       }

                       # pilot must activate autothrottle
                       me.itself["settings"].getChild("vertical-speed-fpm").setValue( me.TOUCHFPM );
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
                       me.FLAREDEG = me.noinstrument["pitch"].getValue();
                   }
               } 
           }
       }

       # re-schedule the next call
       if( me.is_autoland() ) {
           settimer(func{ me.autoland(); }, rates);
       }
   }
}

Autopilot.is_ils = func {
   var result = constant.FALSE;

   var headingmode = me.itself["autoflight"].getChild("heading").getValue();

   if( headingmode == "ils-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

# toggle glide slope (ctrl-G)
Autopilot.aptoggleglideexport = func {
   if( !me.is_ils() or ( me.is_ils() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(1);
   }
   else {
       me.engage(constant.FALSE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.has_lock_altitude = func {
   var result= constant.FALSE;

   var altitudemode = me.itself["locks"].getChild("altitude").getValue();

   if( altitudemode != "" and altitudemode != nil ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_lock_vertical = func {
   var result = constant.FALSE;

   var altitudemode = me.itself["locks"].getChild("altitude").getValue();

   if( altitudemode == "vertical-speed-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.apverticalexport = func {
   var verticalmode = "";

   var verticalselector = me.itself["autoflight"].getChild("vertical-selector").getValue();

   if( verticalselector == -1 ) {
       verticalmode = "";
   }
   elsif( verticalselector == 0 ) {
       verticalmode = "vertical-speed-hold";

       var verticalspeedfps = getprop("/instrumentation/inst-vertical-speed-indicator/indicated-speed-fps");
       var verticalspeedfpm = verticalspeedfps * constant.MINUTETOSECOND;

       me.itself["settings"].getChild("vertical-speed-fpm").setValue(verticalspeedfpm);
   }

   me.itself["autoflight"].getChild("vertical").setValue(verticalmode);

   me.apengageexport();
}

Autopilot.holdpitch = func( pitchdeg ) {
   me.itself["settings"].getNode("target-pitch-deg").setValue(pitchdeg);
   me.lockpitch();
}

Autopilot.lockpitch = func {
   me.itself["locks"].getChild("altitude").setValue("pitch-hold");
}


# -------------
# ALTITUDE MODE
# -------------

Autopilot.is_altitude_select = func {
   var result = constant.FALSE;

   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();

   if( altitudemode == "altitude-select" ) {
       result = constant.TRUE;
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
       me.itself["autoflight"].getChild("altitude").setValue("");

       me.apverticalexport();
   }
}

Autopilot.apaltitudeselectexport = func {
   var targetft = me.itself["autoflight"].getChild("dial-altitude-ft").getValue();

   me.itself["settings"].getChild("target-altitude-ft").setValue(targetft);
   me.itself["autoflight"].getChild("altitude").setValue("altitude-select");

   me.apengageexport();
}

Autopilot.is_altitude_hold = func {
   var result = constant.FALSE;

   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();

   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
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
       me.itself["autoflight"].getChild("altitude").setValue("");

       me.apverticalexport();
   }
}

Autopilot.apaltitudeholdexport = func {
   var targetft = getprop("/instrumentation/altimeter/indicated-altitude-ft");

   me.itself["settings"].getChild("target-altitude-ft").setValue(targetft);
   me.itself["autoflight"].getChild("altitude").setValue("altitude-hold");

   me.apengageexport();
}

Autopilot.is_lock_altitude = func {
   var result = constant.FALSE;

   var altitudemode = me.itself["locks"].getChild("altitude").getValue();

   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
   }

   return result;
}


# ============
# AUTOTHROTTLE
# ============

Autothrottle = {};

Autothrottle.new = func {
   var obj = { parents : [Autothrottle,System],

               AUTOTHROTTLESEC : 2.0,

               AUTOMACHFEET : 0.0
         };

   obj.init();

   return obj;
};

Autothrottle.init = func {
   me.inherit_system("/systems/autothrottle");

   me.AUTOMACHFEET = me.itself["autoflight"].getChild("automach-ft").getValue();
}

Autothrottle.schedule = func {
   var speedmode = me.itself["locks"].getChild("speed").getValue();

   # automatic swaps between kt and Mach
   if( speedmode != "" and speedmode != nil ) {
       me.atmode( speedmode );
   }
}

# speed of sound
Autothrottle.getsoundkt = func {
   # simplification
   var speedkt = getprop("/velocities/airspeed-kt");
   var speedmach = getprop("/velocities/mach");
   var soundkt = speedkt / speedmach;

   return soundkt;
}

Autothrottle.is_vertical = func {
   var result = constant.FALSE;

   var speedmode = me.itself["locks"].getChild("speed").getValue();

   if( speedmode == "vertical-speed-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.is_glide = func {
   var result = constant.FALSE;

   var speedmode = me.itself["locks"].getChild("speed").getValue();

   if( speedmode == "gs1-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.altmach = func {
   var result = constant.FALSE;

   var altft = constant.nonil( getprop("/instrumentation/altimeter/indicated-altitude-ft") );

   if( altft >= me.AUTOMACHFEET ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.atmode = func( speedmode ) {
   var speedkt = 0.0;
   var speedmach = 0.0;

   if( !me.is_vertical() and !me.is_glide() ) {
       if( me.altmach() ) {
           if( speedmode != "mach-with-throttle" ) {
               speedkt = me.itself["settings"].getChild("target-speed-kt").getValue();
               speedmach = speedkt / me.getsoundkt();
               me.itself["settings"].getChild("target-mach").setValue(speedmach);
               me.itself["autoflight"].getChild("dial-mach").setValue(speedmach);
               me.itself["locks"].getChild("speed").setValue("mach-with-throttle");
           }
       }
       else {
           if( speedmode != "speed-with-throttle" ) {
               if( speedmode == "mach-with-throttle" ) {
                   speedmach = me.itself["settings"].getChild("target-mach").getValue();
                   speedkt = speedmach * me.getsoundkt();
                   me.itself["settings"].getChild("target-speed-kt").setValue(speedkt);
                   me.itself["autoflight"].getChild("dial-speed-kt").setValue(speedkt);
               }
               me.itself["locks"].getChild("speed").setValue("speed-with-throttle");
           }
       }
   }
}

# the autothrottle switch may be still activated
Autothrottle.atdisable = func {
   me.itself["autoflight"].getChild("autothrottle-engage").setValue(constant.FALSE);
   me.itself["locks"].getChild("speed").setValue("");
}

Autothrottle.atsend = func {
   var speedmode = me.itself["locks"].getChild("speed").getValue();

   me.atenable(speedmode);
}

Autothrottle.atenable = func( mode ) {
   if( me.itself["autoflight"].getChild("autothrottle-engage").getValue() ) {
       me.itself["locks"].getChild("speed").setValue(mode);
   }
   else {
       me.atdisable();
   }
}

# toggle autothrottle (ctrl-S)
Autothrottle.attoggleexport = func {
   if( me.itself["autoflight"].getChild("autothrottle-engage").getValue() ) {
       me.atdisable();
   }
   else {
       me.itself["autoflight"].getChild("autothrottle-engage").setValue(constant.TRUE);

       if( me.altmach() ) {
           var speedmach = me.itself["autoflight"].getChild("dial-mach").getValue();
           me.itself["settings"].getChild("target-mach").setValue(speedmach);
           me.itself["locks"].getChild("speed").setValue("mach-with-throttle");
       }
       else {
           var speedkt = me.itself["autoflight"].getChild("dial-speed-kt").getValue();
           me.itself["settings"].getChild("target-speed-kt").setValue(speedkt);
           me.itself["locks"].getChild("speed").setValue("speed-with-throttle");
       }
   }
}

Autothrottle.idle = func {
   for(var i=0; i<constantaero.NBENGINES; i=i+1) {
       me.dependency["engine"][i].getChild("throttle").setValue(0);
   }
}
